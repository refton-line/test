import QtQuick
import QtQuick.Controls
import QtQuick.Window
import CClicker
import "components"
import "components/Motion.js" as Motion

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
    property real languageShift: 0
    property int beforeFullscreen: Window.Windowed
    // Opening and closing share one linear timeline, `expansion` (0 = startup card,
    // 1 = full window). Each element eases its own window of it, so the sequence is
    // choreographed rather than simultaneous, and closing replays it backwards:
    // content leaves first, then the shell folds while the C rides its corner home.
    readonly property real shell: Motion.standard(Motion.seg(expansion, 0.04, 0.72))
    readonly property real railReveal: Motion.decelerate(Motion.seg(expansion, 0.3, 0.7))
    readonly property real chromeReveal: Motion.decelerate(Motion.seg(expansion, 0.62, 0.92))
    readonly property real contentReveal: Motion.decelerate(Motion.seg(expansion, 0.6, 1))
    function navReveal(i) { return Motion.decelerate(Motion.seg(expansion, 0.48 + 0.04 * i, 0.78 + 0.04 * i)); }
    readonly property real panelWidth: Theme.splashWidth + (width / uiScale - Theme.splashWidth) * shell
    readonly property real panelHeight: Theme.splashHeight + (height / uiScale - Theme.splashHeight) * shell
    // Selection pill and its crimson edge marker in the rail.
    function navY(i) { return 100 + i * 56; }
    property real railPillY: navY(0)
    property real markerTop: navY(0) + 15
    property real markerBottom: navY(0) + 33

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
            // A close during opening only has to undo what was shown.
            exitFold.duration = Math.max(1, Theme.closeTimeline * expansion);
            exitPause.duration = Math.max(0, exitFold.duration - 140);
            exitAnimation.start();
        }
    }
    function switchLanguage(code) {
        if (code === i18n.language || languageSwitch.running) return;
        languageSwitch.code = code;
        languageSwitch.start();
    }
    // Pages share a vertical axis that follows the rail: going down the list, the
    // new page rises from below while the old one lifts away, overlapping.
    onSelectedPageChanged: {
        const from = displayedPage, to = selectedPage;
        if (from === to) return;
        const direction = to > from ? 1 : -1;
        displayedPage = to;
        const pages = [page0, page1, page2, page3, page4];
        pages[from].leave(direction);
        pages[to].enter(direction);
        pillMove.to = navY(to);
        markerTopMove.to = navY(to) + 15;
        markerBottomMove.to = navY(to) + 33;
        // The leading edge runs ahead and the trailing edge catches up, so the
        // marker stretches in the direction of travel and settles back to 18px.
        markerTopMove.duration = direction > 0 ? Theme.railTravel : Theme.railTravel * 0.55;
        markerBottomMove.duration = direction > 0 ? Theme.railTravel * 0.55 : Theme.railTravel;
        railMove.restart();
    }
    onExpansionChanged: if (expansion === 1) clickEngine.setReady(true)
    Component.onCompleted: { startup.start(); minimum.start(); }
    Connections { target: startup; function onChanged() { win.reveal(); } }
    Shortcut { sequence: "F11"; enabled: win.expansion === 1 && !keyPicker.visible && !clickEngine.startBindings.some(b => b.keys.indexOf(122) !== -1) && !clickEngine.stopBindings.some(b => b.keys.indexOf(122) !== -1); onActivated: win.toggleFullscreen() }
    Shortcut { sequence: "Escape"; enabled: win.fullScreen && !keyPicker.visible; onActivated: win.toggleFullscreen() }
    Timer { id: minimum; interval: Theme.reveal; onTriggered: { win.minimumElapsed = true; win.reveal(); } }
    // Linear on purpose: every consumer applies its own curve to its window.
    NumberAnimation { id: morph; target: win; property: "expansion"; to: 1; duration: Theme.openTimeline; easing.type: Easing.Linear }
    ParallelAnimation {
        id: railMove
        NumberAnimation { id: pillMove; target: win; property: "railPillY"; duration: Theme.railTravel; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve }
        NumberAnimation { id: markerTopMove; target: win; property: "markerTop"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
        NumberAnimation { id: markerBottomMove; target: win; property: "markerBottom"; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
    }
    // Only the words refresh: text lifts out, the catalogue swaps while it is
    // invisible, and the new text settles in. Shell, rail and pill stay put.
    SequentialAnimation {
        id: languageSwitch
        property string code
        ParallelAnimation {
            NumberAnimation { target: win; property: "languagePhase"; to: 0; duration: Theme.languageOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve }
            NumberAnimation { target: win; property: "languageShift"; to: -4; duration: Theme.languageOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve }
        }
        ScriptAction { script: { i18n.setLanguage(languageSwitch.code); win.languageShift = 6; } }
        ParallelAnimation {
            NumberAnimation { target: win; property: "languagePhase"; to: 1; duration: Theme.languageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
            NumberAnimation { target: win; property: "languageShift"; to: 0; duration: Theme.languageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
        }
    }
    // The opening timeline runs backwards; near its end the card dissolves while
    // the C un-draws, overlapping instead of waiting for the fold to finish.
    ParallelAnimation {
        id: exitAnimation
        onFinished: { win.allowClose = true; win.close(); }
        NumberAnimation { id: exitFold; target: win; property: "expansion"; to: 0; duration: Theme.closeTimeline; easing.type: Easing.Linear }
        SequentialAnimation {
            PauseAnimation { id: exitPause; duration: Theme.closeTimeline - 140 }
            NumberAnimation { target: win; property: "dismissal"; to: 0; duration: Theme.closeFade; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve }
        }
    }
    KeyboardPicker { id: keyPicker; engine: clickEngine; uiScale: win.uiScale }

    Item {
        id: scene
        width: win.width / win.uiScale
        height: win.height / win.uiScale
        anchors.centerIn: parent
        scale: win.uiScale * (0.96 + 0.04 * win.dismissal)
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
                visible: win.expansion > 0.25
                enabled: win.expansion === 1
                Rectangle {
                    opacity: win.railReveal
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
                        opacity: win.chromeReveal
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        ActionButton { text: ""; glyph: "minus"; quiet: true; width: 44; Accessible.name: qsTr("Свернуть"); onClicked: win.showMinimized() }
                        ActionButton { objectName: "maximizeButton"; text: ""; glyph: win.maximized ? "restore" : "maximize"; quiet: true; width: 44; Accessible.name: win.maximized ? qsTr("Восстановить окно") : qsTr("Развернуть окно"); enabled: !win.fullScreen; onClicked: win.toggleMaximized() }
                        ActionButton { objectName: "fullscreenButton"; text: ""; glyph: win.fullScreen ? "minimize" : "fullscreen"; quiet: true; width: 44; Accessible.name: win.fullScreen ? qsTr("Выйти из полного экрана") : qsTr("Полный экран"); onClicked: win.toggleFullscreen() }
                        ActionButton { objectName: "closeButton"; text: ""; glyph: "x"; quiet: true; width: 44; Accessible.name: qsTr("Закрыть"); onClicked: win.requestClose() }
                    }
                }
                Rectangle {
                    objectName: "railPill"
                    x: 12; y: win.railPillY
                    width: Theme.railWidth - 24; height: 48
                    radius: Theme.radius
                    color: Theme.surfaceRaised
                    opacity: win.navReveal(win.displayedPage)
                }
                Rectangle {
                    objectName: "railMarker"
                    x: 12; y: win.markerTop
                    width: 3; height: win.markerBottom - win.markerTop
                    radius: 1.5
                    color: Theme.brand
                    opacity: win.navReveal(win.displayedPage)
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
                            navigation: true; quiet: true; fillChecked: false
                            opacity: win.navReveal(index) * win.languagePhase
                            transform: Translate { x: -12 * (1 - win.navReveal(index)); y: win.languageShift }
                            text: modelData; textSize: 13
                            glyph: ["mouse", "activity", "keyboard", "folder", "globe"][index]
                            checked: win.selectedPage === index
                            onClicked: win.selectedPage = index
                        }
                    }
                }
                Column {
                    opacity: win.navReveal(5) * win.languagePhase
                    x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 26; spacing: 8
                    ActionButton { objectName: "openConfigFolder"; text: qsTr("Файлы"); glyph: "folder"; quiet: true; Accessible.name: qsTr("Открыть папку конфигураций"); onClicked: configs.openFolder() }
                }
                Item {
                    id: workArea
                    objectName: "workArea"
                    width: Math.min(1120, parent.width - Theme.railWidth - 2 * Theme.gutter)
                    x: Theme.railWidth + (parent.width - Theme.railWidth - width) / 2
                    y: Math.max(100, (parent.height - 548 - 48) / 2)
                    height: parent.height - y - Theme.gutter
                    opacity: win.contentReveal * win.languagePhase
                    transform: Translate { y: 14 * (1 - win.contentReveal) + win.languageShift }
                    // Content grows horizontally but never becomes an oversized scaled bitmap.
                    // The clicker page is a direct child so its state and objects persist.
                    Stage {
                        id: page0
                        objectName: "page0"
                        width: workArea.width; height: workArea.height
                        current: win.displayedPage === 0
                        onOpacityChanged: if (current) win.pagePhase = opacity
                        SettingsPanel { width: parent.width - 312; height: 548; engine: clickEngine }
                        LiveMetrics { x: parent.width - 240; y: 24; width: 216; height: 500; engine: clickEngine }
                    }
                    component LoadedPage: Stage {
                        id: loaded
                        property int index
                        property Component page
                        objectName: "page" + index
                        width: workArea.width; height: workArea.height
                        current: win.displayedPage === index
                        onOpacityChanged: if (current) win.pagePhase = opacity
                        Loader { anchors.fill: parent; active: loaded.current || loaded.visible; sourceComponent: loaded.page }
                    }
                    LoadedPage { id: page1; index: 1; page: sessionPage }
                    LoadedPage { id: page2; index: 2; page: preferencesPage }
                    LoadedPage { id: page3; index: 3; page: configPage }
                    LoadedPage { id: page4; index: 4; page: languagePage }
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
                    property real lift: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32
                    width: parent.width - x - Theme.gutter
                    height: Math.max(52, errorText.implicitHeight + 24)
                    color: Theme.surface; radius: Theme.radius
                    border.color: Theme.danger
                    opacity: 0
                    visible: opacity > 0
                    transform: Translate { y: errorBanner.lift }
                    states: State { name: "shown"; when: errorBanner.shown; PropertyChanges { errorBanner.opacity: 1; errorBanner.lift: 0 } }
                    transitions: [
                        Transition {
                            to: "shown"
                            NumberAnimation { property: "opacity"; duration: Theme.pageFade; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "lift"; duration: Theme.pageIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.decelerateCurve }
                        },
                        Transition {
                            from: "shown"
                            NumberAnimation { properties: "opacity,lift"; duration: Theme.pageOut + 20; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve }
                        }
                    ]
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
                opacity: 1 - Motion.accelerate(Motion.seg(win.expansion, 0, 0.2))
                transform: Translate { y: -10 * Motion.seg(win.expansion, 0, 0.2) }
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
            objectName: "cmark"
            // Glued to the shell: centred in the card, then carried to the corner.
            readonly property real dock: win.shell
            width: 112 - 84 * dock; height: width
            x: (scene.width - win.panelWidth) / 2 + (win.panelWidth - width) / 2 * (1 - dock) + 20 * dock
            y: (scene.height - win.panelHeight) / 2 + 48 * (1 - dock) + 20 * dock
            erase: 1 - win.dismissal
            visible: startup.error === ""

        }
    }
}
