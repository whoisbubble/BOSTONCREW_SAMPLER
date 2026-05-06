#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "SamplerBackend.h"

#ifdef Q_OS_WIN
#include <shobjidl.h>
#endif

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Basic");

    QApplication app(argc, argv);
#ifdef Q_OS_WIN
    SetCurrentProcessExplicitAppUserModelID(L"BOSTONCREW.SAMPLER");
#endif
    app.setApplicationName("BOSTONCREW SAMPLER");
    app.setApplicationDisplayName("BOSTONCREW SAMPLER");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("BOSTONCREW");
    app.setWindowIcon(QIcon(":/assets/app_icon.png"));

    SamplerBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("samplerBackend", &backend);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("CPlusEventSampler", "Main");

    return QCoreApplication::exec();
}
