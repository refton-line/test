import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import CClicker
import "Motion.js" as Motion

// The start/stop control. One ring carries every state: a soft idle halo, a
// countdown arc, a rotating light while sending and a ripple for each burst of
// accepted clicks. Infinite motion only exists while the engine is active.
AbstractButton {
    id: hero
    objectName: "startButton"
    property var engine
    // Opening/closing choreography (0 = not drawn, 1 = fully lit), driven by Main.
    property real reveal: 1
    readonly property real ringRadius: 128
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // QA/recording preview of the running visuals (capture mode only; no input is sent).
    property bool demo: false
    readonly property bool live: engine.active || demo
    readonly property bool counting: engine.countdown > 0

    implicitWidth: 340; implicitHeight: 340
    text: live ? qsTr("Остановить") : qsTr("Запустить")
    enabled: engine.available || engine.active
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    onClicked: engine.toggle()
    // Only the disc is clickable, not the square around it.
    containmentMask: hitDisc
    Shape {
        id: hitDisc
        anchors.fill: parent
        opacity: 0
        containsMode: Shape.FillContains
        ShapePath {
            fillColor: "black"; strokeColor: Theme.clear
            PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: hero.ringRadius + 8; radiusY: hero.ringRadius + 8; startAngle: 0; sweepAngle: 360 }
        }
    }

    property color hue: Theme.modeColor(engine.clickMode)
    Behavior on hue { ColorAnimation { duration: Theme.hueShift; easing.type: Easing.OutCubic } }

    // Light level: quiet when idle, lifted on hover/focus, full while live.
    property real level: !enabled ? 0.25 : live ? 1 : (hovered || visualFocus) ? 0.62 : 0.42
    Behavior on level { NumberAnimation { duration: Theme.glowIn; easing.type: Easing.OutCubic } }
    property real breath: 0
    SequentialAnimation on breath {
        running: hero.live
        loops: Animation.Infinite
        alwaysRunToEnd: false
        NumberAnimation { from: 0; to: 1; duration: Theme.breathe; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: Theme.breathe; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) hero.breath = 0
    }
    property real flare: 0
    SequentialAnimation {
        id: ignite
        NumberAnimation { target: hero; property: "flare"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: hero; property: "flare"; to: 0; duration: 760; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }
    readonly property real light: Math.min(1.25, level * reveal + 0.12 * breath + 0.5 * flare)

    property real spin: 0
    NumberAnimation on spin { from: 0; to: 360; duration: Theme.heroTurn; loops: Animation.Infinite; running: hero.live }
    onLiveChanged: live ? ignite.restart() : spinHome.restart()
    // Come to rest at the top instead of freezing mid-turn.
    NumberAnimation { id: spinHome; target: hero; property: "spin"; to: 360 * Math.ceil(hero.spin / 360); duration: 600; easing.type: Easing.OutCubic }

    // Countdown arc: remaining fraction, eased between whole seconds.
    property real arc: counting ? engine.countdown / Math.max(1, engine.launchDelaySec) : 0
    Behavior on arc { NumberAnimation { duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }

    background: Item {
        // Halo: radial falloff peaking just outside the ring.
        Shape {
            id: halo
            readonly property real r: hero.ringRadius + 84
            anchors.fill: parent
            opacity: Math.min(1, hero.light)
            scale: 1 + 0.06 * hero.flare
            ShapePath {
                strokeColor: Theme.clear
                fillGradient: RadialGradient {
                    centerX: hero.cx; centerY: hero.cy; centerRadius: halo.r
                    focalX: hero.cx; focalY: hero.cy; focalRadius: 0
                    GradientStop { position: 0.0; color: Theme.alpha(hero.hue, 0.0) }
                    GradientStop { position: (hero.ringRadius - 36) / halo.r; color: Theme.alpha(hero.hue, 0.03) }
                    GradientStop { position: hero.ringRadius / halo.r; color: Theme.alpha(hero.hue, 0.34) }
                    GradientStop { position: (hero.ringRadius + 26) / halo.r; color: Theme.alpha(hero.hue, 0.10) }
                    GradientStop { position: 1.0; color: Theme.alpha(hero.hue, 0.0) }
                }
                PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: halo.r; radiusY: halo.r; startAngle: 0; sweepAngle: 360 }
            }
        }
        // Ripples: one per burst of accepted clicks while live.
        Repeater {
            id: ripples
            model: 3
            Rectangle {
                required property int index
                property real t: 1
                x: hero.cx - width / 2; y: hero.cy - height / 2
                width: 2 * hero.ringRadius; height: width; radius: width / 2
                color: Theme.clear
                border.width: 2
                border.color: hero.hue
                scale: 1 + 0.32 * t
                opacity: 0.55 * (1 - t)
                visible: t < 1
                NumberAnimation on t { id: run; running: false; from: 0; to: 1; duration: Theme.ripple; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                function fire() { run.restart(); }
            }
        }
        // Face.
        Rectangle {
            x: hero.cx - width / 2; y: hero.cy - height / 2
            width: 2 * hero.ringRadius - 10; height: width; radius: width / 2
            scale: hero.down ? 0.97 : 1
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.42; epsilon: 0.0005 } }
            opacity: hero.reveal
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.surfaceRaised }
                GradientStop { position: 1; color: Theme.surface }
            }
            border.width: hero.visualFocus ? 2 : 1
            border.color: hero.visualFocus ? Theme.focus : Theme.hairline
        }
        // Track and rotating core.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: hero.reveal
            ShapePath {
                strokeWidth: 2
                strokeColor: Theme.alpha(hero.hue, 0.18)
                fillColor: Theme.clear
                PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: hero.ringRadius; radiusY: hero.ringRadius; startAngle: 0; sweepAngle: 360 }
            }
        }
        Shape {
            objectName: "heroCore"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            rotation: hero.spin
            opacity: Math.min(1, hero.light) * Motion.seg(hero.reveal, 0.55, 1)
            ShapePath {
                strokeWidth: -1
                strokeColor: Theme.clear
                fillRule: ShapePath.OddEvenFill
                fillGradient: ConicalGradient {
                    centerX: hero.cx; centerY: hero.cy; angle: 90
                    GradientStop { position: 0.0; color: Theme.alpha(hero.hue, 0.95) }
                    GradientStop { position: 0.05; color: Theme.alpha(Theme.ink, 1) }
                    GradientStop { position: 0.13; color: Theme.alpha(hero.hue, 1) }
                    GradientStop { position: 0.42; color: Theme.alpha(hero.hue, 0.22) }
                    GradientStop { position: 0.72; color: Theme.alpha(hero.hue, 0.08) }
                    GradientStop { position: 1.0; color: Theme.alpha(hero.hue, 0.95) }
                }
                PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: hero.ringRadius + 4; radiusY: hero.ringRadius + 4; startAngle: 0; sweepAngle: 360 }
                PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: hero.ringRadius - 4; radiusY: hero.ringRadius - 4; startAngle: 0; sweepAngle: 360 }
            }
        }
        // Arc: draws the ring in on open, then shows the countdown.
        Shape {
            id: arcShape
            objectName: "heroArc"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property bool countdownArc: hero.counting || hero.arc > 0.001
            readonly property real sweep: countdownArc ? hero.arc : (hero.reveal < 1 ? hero.reveal : 0)
            // The draw-in arc hands over to the steady ring near the end of the
            // reveal, so it never pops at full brightness when a close begins.
            opacity: countdownArc ? 1 : Math.min(1, (1 - hero.reveal) * 4)
            visible: sweep > 0.001 && opacity > 0.001
            ShapePath {
                strokeWidth: 5
                strokeColor: hero.counting ? Theme.ink : hero.hue
                capStyle: ShapePath.RoundCap
                fillColor: Theme.clear
                PathAngleArc { centerX: hero.cx; centerY: hero.cy; radiusX: hero.ringRadius; radiusY: hero.ringRadius; startAngle: -90; sweepAngle: 360 * arcShape.sweep }
            }
        }
    }

    // Ripple pacing: at most one ring every 240 ms, only for real deliveries.
    property real lastRipple: 0
    property int nextRipple: 0
    Connections {
        target: hero.engine
        function onChanged() {
            if (!hero.live || hero.engine.clicks === 0) return;
            const now = Date.now();
            if (now - hero.lastRipple < 240 || hero.engine.clicks === hero.seenClicks) return;
            hero.seenClicks = hero.engine.clicks;
            hero.lastRipple = now;
            ripples.itemAt(hero.nextRipple).fire();
            hero.nextRipple = (hero.nextRipple + 1) % 3;
        }
    }
    property real seenClicks: 0
    Timer {
        interval: 420; repeat: true; running: hero.demo
        onTriggered: { ripples.itemAt(hero.nextRipple).fire(); hero.nextRipple = (hero.nextRipple + 1) % 3; }
    }

    function fmt(v, digits) { return v.toLocaleString(Qt.locale(i18n.locale), 'f', digits); }
    property real cpsShown: Math.max(0, engine.measuredCps)
    Behavior on cpsShown { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve } }
    readonly property string idleValue: engine.clickMode === 0
        ? (engine.cpsMin === engine.cpsMax ? String(engine.cpsMin) : engine.cpsMin + "–" + engine.cpsMax)
        : fmt(1000 / engine.intervalMs, 1000 / engine.intervalMs < 100 ? 1 : 0)

    contentItem: Item {
        opacity: Motion.seg(hero.reveal, 0.4, 1)
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 4
            spacing: 6
            Label {
                objectName: "sessionStatus"
                anchors.horizontalCenter: parent.horizontalCenter
                text: hero.counting ? qsTr("Запуск через %1 с").arg(hero.engine.countdown)
                    : hero.live ? qsTr("Идёт отправка") : qsTr("Готов")
                font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
                color: hero.live ? hero.hue : Theme.muted
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
            Label {
                id: value
                objectName: "heroValue"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * hero.ringRadius - 56; height: 76
                horizontalAlignment: Text.AlignHCenter
                text: hero.counting ? String(hero.engine.countdown)
                    : hero.live ? (hero.engine.measuredCps < 0 ? (hero.demo ? hero.idleValue : "—") : hero.fmt(hero.cpsShown, 1))
                    : hero.idleValue
                font.family: Theme.mono; font.pixelSize: 64; font.weight: Font.Medium
                fontSizeMode: Text.Fit; minimumPixelSize: 28
                // Each countdown second lands with a small pop.
                onTextChanged: if (hero.counting) pop.restart()
                SequentialAnimation {
                    id: pop
                    NumberAnimation { target: value; property: "scale"; from: 1.18; to: 1; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: hero.live ? qsTr("КПС") + " · " + qsTr("цель %1").arg(hero.fmt(hero.engine.expectedCps, hero.engine.expectedCps < 100 ? 1 : 0))
                    : qsTr("КПС")
                font.pixelSize: 13
                color: Theme.muted
            }
            Item { width: 1; height: 10 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Icon {
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: hero.live ? "square" : "play"
                    foreground: hero.live ? hero.hue : Theme.ink
                }
                Label {
                    text: hero.live ? qsTr("Стоп · %1").arg(hero.engine.stopLabel) : qsTr("Нажмите или %1").arg(hero.engine.startLabel)
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: Theme.ink
                }
            }
        }
    }
}
