#include "SamplerBackend.h"

#include <algorithm>
#include <stdexcept>
#include <utility>

#include <QAbstractSocket>
#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QScreen>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
constexpr int QuickSlideCount = 11;

QString normalizedRelative(QString value)
{
    return QDir::fromNativeSeparators(value).trimmed();
}

QString fileBaseNameForCopy(const QString &path)
{
    QString base = QFileInfo(path).completeBaseName();
    if (base.trimmed().isEmpty())
        base = "file";
    return base;
}

QString formatDuration(double seconds)
{
    const int total = qMax(0, qRound(seconds));
    return QString("%1:%2").arg(total / 60, 2, 10, QLatin1Char('0')).arg(total % 60, 2, 10, QLatin1Char('0'));
}

bool isVideoFileName(const QString &path)
{
    const QString ext = QFileInfo(path).suffix().toLower();
    return QStringList({"mp4", "avi", "wmv", "mov", "m4v", "mkv", "webm", "flv"}).contains(ext);
}

bool hasAnyMediaCue(const SlideData &slide)
{
    return std::any_of(slide.mediaCues.cbegin(), slide.mediaCues.cend(), [](const SlideData::MediaCue &cue) {
        return cue.hasSample && !cue.sample.path.isEmpty();
    });
}

QString firstMediaCueName(const SlideData &slide)
{
    for (const SlideData::MediaCue &cue : slide.mediaCues) {
        if (cue.hasSample && !cue.sample.name.isEmpty())
            return cue.sample.name;
    }
    return {};
}

QStringList mediaCueNames(const SlideData &slide)
{
    QStringList names;
    for (int i = 0; i < slide.mediaPaths.count(); ++i) {
        if (i < slide.mediaCues.count() && slide.mediaCues.at(i).hasSample)
            names.append(slide.mediaCues.at(i).sample.name);
        else
            names.append(QString());
    }
    return names;
}

QVariantList mediaCueFlags(const SlideData &slide)
{
    QVariantList flags;
    for (int i = 0; i < slide.mediaPaths.count(); ++i)
        flags.append(i < slide.mediaCues.count() && slide.mediaCues.at(i).hasSample && !slide.mediaCues.at(i).sample.path.isEmpty());
    return flags;
}

QVariantList mediaRepeatFlags(const SlideData &slide)
{
    QVariantList flags;
    for (int i = 0; i < slide.mediaPaths.count(); ++i) {
        const bool legacyRepeat = isVideoFileName(slide.mediaPaths.at(i))
            && QFileInfo(slide.mediaPaths.at(i)).fileName().startsWith("again", Qt::CaseInsensitive);
        flags.append(i < slide.mediaCues.count() ? slide.mediaCues.at(i).repeats || legacyRepeat : legacyRepeat);
    }
    return flags;
}
}

SampleListModel::SampleListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int SampleListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.count();
}

QVariant SampleListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return {};

    const SampleData &sample = m_items.at(index.row());
    switch (role) {
    case NameRole:
        return sample.name;
    case PathRole:
        return sample.path;
    case FileNameRole:
        return QFileInfo(sample.path).fileName();
    case IsPlayingRole:
        return sample.isPlaying;
    case DurationRole:
        return sample.duration;
    case DurationTextRole:
        return formatDuration(sample.duration);
    case VolumeRole:
        return sample.volume;
    case StopSoundsRole:
        return sample.stopSounds;
    case ColorRole:
        return sample.color.name(QColor::HexRgb);
    default:
        return {};
    }
}

QHash<int, QByteArray> SampleListModel::roleNames() const
{
    return {
        {NameRole, "sampleName"},
        {PathRole, "samplePath"},
        {FileNameRole, "fileName"},
        {IsPlayingRole, "isPlaying"},
        {DurationRole, "duration"},
        {DurationTextRole, "durationText"},
        {VolumeRole, "sampleVolume"},
        {StopSoundsRole, "sampleStopSounds"},
        {ColorRole, "foreColor"}
    };
}

QList<SampleData> &SampleListModel::items()
{
    return m_items;
}

const QList<SampleData> &SampleListModel::items() const
{
    return m_items;
}

SampleData *SampleListModel::at(int row)
{
    if (row < 0 || row >= m_items.count())
        return nullptr;
    return &m_items[row];
}

const SampleData *SampleListModel::at(int row) const
{
    if (row < 0 || row >= m_items.count())
        return nullptr;
    return &m_items[row];
}

void SampleListModel::reset(QList<SampleData> values)
{
    beginResetModel();
    m_items = std::move(values);
    endResetModel();
}

void SampleListModel::append(const SampleData &sample)
{
    const int row = m_items.count();
    beginInsertRows({}, row, row);
    m_items.append(sample);
    endInsertRows();
}

void SampleListModel::replace(int row, const SampleData &sample)
{
    if (row < 0 || row >= m_items.count())
        return;
    m_items[row] = sample;
    notifyChanged(row);
}

void SampleListModel::removeAt(int row)
{
    if (row < 0 || row >= m_items.count())
        return;
    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
}

void SampleListModel::moveItem(int from, int to)
{
    if (from < 0 || from >= m_items.count() || to < 0 || to >= m_items.count() || from == to)
        return;
    const int destination = from < to ? to + 1 : to;
    beginMoveRows({}, from, from, {}, destination);
    m_items.move(from, to);
    endMoveRows();
}

void SampleListModel::notifyChanged(int row)
{
    if (row < 0 || row >= m_items.count())
        return;
    emit dataChanged(index(row), index(row));
}

void SampleListModel::clear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
}

SlideListModel::SlideListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int SlideListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.count();
}

QVariant SlideListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return {};

    const SlideData &slide = m_items.at(index.row());
    switch (role) {
    case FolderNameRole:
        return slide.folderName;
    case TypeRole:
        return slide.type;
    case CatalogPathRole:
        return slide.catalogPath;
    case CountRole:
        return slide.mediaPaths.count();
    case HasSampleRole:
        return hasAnyMediaCue(slide) || slide.hasSample;
    case SampleNameRole:
        return !firstMediaCueName(slide).isEmpty()
            ? firstMediaCueName(slide)
            : (slide.hasSample ? slide.sample.name : QString());
    case IsSampleNeedRole:
        return slide.isSampleNeed;
    case MediaPathsRole:
        return slide.mediaPaths;
    case MediaSampleNamesRole:
        return mediaCueNames(slide);
    case MediaHasSamplesRole:
        return mediaCueFlags(slide);
    case MediaRepeatsRole:
        return mediaRepeatFlags(slide);
    case FirstMediaUrlRole:
        if (slide.mediaPaths.isEmpty())
            return QString();
        if (isVideoFileName(slide.mediaPaths.first()))
            return QString();
        return QUrl::fromLocalFile(QDir(QCoreApplication::applicationDirPath()).absoluteFilePath(slide.mediaPaths.first())).toString();
    case IsDefaultRole:
        return slide.folderName.isEmpty() && slide.mediaPaths.isEmpty() && !slide.hasSample && slide.catalogPath.isEmpty();
    default:
        return {};
    }
}

QHash<int, QByteArray> SlideListModel::roleNames() const
{
    return {
        {FolderNameRole, "folderName"},
        {TypeRole, "slideType"},
        {CatalogPathRole, "catalogPath"},
        {CountRole, "mediaCount"},
        {HasSampleRole, "hasSample"},
        {SampleNameRole, "sampleName"},
        {IsSampleNeedRole, "isSampleNeed"},
        {MediaPathsRole, "mediaPaths"},
        {MediaSampleNamesRole, "mediaSampleNames"},
        {MediaHasSamplesRole, "mediaHasSamples"},
        {MediaRepeatsRole, "mediaRepeats"},
        {FirstMediaUrlRole, "firstMediaUrl"},
        {IsDefaultRole, "isDefault"}
    };
}

QList<SlideData> &SlideListModel::items()
{
    return m_items;
}

const QList<SlideData> &SlideListModel::items() const
{
    return m_items;
}

SlideData *SlideListModel::at(int row)
{
    if (row < 0 || row >= m_items.count())
        return nullptr;
    return &m_items[row];
}

const SlideData *SlideListModel::at(int row) const
{
    if (row < 0 || row >= m_items.count())
        return nullptr;
    return &m_items[row];
}

void SlideListModel::reset(QList<SlideData> values)
{
    beginResetModel();
    m_items = std::move(values);
    endResetModel();
}

void SlideListModel::append(const SlideData &slide)
{
    const int row = m_items.count();
    beginInsertRows({}, row, row);
    m_items.append(slide);
    endInsertRows();
}

