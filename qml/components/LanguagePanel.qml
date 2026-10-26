import QtQuick
import QtQuick.Controls
import CClicker

Item {
    id: panel
    property var language
    signal pick(string code)

    Label {
        text: qsTr("Язык")
        font.pixelSize: Theme.title
        font.weight: Font.DemiBold
    }
    Label {
        y: 52; width: parent.width
        text: qsTr("Язык интерфейса. Меняется сразу и запоминается.")
        color: Theme.muted
        font.pixelSize: Theme.small
        elide: Text.ElideRight
    }
    Row {
        y: 100
        spacing: 24
        Repeater {
            id: cards
            model: panel.language.languages
            Button {
                id: card
                required property var modelData
                required property int index
                readonly property bool current: panel.language.language === modelData.code
                objectName: "language_" + modelData.code
                width: (panel.width - 24) / 2
                height: 196
                padding: 0
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: current
                Accessible.name: modelData.name
                KeyNavigation.right: cards.itemAt((index + 1) % cards.count)
                KeyNavigation.left: cards.itemAt((index + cards.count - 1) % cards.count)
                onClicked: if (!current) panel.pick(modelData.code)
                scale: down ? 0.99 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                background: Rectangle {
                    radius: Theme.radiusLarge
                    color: card.current ? Theme.surfaceRaised : card.hovered ? Theme.surfaceHover : Theme.surface
                    border.width: card.visualFocus ? 2 : 1
                    border.color: card.visualFocus ? Theme.focus : card.current ? Theme.accent : Theme.hairline
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                    Behavior on border.color { ColorAnimation { duration: Theme.normal } }
                    Rectangle {
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: 3; radius: 1
                        height: card.current ? 48 : 0
                        color: Theme.brand
                        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    }
                }
                contentItem: Item {
                    Label {
                        x: 28; y: 20
                        text: card.modelData.code.toUpperCase()
                        font.family: Theme.mono
                        font.pixelSize: 44
                        color: card.current ? Theme.ink : Theme.muted
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                    Rectangle {
                        objectName: "languageCheck_" + card.modelData.code
                        x: parent.width - width - 22; y: 22
                        width: 32; height: 32; radius: 16
                        color: Theme.accent
                        opacity: card.current ? 1 : 0
                        scale: card.current ? 1 : 0.5
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
                        Icon { anchors.centerIn: parent; width: 18; height: 18; name: "check"; foreground: Theme.accentInk }
                    }
                    Label {
                        x: 28; y: 106
                        text: card.modelData.name
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    Label {
                        x: 28; y: 144
                        width: parent.width - 56
                        elide: Text.ElideRight
                        text: card.modelData.sample
                        color: Theme.muted
                        font.pixelSize: Theme.small
                    }
                }
            }
        }
    }
    Label {
        y: 324; width: parent.width
        wrapMode: Text.WordWrap
        text: qsTr("По умолчанию — английский. Профили и настройки от языка не зависят.")
        color: Theme.muted
        font.pixelSize: Theme.small
    }
}
