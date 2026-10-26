#include "CaptureHarness.h"
#include "ClickController.h"
#include "ConfigStore.h"
#include "Language.h"
#include <QRegularExpression>
#include <QSettings>
#include <QDebug>
#include <functional>
#include <memory>
#include <vector>
#include <QDir>
#include <QGuiApplication>
#include <QImage>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <cmath>
#include <QEventLoop>
#include <QSet>
namespace {
QQuickItem *find(QQuickItem *item, const QString &name) {
    if (item->objectName() == name)
        return item;
    for (auto *child : item->childItems())
        if (auto *found = find(child, name))
            return found;
    return nullptr;
}
void assertCleanShell(QQuickItem *item) {
    if (!item->isVisible()) return;
    if (item->objectName() == "refreshConfigs" || item->property("glyph").toString() == "info")
        qFatal("Removed redundant button returned");
    const QString text = item->property("text").toString();
    if (text.contains("Beta", Qt::CaseInsensitive) || text.contains(QStringLiteral("Без конфигурации")) ||
        text == QCoreApplication::translate("ConfigStore", "Без конфигурации") ||
        text.contains(QStringLiteral("  запуск     ")))
        qFatal("Removed shell clutter returned: %s", qPrintable(text));
    for (auto *child : item->childItems()) assertCleanShell(child);
}
void snapshot(QQuickWindow *win, const QString &path) {
    assertCleanShell(win->contentItem());
    for (const auto &name : {"keyboardPicker", "configNameDialog", "deleteConfigDialog", "limitsPopup"}) {
        auto *popup = win->findChild<QObject *>(name);
        if (popup && popup->property("visible").toBool() && popup->property("opacity").toReal() < 0.8)
            qFatal("Visible popup has unreadable opacity: %s", name);
    }
    if (!win->grabWindow().save(path))
        qFatal("Capture failed");
}
// English UI must not leak untranslated Russian. Key caps and user data are Latin here.
void assertNoCyrillic(QQuickItem *item, const char *where) {
    // Language cards name each language in itself ("Русский") on purpose.
    if (!item->isVisible() || item->objectName().startsWith("language_")) return;
    static const QRegularExpression cyrillic(QStringLiteral("[\\x{0400}-\\x{04FF}]"));
    for (const char *property : {"text", "placeholderText", "title"}) {
        const QString text = item->property(property).toString();
        if (text.contains(cyrillic))
            qFatal("Untranslated text on %s: %s", where, qPrintable(text));
    }
    for (auto *child : item->childItems()) assertNoCyrillic(child, where);
}
void click(QQuickWindow *win, const QString &name) {
    auto *item = find(win->contentItem(), name);
    if (!item || !QMetaObject::invokeMethod(item, "click"))
        qFatal("UI action not found: %s", qPrintable(name));
}
// ---- Settle audit: every animation must finish completely ----
QString describe(QObject *o) {
    QStringList chain;
    for (QObject *p = o; p && chain.size() < 4; p = p->parent())
        chain << QString("%1(%2)").arg(p->metaObject()->className(), p->objectName());
    return chain.join(" < ");
}
QStringList runningAnimations(QQuickWindow *win) {
    QSet<QObject *> seen;
    QStringList names;
    std::function<void(QObject *)> visit = [&](QObject *o) {
        if (!o || seen.contains(o)) return;
        seen.insert(o);
        if (o->inherits("QQuickAbstractAnimation") && o->property("running").toBool())
            names << describe(o);
        for (QObject *c : o->children()) visit(c);
        if (auto *item = qobject_cast<QQuickItem *>(o))
            for (auto *c : item->childItems()) visit(c);
    };
    visit(win);
    visit(win->contentItem());
    return names;
}
// Idle means: nothing loops, pages and glows are fully shown or fully gone, and
// two frames 150 ms apart are pixel-identical.
void assertSettled(QQuickWindow *win, const char *where) {
    const auto running = runningAnimations(win);
    if (!running.isEmpty())
        qFatal("Not settled (%s), still running: %s", where, qPrintable(running.join("; ")));
    std::function<void(QQuickItem *)> check = [&](QQuickItem *item) {
        const QString name = item->objectName();
        const qreal o = item->opacity();
        if ((name.startsWith("page") || name.endsWith("Body")) && item->property("current").isValid()) {
            if ((o > 0.001 && o < 0.999) || (o <= 0.001 && item->isVisible()))
                qFatal("Not settled (%s): %s stuck at opacity %f", where, qPrintable(name), o);
        }
        if (name == "auroraLive" && (o > 0.001 || item->isVisible()))
            qFatal("Not settled (%s): aurora still live (%f)", where, o);
        for (auto *c : item->childItems()) check(c);
    };
    check(win->contentItem());
    const QImage a = win->grabWindow();
    QEventLoop pause;
    QTimer::singleShot(150, &pause, &QEventLoop::quit);
    pause.exec();
    const QImage b = win->grabWindow();
    if (a != b) {
        a.save(QDir::temp().filePath("settle-a.png"));
        b.save(QDir::temp().filePath("settle-b.png"));
        qFatal("Not settled (%s): the picture is still changing", where);
    }
}
// At the moment the window really closes, the exit must have played out fully:
// timeline at 0, card dissolved, C erased and not a single visible pixel left.
class CloseAudit : public QObject {
  public:
    explicit CloseAudit(QQuickWindow *w) : QObject(w), m_win(w) {}
    bool eventFilter(QObject *object, QEvent *event) override {
        if (object != m_win || event->type() != QEvent::Close || !m_win->property("allowClose").toBool())
            return false;
        auto *mark = find(m_win->contentItem(), "cmark");
        if (m_win->property("expansion").toReal() != 0 || m_win->property("dismissal").toReal() != 0 ||
            !mark || mark->property("erase").toReal() < 0.999)
            qFatal("Close ended before its animation finished");
        // With an alpha surface every pixel must be transparent. Offscreen surfaces
        // are RGB32, where "transparent" reads as pure black: then every pixel must be
        // exactly the clear colour (the UI itself never paints pure black).
        const QImage grabbed = m_win->grabWindow();
        const bool alpha = grabbed.hasAlphaChannel();
        // "Visible" means above 2/255. The software renderer repaints only damaged
        // regions and can keep a 1/255 antialiasing fringe from an earlier frame of
        // the fold (seen as a 1 px column with no live item under it); in the dark
        // themes that fringe was black and invisible to this check as well.
        const QImage last = grabbed.convertToFormat(QImage::Format_ARGB32);
        const auto level = [alpha](QRgb px) { return alpha ? qAlpha(px) : qMax(qRed(px), qMax(qGreen(px), qBlue(px))); };
        int lit = 0, residue = 0;
        for (int y = 0; y < last.height(); ++y) {
            const auto *row = reinterpret_cast<const QRgb *>(last.constScanLine(y));
            for (int x = 0; x < last.width(); ++x) {
                residue = qMax(residue, level(row[x]));
                lit += level(row[x]) > 2;
            }
        }
        if (lit) {
            last.save(QDir::temp().filePath("close-left-pixels.png"));
            QRect box;
            for (int y = 0; y < last.height(); ++y) {
                const auto *row = reinterpret_cast<const QRgb *>(last.constScanLine(y));
                for (int x = 0; x < last.width(); ++x)
                    if (level(row[x]) > 2) box |= QRect(x, y, 1, 1);
            }
            const QPointF probe = box.center();
            std::function<void(QQuickItem *, qreal)> dump = [&](QQuickItem *item, qreal parentOpacity) {
                const qreal o = parentOpacity * item->opacity();
                if (!item->isVisible() || o <= 0) return;
                if (item->mapRectToScene(item->boundingRect()).contains(probe) && item->childItems().isEmpty())
                    qWarning().noquote() << "  lit at probe:" << describe(item) << "opacity" << o;
                for (auto *c : item->childItems()) dump(c, o);
            };
            dump(m_win->contentItem()->parentItem() ? m_win->contentItem()->parentItem() : m_win->contentItem(), 1);
            qFatal("Close left %d visible pixels on the last frame, in %d,%d %dx%d", lit, box.x(), box.y(), box.width(), box.height());
        }
        qInfo().noquote() << QString("NATIVE_CLOSE_COMPLETE_PASS (timeline 0, card dissolved, C erased, last frame clear; max residue %1/255)").arg(residue);
        return false;
    }

