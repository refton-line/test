import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker

Item {
    id: panel
    property var engine

    readonly property bool idle: !engine.active
    component ModeBody: Item {
        id: body
        property int mode
        readonly property bool current: panel.engine.clickMode === mode
        y: 88; width: parent.width; height: 284
        enabled: current
        opacity: current ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            x: body.current ? 0 : (body.mode < panel.engine.clickMode ? -Theme.pageTravel : Theme.pageTravel)
            Behavior on x { NumberAnimation { duration: Theme.pageEnter; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: body.current ? Theme.pageEnter : Theme.pageExit; easing.type: Easing.OutCubic } }
    }
    function rate(v) { return v.toLocaleString(Qt.locale(i18n.locale), 'f', 1) }

    Label {
        text: qsTr("Кликер")
        font.pixelSize: Theme.title
        font.weight: Font.DemiBold
    }
    Segmented {
        objectName: "modeFrame"
        anchors.right: parent.right
        y: -9; width: 336
        prefix: "mode"
        model: [qsTr("Легит"), qsTr("Блатант"), qsTr("Свой")]
        current: panel.engine.clickMode
        enabled: panel.idle
        onActivated: index => panel.engine.clickMode = index
    }
    Label {
        objectName: "modeDescription"
        y: 52; width: parent.width
        elide: Text.ElideRight
        color: Theme.muted
        font.pixelSize: Theme.small
        text: [qsTr("Эмуляция мыши через SendInput: живой ритм, разброс и паузы, как у руки."),
               qsTr("Искусственные клики сообщениями окну под курсором: точная сетка, до 1000 / с."),
               qsTr("Свой рецепт: интервал, разброс, волна и способ доставки.")][panel.engine.clickMode] || ""
    }

    // ---- Legit: CPS range with a humanised rhythm ----
    ModeBody {
        objectName: "legitBody"
        mode: 0
        Label {
            x: 8; y: 0; height: 100
            verticalAlignment: Text.AlignVCenter
            text: panel.engine.cpsMin === panel.engine.cpsMax ? String(panel.engine.cpsMin)
                  : panel.engine.cpsMin + "–" + panel.engine.cpsMax
            font.family: Theme.mono; font.pixelSize: 60
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 20
            y: 16; width: 156; spacing: 8
            Label { text: qsTr("Кликов в секунду"); color: Theme.muted; font.pixelSize: Theme.small }
            Label { text: "≈ " + panel.rate(panel.engine.expectedCps) + qsTr(" / с"); font.family: Theme.mono; font.pixelSize: 24 }
        }
        CpsRange {
            objectName: "cpsRange"
            y: 104; width: parent.width
            engine: panel.engine
            enabled: panel.idle
        }
        Segmented {
            objectName: "legitPresets"
            y: 160; width: parent.width
            prefix: "legitPreset"
            readonly property var ranges: [[6, 9], [9, 13], [13, 17], [17, 22]]
            model: [qsTr("Спокойно 6–9"), qsTr("Ровно 9–13"), qsTr("Быстро 13–17"), qsTr("Пик 17–22")]
            current: ranges.findIndex(r => r[0] === panel.engine.cpsMin && r[1] === panel.engine.cpsMax)
            enabled: panel.idle
            onActivated: index => panel.engine.setCpsRange(ranges[index][0], ranges[index][1])
        }
        RhythmStrip {
            objectName: "legitRhythm"
            y: 230; width: parent.width; height: 54
            gaps: panel.engine.rhythmPreview
        }
    }

    // ---- Blatant: exact interval grid ----
    ModeBody {
        objectName: "blatantBody"
        mode: 1
        NumberField {
            objectName: "intervalField"
            x: 8; y: 0
            width: Math.min(328, parent.width - 208); height: 100
            prominent: true
            from: panel.engine.minIntervalMs; to: 10000; stepSize: 1
            value: panel.engine.intervalMs
            suffix: qsTr("Интервал в миллисекундах")
            enabled: panel.idle
            onValueModified: panel.engine.intervalMs = value
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 20
            y: 16; width: 156; spacing: 8
            Label { text: qsTr("Интервал, мс → частота"); color: Theme.muted; font.pixelSize: Theme.small }
            Label { text: panel.rate(1000 / panel.engine.intervalMs) + qsTr(" / с"); font.family: Theme.mono; font.pixelSize: 24 }
        }
        Rectangle {
            objectName: "presetsFrame"
            y: 108; width: parent.width; height: 50
            radius: Theme.radius
            color: Theme.canvas
            border.color: Theme.hairline
            RowLayout {
                anchors.fill: parent; anchors.margins: 3; spacing: 4
                Repeater {
                    id: presets
                    model: [10, 50, 100, 200, 500]
                    ActionButton {
                        required property int index
                        required property int modelData
                        objectName: "preset" + modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                        segmented: true
                        text: modelData + qsTr(" / с")
                        checked: Math.abs(1000 / panel.engine.intervalMs - modelData) < 0.01
                        enabled: panel.idle
                        KeyNavigation.right: presets.itemAt((index + 1) % presets.count)
                        KeyNavigation.left: presets.itemAt((index + presets.count - 1) % presets.count)
                        onClicked: panel.engine.intervalMs = Math.round(1000 / modelData)
                    }
                }
            }
        }
        RowLayout {
            y: 172; width: parent.width; spacing: 8
            Label { text: qsTr("Удержание"); Layout.fillWidth: true; font.pixelSize: 14 }
            NumberField {
                objectName: "holdField"
                implicitWidth: 148
                from: 0
                to: Math.max(0, Math.min(100, panel.engine.intervalMs - 1))
                value: panel.engine.holdMs
                suffix: qsTr("Удержание кнопки в миллисекундах")
                enabled: panel.idle
                onValueModified: panel.engine.holdMs = value
            }
            Label { text: qsTr("мс"); font.pixelSize: 14; color: Theme.muted }
        }
        RhythmStrip {
            y: 230; width: parent.width; height: 54
            gaps: panel.engine.rhythmPreview
        }
    }

    // ---- Custom: every knob exposed ----
    ModeBody {
        objectName: "customBody"
        mode: 2
        component Row2: RowLayout { width: parent.width; spacing: 8 }
        Row2 {
            y: 0
            Label { text: qsTr("Интервал"); Layout.fillWidth: true; font.pixelSize: 14 }
            Label { text: "≈ " + panel.rate(1000 / panel.engine.intervalMs) + qsTr(" / с"); font.family: Theme.mono; font.pixelSize: 13; color: Theme.muted }
            NumberField {
                objectName: "customIntervalField"
                from: panel.engine.minIntervalMs; to: 10000; stepSize: 5
                value: panel.engine.intervalMs
                suffix: qsTr("Интервал в миллисекундах")
                enabled: panel.idle
                onValueModified: panel.engine.intervalMs = value
            }
            Label { text: qsTr("мс"); font.pixelSize: 14; color: Theme.muted; Layout.preferredWidth: 22 }
        }
        Row2 {
            y: 56
            Label { text: qsTr("Разброс"); Layout.fillWidth: true; font.pixelSize: 14 }
            NumberField {
                objectName: "jitterField"
                from: 0; to: 50
                value: panel.engine.jitterPct
                suffix: qsTr("Случайный разброс интервала и удержания, процентов")
                enabled: panel.idle
                onValueModified: panel.engine.jitterPct = value
            }
            Label { text: "± %"; font.pixelSize: 14; color: Theme.muted; Layout.preferredWidth: 22 }
        }
        Row2 {
            y: 112
            Label { text: qsTr("Удержание"); Layout.fillWidth: true; font.pixelSize: 14 }
            NumberField {
                objectName: "customHoldField"
                from: 0
                to: Math.max(0, Math.min(100, panel.engine.intervalMs - 1))
                value: panel.engine.holdMs
                suffix: qsTr("Удержание кнопки в миллисекундах")
                enabled: panel.idle
                onValueModified: panel.engine.holdMs = value
            }
            Label { text: qsTr("мс"); font.pixelSize: 14; color: Theme.muted; Layout.preferredWidth: 22 }
        }
        Row2 {
            y: 168
            Label { text: qsTr("Доставка"); Layout.fillWidth: true; font.pixelSize: 14 }
            Segmented {
                objectName: "deliveryFrame"
                Layout.preferredWidth: 288
                prefix: "delivery"
                model: [qsTr("Эмуляция"), qsTr("Сообщения")]
                current: panel.engine.delivery
                enabled: panel.idle
                onActivated: index => panel.engine.delivery = index
            }
        }
        Row2 {
            y: 230
            Label { text: qsTr("Темп"); Layout.fillWidth: true; font.pixelSize: 14 }
            Segmented {
                objectName: "driftFrame"
                Layout.preferredWidth: 288
                prefix: "drift"
                model: [qsTr("Ровный"), qsTr("Волна")]
                current: panel.engine.drift ? 1 : 0
                enabled: panel.idle
                onActivated: index => panel.engine.drift = index === 1
            }
        }
    }

    Rectangle {
        y: 384
        width: parent.width
        height: 1
        color: Theme.hairline
    }
    RowLayout {
        y: 400
        width: parent.width
        spacing: 12
        Label {
            text: qsTr("Кнопка")
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
                    model: [qsTr("Левая"), qsTr("Правая"), qsTr("Средняя")]
                    ActionButton {
                        required property int index
                        required property string modelData
                        objectName: "mouse" + index
                        text: modelData; width: 92; height: 44
                        segmented: true
                        checked: panel.engine.mouseButton === index
                        enabled: panel.idle
                        KeyNavigation.right: mouseChoices.itemAt((index + 1) % 3)
                        KeyNavigation.left: mouseChoices.itemAt((index + 2) % 3)
                        onClicked: panel.engine.mouseButton = index
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
        ActionButton {
            objectName: "limitsButton"
            text: panel.engine.durationSec > 0 || panel.engine.countLimit > 0 ? qsTr("Заданы лимиты") : qsTr("Остановка вручную")
            glyph: "settings"
            enabled: panel.idle
            onClicked: limits.open()
        }
    }
    ActionButton {
        y: 476
        objectName: "startButton"
        width: parent.width
        height: 56
        primary: true
        glyph: panel.engine.active ? "square" : "play"
        text: panel.engine.active ? qsTr("Остановить") : qsTr("Запустить")
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
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit; easing.type: Easing.InCubic } NumberAnimation { property: "scale"; to: 0.98; duration: Theme.dialogExit; easing.type: Easing.InCubic } } }
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLarge
            border.color: Theme.hairline
        }
        Column {
            width: parent.width
            spacing: 24
            Label {
                text: qsTr("Условия остановки")
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            RowLayout {
                width: parent.width
                Label {
                    text: qsTr("По времени, с")
                    Layout.fillWidth: true
                    font.pixelSize: 14
                }
                NumberField {
                    objectName: "durationField"
                    from: 0
                    to: 3600
                    value: panel.engine.durationSec
                    suffix: qsTr("Лимит секунд, ноль без лимита")
                    onValueModified: panel.engine.durationSec = value
                }
            }
            RowLayout {
                width: parent.width
                Label {
                    text: qsTr("По числу кликов")
                    Layout.fillWidth: true
                    font.pixelSize: 14
                }
                NumberField {
                    objectName: "countField"
                    implicitWidth: 216
                    from: 0
                    to: 1000000000
                    value: panel.engine.countLimit
                    suffix: qsTr("Лимит кликов, ноль без лимита")
                    onValueModified: panel.engine.countLimit = value
                }
            }
            Label {
                text: qsTr("0 — без лимита. Сработает первое из условий.")
                font.pixelSize: 12
                color: Theme.muted
            }
            ActionButton {
                anchors.right: parent.right
                text: qsTr("Готово")
                primary: true
                onClicked: limits.close()
            }
        }
    }
}
