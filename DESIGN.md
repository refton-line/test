# C clicker: Chords / Red Black

Native Qt Quick desktop utility, Cyrillic UI. Neutral black working surfaces, deep dark red for primary actions and selection. User-pinned refinement, not a new product/brand or engine.

## Direction
A quiet instrument, not a dashboard template. One visible page heading, one primary action, a labelled 172px navigation rail, a control area and a narrower session region. No decorative chrome copy. The small red C remains the only persistent brand mark. Startup retains its real progress bar and C-to-rail transition.

## Subtraction
Removed the top app-name label, top profile/modified label, visible Beta/version stamp, bottom status/footer and divider, repeated start/stop shortcuts, run-button shortcut badge and activation tooltip, hotkeys from profile row summaries, redundant binding tooltips, startup readiness/percentage copy and permanent successful-save boilerplate. Actual key assignments remain in Management. Errors, conflict recovery, empty-state guidance and live countdown remain functional. Countdown now lives inside Session.

## Detail
Removed the interval's extra outer well. Softer group borders instead of bright enclosing frames. Selected choices use a dark red fill plus semibold type and native checked semantics, without repeated bottom underlines; navigation retains its left marker. Neutralized the pink cast in text, focus and control gray. No glow, gradients, new charts, fake telemetry or ornamental animations.

## Contract
qml/Theme.qml is the only runtime token authority. Manrope and JetBrains Mono are bundled with Cyrillic coverage; radius family 6/10/14; native Controls keyboard behavior, 44px action targets, keyboard-only visual focus retained; animation-disable feature removed. Dialogs use a short opacity reveal over an opaque face, without scaling. Closing stops input before animation. Fullscreen restores the prior window state; F11 avoids stealing a configured click binding. Worker/timing engine and storage identity unchanged; input matching now uses Windows Raw Input and the JSON envelope is v3, with v1/v2 read compatibility. Packaging version remains in metadata and documentation, not in the working UI.

Current values: workspace #0c0c0d, rail #070707, canvas #090909, panel #141415, primary red #8e1b25, selected #301317, pressed #331318. Not claimed to be exact Linear tokens.

Removed six unused Theme aliases and five unreferenced SVG pictograms; startup-validated resources and runtime dependencies retained. Native progress accessibility uses a description because Qt attached Accessible has no value property.

## Interaction refinement
Explicit single/chord switch, distinct live and saved keyboard states, physical press/release tracking with side-specific modifier identity, Num Lock guard for keypad navigation. Preserve native Tab traversal outside the binding editor, and focus rings for keyboard navigation. Inside the editor, Tab/Shift-Tab are captured as binding keys. Neutral hover cannot masquerade as a saved red selection. No button tooltips; semantic accessible names remain. Navigation has an 85ms outgoing phase and a 170ms incoming phase, with direction derived from the rail order and rapid requests coalesced. Dialogs use 150/100ms opacity transitions; physical key feedback uses 75ms color interpolation, not key scaling. Animations are always on, by explicit user request. This removes the former in-app motion preference and is not presented as reduced-motion accessibility compliance.

Window positions are centered once in the monitor work area in C++; no size-dependent x/y bindings. UI scale follows actual window dimensions with a capped native layout. Fullscreen remains separate from work-area maximize. Windows min/max filtering avoids forcing native handle creation during creation callbacks.

## Physical chord editor (0.4.2)
Single-key / combination modes share one draft, selected by mouse or physical events. A combination is 1–3 distinct physical keys; repeat selection removes it. Each key is a separate removable chip, never a plus-delimited expression. The real keypad-plus key remains independently selectable. Bright live feedback and dark saved selection remain distinct. Reserved/nonassignable keycaps remain visible. Native scan-code normalization is shared with tests, rather than inferred from translated modifier masks.

