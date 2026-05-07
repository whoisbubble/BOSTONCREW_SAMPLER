#include "../LicenseManager.h"

#include <QtTest/QtTest>

#include <QDir>
#include <QFile>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQueue>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>

#include <memory>

namespace {
struct MockResponse {
    int status = 200;
    QJsonObject body;
    bool mirrorActivation = false;
};

class LicenseApiMock final : public QTcpServer
{
    Q_OBJECT

public:
    explicit LicenseApiMock(QObject *parent = nullptr)
        : QTcpServer(parent)
    {
        connect(this, &QTcpServer::newConnection, this, &LicenseApiMock::handleConnection);
    }

    bool start()
    {
        return listen(QHostAddress::LocalHost, 0);
    }

    QString baseUrl() const
    {
        return QString("http://127.0.0.1:%1/api").arg(serverPort());
    }

    void enqueue(const MockResponse &response)
    {
        m_responses.enqueue(response);
    }

    QJsonObject lastRequest() const
    {
        return m_lastRequest;
    }

private:
    void handleConnection()
    {
        QTcpSocket *socket = nextPendingConnection();
        auto buffer = std::make_shared<QByteArray>();

        connect(socket, &QTcpSocket::readyRead, this, [this, socket, buffer]() {
            buffer->append(socket->readAll());

            const int headerEnd = buffer->indexOf("\r\n\r\n");
            if (headerEnd < 0)
                return;

            const QByteArray header = buffer->left(headerEnd);
            int contentLength = 0;
            const QList<QByteArray> headerLines = header.split('\n');
            for (QByteArray line : headerLines) {
                line = line.trimmed();
                if (line.toLower().startsWith("content-length:"))
                    contentLength = line.mid(line.indexOf(':') + 1).trimmed().toInt();
            }

            const int bodyStart = headerEnd + 4;
            if (buffer->size() < bodyStart + contentLength)
                return;

            const QByteArray requestBody = buffer->mid(bodyStart, contentLength);
            m_lastRequest = QJsonDocument::fromJson(requestBody).object();

            MockResponse response;
            if (!m_responses.isEmpty())
                response = m_responses.dequeue();
            else
                response = {500, QJsonObject{{"code", "SERVER_ERROR"}}, false};

            QJsonObject responseBody = response.body;
            if (response.mirrorActivation) {
                QJsonObject license;
                license.insert("key", m_lastRequest.value("licenseKey").toString());
                license.insert("status", "activated");
                license.insert("deviceFingerprint", m_lastRequest.value("deviceFingerprint").toString());
                license.insert("activatedAt", "2026-05-07T00:00:00.000Z");
                license.insert("lastCheckAt", "2026-05-07T00:00:00.000Z");

                QJsonObject offline;
                offline.insert("token", "offline-token");
                offline.insert("issuedAt", "2026-05-07T00:00:00.000Z");

                responseBody.insert("allowed", true);
                responseBody.insert("license", license);
                responseBody.insert("offline", offline);
            }

            const QByteArray payload = QJsonDocument(responseBody).toJson(QJsonDocument::Compact);
            const QByteArray httpStatus = response.status == 200 ? QByteArray("200 OK") : QByteArray::number(response.status) + " Error";
            QByteArray raw;
            raw += "HTTP/1.1 " + httpStatus + "\r\n";
            raw += "Content-Type: application/json\r\n";
            raw += "Content-Length: " + QByteArray::number(payload.size()) + "\r\n";
            raw += "Connection: close\r\n\r\n";
            raw += payload;
            socket->write(raw);
            socket->disconnectFromHost();
        });
    }

    QQueue<MockResponse> m_responses;
    QJsonObject m_lastRequest;
};

QJsonObject readLicenseFile(const QString &storageDir)
{
    QFile file(QDir(storageDir).absoluteFilePath("license.json"));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

void writeLicenseFile(const QString &storageDir, const QJsonObject &object)
{
    QFile file(QDir(storageDir).absoluteFilePath("license.json"));
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
}

void activateSuccessfully(LicenseManager &manager, LicenseApiMock &api)
{
    api.enqueue(MockResponse{200, {}, true});
    manager.activate("BCS-TEST-TEST-TEST-TEST");
    QTRY_VERIFY_WITH_TIMEOUT(!manager.busy(), 3000);
    QVERIFY(manager.allowed());
}
}

class LicenseManagerTests final : public QObject
{
    Q_OBJECT

private slots:
    void noLocalLicenseBlocksApp()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        qputenv("BOSTONCREW_API_URL", "http://127.0.0.1:9/api");
        LicenseManager manager;
        manager.setStorageDir(dir.path());
        manager.initialize();

        QVERIFY(!manager.allowed());
        QVERIFY(manager.message().contains("Введите лицензионный ключ"));
    }

