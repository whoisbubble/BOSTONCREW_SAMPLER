#include "LicenseManager.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QSysInfo>
#include <QUrl>

namespace {
constexpr auto DefaultApiUrl = "https://bostoncrew.ru/api";
constexpr int NetworkTimeoutMs = 12000;
constexpr int PeriodicCheckIntervalMs = 6 * 60 * 60 * 1000;

bool isBlockingLicenseError(const QString &code)
{
    static const QStringList blockingCodes = {
        "LICENSE_NOT_FOUND",
        "LICENSE_NOT_ACTIVATED",
        "DEVICE_MISMATCH",
        "LICENSE_REVOKED",
        "LICENSE_REFUNDED"
    };
    return blockingCodes.contains(code);
}

QString normalizedApiUrl(QString url)
{
    url = url.trimmed();
    if (url.isEmpty())
        url = QString::fromLatin1(DefaultApiUrl);
    while (url.endsWith('/'))
        url.chop(1);
    return url;
}

QString jsonString(const QJsonObject &object, const QString &key)
{
    const QJsonValue value = object.value(key);
    return value.isString() ? value.toString().trimmed() : QString();
}

QString registryValue(const QString &path, const QString &key)
{
    QSettings settings(path, QSettings::NativeFormat);
    return settings.value(key).toString();
}
}

LicenseManager::LicenseManager(QObject *parent)
    : QObject(parent)
    , m_apiUrl(normalizedApiUrl(qEnvironmentVariable("BOSTONCREW_API_URL")))
{
    m_periodicCheckTimer.setInterval(PeriodicCheckIntervalMs);
    connect(&m_periodicCheckTimer, &QTimer::timeout, this, &LicenseManager::checkNow);
}

void LicenseManager::setStorageDir(const QString &storageDir)
{
    m_storageDir = storageDir;
}

void LicenseManager::initialize()
{
    QDir().mkpath(m_storageDir);
    m_currentDeviceFingerprint = currentDeviceFingerprint();
    loadLocalLicense();

    if (!m_hasLocalLicense) {
        setAllowed(false);
        setMessage("Введите лицензионный ключ для активации.");
        setErrorMessage(QString());
        return;
    }

    if (!localLicenseAllowsCurrentDevice()) {
        setAllowed(false);
        setMessage("Лицензия активирована на другом устройстве. Купите отдельный ключ на bostoncrew.ru");
        setErrorMessage(m_message);
        return;
    }

    setAllowed(true);
    setMessage("Лицензия активна.");
    setErrorMessage(QString());
    m_periodicCheckTimer.start();
    QTimer::singleShot(0, this, &LicenseManager::checkNow);
}

bool LicenseManager::allowed() const { return m_allowed; }
bool LicenseManager::busy() const { return m_busy; }
QString LicenseManager::message() const { return m_message; }
QString LicenseManager::errorMessage() const { return m_errorMessage; }
QString LicenseManager::apiUrl() const { return m_apiUrl; }

void LicenseManager::activate(const QString &licenseKey)
{
    if (m_requestKind != RequestKind::None)
        return;

    const QString normalizedKey = normalizedLicenseKey(licenseKey);
    if (normalizedKey.isEmpty()) {
        setErrorMessage("Введите лицензионный ключ.");
        return;
    }

    setBusy(true);
    setErrorMessage(QString());
    setMessage("Проверяем ключ...");
    postLicenseRequest("licenses/activate", normalizedKey, RequestKind::Activation);
}

void LicenseManager::checkNow()
{
    if (!m_allowed || !m_hasLocalLicense || m_requestKind != RequestKind::None)
        return;

    if (!localLicenseAllowsCurrentDevice()) {
        invalidateLocalLicense("device_mismatch", "Лицензия активирована на другом устройстве. Купите отдельный ключ на bostoncrew.ru");
        return;
    }

    postLicenseRequest("licenses/check", m_localLicense.licenseKey, RequestKind::Check);
}