## 0.4.3 subtraction pass
Removed the Session info ornament and the Configuration refresh arrow. The list refreshes on page entry and after mutations; no replacement ornamental button. Removed unused info asset and compatibility-only state/API while keeping semantic labels for icon-only window and binding controls. Physical keyboard data now has a single v identity, shared by live, selected and Num Lock states. No visual redesign or timing change.

## 0.4.4 Tab capture
No new controls. Tab is a physical assignment key while the picker is open, not a traversal command. Shift-Tab uses the same physical Tab identity plus the actual held Shift side. Outside the picker, normal focus navigation is unchanged.

## InputFix 0.4.5
One production processWindowsKey entry point feeds both Raw Input and packet replay tests. Full scan validation precedes normalization; no speculative removal of physical Ctrl near AltGr. Draft errors have one owner (controller); QML displays draftError directly. Global error dismissal changes presentation only, never readiness/configuration.

## BindFix 0.4.6
validKey and validChordKey agree on physical side-specific modifiers and PrintScreen. Alternate single-key APIs canonicalize special standalone identities into explicit arrays; explicit editor arrays stay unchanged. Capture accepts Qt ShortcutOverride without manufacturing a draft key. keyName(44) is PrintScreen; label coverage tests both key validators, including keypad Enter above 255.

## AltGrCapture 0.4.7
No new visual controls. An editor-only Qt right-Alt bridge supplements Raw Input capture. Press identity uses explicit AltGr or Windows right-side native metadata, not translated modifier flags. The editor selects on held-state union rising edges to coalesce both deliveries; releasing one source does not release another. Background matching and storage remain unchanged.

## Languages and motion 0.6.0
A fifth rail destination, Language, with a globe icon in the existing 1.75px stroke style. Two equal cards (EN / RU) show the code in large mono, the native language name and a sample line in that language; the selected card uses the same crimson fill, edge marker and a check badge that scales in. Changing language fades the whole interface out (90 ms), swaps the catalogue while invisible and fades back (220 ms). Default English; the Russian copy stays the source text. "Конфигурации" is "Profiles" in English: shorter in the rail and matches the wording of the list.

Motion is extended where state used to snap, by explicit user request: closing reverses the opening morph (shell folds to the 480×340 card, C re-centres, 300 ms InOutCubic) before the existing 170 ms fade, with the native window mask re-enabled so only the card remains visible; mode bodies crossfade with a 14px slide (85/170 ms like pages); the error banner fades and rises 12px; dialogs add a 0.96→1 scale to their opacity reveal; navigation and profile markers grow from 0; the session dot breathes (1.2 s) only while sending. Input still stops before any closing animation.

## Modes 0.5.0
Same instrument, one new decision at the top. The page heading row now carries a three-way mode switch (Легит / Блатант / Свой) on the right, with a single muted sentence underneath saying what the mode physically does. Only the chosen mode's controls are shown (progressive disclosure, see REFERENCES.md). Legit shows a large mono CPS range, a two-handle range slider with quiet 1/10/20/30 ticks and four named range presets. Blatant keeps the original large interval instrument and presets, now 10–500 / s, plus hold. Custom lists every knob in labelled rows, with segmented choices for delivery and tempo.

The new Ритм strip draws the next 48 planned gaps as thin bottom-aligned crimson bars that fade with distance; a flat row means an exact grid. It is generated by the worker's own generator with a fixed preview seed and labelled with its min–max in ms, so it's a plan rather than fake telemetry. The session card gets a small mode chip (filled red only for Blatant) and a muted mono target rate next to the measured one. Mouse button and stop conditions now share one row to keep the 548px page height. The profile list shows the full mode summary instead of only the interval.

No new colours, gradients or glow. New QML: Segmented (shared 44px segmented frame), CpsRange, RhythmStrip. Theme.qml stays the only token authority. Worker timing for fixed patterns is unchanged (absolute QPC grid); variable patterns schedule gap by gap and drop whole missed gaps instead of bursting.
