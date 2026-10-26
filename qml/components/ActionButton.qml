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
    property bool centered: !navigation
    property int textSize: Theme.small
    property int maxTextWidth: 1000
    property string glyph: ""
    // Language switch: only the words fade and settle, not the control.
    property real contentOpacity: 1
    property real contentShift: 0

    readonly property bool lightFace: primary && enabled
    implicitHeight: Theme.control
    implicitWidth: Math.max(Theme.control, contentRow.implicitWidth + (navigation ? 28 : 32))
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
        color: control.lightFace ? Theme.accent
             : control.checked && !control.fillChecked ? Theme.clear
             : control.down ? Theme.accentSoft
             : control.checked ? Theme.surfaceRaised
             : control.hovered ? Theme.surfaceHover
             : control.quiet || control.segmented ? Theme.clear : Theme.surface
        // Primary actions are lit: an ember gradient face and a bloom that grows on hover.
        gradient: control.lightFace ? emberFace : undefined
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.focus
                    : control.lightFace || control.quiet || control.segmented ? Theme.clear
                    : control.outlined ? Theme.controlBorder : Theme.hairline
        Behavior on color { enabled: !control.primary; ColorAnimation { duration: Theme.fast } }
        Gradient {
            id: emberFace
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: control.down ? Theme.primaryHint : control.hovered ? Theme.accentHover : Theme.accent }
            GradientStop { position: 1; color: control.down ? Theme.primaryHint : Theme.accentEnd }
        }
        Bloom {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            color: Theme.brand
            spread: 14
            peak: 0.2
            strength: control.lightFace ? (control.hovered || control.visualFocus ? 1 : 0.45) : 0
            Behavior on strength { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            visible: control.lightFace
            x: parent.radius; width: parent.width - 2 * parent.radius
            height: 1
            color: Theme.alpha(Theme.accentInk, 0.28)
        }
    }
    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: 24
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: control.contentShift
            x: control.centered ? (parent.width - width) / 2 : 10
            spacing: control.navigation ? 8 : 10
            Icon {
                visible: control.glyph !== ""
                name: control.glyph
                foreground: control.lightFace ? Theme.accentInk
                          : control.navigation && !control.checked ? Theme.muted : Theme.ink
                width: control.navigation ? 18 : 20; height: width
                anchors.verticalCenter: parent.verticalCenter
                Behavior on foreground { ColorAnimation { duration: Theme.normal } }
            }
            Label {
                width: Math.min(implicitWidth, control.maxTextWidth)
                elide: Text.ElideRight
                text: control.text
                opacity: control.contentOpacity
                color: control.lightFace ? Theme.accentInk : control.navigation && !control.checked ? Theme.muted : Theme.ink
                font.pixelSize: control.textSize
                font.weight: control.checked || control.primary ? Font.DemiBold : Font.Medium
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
