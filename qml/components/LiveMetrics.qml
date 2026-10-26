import QtQuick
import CClicker

Item {
    id: panel
    property var engine
    Rectangle {
        anchors.fill: parent; anchors.margins: -24
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.hairline
    }
    Label { text: "Сессия"; font.pixelSize: 18; font.weight: Font.DemiBold }
    Row {
        y: 48; spacing: 8
        Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: panel.engine.active ? Theme.ink : Theme.muted
        }
        Label {
            objectName: "sessionStatus"
            text: panel.engine.countdown > 0 ? "Запуск через " + panel.engine.countdown + " с"
                : panel.engine.active ? "Идёт отправка" : "Ожидание"
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            color: Theme.muted; font.pixelSize: 14
        }
    }
    Label { y: 96; text: "Отправка / с"; color: Theme.muted; font.pixelSize: 14 }
    Label {
        y: 124; width: parent.width; height: 56
        text: panel.engine.measuredCps < 0 ? "—" : panel.engine.measuredCps.toLocaleString(Qt.locale("ru_RU"), 'f', 1)
        font.family: Theme.mono; font.pixelSize: 40
        fontSizeMode: Text.Fit; minimumPixelSize: 20
    }
    Rectangle { y: 200; width: parent.width; height: 1; color: Theme.hairline }
    Label { y: 224; text: "Принято пар"; font.pixelSize: 14; color: Theme.muted }
    Label {
        y: 252; width: parent.width; height: 42
        text: panel.engine.clicks.toLocaleString(Qt.locale("ru_RU"), 'f', 0)
        font.family: Theme.mono; font.pixelSize: 30
        fontSizeMode: Text.Fit; minimumPixelSize: 14
    }
    Column {
        y: 314; width: parent.width
        Repeater {
            model: [
                { label: "Интервал", value: panel.engine.meanGapMs < 0 ? "—" : panel.engine.meanGapMs.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " мс" },
                { label: "Отклонение", value: panel.engine.maxJitterMs < 0 ? "—" : panel.engine.maxJitterMs.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " мс" },
                { label: "Опоздание", value: panel.engine.maxLateMs.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " мс" },
                { label: "Пропуски", value: panel.engine.skipped.toLocaleString(Qt.locale("ru_RU"), 'f', 0) }
            ]
            Item {
                required property var modelData
                width: parent.width; height: 44
                Rectangle { width: parent.width; height: 1; color: Theme.hairline }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 100
                    text: modelData.label; font.pixelSize: 14; color: Theme.muted
                }
                Label {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 100; text: modelData.value
                    font.family: Theme.mono; font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
