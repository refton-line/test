import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import CClicker

Item {
    id: panel
    property var engine
    property var store

    property string selectedId: ""
    property string selectedName: ""
    property bool selectedValid: false
    Label {
        text: qsTr("Конфигурации")
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }
    Row {
        anchors.right: parent.right
        spacing: 8
        ActionButton {
            objectName: "importConfig"
            text: qsTr("Импорт")
            glyph: "download"
            onClicked: importDialog.open()
        }
        ActionButton {
            objectName: "saveConfig"
            text: qsTr("Сохранить как")
            glyph: "plus"
            primary: true
            onClicked: {
                nameDialog.renaming = false;
                profileName.text = "";
                nameDialog.open();
            }
        }
    }
    TextField {
        id: query
        objectName: "configSearch"
        y: 64
        width: parent.width
        height: 44
        leftPadding: 44
        color: Theme.ink
        font.family: Theme.sans
        font.pixelSize: 14
        placeholderText: qsTr("Найти конфигурацию")
        placeholderTextColor: Theme.muted
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentInk
        onTextEdited: {
            panel.store.searchQuery = text;
            panel.selectedId = "";
            panel.selectedName = "";
            panel.selectedValid = false;
        }
        background: Rectangle {
            radius: Theme.radius
            color: Theme.surface
            border.color: query.activeFocus ? Theme.focus : Theme.controlBorder
        }
        Icon {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            width: 18
            height: 18
        }
    }
    Component.onCompleted: {
        panel.store.searchQuery = "";
        panel.store.refresh();
    }

    ListView {
        id: list
        objectName: "configList"
        y: 128
        width: parent.width
        height: 276
        clip: true
        spacing: 4
        model: panel.store.profiles
        delegate: Button {
            id: profile
            required property var modelData
            width: list.width
            height: 76
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            objectName: "profile_" + modelData.id
            Accessible.name: modelData.name
            onClicked: {
                panel.selectedId = modelData.id;
                panel.selectedName = modelData.name;
                panel.selectedValid = modelData.valid;
            }
            background: Rectangle {
                radius: 8
                color: profile.modelData.id === panel.selectedId ? Theme.surfaceRaised : profile.hovered ? Theme.surface : Theme.workspace
                border.width: profile.visualFocus ? 2 : 0
                border.color: profile.visualFocus ? Theme.focus : Theme.clear
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Rectangle {
                    x: 0; anchors.verticalCenter: parent.verticalCenter
                    width: 3; radius: 1; color: Theme.brand
                    height: profile.modelData.id === panel.selectedId ? 24 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                }
            }
            contentItem: Item {
                Icon {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "layers"
                    width: 22
                    height: 22
                }
                Column {
                    x: 56
                    width: parent.width - 180
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Label {
                        width: parent.width
                        text: profile.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        text: profile.modelData.summary
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Theme.muted
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: !profile.modelData.valid ? qsTr("Ошибка JSON") : profile.modelData.active ? qsTr("Применён") : ""
                    font.pixelSize: 12
                    color: Theme.muted
                }
            }
        }
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }
    Column {
        visible: panel.store.profiles.length === 0
        anchors.centerIn: list
        spacing: 12
        Icon {
            name: "folder"
            width: 32
            height: 32
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Label {
            text: panel.store.searchQuery !== "" ? qsTr("Ничего не найдено") : qsTr("Профилей пока нет")
            font.pixelSize: 16; font.weight: Font.DemiBold
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Label {
            text: panel.store.searchQuery !== "" ? qsTr("Попробуйте другое название.") : qsTr("Сохраните текущие параметры или импортируйте JSON.")
            font.pixelSize: 14; color: Theme.muted
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    Rectangle {
        y: 420
        width: parent.width
        height: 1
        color: Theme.hairline
    }
    Row {
        y: 440
        spacing: 8
        ActionButton {
            objectName: "applyConfig"
            text: qsTr("Применить")
            glyph: "check"
            outlined: true
            enabled: panel.selectedId !== "" && panel.selectedValid && !panel.engine.active
            onClicked: panel.store.apply(panel.selectedId)
        }
        ActionButton {
            objectName: "exportConfig"
            text: qsTr("Экспорт")
            glyph: "upload"
            enabled: panel.selectedId !== "" && panel.selectedValid
            onClicked: exportDialog.open()
        }
        ActionButton {
            objectName: "renameConfig"
            text: qsTr("Название")
            glyph: "edit"
            enabled: panel.selectedId !== "" && panel.selectedValid
            onClicked: {
                nameDialog.renaming = true;
                profileName.text = panel.selectedName;
                nameDialog.open();
            }
        }
        ActionButton {
            objectName: "duplicateConfig"
            text: qsTr("Копия")
            glyph: "copy"
            enabled: panel.selectedId !== "" && panel.selectedValid
            onClicked: panel.store.duplicate(panel.selectedId)
        }
        ActionButton {
            objectName: "deleteConfig"
            text: qsTr("Удалить")
            glyph: "trash"
            enabled: panel.selectedId !== ""
            onClicked: deleteDialog.open()
        }
    }
    Label {
        y: 504
        width: parent.width
        visible: panel.store.failed
        text: panel.store.notice
        font.pixelSize: 13
        color: panel.store.failed ? Theme.ink : Theme.muted
        wrapMode: Text.WordWrap
    }
    FileDialog {
        id: importDialog
        title: qsTr("Импорт конфигурации")
        nameFilters: [qsTr("Конфигурация JSON (*.json)")]
        onAccepted: panel.store.importFile(selectedFile)
    }
    FileDialog {
        id: exportDialog
        title: qsTr("Экспорт конфигурации")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [qsTr("Конфигурация JSON (*.json)")]
        onAccepted: panel.store.exportFile(panel.selectedId, selectedFile)
    }
    Popup {
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit; easing.type: Easing.InCubic } NumberAnimation { property: "scale"; to: 0.98; duration: Theme.dialogExit; easing.type: Easing.InCubic } } }
        id: nameDialog
        objectName: "configNameDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        height: 252
        modal: true
        focus: true
        padding: 24
        property bool renaming: false
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLarge
            border.color: Theme.hairline
        }
        onOpened: profileName.forceActiveFocus()
        Column {
            width: parent.width
            spacing: 24
            Label {
                text: nameDialog.renaming ? qsTr("Название конфигурации") : qsTr("Сохранить конфигурацию")
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            TextField {
                id: profileName
                objectName: "profileNameField"
                Accessible.name: qsTr("Название конфигурации")
                width: parent.width
                height: 48
                maximumLength: 64
                placeholderText: qsTr("Например, рабочий профиль")
                placeholderTextColor: Theme.muted
                font.family: Theme.sans
                font.pixelSize: 15
                color: Theme.ink
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentInk
                background: Rectangle {
                    color: Theme.canvas
                    radius: 8
                    border.color: profileName.activeFocus ? Theme.focus : Theme.controlBorder
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                ActionButton {
                    text: qsTr("Отмена")
                    onClicked: nameDialog.close()
                }
                ActionButton {
                    objectName: "confirmSaveConfig"
                    text: qsTr("Сохранить")
                    primary: true
                    enabled: profileName.text.trim().length > 0
                    onClicked: {
                        const ok = nameDialog.renaming ? panel.store.rename(panel.selectedId, profileName.text) : panel.store.saveNew(profileName.text);
                        if (ok)
                            nameDialog.close();
                    }
                }
            }
        }
    }
    Popup {
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dialogEnter; easing.type: Easing.OutCubic } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: Theme.dialogExit; easing.type: Easing.InCubic } NumberAnimation { property: "scale"; to: 0.98; duration: Theme.dialogExit; easing.type: Easing.InCubic } } }
        id: deleteDialog
        objectName: "deleteConfigDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        height: 252
        modal: true
        focus: true
        padding: 24
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLarge
            border.color: Theme.hairline
        }
        Column {
            width: parent.width
            spacing: 24
            Label {
                text: qsTr("Удалить JSON-файл?")
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            Label {
                text: panel.selectedName
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: 15
                color: Theme.muted
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                ActionButton {
                    text: qsTr("Отмена")
                    onClicked: deleteDialog.close()
                }
                ActionButton {
                    objectName: "confirmDeleteConfig"
                    text: qsTr("Удалить")
                    glyph: "trash"
                    onClicked: {
                        if (panel.store.remove(panel.selectedId)) {
                            panel.selectedId = "";
                            panel.selectedName = "";
                            panel.selectedValid = false;
                            deleteDialog.close();
                        }
                    }
                }
            }
        }
    }
}
