import QtQuick
import QtQuick.Controls
import CClicker
import "Motion.js" as Motion

// Two-handle CPS range. Values snap to whole clicks per second.
RangeSlider {
    id: control
    property var engine
    property color hue: Theme.accent
    Behavior on hue { ColorAnimation { duration: Theme.hueShift } }
    from: 1; to: 30; stepSize: 1
    snapMode: RangeSlider.SnapAlways
    implicitHeight: Theme.control
    hoverEnabled: true
    readonly property bool dragging: first.pressed || second.pressed
    // Animated copies of the handle positions: value changes (presets) glide,
    // drags and layout changes stay direct because geometry is applied on top.
    property real low: first.visualPosition
    property real high: second.visualPosition
    Behavior on low { enabled: !control.dragging; NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
    Behavior on high { enabled: !control.dragging; NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
    first.value: engine.cpsMin
    second.value: engine.cpsMax
    first.onMoved: engine.setCpsRange(Math.round(first.value), engine.cpsMax)
    second.onMoved: engine.setCpsRange(engine.cpsMin, Math.round(second.value))
    Accessible.name: qsTr("Диапазон кликов в секунду")
    opacity: enabled ? 1 : 0.5

    background: Item {
        x: control.leftPadding; y: control.topPadding
        width: control.availableWidth; height: control.availableHeight
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Theme.surfaceHover
            Rectangle {
                x: control.low * parent.width
                width: (control.high - control.low) * parent.width
                height: parent.height; radius: 3
                color: control.hue
            }
        }
        Repeater {
            model: [1, 10, 20, 30]
            Rectangle {
                required property int modelData
                x: (modelData - control.from) / (control.to - control.from) * parent.width - 0.5
                y: parent.height / 2 + 9
                width: 1; height: 5
                color: Theme.hairline
            }
        }
    }
    component Knob: Rectangle {
        required property var node
        required property real position
        width: 22; height: 22; radius: 11
        y: control.topPadding + (control.availableHeight - height) / 2
        x: control.leftPadding + position * (control.availableWidth - width)
        color: node.pressed ? Theme.accentInk : Theme.ink
        scale: node.pressed ? 1.2 : node.hovered ? 1.1 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; epsilon: 0.0005 } }
        border.width: activeFocus ? 3 : 0
        border.color: Theme.focus
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    first.handle: Knob { node: control.first; position: control.low }
    second.handle: Knob { node: control.second; position: control.high }
}
