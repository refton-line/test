import QtQuick
import CClicker

// Soft drop shadow for floating light surfaces: the Bloom bands in navy at low
// alpha, nudged down. Place as a child with z: -1 so it renders behind its card.
Bloom {
    property real lift: 4
    color: Theme.shadow
    spread: 16
    peak: 0.06
    layers: 8
    transform: Translate { y: parent ? Math.min(parent.height * 0.1, lift) : 0 }
}
