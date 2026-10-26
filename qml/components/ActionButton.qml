import QtQuick
import QtQuick.Controls
import CClicker

Button {
    id: control
    property bool primary: false
    property bool quiet: false
    property bool navigation: false
    property bool segmented: false
    property bool outlined: false
    // Off where a shared sliding thumb or pill draws the selection instead.
    property bool fillChecked: true
    property int textSize: Theme.small
    property int maxTextWidth: 1000
    property string glyph: ""

    readonly property bool lightFace: primary && enabled
    implicitHeight: Theme.control
    implicitWidth: Math.max(Theme.control, contentRow.implicitWidth + 32)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.checkable: checkable || navigation || segmented
    Accessible.checked: checked
    opacity: enabled ? 1 : 0.5
    // Physical press: a spring dips on press and overshoots slightly on release.
    scale: down ? 0.965 : 1
    Behavior on scale { SpringAnimation { spring: 7; damping: 0.42; epsilon: 0.0005 } }
    background: Rectangle {
        radius: control.segmented ? Theme.radiusSmall : Theme.radius
        color: control.lightFace ? (control.down ? Theme.primaryHint : control.hovered ? Theme.accentHover : Theme.accent)
             : control.checked && !control.fillChecked ? Theme.clear
             : control.down ? Theme.accentSoft
             : control.checked ? Theme.surfaceRaised
             : control.hovered ? Theme.surfaceHover
             : control.quiet || control.segmented ? Theme.clear : Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.focus
                    : control.lightFace || control.quiet || control.segmented ? Theme.clear
                    : control.outlined ? Theme.controlBorder : Theme.hairline
        Behavior on color { enabled: !control.primary; ColorAnimation { duration: Theme.fast } }
    }
    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: 24
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            x: control.navigation ? 10 : (parent.width - width) / 2
            spacing: 10
            Icon {
                visible: control.glyph !== ""
                name: control.glyph
                foreground: control.lightFace ? Theme.accentInk : Theme.ink
                width: 20; height: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                width: Math.min(implicitWidth, control.maxTextWidth)
                elide: Text.ElideRight
                text: control.text
                color: control.lightFace ? Theme.accentInk : control.navigation && !control.checked ? Theme.muted : Theme.ink
                font.pixelSize: control.textSize
                font.weight: control.checked || control.primary ? Font.DemiBold : Font.Medium
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                anchors.verticalCenter: parent.verticalCenter
            }

        }
    }
}