void SlideListModel::replace(int row, const SlideData &slide)
{
    if (row < 0 || row >= m_items.count())
        return;
    m_items[row] = slide;
    notifyChanged(row);
}

void SlideListModel::removeAt(int row)
{
    if (row < 0 || row >= m_items.count())
        return;
    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
}

void SlideListModel::notifyChanged(int row)
{
    if (row < 0 || row >= m_items.count())
        return;
    emit dataChanged(index(row), index(row));
}

void SlideListModel::clear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
}

PreviewListModel::PreviewListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PreviewListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.count();
}

QVariant PreviewListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.count())
        return {};

    const PreviewItem &item = m_items.at(index.row());
    switch (role) {
    case FilePathRole:
        return item.absolutePath;
    case FileNameRole:
        return QFileInfo(item.absolutePath).fileName();
    case FileUrlRole:
        return QUrl::fromLocalFile(item.absolutePath).toString();
    case IsVideoRole:
        return item.isVideo;
    case IsCurrentRole:
        return index.row() == m_currentIndex;
    case IsDimmedRole:
        return item.dimmed;
    default:
        return {};
    }
}

QHash<int, QByteArray> PreviewListModel::roleNames() const
{
    return {
        {FilePathRole, "filePath"},
        {FileNameRole, "fileName"},
        {FileUrlRole, "fileUrl"},
        {IsVideoRole, "isVideo"},
        {IsCurrentRole, "isCurrent"},
        {IsDimmedRole, "isDimmed"}
    };
}

void PreviewListModel::setMedia(const QStringList &mediaPaths, int currentIndex, const QString &basePath)
{
    if (m_items.count() == mediaPaths.count()) {
        bool sameMedia = true;
        for (int i = 0; i < mediaPaths.count(); ++i) {
            if (m_items.at(i).relativePath != mediaPaths.at(i)) {
                sameMedia = false;
                break;
            }
        }
        if (sameMedia) {
            setCurrentIndex(currentIndex);
            return;
        }
    }

    QHash<QString, bool> previousDimmed;
    for (const PreviewItem &existing : std::as_const(m_items))
        previousDimmed.insert(existing.relativePath, existing.dimmed);

    beginResetModel();
    m_items.clear();
    m_currentIndex = currentIndex;
    const QDir base(basePath);
    for (const QString &path : mediaPaths) {
        PreviewItem item;
        item.relativePath = path;
        item.absolutePath = QFileInfo(path).isAbsolute() ? path : base.absoluteFilePath(path);
        item.isVideo = isVideoFileName(item.absolutePath);
        item.dimmed = previousDimmed.value(item.relativePath, false);
        m_items.append(item);
    }
    endResetModel();
}

void PreviewListModel::setCurrentIndex(int currentIndex)
{
    if (m_currentIndex == currentIndex)
        return;
    const int oldIndex = m_currentIndex;
    m_currentIndex = currentIndex;
    if (oldIndex >= 0 && oldIndex < m_items.count())
        emit dataChanged(index(oldIndex), index(oldIndex), {IsCurrentRole});
    if (m_currentIndex >= 0 && m_currentIndex < m_items.count())
        emit dataChanged(index(m_currentIndex), index(m_currentIndex), {IsCurrentRole});
}

void PreviewListModel::dim(int row)
{
    if (row < 0 || row >= m_items.count())
        return;
    m_items[row].dimmed = true;
    emit dataChanged(index(row), index(row), {IsDimmedRole});
}

QString PreviewListModel::absolutePathAt(int row) const
{
    if (row < 0 || row >= m_items.count())
        return {};
    return m_items.at(row).absolutePath;
}

SamplerBackend::SamplerBackend(QObject *parent)
    : QObject(parent)
    , m_licenseManager(this)
{
    updateScreenGeometry();
    connect(qGuiApp, &QGuiApplication::screenAdded, this, &SamplerBackend::updateScreenGeometry);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &SamplerBackend::updateScreenGeometry);

    connect(&m_socket, &QTcpSocket::connected, this, [this]() {
        sendWebSocketHandshake(QUrl("ws://" + m_savedHost));
    });
    connect(&m_socket, &QTcpSocket::disconnected, this, [this]() {
        m_webSocketReady = false;
        m_socketBuffer.clear();
        setStatus("Host disconnected.");
        emit connectionChanged();
    });
    connect(&m_socket, &QTcpSocket::readyRead, this, &SamplerBackend::handleSocketReadyRead);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        m_webSocketReady = false;
        setStatus("Host connection error: " + m_socket.errorString());
        emit connectionChanged();
    });
    connect(&m_licenseManager, &LicenseManager::stateChanged, this, [this]() {
        if (!m_licenseManager.allowed()) {
            stopAllSamples();
            closeStage();
            disconnectHost();
            setSettingsMode(false);
        }
        emit licenseStateChanged();
    });

    loadAll();
    m_licenseManager.setStorageDir(saveDir());
    m_licenseManager.initialize();
}

SamplerBackend::~SamplerBackend()
{
    saveAll();
    stopAllSamples();
    m_socket.close();
}

SampleListModel *SamplerBackend::samples() { return &m_samples; }
SampleListModel *SamplerBackend::fixedSamples() { return &m_fixedSamples; }
SlideListModel *SamplerBackend::quickSlides() { return &m_quickSlides; }
SlideListModel *SamplerBackend::librarySlides() { return &m_librarySlides; }
PreviewListModel *SamplerBackend::previewItems() { return &m_previewItems; }

bool SamplerBackend::settingsMode() const { return m_settingsMode; }
void SamplerBackend::setSettingsMode(bool enabled)
{
    if (m_settingsMode == enabled)
        return;
    m_settingsMode = enabled;
    emit settingsModeChanged();
}

bool SamplerBackend::audioPaused() const { return m_audioPaused; }
bool SamplerBackend::stageActive() const { return m_stageActive; }
QString SamplerBackend::currentMediaUrl() const { return m_currentMediaPath.isEmpty() ? QString() : QUrl::fromLocalFile(m_currentMediaPath).toString(); }
QString SamplerBackend::currentMediaPath() const { return m_currentMediaPath; }
bool SamplerBackend::currentMediaIsVideo() const { return isVideoPath(m_currentMediaPath); }
bool SamplerBackend::currentMediaRepeats() const
{
    const SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || m_currentMediaIndex < 0 || m_currentMediaIndex >= slide->mediaPaths.count())
        return false;
    if (!isVideoPath(slide->mediaPaths.at(m_currentMediaIndex)))
        return false;
    const bool legacyRepeat = QFileInfo(slide->mediaPaths.at(m_currentMediaIndex)).fileName().startsWith("again", Qt::CaseInsensitive);
    return legacyRepeat || (m_currentMediaIndex < slide->mediaCues.count() && slide->mediaCues.at(m_currentMediaIndex).repeats);
}
QString SamplerBackend::nextMediaUrl() const { return m_nextMediaPath.isEmpty() ? QString() : QUrl::fromLocalFile(m_nextMediaPath).toString(); }
QString SamplerBackend::slideCounterText() const
{
    const SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || m_currentMediaIndex < 0 || slide->mediaPaths.isEmpty())
        return "0/0";
    return QString::number(m_currentMediaIndex + 1) + "/" + QString::number(slide->mediaPaths.count());
}
int SamplerBackend::currentSlideIndex() const { return m_currentSlideIndex; }
int SamplerBackend::currentMediaIndex() const { return m_currentMediaIndex; }
bool SamplerBackend::connected() const { return m_socket.state() == QAbstractSocket::ConnectedState && m_webSocketReady; }
QString SamplerBackend::statusMessage() const { return m_statusMessage; }
QString SamplerBackend::savedHost() const { return m_savedHost; }
bool SamplerBackend::licenseAllowed() const { return m_licenseManager.allowed(); }
bool SamplerBackend::licenseBusy() const { return m_licenseManager.busy(); }
QString SamplerBackend::licenseMessage() const { return m_licenseManager.message(); }
QString SamplerBackend::licenseErrorMessage() const { return m_licenseManager.errorMessage(); }
QString SamplerBackend::licenseApiUrl() const { return m_licenseManager.apiUrl(); }
void SamplerBackend::setSavedHost(const QString &host)
{
    if (m_savedHost == host)
        return;
    m_savedHost = host.trimmed();
    emit savedHostChanged();
}
int SamplerBackend::stageX() const { return m_stageX; }
int SamplerBackend::stageY() const { return m_stageY; }
int SamplerBackend::stageWidth() const { return m_stageWidth; }
int SamplerBackend::stageHeight() const { return m_stageHeight; }
QScreen *SamplerBackend::stageScreen() const { return m_stageScreen; }

