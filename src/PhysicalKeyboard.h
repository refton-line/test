#pragma once
#include <QMap>
#include <QtCore/Qt>
// Shared by the Windows Raw Input path and platform-independent unit tests.
// IDs are VK-compatible, with 269 reserved for the physically separate keypad Enter.
namespace PhysicalKeyboard {
inline int windowsKey(int vk, unsigned scan, bool e0, bool e1) {
    // RAWKEYBOARD carries E0/E1 separately. Do not truncate a marked synthetic
    // scan (notably 0x21d) into physical Ctrl 0x1d, even if E0 is also supplied.
    // No timing heuristic: a genuine Ctrl followed by Alt R must remain a chord.
    if (vk <= 0 && !scan) return 0;
    if (vk >= 255 || scan > 0x7f) return 0; // overrun, synthetic or malformed scan
    if (e1) return vk == 19 ? 19 : 0; // Pause, never its synthetic Ctrl fragment
    if (e0 && (scan == 0x2a || scan == 0x36)) return 0; // PrintScreen fake Shift
    if (vk == 19) return 19;
    // Scan + prefix wins over layout-translated or contradictory logical VK.
    if (scan == 0x1d) return e0 ? 163 : 162;
    if (scan == 0x38) return e0 ? 165 : 164;
    if (scan == 0x2a || scan == 0x36) return scan == 0x36 ? 161 : 160;
    if (!scan) {
        if (vk == 17 || vk == 162 || vk == 163) return (e0 || vk == 163) ? 163 : 162;
        if (vk == 18 || vk == 164 || vk == 165) return (e0 || vk == 165) ? 165 : 164;
        if (vk == 16 || vk == 160 || vk == 161) return vk == 161 ? 161 : 160;
    }
    if (e0) {
        static const QMap<unsigned,int> extended{{0x1c,269},{0x35,111},{0x37,44},
            {0x47,36},{0x48,38},{0x49,33},{0x4b,37},{0x4d,39},{0x4f,35},
            {0x50,40},{0x51,34},{0x52,45},{0x53,46},{0x5b,91},{0x5c,92},{0x5d,93}};
        if (extended.contains(scan)) return extended.value(scan);
    } else {
        static const QMap<unsigned,int> plain{
            {0x01,27},{0x02,49},{0x03,50},{0x04,51},{0x05,52},{0x06,53},{0x07,54},
            {0x08,55},{0x09,56},{0x0a,57},{0x0b,48},{0x0c,189},{0x0d,187},{0x0e,8},{0x0f,9},
            {0x10,81},{0x11,87},{0x12,69},{0x13,82},{0x14,84},{0x15,89},{0x16,85},
            {0x17,73},{0x18,79},{0x19,80},{0x1a,219},{0x1b,221},{0x1c,13},
            {0x1e,65},{0x1f,83},{0x20,68},{0x21,70},{0x22,71},{0x23,72},{0x24,74},
            {0x25,75},{0x26,76},{0x27,186},{0x28,222},{0x29,192},{0x2b,220},
            {0x2c,90},{0x2d,88},{0x2e,67},{0x2f,86},{0x30,66},{0x31,78},{0x32,77},
            {0x33,188},{0x34,190},{0x35,191},{0x37,106},{0x39,32},{0x3a,20},
            {0x45,144},{0x46,145},{0x47,103},{0x48,104},{0x49,105},{0x4a,109},
            {0x4b,100},{0x4c,101},{0x4d,102},{0x4e,107},{0x4f,97},{0x50,98},
            {0x51,99},{0x52,96},{0x53,110},{0x56,226},{0x57,122},{0x58,123}};
        if (scan >= 0x3b && scan <= 0x44) return 112 + int(scan - 0x3b);
        if (plain.contains(scan)) return plain.value(scan);
    }
    return vk; // recognized OEM/media keys may be shown, but are not necessarily assignable
}
// Qt Windows can expose right Alt as AltGr, Alt + VK_RMENU, or Alt with
// the extended scan marker packed into nativeScanCode. Never infer it from
// Control/Alt modifier masks: those masks may include layout-generated Ctrl.
inline bool qtRightAlt(int qtKey, unsigned nativeVk, unsigned nativeScan, bool windowsNative) {
    return qtKey == Qt::Key_AltGr ||
        (windowsNative && qtKey == Qt::Key_Alt &&
         (nativeVk == 165 || nativeScan == 0x138 || nativeScan == 0xe038));
}
inline bool keypadDigit(int key) { return (key >= 96 && key <= 105) || key == 110; }
inline bool relevant(int key, const QList<int> &keys) {
    return keys.contains(key) || (keys.contains(17) && (key == 162 || key == 163)) ||
        (keys.contains(18) && (key == 164 || key == 165)) || (keys.contains(16) && (key == 160 || key == 161));
}
} // namespace PhysicalKeyboard
