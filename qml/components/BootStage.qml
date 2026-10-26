import QtQuick
import QtQuick.Shapes
import CClicker
import "Motion.js" as Motion

// Startup card, drawn like the app icon: a graphite plate, the C inside its ring,
// and the ring itself filling with load progress. When the app is ready the ring
// flares once; as the card unfolds into the window (handoff 0..1) the ring
// expands outward like a ripple and lets the C fly to the title bar alone.
Item {
    id: boot
    objectName: "bootStage"
    property int progress: 0
    property bool ready: false
    property string message
    property real handoff: 0
    // Centre of the C: CMark sits 48 px from the card top and is 112 px tall.
    readonly property real cx: width / 2
    readonly property real cy: 104
    readonly property real ringRadius: 62

    property real shownProgress: 0
    property real intro: 0
    onProgressChanged: shownProgress = progress
    Component.onCompleted: { shownProgress = progress; introAnimation.start(); }
    NumberAnimation { id: introAnimation; target: boot; property: "intro"; to: 1; duration: 620; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    Behavior on shownProgress { NumberAnimation { duration: 460; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }

    // Ready: one flare around the ring.
    property real flare: 0
    onReadyChanged: if (ready) flareAnimation.restart()
    SequentialAnimation {
        id: flareAnimation
        PauseAnimation { duration: 260 }
        NumberAnimation { target: boot; property: "flare"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: boot; property: "flare"; to: 0; duration: 620; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }
    // Breathing only while loading and on screen.
    property real breath: 0
    SequentialAnimation on breath {
        running: boot.visible && !boot.ready
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: Theme.breathe; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: Theme.breathe; easing.type: Easing.InOutSine }
    }
    readonly property real light: Math.min(1.2, 0.6 * intro + 0.15 * breath + 0.5 * flare)
    readonly property real ripple: Motion.decelerate(handoff)

    // Plate: the icon's graphite gradient with a lit top edge.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.surfaceRaised }
            GradientStop { position: 0.75; color: Theme.workspace }
        }
        Rim {}
    }
    Shape {
        id: halo
        readonly property real r: ring.r + 96
        anchors.fill: parent
        opacity: boot.light * (1 - boot.ripple)
        ShapePath {
            strokeColor: Theme.clear
            fillGradient: RadialGradient {
                centerX: boot.cx; centerY: boot.cy; centerRadius: halo.r
                focalX: boot.cx; focalY: boot.cy; focalRadius: 0
                GradientStop { position: 0; color: Theme.alpha(Theme.brand, 0) }
                GradientStop { position: (ring.r - 26) / halo.r; color: Theme.alpha(Theme.brand, 0.04) }
                GradientStop { position: ring.r / halo.r; color: Theme.alpha(Theme.brand, 0.28) }
                GradientStop { position: (ring.r + 34) / halo.r; color: Theme.alpha(Theme.brand, 0.07) }
                GradientStop { position: 1; color: Theme.alpha(Theme.brand, 0) }
            }
            PathAngleArc { centerX: boot.cx; centerY: boot.cy; radiusX: halo.r; radiusY: halo.r; startAngle: 0; sweepAngle: 360 }
        }
    }
    // Ring: track plus progress arc. On handoff it grows and thins into a ripple.
    Item {
        id: ring
        objectName: "bootRing"
        anchors.fill: parent
        opacity: Motion.seg(boot.intro, 0.1, 0.7) * (1 - boot.ripple)
        Accessible.role: Accessible.ProgressBar
        Accessible.name: qsTr("Загрузка приложения")
        Accessible.description: boot.progress + "%"
        readonly property real r: boot.ringRadius * (1 + 0.55 * boot.ripple)
        readonly property real w: 4 * (1 - 0.6 * boot.ripple)
        readonly property real sweep: 360 * boot.shownProgress / 100
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: ring.w
                strokeColor: Theme.alpha(Theme.brand, 0.16)
                fillColor: Theme.clear
                PathAngleArc { centerX: boot.cx; centerY: boot.cy; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeWidth: ring.w
                strokeColor: Qt.tint(Theme.brand, Theme.alpha(Theme.ember, 0.35 * boot.flare))
                capStyle: ShapePath.RoundCap
                fillColor: Theme.clear
                PathAngleArc { centerX: boot.cx; centerY: boot.cy; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: ring.sweep }
            }
        }
        // Glint riding the head of the arc.
        Item {
            readonly property real a: (ring.sweep - 90) * Math.PI / 180
            x: boot.cx + ring.r * Math.cos(a) - width / 2
            y: boot.cy + ring.r * Math.sin(a) - height / 2
            width: 8; height: 8
            visible: ring.sweep > 2
            Bloom { anchors.fill: parent; radius: 4; color: Theme.ember; spread: 10; peak: 0.45; strength: 0.6 + 0.4 * boot.flare }
            Rectangle { anchors.fill: parent; radius: 4; color: Theme.accentInk }
        }
    }
    Column {
        y: 194 - 14 * boot.ripple
        width: parent.width
        spacing: 10
        opacity: (1 - Motion.seg(boot.handoff, 0, 0.6))
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: Motion.seg(boot.intro, 0.2, 1)
            transform: Translate { y: 8 * (1 - boot.intro) }
            text: "C clicker"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.letterSpacing: -0.5
        }
        Label {
            id: step
            objectName: "bootMessage"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 64
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: Motion.seg(boot.intro, 0.4, 1) * stepFade
            text: boot.message
            font.pixelSize: 13
            color: boot.ready ? Theme.ink : Theme.muted
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            // Each new step settles in from below.
            property real stepFade: 1
            property real stepShift: 0
            transform: Translate { y: step.stepShift + 8 * (1 - boot.intro) }
            onTextChanged: stepIn.restart()
            ParallelAnimation {
                id: stepIn
                NumberAnimation { target: step; property: "stepFade"; from: 0.2; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: step; property: "stepShift"; from: 6; to: 0; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
            }
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 34
        opacity: Motion.seg(boot.intro, 0.5, 1) * (1 - Motion.seg(boot.handoff, 0, 0.5))
        text: "v" + Qt.application.version.split("-")[0]
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.faint
    }
}
