import QtQuick
import CClicker

// Soft light around a rounded rectangle, built from concentric bands with a
// quadratic falloff instead of a blur shader, so it looks the same on the GPU and
// on the software renderer. strength 0 removes it from the scene entirely.
Item {
    id: bloom
    property color color: Theme.brand
    property real radius: Theme.radius
    property real spread: 16
    property real strength: 1
    property real peak: 0.24
    property int layers: 8
    visible: strength > 0.002
    Repeater {
        model: bloom.visible ? bloom.layers : 0
        Rectangle {
            required property int index
            readonly property real step: bloom.spread / bloom.layers
            readonly property real reach: step * (index + 1)
            x: -reach; y: -reach
            width: bloom.width + 2 * reach; height: bloom.height + 2 * reach
            radius: bloom.radius + reach
            color: Theme.clear
            border.width: step + 0.5
            border.color: Theme.alpha(bloom.color, bloom.peak * bloom.strength * Math.pow(1 - index / bloom.layers, 2))
        }
    }
}
