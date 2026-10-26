import QtQuick
import QtQuick.Controls
import CClicker
import "Motion.js" as Motion

// Three mode tiles share one selection frame. The frame slides to the chosen tile,
// takes on that mode's hue, and a single glint crosses it to confirm the change.
Item {
    id: picker
    objectName: "modeFrame"
    property int current: 0
    property var names: []
    property var hints: []
    readonly property var glyphs: ["cursor", "activity", "settings"]
    signal activated(int index)
    implicitHeight: 96

    property int shown: current
    property bool sliding: false
    property bool ready: false
    Component.onCompleted: ready = true
    onCurrentChanged: {
        shown = current;
        if (!ready) return;
        sliding = true;
        glint.restart();
        settle.restart();
    }
    Timer { id: settle; interval: Theme.thumbTravel + 40; onTriggered: picker.sliding = false }
    readonly property color hue: Theme.modeColor(current)
    property color frameHue: hue
    Behavior on frameHue { ColorAnimation { duration: Theme.hueShift; easing.type: Easing.OutCubic } }

    Item {
        id: selection
        objectName: "modeSelection"
        readonly property Item target: tiles.count > 0 ? tiles.itemAt(picker.shown) : null
        x: target ? target.x : 0
        width: target ? target.width : 0
        height: picker.height
        Behavior on x { enabled: picker.sliding; NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
        Bloom {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: picker.frameHue
            spread: 18
            peak: 0.16
            strength: picker.enabled ? 1 : 0.3
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLarge
            color: Theme.alpha(picker.frameHue, 0.09)
            border.width: 1.5
            border.color: Theme.alpha(picker.frameHue, 0.9)
            clip: true
            Rectangle {
                id: shine
                property real t: 1
                visible: t < 1
                width: 56; height: parent.height * 2
                y: -parent.height / 2
                x: -width + (parent.width + 2 * width) * t
                rotation: 20
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.clear }
                    GradientStop { position: 0.5; color: Theme.alpha(Theme.ink, 0.16) }
                    GradientStop { position: 1; color: Theme.clear }
                }
                NumberAnimation on t { id: glint; running: false; from: 0; to: 1; duration: Theme.glint; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve }
            }
        }
    }
    Row {
        anchors.fill: parent
        spacing: 8
        Repeater {
            id: tiles
            model: picker.names
            AbstractButton {
                id: tile
                required property int index
                required property string modelData
                readonly property bool selected: picker.current === index
                readonly property color hue: Theme.modeColor(index)
                objectName: "mode" + index
                width: (picker.width - 16) / 3; height: picker.height
                text: modelData
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                checkable: false
                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.name: text
                KeyNavigation.right: tiles.itemAt((index + 1) % 3)
                KeyNavigation.left: tiles.itemAt((index + 2) % 3)
                Keys.onSpacePressed: clicked()
                onClicked: picker.activated(index)
                scale: down ? 0.97 : 1
                Behavior on scale { SpringAnimation { spring: 7; damping: 0.42; epsilon: 0.0005 } }
                background: Rectangle {
                    radius: Theme.radiusLarge
                    color: tile.selected ? Theme.clear : tile.hovered ? Theme.surfaceHover : Theme.surface
                    border.width: tile.visualFocus ? 2 : 1
                    border.color: tile.visualFocus ? Theme.focus : tile.selected ? Theme.clear : Theme.hairline
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                contentItem: Item {
                    Icon {
                        x: 14; y: 14
                        width: 22; height: 22
                        name: picker.glyphs[tile.index]
                        foreground: tile.selected ? tile.hue : Theme.muted
                        Behavior on foreground { ColorAnimation { duration: Theme.normal } }
                    }
                    Rectangle {
                        x: parent.width - 20; y: 18
                        width: 8; height: 8; radius: 4
                        color: tile.hue
                        opacity: tile.selected ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    }
                    Label {
                        x: 14; y: 50
                        width: parent.width - 28
                        elide: Text.ElideRight
                        text: tile.modelData
                        font.pixelSize: 15; font.weight: Font.DemiBold
                        color: tile.selected ? Theme.ink : Theme.muted
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                    Label {
                        x: 14; y: 72
                        width: parent.width - 28
                        elide: Text.ElideRight
                        text: picker.hints[tile.index] || ""
                        font.pixelSize: 11
                        color: Theme.faint
                    }
                }
            }
        }
    }
}
