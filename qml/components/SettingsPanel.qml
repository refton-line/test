import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker

Item {
    id: panel
    property var engine

    Label {
        text: "Кликер"
        font.pixelSize: Theme.title
        font.weight: Font.DemiBold
    }
    Label {
        y: 52
        text: "Интервал, мс"
        color: Theme.muted
        font.pixelSize: Theme.small
    }
    NumberField {
        objectName: "intervalField"
        x: 8; y: 80
        width: Math.min(328, parent.width - 208); height: 100
        prominent: true
        from: 5; to: 10000; stepSize: 5
        value: panel.engine.intervalMs
        suffix: "Интервал в миллисекундах"
        enabled: !panel.engine.active
        onValueModified: panel.engine.intervalMs = value
    }
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 104
        width: 156
        spacing: 8
        Label { text: "Целевая частота"; color: Theme.muted; font.pixelSize: Theme.small }
        Label {
            text: (1000 / panel.engine.intervalMs).toLocaleString(Qt.locale("ru_RU"), 'f', 1) + " / с"
            font.family: Theme.mono
            font.pixelSize: 24
        }
    }
    Rectangle {
        objectName: "presetsFrame"
        y: 200; width: parent.width; height: 50
        radius: Theme.radius
        color: Theme.canvas
        border.color: Theme.hairline
        RowLayout {
            anchors.fill: parent; anchors.margins: 3; spacing: 4
            Repeater {
                id: presets
                model: [1, 10, 50, 200]
                ActionButton {
                    required property int index
                    required property int modelData
                    objectName: "preset" + modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    segmented: true
                    text: modelData + " / с"
                    checked: Math.abs(1000 / panel.engine.intervalMs - modelData) < 0.01

                    enabled: !panel.engine.active
                    KeyNavigation.right: presets.itemAt((index + 1) % 4)
                    KeyNavigation.left: presets.itemAt((index + 3) % 4)
                    onClicked: panel.engine.intervalMs = Math.round(1000 / modelData)
                }
            }
        }
    }
    Rectangle {
        y: 268
        width: parent.width
        height: 1
        color: Theme.hairline
    }
    RowLayout {
        y: 292
        width: parent.width
        spacing: 6
        Label {
            text: "Кнопка мыши"
            Layout.fillWidth: true
            font.pixelSize: 14
        }
        Rectangle {
            objectName: "mouseFrame"
            implicitWidth: 288; implicitHeight: 50
            radius: Theme.radius
            color: Theme.canvas
            border.color: Theme.hairline
            Row {
                anchors.fill: parent; anchors.margins: 3; spacing: 3
                Repeater {
                    id: mouseChoices
                    model: ["Левая", "Правая", "Средняя"]
                    ActionButton {
                        required property int index
                        required property string modelData
                        objectName: "mouse" + index
                        text: modelData; width: 92; height: 44
                        segmented: true
                        checked: panel.engine.mouseButton === index
                        enabled: !panel.engine.active
                        KeyNavigation.right: mouseChoices.itemAt((index + 1) % 3)
                        KeyNavigation.left: mouseChoices.itemAt((index + 2) % 3)
                        onClicked: panel.engine.mouseButton = index

                    }
                }
            }
        }
    }
    RowLayout {
        y: 356
        width: parent.width
        spacing: 8
        Label {
            text: "Удержание"
            Layout.fillWidth: true
            font.pixelSize: 14
        }
        NumberField {
            objectName: "holdField"
            implicitWidth: 148
            from: 0
            to: Math.min(100, panel.engine.intervalMs - 1)
            value: panel.engine.holdMs
            suffix: "Удержание кнопки в миллисекундах"
            enabled: !panel.engine.active
            onValueModified: panel.engine.holdMs = value
        }
        Label {
            text: "мс"
            font.pixelSize: 14
            color: Theme.muted
        }
    }
    RowLayout {
        y: 420
        width: parent.width
        spacing: 8
        Label {
            text: "Остановка"
            Layout.fillWidth: true
            font.pixelSize: 14
        }
        ActionButton {
            objectName: "limitsButton"
            text: panel.engine.durationSec > 0 || panel.engine.countLimit > 0 ? "Заданы лимиты" : "Вручную"
            glyph: "settings"
            enabled: !panel.engine.active
            onClicked: limits.open()

        }
    }
    ActionButton {
        y: 492
        objectName: "startButton"
        width: parent.width
        height: 56
        primary: true

        glyph: panel.engine.active ? "square" : "play"
        text: panel.engine.active ? "Остановить" : "Запустить"
        enabled: panel.engine.available || panel.engine.active
        onClicked: panel.engine.toggle()
    }

    Popup {
        id: limits
        objectName: "limitsPopup"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        height: 332
        modal: true
        focus: true
        padding: 24
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit } }
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLarge
            border.color: Theme.hairline
        }
        Column {
            width: parent.width
            spacing: 24
            Label {
                text: "Условия остановки"
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            RowLayout {
                width: parent.width
                Label {
                    text: "По времени, с"
                    Layout.fillWidth: true
                    font.pixelSize: 14
                }
                NumberField {
                    objectName: "durationField"
                    from: 0
                    to: 3600
                    value: panel.engine.durationSec
                    suffix: "Лимит секунд, ноль без лимита"
                    onValueModified: panel.engine.durationSec = value
                }
            }
            RowLayout {
                width: parent.width
                Label {
                    text: "По числу кликов"
                    Layout.fillWidth: true
                    font.pixelSize: 14
                }
                NumberField {
                    objectName: "countField"
                    implicitWidth: 216
                    from: 0
                    to: 1000000000
                    value: panel.engine.countLimit
                    suffix: "Лимит кликов, ноль без лимита"
                    onValueModified: panel.engine.countLimit = value
                }
            }
            Label {
                text: "0 — без лимита. Сработает первое из условий."
                font.pixelSize: 12
                color: Theme.muted
            }
            ActionButton {
                anchors.right: parent.right
                text: "Готово"
                primary: true
                onClicked: limits.close()
            }
        }
    }
}