void SamplerBackend::addSample()
{
    const QString filePath = QFileDialog::getOpenFileName(nullptr, "Select a sample", QString(), "Audio files (*.mp3 *.wav *.m4a *.ogg *.flac)");
    if (filePath.isEmpty())
        return;

    try {
        const int number = m_samples.rowCount() + 1;
        const QString targetPath = copyFileTo(filePath, samplesDir(), fileBaseNameForCopy(filePath), number, false);
        SampleData sample;
        sample.name = QFileInfo(filePath).completeBaseName();
        sample.path = storagePath(targetPath);
        sample.duration = probeDuration(targetPath);
        m_samples.append(sample);
        saveSamples();
        setStatus("Sample added.");
    } catch (const std::exception &e) {
        setStatus("Sample add failed: " + QString::fromUtf8(e.what()));
    }
}

void SamplerBackend::playSample(int index, bool advanceSlide)
{
    if (m_settingsMode)
        return;
    if (startPlayback(&m_samples, index, true) && advanceSlide)
        nextSlide();
}

void SamplerBackend::stopSample(int index)
{
    removeActiveFor(&m_samples, index);
}

void SamplerBackend::stopAllSamples()
{
    while (!m_activePlaybacks.isEmpty())
        cleanupPlaybackEntry(m_activePlaybacks.count() - 1, true);
}

void SamplerBackend::togglePause()
{
    m_audioPaused = !m_audioPaused;
    for (const ActivePlayback &active : std::as_const(m_activePlaybacks)) {
        if (!active.player)
            continue;
        if (m_audioPaused)
            active.player->pause();
        else
            active.player->play();
    }
    emit audioPausedChanged();
}

void SamplerBackend::updateSample(int index, const QString &name, double volume, bool stopSounds, const QString &color)
{
    SampleData *sample = m_samples.at(index);
    if (!sample)
        return;
    sample->name = name.trimmed().isEmpty() ? sample->name : name.trimmed();
    sample->volume = qBound(0.0, volume, 1.0);
    sample->stopSounds = stopSounds;
    QColor parsed(color);
    if (parsed.isValid())
        sample->color = parsed;
    m_samples.notifyChanged(index);
    saveSamples();
}

void SamplerBackend::changeSampleFile(int index)
{
    SampleData *sample = m_samples.at(index);
    if (!sample)
        return;
    const QString filePath = QFileDialog::getOpenFileName(nullptr, "Choose replacement", QString(), "Audio files (*.mp3 *.wav *.m4a *.ogg *.flac)");
    if (filePath.isEmpty())
        return;

    try {
        const QString old = absolutePath(sample->path);
        const QString targetPath = copyFileTo(filePath, samplesDir(), fileBaseNameForCopy(filePath), QDateTime::currentMSecsSinceEpoch() % 100000, false);
        sample->path = storagePath(targetPath);
        sample->duration = probeDuration(targetPath);
        if (sample->name.trimmed().isEmpty())
            sample->name = QFileInfo(filePath).completeBaseName();
        if (!old.isEmpty() && QDir::cleanPath(old) != QDir::cleanPath(targetPath))
            cleanupStoredFile(storagePath(old));
        m_samples.notifyChanged(index);
        saveSamples();
        setStatus("Sample file replaced.");
    } catch (const std::exception &e) {
        setStatus("Sample replace failed: " + QString::fromUtf8(e.what()));
    }
}

void SamplerBackend::deleteSample(int index)
{
    const SampleData *sample = m_samples.at(index);
    if (!sample)
        return;
    const QString path = sample->path;
    removeActiveFor(&m_samples, index);
    cleanupStoredFile(path);
    m_samples.removeAt(index);
    reindexActiveRowsAfterRemoval(&m_samples, index);
    saveSamples();
}

void SamplerBackend::moveSample(int from, int to)
{
    if (from < 0 || from >= m_samples.rowCount() || to < 0 || to >= m_samples.rowCount() || from == to)
        return;
    m_samples.moveItem(from, to);
    reindexActiveRowsAfterMove(&m_samples, from, to);
    saveSamples();
}

void SamplerBackend::playFixedSample(int index, bool advanceSlide)
{
    if (m_settingsMode) {
        replaceFixedSample(index);
        return;
    }
    if (startPlayback(&m_fixedSamples, index, true)) {
        if (index == 1)
            sendHostMessage("RIGHT");
        if (index == 2)
            sendHostMessage("WRONG");
        if (advanceSlide)
            nextSlide();
    }
}

void SamplerBackend::replaceFixedSample(int index)
{
    SampleData *sample = m_fixedSamples.at(index);
    if (!sample)
        return;
    const QString filePath = QFileDialog::getOpenFileName(nullptr, "Choose fixed cue", QString(), "Audio files (*.mp3 *.wav *.m4a *.ogg *.flac)");
    if (filePath.isEmpty())
        return;

    try {
        const QString old = absolutePath(sample->path);
        const QString targetPath = copyFileTo(filePath, samplesDir(), QString::number(index + 1) + "fixed-sample", 0, false);
        sample->path = storagePath(targetPath);
        sample->duration = probeDuration(targetPath);
        sample->name = index == 0 ? "P1" : index == 1 ? "OK" : index == 2 ? "NO" : "Timer";
        if (!old.isEmpty() && QDir::cleanPath(old) != QDir::cleanPath(targetPath))
            cleanupStoredFile(storagePath(old));
        m_fixedSamples.notifyChanged(index);
        saveSamples();
        setStatus("Cue replaced.");
    } catch (const std::exception &e) {
        setStatus("Cue replace failed: " + QString::fromUtf8(e.what()));
    }
}

void SamplerBackend::playQuickSlide(int index)
{
    SlideData *slide = m_quickSlides.at(index);
    if (!slide)
        return;
    if (isDefaultSlide(*slide)) {
        setStatus("Quick slide slot is empty. Assign a slide first.");
        return;
    }
    if (!hasSecondScreen())
        setStatus("Second monitor was not found; stage opens on the main screen.");

    m_currentSlideIndex = index;
    m_currentMediaIndex = 0;
    m_stageActive = true;
    syncStageToCurrentSlide();
}

void SamplerBackend::assignQuickSlide(int quickIndex, int libraryIndex)
{
    const SlideData *slide = m_librarySlides.at(libraryIndex);
    if (!slide || quickIndex < 0 || quickIndex >= m_quickSlides.rowCount())
        return;
    m_quickSlides.replace(quickIndex, copySlide(*slide));
    syncStageToCurrentSlide();
    saveQuickSlides();
}

void SamplerBackend::clearQuickSlide(int quickIndex)
{
    if (quickIndex < 0 || quickIndex >= m_quickSlides.rowCount())
        return;
    m_quickSlides.replace(quickIndex, createDefaultSlide());
    syncStageToCurrentSlide();
    saveQuickSlides();
}

void SamplerBackend::nextSlide()
{
    SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || m_currentMediaIndex + 1 >= slide->mediaPaths.count())
        return;
    ++m_currentMediaIndex;
    showSlideMedia();
}

void SamplerBackend::previousSlide()
{
    SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || m_currentMediaIndex <= 0)
        return;
    --m_currentMediaIndex;
    showSlideMedia();
}

void SamplerBackend::playPreviewMedia(int previewIndex, int action)
{
    SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || previewIndex < 0 || previewIndex >= slide->mediaPaths.count())
        return;
    m_currentMediaIndex = previewIndex;
    m_previewItems.dim(previewIndex);
    showSlideMedia();
    if (action == 1 && m_samples.rowCount() > 0)
        startPlayback(&m_samples, 0, true);
    else if (action == 2)
        startPlayback(&m_fixedSamples, 1, true);
}

void SamplerBackend::closeStage()
{
    m_stageActive = false;
    m_currentSlideIndex = -1;
    m_currentMediaIndex = -1;
    m_currentMediaPath.clear();
    m_nextMediaPath.clear();
    m_previewItems.setMedia({}, -1, baseDir());
    emit stageChanged();
}

void SamplerBackend::createLibrarySlide()
{
    QString name = uniqueSlideName();
    QDir dir(baseDir());
    const QString relativeCatalog = "Content/" + name;
    if (!dir.mkpath(relativeCatalog)) {
        setStatus("Could not create slide folder.");
        return;
    }
    SlideData slide;
    slide.folderName = name;
    slide.catalogPath = relativeCatalog;
    slide.type = "Default";
    m_librarySlides.append(slide);
    saveSlides();
}

