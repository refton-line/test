import QtQuick
import QtQuick.Controls
import CClicker

// Two-handle CPS range. Values snap to whole clicks per second.
RangeSlider {
    id: control
    property var engine
    from: 1; to: 30; stepSize: 1
    snapMode: RangeSlider.SnapAlways
    implicitHeight: Theme.control
    hoverEnabled: true
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
                x: control.first.visualPosition * parent.width
                width: (control.second.visualPosition - control.first.visualPosition) * parent.width
                height: parent.height; radius: 3
                color: Theme.accent
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
        width: 22; height: 22; radius: 11
        y: control.topPadding + (control.availableHeight - height) / 2
        x: control.leftPadding + node.visualPosition * (control.availableWidth - width)
        color: node.pressed ? Theme.accentInk : Theme.ink
        border.width: activeFocus ? 3 : 0
        border.color: Theme.focus
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    first.handle: Knob { node: control.first }
    second.handle: Knob { node: control.second }
}
