import QtQuick
import CClicker
import "Motion.js" as Motion

// Planned gaps from the same generator the worker uses (fixed preview seed).
// Taller bar = longer gap. Not live telemetry.
Item {
    id: strip
    property var gaps: []
    readonly property real low: gaps.length ? Math.min.apply(null, gaps) : 0
    readonly property real high: gaps.length ? Math.max.apply(null, gaps) : 0
    implicitHeight: 52
    function fmt(v) { return v.toLocaleString(Qt.locale(i18n.locale), 'f', v < 10 ? 1 : 0) }
    Label {
        id: caption
        text: qsTr("Ритм")
        color: Theme.muted; font.pixelSize: Theme.small
    }
    Label {
        anchors.right: parent.right
        text: strip.gaps.length === 0 ? "" : strip.high - strip.low < 0.05
              ? qsTr("ровно %1 мс").arg(strip.fmt(strip.low))
              : strip.fmt(strip.low) + "–" + strip.fmt(strip.high) + qsTr(" мс")
        color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12
    }
    Row {
        id: bars
        y: 24
        width: parent.width; height: parent.height - y
        spacing: 2
        Repeater {
            model: strip.gaps
            Rectangle {
                required property real modelData
                required property int index
                readonly property real span: strip.high - strip.low
                width: (bars.width - bars.spacing * (strip.gaps.length - 1)) / strip.gaps.length
                height: span < 0.05 ? bars.height * 0.5
                        : bars.height * (0.22 + 0.78 * (modelData - strip.low) / span)
                anchors.bottom: parent.bottom
                radius: 1.5
                color: Theme.accent
                opacity: 0.45 + 0.55 * (1 - index / strip.gaps.length)
                // A new plan ripples left to right instead of all bars jumping at once.
                Behavior on height {
                    SequentialAnimation {
                        PauseAnimation { duration: index * 6 }
                        NumberAnimation { duration: Theme.pageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                    }
                }
            }
        }
    }
}
