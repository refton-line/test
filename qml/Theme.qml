pragma Singleton
import QtQuick

QtObject {
    // Ember / Graphite (0.7). Cool blue-graphite surfaces so warm light reads as
    // light; ember red is the brand and the primary action. Each click mode owns a
    // hue that drives every glow, so the mode is legible from across the room.
    readonly property color canvas: "#07080b"
    readonly property color workspace: "#0a0c10"
    readonly property color chrome: "#08090d"
    readonly property color surface: "#10131a"
    readonly property color surfaceHover: "#161a23"
    readonly property color surfaceRaised: "#1b2030"
    readonly property color rail: "#0c0e14"
    readonly property color hairline: "#1f2431"
    readonly property color rimLight: "#2c3346"
    readonly property color controlBorder: "#646d82"
    readonly property color ink: "#edf0f6"
    readonly property color muted: "#8b93a7"
    readonly property color faint: "#5a6175"
    readonly property color brand: "#ff4d5e"
    readonly property color ember: "#ff7a45"
    readonly property color accent: "#c8283f"
    readonly property color accentEnd: "#cf3f2a"
    readonly property color accentHover: "#dc3249"
    readonly property color accentInk: "#fff4f2"
    readonly property color accentSoft: "#2a1520"
    readonly property color focus: "#e6eaf3"
    readonly property color danger: "#ff8a96"
    readonly property color clear: "transparent"
    readonly property color edge: "#7d859a"
    readonly property color primaryHint: "#a81f34"
    // Mode hues: Legit is cool and calm, Blatant is the hot brand red, Custom is violet.
    readonly property color legit: "#2fd6c3"
    readonly property color blatant: "#ff4d5e"
    readonly property color custom: "#a48bff"
    function modeColor(mode) { return mode === 0 ? legit : mode === 2 ? custom : blatant; }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    readonly property string sans: "Manrope"
    readonly property string mono: "JetBrains Mono"
    readonly property int small: 14
    readonly property int body: 16
    readonly property int title: 24
    readonly property int radiusSmall: 6
    readonly property int radius: 10
    readonly property int radiusLarge: 14
    readonly property int control: 44
    // Motion durations (ms). Curves live in components/Motion.js.
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int keyFeedback: 75
    readonly property int openTimeline: 820
    readonly property int closeTimeline: 400
    readonly property int closeFade: 170
    readonly property int pageIn: 380
    readonly property int pageFade: 220
    readonly property int pageOut: 120
    readonly property int pageFadeOut: 90
    readonly property int pageOverlap: 30
    readonly property int pageRise: 18
    readonly property int modeTravel: 24
    readonly property int railTravel: 340
    readonly property int thumbTravel: 300
    readonly property int dialogEnter: 300
    readonly property int dialogExit: 130
    readonly property int languageOut: 110
    readonly property int languageIn: 280
    readonly property int glowIn: 420
    readonly property int glowOut: 320
    readonly property int hueShift: 480
    readonly property int rimTurn: 4800
    readonly property int heroTurn: 9000
    readonly property int breathe: 1600
    readonly property int glint: 700
    readonly property int ripple: 900
    readonly property int reveal: 560
    readonly property int baseWidth: 1160
    readonly property int baseHeight: 800
    readonly property int splashWidth: 480
    readonly property int splashHeight: 340
    readonly property int titleHeight: 64
    readonly property int statusHeight: 48
    readonly property int gutter: 32
}
