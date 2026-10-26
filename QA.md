# C clicker 0.4.7 AltGrCapture: QA

## Current 0.4.7 physical AltGr capture
The Windows editor previously consumed Qt key events without selecting keys, relying exclusively on Raw Input. The new editor-only bridge accepts explicit Qt AltGr and, on Windows, Qt Alt with VK_RMENU / extended right-Alt scan metadata. It does not infer keys from modifier masks. Outside the editor Qt input is unchanged; background matching is still Raw Input only.

Raw and Qt events share held-state union rising edges so one physical press selects once even when both sources deliver it. A regression test fails before this merge fix with `two AltGr delivery sources select exactly once` (altgr-repro.log). This reproduces the duplicate-delivery model on native Linux Qt, NOT the user's physical Windows keyboard failure. Actual Windows event delivery remains unverified here.

642 unit assertions pass: four make/break ordering combinations, raw/Qt autorepeat, Qt-only capture, independent release, real right Ctrl with AltGr, focus-loss recovery, editor-only scope, applying the captured key, and strict native-side recognition. Existing 599 assertions remain. CTest 1/1 passed. Native and Windows cross-builds completed.

All five native capture modes rerun. Keyboard UI uses Qt-only physical AltGr events (not a mouse keycap or direct draft setter), clicks Apply, reopens, and checks Alt R. It additionally delivers both raw metadata and Qt events into the same draft, verifies a single selected key and live feedback, releases both, and applies. These are synthetic event-delivery tests of the real native QML editor, not physical Windows hardware tests.

No QML/theme, worker, timing, startup, configuration validation/schema, or profile-store changes relative to supplied 0.4.6. Only keyboard bridging/union selection, tests/harness and release metadata/documentation changed.

## Retained 0.4.6 standalone binding / label fix
Reproduced a rejection by the single-key compatibility API for standalone physical Alt R (165) before the fix; the 0.4.6 archive records the failing assertion in evidence/bindfix/bindfix-repro-tests.log. Explicit applyChordSlot controller tests already accepted Alt R. The user's physical Windows editor failure was not reproduced on Windows here: do not interpret the compatibility failure as proof of its exact cause.

validKey now accepts side-specific modifiers and PrintScreen consistently with validChordKey. Legacy API entry points canonicalize special standalone keys into explicit key arrays. The editor accepts ShortcutOverride so internal Qt shortcuts do not claim capture keys before the key event; outside-editor shortcuts are unaffected. PrintScreen has an explicit stable name. Name coverage now includes validChordKey, not only validKey, and extends beyond 255 to cover keypad Enter.

599 controller/config/timing assertions: all six modifier sides and PrintScreen as standalone start and stop; apply/config/JSON/settings reload; legacy primary and alternate API routes; AltGr and PrintScreen profile save/load with correct labels; raw-packet global start/stop dispatch, repeat rejection and release/rearm; ShortcutOverride capture only while editing. Existing reserved-combination, subset-conflict, Tab, keypad and cleanup regressions remain.

Native QML keyboard harness now applies standalone AltGr, reopens and verifies it, applies a mouse-selected AltGr H chord and reopens it, applies PrintScreen via mouse and packet replay, verifies its persisted button/chip name, and cancels cleanly. General/window/adaptive/damaged-workspace captures also rerun. Windows executable is cross-built, not run; physical layout/AltGr and OS PrintScreen handling still require Windows acceptance.

No change to click worker, timing, startup, profile store/schema or theme. Changes are limited to input/validation, label mapping and regression harness.

## Retained 0.4.5 input/error fix
The shared Windows decoder now validates the full unsigned scan before any low-byte conversion. Synthetic/invalid high-bit scans, including 0x21d even with E0 set, never become Ctrl. Physical scan/prefix takes precedence over contradictory logical VKs. Zero-scan VK fallback is retained. No time-window suppression of real Ctrl with Alt R is introduced.

