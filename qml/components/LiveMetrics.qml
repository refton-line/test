import QtQuick
import CClicker
import "Motion.js" as Motion

Item {
    id: panel
    property var engine
    // Readouts glide between 100 ms samples instead of ticking.
    property real cpsShown: Math.max(0, engine.measuredCps)
    property real clicksShown: engine.clicks
    property real targetShown: engine.expectedCps
    Behavior on cpsShown { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve } }
    Behavior on clicksShown { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on targetShown { NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve } }
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
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Behavior on width { NumberAnimation { duration: Theme.thumbTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
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
        Item {
            width: 6; height: 6
            anchors.verticalCenter: parent.verticalCenter
            // While sending, a ring pings outward from a steady dot.
            Rectangle {
                id: ping
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: Theme.brand
                opacity: 0
                SequentialAnimation {
                    running: panel.engine.active
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    ParallelAnimation {
                        NumberAnimation { target: ping; property: "scale"; from: 1; to: 3.4; duration: 1100; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                        NumberAnimation { target: ping; property: "opacity"; from: 0.6; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                    }
                    PauseAnimation { duration: 200 }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 3
                color: panel.engine.active ? Theme.brand : Theme.muted
                Behavior on color { ColorAnimation { duration: Theme.normal } }
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
        text: qsTr("цель %1").arg(panel.targetShown.toLocaleString(Qt.locale(i18n.locale), 'f', panel.engine.expectedCps < 100 ? 1 : 0))
        color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12
    }
    Label {
        y: 124; width: parent.width; height: 56
        text: panel.engine.measuredCps < 0 ? "—" : panel.cpsShown.toLocaleString(Qt.locale(i18n.locale), 'f', 1)
        font.family: Theme.mono; font.pixelSize: 40
        fontSizeMode: Text.Fit; minimumPixelSize: 20
    }
    Rectangle { y: 200; width: parent.width; height: 1; color: Theme.hairline }
    Label { y: 224; text: qsTr("Принято пар"); font.pixelSize: 14; color: Theme.muted }
    Label {
        y: 252; width: parent.width; height: 42
        text: Math.round(panel.clicksShown).toLocaleString(Qt.locale(i18n.locale), 'f', 0)
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
