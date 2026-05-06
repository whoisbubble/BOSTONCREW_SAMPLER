#pragma once

#include <QAbstractListModel>
#include <QAudioOutput>
#include <QColor>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMediaPlayer>
#include <QObject>
#include <QPointer>
#include <QScreen>
#include <QTcpSocket>
#include <QTimer>
#include <QUrl>

struct SampleData
{
    QString name;
    QString path;
    bool isPlaying = false;
    double duration = 0.0;
    double volume = 1.0;
    bool stopSounds = false;
    QColor color = QColor("#f2c94c");
};

struct SlideData
{
    struct MediaCue
    {
        SampleData sample;
        bool hasSample = false;
        bool repeats = false;
    };

    QString folderName;
    QStringList mediaPaths;
    QList<MediaCue> mediaCues;
    SampleData sample;
    bool hasSample = false;
    bool isSampleNeed = false;
    QString type = "Default";
    QString catalogPath;
};

class SampleListModel final : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        FileNameRole,
        IsPlayingRole,
        DurationRole,
        DurationTextRole,
        VolumeRole,
        StopSoundsRole,
        ColorRole
    };

    explicit SampleListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QList<SampleData> &items();
    const QList<SampleData> &items() const;
    SampleData *at(int row);
    const SampleData *at(int row) const;

    void reset(QList<SampleData> values);
    void append(const SampleData &sample);
    void replace(int row, const SampleData &sample);
    void removeAt(int row);
    void moveItem(int from, int to);
    void notifyChanged(int row);
    void clear();

private:
    QList<SampleData> m_items;
};

class SlideListModel final : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        FolderNameRole = Qt::UserRole + 1,
        TypeRole,
        CatalogPathRole,
        CountRole,
        HasSampleRole,
        SampleNameRole,
        IsSampleNeedRole,
        MediaPathsRole,
        MediaSampleNamesRole,
        MediaHasSamplesRole,
        MediaRepeatsRole,
        FirstMediaUrlRole,
        IsDefaultRole
    };

    explicit SlideListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QList<SlideData> &items();
    const QList<SlideData> &items() const;
    SlideData *at(int row);
    const SlideData *at(int row) const;

    void reset(QList<SlideData> values);
    void append(const SlideData &slide);
    void replace(int row, const SlideData &slide);
    void removeAt(int row);
    void notifyChanged(int row);
    void clear();

private:
    QList<SlideData> m_items;
};

class PreviewListModel final : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        FilePathRole = Qt::UserRole + 1,
        FileNameRole,
        FileUrlRole,
        IsVideoRole,
        IsCurrentRole,
        IsDimmedRole
    };

    explicit PreviewListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setMedia(const QStringList &mediaPaths, int currentIndex, const QString &basePath);
    void setCurrentIndex(int currentIndex);
    void dim(int row);
    QString absolutePathAt(int row) const;

private:
    struct PreviewItem {
        QString relativePath;
        QString absolutePath;
        bool isVideo = false;
        bool dimmed = false;
    };

    QList<PreviewItem> m_items;
    int m_currentIndex = -1;
};

class SamplerBackend final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(SampleListModel *samples READ samples CONSTANT)
    Q_PROPERTY(SampleListModel *fixedSamples READ fixedSamples CONSTANT)
    Q_PROPERTY(SlideListModel *quickSlides READ quickSlides CONSTANT)
    Q_PROPERTY(SlideListModel *librarySlides READ librarySlides CONSTANT)
    Q_PROPERTY(PreviewListModel *previewItems READ previewItems CONSTANT)
    Q_PROPERTY(bool settingsMode READ settingsMode WRITE setSettingsMode NOTIFY settingsModeChanged)
    Q_PROPERTY(bool audioPaused READ audioPaused NOTIFY audioPausedChanged)
    Q_PROPERTY(bool stageActive READ stageActive NOTIFY stageChanged)
    Q_PROPERTY(QString currentMediaUrl READ currentMediaUrl NOTIFY stageChanged)
    Q_PROPERTY(QString currentMediaPath READ currentMediaPath NOTIFY stageChanged)
    Q_PROPERTY(bool currentMediaIsVideo READ currentMediaIsVideo NOTIFY stageChanged)
    Q_PROPERTY(bool currentMediaRepeats READ currentMediaRepeats NOTIFY stageChanged)
    Q_PROPERTY(QString nextMediaUrl READ nextMediaUrl NOTIFY stageChanged)
    Q_PROPERTY(QString slideCounterText READ slideCounterText NOTIFY stageChanged)
    Q_PROPERTY(int currentSlideIndex READ currentSlideIndex NOTIFY stageChanged)
    Q_PROPERTY(int currentMediaIndex READ currentMediaIndex NOTIFY stageChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectionChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString savedHost READ savedHost WRITE setSavedHost NOTIFY savedHostChanged)
    Q_PROPERTY(int stageX READ stageX NOTIFY screenGeometryChanged)
    Q_PROPERTY(int stageY READ stageY NOTIFY screenGeometryChanged)
    Q_PROPERTY(int stageWidth READ stageWidth NOTIFY screenGeometryChanged)
    Q_PROPERTY(int stageHeight READ stageHeight NOTIFY screenGeometryChanged)
    Q_PROPERTY(QScreen *stageScreen READ stageScreen NOTIFY screenGeometryChanged)