void SamplerBackend::updateLibrarySlide(int index, const QString &folderName, const QString &type)
{
    SlideData *slide = m_librarySlides.at(index);
    if (!slide)
        return;

    QString cleaned = cleanFolderName(folderName);
    if (cleaned.isEmpty())
        cleaned = "Slide";

    QString oldCatalog = slide->catalogPath;
    QString newCatalog = "Content/" + cleaned;
    QDir base(baseDir());

    if (!oldCatalog.isEmpty() && oldCatalog != newCatalog) {
        QString candidate = newCatalog;
        while (QDir(base.absoluteFilePath(candidate)).exists() && candidate != oldCatalog)
            candidate += "_";
        newCatalog = candidate;
        cleaned = QFileInfo(newCatalog).fileName();
        if (QDir(base.absoluteFilePath(oldCatalog)).exists()
            && !QDir().rename(base.absoluteFilePath(oldCatalog), base.absoluteFilePath(newCatalog))) {
            setStatus("Could not rename slide folder.");
            return;
        }
    }

    slide->folderName = cleaned;
    slide->type = type.trimmed().isEmpty() ? "Default" : type.trimmed();
    slide->catalogPath = newCatalog;
    for (QString &mediaPath : slide->mediaPaths)
        mediaPath = newCatalog + "/" + QFileInfo(mediaPath).fileName();
    for (SlideData::MediaCue &cue : slide->mediaCues) {
        if (cue.hasSample)
            cue.sample.path = newCatalog + "/" + QFileInfo(cue.sample.path).fileName();
    }
    if (!slide->sample.path.isEmpty())
        slide->sample.path = newCatalog + "/" + QFileInfo(slide->sample.path).fileName();
    slide->hasSample = hasAnyMediaCue(*slide);
    slide->isSampleNeed = slide->hasSample;

    m_librarySlides.notifyChanged(index);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
}

void SamplerBackend::deleteLibrarySlide(int index)
{
    const SlideData *slide = m_librarySlides.at(index);
    if (!slide)
        return;
    const QString catalog = absolutePath(slide->catalogPath);
    if (!catalog.isEmpty()
        && isManagedPath(catalog)
        && QDir::cleanPath(catalog) != QDir::cleanPath(contentDir()))
        QDir(catalog).removeRecursively();
    m_librarySlides.removeAt(index);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
}

void SamplerBackend::addMediaToLibrarySlide(int index)
{
    SlideData *slide = m_librarySlides.at(index);
    if (!slide)
        return;
    const QStringList files = QFileDialog::getOpenFileNames(nullptr, "Choose slide media", QString(), "Media files (*.jpg *.jpeg *.png *.bmp *.mp4 *.avi *.mov *.wmv *.m4v *.mkv *.webm)");
    if (files.isEmpty())
        return;

    const QString targetFolder = absolutePath(slide->catalogPath);
    QDir().mkpath(targetFolder);
    QStringList copiedFiles;
    QStringList newPaths;
    try {
        int i = slide->mediaPaths.count() + 1;
        for (const QString &file : files) {
            const QString copied = copyFileTo(file, targetFolder, fileBaseNameForCopy(file), i++, false);
            copiedFiles.append(QDir::cleanPath(copied));
            newPaths.append(storagePath(copied));
        }
    } catch (const std::exception &e) {
        for (const QString &copied : copiedFiles)
            QFile::remove(copied);
        setStatus("Slide media update failed: " + QString::fromUtf8(e.what()));
        return;
    }

    for (const QString &path : newPaths) {
        slide->mediaPaths.append(path);
        slide->mediaCues.append(SlideData::MediaCue{});
    }
    ensureMediaCueCount(*slide);
    m_librarySlides.notifyChanged(index);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
    setStatus("Slide media added.");
}

void SamplerBackend::addSampleToLibrarySlide(int index)
{
    SlideData *slide = m_librarySlides.at(index);
    if (!slide)
        return;
    if (!slide->mediaPaths.isEmpty()) {
        addSampleToLibrarySlideMedia(index, 0);
        return;
    }
    setStatus("Add media before adding a cue.");
}

void SamplerBackend::moveLibrarySlideMedia(int slideIndex, int from, int to)
{
    SlideData *slide = m_librarySlides.at(slideIndex);
    if (!slide || from < 0 || from >= slide->mediaPaths.count() || to < 0 || to >= slide->mediaPaths.count() || from == to)
        return;
    ensureMediaCueCount(*slide);
    slide->mediaPaths.move(from, to);
    slide->mediaCues.move(from, to);
    m_librarySlides.notifyChanged(slideIndex);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
}

void SamplerBackend::deleteLibrarySlideMedia(int slideIndex, int mediaIndex)
{
    SlideData *slide = m_librarySlides.at(slideIndex);
    if (!slide || mediaIndex < 0 || mediaIndex >= slide->mediaPaths.count())
        return;
    ensureMediaCueCount(*slide);
    cleanupStoredFile(slide->mediaPaths.takeAt(mediaIndex));
    const SlideData::MediaCue cue = slide->mediaCues.takeAt(mediaIndex);
    if (cue.hasSample)
        cleanupStoredFile(cue.sample.path);
    ensureMediaCueCount(*slide);
    m_librarySlides.notifyChanged(slideIndex);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
    setStatus("Slide media removed.");
}

void SamplerBackend::addSampleToLibrarySlideMedia(int slideIndex, int mediaIndex)
{
    SlideData *slide = m_librarySlides.at(slideIndex);
    if (!slide || mediaIndex < 0 || mediaIndex >= slide->mediaPaths.count())
        return;
    const QString filePath = QFileDialog::getOpenFileName(nullptr, "Choose slide sample", QString(), "Audio files (*.mp3 *.wav *.m4a *.ogg *.flac)");
    if (filePath.isEmpty())
        return;

    const QString targetFolder = absolutePath(slide->catalogPath);
    QDir().mkpath(targetFolder);
    try {
        ensureMediaCueCount(*slide);
        SlideData::MediaCue &cue = slide->mediaCues[mediaIndex];
        const QString old = cue.hasSample ? cue.sample.path : QString();
        const QString mediaBase = QFileInfo(slide->mediaPaths.at(mediaIndex)).completeBaseName();
        const QString copied = copyFileTo(filePath, targetFolder, mediaBase + "-cue", mediaIndex + 1, false);
        cue.sample = SampleData();
        cue.sample.name = QFileInfo(filePath).completeBaseName();
        cue.sample.path = storagePath(copied);
        cue.sample.duration = probeDuration(copied);
        cue.hasSample = true;
        slide->hasSample = true;
        slide->isSampleNeed = true;
        if (!old.isEmpty() && QDir::cleanPath(absolutePath(old)) != QDir::cleanPath(copied))
            cleanupStoredFile(old);
        m_librarySlides.notifyChanged(slideIndex);
        refreshAssignedSlides();
        saveSlides();
        saveQuickSlides();
        setStatus("Media cue updated.");
    } catch (const std::exception &e) {
        setStatus("Media cue update failed: " + QString::fromUtf8(e.what()));
    }
}

void SamplerBackend::clearSampleFromLibrarySlideMedia(int slideIndex, int mediaIndex)
{
    SlideData *slide = m_librarySlides.at(slideIndex);
    if (!slide || mediaIndex < 0 || mediaIndex >= slide->mediaPaths.count())
        return;
    ensureMediaCueCount(*slide);
    SlideData::MediaCue &cue = slide->mediaCues[mediaIndex];
    if (!cue.hasSample)
        return;
    const bool repeats = cue.repeats;
    cleanupStoredFile(cue.sample.path);
    cue = {};
    cue.repeats = repeats;
    slide->hasSample = hasAnyMediaCue(*slide);
    slide->isSampleNeed = slide->hasSample;
    m_librarySlides.notifyChanged(slideIndex);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
    setStatus("Media cue removed.");
}

void SamplerBackend::setLibrarySlideMediaRepeats(int slideIndex, int mediaIndex, bool repeats)
{
    SlideData *slide = m_librarySlides.at(slideIndex);
    if (!slide || mediaIndex < 0 || mediaIndex >= slide->mediaPaths.count())
        return;
    ensureMediaCueCount(*slide);
    if (!isVideoPath(slide->mediaPaths.at(mediaIndex)))
        repeats = false;
    if (slide->mediaCues[mediaIndex].repeats == repeats)
        return;
    slide->mediaCues[mediaIndex].repeats = repeats;
    m_librarySlides.notifyChanged(slideIndex);
    refreshAssignedSlides();
    saveSlides();
    saveQuickSlides();
    emit stageChanged();
    setStatus(repeats ? "Video repeat enabled." : "Video repeat disabled.");
}

