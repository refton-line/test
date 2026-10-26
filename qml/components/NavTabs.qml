import QtQuick
import QtQuick.Controls
import CClicker
import "Motion.js" as Motion

// Primary navigation as tabs in the title bar. One pill slides between tabs and
// carries a short light under it in the current mode's hue; its leading edge runs
// ahead of the trailing one, so the light stretches in the direction of travel.
Item {
    id: nav
    property var labels: []
    property var glyphs: []
    property int current: 0
    property color hue: Theme.brand
    // Opening cascade, provided by Main: reveal(i) in 0..1 per tab.
    property var reveal: function(i) { return 1; }
    property real textPhase: 1
    property real textShift: 0
    signal picked(int index)
    implicitWidth: row.implicitWidth
    implicitHeight: 40

    property real pillX: 0
    property real pillW: 0
    property real glowL: 0
    property real glowR: 0
    function target(i) { return tabs.count > i ? tabs.itemAt(i) : null; }
    function place(animated) {
        const t = target(current);
        if (!t) return;
        const x = row.x + t.x, w = t.width;
        if (!animated) {
            move.stop();
            pillX = x; pillW = w; glowL = x + 14; glowR = x + w - 14;
            return;
        }
        const forward = x > pillX;
        pillMoveX.to = x; pillMoveW.to = w;
        glowMoveL.to = x + 14; glowMoveR.to = x + w - 14;
        glowMoveL.duration = forward ? Theme.railTravel : Theme.railTravel * 0.55;
        glowMoveR.duration = forward ? Theme.railTravel * 0.55 : Theme.railTravel;
        move.restart();
    }
    onCurrentChanged: place(true)
    onWidthChanged: place(false)
    Connections { target: row; function onImplicitWidthChanged() { nav.place(false); } }
    ParallelAnimation {
        id: move
        NumberAnimation { id: pillMoveX; target: nav; property: "pillX"; duration: Theme.railTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve }
        NumberAnimation { id: pillMoveW; target: nav; property: "pillW"; duration: Theme.railTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve }
        NumberAnimation { id: glowMoveL; target: nav; property: "glowL"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
        NumberAnimation { id: glowMoveR; target: nav; property: "glowR"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }

    Rectangle {
        objectName: "tabPill"
        x: nav.pillX; y: 0
        width: nav.pillW; height: nav.height
        radius: Theme.radius
        color: Theme.surfaceRaised
        opacity: nav.reveal(nav.current)
        Rim { inset: Theme.radius }
    }
    Item {
        objectName: "tabGlow"
        x: nav.glowL; y: nav.height - 2
        width: Math.max(0, nav.glowR - nav.glowL); height: 2
        opacity: nav.reveal(nav.current)
        Bloom { anchors.fill: parent; radius: 1; color: nav.hue; spread: 7; peak: 0.3 }
        Rectangle { anchors.fill: parent; radius: 1; color: nav.hue }
    }
    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        onPositioningComplete: nav.place(false)
        Repeater {
            id: tabs
            model: nav.labels
            ActionButton {
                required property int index
                required property string modelData
                objectName: "nav" + index
                height: nav.height
                navigation: true
                quiet: true
                fillChecked: false
                centered: true
                text: modelData
                textSize: 13
                glyph: nav.glyphs[index] || ""
                checked: nav.current === index
                opacity: nav.reveal(index)
                transform: Translate { y: -8 * (1 - nav.reveal(index)) }
                contentOpacity: nav.textPhase
                contentShift: nav.textShift
                onClicked: nav.picked(index)
            }
        }
    }
}
