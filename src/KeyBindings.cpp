#include "ClickController.h"
#include "PhysicalKeyboard.h"
#include <QGuiApplication>
#include <QKeyEvent>
#include <QWindow>
#include <QMap>
#include <algorithm>
#include <cstddef>
#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
namespace {
constexpr int MaxBindings = 8;
// Separate editor-only Qt AltGr source; never registered as a background device.
constexpr quintptr QtAltGrDevice = ~quintptr(0);
KeyBinding singleBinding(int key, int mods) {
    // Physical side-specific modifiers and PrintScreen must not fall back to
    // a legacy primary-key-only representation on alternate API paths.
    if (!mods && ((key >= 160 && key <= 165) || key == 44 || key == 269 || key == 226))
        return {key, 0, {key}};
    return {key, mods};
}
QVariantList variants(const QList<int> &keys) { QVariantList out; for (int k : keys) out.append(k); return out; }
}
bool ClickController::registerBindings(const ClickConfig &c) {
#ifdef Q_OS_WIN
    if (!m_inputWindow) { m_inputWindow = new QWindow; m_inputWindow->create(); }
    RAWINPUTDEVICE device{0x01, 0x06, RIDEV_INPUTSINK | RIDEV_DEVNOTIFY,
                           reinterpret_cast<HWND>(m_inputWindow->winId())};
    m_inputRegistered = RegisterRawInputDevices(&device, 1, sizeof(device));
    clearKeyboardState();
    m_numLockOn = (GetKeyState(VK_NUMLOCK) & 1) != 0;
    // Do not activate a newly applied binding from a key that is already held.
    for (bool stop : {false, true}) for (const auto &b : Configuration::bindings(c, stop)) {
        for (int key : Configuration::chordKeys(b)) {
            const QList<int> candidates = key == 17 ? QList<int>{162,163} : key == 18 ? QList<int>{164,165} :
                key == 16 ? QList<int>{160,161} : QList<int>{key == 269 ? 13 : key};
            for (int vk : candidates) if (GetAsyncKeyState(vk) & 0x8000) m_blockedKeys.insert(vk);
        }
    }
    return m_inputRegistered;
#else
    Q_UNUSED(c)
    return false;
#endif
}
void ClickController::unregisterBindings() {
#ifdef Q_OS_WIN
    if (m_inputRegistered) {
        RAWINPUTDEVICE device{0x01, 0x06, RIDEV_REMOVE, nullptr};
        RegisterRawInputDevices(&device, 1, sizeof(device));
    }
#endif
    m_inputRegistered = false;
    clearKeyboardState();
}
QVariantList ClickController::bindingList(bool stop) const {
    QVariantList list;
    for (const auto &b : Configuration::bindings(m_config, stop))
        list.append(QVariantMap{{"key", b.key}, {"mods", b.mods},
            {"keys", variants(Configuration::chordKeys(b))}, {"label", Configuration::chordName(b)}});
    return list;
}
bool ClickController::applyBindingSlot(bool stop, int index, int key, int mods) {
    auto c = m_config;
    auto list = Configuration::bindings(c, stop);
    if (index < 0 || index > list.size() || (index == list.size() && list.size() >= MaxBindings)) return false;
    if (index == list.size()) list.append(singleBinding(key, mods)); else list[index] = singleBinding(key, mods);
    const auto first = list.takeFirst();
    if (stop) { c.stopKey = first.key; c.stopMods = first.mods; c.stopChord = first.keys; c.stopExtra = list; }
    else { c.startKey = first.key; c.startMods = first.mods; c.startChord = first.keys; c.startExtra = list; }
    return applyConfig(c);
}
bool ClickController::applyChordSlot(bool stop, int index, const QVariantList &values) {
    const auto reject = [this](const QString &message) {
        m_draftError = message; emit keyboardStateChanged(); return false;
    };
    m_draftError.clear();
    QList<int> keys;
    for (const auto &v : values) {
        bool ok = false; const int key = v.toInt(&ok);
        if (!ok || v.toDouble() != key || !Configuration::validChordKey(key) || keys.contains(key)) {
            return reject(tr("Некорректный набор клавиш."));
        }
        keys.append(key);
    }
    if (keys.isEmpty() || keys.size() > 3) { return reject(tr("Выберите от одной до трёх клавиш.")); }
    auto c = m_config;
    auto list = Configuration::bindings(c, stop);
    if (index < 0 || index > list.size() || (index == list.size() && list.size() >= MaxBindings)) return reject(tr("Список назначений изменился. Откройте редактор заново."));
    KeyBinding binding{keys.last(), 0, keys};
    if (index == list.size()) list.append(binding); else list[index] = binding;
    const auto first = list.takeFirst();
    if (stop) { c.stopKey = first.key; c.stopMods = first.mods; c.stopChord = first.keys; c.stopExtra = list; }
    else { c.startKey = first.key; c.startMods = first.mods; c.startChord = first.keys; c.startExtra = list; }
    const auto error = Configuration::validate(c);
    if (!error.isEmpty()) return reject(error);
    // Operational failures are also visible while the editor hides the general banner.
    if (!applyConfig(c)) return reject(m_error);
    return true;
}
bool ClickController::removeBinding(bool stop, int index) {
    auto c = m_config; auto list = Configuration::bindings(c, stop);
    if (list.size() <= 1 || index < 0 || index >= list.size()) return false;
    list.removeAt(index); const auto first = list.takeFirst();
    if (stop) { c.stopKey = first.key; c.stopMods = first.mods; c.stopChord = first.keys; c.stopExtra = list; }
    else { c.startKey = first.key; c.startMods = first.mods; c.startChord = first.keys; c.startExtra = list; }
    return applyConfig(c);
}
bool ClickController::applyBindings(int k, int m, int t, int n) {
    auto c = m_config; c.startKey = k; c.startMods = m; c.stopKey = t; c.stopMods = n;
    c.startChord = singleBinding(k,m).keys; c.stopChord = singleBinding(t,n).keys; return applyConfig(c);
}
bool ClickController::resetBindings() {
    auto c = m_config; c.startKey = 117; c.startMods = 0; c.stopKey = 119; c.stopMods = 0;
    c.startExtra.clear(); c.stopExtra.clear(); c.startChord.clear(); c.stopChord.clear(); return applyConfig(c);
}
void ClickController::clearKeyboardState() {
    m_pressedKeys.clear(); m_deviceKeys.clear(); m_latchedBindings.clear(); m_blockedKeys.clear();
}
void ClickController::setBindingEditor(bool enabled) {
    if ((enabled && m_active) || enabled == m_editing) return;
    m_editing = enabled;
    m_draftError.clear();
    clearKeyboardState();
#ifdef Q_OS_WIN
    m_numLockOn = (GetKeyState(VK_NUMLOCK) & 1) != 0;
    if (!enabled) m_available = m_stopEvent && registerBindings(m_config);
    // Raw Input stays connected in both modes: only routing changes, never a Qt modifier mask.
#endif
    emit keyboardStateChanged(); emit changed();
}
QVariantList ClickController::pressedKeys() const {
    QList<int> keys = m_pressedKeys.values(); std::sort(keys.begin(), keys.end()); return variants(keys);
}
QVariantList ClickController::draftKeys() const { return variants(m_draftKeys); }
void ClickController::beginBindingDraft(const QVariantList &values, bool combination) {
    m_draftKeys.clear(); m_captureCombination = combination; m_draftError.clear();
    for (const auto &v : values) {
        int key = v.toInt();
        // Old generic modifier bindings migrate to explicit left-side identities in the editor.
        if (key == 17) key = 162; else if (key == 18) key = 164; else if (key == 16) key = 160;
        if (Configuration::validChordKey(key) && !m_draftKeys.contains(key) && m_draftKeys.size() < 3) m_draftKeys.append(key);
    }
    if (!combination && m_draftKeys.size() > 1) m_draftKeys = {m_draftKeys.last()};
    if (values.size() > 3) m_draftError = tr("Прежнее сочетание длиннее трёх клавиш. Проверьте новый набор.");
    emit keyboardStateChanged();
}
void ClickController::setCaptureCombination(bool value) {
    if (m_captureCombination == value) return;
    m_captureCombination = value; m_draftKeys.clear(); m_draftError.clear();
    emit keyboardStateChanged();
}
void ClickController::selectDraftKey(int key) {
    if (!m_editing || !Configuration::validChordKey(key) || (PhysicalKeyboard::keypadDigit(key) && !m_numLockOn)) return;
    m_draftError.clear();
    if (!m_captureCombination) m_draftKeys = {key};
    else if (m_draftKeys.contains(key)) m_draftKeys.removeAll(key);
    else if (m_draftKeys.size() < 3) m_draftKeys.append(key);
    else m_draftError = tr("Не больше трёх клавиш. Нажмите выбранную клавишу, чтобы убрать её.");
    emit keyboardStateChanged();
}
void ClickController::evaluateBindings(bool trigger) {
    QSet<int> matched;
    bool startEdge = false, stopEdge = false;
    for (bool stop : {true, false}) {
        const auto list = Configuration::bindings(m_config, stop);
        for (qsizetype i = 0; i < list.size(); ++i) {
            const int id = (stop ? 8 : 0) + int(i);
            if (Configuration::chordMatches(list[i], m_pressedKeys)) {
                matched.insert(id);
                if (!m_latchedBindings.contains(id)) { if (stop) stopEdge = true; else startEdge = true; }
            }
        }
    }
    m_latchedBindings = matched;
    if (!trigger || m_editing || !m_ready) return;
    if (stopEdge) { emit shortcutActivated(true); stop(); }
    else if (startEdge) { emit shortcutActivated(false); start(); }
}
void ClickController::dismissError() {
    if (m_error.isEmpty()) return;
    m_error.clear(); emit changed(); // Never alters readiness, availability or persisted config.
}
void ClickController::processWindowsKey(int vk, unsigned scan, bool e0, bool e1, bool down,
                                        bool numLock, quintptr device) {
    processPhysicalKey(PhysicalKeyboard::windowsKey(vk, scan, e0, e1), down, numLock, device);
}
void ClickController::processPhysicalKey(int key, bool down, bool numLock, quintptr device) {
    if (!key) return;
    m_numLockOn = numLock;
    if (!numLock) {
        for (auto it = m_deviceKeys.begin(); it != m_deviceKeys.end(); ++it)
            for (int k : QList<int>(it.value().values())) if (PhysicalKeyboard::keypadDigit(k)) it.value().remove(k);
    }
    if (!m_editing) {
        bool relevant = false;
        for (bool stop : {false, true}) for (const auto &b : Configuration::bindings(m_config, stop))
            relevant |= PhysicalKeyboard::relevant(key, Configuration::chordKeys(b));
        if (!relevant && key != 144) return; // never retain unrelated background typing
    }
    const bool editorWasDown = m_pressedKeys.contains(key);
    auto &held = m_deviceKeys[device];
    const bool wasDown = held.contains(key);
    if (!down) { held.remove(key); m_blockedKeys.remove(key); if (key == 269) m_blockedKeys.remove(13); }
    else if (!m_blockedKeys.contains(key) && !(key == 269 && m_blockedKeys.contains(13)) &&
             (!PhysicalKeyboard::keypadDigit(key) || numLock) ) held.insert(key);
    if (held.isEmpty()) m_deviceKeys.remove(device);
    m_pressedKeys.clear();
    for (const auto &keys : std::as_const(m_deviceKeys)) m_pressedKeys.unite(keys);
    if (m_editing) {
        emit keyboardStateChanged();
        // Qt may supply the same AltGr press already delivered by Raw Input.
        // Select on the union's rising edge, not once for each input source.
        if (down && !wasDown && !editorWasDown && m_pressedKeys.contains(key)) {
            selectDraftKey(key);

        }
    } else evaluateBindings(down && !wasDown);
}
bool ClickController::nativeEventFilter(const QByteArray &, void *data, qintptr *result) {
#ifdef Q_OS_WIN
    const auto *msg = static_cast<MSG *>(data);
    if (msg->message == WM_GETMINMAXINFO) {
        for (QWindow *window : QGuiApplication::allWindows()) {
            if (!window->handle() || !(window->flags() & Qt::FramelessWindowHint) ||
                reinterpret_cast<HWND>(window->winId()) != msg->hwnd) continue;
            MONITORINFO info{};
            info.cbSize = sizeof(info);
            if (!GetMonitorInfoW(MonitorFromWindow(msg->hwnd, MONITOR_DEFAULTTONEAREST), &info))
                return false;
            auto *limits = reinterpret_cast<MINMAXINFO *>(msg->lParam);
            limits->ptMaxPosition = {info.rcWork.left - info.rcMonitor.left,
                                     info.rcWork.top - info.rcMonitor.top};
            limits->ptMaxSize = {info.rcWork.right - info.rcWork.left,
                                 info.rcWork.bottom - info.rcWork.top};
            limits->ptMinTrackSize = {qRound(window->minimumWidth() * window->devicePixelRatio()),
                                     qRound(window->minimumHeight() * window->devicePixelRatio())};
            if (result) *result = 0;
            return true;
        }
    }

    if (m_inputWindow && msg->hwnd == reinterpret_cast<HWND>(m_inputWindow->winId())) {
        if (msg->message == WM_INPUT_DEVICE_CHANGE) {
            // Device removal cannot leave a binding or keycap stuck.
            if (msg->wParam == GIDC_REMOVAL) {
                m_deviceKeys.remove(quintptr(msg->lParam));
                m_pressedKeys.clear();
                for (const auto &keys : std::as_const(m_deviceKeys)) m_pressedKeys.unite(keys);
                evaluateBindings(false); emit keyboardStateChanged();
            }
        }
        if (msg->message == WM_INPUT) {
            RAWINPUT input{}; UINT size = sizeof(input);
            const UINT count = GetRawInputData(reinterpret_cast<HRAWINPUT>(msg->lParam), RID_INPUT, &input, &size, sizeof(RAWINPUTHEADER));
            if (count != UINT(-1) && count >= offsetof(RAWINPUT, data) + sizeof(RAWKEYBOARD) && input.header.dwType == RIM_TYPEKEYBOARD) {
                const auto &k = input.data.keyboard;
                const int key = PhysicalKeyboard::windowsKey(k.VKey, k.MakeCode, k.Flags & RI_KEY_E0, k.Flags & RI_KEY_E1);
                const bool down = !(k.Flags & RI_KEY_BREAK);
                const auto *focus = QGuiApplication::focusObject();
                const QString name = focus ? focus->objectName() : QString();
                const bool uiActivation = m_editing && ((key == 13 || key == 269 || key == 32) &&
                    (name == "applyKeyboard" || name == "cancelKeyboard" || name == "combinationMode" || name == "singleMode"));
                const bool editorForeground = QGuiApplication::applicationState() == Qt::ApplicationActive;
                if ((!m_editing || editorForeground) && !uiActivation)
                    {
                    const auto device = quintptr(input.header.hDevice);
                    bool num = m_numLockOn;
                    if (key == 144 && down && !m_deviceKeys.value(device).contains(144)) num = !num;
                    processWindowsKey(k.VKey, k.MakeCode, k.Flags & RI_KEY_E0, k.Flags & RI_KEY_E1, down, num, device);
                    // Pause has no break packet on standard Windows keyboards.
                    if (key == 19 && down) QTimer::singleShot(0, this, [this, device] {
                        processPhysicalKey(19, false, m_numLockOn, device);
                    });
                }
            }
            // Leave WM_INPUT to DefWindowProc for documented foreground-message cleanup.
        }
    }
#else
    Q_UNUSED(data) Q_UNUSED(result)
#endif
    return false;
}
// Background input stays Raw Input only. While the picker is open, an explicit
// Qt right-Alt event is also accepted and coalesced with raw feedback. Other Qt
// events on Windows are consumed to prevent focus navigation/double selection.
bool ClickController::eventFilter(QObject *object, QEvent *event) {
    Q_UNUSED(object)
    if (!m_editing) return false;
    if (event->type() == QEvent::ApplicationDeactivate || event->type() == QEvent::WindowDeactivate) {
        clearKeyboardState(); emit keyboardStateChanged(); return false;
    }
    if (event->type() == QEvent::ShortcutOverride) {
        // Keep Qt shortcuts/mnemonics from stealing an assignment before raw/key
        // capture sees it. Outside the editor normal shortcuts remain untouched.
        event->accept(); return true;
    }
    if (event->type() != QEvent::KeyPress && event->type() != QEvent::KeyRelease) return false;
    auto *e = static_cast<QKeyEvent *>(event);
    if (e->isAutoRepeat()) return true;
    const int qtKey = e->key();
    const auto *focused = QGuiApplication::focusObject();
    const QString name = focused ? focused->objectName() : QString();
    if ((qtKey == Qt::Key_Return || qtKey == Qt::Key_Enter || qtKey == Qt::Key_Space) &&
        (name == "applyKeyboard" || name == "cancelKeyboard" || name == "combinationMode" || name == "singleMode")) return false;
#ifdef Q_OS_WIN
    constexpr bool windowsNative = true;
#else
    constexpr bool windowsNative = false;
#endif
    if (PhysicalKeyboard::qtRightAlt(qtKey, e->nativeVirtualKey(), e->nativeScanCode(), windowsNative)) {
        processPhysicalKey(165, event->type() == QEvent::KeyPress, m_numLockOn, QtAltGrDevice);
        return true;
    }
#ifndef Q_OS_WIN
    int key = qtKey;
    if (key >= Qt::Key_F1 && key <= Qt::Key_F24) key = 112 + key - Qt::Key_F1;
    else {
        const QMap<int,int> special{{Qt::Key_Tab,9},{Qt::Key_Backtab,9},{Qt::Key_Escape,27},{Qt::Key_Return,13},{Qt::Key_Enter,269},
            {Qt::Key_Backspace,8},{Qt::Key_Space,32},{Qt::Key_Control,162},{Qt::Key_Alt,164},
            {Qt::Key_AltGr,165},{Qt::Key_Shift,160},{Qt::Key_Meta,91},{Qt::Key_Menu,93},
            {Qt::Key_CapsLock,20},{Qt::Key_NumLock,144},{Qt::Key_ScrollLock,145},{Qt::Key_Print,44},
            {Qt::Key_Pause,19},{Qt::Key_Insert,45},{Qt::Key_Delete,46},{Qt::Key_Home,36},
            {Qt::Key_End,35},{Qt::Key_PageUp,33},{Qt::Key_PageDown,34},{Qt::Key_Left,37},
            {Qt::Key_Up,38},{Qt::Key_Right,39},{Qt::Key_Down,40},{Qt::Key_Minus,189},
            {Qt::Key_Equal,187},{Qt::Key_Plus,187},{Qt::Key_BracketLeft,219},{Qt::Key_BracketRight,221},
            {Qt::Key_Backslash,220},{Qt::Key_Semicolon,186},{Qt::Key_Apostrophe,222},
            {Qt::Key_Comma,188},{Qt::Key_Period,190},{Qt::Key_Slash,191},{Qt::Key_QuoteLeft,192}};
        key = special.value(qtKey, key);
    }
    const QMap<quint32,int> right{{105,163},{62,161},{108,165},{134,92}};
    if ((qtKey == Qt::Key_Control || qtKey == Qt::Key_Shift || qtKey == Qt::Key_Alt || qtKey == Qt::Key_Meta) && right.contains(e->nativeScanCode())) key = right.value(e->nativeScanCode());
    const bool down = event->type() == QEvent::KeyPress;
    if (key == 144 && down) m_numLockOn = !m_numLockOn;
    if (e->modifiers() & Qt::KeypadModifier) {
        const QMap<int,int> pad{{Qt::Key_Home,103},{Qt::Key_Up,104},{Qt::Key_PageUp,105},
            {Qt::Key_Left,100},{Qt::Key_Clear,101},{Qt::Key_Right,102},{Qt::Key_End,97},
            {Qt::Key_Down,98},{Qt::Key_PageDown,99},{Qt::Key_Insert,96},{Qt::Key_Delete,110},
            {Qt::Key_Period,110},{Qt::Key_Plus,107},{Qt::Key_Minus,109},{Qt::Key_Asterisk,106},{Qt::Key_Slash,111}};
        if (qtKey >= Qt::Key_0 && qtKey <= Qt::Key_9) key = 96 + qtKey - Qt::Key_0;
        else key = pad.value(qtKey, key);
    }
    processPhysicalKey(key, down, m_numLockOn);
#endif
    return true;
}