void SamplerBackend::openLibraryFolder(int index)
{
    const SlideData *slide = m_librarySlides.at(index);
    if (!slide)
        return;
    QDesktopServices::openUrl(QUrl::fromLocalFile(absolutePath(slide->catalogPath)));
}

void SamplerBackend::openDataFolder()
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(baseDir()));
}

void SamplerBackend::saveAll()
{
    saveSamples();
    saveSlides();
    saveQuickSlides();
}

void SamplerBackend::activateLicense(const QString &licenseKey)
{
    m_licenseManager.activate(licenseKey);
}

void SamplerBackend::retryLicenseCheck()
{
    m_licenseManager.checkNow();
}

void SamplerBackend::openPurchasePage()
{
    QDesktopServices::openUrl(QUrl("https://bostoncrew.ru"));
}

void SamplerBackend::connectHost(const QString &host)
{
    const QString trimmed = host.trimmed();
    if (trimmed.isEmpty()) {
        setStatus("Enter host as 192.168.4.15:81.");
        return;
    }
    m_savedHost = trimmed;
    emit savedHostChanged();
    QUrl url("ws://" + trimmed);
    if (url.host().isEmpty()) {
        setStatus("Invalid host address.");
        return;
    }
    m_webSocketReady = false;
    m_socketBuffer.clear();
    m_socket.close();
    m_socket.connectToHost(url.host(), url.port(80));
    setStatus("Connecting to host...");
}

void SamplerBackend::disconnectHost()
{
    m_socket.close();
}

void SamplerBackend::sendHostMessage(const QString &message)
{
    if (connected())
    sendWebSocketText(message);
}

void SamplerBackend::toggleStageVideoPause()
{
    emit stageVideoPauseRequested();
}

void SamplerBackend::restartStageVideo()
{
    emit stageVideoRestartRequested();
}

QString SamplerBackend::absolutePath(const QString &storedPath) const
{
    if (storedPath.trimmed().isEmpty())
        return {};
    QFileInfo info(storedPath);
    if (info.isAbsolute())
        return QDir::cleanPath(storedPath);
    return QDir(baseDir()).absoluteFilePath(normalizedRelative(storedPath));
}

QString SamplerBackend::urlForPath(const QString &storedPath) const
{
    const QString path = absolutePath(storedPath);
    return path.isEmpty() ? QString() : QUrl::fromLocalFile(path).toString();
}

bool SamplerBackend::isVideoPath(const QString &path) const
{
    return isVideoExtension(path);
}

bool SamplerBackend::hasSecondScreen() const
{
    return QGuiApplication::screens().count() > 1;
}

QString SamplerBackend::baseDir() const
{
    return QCoreApplication::applicationDirPath();
}

QString SamplerBackend::saveDir() const
{
    return QDir(baseDir()).absoluteFilePath("SaveData");
}

QString SamplerBackend::samplesDir() const
{
    return QDir(baseDir()).absoluteFilePath("Samples");
}

QString SamplerBackend::contentDir() const
{
    return QDir(baseDir()).absoluteFilePath("Content");
}

QString SamplerBackend::storagePath(const QString &path) const
{
    if (path.trimmed().isEmpty())
        return {};
    const QString cleaned = QDir::cleanPath(path);
    const QString base = QDir::cleanPath(baseDir());
    if (cleaned.startsWith(base, Qt::CaseInsensitive))
        return normalizedRelative(QDir(base).relativeFilePath(cleaned));
    return normalizedRelative(cleaned);
}

bool SamplerBackend::isManagedPath(const QString &path) const
{
    if (path.trimmed().isEmpty())
        return false;
    const QString base = QDir::cleanPath(baseDir());
    const QFileInfo info(path);
    const QString absolute = QDir::cleanPath(info.isAbsolute()
        ? path
        : QDir(baseDir()).absoluteFilePath(path));
    return absolute.startsWith(base + "/", Qt::CaseInsensitive);
}

void SamplerBackend::cleanupStoredFile(const QString &storedPath) const
{
    const QString absolute = absolutePath(storedPath);
    if (!absolute.isEmpty() && isManagedPath(absolute) && QFileInfo(absolute).isFile())
        QFile::remove(absolute);
}

QString SamplerBackend::cleanFolderName(const QString &name) const
{
    QString cleaned = name.trimmed();
    cleaned.replace(QRegularExpression("[\\\\/:*?\"<>|\\s]+"), "_");
    cleaned.replace(QRegularExpression("_+"), "_");
    cleaned = cleaned.trimmed();
    if (cleaned == "." || cleaned == "..")
        cleaned = "Slide";
    return cleaned;
}

QString SamplerBackend::uniqueSlideName() const
{
    int index = m_librarySlides.rowCount() + 1;
    QDir content(contentDir());
    while (true) {
        const QString name = "NewSlide_" + QString::number(index);
        const bool inModel = std::any_of(m_librarySlides.items().cbegin(), m_librarySlides.items().cend(), [&name](const SlideData &slide) {
            return slide.folderName.compare(name, Qt::CaseInsensitive) == 0;
        });
        if (!content.exists(name) && !inModel)
            return name;
        ++index;
    }
}

QString SamplerBackend::uniqueFileName(const QString &directory, const QString &baseName, const QString &extension, int index) const
{
    QString safeBase = cleanFolderName(baseName);
    if (safeBase.isEmpty())
        safeBase = "file";
    QString ext = extension.startsWith('.') ? extension : "." + extension;
    QString fileName = index > 0 ? QString("%1-%2%3").arg(safeBase).arg(index).arg(ext) : safeBase + ext;
    int suffix = 1;
    while (QFile::exists(QDir(directory).absoluteFilePath(fileName))) {
        fileName = QString("%1-%2-%3%4").arg(safeBase).arg(index).arg(suffix++).arg(ext);
    }
    return fileName;
}

