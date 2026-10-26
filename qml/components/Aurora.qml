import QtQuick
import QtQuick.Shapes
import CClicker
import "Motion.js" as Motion

// Light rising from the bottom edge of the window, after the Liner hero: a soft
// glow under vertical light curtains. At rest it is a faint, still horizon in the
// mode hue. While clicks are sent it brightens, the curtains rise and sway (each
// burst of clicks kicks them), and a
// bright crest appears; when sending stops it sinks back and holds still.
Item {
    id: aurora
    property color color: Theme.brand
    property bool active: false
    property int pulse: 0
    property real level: active ? 1 : 0
    Behavior on level { NumberAnimation { duration: aurora.active ? Theme.glowIn + 180 : Theme.glowOut + 280; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } }
    property color tint: color
    Behavior on tint { ColorAnimation { duration: Theme.hueShift } }
    // Sway runs only while the light is (or is settling) above rest.
    property real phase: 0
    NumberAnimation on phase { from: 0; to: 2 * Math.PI; duration: 5200; loops: Animation.Infinite; running: aurora.level > 0 }
    // Each burst of clicks kicks the curtains; the kick decays on its own.
    property real kick: 0
    onPulseChanged: if (active) kickAnimation.restart()
    SequentialAnimation {
        id: kickAnimation
        NumberAnimation { target: aurora; property: "kick"; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: aurora; property: "kick"; to: 0; duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }
    readonly property real band: 150 + 110 * level

    // Base glow: a wide ellipse centred below the bottom edge.
    Shape {
        id: base
        anchors.fill: parent
        readonly property real cx: width / 2
        readonly property real cy: height + 40
        readonly property real rx: width * 0.7
        readonly property real ry: aurora.band + 40
        ShapePath {
            strokeColor: Theme.clear
            fillGradient: RadialGradient {
                centerX: base.cx; centerY: base.cy; centerRadius: base.ry
                focalX: base.cx; focalY: base.cy; focalRadius: 0
                GradientStop { position: 0; color: Theme.alpha(aurora.tint, 0.34 + 0.3 * aurora.level) }
                GradientStop { position: 0.5; color: Theme.alpha(aurora.tint, 0.12 + 0.14 * aurora.level) }
                GradientStop { position: 1; color: Theme.alpha(aurora.tint, 0) }
            }
            // Radial gradients are circular; scale the path horizontally instead.
            PathAngleArc { centerX: base.cx; centerY: base.cy; radiusX: base.ry; radiusY: base.ry; startAngle: 0; sweepAngle: 360 }
        }
        transform: Scale { origin.x: base.cx; origin.y: base.cy; xScale: base.rx / base.ry }
    }
    // Two smooth light curtains: filled waves with a vertical fade. The back one
    // carries the hue, the front one is paler and sways the other way.
    function wave(offset, scale, direction) {
        const n = 40, w = width, h = height, pts = [Qt.point(0, h)];
        for (let i = 0; i <= n; ++i) {
            const u = i / n;
            const envelope = 0.3 + 0.7 * Math.pow(Math.sin(Math.PI * u), 0.8);
            const sway = 0.5 + 0.3 * Math.sin(direction * phase + u * 7.0 + offset)
                       + 0.2 * Math.sin(2 * direction * phase - u * 11.0 + offset * 2);
            const lift = 0.36 + level * (0.42 * sway + 0.22 * kick * (0.6 + 0.4 * Math.sin(u * 23.0 + offset)));
            pts.push(Qt.point(w * u, h - band * scale * envelope * lift));
        }
        pts.push(Qt.point(w, h));
        return pts;
    }
    Shape {
        objectName: "auroraCurtains"
        anchors.fill: parent
        // Feather: two fainter, slightly taller copies soften the crest.
        ShapePath {
            strokeColor: Theme.clear
            fillColor: Theme.alpha(aurora.tint, 0.05 + 0.04 * aurora.level)
            PathPolyline { path: aurora.wave(0, 1.16, 1) }
        }
        ShapePath {
            strokeColor: Theme.clear
            fillColor: Theme.alpha(aurora.tint, 0.06 + 0.05 * aurora.level)
            PathPolyline { path: aurora.wave(0, 1.07, 1) }
        }
        ShapePath {
            strokeColor: Theme.clear
            fillGradient: LinearGradient {
                x1: 0; y1: aurora.height - aurora.band; x2: 0; y2: aurora.height
                GradientStop { position: 0; color: Theme.alpha(aurora.tint, 0) }
                GradientStop { position: 0.6; color: Theme.alpha(aurora.tint, 0.2 + 0.18 * aurora.level) }
                GradientStop { position: 1; color: Theme.alpha(aurora.tint, 0.55 + 0.3 * aurora.level) }
            }
            PathPolyline { path: aurora.wave(0, 1, 1) }
        }
        ShapePath {
            strokeColor: Theme.clear
            fillGradient: LinearGradient {
                x1: 0; y1: aurora.height - aurora.band * 0.8; x2: 0; y2: aurora.height
                GradientStop { position: 0; color: Theme.alpha(Qt.lighter(aurora.tint, 1.35), 0) }
                GradientStop { position: 0.7; color: Theme.alpha(Qt.lighter(aurora.tint, 1.35), 0.16 + 0.16 * aurora.level) }
                GradientStop { position: 1; color: Theme.alpha(Qt.lighter(aurora.tint, 1.35), 0.4 + 0.25 * aurora.level) }
            }
            PathPolyline { path: aurora.wave(2.1, 0.72, -1) }
        }
    }
    // Live only: white light streaks and a bright crest along the bottom edge.
    Item {
        id: live
        objectName: "auroraLive"
        anchors.fill: parent
        opacity: aurora.level
        visible: opacity > 0.001
        // Soft vertical light: tall, narrow radial glows (a circle squeezed sideways).
        Repeater {
            model: 7
            Shape {
                id: streak
                required property int index
                readonly property real cx: aurora.width * (index + 0.5) / 7 + 40 * Math.sin(aurora.phase * (index % 2 ? 1 : -1) + index)
                readonly property real r: aurora.band * (0.55 + 0.2 * Math.sin(aurora.phase + index * 1.3)) * (0.85 + 0.3 * aurora.kick)
                anchors.fill: parent
                ShapePath {
                    strokeColor: Theme.clear
                    fillGradient: RadialGradient {
                        centerX: streak.cx; centerY: aurora.height; centerRadius: streak.r
                        focalX: streak.cx; focalY: aurora.height; focalRadius: 0
                        GradientStop { position: 0; color: Theme.alpha(Theme.sheen, 0.5) }
                        GradientStop { position: 0.6; color: Theme.alpha(Theme.sheen, 0.12) }
                        GradientStop { position: 1; color: Theme.alpha(Theme.sheen, 0) }
                    }
                    PathAngleArc { centerX: streak.cx; centerY: aurora.height; radiusX: streak.r; radiusY: streak.r; startAngle: 180; sweepAngle: 180 }
                }
                transform: Scale { origin.x: streak.cx; origin.y: aurora.height; xScale: 0.07 + 0.03 * (streak.index % 3) }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(Theme.sheen, 0) }
                GradientStop { position: 0.5; color: Theme.alpha(Theme.sheen, 0.9) }
                GradientStop { position: 1; color: Theme.alpha(Theme.sheen, 0) }
            }
        }
    }
}
