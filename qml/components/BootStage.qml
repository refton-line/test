import QtQuick
import CClicker

Item {
    id: boot
    property int progress: 0
    property bool ready: false

    property real shownProgress: 0
    onProgressChanged: shownProgress = progress
    Component.onCompleted: shownProgress = progress
    Behavior on shownProgress {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutCubic
        }
    }
    Label {
        y: 196
        anchors.horizontalCenter: parent.horizontalCenter
        text: "C clicker"
        font.pixelSize: 26
        font.weight: Font.Medium
        font.letterSpacing: -0.5
    }
    Rectangle {
        x: 48
        y: 306
        width: parent.width - 96
        height: 2
        Accessible.role: Accessible.ProgressBar
        Accessible.name: "Загрузка приложения"
        Accessible.description: boot.progress + "%"
        color: Theme.hairline
        Rectangle {
            width: parent.width * boot.shownProgress / 100
            height: 2
            color: Theme.brand
        }
    }
}
