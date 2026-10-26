#include "CaptureHarness.h"
#include "ClickController.h"
#include "ConfigStore.h"
#include "Language.h"
#include "StartupController.h"
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegion>
#include <QScreen>
#ifdef Q_OS_WIN
#include <windows.h>
#include <shobjidl.h>
#endif
int main(int argc, char *argv[]) {
#ifdef Q_OS_WIN
    // Stable shell identity for taskbar grouping and pinned shortcuts.
    SetCurrentProcessExplicitAppUserModelID(L"CClicker.Desktop");
#endif
    QGuiApplication app(argc, argv);
    // Keep the established storage identity: an upgrade does not move or delete user data.
    app.setApplicationDisplayName("C clicker");
    app.setOrganizationName("ObsidianClick");
    app.setApplicationName("ObsidianClick");
    app.setApplicationVersion("0.7.0-glow");
    app.setWindowIcon(QIcon(":/qt/qml/CClicker/assets/app.ico"));
    QFontDatabase::addApplicationFont(":/qt/qml/CClicker/assets/fonts/Manrope.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/CClicker/assets/fonts/JetBrainsMono.ttf");
    QQuickStyle::setStyle("Basic");
    // Install the translator before any controller builds its first strings.
    LanguageController language;
    StartupController startup;
    ClickController clicks;
    ConfigStore configs(&clicks);
    QQmlApplicationEngine engine;
    language.setEngine(&engine);
    QObject::connect(&language, &LanguageController::languageChanged, &clicks, &ClickController::retranslate);
    QObject::connect(&language, &LanguageController::languageChanged, &configs, &ConfigStore::refresh);
    engine.rootContext()->setContextProperty("i18n", &language);
    engine.rootContext()->setContextProperty("startup", &startup);
    engine.rootContext()->setContextProperty("configs", &configs);
    engine.rootContext()->setContextProperty("clickEngine", &clicks);
    engine.rootContext()->setContextProperty("uiCapture", app.arguments().contains("--capture") && !app.arguments().contains("--capture-adaptive-tests"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("CClicker", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    // Center once within this monitor's work area, never bind x/y to changing window dimensions.
    const QRect workArea = win->screen()->availableGeometry();
    win->setPosition(workArea.topLeft() + QPoint((workArea.width() - win->width()) / 2,
                                                (workArea.height() - win->height()) / 2));
    // Transparent margins must not intercept clicks during the compact startup.
    auto updateMask = [win] {
        if (QGuiApplication::platformName() == "offscreen")
            return;
        if (win->property("expansion").toReal() >= 1 && !win->property("exiting").toBool()) {
            // Clear the transient startup mask, otherwise fullscreen remains
            // restricted to the original window's rectangle.
            win->setMask(QRegion());
            return;
        }
        const qreal scale = win->property("uiScale").toReal();
        const int w = qRound(win->property("panelWidth").toReal() * scale);
        const int h = qRound(win->property("panelHeight").toReal() * scale);
        win->setMask(QRegion((win->width() - w) / 2, (win->height() - h) / 2, w, h));
    };
    // A lightweight timer owns only the transient native input region, not rendering.
    QTimer maskTimer;
    maskTimer.setInterval(16);
    QObject::connect(&maskTimer, &QTimer::timeout, &app, [&] {
        updateMask();
        if (win->property("expansion").toReal() >= 1 && !win->property("exiting").toBool())
            maskTimer.stop();
    });
    // The closing fold shrinks the shell again: clip the window to it, as at startup.
    QObject::connect(win, SIGNAL(exitingChanged()), &maskTimer, SLOT(start()));
    updateMask();
    maskTimer.start();
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &clicks, &ClickController::stop);
    const int captureIndex = app.arguments().indexOf("--capture");
    if (captureIndex >= 0 && captureIndex + 1 < app.arguments().size())
        runCaptureHarness(win, app.arguments()[captureIndex + 1], &clicks, &configs, &language);
    return app.exec();
}
