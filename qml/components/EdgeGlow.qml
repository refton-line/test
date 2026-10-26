import QtQuick
import QtQuick.Shapes
import CClicker

// Edge light around the window while clicks are being sent: a rotating comet
// of the mode hue on a thin rim, plus an inward bloom. It is tied to the real
// running state, never decorative, and fades all the way to nothing when idle.
Item {
    id: rim
    objectName: "edgeGlow"
    property color color: Theme.brand
    property real radius: Theme.radiusLarge
    property bool active: false
    property real level: active ? 1 : 0
    property real angle: 0
    Behavior on level { NumberAnimation { duration: rim.active ? Theme.glowIn : Theme.glowOut; easing.type: Easing.OutCubic } }
    opacity: level
    visible: level > 0.001
    NumberAnimation on angle { from: 0; to: 360; duration: Theme.rimTurn; loops: Animation.Infinite; running: rim.visible }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Inward bloom: wide translucent strokes centred on the edge; the outer
        // half is clipped by the window shell.
        ShapePath {
            strokeWidth: 34
            strokeColor: Theme.alpha(rim.color, 0.08)
            fillColor: Theme.clear
            PathRectangle { x: 0; y: 0; width: rim.width; height: rim.height; radius: rim.radius }
        }
        ShapePath {
            strokeWidth: 12
            strokeColor: Theme.alpha(rim.color, 0.2)
            fillColor: Theme.clear
            PathRectangle { x: 0; y: 0; width: rim.width; height: rim.height; radius: rim.radius }
        }
        // Core: a 2px ring filled with a rotating conical gradient.
        ShapePath {
            strokeWidth: -1
            strokeColor: Theme.clear
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: rim.width / 2; centerY: rim.height / 2
                angle: rim.angle
                GradientStop { position: 0.0; color: Theme.alpha(rim.color, 1) }
                GradientStop { position: 0.12; color: Theme.alpha(Theme.ember, 0.85) }
                GradientStop { position: 0.32; color: Theme.alpha(rim.color, 0.3) }
                GradientStop { position: 0.68; color: Theme.alpha(rim.color, 0.3) }
                GradientStop { position: 0.88; color: Theme.alpha(rim.color, 0.7) }
                GradientStop { position: 1.0; color: Theme.alpha(rim.color, 1) }
            }
            PathRectangle { x: 0; y: 0; width: rim.width; height: rim.height; radius: rim.radius }
            PathRectangle { x: 3; y: 3; width: rim.width - 6; height: rim.height - 6; radius: Math.max(0, rim.radius - 3) }
        }
    }
}
