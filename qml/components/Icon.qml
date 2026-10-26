import QtQuick
import QtQuick.Controls.impl as Impl
import CClicker

Item {
    id: icon
    property string name: "cursor"
    property bool dark: false
    property color foreground: dark ? Theme.accentInk : Theme.ink
    Accessible.ignored: true
    Impl.IconImage {
        anchors.fill: parent
        source: icon.name === "" ? "" : "qrc:/qt/qml/CClicker/assets/" + icon.name + ".svg"
        color: icon.foreground
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
