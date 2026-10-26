pragma Singleton
import QtQuick

QtObject {
    // Red / Black: neutral black surfaces; deep crimson only for actions and selection.
    readonly property color canvas: "#090909"
    readonly property color workspace: "#0c0c0d"
    readonly property color surface: "#141415"
    readonly property color surfaceHover: "#1c1c1e"
    readonly property color surfaceRaised: "#301317"
    readonly property color rail: "#070707"
    readonly property color hairline: "#272727"
    readonly property color controlBorder: "#858585"
    readonly property color ink: "#f0f0f0"
    readonly property color muted: "#b5b5b5"
    readonly property color brand: "#b83e4a"
    readonly property color accent: "#8e1b25"
    readonly property color accentHover: "#a42530"
    readonly property color accentInk: "#fff1f3"
    readonly property color accentSoft: "#331318"
    readonly property color focus: "#d3d3d3"
    readonly property color danger: "#e599a1"
    readonly property color clear: "transparent"
    readonly property color edge: "#a0a0a0"
    readonly property color primaryHint: "#68121a"
    readonly property string sans: "Manrope"
    readonly property string mono: "JetBrains Mono"
    readonly property int small: 14
    readonly property int body: 16
    readonly property int title: 24
    readonly property int radiusSmall: 6
    readonly property int radius: 10
    readonly property int radiusLarge: 14
    readonly property int control: 44
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int pageExit: 85
    readonly property int pageEnter: 170
    readonly property int pageTravel: 14
    readonly property int dialogEnter: 150
    readonly property int dialogExit: 100
    readonly property int keyFeedback: 75
    readonly property int exitDuration: 170
    readonly property int exitMorph: 300
    readonly property int languageOut: 90
    readonly property int languageIn: 220
    readonly property int reveal: 560
    readonly property int baseWidth: 1160
    readonly property int baseHeight: 800
    readonly property int splashWidth: 480
    readonly property int splashHeight: 340
    readonly property int railWidth: 172
    readonly property int gutter: 32
}