QString SamplerBackend::copyFileTo(const QString &sourcePath, const QString &directory, const QString &baseName, int index, bool forceMp3Name)
{
    QDir().mkpath(directory);
    QString extension = QFileInfo(sourcePath).suffix();
    if (extension.isEmpty())
        extension = "dat";

    const QString ffmpeg = QDir(baseDir()).absoluteFilePath("ffmpeg/ffmpeg.exe");
    const bool canTranscode = forceMp3Name && QFile::exists(ffmpeg);
    if (canTranscode)
        extension = "mp3";

    const QString fileName = uniqueFileName(directory, baseName, extension, index);
    const QString targetPath = QDir(directory).absoluteFilePath(fileName);

    if (canTranscode) {
        QProcess process;
        process.start(ffmpeg, {"-y", "-i", sourcePath, targetPath});
        if (!process.waitForFinished(15000) || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
            throw std::runtime_error("ffmpeg conversion failed");
    } else if (!QFile::copy(sourcePath, targetPath)) {
        throw std::runtime_error("file copy failed");
    }
    return targetPath;
}

double SamplerBackend::probeDuration(const QString &path) const
{
    const QString ffprobe = QDir(baseDir()).absoluteFilePath("ffmpeg/ffprobe.exe");
    if (!QFile::exists(ffprobe))
        return 0.0;
    QProcess process;
    process.start(ffprobe, {"-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path});
    if (!process.waitForFinished(2000))
        return 0.0;
    bool ok = false;
    const double duration = QString::fromUtf8(process.readAllStandardOutput()).trimmed().toDouble(&ok);
    return ok ? duration : 0.0;
}

bool SamplerBackend::isDefaultSlide(const SlideData &slide)
{
    return slide.folderName.isEmpty() && slide.mediaPaths.isEmpty() && !slide.hasSample && !slide.isSampleNeed && slide.catalogPath.isEmpty();
}

bool SamplerBackend::isVideoExtension(const QString &path)
{
    const QString ext = QFileInfo(path).suffix().toLower();
    return QStringList({"mp4", "avi", "wmv", "mov", "m4v", "mkv", "webm", "flv"}).contains(ext);
}

bool SamplerBackend::isImageExtension(const QString &path)
{
    const QString ext = QFileInfo(path).suffix().toLower();
    return QStringList({"jpg", "jpeg", "png", "bmp"}).contains(ext);
}

QString SamplerBackend::durationText(double seconds)
{
    const int total = qMax(0, qRound(seconds));
    return QString("%1:%2").arg(total / 60, 2, 10, QLatin1Char('0')).arg(total % 60, 2, 10, QLatin1Char('0'));
}

QJsonObject SamplerBackend::sampleToJson(const SampleData &sample)
{
    return {
        {"sampleName", sample.name},
        {"samplePath", normalizedRelative(sample.path)},
        {"isPlaying", false},
        {"duration", sample.duration},
        {"sampleVolume", sample.volume},
        {"sampleStopSounds", sample.stopSounds},
        {"foreColor", sample.color.name(QColor::HexRgb)}
    };
}

SampleData SamplerBackend::sampleFromJson(const QJsonObject &object)
{
    SampleData sample;
    sample.name = object.value("sampleName").toString();
    sample.path = normalizedRelative(object.value("samplePath").toString());
    sample.duration = object.value("duration").toDouble();
    sample.volume = object.contains("sampleVolume") ? object.value("sampleVolume").toDouble(1.0) : 1.0;
    sample.stopSounds = object.value("sampleStopSounds").toBool(false);
    sample.isPlaying = false;
    const QJsonValue colorValue = object.value("foreColor");
    if (colorValue.isString()) {
        QColor color(colorValue.toString());
        if (color.isValid())
            sample.color = color;
    } else if (colorValue.isObject()) {
        const QString colorText = colorValue.toObject().value("Color").toString();
        QColor color(colorText);
        if (color.isValid())
            sample.color = color;
    }
    return sample;
}

QJsonObject SamplerBackend::slideToJson(const SlideData &slide)
{
    QJsonArray media;
    for (const QString &path : slide.mediaPaths)
        media.append(normalizedRelative(path));

    QJsonArray mediaSamples;
    QJsonArray mediaRepeats;
    for (int i = 0; i < slide.mediaPaths.count(); ++i) {
        if (i < slide.mediaCues.count() && slide.mediaCues.at(i).hasSample)
            mediaSamples.append(sampleToJson(slide.mediaCues.at(i).sample));
        else
            mediaSamples.append(QJsonValue::Null);
        mediaRepeats.append(i < slide.mediaCues.count() && slide.mediaCues.at(i).repeats && isVideoFileName(slide.mediaPaths.at(i)));
    }

    QJsonObject object{
        {"FolderName", slide.folderName},
        {"MediaPaths", media},
        {"MediaSamples", mediaSamples},
        {"MediaRepeats", mediaRepeats},
        {"IsSampleNeed", hasAnyMediaCue(slide)},
        {"Count", slide.mediaPaths.count()},
        {"Type", slide.type},
        {"CatalogPath", normalizedRelative(slide.catalogPath)}
    };
    object.insert("Sample", QJsonValue::Null);
    return object;
}

SlideData SamplerBackend::slideFromJson(const QJsonObject &object)
{
    SlideData slide;
    slide.folderName = object.value("FolderName").toString();
    slide.type = object.value("Type").toString("Default");
    slide.catalogPath = normalizedRelative(object.value("CatalogPath").toString());
    slide.isSampleNeed = object.value("IsSampleNeed").toBool(false);
    const QJsonArray media = object.value("MediaPaths").toArray();
    for (const QJsonValue &value : media)
        slide.mediaPaths.append(normalizedRelative(value.toString()));

    const QJsonArray mediaSamples = object.value("MediaSamples").toArray();
    const QJsonArray mediaRepeats = object.value("MediaRepeats").toArray();
    for (int i = 0; i < slide.mediaPaths.count(); ++i) {
        SlideData::MediaCue cue;
        if (i < mediaSamples.count() && mediaSamples.at(i).isObject()) {
            cue.sample = sampleFromJson(mediaSamples.at(i).toObject());
            cue.hasSample = !cue.sample.path.isEmpty();
        }
        const bool legacyRepeat = isVideoFileName(slide.mediaPaths.at(i))
            && QFileInfo(slide.mediaPaths.at(i)).fileName().startsWith("again", Qt::CaseInsensitive);
        cue.repeats = legacyRepeat || (i < mediaRepeats.count() && mediaRepeats.at(i).toBool(false));
        slide.mediaCues.append(cue);
    }

    if (object.value("Sample").isObject()) {
        SampleData legacySample = sampleFromJson(object.value("Sample").toObject());
        if (!legacySample.path.isEmpty() && !slide.mediaPaths.isEmpty()) {
            while (slide.mediaCues.count() < slide.mediaPaths.count())
                slide.mediaCues.append(SlideData::MediaCue{});
            if (!slide.mediaCues[0].hasSample) {
                slide.mediaCues[0].sample = legacySample;
                slide.mediaCues[0].hasSample = true;
            }
        } else {
            slide.sample = legacySample;
            slide.hasSample = !slide.sample.path.isEmpty();
        }
    }
    while (slide.mediaCues.count() < slide.mediaPaths.count())
        slide.mediaCues.append(SlideData::MediaCue{});
    while (slide.mediaCues.count() > slide.mediaPaths.count())
        slide.mediaCues.removeLast();
    slide.hasSample = slide.hasSample || hasAnyMediaCue(slide);
    slide.isSampleNeed = slide.hasSample;
    return slide;
}

QJsonDocument SamplerBackend::readJsonDocument(const QString &path) const
{
    const QStringList candidates = {path, path + ".bak"};
    for (const QString &candidate : candidates) {
        QFile file(candidate);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        QJsonParseError error;
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &error);
        if (error.error == QJsonParseError::NoError)
            return doc;
    }
    return {};
}

void SamplerBackend::writeJsonDocument(const QString &path, const QJsonDocument &document) const
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    const QByteArray payload = document.toJson(QJsonDocument::Indented);
    const QString backupPath = path + ".bak";
    const QString backupTempPath = backupPath + ".tmp";

    QFile::remove(backupTempPath);
    if (QFile::exists(path))
        QFile::copy(path, backupTempPath);

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QFile::remove(backupTempPath);
        return;
    }

    if (file.write(payload) != payload.size() || !file.commit()) {
        QFile::remove(backupTempPath);
        return;
    }

    if (QFile::exists(backupTempPath)) {
        QFile::remove(backupPath);
        QFile::rename(backupTempPath, backupPath);
    }
}

void SamplerBackend::loadAll()
{
    QDir().mkpath(saveDir());
    QDir().mkpath(samplesDir());
    QDir().mkpath(contentDir());
    m_savedHost = loadHost();
    emit savedHostChanged();
    loadSamples();
    loadSlides();
    loadQuickSlides();
}

void SamplerBackend::loadSamples()
{
    QList<SampleData> loadedSamples;
    const QJsonDocument sampleDoc = readJsonDocument(QDir(saveDir()).absoluteFilePath("samples.json"));
    if (sampleDoc.isArray()) {
        for (const QJsonValue &value : sampleDoc.array()) {
            if (!value.isObject())
                continue;
            SampleData sample = sampleFromJson(value.toObject());
            const QString path = absolutePath(sample.path);
            if (!path.isEmpty() && isManagedPath(path) && QFile::exists(path))
                loadedSamples.append(sample);
        }
    }
    m_samples.reset(loadedSamples);

    QList<SampleData> fixed;
    for (int i = 0; i < 4; ++i) {
        SampleData sample;
        sample.name = i == 0 ? "P1" : i == 1 ? "OK" : i == 2 ? "NO" : "Timer";
        sample.path = QString("Samples/%1fixed-sample.mp3").arg(i + 1);
        fixed.append(sample);
    }
    const QJsonDocument fixedDoc = readJsonDocument(QDir(saveDir()).absoluteFilePath("fixedsamples.json"));
    if (fixedDoc.isArray()) {
        const QJsonArray array = fixedDoc.array();
        for (int i = 0; i < fixed.count() && i < array.count(); ++i) {
            if (array.at(i).isObject()) {
                SampleData parsed = sampleFromJson(array.at(i).toObject());
                if (!parsed.name.isEmpty())
                    fixed[i].name = parsed.name;
                const QString parsedPath = absolutePath(parsed.path);
                if (!parsed.path.isEmpty() && isManagedPath(parsedPath) && QFile::exists(parsedPath))
                    fixed[i].path = parsed.path;
                fixed[i].duration = parsed.duration;
                fixed[i].volume = parsed.volume;
                fixed[i].stopSounds = parsed.stopSounds;
                fixed[i].color = parsed.color;
            }
        }
    }
    m_fixedSamples.reset(fixed);
}

void SamplerBackend::loadSlides()
{
    QList<SlideData> slides;
    const QJsonDocument doc = readJsonDocument(QDir(saveDir()).absoluteFilePath("slides.json"));
    if (doc.isArray()) {
        for (const QJsonValue &value : doc.array()) {
            if (!value.isObject())
                continue;
            SlideData slide = slideFromJson(value.toObject());
            if (isSlideValid(slide))
                slides.append(slide);
        }
    }
    m_librarySlides.reset(slides);
}