Tests replay full packet identities through production processWindowsKey(), also called by nativeEventFilter: synthetic make/break, release-first, both E0 states, repeats, Alt R only, actual left/right Ctrl with Alt R in either order, separate devices and fake release not releasing a real held Ctrl. Tests additionally check conflicting scan/VK identities and malformed scans. These are deterministic decoder/controller tests, not Windows event-delivery tests. A synthetic packet indistinguishable from real Ctrl is not heuristically dropped; physical Windows/layout acceptance remains required.

Binding validation uses draftError only, removing stale QML shadow validation. Conflict and invalid candidates cannot leak into the global banner. Draft edit/cancel/reopen/success and atomic config preservation are tested. Operational registration errors remain global and visible locally while the editor is open. General errors have a 44px accessible dismiss control; dismissal does not modify configuration, readiness or availability.

Native UI regression includes local conflict/cancel, dismissible general error, actual Tab/Shift-Tab Qt events, Windows metadata replay displaying only Alt R, genuine Ctrl R + Alt R feedback and cancellation. Native/cross builds and all five capture modes are rerun for 0.4.5. No worker, timing, profile schema or store change.

## Retained 0.4.4 Tab fix
Removed the special-case exclusion of physical Tab in the Windows Raw Input editor path. The editor consumes Qt Tab/Backtab instead of handing them to focus traversal. The Linux test adapter maps both Qt identities to physical Tab; actual Shift is tracked separately, not fabricated from event modifier flags. Outside the editor, the event filter still returns control to native focus navigation.

Added unit checks for Tab press/release, single/chord selection, Shift with Tab, repeat rejection, repeat-selection removal, virtual/physical draft parity, applying Tab and global Tab rising-edge dispatch/rearm. The native QML harness verifies that physical Tab and Shift-Tab leave the actual focused item unchanged, select the Tab keycap, and persist on apply; ordinary Tab navigation before opening the editor remains tested.

Final 0.4.4 native/cross builds, unit suite and keyboard/general UI scenarios are rerun. Adaptive/window/error scenarios also rerun. No profile-schema, click-worker or timing change.

## Retained 0.4.3 cleanup scope
Removed the inert Session info control and the Configuration refresh arrow. Configuration entry explicitly refreshes the profile list. Removed unused info.svg, tip/neon properties, chosenVK/chosenMods compatibility views, unused bindingName wrapper and keyCaptured compatibility signal. Existing accessibility labels are now declared directly; no tooltip infrastructure remains. KeyboardMap uses one physical v identity; duplicate k/m data and unused modifier property removed, one row per key for readable review. Unused QML imports removed.

Tests use the actual draft array, not the old shadow signal. Static audit rejects the removed surface, legacy map fields, duplicate physical map identities and the unused info asset. Native snapshot assertions reject visible info/refresh controls on every captured page. Final native and cross builds, controller suite, actual QML UI scenarios and PE/ZIP audits rerun for this release.

No configuration, scan-code/chord matching or SendInput algorithm change in 0.4.3. Review is targeted source/dependency cleanup, not proof of a defect-free program or an independent security audit.

## Retained chord behavior
Arbitrary physical chords of 1–3 keys, mouse/keyboard selection into one draft, repeat-to-remove and max-three rejection. Separate chips avoid confusing a separator with the real keypad-plus key. Side-specific Ctrl/Alt/Shift, keypad Enter, dedicated navigation and keypad identities share a scan-code/E0/E1 normalization table with tests. Windows Raw Input replaces RegisterHotKey; a transient rising-edge matcher triggers configured chords nonexclusively. New v3 JSON arrays preserve exact physical keys; old v1/v2 remain readable.

The prior 0.4.2 release intentionally changed input/controller, configuration validation/store and the QML editor. This cleanup removes the unused compatibility signal without changing input matching. ClickWorker.cpp, Timing.h and StartupController files are byte-compared against the previous 0.4.3 source. No click timing/speed improvement claimed. Previous black/red theme, always-on animation, work-area maximize, adaptive popup and clutter cleanup are retained.

