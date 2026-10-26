# Design research: October 20, 2026

This is a curated working set, not a claim to have ranked all applications of 2025–2026. Product screenshots were inspected locally; links preserve their original attribution. No third-party application artwork is bundled in the release.

| Source | Material examined | Applied to C clicker | Rejected |
|---|---|---|---|
| [Linear: UI refresh, March 12, 2026](https://linear.app/changelog/2026-03-12-ui-refresh) | Official release and redrawn icon / header changes | Clear hierarchy and repeatable chrome | Turning a utility into an issue tracker |
| [Linear: Behind the latest refresh](https://linear.app/now/behind-the-latest-design-refresh) | Actual before/after sidebar, tab and border comparisons; header construction diagrams | Quiet navigation, stronger work area, fewer competing borders | Low-contrast text and decorative colored icon backgrounds |
| [Raycast Windows 2025 changelog](https://www.raycast.com/changelog/windows/5) | Hotkey recorder screenshot and release notes, including October 27, 2025; launch images separately identified as marketing | Readable recorded key combinations, clear apply/cancel | Launch graphics are not product UI; no confetti or red glow copied |
| [Raycast Windows 2026 changelog](https://www.raycast.com/changelog/windows) | Theme-aware monochrome app icons and automatic contrast adjustments | Semantic foreground-based icon tinting on dark and light controls | One fixed SVG color for every button state |
| [Zed: 2025 recap](https://zed.dev/2025) | Dark Git panel, debugger workspace and Windows screenshot | Operational density, mono numerals, purposeful panel division | IDE-level tool density in a single-purpose clicker |
| [PowerToys Command Palette](https://learn.microsoft.com/en-us/windows/powertoys/command-palette/overview) | Actual animated application interface, inspected frame; keyboard-first and compact-mode behavior | Labeled command affordances and visible keyboard context | Platform-specific acrylic effects and giant search UI |
| [Affinity: new features](https://www.affinity.studio/help/introduction-new-features/) | Official text describing monochrome iconography, cleaner tools and unified shortcuts; screenshot fetch was blocked by a browser-support page | One icon weight, progressive disclosure of limits | Copying a creative-suite layout; no claim of visual inspection of blocked images |
| [Affinity: Studios](https://www.affinity.studio/help/workspace-about-studios/) | Workflow-scoped tool and panel explanation | Each destination has only the controls needed there | Exposing all advanced controls on the main screen |

## Attached examples and skills

- Existing C clicker Beta 2 screenshots, QML, DESIGN.md and the supplied engine description were the product baseline. The two source ZIPs have identical sizes and duplicate contents; one working copy was edited.
- The supplied `viora-design-skills` 4.2.0 and bundled artifact-design guidance were read and used. Native Qt build / image capture / QML theme audit replace web-only CSS and browser checks; a web checker alone does not verify this app.
- IIOL is a gallery of 147+ experimental landing concepts, not a production desktop component library. Sample title/style metadata, including INK, was examined; it was not blindly imported into the click engine. Heavy fluid/background effects are intentionally excluded from the app.
- Craft OS26 was explored as a research lead, but the live URL redirected to the general product homepage. It is not counted as a verified OS26 screenshot reference.

## Darker palette follow-up

User reference: [Spectra](https://getspectra.com/), inspected in its explicit Dark theme on October 20, 2026. Applied only the near-black neutral background and subtle surface steps, not the landing-page layout, pixel branding or dotted background. No Spectra assets are bundled.

## Beta 4 — additional app-interface study

Reviewed official product pages and their actual UI images, not only landing-page headlines:

- [Raycast, new interface](https://www.raycast.com/new): compact command surfaces and inline shortcut hints. Inspected official look-and-feel image; did not copy glass, icons, logos or macOS chrome.
- [Bear](https://bear.app/): strong separation of working regions, typography-first hierarchy and a quiet selected row. Inspected official Mac UI image. Kept C clicker's dark palette, not Bear's white editor or red branding.
- [Things features](https://culturedcode.com/things/features/): progressive disclosure, quick-find selection and restrained grouping. Its illustrated Things 3 feature page contains historical imagery; this is not described as a 2026 redesign.
- Existing [Linear UI research](https://linear.app/now/behind-the-latest-design-refresh) and the user's [Spectra dark reference](https://getspectra.com/) informed quiet structure and near-black neutral surfaces.

Applied: cohesive segmented settings, fewer strong secondary-action outlines, an interval instrument well, measured session hierarchy and right-aligned dialog actions. No reference product images or assets are bundled in the app.

## Red / Black variant
User-pinned refinement: neutral black like the supplied Linear reference, with deep dark red accents only. The chosen hex values are original implementation tokens, not claimed exact Linear colors. No additional web research was needed for this palette-only pass.

## 0.4.2 physical keyboard implementation
- Microsoft RAWKEYBOARD structure: https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawkeyboard
- Microsoft using Raw Input: https://learn.microsoft.com/en-us/windows/win32/inputdev/using-raw-input

## 0.4.5 input validation note
RAWKEYBOARD stores E0/E1 in Flags separately from MakeCode: https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-rawkeyboard . The decoder rejects high-bit/malformed scans instead of silently truncating them. SDL also explicitly skips the synthetic 0x21d Ctrl in its low-level hook (https://github.com/libsdl-org/SDL/blob/main/src/video/windows/SDL_windowsevents.c); that hook is not Raw Input and is not evidence that every layout/driver exposes the marker in RAWKEYBOARD. No global hook or timing-based AltGr guess was added to this application.

### Qt AltGr editor bridge (0.4.7)
QKeyEvent exposes key(), nativeVirtualKey() and nativeScanCode(): https://doc.qt.io/qt-6/qkeyevent.html . The bridge accepts explicit Qt::Key_AltGr; only on Windows it also interprets right-Alt native metadata. Raw Input remains the background source. Tests cover bridge/merge behavior, not every Windows layout/driver's real delivery.

## 0.5.0 click modes (October 26, 2026)
- [OP Auto Clicker features](https://opautoclicker.io/features.html), 4.1 notes (read as text, no screenshots inspected): a base interval plus an optional "Random offset ±" millisecond field (100 ms ± 40 ms), mouse button choice and repeat-until-stopped/count. Applied: randomness as a first-class, opt-in parameter next to the interval (Custom ± %), button choice and limits kept as compact rows. Rejected: hours/minutes/seconds/ms field grid, which doesn't suit a CPS-oriented tool.
- CPS ranges are the established control vocabulary of gaming auto-clickers. Applied as a two-handle range plus named presets instead of two separate numeric fields. No third-party UI or assets copied.
- [Qt 6 RangeSlider](https://doc.qt.io/qt-6/qml-qtquick-controls-rangeslider.html): native two-handle control with keyboard support, restyled with Theme tokens.
- Win32 [SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput) vs. posted [WM_LBUTTONDOWN](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-lbuttondown): SendInput enters the system input stream like a device, while posted messages reach only the target window's queue and do not update cursor/async button state. This split is the Legit / Blatant delivery difference.
- Existing Linear / Raycast / Affinity notes above (progressive disclosure, compact header controls, mono numerals) informed placing the mode switch in the heading row and showing only that mode's controls.