  private:
    QQuickWindow *m_win;
};
} // namespace
void runCaptureHarness(QQuickWindow *win, const QString &output, ClickController *engine,
                       ConfigStore *configs, LanguageController *language) {
    QDir().mkpath(output);
    const int capturePace = QCoreApplication::arguments().contains("--capture-slow") ? 3 : 1;
    // A relative sequence keeps a costly first font/layout/grab from bunching later actions
    // into one event-loop turn, before Qt has rendered the previous transition.
    struct Step { int time; std::function<void()> action; };
    auto steps = std::make_shared<std::vector<Step>>();
    auto index = std::make_shared<size_t>(0);
    auto previous = std::make_shared<int>(0);
    auto runner = std::make_shared<std::function<void()>>();
    std::weak_ptr<std::function<void()>> weakRunner = runner;
    *runner = [=] {
        if (*index >= steps->size()) return;
        const auto step = steps->at((*index)++);
        const int delay = qMax(1, step.time - *previous);
        *previous = step.time;
        auto next = weakRunner.lock();
        QTimer::singleShot(delay, win, [step, next] { step.action(); (*next)(); });
    };
    QTimer::singleShot(0, win, [runner] { (*runner)(); });
    auto at = [steps, capturePace](int ms, auto fn) {
        steps->push_back({ms <= 1600 ? ms : ms * capturePace, fn});
    };
    auto shot = [=](const QString &name) { snapshot(win, output + "/" + name + ".png"); };
    if (QCoreApplication::arguments().contains("--capture-window-tests")) {
        win->installEventFilter(new CloseAudit(win));
        at(1600, [=] { shot("windowed"); });
        at(1800, [=] { click(win, "fullscreenButton"); });
        at(2200, [=] {
            if (win->visibility() != QWindow::FullScreen)
                qFatal("Fullscreen state did not activate");
            if (QGuiApplication::platformName() == "xcb" &&
                win->size() != win->screen()->geometry().size())
                qFatal("Fullscreen did not fill screen geometry (run with a window manager)");
            shot("fullscreen");
        });
        at(2400, [=] { click(win, "fullscreenButton"); });
        at(2800, [=] {
            if (win->visibility() != QWindow::Windowed)
                qFatal("Fullscreen did not restore window state");
            shot("restored");
        });
        at(3000, [=] { click(win, "maximizeButton"); });
        at(3300, [=] {
            if (win->visibility() != QWindow::Maximized) qFatal("Maximize state did not activate");
            const QRect work = win->screen()->availableGeometry();
            if (QGuiApplication::platformName() == "xcb" &&
                (win->size() != work.size() || win->position() != work.topLeft()))
                qFatal("Maximize did not use available work area");
            shot("maximized");
            click(win, "fullscreenButton");
        });
        at(3500, [=] { click(win, "fullscreenButton"); });
        at(3700, [=] {
            if (win->visibility() != QWindow::Maximized) qFatal("Fullscreen failed to restore maximized");
            click(win, "maximizeButton");
        });
        at(3900, [=] {
            if (win->visibility() != QWindow::Windowed || win->size() != QSize(1160,800))
                qFatal("Maximize did not restore normal geometry");
            shot("maximize-restored");
        });
        at(4000, [=] { win->resize(1440, 900); });
        at(4300, [=] { shot("wide-window"); });
        at(4500, [=] { win->resize(1160, 800); });
        at(4800, [=] {
            click(win, "closeButton");
            if (!win->property("exiting").toBool() || engine->active())
                qFatal("Close did not stop input immediately");
            // Follow the fold frame by frame; fixed-time steps raced the 400 ms close.
            auto *probe = new QTimer(win);
            auto stage = std::make_shared<int>(0);
            probe->setInterval(4);
            QObject::connect(probe, &QTimer::timeout, win, [=] {
                const qreal fold = win->property("expansion").toReal();
                if (fold <= 0) { probe->stop(); return; }
                if (*stage == 0 && fold < 0.95) { *stage = 1; shot("closing"); }
                else if (*stage == 1 && fold < 0.75) {
                    *stage = 2;
                    if (fold >= 1) qFatal("Close did not fold the shell back");
                    qInfo() << "NATIVE_WINDOW_UI_PASS (fullscreen, work-area maximize, normal/maximized restore, resize, close stop, close fold)";
                    shot("closing-fold");
                }
            });
            probe->start();
        });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-mode-tests")) {
        at(1700, [=] {
            if (engine->clickMode() != 0 || !find(win->contentItem(), "legitBody")->isVisible())
                qFatal("Fresh profile is not Legit");
            click(win, "legitPreset2");
        });
        at(2000, [=] {
            if (engine->cpsMin() != 13 || engine->cpsMax() != 17) qFatal("Legit preset did not apply");
            shot("mode-legit");
            click(win, "legitPreset1");
            click(win, "mode2");
            engine->setIntervalMs(80); engine->setJitterPct(25); engine->setHoldMs(18); engine->setDrift(true);
        });
        at(2400, [=] {
            if (engine->clickMode() != 2 || !find(win->contentItem(), "customBody")->isVisible())
                qFatal("Custom mode click failed");
            shot("mode-custom");
            engine->setJitterPct(0); engine->setDrift(false); engine->setHoldMs(1);
            click(win, "mode1");
            engine->setIntervalMs(2);
        });
        at(2800, [=] {
            if (engine->clickMode() != 1 || engine->intervalMs() != 2 ||
                !find(win->contentItem(), "blatantBody")->isVisible())
                qFatal("Blatant mode click failed");
            shot("mode-blatant");
            click(win, "mode0");
            if (engine->clickMode() != 0 || engine->intervalMs() != 5)
                qFatal("Leaving Blatant did not restore the 5 ms floor");
            qInfo() << "NATIVE_MODE_UI_PASS (legit preset, custom recipe, blatant floor, mode return)";
            QCoreApplication::quit();
        });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-language-tests")) {
        const auto sweep = [=](const char *where) { assertNoCyrillic(win->contentItem(), where); };
        at(1700, [=] {
            if (language->language() != "en" || engine->modeSummary() != "Legit · 9–13 CPS")
                qFatal("Fresh install is not English");
            sweep("clicker"); click(win, "nav1");
        });
        at(2100, [=] { sweep("log"); click(win, "nav2"); });
        at(2500, [=] { sweep("controls"); click(win, "editStartBinding"); });
        at(2900, [=] {
            sweep("keyboard picker");
            QMetaObject::invokeMethod(win->findChild<QObject *>("keyboardPicker"), "close");
            click(win, "nav3");
        });
        at(3300, [=] { sweep("profiles"); click(win, "nav4"); });
        at(3700, [=] {
            sweep("language");
            if (find(win->contentItem(), "nav4")->property("text").toString() != "Language")
                qFatal("Language tab label missing");
            shot("language-en");
            click(win, "language_ru");
        });
        at(4100, [=] {
            if (language->language() != "ru" || QSettings().value("ui/language").toString() != "ru")
                qFatal("Switch to Russian failed");
            if (find(win->contentItem(), "nav0")->property("text").toString() != QStringLiteral("Кликер") ||
                !engine->modeSummary().startsWith(QStringLiteral("Легит")) ||
                win->property("languagePhase").toReal() < 0.99)
                qFatal("Russian UI not applied");
            assertSettled(win, "language switch to Russian");
            shot("language-ru");
            click(win, "nav0");
        });
        at(4500, [=] {
            if (find(win->contentItem(), "startButton")->property("text").toString() != QStringLiteral("Запустить"))
                qFatal("Russian start button missing");
            shot("clicker-ru");
            click(win, "nav4");
        });
        at(4900, [=] { click(win, "language_en"); });
        at(5300, [=] {
            if (language->language() != "en" || engine->modeSummary() != "Legit · 9–13 CPS") qFatal("Switch back to English failed");
            assertSettled(win, "language switch back to English");
            click(win, "nav0");
        });
        at(5700, [=] { click(win, "limitsButton"); });
        at(6100, [=] {
            sweep("limits");
            qInfo() << "NATIVE_LANGUAGE_UI_PASS (English default, no Cyrillic on 5 pages and 2 dialogs, RU switch, persistence, back to EN)";
            QCoreApplication::quit();
        });
        return;
    }
    // Recording run: the motion sequence at a viewing pace, with no window grabs that
    // would stall frames. Uses the relative step runner so a busy frame cannot bunch steps.
    if (QCoreApplication::arguments().contains("--capture-motion-reel")) {
        const QStringList clicks = {"nav2", "nav3", "nav4", "nav0", "mode1", "mode2", "mode0",
                                    "legitPreset3", "legitPreset1"};
        int t = 2200;
        for (const auto &name : clicks) {
            at(t, [=] { click(win, name); });
            t += 800;
        }
        // Running visuals (preview only): the glow follows the mode hue live.
        at(t, [=] { win->setProperty("glowDemo", true); });
        at(t + 2600, [=] { click(win, "mode1"); });
        at(t + 4600, [=] { click(win, "mode2"); });
        at(t + 6200, [=] { win->setProperty("glowDemo", false); });
        at(t + 7000, [=] { click(win, "mode0"); });
        at(t + 7800, [=] { engine->applyBindings(0, 0, 119, 0); });
        at(t + 9000, [=] { click(win, "dismissError"); });
        at(t + 10000, [=] { click(win, "closeButton"); });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-motion-tests")) {
        // Under --capture-slow, steps after 1600 ms run at 3x: 20 ms here is 60 ms real.
        const auto sceneRect = [=](const QString &name) {
            auto *item = find(win->contentItem(), name);
            if (!item) qFatal("Motion item missing: %s", qPrintable(name));
            return item->mapRectToScene(QRectF(0, 0, item->width(), item->height()));
        };
        const auto near = [](qreal a, qreal b) { return qAbs(a - b) < 0.75; };
        const auto opacity = [=](const QString &name) { return find(win->contentItem(), name)->opacity(); };
        win->installEventFilter(new CloseAudit(win));
        at(1700, [=] {
            assertSettled(win, "after opening");
            const QRectF pill = sceneRect("tabPill"), tab = sceneRect("nav0");
            if (!near(pill.x(), tab.x()) || !near(pill.width(), tab.width())) qFatal("Tab pill is not on the selected tab");
            click(win, "nav2");
            if (!find(win->contentItem(), "page0")->isVisible() || !find(win->contentItem(), "editStartBinding"))
                qFatal("Page change has a blank gap");
        });
        at(1720, [=] { shot("motion-page-mid"); });
        at(1900, [=] {
            if (find(win->contentItem(), "page0")->isVisible() || opacity("page2") < 0.999)
                qFatal("Page transition did not settle");
            const QRectF pill = sceneRect("tabPill"), tab = sceneRect("nav2"), glow = sceneRect("tabGlow");
            if (!near(pill.x(), tab.x()) || !near(pill.width(), tab.width()) || !near(glow.center().x(), pill.center().x()) ||
                !near(glow.width(), pill.width() - 28))
                qFatal("Tab pill/light did not settle on the new tab");
            assertSettled(win, "page change");
            click(win, "nav0");
        });
        at(2100, [=] {
            if (!near(sceneRect("modeSelection").x(), sceneRect("mode0").x())) qFatal("Mode selection misplaced");
            click(win, "mode2");
        });
        at(2110, [=] { shot("motion-mode-mid"); });
        at(2300, [=] {
            const QRectF frame = sceneRect("modeSelection"), target = sceneRect("mode2");
            if (!near(frame.x(), target.x()) || !near(frame.width(), target.width()))
                qFatal("Mode selection did not slide to the chosen tile");
            if (opacity("customBody") < 0.999 || find(win->contentItem(), "legitBody")->isVisible())
                qFatal("Mode bodies did not settle");
        });
        at(2400, [=] {
            assertSettled(win, "mode change");
            click(win, "mode0");
            engine->applyBindings(0, 0, 119, 0); // a real validation error for the banner
        });
        at(2410, [=] { shot("motion-error-rise"); });
        at(2600, [=] {
            auto *banner = find(win->contentItem(), "generalError");
            if (!banner->property("shown").toBool() || banner->opacity() < 0.999) qFatal("Error banner did not rise");
            click(win, "dismissError");
        });
        at(2800, [=] {
            if (find(win->contentItem(), "generalError")->isVisible()) qFatal("Error banner did not leave");
            assertSettled(win, "error banner");
            win->setProperty("glowDemo", true);
        });
        at(2820, [=] { shot("motion-glow-rise"); });
        at(3000, [=] {
            auto *rim = find(win->contentItem(), "auroraLive");
            if (!rim->isVisible() || rim->opacity() < 0.999) qFatal("Aurora did not come up");
            win->setProperty("spinProbe", find(win->contentItem(), "heroCore")->rotation());
            shot("glow-live");
        });
        at(3050, [=] {
            if (near(find(win->contentItem(), "heroCore")->rotation(), win->property("spinProbe").toReal()))
                qFatal("Ring light is not turning while live");
            win->setProperty("glowDemo", false);
        });
        at(3060, [=] { shot("motion-glow-fall"); });
        at(3400, [=] {
            const qreal rest = std::fmod(find(win->contentItem(), "heroCore")->rotation(), 360.0);
            if (rest > 0.5 && rest < 359.5) qFatal("Ring light did not come to rest at the top (%f)", rest);
            assertSettled(win, "glow off");
            click(win, "closeButton");
            // Poll the close on every turn of the event loop instead of at fixed
            // times: the checks run across the whole timeline and cannot race it.
            auto *probe = new QTimer(win);
            auto checks = std::make_shared<int>(0);
            auto stage = std::make_shared<int>(0);
            probe->setInterval(4);
            QObject::connect(probe, &QTimer::timeout, win, [=] {
                const qreal expansion = win->property("expansion").toReal();
                if (expansion <= 0) { probe->stop(); return; }
                const qreal content = win->property("contentReveal").toReal(), shell = win->property("shell").toReal();
                if (!win->property("exiting").toBool() || content > shell + 1e-6)
                    qFatal("Close: content must leave before the shell folds");
                auto *mark = find(win->contentItem(), "cmark");
                const qreal panelW = win->property("panelWidth").toReal(), panelH = win->property("panelHeight").toReal();
                auto *scene = mark->parentItem();
                const qreal ex = (scene->width() - panelW) / 2 + (panelW - mark->width()) / 2 * (1 - shell) + 25 * shell;
                const qreal ey = (scene->height() - panelH) / 2 + 48 * (1 - shell) + 19 * shell;
                if (!near(mark->x(), ex) || !near(mark->y(), ey)) qFatal("Close: the C left the shell corner");
                ++*checks;
                // Pass on evidence gathered, then take one picture; a slow grab can
                // no longer make the close outrun the check.
                if (*stage == 0 && *checks >= 6 && expansion < 0.7) {
                    *stage = 1;
                    qInfo().noquote() << QString("NATIVE_MOTION_UI_PASS (settle audits, overlapping pages, tab pill and light, sliding mode frame, "
                                                 "mode bodies, error rise/leave, aurora up/down, ring spin and rest; close order and C glued "
                                                 "to the shell checked on %1 frames of the close)").arg(*checks);
                    shot("motion-close-fold");
                }
            });
            probe->start();
        });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-adaptive-tests")) {
        at(1600, [=] {
            const QRect available = win->screen()->availableGeometry();
            if (!available.contains(win->geometry()) || win->property("uiScale").toReal() >= 1)
                qFatal("Adaptive small-screen window does not fit its work area");
            shot("adaptive-clicker"); click(win, "nav2");
        });
        at(2100, [=] { click(win, "editStartBinding"); });
        at(2500, [=] {
            auto *popup = win->findChild<QObject *>("keyboardPicker");
            auto *content = popup ? qobject_cast<QQuickItem *>(popup->property("contentItem").value<QObject *>()) : nullptr;
            if (!content) qFatal("Adaptive keyboard content missing");
            const QRectF bounds = content->mapRectToScene(QRectF(0, 0, content->width(), content->height()));
            if (!QRectF(0, 0, win->width(), win->height()).adjusted(-1,-1,1,1).contains(bounds))
                qFatal("Adaptive virtual keyboard is clipped by actual scene bounds");
            shot("adaptive-keyboard"); QMetaObject::invokeMethod(popup, "close");
        });
        at(2800, [=] { click(win, "maximizeButton"); });
        at(3200, [=] {
            if (win->size() != win->screen()->availableGeometry().size()) qFatal("DPI maximize work area mismatch");
            shot("adaptive-maximized");
            qInfo() << "NATIVE_ADAPTIVE_UI_PASS (150% scale, small work area, keyboard fit, maximize)";
            QCoreApplication::quit();
        });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-keyboard-tests")) {
        at(1700, [=] {
            auto *nav = find(win->contentItem(), "nav2");
            const QPointF pos = nav->mapToScene(QPointF(nav->width()/2, nav->height()/2));
            const QPointF global = win->mapToGlobal(pos.toPoint());
            QMouseEvent press(QEvent::MouseButtonPress, pos, global, Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
            QMouseEvent release(QEvent::MouseButtonRelease, pos, global, Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &press); QGuiApplication::sendEvent(win, &release);
            if (nav->property("visualFocus").toBool()) qFatal("Mouse click left a keyboard focus ring");
            QKeyEvent tab(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
            QKeyEvent tabUp(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &tab); QGuiApplication::sendEvent(win, &tabUp);
            auto *focused = win->activeFocusItem();
            if (!focused || !focused->property("visualFocus").toBool())
                qFatal("Keyboard Tab focus ring missing");
        });
        at(1800, [=] {
            click(win, "nav3");
            QTimer::singleShot(20, win, [=] { click(win, "nav1"); });
            QTimer::singleShot(40, win, [=] { click(win, "nav2"); });
        });
        at(2250, [=] {
            if (win->property("displayedPage").toInt() != 2 || find(win->contentItem(), "motionToggle"))
                qFatal("Rapid navigation or motion toggle removal failed");
            click(win, "editStartBinding");
        });
        at(2400, [=] {
            auto *mode = find(win->contentItem(), "combinationMode");
            auto *key = find(win->contentItem(), "keycap75");
            if (!mode || !key) qFatal("Keyboard mode controls missing");
            click(win, "combinationMode");
            QKeyEvent press(QEvent::KeyPress, Qt::Key_Control, Qt::ControlModifier);
            QGuiApplication::sendEvent(win, &press);
            if (!engine->pressedKeys().contains(162)) qFatal("Ctrl live state missing");
        });
        at(2600, [=] { shot("keyboard-ctrl-held"); });
        at(2800, [=] {
            QKeyEvent press(QEvent::KeyPress, Qt::Key_K, Qt::ControlModifier);
            QGuiApplication::sendEvent(win, &press);
            if (!find(win->contentItem(), "keycap75")->property("pressedPhysical").toBool())
                qFatal("Physical key feedback missing");
        });
        at(3000, [=] { shot("keyboard-chord-held"); });
        at(3200, [=] {
            QKeyEvent release(QEvent::KeyRelease, Qt::Key_K, Qt::ControlModifier);
            QKeyEvent ctrlUp(QEvent::KeyRelease, Qt::Key_Control, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &release); QGuiApplication::sendEvent(win, &ctrlUp);
            if (!engine->pressedKeys().isEmpty()) qFatal("Pressed state stuck after release");
            shot("keyboard-chord-released");
            click(win, "singleMode");
            if (!engine->draftKeys().isEmpty()) qFatal("Single mode retained chord draft");
            click(win, "keycap75");
            QKeyEvent num(QEvent::KeyPress, Qt::Key_NumLock, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &num);
            QKeyEvent numUp(QEvent::KeyRelease, Qt::Key_NumLock, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &numUp);
        });
        at(3400, [=] { shot("keyboard-num-off"); });
        at(3600, [=] {
            const auto before = engine->draftKeys();
            QKeyEvent numHome(QEvent::KeyPress, Qt::Key_Home, Qt::KeypadModifier);
            QGuiApplication::sendEvent(win, &numHome);
            if (engine->draftKeys() != before || find(win->contentItem(), "keycap103")->isEnabled())
                qFatal("Num off keypad was not ignored");
            click(win, "applyKeyboard");
            if (engine->config().startChord != QList<int>({75})) qFatal("Single mode apply failed");
        });
        at(3800, [=] { click(win, "editStartBinding"); });
        at(4000, [=] {
            click(win, "combinationMode");
            click(win, "keycap72"); click(win, "keycap89");
            if (engine->draftKeys() != QVariantList({72,89})) qFatal("Mouse H Y lost a key");
            click(win, "keycap72");
            if (engine->draftKeys() != QVariantList({89})) qFatal("Repeated mouse key did not remove");
            click(win, "keycap72"); click(win, "keycap107");
        });
        at(4200, [=] {
            shot("triple-literal-plus");
            click(win, "keycap75");
            if (engine->draftKeys() != QVariantList({89,72,107}) || engine->draftError().isEmpty()) qFatal("Triple key limit failed");
            click(win, "keycap107"); click(win, "keycap163");
            if (engine->draftKeys() != QVariantList({89,72,163})) qFatal("Right Ctrl mouse identity failed");
        });
        at(4400, [=] { shot("triple-side-specific"); });
        at(4600, [=] {
            click(win, "applyKeyboard");
            if (engine->config().startChord != QList<int>({89,72,163})) qFatal("Arbitrary triple did not persist");
        });
        at(4800, [=] { click(win, "editStartBinding"); });
        at(5000, [=] {
            click(win, "singleMode");
            for (auto pair : QList<QPair<int,int>>{{Qt::Key_Left,37},{Qt::Key_Up,38},{Qt::Key_Right,39},{Qt::Key_Down,40},
                {Qt::Key_Home,36},{Qt::Key_End,35},{Qt::Key_PageUp,33},{Qt::Key_PageDown,34},{Qt::Key_Insert,45},{Qt::Key_Delete,46}}) {
                QKeyEvent press(QEvent::KeyPress, pair.first, Qt::NoModifier);
                QKeyEvent release(QEvent::KeyRelease, pair.first, Qt::NoModifier);
                QGuiApplication::sendEvent(win, &press); QGuiApplication::sendEvent(win, &release);
                if (engine->draftKeys() != QVariantList({pair.second}) || !engine->pressedKeys().isEmpty()) qFatal("Navigation group capture failed");
            }
        });
        at(5200, [=] { shot("navigation-delete-selected"); });
        at(5400, [=] {
            click(win, "applyKeyboard");
            if (engine->config().startChord != QList<int>({46})) qFatal("Navigation key did not persist");
        });
        at(5600, [=] { click(win, "editStartBinding"); });
        at(5800, [=] {
            auto *key = find(win->contentItem(), "keycap75"); key->forceActiveFocus();
            auto *before = win->activeFocusItem();
            QKeyEvent down(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
            QKeyEvent up(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
            QGuiApplication::sendEvent(win,&down); QGuiApplication::sendEvent(win,&up);
            if (engine->draftKeys() != QVariantList{9} || !engine->pressedKeys().isEmpty() ||
                win->activeFocusItem() != before || !find(win->contentItem(),"keycap9")->property("selected").toBool())
                qFatal("Tab navigated instead of selecting physical key");
        });
        at(6000, [=] {
            shot("tab-single-selected"); click(win,"applyKeyboard");
            if (engine->config().startChord != QList<int>{9}) qFatal("Tab single did not persist");
        });
        at(6200, [=] { click(win,"editStartBinding"); });
        at(6400, [=] {
            click(win,"combinationMode");
            auto *key = find(win->contentItem(),"keycap75"); key->forceActiveFocus();
            auto *before = win->activeFocusItem();
            QKeyEvent shift(QEvent::KeyPress,Qt::Key_Shift,Qt::ShiftModifier);
            QKeyEvent tab(QEvent::KeyPress,Qt::Key_Backtab,Qt::ShiftModifier);
            QKeyEvent tabUp(QEvent::KeyRelease,Qt::Key_Backtab,Qt::ShiftModifier);
            QKeyEvent shiftUp(QEvent::KeyRelease,Qt::Key_Shift,Qt::NoModifier);
            for (auto *event : {&shift,&tab,&tabUp,&shiftUp}) QGuiApplication::sendEvent(win,event);
            if (engine->draftKeys() != QVariantList({160,9}) || !engine->pressedKeys().isEmpty() || win->activeFocusItem()!=before)
                qFatal("Shift Tab traversed instead of recording chord");
        });
        at(6600, [=] {
            shot("tab-shift-selected"); click(win,"applyKeyboard");
            if (engine->config().startChord != QList<int>({160,9})) qFatal("Shift Tab did not persist");
        });
        at(6800, [=] { click(win,"editStartBinding"); });
        at(7000, [=] {
            engine->beginBindingDraft({},true);
            engine->processWindowsKey(163,0x21d,true,false,true,true,77);
            engine->processWindowsKey(18,0x38,true,false,true,true,77);
            if (engine->draftKeys()!=QVariantList{165} || engine->pressedKeys()!=QVariantList{165})
                qFatal("Raw AltGr metadata fabricated Ctrl in UI");
        });
        at(7200, [=] { shot("altgr-only-held"); });
        at(7400, [=] {
            engine->processWindowsKey(163,0x21d,true,false,false,true,77);
            engine->processWindowsKey(18,0x38,true,false,false,true,77);
            if (!engine->pressedKeys().isEmpty()) qFatal("AltGr held state stuck");
            engine->processWindowsKey(17,0x1d,true,false,true,true,77);
            engine->processWindowsKey(18,0x38,true,false,true,true,77);
            if (engine->pressedKeys()!=QVariantList({163,165})) qFatal("Genuine Ctrl R Alt R lost");
        });
        at(7600, [=] { shot("genuine-ctrl-alt-held"); click(win,"cancelKeyboard"); });
        at(7800, [=] {
            if (!engine->pressedKeys().isEmpty() || !engine->draftError().isEmpty()) qFatal("Cancel retained input state");
        });
        at(8000, [=] { click(win,"editStartBinding"); });
        at(8200, [=] {
            click(win,"singleMode");
            QKeyEvent down(QEvent::KeyPress,Qt::Key_AltGr,Qt::ControlModifier | Qt::AltModifier | Qt::GroupSwitchModifier,0x138,165,0);
            QKeyEvent up(QEvent::KeyRelease,Qt::Key_AltGr,Qt::NoModifier,0x138,165,0);
            QCoreApplication::sendEvent(win,&down); QCoreApplication::sendEvent(win,&up);
            if (engine->draftKeys()!=QVariantList{165}) qFatal("Qt-only physical AltGr not selected as standalone");
            click(win,"applyKeyboard");
            if (engine->config().startChord!=QList<int>{165}) qFatal("AltGr standalone failed to apply");
        });
        at(8400, [=] { shot("altgr-standalone-applied"); click(win,"editStartBinding"); });
        at(8600, [=] {
            if (engine->draftKeys()!=QVariantList{165} || engine->captureCombination()) qFatal("AltGr lost after reopening");
            shot("altgr-standalone-reopened"); click(win,"cancelKeyboard");
        });
        at(8800, [=] { click(win,"editStopBinding"); });
        at(9000, [=] {
            click(win,"keycap44"); click(win,"applyKeyboard");
            if (engine->config().stopChord!=QList<int>{44} || engine->stopLabel()!="PrintScreen")
                qFatal("PrintScreen mouse apply/name regression");
        });
        at(9200, [=] {
            shot("printscreen-applied"); click(win,"editStopBinding");
        });
        at(9400, [=] {
            if (engine->draftKeys()!=QVariantList{44}) qFatal("PrintScreen lost after reopening");
            engine->processWindowsKey(16,0x2a,true,false,true,true,77); // fake PrintScreen Shift
            engine->processWindowsKey(44,0x37,true,false,true,true,77);
            engine->processWindowsKey(44,0x37,true,false,false,true,77);
            engine->processWindowsKey(16,0x2a,true,false,false,true,77);
            if (engine->draftKeys()!=QVariantList{44} || !engine->pressedKeys().isEmpty()) qFatal("PrintScreen packet selection changed identity");
            shot("printscreen-reopened"); click(win,"applyKeyboard");
        });
        at(9600, [=] { click(win,"editStartBinding"); });
        at(9800, [=] {
            click(win,"combinationMode"); click(win,"keycap165"); click(win,"keycap72");
            click(win,"applyKeyboard");
            if (engine->config().startChord!=QList<int>({165,72})) qFatal("AltGr mouse chord failed apply");
        });
        at(10000, [=] { shot("altgr-chord-applied"); click(win,"editStartBinding"); });
        at(10200, [=] {
            if (engine->draftKeys()!=QVariantList({165,72}) || !engine->captureCombination()) qFatal("AltGr chord lost after reopening");
            shot("altgr-chord-reopened"); click(win,"cancelKeyboard");
        });
        at(10400, [=] { click(win,"editStartBinding"); });
        at(10600, [=] {
            click(win,"singleMode"); click(win,"combinationMode");
            engine->processWindowsKey(18,0x38,true,false,true,true,77);
            QKeyEvent down(QEvent::KeyPress,Qt::Key_AltGr,Qt::ControlModifier | Qt::AltModifier,0x138,165,0);
            QCoreApplication::sendEvent(win,&down);
            if (engine->draftKeys()!=QVariantList{165} || engine->pressedKeys()!=QVariantList{165}) qFatal("Raw plus Qt AltGr selected twice");
        });
        at(10700, [=] { shot("altgr-dual-source-held"); });
        at(10800, [=] {
            engine->processWindowsKey(18,0x38,true,false,false,true,77);
            QKeyEvent up(QEvent::KeyRelease,Qt::Key_AltGr,Qt::NoModifier,0x138,165,0);
            QCoreApplication::sendEvent(win,&up);
            if (!engine->pressedKeys().isEmpty() || engine->draftKeys()!=QVariantList{165}) qFatal("AltGr dual source release changed draft");
            click(win,"applyKeyboard");
            if (engine->config().startChord!=QList<int>{165}) qFatal("Dual-source AltGr apply failed");
        });
        at(11000, [=] {
            shot("altgr-physical-capture-applied");
            qInfo() << "NATIVE_KEYBOARD_UI_PASS (Tab, navigation, triple, Qt-only AltGr capture/apply/reopen, dual-source AltGr select-once/release/apply, mouse chord, PrintScreen, cancel)";
            QCoreApplication::quit();
        });
        return;
    }
    if (QCoreApplication::arguments().contains("--capture-error")) {
        at(600, [=] { shot("error"); });
        at(850, [] {
            qInfo() << "NATIVE_ERROR_CAPTURE_PASS";
            QCoreApplication::quit();
        });
        return;
    }
    at(300, [=] { shot("startup"); });
    at(650, [=] { shot("transition-mid"); });
    at(800, [=] { shot("transition-flight"); });
    at(1000, [=] { shot("transition"); });
    at(1900, [=] { engine->setIntervalMs(5); });
    at(2200, [=] {
        shot("clicker");
        if (engine->measuredCps() >= 0)
            qFatal("Idle measured rate fabricated");
        if (engine->clickMode() != 0) qFatal("Fresh profile is not Legit");
        click(win, "mode1");
    });
    at(2300, [=] {
        // Exercise the native segmented choices with actual key events, not clicks only.
        for (const auto &pair : {qMakePair(QString("presetsFrame"), QStringList{"preset10", "preset50", "preset100", "preset200", "preset500"}),
                                 qMakePair(QString("modeFrame"), QStringList{"mode0", "mode1", "mode2"}),
                                 qMakePair(QString("mouseFrame"), QStringList{"mouse0", "mouse1", "mouse2"})}) {
            auto *frame = find(win->contentItem(), pair.first);
            if (!frame) qFatal("Missing segmented frame");
            for (const auto &name : pair.second) {
                auto *button = find(win->contentItem(), name);
                if (!button || button->width() < 44 || button->height() < 44)
                    qFatal("Segmented target below 44px");
                const QPointF pos = button->mapToItem(frame, QPointF(0, 0));
                if (pos.x() < 0 || pos.y() < 0 || pos.x() + button->width() > frame->width() + .1 ||
                    pos.y() + button->height() > frame->height() + .1)
                    qFatal("Segmented target clipped");
            }
        }
        const auto sendKey = [=](int key) {
            QKeyEvent press(QEvent::KeyPress, key, Qt::NoModifier);
            QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier);
            QGuiApplication::sendEvent(win, &press);
            QGuiApplication::sendEvent(win, &release);
        };
        find(win->contentItem(), "preset10")->forceActiveFocus();
        sendKey(Qt::Key_Right);
        if (!find(win->contentItem(), "preset50")->hasActiveFocus()) qFatal("Preset arrow navigation failed");
        sendKey(Qt::Key_Space);
        if (engine->intervalMs() != 20) qFatal("Preset keyboard activation failed");
        click(win, "preset200");
        find(win->contentItem(), "mouse0")->forceActiveFocus();
        sendKey(Qt::Key_Right);
        if (!find(win->contentItem(), "mouse1")->hasActiveFocus()) qFatal("Mouse choice arrow navigation failed");
        sendKey(Qt::Key_Space);
        if (engine->mouseButton() != 1) qFatal("Mouse choice keyboard activation failed");
        click(win, "mouse0");
        click(win, "mode0");
        if (engine->clickMode() != 0 || engine->intervalMs() < 5) qFatal("Return to Legit failed");
        auto *start = find(win->contentItem(), "startButton");
        if (!start || start->property("text").toString() != QCoreApplication::translate("SettingsPanel", "Запустить") ||
            start->property("hint").isValid() || !start->property("tip").toString().isEmpty())
            qFatal("Activation hint returned to the run button");
        // The window icon must load from the embedded .ico with every size it ships.
        const QList<QSize> iconSizes = QGuiApplication::windowIcon().availableSizes();
        for (int side : {16, 20, 24, 32, 40, 48, 64, 128, 256})
            if (!iconSizes.contains(QSize(side, side))) qFatal("Window icon is missing the %dpx entry", side);
        qInfo() << "NATIVE_ICON_PASS (window icon loaded from app.ico, 9 sizes 16-256)";
        qInfo() << "NATIVE_CLEAN_UI_PASS (no Beta/profile/footer clutter, no activation badge or tooltip)";
        qInfo() << "NATIVE_SEGMENTED_UI_PASS (44px targets, contained geometry, arrow focus, Space activation)";
    });
    at(2400, [=] { click(win, "nav1"); });
    at(2800, [=] { shot("session"); });
    at(3000, [=] { click(win, "nav2"); });
    at(3400, [=] { shot("settings"); });
    at(3600, [=] { click(win, "editStartBinding"); });
    at(4000, [=] { shot("keyboard"); });
    at(4200, [=] {
        click(win, "combinationMode");
        click(win, "keycap75");
        click(win, "keycap162");
    });
    at(4600, [=] { shot("keyboard-selected"); });
    at(4800, [=] {
        click(win, "applyKeyboard");
        if (engine->config().startChord != QList<int>({75,162}))
            qFatal("Binding not applied");
    });
    at(5000, [=] { shot("binding-saved"); });
    at(5200, [=] { click(win, "nav3"); });
    at(5400, [=] { click(win, "saveConfig"); });
    at(5600, [=] { shot("config-save"); });
    at(5800, [=] {
        auto *field = find(win->contentItem(), "profileNameField");
        if (!field)
            qFatal("Missing name field");
        field->setProperty("text", QStringLiteral("Test · 200 / s"));
        click(win, "confirmSaveConfig");
        if (configs->profiles().isEmpty())
            qFatal("Profile not saved");
    });
    at(6200, [=] {
        auto id = configs->profiles()[0].toMap()["id"].toString();
        click(win, "profile_" + id);
    });
    at(6400, [=] { shot("configs"); });
    at(6600, [=] { click(win, "deleteConfig"); });
    at(6800, [=] { shot("config-delete"); });
    at(7000, [=] {
        click(win, "confirmDeleteConfig");
        if (!configs->profiles().isEmpty())
            qFatal("Profile not deleted");
    });
    at(7200, [=] { click(win, "nav0"); });
    at(7400, [=] { click(win, "limitsButton"); });
    at(7800, [=] { shot("limits"); });
    at(8000, [=] { engine->setCountLimit(200); });
    at(8200, [=] { shot("limits-count"); });
    at(8400, [=] {
        auto *popup = win->findChild<QObject *>("limitsPopup");
        if (!popup || !QMetaObject::invokeMethod(popup, "close"))
            qFatal("Missing limits popup");
    });
    at(8600, [=] { click(win, "nav2"); });
    at(8800, [=] { click(win, "resetBindings"); });
    at(9000, [=] {
        if (engine->startKey() != 117 || engine->stopKey() != 119)
            qFatal("Reset bindings failed");
    });
    at(9400, [=] {
        click(win, "addStartBinding");
    });
    at(9700, [=] {
        click(win, "keycap76");
        click(win, "applyKeyboard");
        if (engine->startBindings().size() != 2)
            qFatal("Second start binding not appended");
    });
    at(10000, [=] {
        shot("multi-bindings");
        click(win, "addStopBinding");
    });
    at(10300, [=] {
        click(win, "keycap76");
        click(win, "applyKeyboard");
    });
    at(10600, [=] {
        shot("binding-conflict");
        if (engine->stopBindings().size() != 1 || engine->draftError().isEmpty() || !engine->error().isEmpty())
            qFatal("Conflict changed bindings or leaked to general banner");
        auto *popup = win->findChild<QObject *>("keyboardPicker");
        if (!popup || !QMetaObject::invokeMethod(popup, "close"))
            qFatal("Missing keyboard popup");
    });
    at(10900, [=] {
        if (!engine->draftError().isEmpty() || !engine->error().isEmpty()) qFatal("Cancel left conflict banner behind");
        engine->applyBindings(0,0,119,0); // Exercise a genuine general API validation error.
    });
    at(11000, [=] {
        auto *banner=find(win->contentItem(),"generalError");
        if (!banner || !banner->isVisible() || engine->error().isEmpty()) qFatal("General error not shown");
        shot("dismissible-error"); click(win,"dismissError");
    });
    at(11100, [=] {
        if (!engine->error().isEmpty() || find(win->contentItem(),"generalError")->property("shown").toBool()) qFatal("Error dismissal failed");
        engine->resetBindings();
        shot("error-dismissed");
        qInfo() << "NATIVE_ERROR_LIFECYCLE_PASS (local conflict, cancel clears, general error closes)";
    });
    at(11200, [=] {
        for (int i = 1; i < 8; ++i) {
            if (!engine->applyBindingSlot(false, i, 64 + i, 0) ||
                !engine->applyBindingSlot(true, i, 71 + i, 0))
                qFatal("Maximum binding fixture failed");
        }
    });
    at(11600, [=] { shot("maximum-bindings"); });
    at(11900, [=] {
        if (!engine->removeBinding(false, 0) || engine->startKey() != 65)
            qFatal("Primary promotion failed");
        engine->resetBindings();
        click(win, "nav3");
    });
    at(12200, [=] {
        // Offscreen animation clocks can lag wall time under compiler load. Wait for
        // the actual page transition, rather than blessing a blank captured frame.
        auto *settled = new QTimer(win);
        settled->setInterval(50);
        QObject::connect(settled, &QTimer::timeout, win, [=, attempts = 0]() mutable {
            if (++attempts > 40)
                qFatal("Config page transition did not settle");
            if (win->property("pagePhase").toReal() < 0.99)
                return;
            shot("empty-configs");
            settled->stop();
            qInfo() << "NATIVE_EXTENDED_UI_PASS (keyboard, modifiers, apply, reset, save, select, "
                       "delete, limits, always-on animation, append, conflict, maximum bindings, "
                       "promotion, settled page)";
            QCoreApplication::quit();
        });
        settled->start();
    });
}
