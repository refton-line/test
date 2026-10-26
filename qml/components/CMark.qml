import QtQuick
import CClicker
import "Motion.js" as Motion

Item {
    id: mark

    property real trace: 0.05
    // 0..1, un-draws the stroke on close (the reverse of the opening trace).
    property real erase: 0
    implicitWidth: 64
    implicitHeight: 64
    Accessible.role: Accessible.Graphic
    Accessible.name: "C clicker"
    Component.onCompleted: trace = 1
    Behavior on trace { NumberAnimation { duration: Theme.reveal; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve } }
    onTraceChanged: ink.requestPaint()
    onEraseChanged: ink.requestPaint()
    Canvas {
        id: ink
        anchors.fill: parent
        visible: mark.trace * (1 - mark.erase) > 0.02
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const s = Math.min(width, height);
            c.beginPath();
            c.arc(width/2, height/2, s*0.31, Math.PI*0.23, Math.PI*0.23 + Math.PI*1.54*mark.trace*(1 - mark.erase));
            c.lineCap = "round"; c.lineWidth = s*0.105;
            // Same silver gradient and soft white light as the app icon.
            const g = c.createLinearGradient(width*0.74, height*0.26, width*0.26, height*0.76);
            g.addColorStop(0, Theme.sheen); g.addColorStop(0.45, Theme.accentEnd); g.addColorStop(1, Theme.edge);
            c.strokeStyle = g;
            c.shadowColor = Theme.alpha(Theme.sheen, 0.4); c.shadowBlur = s*0.12;
            c.stroke();
        }
    }
}