public:
    explicit SamplerBackend(QObject *parent = nullptr);
    ~SamplerBackend() override;

    SampleListModel *samples();
    SampleListModel *fixedSamples();
    SlideListModel *quickSlides();
    SlideListModel *librarySlides();
    PreviewListModel *previewItems();

    bool settingsMode() const;
    void setSettingsMode(bool enabled);
    bool audioPaused() const;
    bool stageActive() const;
    QString currentMediaUrl() const;
    QString currentMediaPath() const;
    bool currentMediaIsVideo() const;
    bool currentMediaRepeats() const;
    QString nextMediaUrl() const;
    QString slideCounterText() const;
    int currentSlideIndex() const;
    int currentMediaIndex() const;
    bool connected() const;
    QString statusMessage() const;
    QString savedHost() const;
    void setSavedHost(const QString &host);
    int stageX() const;
    int stageY() const;
    int stageWidth() const;
    int stageHeight() const;
    QScreen *stageScreen() const;

    Q_INVOKABLE void addSample();
    Q_INVOKABLE void playSample(int index, bool advanceSlide = false);
    Q_INVOKABLE void stopSample(int index);
    Q_INVOKABLE void stopAllSamples();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void updateSample(int index, const QString &name, double volume, bool stopSounds, const QString &color);
    Q_INVOKABLE void changeSampleFile(int index);
    Q_INVOKABLE void deleteSample(int index);
    Q_INVOKABLE void moveSample(int from, int to);

    Q_INVOKABLE void playFixedSample(int index, bool advanceSlide = false);
    Q_INVOKABLE void replaceFixedSample(int index);

    Q_INVOKABLE void playQuickSlide(int index);
    Q_INVOKABLE void assignQuickSlide(int quickIndex, int libraryIndex);
    Q_INVOKABLE void clearQuickSlide(int quickIndex);
    Q_INVOKABLE void nextSlide();
    Q_INVOKABLE void previousSlide();
    Q_INVOKABLE void playPreviewMedia(int previewIndex, int action);
    Q_INVOKABLE void closeStage();

    Q_INVOKABLE void createLibrarySlide();
    Q_INVOKABLE void updateLibrarySlide(int index, const QString &folderName, const QString &type);
    Q_INVOKABLE void deleteLibrarySlide(int index);
    Q_INVOKABLE void addMediaToLibrarySlide(int index);
    Q_INVOKABLE void addSampleToLibrarySlide(int index);
    Q_INVOKABLE void moveLibrarySlideMedia(int slideIndex, int from, int to);
    Q_INVOKABLE void deleteLibrarySlideMedia(int slideIndex, int mediaIndex);
    Q_INVOKABLE void addSampleToLibrarySlideMedia(int slideIndex, int mediaIndex);
    Q_INVOKABLE void clearSampleFromLibrarySlideMedia(int slideIndex, int mediaIndex);
    Q_INVOKABLE void setLibrarySlideMediaRepeats(int slideIndex, int mediaIndex, bool repeats);
    Q_INVOKABLE void openLibraryFolder(int index);
    Q_INVOKABLE void openDataFolder();
    Q_INVOKABLE void saveAll();

    Q_INVOKABLE void connectHost(const QString &host);
    Q_INVOKABLE void disconnectHost();
    Q_INVOKABLE void sendHostMessage(const QString &message);
    Q_INVOKABLE void toggleStageVideoPause();
    Q_INVOKABLE void restartStageVideo();

    Q_INVOKABLE QString absolutePath(const QString &storedPath) const;
    Q_INVOKABLE QString urlForPath(const QString &storedPath) const;
    Q_INVOKABLE bool isVideoPath(const QString &path) const;
    Q_INVOKABLE bool hasSecondScreen() const;

