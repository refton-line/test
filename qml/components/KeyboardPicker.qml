import QtQuick
import QtQuick.Controls
import CClicker
import "Motion.js" as Motion
import "KeyboardMap.js" as KeyMap

Popup {
    id: picker
    objectName: "keyboardPicker"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 1040 * uiScale
    height: 556 * uiScale
    padding: 0
    modal: true
    focus: true
    property var engine

    property real uiScale: 1
    readonly property bool combination: engine.captureCombination
    readonly property var chosenKeys: engine.draftKeys
    property int targetBinding: 0
    property int bindingIndex: 0
    function edit(target, slot = 0) {
        if (engine.active) return;
        targetBinding = target; bindingIndex = slot;
        const list = target === 0 ? engine.startBindings : engine.stopBindings;
        const keys = slot < list.length ? list[slot].keys : [];
        engine.setBindingEditor(true);
        engine.beginBindingDraft(keys, keys.length > 1);
        open();
    }
    function choose(key) { engine.selectDraftKey(key); }
    closePolicy: Popup.CloseOnPressOutside
    onClosed: engine.setBindingEditor(false)
    background: Rectangle {
        color: Theme.canvas
        radius: 14
        border.color: Theme.controlBorder
    }
    enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.pageFade; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.dialogEnter; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standardCurve } } }
    exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve } NumberAnimation { property: "scale"; to: 0.97; duration: Theme.dialogExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.accelerateCurve } } }
    contentItem: Item {
        Item {
            width: 1040; height: 556
            scale: picker.uiScale
            transformOrigin: Item.TopLeft
            focus: true
        Label {
            x: 24
            y: 22
            text: qsTr("Назначение клавиши")
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
        ActionButton {
            x: 972
            y: 12
            implicitWidth: 44
            text: ""
            glyph: "x"
            quiet: true
            Accessible.name: qsTr("Закрыть клавиатуру")
            onClicked: picker.close()
        }
        Row {
            x: 620; y: 66; spacing: 8
            ActionButton {
                objectName: "singleMode"
                text: qsTr("Одна клавиша")
                segmented: true; checked: !picker.combination
                onClicked: picker.engine.captureCombination = false
            }
            ActionButton {
                objectName: "combinationMode"
                text: qsTr("Сочетание")
                segmented: true; checked: picker.combination
                onClicked: picker.engine.captureCombination = true
            }
        }
        Row {
            x: 24; y: 66; spacing: 8
            Label {
                height: 44; width: 72
                text: picker.targetBinding === 0 ? qsTr("Запуск") : qsTr("Стоп")
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
            Repeater {
                model: picker.chosenKeys
                ActionButton {
                    required property int modelData
                    objectName: "draftChip" + modelData
                    text: picker.engine.keyName(modelData)
                    checked: true
                    // Each captured key lands as a chip with a small spring.
                    property bool landed: false
                    Component.onCompleted: landed = true
                    scale: !landed ? 0.6 : down ? 0.965 : 1
                    onClicked: picker.choose(modelData)
                    Accessible.name: (picker.combination ? qsTr("Убрать %1") : qsTr("Выбрать %1")).arg(text)
                }
            }
            Label {
                height: 44
                text: picker.chosenKeys.length ? "" : qsTr("Выберите клавиши")
                color: Theme.muted
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
        }
        Item {
            x: 14
            y: 146
            width: 1012
            height: 278
            Repeater {
                model: KeyMap.keys
                Button {
                    id: keycap
                    required property var modelData
                    objectName: "keycap" + modelData.v
                    x: modelData.x * 44
                    y: modelData.y * 44
                    width: modelData.u * 44
                    height: modelData.h * 44
                    readonly property bool selected: picker.chosenKeys.indexOf(modelData.v) !== -1
                    readonly property bool pressedPhysical: picker.engine.pressedKeys.indexOf(modelData.v) !== -1
                    readonly property bool numpadDigit: (modelData.v >= 96 && modelData.v <= 105) || modelData.v === 110
                    enabled: picker.engine.keyAllowed(modelData.v) && (!numpadDigit || picker.engine.numLockOn)
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: modelData.t
                    onClicked: picker.choose(modelData.v)
                    background: Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.radiusSmall
                        border.width: keycap.visualFocus ? 2 : 1
                        border.color: keycap.visualFocus ? Theme.focus : keycap.selected ? Theme.brand : keycap.enabled ? Theme.controlBorder : Theme.hairline
                        color: keycap.pressedPhysical ? Theme.accent : keycap.selected ? Theme.accentSoft : keycap.hovered && keycap.enabled ? Theme.surfaceHover : Theme.workspace
                        Behavior on color { ColorAnimation { duration: Theme.keyFeedback } }
                    }
                    Rectangle {
                        visible: keycap.modelData.v === 144
                        width: 5; height: 3; radius: 1
                        x: (parent.width - width) / 2; y: parent.height - 8
                        color: picker.engine.numLockOn ? Theme.brand : Theme.hairline
                    }
                    contentItem: Label {
                        text: keycap.modelData.t
                        font.pixelSize: 12
                        font.family: Theme.mono
                        color: keycap.pressedPhysical ? Theme.accentInk : keycap.enabled ? Theme.ink : Theme.edge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        Label {
            x: 24
            y: 444
            width: 980
            elide: Text.ElideRight
            text: picker.engine.draftError
            font.pixelSize: 12
            color: Theme.muted
        }
        Rectangle {
            x: 24
            y: 476
            width: 992
            height: 1
            color: Theme.hairline
        }
        ActionButton {
            x: 24
            y: 492
            text: qsTr("По умолчанию")
            glyph: "undo"

            onClicked: {
                picker.engine.beginBindingDraft([picker.targetBinding === 0 ? 117 : 119], false);
            }
        }
        ActionButton {
            objectName: "cancelKeyboard"
            x: 744
            y: 492
            width: 128
            text: qsTr("Отмена")
            onClicked: picker.close()

        }
        ActionButton {
            objectName: "applyKeyboard"
            x: 884
            y: 492
            width: 132
            text: qsTr("Применить")
            primary: true
            enabled: picker.chosenKeys.length > 0
            onClicked: {
                if (picker.engine.applyChordSlot(picker.targetBinding === 1, picker.bindingIndex, picker.chosenKeys))
                    picker.close();
            }
        }
        }
    }
}
