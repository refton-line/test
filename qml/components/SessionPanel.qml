import QtQuick
import QtQuick.Controls
import CClicker

Item {
    id: panel
    property var engine

    function elapsed() {
        const s = Math.floor(engine.elapsedSec);
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }
    Label {
        text: qsTr("Журнал")
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }
    Row {
        y: 56
        spacing: 40
        Column {
            spacing: 8
            Label {
                text: qsTr("Принятых пар")
                color: Theme.muted
                font.pixelSize: 14
            }
            Label {
                width: 220
                height: 52
                text: panel.engine.clicks.toLocaleString(Qt.locale(i18n.locale), 'f', 0)
                font.family: Theme.mono
                font.pixelSize: 40
                fontSizeMode: Text.Fit
                minimumPixelSize: 16
            }
        }
        Column {
            spacing: 8
            Label {
                text: qsTr("Время отправки")
                color: Theme.muted
                font.pixelSize: 14
            }
            Label {
                width: 260
                height: 52
                text: panel.elapsed()
                font.family: Theme.mono
                font.pixelSize: 40
                fontSizeMode: Text.Fit
                minimumPixelSize: 16
            }
        }
        Column {
            spacing: 8
            Label {
                text: qsTr("Средняя отправка / с")
                color: Theme.muted
                font.pixelSize: 14
            }
            Label {
                width: 240
                height: 52
                text: panel.engine.averageCps < 0 ? "—" : panel.engine.averageCps.toFixed(1)
                font.family: Theme.mono
                font.pixelSize: 40
                fontSizeMode: Text.Fit
                minimumPixelSize: 16
            }
        }
    }
    Row {
        y: 156
        spacing: 8
        ActionButton {
            objectName: "copyLog"
            text: qsTr("Копировать")
            glyph: "copy"
            enabled: panel.engine.entries.length > 0
            onClicked: panel.engine.copyLog()

        }
        ActionButton {
            objectName: "clearLog"
            text: qsTr("Очистить")
            enabled: panel.engine.entries.length > 0 && !panel.engine.active
            onClicked: panel.engine.clearLog()

        }
    }
    Rectangle {
        y: 224
        width: parent.width
        height: 1
        color: Theme.hairline
    }
    ListView {
        id: list
        y: 240
        width: parent.width
        height: parent.height - y
        clip: true
        model: panel.engine.entries
        delegate: Item {
            required property string modelData
            width: ListView.view.width
            height: Math.max(48, message.implicitHeight + 24)
            Label {
                id: message
                width: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                font.family: Theme.mono
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.hairline
            }
        }
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
    Label {
        visible: panel.engine.entries.length === 0
        anchors.centerIn: list
        text: qsTr("Журнал очищен")
        color: Theme.muted
        font.pixelSize: 14
    }
}
