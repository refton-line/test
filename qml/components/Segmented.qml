import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker
import "Motion.js" as Motion

// Segmented choice: one row of 44px targets inside a quiet canvas frame. A single
// thumb slides between segments rather than each segment filling on its own.
Rectangle {
    id: frame
    property var model: []
    property int current: -1
    property string prefix: ""
    property var names: []
    signal activated(int index)
    implicitWidth: 300
    implicitHeight: 50
    radius: Theme.radius
    color: Theme.canvas
    border.color: Theme.hairline

    // The thumb follows `shown`, assigned after `sliding` so the slide decision is
    // made before the position changes. Resizes move it without animation.
    property int shown: -1
    property int last: -1
    property bool sliding: false
    Component.onCompleted: { shown = current; last = current; }
    onCurrentChanged: {
        sliding = last >= 0 && current >= 0;
        last = current;
        if (current >= 0) shown = current;
        settle.restart();
    }
    Timer { id: settle; interval: Theme.thumbTravel + 40; onTriggered: frame.sliding = false }
    Rectangle {
        id: thumb
        objectName: frame.objectName + "Thumb"
        readonly property Item target: choices.count > 0 && frame.shown >= 0 ? choices.itemAt(frame.shown) : null
        x: target ? row.x + target.x : 0
        y: row.y
        width: target ? target.width : 0
        height: row.height
        radius: Theme.radiusSmall
        color: Theme.surfaceRaised
        opacity: frame.current >= 0 && target ? 1 : 0
        Behavior on x { enabled: frame.sliding; NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
        Behavior on width { enabled: frame.sliding; NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
    RowLayout {
        id: row
        anchors.fill: parent; anchors.margins: 3; spacing: 3
        Repeater {
            id: choices
            model: frame.model
            ActionButton {
                required property int index
                required property var modelData
                objectName: frame.names.length > index ? frame.names[index] : frame.prefix + index
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                segmented: true
                fillChecked: false
                text: modelData
                checked: frame.current === index
                KeyNavigation.right: choices.itemAt((index + 1) % choices.count)
                KeyNavigation.left: choices.itemAt((index + choices.count - 1) % choices.count)
                onClicked: frame.activated(index)
            }
        }
    }
}
