pragma Singleton
import QtQuick

QtObject {
    // Graphite / Silver (0.8). Neutral grey surfaces, white light. The primary
    // action is a light silver face with near-black text; glows are white. Modes
    // differ by brightness, from steel to pure white, so the hottest mode glows most.
    readonly property color canvas: "#08090a"
    readonly property color workspace: "#0b0c0e"
    readonly property color chrome: "#090a0b"
    readonly property color surface: "#121316"
    readonly property color surfaceHover: "#191a1e"
    readonly property color surfaceRaised: "#1f2126"
    readonly property color rail: "#0d0e10"
    readonly property color hairline: "#24262b"
    readonly property color rimLight: "#3d4047"
    readonly property color controlBorder: "#74777f"
    readonly property color ink: "#f2f3f5"
    readonly property color muted: "#9c9fa7"
    readonly property color faint: "#666970"
    readonly property color brand: "#eef0f4"
    readonly property color sheen: "#ffffff"
    readonly property color accent: "#eceef2"
    readonly property color accentEnd: "#c3c7cf"
    readonly property color accentHover: "#ffffff"
    readonly property color accentInk: "#0b0c0f"
    readonly property color accentSoft: "#26282e"
    readonly property color focus: "#e8eaee"
    // Focus ring on the light primary face.
    readonly property color focusOnAccent: "#0b0c0f"
    // Errors keep a soft red: a fault has to read as a fault even in a grey UI.
    readonly property color danger: "#f2a4a4"
    readonly property color clear: "transparent"
    readonly property color edge: "#868991"
    readonly property color primaryHint: "#adb2bc"
    readonly property color legit: "#aab1bd"
    readonly property color blatant: "#ffffff"
    readonly property color custom: "#7c8494"
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