void SamplerBackend::loadQuickSlides()
{
    QList<SlideData> slides;
    const QJsonDocument doc = readJsonDocument(QDir(saveDir()).absoluteFilePath("eightslides.json"));
    if (doc.isArray()) {
        const QJsonArray array = doc.array();
        for (int i = 0; i < QuickSlideCount; ++i) {
            if (i < array.count() && array.at(i).isObject()) {
                SlideData slide = slideFromJson(array.at(i).toObject());
                slides.append(isSlideValid(slide) ? copySlide(slide) : createDefaultSlide());
            } else {
                slides.append(createDefaultSlide());
            }
        }
    } else {
        for (int i = 0; i < QuickSlideCount; ++i)
            slides.append(createDefaultSlide());
    }
    m_quickSlides.reset(slides);
}

void SamplerBackend::saveSamples() const
{
    QJsonArray samples;
    for (const SampleData &sample : m_samples.items())
        samples.append(sampleToJson(sample));
    writeJsonDocument(QDir(saveDir()).absoluteFilePath("samples.json"), QJsonDocument(samples));

    QJsonArray fixed;
    for (const SampleData &sample : m_fixedSamples.items())
        fixed.append(sampleToJson(sample));
    writeJsonDocument(QDir(saveDir()).absoluteFilePath("fixedsamples.json"), QJsonDocument(fixed));
}

void SamplerBackend::saveSlides() const
{
    QJsonArray slides;
    for (const SlideData &slide : m_librarySlides.items())
        slides.append(slideToJson(slide));
    writeJsonDocument(QDir(saveDir()).absoluteFilePath("slides.json"), QJsonDocument(slides));
}

void SamplerBackend::saveQuickSlides() const
{
    QJsonArray slides;
    for (const SlideData &slide : m_quickSlides.items())
        slides.append(slideToJson(slide));
    writeJsonDocument(QDir(saveDir()).absoluteFilePath("eightslides.json"), QJsonDocument(slides));
}

void SamplerBackend::refreshAssignedSlides()
{
    for (int i = 0; i < m_quickSlides.rowCount(); ++i) {
        SlideData *assigned = m_quickSlides.at(i);
        if (!assigned || isDefaultSlide(*assigned))
            continue;
        auto it = std::find_if(m_librarySlides.items().cbegin(), m_librarySlides.items().cend(), [assigned](const SlideData &slide) {
            return slide.catalogPath.compare(assigned->catalogPath, Qt::CaseInsensitive) == 0
                || slide.folderName.compare(assigned->folderName, Qt::CaseInsensitive) == 0;
        });
        m_quickSlides.replace(i, it != m_librarySlides.items().cend() && isSlideValid(*it) ? copySlide(*it) : createDefaultSlide());
    }
    syncStageToCurrentSlide();
}

bool SamplerBackend::isSlideValid(const SlideData &slide) const
{
    if (isDefaultSlide(slide))
        return true;
    if (slide.catalogPath.isEmpty())
        return false;
    const QString catalog = absolutePath(slide.catalogPath);
    if (!isManagedPath(catalog) || !QDir(catalog).exists())
        return false;
    if (!slide.folderName.isEmpty() && QFileInfo(catalog).fileName().compare(slide.folderName, Qt::CaseInsensitive) != 0)
        return false;
    for (const QString &path : slide.mediaPaths) {
        const QString absolute = absolutePath(path);
        if (!isManagedPath(absolute) || !QFile::exists(absolute))
            return false;
    }
    if (slide.hasSample && !slide.sample.path.isEmpty()) {
        const QString absolute = absolutePath(slide.sample.path);
        if (!isManagedPath(absolute) || !QFile::exists(absolute))
            return false;
    }
    for (const SlideData::MediaCue &cue : slide.mediaCues) {
        if (!cue.hasSample)
            continue;
        const QString absolute = absolutePath(cue.sample.path);
        if (!isManagedPath(absolute) || !QFile::exists(absolute))
            return false;
    }
    return true;
}

SlideData SamplerBackend::createDefaultSlide() const
{
    return {};
}

SlideData SamplerBackend::copySlide(const SlideData &slide) const
{
    return slide;
}

void SamplerBackend::ensureMediaCueCount(SlideData &slide) const
{
    while (slide.mediaCues.count() < slide.mediaPaths.count())
        slide.mediaCues.append(SlideData::MediaCue{});
    while (slide.mediaCues.count() > slide.mediaPaths.count()) {
        const SlideData::MediaCue cue = slide.mediaCues.takeLast();
        if (cue.hasSample)
            cleanupStoredFile(cue.sample.path);
    }
    slide.hasSample = hasAnyMediaCue(slide);
    slide.isSampleNeed = slide.hasSample;
}

bool SamplerBackend::startPlayback(SampleListModel *model, int row, bool showErrors, QObject *ownedObject)
{
    SampleData *sample = model ? model->at(row) : nullptr;
    if (!sample)
        return false;

    const QString path = absolutePath(sample->path);
    if (!QFile::exists(path)) {
        if (showErrors)
            setStatus("Sample file not found: " + sample->path);
        return false;
    }

    if (sample->stopSounds)
        stopAllSamples();
    removeActiveFor(model, row);

    auto *player = new QMediaPlayer(this);
    auto *output = new QAudioOutput(this);
    output->setVolume(qBound(0.0, sample->volume, 1.0));
    player->setAudioOutput(output);
    player->setSource(QUrl::fromLocalFile(path));

    ActivePlayback active;
    active.player = player;
    active.output = output;
    active.model = model;
    active.row = row;
    active.ownedObject = ownedObject;
    m_activePlaybacks.append(active);

    connect(player, &QMediaPlayer::mediaStatusChanged, this, [this, player](QMediaPlayer::MediaStatus status) {
        if (status == QMediaPlayer::EndOfMedia || status == QMediaPlayer::InvalidMedia)
            cleanupFinishedPlayback(player);
    });
    connect(player, &QMediaPlayer::errorOccurred, this, [this, player](QMediaPlayer::Error, const QString &errorString) {
        if (!errorString.isEmpty())
            setStatus("Audio error: " + errorString);
        cleanupFinishedPlayback(player);
    });

    markPlaying(model, row, true);
    if (m_audioPaused) {
        m_audioPaused = false;
        emit audioPausedChanged();
    }
    player->play();
    return true;
}

void SamplerBackend::playMediaCue(const SlideData &slide, int mediaIndex)
{
    if (mediaIndex < 0 || mediaIndex >= slide.mediaCues.count())
        return;
    const SlideData::MediaCue &cue = slide.mediaCues.at(mediaIndex);
    if (!cue.hasSample || cue.sample.path.isEmpty())
        return;

    QList<SampleData> values;
    values.append(cue.sample);
    auto *temporaryModel = new SampleListModel(this);
    temporaryModel->reset(values);
    if (!startPlayback(temporaryModel, 0, false, temporaryModel))
        temporaryModel->deleteLater();
}

void SamplerBackend::markPlaying(SampleListModel *model, int row, bool playing)
{
    if (!model)
        return;
    if (SampleData *sample = model->at(row)) {
        sample->isPlaying = playing;
        model->notifyChanged(row);
    }
}

void SamplerBackend::reindexActiveRowsAfterRemoval(SampleListModel *model, int removedRow)
{
    for (ActivePlayback &active : m_activePlaybacks) {
        if (active.model == model && active.row > removedRow)
            --active.row;
    }
}

void SamplerBackend::reindexActiveRowsAfterMove(SampleListModel *model, int from, int to)
{
    if (from == to)
        return;

    for (ActivePlayback &active : m_activePlaybacks) {
        if (active.model != model)
            continue;
        if (active.row == from) {
            active.row = to;
        } else if (from < to && active.row > from && active.row <= to) {
            --active.row;
        } else if (to < from && active.row >= to && active.row < from) {
            ++active.row;
        }
    }
}

void SamplerBackend::cleanupPlaybackEntry(int index, bool stopPlayer)
{
    if (index < 0 || index >= m_activePlaybacks.count())
        return;

    const ActivePlayback active = m_activePlaybacks.takeAt(index);
    if (active.player && stopPlayer) {
        QObject::disconnect(active.player, nullptr, this, nullptr);
        active.player->stop();
    }

    markPlaying(active.model, active.row, false);

    if (active.player)
        active.player->deleteLater();
    if (active.output)
        active.output->deleteLater();
    if (active.ownedObject)
        active.ownedObject->deleteLater();

    if (m_activePlaybacks.isEmpty() && m_audioPaused) {
        m_audioPaused = false;
        emit audioPausedChanged();
    }
}

