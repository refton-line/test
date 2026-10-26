# C clicker 0.9.0 Daylight: QA

## Current 0.9.0 Daylight
- Palette, fonts, shell layout, aurora and icon; no engine changes. `scripts/audit-ui.py` passes on the light palette; the lowest ratio is controlBorder on surfaceRaised at 3.33 (3.0 minimum).
- The motion capture's close check was timer-based and failed intermittently on a cold start: a slow screenshot let the 400 ms close outrun the step. It now polls the close on every event-loop turn, checks the content-before-shell order and the C position on 11-20 frames per run, and passes on that evidence before taking its picture. 8 of 8 consecutive runs passed. Software frame times during the run: median 3 ms.
- The edge-glow checks now target `auroraLive`: invisible at rest, fully up while live, gone after stopping, plus the existing pixel-identical settle frames.
- All eight captures plus adaptive at 150 % pass. The icon in the EXE is byte-identical to app.ico in all nine sizes.
- Visual review of every page and dialog against the reference. The first aurora drew discrete bars and a comb-like rest stripe and was rebuilt as smooth curtains; hard-edged streaks were replaced by soft radial ones.


## Current 0.8.0 palette
Palette, icon and C mark only; no logic or motion changes. `scripts/audit-ui.py` passes (theme "Graphite / Silver"; the lowest ratio is controlBorder on accentSoft at 3.29 against a 3.0 minimum). The focus check on the primary face now uses focusOnAccent. All eight captures plus adaptive pass, including the settle and close-completion audits and NATIVE_ICON_PASS. The icon in the cross-built EXE is byte-identical to assets/app.ico in all nine sizes. Captures of every page and dialog were reviewed for leftovers of the old colours. One was found and removed: a warm-white glint dot on the icon.