signals:
    void settingsModeChanged();
    void audioPausedChanged();
    void stageChanged();
    void connectionChanged();
    void statusMessageChanged();
    void savedHostChanged();
    void screenGeometryChanged();
    void stageVideoPauseRequested();
    void stageVideoRestartRequested();

private:
    struct ActivePlayback {
        QPointer<QMediaPlayer> player;
        QPointer<QAudioOutput> output;
        SampleListModel *model = nullptr;
        int row = -1;
        QObject *ownedObject = nullptr;
    };

    QString baseDir() const;
    QString saveDir() const;
    QString samplesDir() const;
    QString contentDir() const;
    QString storagePath(const QString &path) const;
    bool isManagedPath(const QString &path) const;
    void cleanupStoredFile(const QString &storedPath) const;
    QString cleanFolderName(const QString &name) const;
    QString uniqueSlideName() const;
    QString uniqueFileName(const QString &directory, const QString &baseName, const QString &extension, int index) const;
    QString copyFileTo(const QString &sourcePath, const QString &directory, const QString &baseName, int index, bool forceMp3Name);
    double probeDuration(const QString &path) const;

    static bool isDefaultSlide(const SlideData &slide);
    static bool isVideoExtension(const QString &path);
    static bool isImageExtension(const QString &path);
    static QString durationText(double seconds);
    static QJsonObject sampleToJson(const SampleData &sample);
    static SampleData sampleFromJson(const QJsonObject &object);
    static QJsonObject slideToJson(const SlideData &slide);
    static SlideData slideFromJson(const QJsonObject &object);

    QJsonDocument readJsonDocument(const QString &path) const;
    void writeJsonDocument(const QString &path, const QJsonDocument &document) const;
    void loadAll();
    void loadSamples();
    void loadSlides();
    void loadQuickSlides();
    void saveSamples() const;
    void saveSlides() const;
    void saveQuickSlides() const;
    void refreshAssignedSlides();
    bool isSlideValid(const SlideData &slide) const;
    SlideData createDefaultSlide() const;
    SlideData copySlide(const SlideData &slide) const;
    void ensureMediaCueCount(SlideData &slide) const;

    bool startPlayback(SampleListModel *model, int row, bool showErrors, QObject *ownedObject = nullptr);
    void playMediaCue(const SlideData &slide, int mediaIndex);
    void markPlaying(SampleListModel *model, int row, bool playing);
    void reindexActiveRowsAfterRemoval(SampleListModel *model, int removedRow);
    void reindexActiveRowsAfterMove(SampleListModel *model, int from, int to);
    void cleanupPlaybackEntry(int index, bool stopPlayer);
    void removeActiveFor(SampleListModel *model, int row);
    void cleanupFinishedPlayback(QMediaPlayer *player);

    void syncStageToCurrentSlide();
    void showSlideMedia();
    void updatePreviewModel();
    void setStatus(const QString &message);
    void updateScreenGeometry();
    void saveHost(const QString &host) const;
    QString loadHost() const;
    void sendWebSocketHandshake(const QUrl &url);
    void handleSocketReadyRead();
    void handleWebSocketPayload(const QString &message);
    void sendWebSocketText(const QString &message);
    QByteArray takeWebSocketFrame();

    SampleListModel m_samples;
    SampleListModel m_fixedSamples;
    SlideListModel m_quickSlides;
    SlideListModel m_librarySlides;
    PreviewListModel m_previewItems;
    QList<ActivePlayback> m_activePlaybacks;
    QTcpSocket m_socket;
    QByteArray m_socketBuffer;
    QByteArray m_webSocketKey;
    bool m_webSocketReady = false;

    bool m_settingsMode = false;
    bool m_audioPaused = false;
    bool m_stageActive = false;
    int m_currentSlideIndex = -1;
    int m_currentMediaIndex = -1;
    QString m_currentMediaPath;
    QString m_nextMediaPath;
    QString m_statusMessage;
    QString m_savedHost;
    int m_stageX = 80;
    int m_stageY = 80;
    int m_stageWidth = 1280;
    int m_stageHeight = 720;
    QPointer<QScreen> m_stageScreen;
};
