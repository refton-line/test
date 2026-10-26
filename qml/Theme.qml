pragma Singleton
import QtQuick

QtObject {
    // Daylight (0.9), after the Liner site: a light grey canvas, white cards with
    // navy hairlines, navy ink, a cyan primary action and coloured light (the
    // "aurora") for live state. Each mode owns one saturated hue for its light.
    readonly property color canvas: "#f3f4f6"
    readonly property color workspace: "#f3f4f6"
    readonly property color chrome: "#ffffff"
    readonly property color surface: "#ffffff"
    readonly property color surfaceHover: "#eceef1"
    readonly property color surfaceRaised: "#e6e8ec"
    readonly property color rail: "#eceef1"
    readonly property color hairline: "#dfe0e5"
    readonly property color rimLight: "#ffffff"
    readonly property color controlBorder: "#787d91"
    readonly property color ink: "#010521"
    readonly property color muted: "#40455f"
    readonly property color faint: "#696e83"
    readonly property color brand: "#0055ff"
    readonly property color sheen: "#ffffff"
    readonly property color shadow: "#010521"
    readonly property color accent: "#97e6ff"
    readonly property color accentEnd: "#8ce1fd"
    readonly property color accentHover: "#7fdbfc"
    readonly property color accentInk: "#010521"
    readonly property color accentSoft: "#e2f5fc"
    readonly property color focus: "#0055ff"
    readonly property color focusOnAccent: "#010521"
    readonly property color danger: "#c22a14"
    readonly property color clear: "transparent"
    readonly property color edge: "#868a9c"
    readonly property color primaryHint: "#6ad2f7"
    // Inverse surfaces (window controls pill).
    readonly property color night: "#0b0e1e"
    readonly property color legit: "#0a7cff"
    readonly property color blatant: "#ff3f1d"
    readonly property color custom: "#47a518"
    function modeColor(mode) { return mode === 0 ? legit : mode === 2 ? custom : blatant; }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    readonly property string sans: "Geist"
    readonly property string mono: "Geist Mono"
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
    readonly property int titleHeight: 72
    readonly property int statusHeight: 44
    readonly property int gutter: 32
}
