#include "ClickController.h"
#include "ConfigStore.h"
#include "Timing.h"
#include "PhysicalKeyboard.h"
#include "ClickPattern.h"
#include <cmath>
#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QKeyEvent>
#include <QSettings>
#include <QTemporaryDir>
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QTemporaryDir temp;
    qputenv("XDG_CONFIG_HOME", temp.path().toUtf8());
    app.setOrganizationName("ObsidianTest");
    app.setApplicationName("Validation");
    QSettings().clear();
    int checks = 0;
    auto check = [&](bool ok, const char *label) {
        ++checks;
        if (!ok)
            qFatal("FAIL: %s", label);
    };
    ClickController e;
    check(e.intervalMs() == 100, "default interval");
    e.setIntervalMs(5);
    check(e.intervalMs() == 5, "minimum interval");
    e.setIntervalMs(4);
    check(e.intervalMs() == 5, "reject interval4");
    e.setIntervalMs(10001);
    check(e.intervalMs() == 5, "reject interval overflow");
    e.setIntervalMs(10000);
    check(e.intervalMs() == 10000, "maximum interval");
    e.setDurationSec(3600);
    e.setDurationSec(3601);
    check(e.durationSec() == 3600, "duration bounds");
    e.setMouseButton(2);
    check(e.mouseButton() == 2, "middle mouse");
    e.setMouseButton(3);
    check(e.mouseButton() == 2, "reject invalid mouse");
    check(e.applyBindings(65, 1, 66, 1), "custom Ctrl A/B");
    check(!e.applyBindings(65, 1, 65, 1), "duplicate bindings rejected");
    check(e.startKey() == 65 && e.stopKey() == 66, "failed binding preserves both");
    check(!e.applyBindings(0x7b, 0, 66, 0), "F12 rejected");
    check(!e.applyBindings(46, 3, 66, 0), "CtrlAltDel rejected");
    check(e.resetBindings(), "reset bindings");
    check(e.startKey() == 0x75 && e.stopKey() == 0x77, "reset defaults");
    check(e.clicks() == 0 && e.measuredCps() < 0 && e.averageCps() < 0,
          "no fabricated measured rate");
    e.setIntervalMs(5);
    e.setHoldMs(5);
    check(e.holdMs() == 1, "hold shorter than interval");
    e.setCountLimit(200);
    check(e.countLimit() == 200, "count limit");
    e.setBindingEditor(true);
    e.setCaptureCombination(true);
    QKeyEvent physical(QEvent::KeyPress, Qt::Key_K, Qt::ControlModifier | Qt::ShiftModifier);
    QObject sink;
    QCoreApplication::sendEvent(&sink, &physical);
    check(e.draftKeys() == QVariantList{75}, "Qt modifier mask cannot fabricate held Ctrl/Shift");
    check(e.pressedKeys().contains(75), "held main key is visible");
    QKeyEvent released(QEvent::KeyRelease, Qt::Key_K, Qt::ControlModifier | Qt::ShiftModifier);
    QCoreApplication::sendEvent(&sink, &released);
    check(!e.pressedKeys().contains(75), "key release clears live state");
    QKeyEvent ctrl(QEvent::KeyPress, Qt::Key_Control, Qt::ControlModifier);
    QCoreApplication::sendEvent(&sink, &ctrl);
    check(e.pressedKeys().contains(162), "Ctrl visible before a main key");
    check(e.draftKeys() == QVariantList({75, 162}), "modifier extends physical draft without replacing main key");
    QKeyEvent shift(QEvent::KeyPress, Qt::Key_Shift, Qt::ShiftModifier | Qt::ControlModifier);
    QCoreApplication::sendEvent(&sink, &shift);
    check(e.pressedKeys().contains(160) && e.pressedKeys().contains(162), "simultaneous modifiers visible");
    QKeyEvent ctrlUp(QEvent::KeyRelease, Qt::Key_Control, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &ctrlUp);
    check(!e.pressedKeys().contains(162) && e.pressedKeys().contains(160), "independent modifier release");
    QEvent deactivate(QEvent::ApplicationDeactivate);
    QCoreApplication::sendEvent(&sink, &deactivate);
    check(e.pressedKeys().isEmpty(), "deactivate clears held keys");
    e.setCaptureCombination(false);
    QCoreApplication::sendEvent(&sink, &physical);
    check(e.draftKeys() == QVariantList{75}, "single mode ignores chord modifiers");
    e.setCaptureCombination(true);
#ifndef Q_OS_WIN
    QKeyEvent numLock(QEvent::KeyPress, Qt::Key_NumLock, Qt::NoModifier);
    const auto beforeLock = e.draftKeys();
    QCoreApplication::sendEvent(&sink, &numLock);
    check(!e.numLockOn() && e.draftKeys() == beforeLock, "Num Lock toggle never becomes candidate");
    QKeyEvent padHome(QEvent::KeyPress, Qt::Key_Home, Qt::KeypadModifier);
    QCoreApplication::sendEvent(&sink, &padHome);
    check(e.draftKeys() == beforeLock && !e.pressedKeys().contains(103), "Num off ignores keypad navigation");
    QKeyEvent home(QEvent::KeyPress, Qt::Key_Home, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &home);
    check(e.draftKeys() == QVariantList{36}, "dedicated Home remains assignable with Num off");
    QKeyEvent lockRelease(QEvent::KeyRelease, Qt::Key_NumLock, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &lockRelease);
    QCoreApplication::sendEvent(&sink, &numLock);
    QKeyEvent pad7(QEvent::KeyPress, Qt::Key_7, Qt::KeypadModifier);
    QCoreApplication::sendEvent(&sink, &pad7);
    check(e.numLockOn() && e.draftKeys() == QVariantList({36, 103}), "Num on captures keypad digit distinctly");
    QKeyEvent pad7Up(QEvent::KeyRelease, Qt::Key_7, Qt::KeypadModifier);
    QCoreApplication::sendEvent(&sink, &pad7Up);
    check(!e.pressedKeys().contains(103), "keypad release clears key");
    QKeyEvent bracket(QEvent::KeyPress, Qt::Key_BracketLeft, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &bracket);
    check(e.draftKeys() == QVariantList({36, 103, 219}), "OEM punctuation maps to virtual keyboard");
#endif
    QKeyEvent aDown(QEvent::KeyPress, Qt::Key_A, Qt::NoModifier);
    QKeyEvent bDown(QEvent::KeyPress, Qt::Key_B, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &aDown); QCoreApplication::sendEvent(&sink, &bDown);
    check(e.pressedKeys().contains(65) && e.pressedKeys().contains(66), "multiple held primary keys visible");
    const auto beforeRepeat = e.draftKeys();
    QKeyEvent repeat(QEvent::KeyPress, Qt::Key_C, Qt::NoModifier, QString(), true);
    QCoreApplication::sendEvent(&sink, &repeat);
    check(e.draftKeys() == beforeRepeat && !e.pressedKeys().contains(67), "auto-repeat does not add phantom keys");
#ifndef Q_OS_WIN
    QKeyEvent padEnter(QEvent::KeyPress, Qt::Key_Enter, Qt::KeypadModifier);
    QCoreApplication::sendEvent(&sink, &padEnter);
    check(e.pressedKeys().contains(269) && !e.pressedKeys().contains(13), "keypad Enter feedback distinct from main Enter");
    QKeyEvent rightCtrl(QEvent::KeyPress, Qt::Key_Control, Qt::ControlModifier, 105, 0, 0);
    QCoreApplication::sendEvent(&sink, &rightCtrl);
    check(e.pressedKeys().contains(163) && !e.pressedKeys().contains(162), "right Ctrl feedback has its own keycap");
