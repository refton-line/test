import QtQuick
import CClicker
import "Motion.js" as Motion

Item {
    id: boot
    property int progress: 0
    property bool ready: false

    property real shownProgress: 0
    // Title and bar rise in under the drawing C instead of being there at frame one.
    property real intro: 0
    onProgressChanged: shownProgress = progress
    Component.onCompleted: { shownProgress = progress; introAnimation.start(); }
    NumberAnimation { id: introAnimation; target: boot; property: "intro"; to: 1; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    Behavior on shownProgress {
        NumberAnimation {
            duration: 420
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standardCurve
        }
    }
    Label {
        opacity: Motion.seg(boot.intro, 0.15, 1)
        y: 196 + 8 * (1 - boot.intro)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "C clicker"
        font.pixelSize: 26
        font.weight: Font.Medium
        font.letterSpacing: -0.5
    }
    Rectangle {
        opacity: Motion.seg(boot.intro, 0.35, 1)
        x: 48
        y: 306
        width: parent.width - 96
        height: 2
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("Загрузка приложения")
        Accessible.description: boot.progress + "%"
        color: Theme.hairline
        Rectangle {
            width: parent.width * boot.shownProgress / 100
            height: 2
            color: Theme.brand
        }
    }
}