## Executed checks
- Native Qt 6.8.3 Release build and MinGW Windows x64 cross-build completed.
- CTest: 1/1 passed. Controller/config/timing suite: **642 assertions passed**.
- Shared Windows physical identity matrix: printable/function/OEM keys, both modifier sides, E0 navigation, keypad operators/Enter, E1 Pause and fake PrintScreen/Pause fragments.
- Draft selection: arbitrary H/Y, mouse/physical mixing, repeated selection removes, auto-repeat ignored, literal Num + as third key, fourth key rejected, modifier identity independent of translated Qt modifier masks.
- Live make/break state, independent releases and multiple input devices; Num Lock off/on gating for every keypad digit and decimal.
- Chord matching: simultaneous versus sequential taps, partial chord, release/rearm, no repeat trigger, stop dispatch, editor suspension, no retention of unrelated background typing, side-specific versus legacy generic modifiers.
- Validation: duplicates, order-independent conflicts, subset overlap, reserved combinations, malformed/fractional/oversized arrays. JSON encode/decode, v3 profile save/apply/export/import and settings reload preserve an explicit side-specific triple. v1 imports and strict file/path limits retained.
- NATIVE_KEYBOARD_UI_PASS: actual Qt QML editor; H/Y mouse toggles; literal-plus triple; side-specific triple; apply/reopen; all ten dedicated navigation keys; Delete applied; modifier held/released and Num Lock states. Final 0.4.4 executable additionally checks Tab capture without editor focus traversal.
- NATIVE_ADAPTIVE_UI_PASS: 150% scale with 1920x1080 Xvfb display and 40px reserved dock; actual mapped keyboard popup contained; initial/maximized geometry fits logical available area.
- NATIVE_WINDOW_UI_PASS: normal/maximized/fullscreen transitions and restore; work area; resize; close cancels immediately.
- NATIVE_CLEAN_UI_PASS, NATIVE_SEGMENTED_UI_PASS and NATIVE_EXTENDED_UI_PASS: retained clutter removal, keyboard-only focus, segmented activation, conflict/max8+8 bindings, profiles and limits.
- NATIVE_ERROR_CAPTURE_PASS: damaged workspace UI; original malformed bytes unchanged.
- Theme audit: 36 contrast pairs and 24 semantic icons; no reported errors. Not accessibility certification.
- Visual review at full size: triple with real Num +; right Ctrl triple; dedicated Delete selection. Adaptive layout and other primary/dialog states included in previews.
- Static normal PE imports, archive integrity, current executable/source byte checks and SHA256 recorded during packaging.

Evidence for current run: evidence/altgrcapture. Captures use isolated test configuration directories and relative scheduling; capture modes modify test profiles. No fabricated browser DOM substitutes for native Qt testing.

## Windows acceptance still required
The Windows executable was **cross-compiled, not executed on Windows**. Native tests run Linux Qt software rendering; click injection is deliberately unavailable there. Scan-code unit tests do not demonstrate physical Windows event delivery. Test both Ctrl/Alt/Shift sides, AltGr with your layout, every navigation key, keypad Num Lock transitions, device removal and multikey rollover on actual hardware. Fn/OS intercepts and hardware rollover are not software guarantees. Win/F12 remain unavailable; editor Tab is captured as a binding, with no focus traversal; outside the editor, Tab navigation is retained.

Raw Input does not reserve or suppress shortcuts; other programs can also react. No universal shortcut availability claim. Windows SendInput/UIPI, taskbar work-area behavior, multiple monitors/mixed DPI, real click rate/latency and failing input release need controlled Windows tests. No performance or security certification. Extract the whole archive, back up settings before migration, and do not disable Windows protections for the unsigned executable.