## Current 0.7.1 icon and startup card
- `NATIVE_ICON_PASS`: QGuiApplication::windowIcon() loaded from the embedded app.ico exposes all nine sizes (16, 20, 24, 32, 40, 48, 64, 128, 256).
- The icon resource extracted from the cross-built CClicker.exe (wrestool) has the same nine entries as assets/app.ico, and each extracted image is byte-identical. Before the CMake fix the EXE still carried the old icon; that is how the missing dependency was found.
- `scripts/audit-ui.py` passes again. The 0.7.0 redesign had broken it with accentInk on accentHover at 4.24 (now #d42d45, 4.57). The audit now also checks accentEnd (was 4.43, now #c63a27, 4.83). Its icon scan no longer mistakes `State { name: ... }` for an icon name.
- The startup card was reviewed in captures and in a real-time recording (xcb, OpenGL/llvmpipe): ring fill with glint, ready flare, ripple handoff. The breathing loop runs only while the card is visible and loading, so the settle audit after opening stays clean.
- Icon sizes were checked on dark and light backgrounds at 1x and zoomed. 16–48 px come from the small variant because the full one turned muddy at 40–48 px.


## Current 0.7.0 design, glow and control model
No engine or storage changes; 725 unit assertions unchanged; translations_complete now covers 236 messages. All eight capture modes pass plus adaptive at 150 %. New in the harness:
- `assertSettled` after opening, page change, mode change, error banner, edge glow off, and both language switches: no running QQuickAbstractAnimation in the tree, Stage opacities exactly 0/1 with hidden stages invisible, edge glow invisible, two frames 150 ms apart identical.
- `CloseAudit` (motion and window captures) at the real QCloseEvent: expansion 0, dismissal 0, C erase 1, every pixel of the last frame clear. Prints `NATIVE_CLOSE_COMPLETE_PASS`.
- Motion capture also checks the tab pill and light, the mode selection frame, edge glow up and down, that the ring light turns while live and rests at 0 degrees after.
The running visuals are exercised through a capture-only preview flag (`glowDemo`, guarded by `uiCapture`); the engine itself cannot send input under the harness.

A real-time recording (Xvfb + xcompmgr, xcb, OpenGL via llvmpipe, `--capture-motion-reel`) was reviewed frame by frame: opening cascade, tab and page travel, mode hue crossfade, edge glow while running in all three hues, error rise/leave, and a close that ends on the desktop with nothing left. It found two issues the static captures could not: the draw-in arc popping at full brightness at the start of a close, and a page overlap long enough to read as a double exposure. Both fixed and re-recorded.


## Current 0.6.1 motion system
No engine, storage or translation changes (`translations_complete` still 232 messages; 725 unit assertions unchanged). New native capture `--capture-motion-tests` (`NATIVE_MOTION_UI_PASS`): right after a nav click the new page already exists while the old one is still visible (no blank gap); after settling the old page is hidden, the rail pill sits on the new item and the marker is back to 18px, centred; the mode thumb slides to the chosen segment's exact geometry; mode bodies settle; the error banner rises to full opacity and leaves after dismiss; during the close, at two points of the timeline, content progress never exceeds shell progress and the C stays at the shell-corner position. All eight capture modes pass, plus adaptive at 150 %.

A real-time recording under Xvfb (xcb, software renderer, `--capture-motion-reel`) was reviewed frame by frame: opening cascade, page and mode transitions, error rise/leave and close fold all play in order. An earlier reel scheduled steps with independent timers, which bunched under load; the reel now uses the relative step runner.

Found and fixed during review: an exposure overlap in mode switching (both bodies ~50 % visible mid-switch), and the CPS slider animating its own initial layout (knobs sliding in from the left). The slider now animates value changes only.


## Current 0.6.0 languages and animations
725 controller assertions (711 retained + 14): English default and locale, translated mode summary / run state / validation error / QML string, unknown language rejected, switch to Russian stored and reflected in derived text, persistence across controller restarts, back to English, missing catalogue falls back to Russian, invalid stored value falls back to English. New CTest `translations_complete` re-runs lupdate over all sources and fails on new, stale, unfinished, empty, placeholder-mismatched or Cyrillic English entries (232 messages pass).

Native captures (Linux offscreen, Qt 6.8.3), all passing: general, modes, new `--capture-language-tests` (`NATIVE_LANGUAGE_UI_PASS`: English default; no Cyrillic in visible text on Clicker, Log, Controls, keyboard picker, Profiles, Language and the limits dialog, except the native "Русский" card; switch to Russian updates nav, start button and C++ mode summary and persists; switch back), window (`NATIVE_WINDOW_UI_PASS` now also requires the close fold: expansion strictly between 0 and 1 mid-close), keyboard, error, adaptive at 150 %. Error dismissal is asserted on the banner's `shown` state because it now fades out. The capture profile name is now Latin ("Test · 200 / s") so English previews contain no harness-entered Cyrillic.

Not verified here: the window mask during the close fold and translucency on real Windows; the Windows EXE is cross-built, not run.


## Current 0.5.0 click modes
711 controller/config/timing assertions pass (642 retained, one updated: profile envelope version 3 → 4, because v4 adds the pattern block). New checks: Legit default and CPS range setters/validation; Blatant 1 ms floor and snap back to 5 ms on leaving; Custom jitter/delivery/drift bounds; pattern JSON round trip for all modes, malformed pattern rejection, 0.4.7 JSON loading as Custom with the exact fixed-grid SendInput plan; v4 profile save/apply/reload, v3 import, fractional envelope version rejected. Generator statistics over 20 000 steps: Legit mean CPS inside the range, gap CV 0.06–0.35, >95 % distinct gaps, hold always < gap and 30–55 % of the cycle, tempo drift between 50-click windows, 0.4–3 % micro-pauses, 30 CPS edge case; Blatant exact gaps; Custom ±20 % bounds and unbiased mean, ±12 % wave, extreme 5 ms / 50 % jitter never yields hold ≥ gap; seed determinism.

Native captures, all passing on Linux offscreen/software Qt 6.8.3: general (`NATIVE_CLEAN_UI_PASS`, `NATIVE_SEGMENTED_UI_PASS` now also checks the mode switch, `NATIVE_ERROR_LIFECYCLE_PASS`, `NATIVE_EXTENDED_UI_PASS`), new `--capture-mode-tests` (`NATIVE_MODE_UI_PASS`: Legit preset, Custom recipe, Blatant 2 ms, return to Legit restores the 5 ms floor), window, keyboard, error, adaptive at QT_SCALE_FACTOR=1.5. Previews regenerated, incl. mode-legit/mode-blatant/mode-custom.png.

Not verified here: actual SendInput/PostMessage delivery on Windows, and which target programs accept posted window messages. The Windows EXE is cross-built with MinGW, not run.


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
