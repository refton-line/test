# Incremental security review · 0.6.0 Languages

## Current 0.6.0 languages and animations
Translations are compiled into the executable's resources; no catalogue is loaded from disk or network at runtime. The only new persisted value is `ui/language`, validated against `en`/`ru` (anything else falls back to English). Input handling, the click worker and the profile schema are unchanged; the close animation runs after input has already been stopped, as before.


Manual source review and automated native functional tests, not an independent security audit or penetration test. Windows-only input paths were cross-compiled, not executed here.

## Current 0.5.0 click modes
Blatant and Custom → Сообщения post `WM_*BUTTONDOWN/UP` with `PostMessageW` only to the window under the cursor, after the unchanged checks: the target must still be the foreground window chosen during the countdown (same process/thread), the cursor must be inside it, and the button must not already be held at start. No cross-process injection beyond window messages, no hooks, no new privileges, no cursor movement. Legit and Custom → Эмуляция keep the existing `SendInput` path. A down is always followed by an up, including on cancel. The profile `pattern` block is strictly validated (exact keys, integer/bool types, ranges) before use; unknown keys and fractional envelope versions are rejected. The random generator only shapes timing and is seeded per run from `QRandomGenerator::system()`.

## Retained AltGr capture bridge
The Qt right-Alt bridge runs only while the binding picker is active. It uses explicit identity/native right-side metadata, never the Ctrl/Alt modifier mask. Events from Raw Input and Qt are merged for one editor selection edge; source-local releases and editor deactivation clean up held feedback. No global hook, keyboard injection, extra background collection, telemetry or filesystem permission change. Background Raw Input matcher and all reserved-key validation remain unchanged. Deterministic tests do not certify real Windows event delivery.

## Retained Tab fix
0.4.4 changes only editor Tab routing and adds regression coverage. Windows Raw Input no longer drops Tab; Qt focus navigation is prevented only while the picker is open. No change to background retention, profile schema, reserved-key validation or click timing.

## Retained cleanup
0.4.3 removes two redundant controls, unused UI data/properties/assets and an unused keyCaptured signal. Accessibility labels remain. Profile refresh on page entry is read-only; strict file/path limits remain. The scan-code matcher, configuration schema and click timing algorithms are unchanged relative to 0.4.2. Tests now inspect the actual draft state rather than a compatibility event.

## Retained input surface (introduced in 0.4.2)
Windows Raw Input replaces RegisterHotKey to support arbitrary held chords. A hidden receiver listens nonexclusively for keyboard make/break events. No low-level global hook, injected keyboard events or suppression of other applications' input is installed. Background processing retains only transient configured-key state; no background text, event history or keystroke file is retained. While the editor is active, delivered physical events also drive visible feedback. Closing/deactivating the editor clears visible held state. Applying a binding blocks keys already held until release.

Raw Input does NOT reserve a shortcut: other applications may act on the same keys. Validation rejects duplicate/subset bindings and selected dangerous OS combinations, but cannot guarantee no OS/application conflict. System intercepts, AltGr on real devices, device disconnects and keyboard rollover need Windows hardware acceptance. Do not treat the feature as a way to bypass OS security or input restrictions.

## Configuration boundary
New v3 envelopes carry explicit arrays of 1–3 valid, distinct key identities. Numeric/integer bounds, known fields, maximum 8 bindings/action, profile/file limits, path confinement, symlink rejection, atomic QSaveFile writes and import-with-new-UUID behavior are retained. v1/v2 profiles remain readable; imports do not automatically apply. Back up settings before updating; older executables cannot read the new envelope.

## Unchanged click worker
ClickWorker.cpp, Timing.h and startup validation are byte-compared against the previous 0.4.3 source. Cancellation, foreground/cursor checks, bounded worker state, no catch-up burst and mouse-up retry remain. SendInput acceptance does not prove target application processing. No networking, privilege escalation, driver installation or shell commands from profiles are introduced.

## Residual limits
Unsigned binary. No Windows-runtime, UIPI, antivirus, mixed-DPI or failing SendInput certification. Scan-code unit tests are not proof of every hardware/firmware delivery case. Fn/OS-reserved keys and hardware rollover cannot be guaranteed. Preserve Windows protections; test in a controlled target window first. See QA.md and evidence/altgrcapture.
