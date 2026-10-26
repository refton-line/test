import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CClicker
import "Motion.js" as Motion

// Left control panel: choose the mode, tune it, pick the button and limits.
// The ring on the right only starts and shows; everything adjustable lives here.
Rectangle {
    id: panel
    property var engine
    radius: Theme.radiusLarge
    color: Theme.surface
    border.color: Theme.hairline
    Rim {}

    readonly property bool idle: !engine.active
    readonly property real inner: width - 40
    // Mode bodies take turns on the horizontal axis of the tiles: the new body
    // slides in from the side of the chosen tile, the old one leaves the other way.
    property int settledMode: 0
    component ModeBody: Stage {
        property int mode
        x: 20; y: 196; width: panel.inner; height: 284
        horizontal: true
        travel: Theme.modeTravel
        current: panel.engine.clickMode === mode
        Component.onCompleted: if (current) panel.settledMode = mode
        onCurrentChanged: {
            if (current) {
                const direction = mode > panel.settledMode ? 1 : -1;
                panel.settledMode = mode;
                enter(direction);
            } else {
                leave(panel.engine.clickMode > mode ? 1 : -1);
            }
        }
    }
    component Caption: Label {
        font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.1
        font.capitalization: Font.AllUppercase
        color: Theme.faint
    }
    component Readout: Label { font.family: Theme.mono; font.pixelSize: 13; color: Theme.muted }
    function rate(v) { return v.toLocaleString(Qt.locale(i18n.locale), 'f', v < 100 ? 1 : 0) }

    Caption { x: 20; y: 20; text: qsTr("Режим") }
    ModePicker {
        x: 20; y: 42; width: panel.inner
        names: [qsTr("Легит"), qsTr("Блатант"), qsTr("Свой")]
        hints: [qsTr("Как рука"), qsTr("Максимум"), qsTr("Рецепт")]
        current: panel.engine.clickMode
        enabled: panel.idle
        onActivated: index => panel.engine.clickMode = index
    }
    Label {
        objectName: "modeDescription"
        x: 20; y: 146; width: panel.inner; height: 40
        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        color: Theme.muted
        font.pixelSize: 12
        lineHeight: 1.15
        text: [qsTr("Эмуляция мыши через SendInput: живой ритм, разброс и паузы, как у руки."),
               qsTr("Искусственные клики сообщениями окну под курсором: точная сетка, до 1000 / с."),
               qsTr("Свой рецепт: интервал, разброс, волна и способ доставки.")][panel.engine.clickMode] || ""
    }

    // ---- Legit: CPS range with a humanised rhythm ----
    ModeBody {
        objectName: "legitBody"
        mode: 0
        Caption { y: 4; text: qsTr("Диапазон КПС") }
        Readout {
            anchors.right: parent.right; y: 2
            text: (panel.engine.cpsMin === panel.engine.cpsMax ? String(panel.engine.cpsMin) : panel.engine.cpsMin + "–" + panel.engine.cpsMax) + " · ≈ " + panel.rate(panel.engine.expectedCps)
        }
        CpsRange {
            objectName: "cpsRange"
            y: 24; width: parent.width
            engine: panel.engine
            hue: Theme.legit
            enabled: panel.idle
        }
        Segmented {
            objectName: "legitPresets"
            y: 80; width: parent.width
            columns: 2
            prefix: "legitPreset"
            readonly property var ranges: [[6, 9], [9, 13], [13, 17], [17, 22]]
            model: [qsTr("Спокойно 6–9"), qsTr("Ровно 9–13"), qsTr("Быстро 13–17"), qsTr("Пик 17–22")]
            current: ranges.findIndex(r => r[0] === panel.engine.cpsMin && r[1] === panel.engine.cpsMax)
            enabled: panel.idle
            onActivated: index => panel.engine.setCpsRange(ranges[index][0], ranges[index][1])
        }
        RhythmStrip {
            objectName: "legitRhythm"
            hue: Theme.legit
            y: 192; width: parent.width; height: 64
            gaps: panel.engine.rhythmPreview
        }
    }

    // ---- Blatant: exact interval grid ----
    ModeBody {
        objectName: "blatantBody"
        mode: 1
        RowLayout {
            width: parent.width; spacing: 8
            Label { text: qsTr("Интервал"); font.pixelSize: 14 }
            Item { Layout.fillWidth: true }
            Readout { text: panel.rate(1000 / panel.engine.intervalMs) + qsTr(" / с") }
            NumberField {
                objectName: "intervalField"
                from: panel.engine.minIntervalMs; to: 10000; stepSize: 1
                value: panel.engine.intervalMs
                suffix: qsTr("Интервал в миллисекундах")
                enabled: panel.idle
                onValueModified: panel.engine.intervalMs = value
            }
            Label { text: qsTr("мс"); font.pixelSize: 14; color: Theme.muted; Layout.preferredWidth: 22 }
        }
        Segmented {
            objectName: "presetsFrame"
            y: 60; width: parent.width
            readonly property var rates: [10, 50, 100, 200, 500]
            model: rates.map(v => v + qsTr(" / с"))
            names: rates.map(v => "preset" + v)
            current: rates.findIndex(v => Math.abs(1000 / panel.engine.intervalMs - v) < 0.01)
            enabled: panel.idle
            onActivated: index => panel.engine.intervalMs = Math.round(1000 / rates[index])
        }
        RowLayout {
            y: 124; width: parent.width; spacing: 8
            Label { text: qsTr("Удержание"); Layout.fillWidth: true; font.pixelSize: 14 }
            NumberField {
                objectName: "holdField"
                from: 0
                to: Math.max(0, Math.min(100, panel.engine.intervalMs - 1))
                value: panel.engine.holdMs
                suffix: qsTr("Удержание кнопки в миллисекундах")
                enabled: panel.idle
                onValueModified: panel.engine.holdMs = value
            }
            Label { text: qsTr("мс"); font.pixelSize: 14; color: Theme.muted; Layout.preferredWidth: 22 }
        }
        RhythmStrip {
            hue: Theme.blatant
            y: 192; width: parent.width; height: 64
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
                Layout.preferredWidth: 220
                prefix: "delivery"
                model: [qsTr("Эмуляция"), qsTr("Сообщения")]
                current: panel.engine.delivery
                enabled: panel.idle
                onActivated: index => panel.engine.delivery = index
            }
        }
        Row2 {
            y: 228
            Label { text: qsTr("Темп"); Layout.fillWidth: true; font.pixelSize: 14 }
            Segmented {
                objectName: "driftFrame"
                Layout.preferredWidth: 220
                prefix: "drift"
                model: [qsTr("Ровный"), qsTr("Волна")]
                current: panel.engine.drift ? 1 : 0
                enabled: panel.idle
                onActivated: index => panel.engine.drift = index === 1
            }
        }
    }

    Rectangle { x: 20; y: 492; width: panel.inner; height: 1; color: Theme.hairline }
    RowLayout {
        x: 20; y: 508; width: panel.inner
        spacing: 12
        Label { text: qsTr("Кнопка"); font.pixelSize: 14; Layout.fillWidth: true }
        Segmented {
            objectName: "mouseFrame"
            Layout.preferredWidth: 270
            prefix: "mouse"
            model: [qsTr("Левая"), qsTr("Правая"), qsTr("Средняя")]
            current: panel.engine.mouseButton
            enabled: panel.idle
            onActivated: index => panel.engine.mouseButton = index
        }
    }
    ActionButton {
        objectName: "limitsButton"
        x: 20; y: 572; width: panel.inner
        outlined: true
        text: panel.engine.durationSec > 0 || panel.engine.countLimit > 0 ? qsTr("Заданы лимиты") : qsTr("Остановка вручную")
        glyph: "settings"
        enabled: panel.idle
        onClicked: limits.open()
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
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.pageFade; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.dialogEnter; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve } NumberAnimation { property: "scale"; to: 0.97; duration: Theme.dialogExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve } } }
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