#endif
    e.setBindingEditor(false);
    check(e.pressedKeys().isEmpty(), "editor close clears held keys");
    const auto closedDraft = e.draftKeys();
    QCoreApplication::sendEvent(&sink, &physical);
    check(e.draftKeys() == closedDraft, "physical capture off after editor close");
    e.setBindingEditor(true);
    e.beginBindingDraft({}, false);
    QKeyEvent tabDown(QEvent::KeyPress, Qt::Key_Tab, Qt::NoModifier);
    QKeyEvent tabUp(QEvent::KeyRelease, Qt::Key_Tab, Qt::NoModifier);
    check(QCoreApplication::sendEvent(&sink, &tabDown), "editor consumes Tab press");
    check(e.draftKeys() == QVariantList{9} && e.pressedKeys().contains(9), "physical Tab selected and held");
    QCoreApplication::sendEvent(&sink, &tabUp);
    check(e.draftKeys() == QVariantList{9} && !e.pressedKeys().contains(9), "Tab release retains draft only");
    e.setCaptureCombination(true);
    QCoreApplication::sendEvent(&sink, &shift);
    QKeyEvent backTab(QEvent::KeyPress, Qt::Key_Backtab, Qt::ShiftModifier);
    QKeyEvent backTabUp(QEvent::KeyRelease, Qt::Key_Backtab, Qt::ShiftModifier);
    QCoreApplication::sendEvent(&sink, &backTab);
    check(e.draftKeys() == QVariantList({160,9}), "Shift Backtab adds physical Shift and Tab");
    QKeyEvent tabRepeat(QEvent::KeyPress, Qt::Key_Backtab, Qt::ShiftModifier, QString(), true);
    QCoreApplication::sendEvent(&sink, &tabRepeat);
    check(e.draftKeys() == QVariantList({160,9}), "Tab auto repeat does not toggle selection");
    QCoreApplication::sendEvent(&sink, &backTabUp);
    QKeyEvent shiftUp(QEvent::KeyRelease, Qt::Key_Shift, Qt::NoModifier);
    QCoreApplication::sendEvent(&sink, &shiftUp);
    check(e.pressedKeys().isEmpty(), "Shift Tab release clears both live keys");
    QCoreApplication::sendEvent(&sink, &tabDown); QCoreApplication::sendEvent(&sink, &tabUp);
    check(e.draftKeys() == QVariantList{160}, "reselecting physical Tab removes it from chord");
    e.selectDraftKey(9);
    check(e.draftKeys() == QVariantList({160,9}), "virtual Tab uses same draft");
    check(e.applyChordSlot(false,0,e.draftKeys()), "apply physical Shift Tab chord");
    check(e.config().startChord == QList<int>({160,9}), "Tab identity preserved on apply");
    e.setBindingEditor(false); e.resetBindings();
    // Regression: apply standalone physical modifiers, not just their keycap feedback.
    for (int key : {160,161,162,163,164,165,44}) for (bool stopAction : {false,true}) {
        check(e.resetBindings(), "standalone regression fixture reset");
        e.setBindingEditor(true); e.beginBindingDraft({},false);
        e.processPhysicalKey(key,true,true); e.processPhysicalKey(key,false,true);
        check(e.draftKeys()==QVariantList{key}, "standalone modifier or PrintScreen selected");
        check(e.applyChordSlot(stopAction,0,e.draftKeys()), "standalone modifier or PrintScreen applies");
        e.setBindingEditor(false);
        const auto actual=stopAction?e.config().stopChord:e.config().startChord;
        check(actual==QList<int>{key}, "standalone binding saved in controller");
        ClickConfig roundtrip; QString why;
        check(Configuration::decode(Configuration::encode(e.config()),roundtrip,why), "standalone binding JSON roundtrip");
        check((stopAction?roundtrip.stopChord:roundtrip.startChord)==QList<int>{key}, "standalone exact side survives JSON");
        ClickController reloaded;
        check((stopAction?reloaded.config().stopChord:reloaded.config().startChord)==QList<int>{key}, "standalone exact side survives settings reload");
    }
    e.resetBindings();
    check(e.applyBindings(165,0,119,0), "AltGr standalone accepted by single-key compatibility API");
    check(e.startKey()==165 && e.config().startChord==QList<int>{165}, "AltGr standalone compatibility binding retained explicitly");
    for (int key : {160,161,162,163,164,165,44}) {
        check(e.resetBindings() && e.applyBindingSlot(false,1,key,0), "modifier/PrintScreen append compatibility route");
        check(e.startBindings()[1].toMap()["keys"].toList()==QVariantList{key}, "alternate route retains explicit physical identity");
        check(Configuration::keyName(key)!="?", "every physical modifier and PrintScreen has name");
    }
    check(Configuration::keyName(44)=="PrintScreen", "PrintScreen has stable non-question-mark label");
    e.setBindingEditor(true); e.beginBindingDraft({},false);
    QKeyEvent altOverride(QEvent::ShortcutOverride, Qt::Key_AltGr, Qt::GroupSwitchModifier);
    altOverride.ignore(); QCoreApplication::sendEvent(&sink,&altOverride);
    check(altOverride.isAccepted() && e.draftKeys().isEmpty(), "editor reserves AltGr shortcut without fabricating input");
    e.setBindingEditor(false);
    QKeyEvent ordinaryOverride(QEvent::ShortcutOverride, Qt::Key_AltGr, Qt::GroupSwitchModifier);
    ordinaryOverride.ignore(); QCoreApplication::sendEvent(&sink,&ordinaryOverride);
    check(!ordinaryOverride.isAccepted(), "closed editor does not reserve AltGr shortcut");
    e.resetBindings();
    check(PhysicalKeyboard::qtRightAlt(Qt::Key_AltGr,0,0,true), "explicit Qt AltGr accepted on Windows");
    check(PhysicalKeyboard::qtRightAlt(Qt::Key_AltGr,0,0,false), "explicit Qt AltGr accepted by native test adapter");
    check(PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,165,0x38,true), "Qt VK_RMENU accepted without packed scan");
    check(PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,18,0x138,true), "Qt extended right Alt scan accepted");
    check(PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,18,0xe038,true), "Qt E0-prefixed right Alt scan accepted");
    check(!PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,164,0x38,true), "left Alt is never inferred to be AltGr");
    check(!PhysicalKeyboard::qtRightAlt(Qt::Key_Control,163,0x11d,true), "right Ctrl is not consumed by AltGr bridge");
    check(!PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,18,0,true), "ambiguous generic Alt is not forced right");
    check(!PhysicalKeyboard::qtRightAlt(Qt::Key_H,165,0x138,true), "main key with stale Alt metadata is not AltGr");
    check(!PhysicalKeyboard::qtRightAlt(Qt::Key_Alt,165,0x138,false), "Windows-native fields are not interpreted as X11 metadata");
    // A single physical AltGr may arrive through Raw Input and Qt in either order.
    // Both sources must select once, release independently, and never infer Ctrl.
    auto qtAltGr = [&](bool down, bool repeat = false) {
        QKeyEvent event(down ? QEvent::KeyPress : QEvent::KeyRelease, Qt::Key_AltGr,
                        Qt::ControlModifier | Qt::AltModifier | Qt::GroupSwitchModifier,
                        0x138, 165, 0, QString(), repeat);
        QCoreApplication::sendEvent(&sink, &event);
    };
    for (bool qtFirst : {false,true}) for (bool qtReleaseFirst : {false,true}) {
        e.setBindingEditor(false); e.setBindingEditor(true); e.beginBindingDraft({},true);
        auto raw = [&](bool down) { e.processWindowsKey(18,0x38,true,false,down,true,777); };
        if (qtFirst) { qtAltGr(true); raw(true); } else { raw(true); qtAltGr(true); }
        check(e.draftKeys()==QVariantList{165}, "two AltGr delivery sources select exactly once");
        check(e.pressedKeys()==QVariantList{165}, "AltGr modifiers never manufacture Ctrl or Alt L");
        raw(true); qtAltGr(true,true);
        check(e.draftKeys()==QVariantList{165}, "AltGr repeats do not toggle the draft");
        if (qtReleaseFirst) { qtAltGr(false); } else { raw(false); }
        check(e.pressedKeys()==QVariantList{165}, "second AltGr source retains live hold until its release");
        if (qtReleaseFirst) { raw(false); } else { qtAltGr(false); }
        check(e.pressedKeys().isEmpty() && e.draftKeys()==QVariantList{165}, "AltGr release clears feedback but retains selection");
        qtAltGr(true); qtAltGr(false);
        check(e.draftKeys().isEmpty(), "new Qt-only AltGr press toggles selection once");
        qtAltGr(true); qtAltGr(false);
        check(e.applyChordSlot(false,0,e.draftKeys()) && e.config().startChord==QList<int>{165}, "Qt AltGr selection applies as a real binding");
        e.resetBindings();
    }
    e.setBindingEditor(true); e.beginBindingDraft({},false);
    qtAltGr(true); qtAltGr(false);
    check(e.draftKeys()==QVariantList{165} && e.pressedKeys().isEmpty(), "Qt-only AltGr fallback works without raw make or break");
    e.beginBindingDraft({},true);
    e.processWindowsKey(17,0x1d,true,false,true,true,777); qtAltGr(true);
    check(e.draftKeys()==QVariantList({163,165}), "real right Ctrl survives Qt AltGr bridge");
    QCoreApplication::sendEvent(&sink,&deactivate);
    check(e.pressedKeys().isEmpty(), "deactivation clears raw and Qt AltGr holds");
    e.beginBindingDraft({},true); qtAltGr(true); qtAltGr(false);
    check(e.draftKeys()==QVariantList{165}, "AltGr recaptures after deactivation");
    e.setBindingEditor(false); const auto altGrClosedDraft=e.draftKeys();
    qtAltGr(true); qtAltGr(false);
    check(e.draftKeys()==altGrClosedDraft && e.pressedKeys().isEmpty(), "Qt bridge is editor only");
    e.resetBindings();
    // One normalization table drives both Windows Raw Input and these cases.
    const QList<QList<int>> nativeCases{
        {17,0x1d,0,162},{17,0x1d,1,163},{163,0,0,163},
        {18,0x38,0,164},{18,0x38,1,165},{165,0,0,165},
        {16,0x2a,0,160},{16,0x36,0,161},
        {38,0x48,1,38},{40,0x50,1,40},{37,0x4b,1,37},{39,0x4d,1,39},
        {45,0x52,1,45},{46,0x53,1,46},{36,0x47,1,36},{35,0x4f,1,35},
        {33,0x49,1,33},{34,0x51,1,34},
        {36,0x47,0,103},{45,0x52,0,96},{46,0x53,0,110},
        {13,0x1c,0,13},{13,0x1c,1,269},{111,0x35,1,111},
        {106,0x37,0,106},{107,0x4e,0,107},{109,0x4a,0,109},
        {65,0x23,0,72},{0,0x15,0,89},{187,0x0d,0,187},
        {144,0x45,0,144},{145,0x46,0,145},{20,0x3a,0,20},
        {44,0x37,1,44},{16,0x2a,1,0},{255,0xff,0,0}};
    for (const auto &c : nativeCases)
        check(PhysicalKeyboard::windowsKey(c[0],c[1],c[2],false)==c[3], "native identity matrix");
    const QList<QPair<int,int>> everyPlainScan{{0x1,27},{0x2,49},{0x3,50},{0x4,51},{0x5,52},{0x6,53},{0x7,54},{0x8,55},{0x9,56},{0xa,57},{0xb,48},{0xc,189},{0xd,187},{0xe,8},{0xf,9},{0x10,81},{0x11,87},{0x12,69},{0x13,82},{0x14,84},{0x15,89},{0x16,85},{0x17,73},{0x18,79},{0x19,80},{0x1a,219},{0x1b,221},{0x1c,13},{0x1e,65},{0x1f,83},{0x20,68},{0x21,70},{0x22,71},{0x23,72},{0x24,74},{0x25,75},{0x26,76},{0x27,186},{0x28,222},{0x29,192},{0x2b,220},{0x2c,90},{0x2d,88},{0x2e,67},{0x2f,86},{0x30,66},{0x31,78},{0x32,77},{0x33,188},{0x34,190},{0x35,191},{0x37,106},{0x39,32},{0x3a,20},{0x45,144},{0x46,145},{0x47,103},{0x48,104},{0x49,105},{0x4a,109},{0x4b,100},{0x4c,101},{0x4d,102},{0x4e,107},{0x4f,97},{0x50,98},{0x51,99},{0x52,96},{0x53,110},{0x56,226},{0x57,122},{0x58,123},{0x3b,112},{0x3c,113},{0x3d,114},{0x3e,115},{0x3f,116},{0x40,117},{0x41,118},{0x42,119},{0x43,120},{0x44,121}};
    for (const auto &item : everyPlainScan) check(PhysicalKeyboard::windowsKey(0,item.first,false,false)==item.second, "full printable/function/keypad scan table");
    check(PhysicalKeyboard::windowsKey(19,0x45,false,true)==19, "Pause E1");
    check(PhysicalKeyboard::windowsKey(17,0x1d,false,true)==0, "Pause fake Ctrl ignored");
    // Feed full Windows packet identities through the production controller entry point,
    // not pre-normalized VKs: truncation used to convert 0x21d into right Ctrl.
    for (bool fakeE0 : {false, true}) for (bool releaseFirst : {false, true}) {
        e.setBindingEditor(true); e.beginBindingDraft({}, true);
        auto raw = [&](int vk, unsigned scan, bool e0, bool down, quintptr device = 7) {
            e.processWindowsKey(vk,scan,e0,false,down,true,device);
        };
        if (releaseFirst) raw(163,0x21d,fakeE0,false);
        raw(163,0x21d,fakeE0,true);
        check(e.draftKeys().isEmpty() && e.pressedKeys().isEmpty(), "marked AltGr Ctrl never selects or holds either Ctrl");
        raw(18,0x38,true,true);
        check(e.draftKeys()==QVariantList{165} && e.pressedKeys()==QVariantList{165}, "AltGr raw packet selects only Alt R");
        raw(18,0x38,true,true);
        check(e.draftKeys()==QVariantList{165}, "AltGr repeat cannot toggle selected Alt");
        raw(163,0x21d,fakeE0,false); raw(18,0x38,true,false);
        check(e.pressedKeys().isEmpty() && e.draftKeys()==QVariantList{165}, "synthetic release cannot leave Ctrl or Alt held");
        e.setBindingEditor(false);
    }
    for (int ctrlSide : {162,163}) for (bool ctrlFirst : {false,true}) {
        e.setBindingEditor(true); e.beginBindingDraft({},true);
        auto control = [&](bool down) { e.processWindowsKey(17,0x1d,ctrlSide==163,false,down,true,1); };
        auto alt = [&](bool down) { e.processWindowsKey(18,0x38,true,false,down,true,2); };
        if (ctrlFirst) { control(true); alt(true); } else { alt(true); control(true); }
        check(e.pressedKeys().contains(ctrlSide) && e.pressedKeys().contains(165) && e.draftKeys().size()==2,
              "genuine Ctrl and Alt R remain separate in either order and across devices");
        e.processWindowsKey(ctrlSide,0x21d,ctrlSide==163,false,false,true,1);
        check(e.pressedKeys().contains(ctrlSide), "fake break cannot release genuine Ctrl");
        control(false); alt(false);
        check(e.pressedKeys().isEmpty(), "real Ctrl Alt release independently");
        e.setBindingEditor(false);
    }
    for (const auto &c : QList<QList<int>>{{163,0x1d,0,162},{162,0x1d,1,163},
            {163,0x38,1,165},{165,0x38,0,164},{18,0x1d,1,163},
            {17,0x38,1,165},{161,0x2a,0,160},{160,0x36,0,161},
            {17,0x21d,0,0},{163,0x21d,1,0},{18,0x138,1,0},{17,0xff,0,0}})
        check(PhysicalKeyboard::windowsKey(c[0],c[1],c[2],false)==c[3], "physical scan takes precedence; high bits are not truncated");
    check(e.resetBindings(), "prepare draft error lifecycle");
    e.dismissError(); e.setBindingEditor(true); e.beginBindingDraft({119},false);
    const auto beforeConflict = Configuration::encode(e.config());
    check(!e.applyChordSlot(false,0,{119}) && !e.draftError().isEmpty() && e.error().isEmpty(), "conflict is local to editor, never global banner");
    check(Configuration::encode(e.config())==beforeConflict, "local conflict does not mutate config");
    e.selectDraftKey(72);
    check(e.draftError().isEmpty(), "physical or virtual edit clears conflict immediately");
    check(!e.applyChordSlot(false,0,{72,72}) && !e.draftError().isEmpty(), "invalid duplicate is local");
    e.setBindingEditor(false);
    check(e.draftError().isEmpty() && e.error().isEmpty(), "cancel leaves no stuck conflict banner");
    e.setBindingEditor(true); e.beginBindingDraft({72},false);
    check(e.draftError().isEmpty() && e.applyChordSlot(false,0,{72}) && e.draftError().isEmpty(), "reopen and successful apply clear local error");
    check(!e.applyBindings(0,0,119,0) && !e.error().isEmpty(), "operational API errors remain visible");
    const bool readyBeforeDismiss=e.available(); const auto configBeforeDismiss=Configuration::encode(e.config());
    e.dismissError(); e.dismissError();
    check(e.error().isEmpty() && e.available()==readyBeforeDismiss && Configuration::encode(e.config())==configBeforeDismiss,
          "dismiss is idempotent and cannot enable unavailable input or change config");
    e.resetBindings();
    e.setBindingEditor(true);
    e.beginBindingDraft({}, true);
    e.selectDraftKey(72); e.selectDraftKey(89);
    check(e.draftKeys()==QVariantList({72,89}), "mouse-style H Y is a two-key chord");
    e.selectDraftKey(72);
    check(e.draftKeys()==QVariantList({89}), "second selection removes same key");
    e.selectDraftKey(72); e.selectDraftKey(107); e.selectDraftKey(75);
    check(e.draftKeys()==QVariantList({89,72,107}) && !e.draftError().isEmpty(), "literal plus is third key; fourth rejected");
    e.selectDraftKey(107);
    check(e.draftKeys()==QVariantList({89,72}) && e.draftError().isEmpty(), "removal clears capacity error");
    e.beginBindingDraft({}, true);
    e.processPhysicalKey(163,true,true);
    check(e.pressedKeys().contains(163) && !e.pressedKeys().contains(162) && e.draftKeys()==QVariantList({163}), "physical right Ctrl exact identity and selection");
    e.processPhysicalKey(163,false,true); e.selectDraftKey(72);
    check(e.draftKeys()==QVariantList({163,72}), "physical and mouse edits share one draft");
    e.processPhysicalKey(72,true,true); e.processPhysicalKey(72,false,true);
    check(e.draftKeys()==QVariantList({163}), "physical repeated selection removes mouse-selected key");
    e.beginBindingDraft({},true);
    e.processPhysicalKey(164,true,true);
    check(e.draftKeys()==QVariantList({164}) && !e.pressedKeys().contains(162), "left Alt never synthesizes Ctrl");
    e.processPhysicalKey(164,false,true); e.processPhysicalKey(165,true,true);
    check(e.draftKeys()==QVariantList({164,165}) && !e.pressedKeys().contains(162), "AltGr is only right Alt without phantom Ctrl");
    e.processPhysicalKey(165,false,true);
    for (int key : {37,38,39,40,45,46,36,35,33,34,13,269,106,107,109,111,186,187,188,189,190,191,192,219,220,221,222}) {
        e.beginBindingDraft({},true); e.processPhysicalKey(key,true,true);
        check(e.draftKeys()==QVariantList({key}) && e.pressedKeys().contains(key), "navigation/OEM/keypad key selects exact identity");
        e.processPhysicalKey(key,true,true);
        check(e.draftKeys()==QVariantList({key}), "repeat make does not toggle a selection");
        e.processPhysicalKey(key,false,true);
        check(!e.pressedKeys().contains(key), "each supported key releases independently");
    }
    for (int key : {96,97,98,99,100,101,102,103,104,105,110}) {
        e.beginBindingDraft({},true); e.processPhysicalKey(key,true,false);
        check(e.draftKeys().isEmpty() && !e.pressedKeys().contains(key), "Num off ignores every digit/decimal key");
        e.processPhysicalKey(key,false,false); e.processPhysicalKey(key,true,true);
        check(e.draftKeys()==QVariantList({key}), "Num on accepts each keypad identity");
        e.processPhysicalKey(key,false,true);
    }
    e.beginBindingDraft({},true); e.processPhysicalKey(72,true,true,1); e.processPhysicalKey(72,true,true,2);
    e.processPhysicalKey(72,false,true,1);
    check(e.pressedKeys().contains(72), "one keyboard release does not release another device");
    e.processPhysicalKey(72,false,true,2);
    check(!e.pressedKeys().contains(72), "all device releases clear key");
    e.setBindingEditor(false);
    check(e.applyChordSlot(false,0,{72,89}), "apply arbitrary H Y chord");
    check(e.startBindings()[0].toMap()["keys"].toList()==QVariantList({72,89}), "binding exposes explicit keys");
    check(!e.startLabel().contains('+'), "no plus separator in chord label");
    check(!e.applyChordSlot(true,0,{89,72}), "reversed-order chord conflict rejected");
    check(!e.applyChordSlot(true,0,{72}), "subset conflict rejected");
    check(!e.applyChordSlot(false,0,{72,89,75,76}), "four keys rejected atomically");
    check(!e.applyChordSlot(false,0,{72,72}), "duplicate physical key rejected");
    check(!e.applyChordSlot(false,0,{162,164,46}), "explicit Ctrl Alt Delete reserved");
    check(e.applyChordSlot(false,0,{163,72}), "side-specific modifier chord accepted");
    check(Configuration::chordMatches({72,0,{163,72}}, QSet<int>{163,72}), "right Ctrl chord matches");
    check(!Configuration::chordMatches({72,0,{163,72}}, QSet<int>{162,72}), "left Ctrl cannot match right Ctrl chord");
    check(Configuration::chordMatches({72,1}, QSet<int>{163,72}), "legacy generic Ctrl accepts right side");
    check(Configuration::chordMatches({107,0,{72,107,89}}, QSet<int>{89,72,107}), "literal keypad plus is real third required key");
    check(!Configuration::chordMatches({107,0,{72,107,89}}, QSet<int>{89,72}), "separator is not inferred as plus key");
    QString chordError; ClickConfig chordDecoded;
    check(Configuration::decode(Configuration::encode(e.config()), chordDecoded, chordError) && chordDecoded.startChord==QList<int>({163,72}), "new chord JSON roundtrip");
    auto malformedChord=Configuration::encode(e.config()); malformedChord["startChord"]=QJsonArray{163,72,75,76};
    check(!Configuration::decode(malformedChord,chordDecoded,chordError), "JSON fourth key rejected");
    malformedChord=Configuration::encode(e.config()); malformedChord["startChord"]=QJsonArray{72,72};
    check(!Configuration::decode(malformedChord,chordDecoded,chordError), "JSON duplicate chord key rejected");
    malformedChord=Configuration::encode(e.config()); malformedChord["startChord"]=QJsonArray{72.5};
    check(!Configuration::decode(malformedChord,chordDecoded,chordError), "JSON fractional chord key rejected");
    check(e.resetBindings() && e.applyChordSlot(false,0,{72,89}), "prepare global matcher");
    int starts=0, stops=0;
    QObject::connect(&e,&ClickController::shortcutActivated,&e,[&](bool stopAction){ if(stopAction) ++stops; else ++starts; });
    e.setReady(true);
    e.processPhysicalKey(72,true,true); e.processPhysicalKey(72,false,true); e.processPhysicalKey(89,true,true);
    check(starts==0, "sequential taps are not a held chord"); e.processPhysicalKey(89,false,true);
    e.processPhysicalKey(72,true,true); check(starts==0, "partial chord does not trigger");
    e.processPhysicalKey(89,true,true); check(starts==1, "all chord keys held trigger once");
    e.processPhysicalKey(89,true,true); check(starts==1, "repeat cannot retrigger global chord");
    e.processPhysicalKey(89,false,true); e.processPhysicalKey(89,true,true);
    check(starts==2, "release and repress rearm chord");
    e.processPhysicalKey(89,false,true); e.processPhysicalKey(72,false,true);
    e.processPhysicalKey(67,true,true); check(e.pressedKeys().isEmpty(), "unbound background key is not retained");
    e.processPhysicalKey(119,true,true); check(stops==1, "stop binding dispatches");
    e.processPhysicalKey(119,false,true);
    e.setBindingEditor(true); e.processPhysicalKey(119,true,true); check(stops==1, "global action disabled during editor");
    e.setBindingEditor(false);
    check(e.resetBindings() && e.applyChordSlot(false,0,{9}), "prepare global Tab binding");
    const int tabStarts = starts;
    e.processPhysicalKey(9,true,true);
    check(starts == tabStarts + 1, "global Tab dispatches");
    e.processPhysicalKey(9,true,true);
    check(starts == tabStarts + 1, "global Tab repeat ignored");
    e.processPhysicalKey(9,false,true); e.processPhysicalKey(9,true,true);
    check(starts == tabStarts + 2, "global Tab release rearms binding");
    e.processPhysicalKey(9,false,true);
    for (bool stopAction : {false,true}) for (int key : {165,44}) {
        check(e.resetBindings() && e.applyChordSlot(stopAction,0,{key}), "apply AltGr/PrintScreen for dispatch regression");
        int before = stopAction?stops:starts;
        auto packet = [&](bool down) { e.processWindowsKey(key==165?18:44,key==165?0x38:0x37,true,false,down,true,77); };
        packet(true);
        check((stopAction?stops:starts)==before+1, "applied AltGr/PrintScreen dispatches exact configured action");
        packet(true);
        check((stopAction?stops:starts)==before+1, "modifier and PrintScreen repeats do not retrigger");
        packet(false); packet(true);
        check((stopAction?stops:starts)==before+2, "AltGr/PrintScreen release rearms dispatch");
        packet(false);
    }
    e.setReady(false); e.resetBindings();
    QString err;
    ClickConfig decoded;
    auto obj = Configuration::encode(e.config());
    check(Configuration::decode(obj, decoded, err), "config roundtrip");
    obj["intervalMs"] = 5.5;
    check(!Configuration::decode(obj, decoded, err), "fraction rejected");
    obj = Configuration::encode(e.config());
    obj["stopKey"] = QString("F8");
    check(!Configuration::decode(obj, decoded, err), "type rejected");
    obj = Configuration::encode(e.config());
    obj["unknown"] = 1;
    check(!Configuration::decode(obj, decoded, err), "unknown fields rejected");
    ConfigStore store(&e);
    check(e.applyChordSlot(false,0,{165}) && e.applyChordSlot(true,0,{44}), "AltGr and PrintScreen together for profile regression");
    check(store.saveNew("AltGr PrintScreen"), "profile with AltGr and PrintScreen saved");
    const auto specialId=store.profiles()[0].toMap()["id"].toString();
    check(e.resetBindings() && store.apply(specialId), "profile AltGr PrintScreen loads and applies");
    check(e.config().startChord==QList<int>{165} && e.config().stopChord==QList<int>{44} && e.stopLabel()=="PrintScreen", "profile keeps exact modifiers and PrintScreen name");
    check(store.remove(specialId) && e.resetBindings(), "special profile regression cleans up");
    check(store.saveNew("Тест5мс"), "save profile unicode name");
    check(store.profiles().size() == 1, "profile listed");
    auto id = store.profiles()[0].toMap()["id"].toString();
    e.setIntervalMs(100);
    check(store.modified(), "modified detected");
    check(store.apply(id) && e.intervalMs() == 5, "apply profile");
    check(!store.modified(), "applied state clean");
    const QString out = temp.path() + "/export.json";
    check(store.exportFile(id, QUrl::fromLocalFile(out)), "export profile");
    check(store.importFile(QUrl::fromLocalFile(out)), "import copy");
    check(store.profiles().size() == 2, "import does not overwrite");
    check(!store.remove("../export.json"), "path traversal rejected");
    check(!store.apply("/export.json"), "absolute managed path rejected");
    check(store.rename(id, "Профиль200"), "rename profile");
    QFile bad(temp.path() + "/bad.json");
    bad.open(QIODevice::WriteOnly);
    bad.write("{broken");
    bad.close();
    check(!store.importFile(QUrl::fromLocalFile(bad.fileName())), "malformed import rejected");
    check(!store.saveNew("\n"), "invalid name rejected");
    check(store.remove(id), "delete profile");
    check(store.profiles().size() == 1, "delete updates list");
    auto next = Timing::advance(100, 105, 10);
    check(next.deadline == 110 && next.skipped == 0, "normal deadline grid");
    next = Timing::advance(100, 135, 10);
    check(next.deadline == 140 && next.skipped == 3, "skip late slots no burst");
    check(Timing::rate(200, 1000000000) == 200, "measured rate200");
    check(Timing::rate(150, 1000000000) == 150, "does not substitute requested200");
    check(Timing::rate(1, 1000) < 0, "warmup no extrapolated rate");
    {
        ClickController restored;
        check(restored.intervalMs() == 5 && restored.countLimit() == 200, "new config persistence");
    }
    const auto beforeCount = store.profiles().size();
    QFile huge(temp.path() + "/huge.json");
    huge.open(QIODevice::WriteOnly);
    huge.write(QByteArray(65537, ' '));
    huge.close();
    check(!store.importFile(QUrl::fromLocalFile(huge.fileName())), "oversize import rejected");
    check(store.profiles().size() == beforeCount, "failed import does not alter profiles");
    check(!store.importFile(QUrl("https://example.com/config.json")), "remote import rejected");
    e.setCountLimit(1000000001ULL);
    check(e.countLimit() == 200, "count overflow rejected");
    obj = Configuration::encode(e.config());
    obj["countLimit"] = -1;
    check(!Configuration::decode(obj, decoded, err), "negative count rejected");
    next = Timing::advance(100, 110, 10);
    check(next.deadline == 120 && next.skipped == 1, "equal deadline skips no burst");
    check(Timing::rate(0, 1000000000) == 0, "zero sent means measured zero");