void SamplerBackend::removeActiveFor(SampleListModel *model, int row)
{
    for (int i = m_activePlaybacks.count() - 1; i >= 0; --i) {
        const ActivePlayback active = m_activePlaybacks.at(i);
        if (active.model != model || active.row != row)
            continue;
        cleanupPlaybackEntry(i, true);
    }
    markPlaying(model, row, false);
}

void SamplerBackend::cleanupFinishedPlayback(QMediaPlayer *player)
{
    for (int i = 0; i < m_activePlaybacks.count(); ++i) {
        const ActivePlayback active = m_activePlaybacks.at(i);
        if (active.player != player)
            continue;
        cleanupPlaybackEntry(i, false);
        return;
    }
}

void SamplerBackend::syncStageToCurrentSlide()
{
    if (!m_stageActive)
        return;

    const SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || isDefaultSlide(*slide)) {
        closeStage();
        return;
    }

    if (slide->mediaPaths.isEmpty()) {
        m_currentMediaIndex = -1;
        m_currentMediaPath.clear();
        m_nextMediaPath.clear();
        updatePreviewModel();
        emit stageChanged();
        return;
    }

    if (m_currentMediaIndex < 0)
        m_currentMediaIndex = 0;
    if (m_currentMediaIndex >= slide->mediaPaths.count())
        m_currentMediaIndex = slide->mediaPaths.count() - 1;
    showSlideMedia();
}

void SamplerBackend::showSlideMedia()
{
    const SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide || m_currentMediaIndex < 0 || m_currentMediaIndex >= slide->mediaPaths.count()) {
        m_currentMediaPath.clear();
        m_nextMediaPath.clear();
        updatePreviewModel();
        emit stageChanged();
        return;
    }

    m_currentMediaPath = absolutePath(slide->mediaPaths.at(m_currentMediaIndex));
    m_nextMediaPath = m_currentMediaIndex + 1 < slide->mediaPaths.count()
        ? absolutePath(slide->mediaPaths.at(m_currentMediaIndex + 1))
        : QString();
    playMediaCue(*slide, m_currentMediaIndex);
    updatePreviewModel();
    emit stageChanged();
}

void SamplerBackend::updatePreviewModel()
{
    const SlideData *slide = m_quickSlides.at(m_currentSlideIndex);
    if (!slide) {
        m_previewItems.setMedia({}, -1, baseDir());
        return;
    }
    m_previewItems.setMedia(slide->mediaPaths, m_currentMediaIndex, baseDir());
}

void SamplerBackend::setStatus(const QString &message)
{
    if (m_statusMessage == message)
        return;
    m_statusMessage = message;
    emit statusMessageChanged();
}

void SamplerBackend::updateScreenGeometry()
{
    const QList<QScreen *> screens = QGuiApplication::screens();
    QScreen *target = nullptr;
    for (QScreen *screen : screens) {
        if (screen != QGuiApplication::primaryScreen()) {
            target = screen;
            break;
        }
    }
    if (!target)
        target = QGuiApplication::primaryScreen();
    if (!target)
        return;
    m_stageScreen = target;
    const QRect geometry = target->geometry();
    m_stageX = geometry.x();
    m_stageY = geometry.y();
    m_stageWidth = geometry.width();
    m_stageHeight = geometry.height();
    emit screenGeometryChanged();
}

void SamplerBackend::saveHost(const QString &host) const
{
    QDir().mkpath(saveDir());
    QFile file(QDir(saveDir()).absoluteFilePath("host.txt"));
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(host.trimmed().toUtf8());
}

QString SamplerBackend::loadHost() const
{
    QFile file(QDir(saveDir()).absoluteFilePath("host.txt"));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

void SamplerBackend::sendWebSocketHandshake(const QUrl &url)
{
    QByteArray randomBytes;
    randomBytes.resize(16);
    for (char &byte : randomBytes)
        byte = static_cast<char>(QRandomGenerator::global()->bounded(256));
    m_webSocketKey = randomBytes.toBase64();

    QString path = url.path().isEmpty() ? "/" : url.path();
    if (url.hasQuery())
        path += "?" + url.query();

    QByteArray request;
    request += "GET " + path.toUtf8() + " HTTP/1.1\r\n";
    request += "Host: " + url.host().toUtf8();
    if (url.port() > 0)
        request += ":" + QByteArray::number(url.port());
    request += "\r\n";
    request += "Upgrade: websocket\r\n";
    request += "Connection: Upgrade\r\n";
    request += "Sec-WebSocket-Key: " + m_webSocketKey + "\r\n";
    request += "Sec-WebSocket-Version: 13\r\n\r\n";
    m_socket.write(request);
}

void SamplerBackend::handleSocketReadyRead()
{
    m_socketBuffer += m_socket.readAll();

    if (!m_webSocketReady) {
        const int headerEnd = m_socketBuffer.indexOf("\r\n\r\n");
        if (headerEnd < 0)
            return;

        const QByteArray header = m_socketBuffer.left(headerEnd);
        m_socketBuffer.remove(0, headerEnd + 4);
        if (!header.startsWith("HTTP/1.1 101") && !header.startsWith("HTTP/1.0 101")) {
            setStatus("Host rejected WebSocket upgrade.");
            m_socket.disconnectFromHost();
            return;
        }

        m_webSocketReady = true;
        saveHost(m_savedHost);
        setStatus("Host connected.");
        emit connectionChanged();
        sendWebSocketText("HOST");
        sendWebSocketText("HSFALSE");
    }

    while (true) {
        const QByteArray payload = takeWebSocketFrame();
        if (payload.isNull())
            break;
        handleWebSocketPayload(QString::fromUtf8(payload));
    }
}

void SamplerBackend::handleWebSocketPayload(const QString &message)
{
    if (message == QString::fromUtf8("Игрок 1") || message == QString::fromUtf8("Игрок 2"))
        playFixedSample(0, false);
}

void SamplerBackend::sendWebSocketText(const QString &message)
{
    const QByteArray payload = message.toUtf8();
    QByteArray frame;
    frame.append(char(0x81));

    const quint64 length = static_cast<quint64>(payload.size());
    if (length < 126) {
        frame.append(char(0x80 | length));
    } else if (length <= 0xffff) {
        frame.append(char(0x80 | 126));
        frame.append(char((length >> 8) & 0xff));
        frame.append(char(length & 0xff));
    } else {
        frame.append(char(0x80 | 127));
        for (int shift = 56; shift >= 0; shift -= 8)
            frame.append(char((length >> shift) & 0xff));
    }

    QByteArray mask;
    mask.resize(4);
    for (char &byte : mask)
        byte = static_cast<char>(QRandomGenerator::global()->bounded(256));
    frame += mask;

    QByteArray maskedPayload = payload;
    for (int i = 0; i < maskedPayload.size(); ++i)
        maskedPayload[i] = maskedPayload.at(i) ^ mask.at(i % 4);

    frame += maskedPayload;
    m_socket.write(frame);
}

QByteArray SamplerBackend::takeWebSocketFrame()
{
    if (m_socketBuffer.size() < 2)
        return QByteArray();

    const quint8 first = static_cast<quint8>(m_socketBuffer.at(0));
    const quint8 second = static_cast<quint8>(m_socketBuffer.at(1));
    const quint8 opcode = first & 0x0f;
    const bool masked = (second & 0x80) != 0;
    quint64 length = second & 0x7f;
    int offset = 2;

    if (length == 126) {
        if (m_socketBuffer.size() < offset + 2)
            return QByteArray();
        length = (static_cast<quint8>(m_socketBuffer.at(offset)) << 8)
            | static_cast<quint8>(m_socketBuffer.at(offset + 1));
        offset += 2;
    } else if (length == 127) {
        if (m_socketBuffer.size() < offset + 8)
            return QByteArray();
        length = 0;
        for (int i = 0; i < 8; ++i)
            length = (length << 8) | static_cast<quint8>(m_socketBuffer.at(offset + i));
        offset += 8;
    }

    QByteArray mask;
    if (masked) {
        if (m_socketBuffer.size() < offset + 4)
            return QByteArray();
        mask = m_socketBuffer.mid(offset, 4);
        offset += 4;
    }

    if (m_socketBuffer.size() < offset + static_cast<int>(length))
        return QByteArray();

    QByteArray payload = m_socketBuffer.mid(offset, static_cast<int>(length));
    m_socketBuffer.remove(0, offset + static_cast<int>(length));

    if (masked) {
        for (int i = 0; i < payload.size(); ++i)
            payload[i] = payload.at(i) ^ mask.at(i % 4);
    }

    if (opcode == 0x8) {
        m_socket.disconnectFromHost();
        return QByteArray();
    }
    if (opcode != 0x1)
        return QByteArray();
    return payload;
}
