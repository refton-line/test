import QtQuick
import QtQuick.Controls
import QtQuick.Window
import CClicker
import "components"

ApplicationWindow {
    id: win
    objectName: "mainWindow"
    visible: true
    title: "C clicker"
    width: Theme.baseWidth * initialScale
    height: Theme.baseHeight * initialScale
    minimumWidth: Theme.baseWidth * initialScale
    minimumHeight: Theme.baseHeight * initialScale
    color: Theme.clear
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint | Qt.WindowSystemMenuHint
    readonly property real initialScale: uiCapture ? 1 : Math.min(1, (Screen.desktopAvailableWidth - 32) / Theme.baseWidth, (Screen.desktopAvailableHeight - 32) / Theme.baseHeight)
    readonly property real uiScale: Math.min(1, width / Theme.baseWidth, height / Theme.baseHeight)
    readonly property bool fullScreen: visibility === Window.FullScreen
    readonly property bool maximized: visibility === Window.Maximized

    property real expansion: 0
    property real dismissal: 1
    property bool minimumElapsed: false
    property bool opening: false
    property bool exiting: false
    property bool allowClose: false
    property int selectedPage: 0
    property real pagePhase: 1
    property real languagePhase: 1
    property int displayedPage: 0
    property int pageDirection: 1
    property bool pageLeaving: false
    property int beforeFullscreen: Window.Windowed
    readonly property real panelWidth: Theme.splashWidth + (width / uiScale - Theme.splashWidth) * expansion
    readonly property real panelHeight: Theme.splashHeight + (height / uiScale - Theme.splashHeight) * expansion
    readonly property real entrance: Math.max(0, (expansion - 0.78) / 0.22)

    function reveal() {
        if (startup.done && minimumElapsed && !opening && !exiting) {
            opening = true;
            morph.start();
        }
    }
    function toggleFullscreen() {
        if (exiting || expansion < 1) return;
        if (fullScreen) {
            if (beforeFullscreen === Window.Maximized) showMaximized();
            else showNormal();
        } else {
            beforeFullscreen = visibility;
            showFullScreen();
        }
    }
    function toggleMaximized() {
        if (fullScreen || exiting || expansion < 1) return;
        if (maximized) showNormal(); else showMaximized();
    }
    function requestClose() { close(); }
    onClosing: function(event) {
        // Stop immediately, before the exit animation. Alt+F4 uses this same path.
        clickEngine.setReady(false);
        clickEngine.stop();
        if (allowClose) { event.accepted = true; return; }
        event.accepted = false;
        if (!exiting) {
            exiting = true;
            morph.stop();
            exitAnimation.start();
        }
    }
    function switchLanguage(code) {
        if (code === i18n.language || languageSwitch.running) return;
        languageSwitch.code = code;
        languageSwitch.start();
    }
    function changePage() {
        if (pageTransition.running || selectedPage === displayedPage) return;
        pageDirection = selectedPage > displayedPage ? 1 : -1;
        pageTransition.start();
    }
    onSelectedPageChanged: changePage()
    onExpansionChanged: if (expansion === 1) clickEngine.setReady(true)
    Component.onCompleted: { startup.start(); minimum.start(); }
    Connections { target: startup; function onChanged() { win.reveal(); } }
    Shortcut { sequence: "F11"; enabled: win.expansion === 1 && !keyPicker.visible && !clickEngine.startBindings.some(b => b.keys.indexOf(122) !== -1) && !clickEngine.stopBindings.some(b => b.keys.indexOf(122) !== -1); onActivated: win.toggleFullscreen() }
    Shortcut { sequence: "Escape"; enabled: win.fullScreen && !keyPicker.visible; onActivated: win.toggleFullscreen() }
    Timer { id: minimum; interval: Theme.reveal; onTriggered: { win.minimumElapsed = true; win.reveal(); } }
    NumberAnimation { id: morph; target: win; property: "expansion"; to: 1; duration: Theme.reveal; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: pageTransition
        onFinished: win.changePage()
        ScriptAction { script: win.pageLeaving = true }
        NumberAnimation { target: win; property: "pagePhase"; to: 0; duration: Theme.pageExit; easing.type: Easing.InCubic }
        ScriptAction { script: { win.displayedPage = win.selectedPage; win.pageLeaving = false; } }
        NumberAnimation { target: win; property: "pagePhase"; to: 1; duration: Theme.pageEnter; easing.type: Easing.OutCubic }
    }
    // Fade the whole interface out, swap the catalogue while invisible, fade back in.
    SequentialAnimation {
        id: languageSwitch
        property string code
        NumberAnimation { target: win; property: "languagePhase"; to: 0; duration: Theme.languageOut; easing.type: Easing.InCubic }
        ScriptAction { script: i18n.setLanguage(languageSwitch.code) }
        NumberAnimation { target: win; property: "languagePhase"; to: 1; duration: Theme.languageIn; easing.type: Easing.OutCubic }
    }
    // Closing mirrors the opening: the shell folds back into the startup card,
    // the C returns to the centre, then everything fades.
    SequentialAnimation {
        id: exitAnimation
        onFinished: { win.allowClose = true; win.close(); }
        NumberAnimation { target: win; property: "expansion"; to: 0; duration: Theme.exitMorph; easing.type: Easing.InOutCubic }
        NumberAnimation { target: win; property: "dismissal"; to: 0; duration: Theme.exitDuration; easing.type: Easing.InCubic }
    }
    KeyboardPicker { id: keyPicker; engine: clickEngine; uiScale: win.uiScale }

    Item {
        id: scene
        width: win.width / win.uiScale
        height: win.height / win.uiScale
        anchors.centerIn: parent
        scale: win.uiScale * (0.985 + 0.015 * win.dismissal)
        opacity: win.dismissal
        enabled: !win.exiting
        Rectangle {
            id: chassis
            anchors.centerIn: parent
            width: win.panelWidth
            height: win.panelHeight
            readonly property bool edgeToEdge: (win.fullScreen || win.maximized) && !win.exiting
            radius: edgeToEdge ? 0 : Theme.radiusLarge
            color: Theme.workspace
            border.color: edgeToEdge ? Theme.clear : Theme.hairline
            // Rectangular clipping only. Backgrounds respect the outer inset;
            // no glowing Canvas textures can bleed outside the rounded shell.
            clip: true
            Item {
                anchors.fill: parent
                anchors.margins: 1
                visible: win.entrance > 0
                opacity: win.entrance * win.languagePhase
                enabled: win.expansion === 1
                Rectangle {
                    x: 0; y: 0
                    width: Theme.railWidth; height: parent.height
                    radius: win.fullScreen || win.maximized ? 0 : Theme.radiusLarge - 1
                    color: Theme.rail
                    Rectangle { anchors.right: parent.right; width: Theme.radiusLarge; height: parent.height; color: Theme.rail }
                }
                // Titlebar is a separate drag target, never laid over interactive controls.
                Item {
                    x: Theme.railWidth; y: 0
                    width: parent.width - x; height: 64
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: if (!win.fullScreen) win.startSystemMove()
                        onDoubleClicked: win.toggleMaximized()
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        ActionButton { text: ""; glyph: "minus"; quiet: true; width: 44; Accessible.name: qsTr("Свернуть"); onClicked: win.showMinimized() }
                        ActionButton { objectName: "maximizeButton"; text: ""; glyph: win.maximized ? "restore" : "maximize"; quiet: true; width: 44; Accessible.name: win.maximized ? qsTr("Восстановить окно") : qsTr("Развернуть окно"); enabled: !win.fullScreen; onClicked: win.toggleMaximized() }
                        ActionButton { objectName: "fullscreenButton"; text: ""; glyph: win.fullScreen ? "minimize" : "fullscreen"; quiet: true; width: 44; Accessible.name: win.fullScreen ? qsTr("Выйти из полного экрана") : qsTr("Полный экран"); onClicked: win.toggleFullscreen() }
                        ActionButton { objectName: "closeButton"; text: ""; glyph: "x"; quiet: true; width: 44; Accessible.name: qsTr("Закрыть"); onClicked: win.requestClose() }
                    }
                }
                Column {
                    x: 12; y: 100; spacing: 8
                    Repeater {
                        model: [qsTr("Кликер"), qsTr("Журнал"), qsTr("Управление"), qsTr("Конфигурации"), qsTr("Язык")]
                        ActionButton {
                            required property int index
                            required property string modelData
                            objectName: "nav" + index
                            width: Theme.railWidth - 24; height: 48
                            navigation: true; quiet: true
                            text: modelData; textSize: 13
                            glyph: ["mouse", "activity", "keyboard", "folder", "globe"][index]
                            checked: win.selectedPage === index
                            onClicked: win.selectedPage = index
                        }
                    }
                }
                Column {
                    x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 26; spacing: 8
                    ActionButton { objectName: "openConfigFolder"; text: qsTr("Файлы"); glyph: "folder"; quiet: true; Accessible.name: qsTr("Открыть папку конфигураций"); onClicked: configs.openFolder() }
                }
                Item {
                    id: workArea
                    enabled: !pageTransition.running
                    width: Math.min(1120, parent.width - Theme.railWidth - 2 * Theme.gutter)
                    x: Theme.railWidth + (parent.width - Theme.railWidth - width) / 2
                    y: Math.max(100, (parent.height - 548 - 48) / 2)
                    height: parent.height - y - Theme.gutter
                    // Content grows horizontally but never becomes an oversized scaled bitmap.
                    SettingsPanel {
                        x: (win.pageLeaving ? -1 : 1) * win.pageDirection * Theme.pageTravel * (1 - win.pagePhase)
                        y: 0
                        width: parent.width - 312; height: 548
                        opacity: win.pagePhase
                        engine: clickEngine
                        visible: win.displayedPage === 0
                    }
                    LiveMetrics {
                        x: parent.width - 240
                        y: 24
                        width: 216; height: 500
                        opacity: win.pagePhase
                        engine: clickEngine
                        visible: win.displayedPage === 0
                    }
                    Loader {
                        id: page
                        x: (win.pageLeaving ? -1 : 1) * win.pageDirection * Theme.pageTravel * (1 - win.pagePhase)
                        y: 0
                        width: parent.width; height: parent.height
                        opacity: win.pagePhase
                        active: win.displayedPage !== 0
                        sourceComponent: [null, sessionPage, preferencesPage, configPage, languagePage][win.displayedPage]
                    }
                    Component { id: sessionPage; SessionPanel { engine: clickEngine} }
                    Component { id: preferencesPage; PreferencesPanel { engine: clickEngine; keyboard: keyPicker } }
                    Component { id: configPage; ConfigPanel { engine: clickEngine; store: configs} }
                    Component { id: languagePage; LanguagePanel { language: i18n; onPick: code => win.switchLanguage(code) } }
                }
                Rectangle {
                    x: Theme.railWidth + Theme.gutter
                    objectName: "generalError"
                    id: errorBanner
                    // Keep the last message while fading out after the error clears.
                    readonly property bool shown: clickEngine.error !== "" && !keyPicker.visible
                    property string message
                    Connections { target: clickEngine; function onChanged() { if (clickEngine.error !== "") errorBanner.message = clickEngine.error } }
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: shown ? 32 : 20
                    width: parent.width - x - Theme.gutter
                    height: Math.max(52, errorText.implicitHeight + 24)
                    color: Theme.surface; radius: Theme.radius
                    border.color: Theme.danger
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: errorBanner.shown ? Theme.dialogEnter : Theme.dialogExit; easing.type: Easing.OutCubic } }
                    Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Label {
                        id: errorText
                        anchors.left: parent.left; anchors.right: dismissErrorButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12; anchors.rightMargin: 8
                        text: errorBanner.message; font.pixelSize: 13
                        color: Theme.danger; wrapMode: Text.WordWrap
                    }
                    ActionButton {
                        id: dismissErrorButton
                        objectName: "dismissError"
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 4
                        width: 44; height: 44
                        glyph: "x"; quiet: true
                        Accessible.name: qsTr("Закрыть сообщение об ошибке")
                        onClicked: clickEngine.dismissError()
                    }
                }
            }
            BootStage {
                anchors.fill: parent
                progress: startup.progress; ready: startup.done
                opacity: Math.max(0, 1 - win.expansion / 0.25)
                visible: opacity > 0 && startup.error === "" && !win.exiting
            }
            Rectangle {
                anchors.fill: parent; anchors.margins: 24
                visible: startup.error !== ""; color: Theme.workspace
                Column {
                    anchors.centerIn: parent; width: parent.width; spacing: 16
                    Label { text: qsTr("Не удалось открыть приложение"); font.pixelSize: 18; font.weight: Font.DemiBold; width: parent.width; wrapMode: Text.WordWrap }
                    Label { text: startup.error; font.pixelSize: 14; color: Theme.muted; width: parent.width; wrapMode: Text.WordWrap }
                    ActionButton { text: qsTr("Повторить"); primary: true; onClicked: startup.start() }
                }
            }
            ActionButton {
                visible: win.expansion < 0.45 && !win.exiting
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                text: ""; glyph: "x"; quiet: true; width: 44; Accessible.name: qsTr("Закрыть")
                onClicked: win.requestClose()
            }
        }
        CMark {
            readonly property real dock: Math.max(0, Math.min(1, (win.expansion - 0.10) / 0.90))
            width: 112 - 84 * dock; height: width
            x: (scene.width - width)/2 * (1-dock) + 20*dock
            y: ((scene.height - Theme.splashHeight)/2 + 48)*(1-dock) + 20*dock
            visible: startup.error === ""

        }
    }
}
