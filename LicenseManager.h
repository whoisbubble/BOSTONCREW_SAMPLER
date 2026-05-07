#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>

class QNetworkReply;

class LicenseManager final : public QObject
{
    Q_OBJECT

public:
    explicit LicenseManager(QObject *parent = nullptr);

    void setStorageDir(const QString &storageDir);
    void initialize();

    bool allowed() const;
    bool busy() const;
    QString message() const;
    QString errorMessage() const;
    QString apiUrl() const;

public slots:
    void activate(const QString &licenseKey);
    void checkNow();

signals:
    void stateChanged();

private:
    enum class RequestKind {
        None,
        Activation,
        Check
    };

    struct LocalLicense {
        QString licenseKey;
        QString deviceFingerprint;
        QString status;
        QString activatedAt;
        QString lastCheckAt;
        QString offlineToken;
        QString offlineIssuedAt;
    };

    QString licensePath() const;
    QString currentDeviceFingerprint() const;
    void loadLocalLicense();
    void saveLocalLicense() const;
    void clearLocalLicense();
    bool localLicenseAllowsCurrentDevice() const;
    void setAllowed(bool allowed);
    void setBusy(bool busy);
    void setMessage(const QString &message);
    void setErrorMessage(const QString &message);
    void emitStateChanged();
    void postLicenseRequest(const QString &endpoint, const QString &licenseKey, RequestKind kind);
    void handleActivationReply(QNetworkReply *reply);
    void handleCheckReply(QNetworkReply *reply);
    void applyAllowedResponse(const QJsonObject &root);
    void invalidateLocalLicense(const QString &status, const QString &message);
    QString mapErrorCodeToMessage(const QString &code) const;
    static QString normalizedLicenseKey(const QString &licenseKey);
    static QString normalizedSignalValue(const QString &value);
    static QString extractErrorCode(const QJsonObject &root);

    QNetworkAccessManager m_network;
    QTimer m_periodicCheckTimer;
    QString m_storageDir;
    QString m_apiUrl;
    QString m_currentDeviceFingerprint;
    LocalLicense m_localLicense;
    bool m_hasLocalLicense = false;
    bool m_allowed = false;
    bool m_busy = false;
    QString m_message;
    QString m_errorMessage;
    RequestKind m_requestKind = RequestKind::None;
};
