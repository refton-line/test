import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker

// Segmented choice: one row of 44px targets inside a quiet canvas frame.
Rectangle {
    id: frame
    property var model: []
    property int current: -1
    property string prefix: ""
    signal activated(int index)
    implicitWidth: 300
    implicitHeight: 50
    radius: Theme.radius
    color: Theme.canvas
    border.color: Theme.hairline
    RowLayout {
        anchors.fill: parent; anchors.margins: 3; spacing: 3
        Repeater {
            id: choices
            model: frame.model
            ActionButton {
                required property int index
                required property var modelData
                objectName: frame.prefix + index
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                segmented: true
                text: modelData
                checked: frame.current === index
                KeyNavigation.right: choices.itemAt((index + 1) % choices.count)
                KeyNavigation.left: choices.itemAt((index + choices.count - 1) % choices.count)
                onClicked: frame.activated(index)
            }
        }
    }
}