QString LicenseManager::licensePath() const
{
    return QDir(m_storageDir).absoluteFilePath("license.json");
}

QString LicenseManager::currentDeviceFingerprint() const
{
    QStringList stableSignals;
    int uniqueSignalCount = 0;

    auto addSignal = [&stableSignals, &uniqueSignalCount](const QString &name, const QString &value, bool uniqueSignal = true) {
        const QString normalized = LicenseManager::normalizedSignalValue(value);
        if (normalized.isEmpty())
            return;
        stableSignals.append(name.toLower() + "=" + normalized);
        if (uniqueSignal)
            ++uniqueSignalCount;
    };

    addSignal("qtMachineUniqueId", QString::fromUtf8(QSysInfo::machineUniqueId()));

#ifdef Q_OS_WIN
    addSignal("windowsMachineGuid", registryValue("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography", "MachineGuid"));
    addSignal("windowsHardwareProfileGuid", registryValue("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\IDConfigDB\\Hardware Profiles\\0001", "HwProfileGuid"));
#endif

    if (uniqueSignalCount == 0)
        addSignal("machineHostName", QSysInfo::machineHostName());

    addSignal("kernelType", QSysInfo::kernelType(), false);
    addSignal("productType", QSysInfo::productType(), false);
    addSignal("cpuArchitecture", QSysInfo::currentCpuArchitecture(), false);
    addSignal("buildAbi", QSysInfo::buildAbi(), false);

    stableSignals.removeDuplicates();
    stableSignals.sort(Qt::CaseInsensitive);

    const QByteArray payload = QString("bostoncrew-sampler-device-v1\n%1").arg(stableSignals.join('\n')).toUtf8();
    const QByteArray digest = QCryptographicHash::hash(payload, QCryptographicHash::Sha256).toHex();
    return QString("sha256:%1").arg(QString::fromLatin1(digest)).toLower();
}

void LicenseManager::loadLocalLicense()
{
    m_hasLocalLicense = false;
    m_localLicense = {};

    QFile file(licensePath());
    if (!file.open(QIODevice::ReadOnly))
        return;

    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return;

    const QJsonObject root = doc.object();
    const QJsonObject offline = root.value("offline").toObject();

    m_localLicense.licenseKey = normalizedLicenseKey(jsonString(root, "licenseKey"));
    m_localLicense.deviceFingerprint = jsonString(root, "deviceFingerprint").toLower();
    m_localLicense.status = jsonString(root, "status").toLower();
    m_localLicense.activatedAt = jsonString(root, "activatedAt");
    m_localLicense.lastCheckAt = jsonString(root, "lastCheckAt");
    m_localLicense.offlineToken = jsonString(offline, "token");
    m_localLicense.offlineIssuedAt = jsonString(offline, "issuedAt");

    m_hasLocalLicense = !m_localLicense.licenseKey.isEmpty()
        && !m_localLicense.deviceFingerprint.isEmpty()
        && !m_localLicense.status.isEmpty();
}

void LicenseManager::saveLocalLicense() const
{
    QDir().mkpath(m_storageDir);

    QJsonObject offline;
    offline.insert("token", m_localLicense.offlineToken);
    offline.insert("issuedAt", m_localLicense.offlineIssuedAt);

    QJsonObject root;
    root.insert("licenseKey", m_localLicense.licenseKey);
    root.insert("deviceFingerprint", m_localLicense.deviceFingerprint.toLower());
    root.insert("status", m_localLicense.status.toLower());
    root.insert("activatedAt", m_localLicense.activatedAt);
    root.insert("lastCheckAt", m_localLicense.lastCheckAt);
    root.insert("offline", offline);

    QSaveFile file(licensePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;

    const QByteArray payload = QJsonDocument(root).toJson(QJsonDocument::Indented);
    if (file.write(payload) == payload.size())
        file.commit();
}

void LicenseManager::clearLocalLicense()
{
    m_localLicense = {};
    m_hasLocalLicense = false;
    QFile::remove(licensePath());
}

bool LicenseManager::localLicenseAllowsCurrentDevice() const
{
    return m_hasLocalLicense
        && m_localLicense.status.compare("activated", Qt::CaseInsensitive) == 0
        && !m_localLicense.offlineToken.isEmpty()
        && m_localLicense.deviceFingerprint.compare(m_currentDeviceFingerprint, Qt::CaseInsensitive) == 0;
}

void LicenseManager::setAllowed(bool allowed)
{
    if (m_allowed == allowed)
        return;
    m_allowed = allowed;
    emitStateChanged();
}

void LicenseManager::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emitStateChanged();
}

