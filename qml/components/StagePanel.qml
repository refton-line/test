import QtQuick
import QtQuick.Shapes
import CClicker
import "Motion.js" as Motion

// The stage: the ring that starts and shows the session, the numbers that matter
// while it runs, and the last few log lines. Nothing here is a setting.
Item {
    id: stage
    property var engine
    property real reveal: 1
    property bool demo: false
    readonly property color hue: Theme.modeColor(engine.clickMode)
    readonly property bool live: engine.active || demo
    function fmt(v, digits) { return v.toLocaleString(Qt.locale(i18n.locale), 'f', digits); }

    // Ambient light behind the ring; brighter while sending.
    Shape {
        id: ambient
        readonly property real r: 420
        readonly property real cx: stage.width / 2
        readonly property real cy: hero.y + hero.height / 2
        x: 0; y: 0; width: stage.width; height: stage.height
        opacity: (stage.live ? 1 : 0.55) * Motion.seg(stage.reveal, 0.5, 1)
        Behavior on opacity { NumberAnimation { duration: Theme.glowIn; easing.type: Easing.OutCubic } }
        property color tint: stage.hue
        Behavior on tint { ColorAnimation { duration: Theme.hueShift } }
        ShapePath {
            strokeColor: Theme.clear
            fillGradient: RadialGradient {
                centerX: ambient.cx; centerY: ambient.cy; centerRadius: ambient.r
                focalX: ambient.cx; focalY: ambient.cy; focalRadius: 0
                GradientStop { position: 0; color: Theme.alpha(ambient.tint, 0.09) }
                GradientStop { position: 0.45; color: Theme.alpha(ambient.tint, 0.03) }
                GradientStop { position: 1; color: Theme.alpha(ambient.tint, 0) }
            }
            PathAngleArc { centerX: ambient.cx; centerY: ambient.cy; radiusX: ambient.r; radiusY: ambient.r * 0.8; startAngle: 0; sweepAngle: 360 }
        }
    }

    HeroRing {
        id: hero
        engine: stage.engine
        demo: stage.demo
        reveal: Motion.decelerate(Motion.seg(stage.reveal, 0.15, 1))
        x: (stage.width - width) / 2; y: 4
        scale: 0.92 + 0.08 * Motion.decelerate(Motion.seg(stage.reveal, 0, 0.8))
    }

    // Live numbers.
    property real clicksShown: engine.clicks
    Behavior on clicksShown { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Row {
        id: tiles
        y: 368; width: stage.width
        spacing: 10
        opacity: Motion.seg(stage.reveal, 0.4, 1)
        transform: Translate { y: 12 * (1 - Motion.decelerate(Motion.seg(stage.reveal, 0.4, 1))) }
        Repeater {
            model: [
                { label: qsTr("Принято пар"), value: Math.round(stage.clicksShown).toLocaleString(Qt.locale(i18n.locale), 'f', 0), lead: true },
                { label: qsTr("Интервал"), value: stage.engine.meanGapMs < 0 ? "—" : stage.fmt(stage.engine.meanGapMs, 2) + qsTr(" мс") },
                { label: qsTr("Отклонение"), value: stage.engine.maxJitterMs < 0 ? "—" : stage.fmt(stage.engine.maxJitterMs, 2) + qsTr(" мс") },
                { label: qsTr("Опоздание"), value: stage.fmt(stage.engine.maxLateMs, 2) + qsTr(" мс") },
                { label: qsTr("Пропуски"), value: stage.fmt(stage.engine.skipped, 0) }
            ]
            Rectangle {
                required property var modelData
                required property int index
                width: (tiles.width - 4 * tiles.spacing) / 5; height: 76
                radius: Theme.radius
                color: Theme.surface
                border.color: modelData.lead && stage.engine.active ? Theme.alpha(stage.hue, 0.55) : Theme.hairline
                Behavior on border.color { ColorAnimation { duration: Theme.normal } }
                Shadow { z: -1; anchors.fill: parent; radius: parent.radius; peak: 0.035; spread: 12; lift: 2 }
                Label {
                    x: 14; y: 14
                    width: parent.width - 28; elide: Text.ElideRight
                    text: modelData.label
                    font.pixelSize: 12
                    color: Theme.muted
                }
                Label {
                    x: 14; y: 36
                    width: parent.width - 28; height: 28
                    text: modelData.value
                    font.family: Theme.mono; font.pixelSize: modelData.lead ? 22 : 16
                    fontSizeMode: Text.Fit; minimumPixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.ink
                }
            }
        }
    }

    // Recent log lines; the newest slides in from above.
    Item {
        id: recent
        y: 470; width: stage.width; height: 140
        opacity: Motion.seg(stage.reveal, 0.55, 1)
        Rectangle {
            width: recentChip.implicitWidth + 12; height: 20
            radius: 5
            color: Theme.clear
            border.color: Theme.controlBorder
            Label {
                id: recentChip
                anchors.centerIn: parent
                text: "/" + qsTr("Последние события").toLowerCase()
                font.family: Theme.mono; font.pixelSize: 11
            }
        }
        Label {
            y: 28
            visible: stage.engine.entries.length === 0
            text: qsTr("Событий пока нет")
            font.pixelSize: 13; color: Theme.muted
        }
        Column {
            y: 26; width: parent.width
            Repeater {
                model: 3
                Item {
                    id: line
                    required property int index
                    readonly property string entry: stage.engine.entries.length > index ? stage.engine.entries[index] : ""
                    width: parent.width; height: 34
                    visible: entry !== ""
                    property real arrive: 1
                    onEntryChanged: if (index === 0 && entry !== "") enterLine.restart()
                    NumberAnimation { id: enterLine; target: line; property: "arrive"; from: 0; to: 1; duration: Theme.pageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                    Rectangle { width: parent.width; height: 1; color: Theme.hairline }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -8 * (1 - line.arrive)
                        width: parent.width; elide: Text.ElideRight
                        text: line.entry
                        font.family: Theme.mono; font.pixelSize: 12
                        color: line.index === 0 ? Theme.ink : Theme.muted
                        opacity: (1 - line.index * 0.28) * line.arrive
                    }
                }
            }
        }
    }
}
