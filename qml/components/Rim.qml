import QtQuick
import CClicker

// A 1px rim light along the top edge of a surface, brightest in the middle and
// fading at the corners, so panels read as lit from above rather than outlined.
Rectangle {
    property real inset: Theme.radiusLarge
    x: inset; width: parent.width - 2 * inset
    height: 1
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.clear }
        GradientStop { position: 0.5; color: Theme.rimLight }
        GradientStop { position: 1; color: Theme.clear }
    }
}