void LicenseManager::setMessage(const QString &message)
{
    if (m_message == message)
        return;
    m_message = message;
    emitStateChanged();
}

void LicenseManager::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emitStateChanged();
}

void LicenseManager::emitStateChanged()
{
    emit stateChanged();
}

void LicenseManager::postLicenseRequest(const QString &endpoint, const QString &licenseKey, RequestKind kind)
{
    m_requestKind = kind;

    QUrl url(m_apiUrl + "/" + endpoint);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(NetworkTimeoutMs);

    QJsonObject body;
    body.insert("licenseKey", normalizedLicenseKey(licenseKey));
    body.insert("deviceFingerprint", m_currentDeviceFingerprint);
    body.insert("appVersion", QCoreApplication::applicationVersion());

    QNetworkReply *reply = m_network.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const RequestKind finishedKind = m_requestKind;
        m_requestKind = RequestKind::None;

        if (finishedKind == RequestKind::Activation)
            handleActivationReply(reply);
        else if (finishedKind == RequestKind::Check)
            handleCheckReply(reply);

        reply->deleteLater();
    });
}

void LicenseManager::handleActivationReply(QNetworkReply *reply)
{
    setBusy(false);

    const QByteArray payload = reply->readAll();
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);
    const QJsonObject root = doc.isObject() ? doc.object() : QJsonObject();
    const QString errorCode = extractErrorCode(root);
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (statusCode >= 500 || (errorCode.isEmpty() && (reply->error() != QNetworkReply::NoError || parseError.error != QJsonParseError::NoError))) {
        setAllowed(false);
        setMessage("Введите лицензионный ключ для активации.");
        setErrorMessage("Для первой активации нужно подключение к интернету");
        return;
    }

    if (root.value("allowed").toBool(false)) {
        applyAllowedResponse(root);
        setAllowed(true);
        setMessage("Лицензия активирована.");
        setErrorMessage(QString());
        m_periodicCheckTimer.start();
        return;
    }

    const QString message = mapErrorCodeToMessage(errorCode);
    setAllowed(false);
    setMessage("Введите лицензионный ключ для активации.");
    setErrorMessage(message);
}

void LicenseManager::handleCheckReply(QNetworkReply *reply)
{
    const QByteArray payload = reply->readAll();
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);
    const QJsonObject root = doc.isObject() ? doc.object() : QJsonObject();
    const QString errorCode = extractErrorCode(root);
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (statusCode >= 500 || (errorCode.isEmpty() && (reply->error() != QNetworkReply::NoError || parseError.error != QJsonParseError::NoError))) {
        setMessage("Лицензия активна. Онлайн-проверка будет повторена позже.");
        return;
    }

    if (root.value("allowed").toBool(false)) {
        applyAllowedResponse(root);
        setAllowed(true);
        setMessage("Лицензия активна.");
        setErrorMessage(QString());
        return;
    }

    if (isBlockingLicenseError(errorCode)) {
        invalidateLocalLicense(errorCode.toLower(), mapErrorCodeToMessage(errorCode));
        return;
    }

    setMessage("Лицензия активна. Онлайн-проверка будет повторена позже.");
}

