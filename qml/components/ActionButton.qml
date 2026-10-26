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
    scale: down ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: control.segmented ? Theme.radiusSmall : Theme.radius
        color: control.lightFace ? (control.down ? Theme.primaryHint : control.hovered ? Theme.accentHover : Theme.accent)
             : control.down ? Theme.accentSoft
             : control.checked ? Theme.surfaceRaised
             : control.hovered ? Theme.surfaceHover
             : control.quiet || control.segmented ? Theme.clear : Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.focus
                    : control.lightFace || control.quiet || control.segmented ? Theme.clear
                    : control.outlined ? Theme.controlBorder : Theme.hairline
        Behavior on color { enabled: !control.primary; ColorAnimation { duration: Theme.fast } }
        Rectangle {
            visible: control.navigation && height > 0
            width: 3; height: control.checked ? 18 : 0; radius: 1
            Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            x: 0; y: (parent.height - height) / 2
            color: control.lightFace ? Theme.accentInk : Theme.brand
        }
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
                anchors.verticalCenter: parent.verticalCenter
            }

        }
    }
}
