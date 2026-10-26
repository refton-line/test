import QtQuick
import QtQuick.Controls
import CClicker

SpinBox {
    id: field
    property string suffix: ""
    property bool prominent: false
    implicitWidth: prominent ? 340 : 168
    implicitHeight: prominent ? 116 : Theme.control
    leftPadding: Theme.control
    rightPadding: Theme.control
    editable: true
    font.family: Theme.mono
    font.pixelSize: prominent ? 60 : Theme.body
    Accessible.name: suffix
    hoverEnabled: true
    validator: IntValidator {
        bottom: Math.min(field.from, field.to)
        top: Math.max(field.from, field.to)
    }
    contentItem: TextInput {
        text: field.textFromValue(field.value, field.locale)
        font: field.font
        color: Theme.ink
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentInk
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        readOnly: !field.editable
        validator: field.validator
        inputMethodHints: Qt.ImhDigitsOnly
    }
    background: Rectangle {
        color: field.prominent ? Theme.clear : Theme.canvas
        radius: Theme.radius
        border.color: field.visualFocus ? Theme.focus : field.prominent ? Theme.clear : Theme.controlBorder
        border.width: field.visualFocus ? 2 : 1
        Rectangle {
            visible: field.prominent && field.visualFocus
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 88
            height: 1
            color: field.visualFocus ? Theme.focus : Theme.controlBorder
        }
    }
    up.indicator: Rectangle {
        x: parent.width - width
        width: Theme.control
        height: field.height
        radius: Theme.radius
        color: field.up.pressed ? Theme.accentSoft : field.up.hovered ? Theme.surfaceHover : Theme.clear
        Label {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: Theme.title
            color: Theme.ink
        }
    }
    down.indicator: Rectangle {
        width: Theme.control
        height: field.height
        radius: Theme.radius
        color: field.down.pressed ? Theme.accentSoft : field.down.hovered ? Theme.surfaceHover : Theme.clear
        Label {
            anchors.centerIn: parent
            text: "−"
            font.pixelSize: Theme.title
            color: Theme.ink
        }
    }
}
