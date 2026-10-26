import QtQuick
import CClicker
import "Motion.js" as Motion

// A surface that takes turns with its siblings (pages, mode bodies).
// enter()/leave() overlap in motion but not in opacity: the old surface drops out
// almost at once while it accelerates away, and the new one fades in just after,
// decelerating from the direction of travel. No blank frame, no double exposure.
Item {
    id: stage
    property bool current: false
    property bool horizontal: false
    property real travel: Theme.pageRise
    property real shift: 0
    property real leaveTo: 0
    opacity: 0
    visible: opacity > 0
    enabled: current
    transform: Translate {
        x: stage.horizontal ? stage.shift : 0
        y: stage.horizontal ? 0 : stage.shift
    }
    Component.onCompleted: if (current) opacity = 1
    function enter(direction) {
        leaveAnimation.stop();
        if (opacity === 0) shift = travel * direction;
        enterAnimation.restart();
    }
    function leave(direction) {
        enterAnimation.stop();
        leaveTo = -travel * 0.5 * direction;
        leaveAnimation.restart();
    }
    ParallelAnimation {
        id: enterAnimation
        SequentialAnimation {
            PauseAnimation { duration: Theme.pageOverlap }
            NumberAnimation { target: stage; property: "opacity"; to: 1; duration: Theme.pageFade; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: stage; property: "shift"; to: 0; duration: Theme.pageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }
    ParallelAnimation {
        id: leaveAnimation
        NumberAnimation { target: stage; property: "opacity"; to: 0; duration: Theme.pageFadeOut; easing.type: Easing.OutCubic }
        NumberAnimation { target: stage; property: "shift"; to: stage.leaveTo; duration: Theme.pageOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve }
    }
}