    void successfulActivationSavesLicense()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        LicenseApiMock api;
        QVERIFY(api.start());
        qputenv("BOSTONCREW_API_URL", api.baseUrl().toUtf8());

        LicenseManager manager;
        manager.setStorageDir(dir.path());
        manager.initialize();
        activateSuccessfully(manager, api);

        const QJsonObject saved = readLicenseFile(dir.path());
        QCOMPARE(saved.value("licenseKey").toString(), QString("BCS-TEST-TEST-TEST-TEST"));
        QCOMPARE(saved.value("status").toString(), QString("activated"));
        QVERIFY(saved.value("deviceFingerprint").toString().startsWith("sha256:"));
        QCOMPARE(saved.value("offline").toObject().value("token").toString(), QString("offline-token"));
    }

    void offlineRestartOnSameDeviceIsAllowed()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        LicenseApiMock api;
        QVERIFY(api.start());
        qputenv("BOSTONCREW_API_URL", api.baseUrl().toUtf8());

        {
            LicenseManager manager;
            manager.setStorageDir(dir.path());
            manager.initialize();
            activateSuccessfully(manager, api);
        }

        qputenv("BOSTONCREW_API_URL", "http://127.0.0.1:9/api");
        LicenseManager offlineManager;
        offlineManager.setStorageDir(dir.path());
        offlineManager.initialize();

        QVERIFY(offlineManager.allowed());
    }

    void fingerprintMismatchBlocksApp()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        LicenseApiMock api;
        QVERIFY(api.start());
        qputenv("BOSTONCREW_API_URL", api.baseUrl().toUtf8());

        {
            LicenseManager manager;
            manager.setStorageDir(dir.path());
            manager.initialize();
            activateSuccessfully(manager, api);
        }

        QJsonObject saved = readLicenseFile(dir.path());
        saved.insert("deviceFingerprint", "sha256:another-device");
        writeLicenseFile(dir.path(), saved);

        LicenseManager movedManager;
        movedManager.setStorageDir(dir.path());
        movedManager.initialize();

        QVERIFY(!movedManager.allowed());
        QCOMPARE(movedManager.errorMessage(), QString("Лицензия активирована на другом устройстве. Купите отдельный ключ на bostoncrew.ru"));
    }

    void licenseNotFoundShowsFriendlyError()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        LicenseApiMock api;
        QVERIFY(api.start());
        api.enqueue(MockResponse{404, QJsonObject{{"allowed", false}, {"code", "LICENSE_NOT_FOUND"}}, false});
        qputenv("BOSTONCREW_API_URL", api.baseUrl().toUtf8());

        LicenseManager manager;
        manager.setStorageDir(dir.path());
        manager.initialize();
        manager.activate("BCS-NOPE-NOPE-NOPE-NOPE");
        QTRY_VERIFY_WITH_TIMEOUT(!manager.busy(), 3000);

        QVERIFY(!manager.allowed());
        QVERIFY(manager.errorMessage().contains("Ключ не найден"));
    }

    void checkErrorsInvalidateLocalLicense_data()
    {
        QTest::addColumn<QString>("code");

        QTest::newRow("device mismatch") << "DEVICE_MISMATCH";
        QTest::newRow("revoked") << "LICENSE_REVOKED";
        QTest::newRow("refunded") << "LICENSE_REFUNDED";
    }

    void checkErrorsInvalidateLocalLicense()
    {
        QFETCH(QString, code);

        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        LicenseApiMock api;
        QVERIFY(api.start());
        qputenv("BOSTONCREW_API_URL", api.baseUrl().toUtf8());

        LicenseManager manager;
        manager.setStorageDir(dir.path());
        manager.initialize();
        activateSuccessfully(manager, api);

        api.enqueue(MockResponse{403, QJsonObject{{"allowed", false}, {"code", code}}, false});
        manager.checkNow();
        QTRY_VERIFY_WITH_TIMEOUT(!manager.allowed(), 3000);

        const QJsonObject saved = readLicenseFile(dir.path());
        QVERIFY(saved.value("offline").toObject().value("token").toString().isEmpty());
        QVERIFY(saved.value("status").toString().contains(code.toLower()));
    }

    void firstActivationRequiresReachableServer()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        qputenv("BOSTONCREW_API_URL", "http://127.0.0.1:9/api");
        LicenseManager manager;
        manager.setStorageDir(dir.path());
        manager.initialize();
        manager.activate("BCS-TEST-TEST-TEST-TEST");
        QTRY_VERIFY_WITH_TIMEOUT(!manager.busy(), 15000);

        QVERIFY(!manager.allowed());
        QCOMPARE(manager.errorMessage(), QString("Для первой активации нужно подключение к интернету"));
    }
};

QTEST_MAIN(LicenseManagerTests)

#include "LicenseManagerTests.moc"
