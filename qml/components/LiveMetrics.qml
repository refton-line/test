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
    Label { text: qsTr("Сессия"); font.pixelSize: 18; font.weight: Font.DemiBold }
    Rectangle {
        objectName: "modeChip"
        anchors.right: parent.right
        y: 1
        width: chipText.implicitWidth + 16; height: 24
        radius: Theme.radiusSmall
        color: panel.engine.clickMode === 1 ? Theme.accent : Theme.surfaceRaised
        Label {
            id: chipText
            anchors.centerIn: parent
            text: [qsTr("ЛЕГИТ"), qsTr("БЛАТАНТ"), qsTr("СВОЙ")][panel.engine.clickMode] || ""
            font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.8
            color: Theme.accentInk
        }
    }
    Row {
        y: 48; spacing: 8
        Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: panel.engine.active ? Theme.brand : Theme.muted
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            SequentialAnimation on opacity {
                running: panel.engine.active
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }
        Label {
            objectName: "sessionStatus"
            text: panel.engine.countdown > 0 ? qsTr("Запуск через %1 с").arg(panel.engine.countdown)
                : panel.engine.active ? qsTr("Идёт отправка") : qsTr("Ожидание")
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            color: Theme.muted; font.pixelSize: 14
        }
    }
    Label { y: 96; text: qsTr("Отправка / с"); color: Theme.muted; font.pixelSize: 14 }
    Label {
        objectName: "targetRate"
        y: 96; anchors.right: parent.right
        text: qsTr("цель %1").arg(panel.engine.expectedCps.toLocaleString(Qt.locale(i18n.locale), 'f', panel.engine.expectedCps < 100 ? 1 : 0))
        color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12
    }
    Label {
        y: 124; width: parent.width; height: 56
        text: panel.engine.measuredCps < 0 ? "—" : panel.engine.measuredCps.toLocaleString(Qt.locale(i18n.locale), 'f', 1)
        font.family: Theme.mono; font.pixelSize: 40
        fontSizeMode: Text.Fit; minimumPixelSize: 20
    }
    Rectangle { y: 200; width: parent.width; height: 1; color: Theme.hairline }
    Label { y: 224; text: qsTr("Принято пар"); font.pixelSize: 14; color: Theme.muted }
    Label {
        y: 252; width: parent.width; height: 42
        text: panel.engine.clicks.toLocaleString(Qt.locale(i18n.locale), 'f', 0)
        font.family: Theme.mono; font.pixelSize: 30
        fontSizeMode: Text.Fit; minimumPixelSize: 14
    }
    Column {
        y: 314; width: parent.width
        Repeater {
            model: [
                { label: qsTr("Интервал"), value: panel.engine.meanGapMs < 0 ? "—" : panel.engine.meanGapMs.toLocaleString(Qt.locale(i18n.locale), 'f', 2) + qsTr(" мс") },
                { label: qsTr("Отклонение"), value: panel.engine.maxJitterMs < 0 ? "—" : panel.engine.maxJitterMs.toLocaleString(Qt.locale(i18n.locale), 'f', 2) + qsTr(" мс") },
                { label: qsTr("Опоздание"), value: panel.engine.maxLateMs.toLocaleString(Qt.locale(i18n.locale), 'f', 2) + qsTr(" мс") },
                { label: qsTr("Пропуски"), value: panel.engine.skipped.toLocaleString(Qt.locale(i18n.locale), 'f', 0) }
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
