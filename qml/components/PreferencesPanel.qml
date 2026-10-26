import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker

Item {
    id: panel
    property var engine
    property var keyboard
    readonly property int bindingHeight: Math.max(164, 76 + 56 * Math.ceil(Math.max(engine.startBindings.length, engine.stopBindings.length) / 2))
    Label {
        text: qsTr("Управление")
        font.pixelSize: Theme.title
        font.weight: Font.DemiBold
    }
    ActionButton {
        objectName: "resetBindings"
        anchors.right: parent.right
        text: ""
        glyph: "undo"
        Accessible.name: qsTr("Сбросить назначения")
        enabled: !panel.engine.active
        onClicked: panel.engine.resetBindings()

    }
    Row {
        y: 64
        spacing: 24
        width: parent.width
        Repeater {
            model: 2
            Rectangle {
                id: bindingCard
                required property int index
                width: (panel.width - 24) / 2
                height: panel.bindingHeight
                radius: Theme.radiusLarge
                color: Theme.surface
                border.color: Theme.hairline
                readonly property bool stopAction: index === 1
                readonly property var bindings: stopAction ? panel.engine.stopBindings : panel.engine.startBindings
                Label {
                    x: 20
                    y: 20
                    text: bindingCard.stopAction ? qsTr("Остановка") : qsTr("Запуск")
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                ActionButton {
                    objectName: bindingCard.stopAction ? "addStopBinding" : "addStartBinding"
                    x: parent.width - 60
                    y: 10
                    text: ""
                    glyph: "plus"
                    quiet: true
                    Accessible.name: qsTr("Добавить назначение")
                    enabled: !panel.engine.active && bindingCard.bindings.length < 8
                    onClicked: panel.keyboard.edit(bindingCard.index, bindingCard.bindings.length)

                }
                Grid {
                    x: 16
                    y: 76
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    Repeater {
                        model: bindingCard.bindings
                        Row {
                            required property int index
                            required property var modelData
                            spacing: 2
                            ActionButton {
                                objectName: index === 0 ? bindingCard.stopAction ? "editStopBinding" : "editStartBinding" : "binding" + bindingCard.index + "_" + index
                                width: 148
                                text: modelData.label
                                outlined: true
                                maxTextWidth: 116
                                enabled: !panel.engine.active
                                onClicked: panel.keyboard.edit(bindingCard.index, parent.index)

                            }
                            ActionButton {
                                width: 44
                                text: ""
                                glyph: "x"
                                quiet: true
                                Accessible.name: qsTr("Удалить назначение")
                                visible: bindingCard.bindings.length > 1
                                enabled: !panel.engine.active
                                onClicked: panel.engine.removeBinding(bindingCard.stopAction, parent.index)

                            }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        y: 88 + panel.bindingHeight
        width: parent.width
        Label {
            text: qsTr("Отсчёт запуска")
            font.pixelSize: 14
            Layout.fillWidth: true
        }
        NumberField {
            objectName: "delayField"
            from: 1
            to: 10
            value: panel.engine.launchDelaySec
            suffix: qsTr("Отсчёт запуска в секундах")
            enabled: !panel.engine.active
            onValueModified: panel.engine.launchDelaySec = value
        }
        Label {
            text: qsTr("с")
            font.pixelSize: 14
            color: Theme.muted
            Layout.preferredWidth: 24
        }
    }
}