#ifndef Q_OS_WIN
    const auto link = store.directory() + "/symlink.json";
    check(QFile::link(out, link), "symlink fixture created");
    check(!store.apply("symlink.json"), "managed symlink rejected");
#endif
    check(e.applyBindingSlot(false, 1, 65, 1), "add second start binding");
    check(e.startBindings().size() == 2, "two start bindings visible");
    check(e.applyBindingSlot(true, 1, 66, 1), "add second stop binding");
    check(!e.applyBindingSlot(true, 2, 65, 1), "cross action conflict rejected");
    check(!e.applyBindingSlot(false, 2, 65, 1), "same action duplicate rejected");
    check(e.removeBinding(false, 0) && e.startKey() == 65, "removing primary promotes second");
    check(!e.removeBinding(false, 0), "at least one binding retained");
    check(e.resetBindings() && e.startBindings().size() == 1 && e.stopBindings().size() == 1,
          "reset all binding lists");
    for (int i = 1; i < 8; ++i)
        check(e.applyBindingSlot(false, i, 65 + i, 0), "append bounded binding");
    check(!e.applyBindingSlot(false, 8, 90, 0), "ninth binding rejected");
    obj = Configuration::encode(e.config());
    check(Configuration::decode(obj, decoded, err) && decoded.startExtra.size() == 7,
          "multibind JSON roundtrip");
    auto legacy = obj;
    legacy.remove("startExtra");
    legacy.remove("stopExtra");
    legacy.remove("launchDelaySec");
    check(Configuration::decode(legacy, decoded, err) && decoded.launchDelay == 3 &&
              decoded.startExtra.isEmpty(),
          "legacy nine field import");
    e.setLaunchDelaySec(7);
    check(e.launchDelaySec() == 7, "custom countdown");
    e.setLaunchDelaySec(0);
    check(e.launchDelaySec() == 7, "reject zero countdown");
    e.setLaunchDelaySec(11);
    check(e.launchDelaySec() == 7, "reject countdown overflow");
    check(e.meanGapMs() < 0 && e.maxJitterMs() < 0, "no invented gap measurement");
    Timing::TickGrid grid(100, 10000003, 5);
    check(grid.at(200) == 100 + 10000003, "fractional QPC ticks preserved over one second");
    check(grid.at(1000000) == 100 + 5000LL * 10000003, "no long run truncation drift");
    check(grid.nextSlot(0, grid.at(1)) == 2, "equal rational deadline skips");
    check(grid.nextSlot(0, grid.at(50) + 1) == 51, "late rational grid no catchup burst");
    bool rational = true;
    for (int i = 0; i < 5000; ++i) {
        auto n = grid.nextSlot(0, 100 + i * 7919);
        rational &= grid.at(n) > 100 + i * 7919 && grid.at(n - 1) <= 100 + i * 7919;
    }
    check(rational, "rational schedule boundary sweep 5000 samples");
    Timing::GapStats gap;
    gap.accept(0, 5000000);
    check(gap.mean() == -1, "one insertion no gap yet");
    gap.accept(6000000, 5000000);
    gap.accept(10000000, 5000000);
    check(gap.mean() == 5000000 && gap.maxJitter == 1000000,
          "measured gaps and jitter from actual samples");
    store.setSearchQuery("");
    check(store.saveNew("Beta keyboard"), "save beta profile");
    QString betaId;
    for (const auto &row : store.profiles())
        if (row.toMap()["name"] == "Beta keyboard")
            betaId = row.toMap()["id"].toString();
    const auto beforeDuplicate = store.profiles().size();
    check(store.duplicate(betaId) && store.profiles().size() == beforeDuplicate + 1,
          "duplicate independent JSON");
    store.setSearchQuery("Beta keyboard");
    check(!store.profiles().isEmpty(), "case insensitive profile search");
    store.setSearchQuery("nonexistent-profile");
    check(store.profiles().isEmpty(), "empty query result");
    store.setSearchQuery("");
    check(store.profiles().size() == beforeDuplicate + 1, "search does not delete profiles");
    {
        ClickController loadedMulti;
        check(loadedMulti.startBindings().size() == 8 && loadedMulti.launchDelaySec() == 7,
              "persist multibind and countdown");
    }
    obj = Configuration::encode(e.config());
    obj["startExtra"] = QJsonArray{QJsonObject{{"key", 65.5}, {"mods", 0}}};
    check(!Configuration::decode(obj, decoded, err), "fractional extra key rejected");
    obj = Configuration::encode(e.config());
    obj["launchDelaySec"] = 2.5;
    check(!Configuration::decode(obj, decoded, err), "fractional delay rejected");
    obj = Configuration::encode(e.config());
    obj["stopExtra"] = QJsonArray{QJsonObject{{"key", 65}, {"mods", 8}}};
    check(!Configuration::decode(obj, decoded, err), "invalid modifier mask rejected");
    const auto oldDoc = QJsonDocument(QJsonObject{{"format", "obsidian-click"},
                                                  {"version", 1},
                                                  {"name", "Legacy"},
                                                  {"settings", legacy}})
                            .toJson();
    QFile oldFile(temp.path() + "/legacy.json");
    oldFile.open(QIODevice::WriteOnly);
    oldFile.write(oldDoc);
    oldFile.close();
    check(store.importFile(QUrl::fromLocalFile(oldFile.fileName())), "import original v1 envelope");
    oldFile.open(QIODevice::ReadOnly);
    check(oldFile.readAll() == oldDoc, "legacy source not rewritten");
    oldFile.close();
    bool namedKeys = true;
    for (int k = 0; k < 512; ++k)
        if (Configuration::validKey(k) || Configuration::validChordKey(k))
            namedKeys &= Configuration::keyName(k) != "?";
    check(namedKeys, "all supported virtual keys have display labels");
    check(!store.apply("C:profile.json"), "drive-relative or NTFS stream identifier rejected");
    check(!store.remove("control\n.json"), "control character identifier rejected");
    QFile boundary(temp.path() + "/boundary.json");
    auto boundaryBytes = oldDoc;
    boundaryBytes.append(QByteArray(65536 - boundaryBytes.size(), ' '));
    boundary.open(QIODevice::WriteOnly);
    boundary.write(boundaryBytes);
    boundary.close();
    check(store.importFile(QUrl::fromLocalFile(boundary.fileName())),
          "valid JSON at exact 64KB limit");
    boundary.open(QIODevice::Append);
    boundary.write(" ");
    boundary.close();
    check(!store.importFile(QUrl::fromLocalFile(boundary.fileName())),
          "valid JSON over 64KB rejected");
    check(e.resetBindings(), "reset after multibind tests");
    check(e.applyChordSlot(false, 0, {72, 89, 163}), "prepare persistent physical triple");
    check(store.saveNew("Physical triple v3"), "save physical triple profile");
    QString tripleId;
    for (const auto &row : store.profiles())
        if (row.toMap()["name"] == "Physical triple v3")
            tripleId = row.toMap()["id"].toString();
    check(!tripleId.isEmpty(), "saved triple has managed id");
    QFile tripleFile(store.directory() + "/" + tripleId);
    check(tripleFile.open(QIODevice::ReadOnly), "read saved triple envelope");
    const auto tripleBytes = tripleFile.readAll();
    tripleFile.close();
    check(QJsonDocument::fromJson(tripleBytes).object()["version"].toInt() == 4,
          "physical triple uses version 4 envelope");
    check(e.resetBindings() && store.apply(tripleId), "apply saved triple after reset");
    check(e.config().startChord == QList<int>({72, 89, 163}), "saved side-specific triple round trip");
    const QUrl tripleExport = QUrl::fromLocalFile(temp.path() + "/triple-export.json");
    check(store.exportFile(tripleId, tripleExport), "export explicit triple");
    check(store.importFile(tripleExport), "import explicit triple");
    { ClickController loadedTriple;
      check(loadedTriple.config().startChord == QList<int>({72, 89, 163}),
            "persist explicit triple through settings reload"); }
    check(e.resetBindings(), "restore defaults after triple persistence");
    {
        // ---- 0.5.0 click modes: Legit / Blatant / Custom ----
        QSettings().clear();
        ClickController m;
        check(m.clickMode() == LegitMode && m.cpsMin() == 9 && m.cpsMax() == 13,
              "fresh install defaults to Legit 9-13 CPS");
        check(m.modeSummary() == QStringLiteral("Легит · 9–13 КПС"), "legit summary");
        check(m.rhythmPreview().size() == 48, "rhythm preview has 48 planned gaps");
        check(qAbs(m.expectedCps() - 11) < 1e-9, "legit expected CPS is the range centre");
        check(m.setCpsRange(12, 16) && m.cpsMin() == 12 && m.cpsMax() == 16, "set CPS range");
        check(!m.setCpsRange(16, 12) && m.cpsMin() == 12, "inverted CPS range rejected");
        check(!m.setCpsRange(0, 5) && !m.setCpsRange(5, 31), "CPS outside 1-30 rejected");
        m.setCpsMin(20);
        check(m.cpsMin() == 20 && m.cpsMax() == 20, "raising min pushes max");
        m.setCpsMax(4);
        check(m.cpsMin() == 4 && m.cpsMax() == 4, "lowering max pulls min");
        check(m.modeSummary() == QStringLiteral("Легит · 4 КПС"), "single-value legit summary");
        m.setCpsRange(9, 13);
        m.setIntervalMs(1);
        check(m.intervalMs() != 1 && m.minIntervalMs() == 5, "legit keeps the 5 ms floor");
        m.setClickMode(BlatantMode);
        check(m.clickMode() == BlatantMode && m.minIntervalMs() == 1, "blatant mode floor 1 ms");
        m.setIntervalMs(1);
        check(m.intervalMs() == 1 && m.holdMs() == 0, "blatant 1 ms clamps hold to zero");
        check(qAbs(m.expectedCps() - 1000) < 1e-9, "blatant expected CPS");
        m.setClickMode(CustomMode);
        check(m.clickMode() == CustomMode && m.intervalMs() == 5, "leaving blatant snaps interval");
        m.setClickMode(3);
        check(m.clickMode() == CustomMode, "unknown mode rejected");
        m.setJitterPct(50);
        check(m.jitterPct() == 50, "jitter 50 accepted");
        m.setJitterPct(51);
        check(m.jitterPct() == 50, "jitter 51 rejected");
        m.setDelivery(MessageDelivery);
        check(m.delivery() == MessageDelivery, "message delivery");
        m.setDelivery(2);
        check(m.delivery() == MessageDelivery, "unknown delivery rejected");
        m.setDrift(true);
        check(m.drift(), "drift toggle");
        check(m.modeSummary() == QStringLiteral("Свой · 5 мс ±50 % · волна · сообщения"),
              "custom summary");

        // JSON: pattern block round trip and legacy compatibility.
        QString why;
        ClickConfig back;
        auto json = Configuration::encode(m.config());
        check(json["pattern"].isObject() && json["pattern"].toObject().size() == 6,
              "pattern block encoded");
        check(Configuration::decode(json, back, why) && back.mode == CustomMode &&
                  back.jitter == 50 && back.delivery == MessageDelivery && back.drift,
              "custom pattern round trip");
        for (int mode : {LegitMode, BlatantMode}) {
            auto cfg = m.config();
            cfg.mode = mode;
            check(Configuration::decode(Configuration::encode(cfg), back, why) && back.mode == mode,
                  "mode round trip");
        }
        auto legacyJson = json;
        legacyJson.remove("pattern");
        check(Configuration::decode(legacyJson, back, why) && back.mode == CustomMode &&
                  back.jitter == 0 && back.delivery == EmulatedDelivery && !back.drift,
              "0.4.7 JSON loads as Custom");
        const auto legacyPlan = ClickPattern::plan(back);
        check(legacyPlan.fixed && !legacyPlan.messages,
              "legacy plan is the 0.4.7 fixed-grid SendInput engine");
        auto bad = [&](const char *key, const QJsonValue &value) {
            auto broken = json;
            auto pattern = broken["pattern"].toObject();
            if (value.isUndefined())
                pattern.remove(key);
            else
                pattern[key] = value;
            broken["pattern"] = pattern;
            return !Configuration::decode(broken, back, why);
        };
        check(bad("mode", QJsonValue::Undefined), "pattern missing key rejected");
        check(bad("drift", 1), "pattern drift must be bool");
        check(bad("cpsMin", 9.5), "pattern fractional CPS rejected");
        check(bad("cpsMin", 20) && bad("cpsMax", 31), "pattern CPS range validated");
        check(bad("extra", 1), "pattern unknown key rejected");
        check(bad("mode", 7) && bad("delivery", -1), "pattern enums validated");
        auto notObject = json;
        notObject["pattern"] = 3;
        check(!Configuration::decode(notObject, back, why), "pattern must be an object");

        // Profiles: v4 envelope, mode in the list, v3 file still loads.
        ConfigStore modes(&m);
        m.setClickMode(LegitMode);
        m.setCpsRange(10, 14);
        check(modes.saveNew("Legit profile"), "save legit profile");
        QString legitId;
        for (const auto &row : modes.profiles())
            if (row.toMap()["name"] == "Legit profile") {
                legitId = row.toMap()["id"].toString();
                check(row.toMap()["detail"].toString().startsWith(QStringLiteral("Легит · 10–14 КПС")),
                      "profile detail shows mode");
                check(row.toMap()["summary"].toString() == QStringLiteral("Легит · 10–14 КПС"),
                      "profile summary is the full mode description");
            }
        QFile legitFile(modes.directory() + "/" + legitId);
        check(legitFile.open(QIODevice::ReadOnly), "read legit profile");
        const auto legitDoc = QJsonDocument::fromJson(legitFile.readAll()).object();
        legitFile.close();
        check(legitDoc["version"].toInt() == 4 &&
                  legitDoc["settings"].toObject()["pattern"].toObject()["cpsMin"].toInt() == 10,
              "legit profile stored as v4 with pattern");
        m.setClickMode(BlatantMode);
        check(modes.apply(legitId) && m.clickMode() == LegitMode && m.cpsMax() == 14,
              "apply restores legit mode");
        QFile v3(temp.path() + "/v3.json");
        check(v3.open(QIODevice::WriteOnly), "write v3 profile");
        v3.write(QJsonDocument(QJsonObject{{"format", "c-clicker"},
                                           {"version", 3},
                                           {"name", "Old v3"},
                                           {"settings", legacyJson}})
                     .toJson());
        v3.close();
        check(modes.importFile(QUrl::fromLocalFile(v3.fileName())), "v3 profile still imports");
        QFile badVersion(temp.path() + "/v35.json");
        check(badVersion.open(QIODevice::WriteOnly), "write fractional version");
        badVersion.write(QJsonDocument(QJsonObject{{"format", "c-clicker"},
                                                   {"version", 3.5},
                                                   {"name", "Bad"},
                                                   {"settings", json}})
                             .toJson());
        badVersion.close();
        check(!modes.importFile(QUrl::fromLocalFile(badVersion.fileName())),
              "fractional envelope version rejected");
        { ClickController reloaded;
          check(reloaded.clickMode() == LegitMode && reloaded.cpsMin() == 10,
                "mode persists through settings reload"); }

        // Generator: Legit is human-like, bounded and seed-deterministic.
        ClickConfig legit;
        legit.mode = LegitMode;
        legit.cpsMin = 9;
        legit.cpsMax = 13;
        auto legitPlan = ClickPattern::plan(legit);
        check(!legitPlan.fixed && !legitPlan.messages, "legit uses SendInput emulation, variable");
        {
            ClickPattern::Generator a(legitPlan, 42), b(legitPlan, 42), other(legitPlan, 43);
            bool same = true, differs = false;
            for (int i = 0; i < 200; ++i) {
                const auto x = a.next(), y = b.next(), z = other.next();
                same &= x.gapNs == y.gapNs && x.holdNs == y.holdNs;
                differs |= x.gapNs != z.gapNs;
            }
            check(same, "same seed reproduces the rhythm");
            check(differs, "different seeds differ");
        }
        auto stats = [&](const ClickConfig &cfg, quint64 seed, int n, auto &&perStep) {
            ClickPattern::Generator g(ClickPattern::plan(cfg), seed);
            double sum = 0, sq = 0;
            QSet<qint64> distinct;
            QList<double> gaps;
            for (int i = 0; i < n; ++i) {
                const auto st = g.next();
                perStep(st);
                const double ms = st.gapNs / 1e6;
                sum += ms;
                sq += ms * ms;
                distinct.insert(st.gapNs);
                gaps.append(ms);
            }
            const double mean = sum / n;
            return std::tuple{mean, std::sqrt(qMax(0.0, sq / n - mean * mean)) / mean,
                              distinct.size(), gaps};
        };
        bool holdsOk = true, gapsBounded = true;
        double holdShare = 0;
        const int samples = 20000;
        auto [legitMean, legitCv, legitDistinct, legitGaps] =
            stats(legit, 7, samples, [&](const ClickPattern::Step &st) {
                holdsOk &= st.holdNs > 0 && st.holdNs < st.gapNs;
                holdShare += double(st.holdNs) / double(st.gapNs);
                const double ms = st.gapNs / 1e6;
                gapsBounded &= ms >= 1000.0 / (13 * 1.2) - 1e-6 && ms <= 1000.0 / (9 * 0.8) + 110;
            });
        const double legitCps = 1000.0 / legitMean;
        check(legitCps >= 9 && legitCps <= 13, "legit mean CPS stays inside the range");
        check(legitCv > 0.06 && legitCv < 0.35, "legit gaps vary like a human, not wildly");
        check(legitDistinct > samples * 0.95, "legit gaps are practically never repeated");
        check(holdsOk, "legit hold is always shorter than its gap");
        check(gapsBounded, "legit gaps bounded by range and micro-pauses");
        holdShare /= samples;
        check(holdShare > 0.3 && holdShare < 0.55, "legit hold is about a third to half of a cycle");
        {
            // The tempo wanders: 50-click windows do not all average the same.
            double lo = 1e9, hi = 0;
            for (int i = 0; i + 50 <= legitGaps.size(); i += 50) {
                double w = 0;
                for (int j = i; j < i + 50; ++j) w += legitGaps[j];
                lo = qMin(lo, 50000.0 / w);
                hi = qMax(hi, 50000.0 / w);
            }
            check(hi - lo > 0.5, "legit tempo drifts between windows");
            int pauses = 0;
            for (double ms : legitGaps) pauses += ms > 1000.0 / (9 * 0.8) + 1;
            check(pauses > samples * 0.004 && pauses < samples * 0.03, "rare legit micro-pauses");
        }
        ClickConfig fast = legit;
        fast.cpsMin = fast.cpsMax = 30;
        bool fastHolds = true;
        auto [fastMean, fastCv, fastDistinct, fastGaps] =
            stats(fast, 9, 5000, [&](const ClickPattern::Step &st) {
                fastHolds &= st.holdNs >= 5000000 && st.holdNs < st.gapNs &&
                             st.gapNs >= qint64(1e9 / 36) - 1;
            });
        check(fastHolds, "30 CPS legit keeps valid holds and gap floor");
        check(qAbs(1000.0 / fastMean - 30) < 30 * 0.08, "fixed-value legit averages its CPS");
        Q_UNUSED(fastCv) Q_UNUSED(fastDistinct) Q_UNUSED(fastGaps)

        // Blatant: exact grid, window messages.
        ClickConfig blatant;
        blatant.mode = BlatantMode;
        blatant.interval = 2;
        blatant.hold = 1;
        const auto blatantPlan = ClickPattern::plan(blatant);
        check(blatantPlan.fixed && blatantPlan.messages, "blatant is fixed and message-delivered");
        bool exact = true;
        auto [bMean, bCv, bDistinct, bGaps] = stats(blatant, 1, 1000, [&](const ClickPattern::Step &st) {
            exact &= st.gapNs == 2000000 && st.holdNs == 1000000;
        });
        check(exact && bDistinct == 1 && bCv < 1e-12, "blatant gaps are exact");
        Q_UNUSED(bMean) Q_UNUSED(bGaps)
        const auto bPreview = ClickPattern::preview(blatant, 10);
        check(bPreview.size() == 10 && bPreview.count(2.0) == 10, "blatant preview is flat");

        // Custom: jitter and drift stay bounded around the interval.
        ClickConfig custom;
        custom.mode = CustomMode;
        custom.interval = 100;
        custom.hold = 20;
        custom.jitter = 20;
        check(!ClickPattern::plan(custom).fixed && !ClickPattern::plan(custom).messages,
              "custom jitter is variable and emulated by default");
        bool withinJitter = true;
        auto [cMean, cCv, cDistinct, cGaps] = stats(custom, 3, 20000, [&](const ClickPattern::Step &st) {
            withinJitter &= st.gapNs >= 80000000 && st.gapNs <= 120000000 && st.holdNs >= 16000000 &&
                            st.holdNs <= 24000000;
        });
        check(withinJitter, "custom jitter stays within ±20 %");
        check(qAbs(cMean - 100) < 1, "custom jitter is unbiased");
        Q_UNUSED(cCv) Q_UNUSED(cDistinct) Q_UNUSED(cGaps)
        custom.jitter = 0;
        custom.drift = true;
        bool waveBounded = true;
        auto [dMean, dCv, dDistinct, dGaps] = stats(custom, 5, 2000, [&](const ClickPattern::Step &st) {
            waveBounded &= st.gapNs >= 88000000 - 1 && st.gapNs <= 112000000 + 1;
        });
        check(waveBounded && dDistinct > 100 && dCv > 0.03, "custom wave varies within ±12 %");
        Q_UNUSED(dMean) Q_UNUSED(dGaps)
        custom.drift = false;
        custom.delivery = MessageDelivery;
        check(ClickPattern::plan(custom).fixed && ClickPattern::plan(custom).messages,
              "custom without jitter uses the exact grid, chosen delivery");
        ClickConfig tiny;
        tiny.mode = CustomMode;
        tiny.interval = 5;
        tiny.hold = 4;
        tiny.jitter = 50;
        bool tinyOk = true;
        stats(tiny, 11, 5000, [&](const ClickPattern::Step &st) {
            tinyOk &= st.gapNs >= 1000000 && st.holdNs >= 0 && st.holdNs < st.gapNs;
        });
        check(tinyOk, "custom extreme jitter never produces hold >= gap or sub-ms gaps");
        const auto skip = Timing::advance(100, 1000, 300);
        // Slots at 400, 700 and 1000 are already due at t=1000: three dropped, next at 1300.
        check(skip.deadline == 1300 && skip.skipped == 3, "variable scheduler drops missed gaps");
    }
    QSettings().clear();
    qInfo() << "CONTROLLER_CONFIG_TIMING_PASS" << checks << "assertions";
}