void LicenseManager::applyAllowedResponse(const QJsonObject &root)
{
    const QJsonObject license = root.value("license").toObject();
    const QJsonObject offline = root.value("offline").toObject();

    const QString responseKey = normalizedLicenseKey(jsonString(license, "key"));
    if (!responseKey.isEmpty())
        m_localLicense.licenseKey = responseKey;
    else if (m_localLicense.licenseKey.isEmpty())
        m_localLicense.licenseKey = normalizedLicenseKey(jsonString(root, "licenseKey"));

    m_localLicense.deviceFingerprint = jsonString(license, "deviceFingerprint").toLower();
    if (m_localLicense.deviceFingerprint.isEmpty())
        m_localLicense.deviceFingerprint = m_currentDeviceFingerprint;

    m_localLicense.status = jsonString(license, "status").toLower();
    if (m_localLicense.status.isEmpty())
        m_localLicense.status = "activated";

    const QString activatedAt = jsonString(license, "activatedAt");
    if (!activatedAt.isEmpty())
        m_localLicense.activatedAt = activatedAt;
    else if (m_localLicense.activatedAt.isEmpty())
        m_localLicense.activatedAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    const QString lastCheckAt = jsonString(license, "lastCheckAt");
    m_localLicense.lastCheckAt = !lastCheckAt.isEmpty()
        ? lastCheckAt
        : QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);

    const QString offlineToken = jsonString(offline, "token");
    if (!offlineToken.isEmpty())
        m_localLicense.offlineToken = offlineToken;

    const QString offlineIssuedAt = jsonString(offline, "issuedAt");
    if (!offlineIssuedAt.isEmpty())
        m_localLicense.offlineIssuedAt = offlineIssuedAt;

    m_hasLocalLicense = true;
    saveLocalLicense();
}

void LicenseManager::invalidateLocalLicense(const QString &status, const QString &message)
{
    if (m_hasLocalLicense) {
        m_localLicense.status = status.toLower();
        m_localLicense.offlineToken.clear();
        m_localLicense.offlineIssuedAt.clear();
        saveLocalLicense();
    }

    m_periodicCheckTimer.stop();
    setAllowed(false);
    setMessage(message);
    setErrorMessage(message);
}

QString LicenseManager::mapErrorCodeToMessage(const QString &code) const
{
    if (code == "LICENSE_NOT_FOUND")
        return "Ключ не найден. Проверьте ввод или купите ключ на bostoncrew.ru";
    if (code == "LICENSE_NOT_ACTIVATED")
        return "Ключ еще не активирован. Проверьте ключ или обратитесь в поддержку.";
    if (code == "DEVICE_MISMATCH")
        return "Лицензия активирована на другом устройстве. Купите отдельный ключ на bostoncrew.ru";
    if (code == "LICENSE_REVOKED")
        return "Ключ отключен. Купите новый ключ на bostoncrew.ru";
    if (code == "LICENSE_REFUNDED")
        return "По этому ключу оформлен возврат. Купите новый ключ на bostoncrew.ru";
    return "Не удалось проверить ключ. Попробуйте еще раз.";
}

QString LicenseManager::normalizedLicenseKey(const QString &licenseKey)
{
    return licenseKey.trimmed().toUpper();
}

QString LicenseManager::normalizedSignalValue(const QString &value)
{
    QString normalized = value.trimmed().toLower();
    normalized.replace(QRegularExpression("\\s+"), "");
    return normalized;
}

QString LicenseManager::extractErrorCode(const QJsonObject &root)
{
    QString code = jsonString(root, "code").toUpper();
    if (!code.isEmpty())
        return code;

    code = jsonString(root, "error").toUpper();
    if (!code.isEmpty() && code.contains('_'))
        return code;

    const QJsonObject errorObject = root.value("error").toObject();
    code = jsonString(errorObject, "code").toUpper();
    if (!code.isEmpty())
        return code;

    code = jsonString(root, "errorCode").toUpper();
    if (!code.isEmpty())
        return code;

    return {};
}
