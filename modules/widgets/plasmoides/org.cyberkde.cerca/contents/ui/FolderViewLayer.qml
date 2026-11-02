/*
    SPDX-FileCopyrightText: 2014-2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later

    Derivado do org.kde.desktopcontainment (Plasma 6) para o widget Cyber Fence: mesmas funções,
    com as cores do tema (Cores) no lugar das do Plasma. GPL-2.0-or-later, como o original.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQml

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.config // for KAuthorized
import org.kde.kirigami as Kirigami

import org.kde.private.desktopcontainment.folder as Folder

FocusScope {
    id: folderViewLayerComponent

    // these need to be passed in from main, but required properties with Loaders are awkward
    /*required*/ property bool isPopup
    /*required*/ property bool useListViewMode

    property var sharedActions: ["newMenu", "paste", "undo", "emptyTrash"]
    property Component folderViewDialogComponent: Qt.createComponent("FolderViewDialog.qml", Qt.Asynchronous, root)

    property FolderView view: folderView
    property Item label: null
    readonly property string rotuloPasta: labelGenerator.displayLabel   // título padrão da cerca

    property alias model: folderView.model
    property alias overflowing: folderView.overflowing
    property alias flow: folderView.flow

    readonly property bool lockedByKiosk: !KAuthorized.authorize("editable_desktop_icons")

    focus: true

    function updateContextualActions() {
        folderView.model.updateActions();

        for (let i = 0, len = sharedActions.length; i < len; i++) {
            const actionName = sharedActions[i];
            const appletAction = Plasmoid.internalAction(actionName);
            if (appletAction) {
                modelAction = folderView.model.action(actionName);
                appletAction.text = modelAction.text;
                appletAction.enabled = modelAction.enabled;
                appletAction.visible = modelAction.visible;
            }
        }
    }

    function cancelRename() {
        folderView.cancelRename();
    }

    function goHome() {
        if (folderView.url !== root.pastaUrl) {
            folderView.url = Qt.binding(() => root.pastaUrl);
            folderView.history = [];
            folderView.historyChanged();
        }
    }

    Binding {
        target: Plasmoid
        property: "title"
        value: root.tituloCerca
        restoreMode: Binding.RestoreBinding
    }

    Folder.LabelGenerator {
        id: labelGenerator

        folderModel: folderView.model
        rtl: (Application.layoutDirection === Qt.RightToLeft)
        labelMode: 1
    }

    Folder.ViewPropertiesMenu {
        id: viewPropertiesMenu

        showLayoutActions: !folderViewLayerComponent.isPopup
        showLockAction: Plasmoid.isContainment
        showIconSizeActions: !folderViewLayerComponent.useListViewMode

        lockedEnabled: !folderViewLayerComponent.lockedByKiosk

        onArrangementChanged: {
            Plasmoid.configuration.arrangement = arrangement;
        }

        onAlignmentChanged: {
            Plasmoid.configuration.alignment = alignment;
        }

        onPreviewsChanged: {
            Plasmoid.configuration.previews = previews;
        }

        onLockedChanged: {
            if (!folderViewLayerComponent.lockedByKiosk) {
                Plasmoid.configuration.locked = locked;
            }
        }

        onSortModeChanged: {
            Plasmoid.configuration.sortMode = sortMode;
        }

        onSortDescChanged: {
            Plasmoid.configuration.sortDesc = sortDesc;
        }

        onSortDirsFirstChanged: {
            Plasmoid.configuration.sortDirsFirst = sortDirsFirst;
        }

        onIconSizeChanged: {
            Plasmoid.configuration.iconSize = iconSize;
        }

        Component.onCompleted: {
            arrangement = Plasmoid.configuration.arrangement;
            alignment = Plasmoid.configuration.alignment;
            previews = Plasmoid.configuration.previews;
            locked = Plasmoid.configuration.locked || folderViewLayerComponent.lockedByKiosk;
            sortMode = Plasmoid.configuration.sortMode;
            sortDesc = Plasmoid.configuration.sortDesc;
            sortDirsFirst = Plasmoid.configuration.sortDirsFirst;
            iconSize = Plasmoid.configuration.iconSize;
        }
    }

    PlasmaComponents.Label {
        anchors.fill: parent

        text: folderView.errorString
        textFormat: Text.PlainText

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }

    Connections {
        target: root

        function onExpandedChanged() {
            if (folderViewLayerComponent.isPopup) {
                if (root.expanded) {
                    folderView.currentIndex = -1;
                    folderView.forceActiveFocus();
                    folderView.positionViewAtBeginning();
                } else {
                    folderViewLayerComponent.goHome();

                    folderView.currentIndex = -1;
                    folderView.model.clearSelection();
                    folderView.cancelRename();
                }
            }
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onArrangementChanged() {
            viewPropertiesMenu.arrangement = Plasmoid.configuration.arrangement;
        }

        function onAlignmentChanged() {
            viewPropertiesMenu.alignment = Plasmoid.configuration.alignment;
        }

        function onLockedChanged() {
            viewPropertiesMenu.locked = Plasmoid.configuration.locked;
        }

        function onSortModeChanged() {
            folderView.sortMode = Plasmoid.configuration.sortMode;
            viewPropertiesMenu.sortMode = Plasmoid.configuration.sortMode;
        }

        function onSortDescChanged() {
            viewPropertiesMenu.sortDesc = Plasmoid.configuration.sortDesc;
        }

        function onSortDirsFirstChanged() {
            viewPropertiesMenu.sortDirsFirst = Plasmoid.configuration.sortDirsFirst;
        }

        function onIconSizeChanged() {
            viewPropertiesMenu.iconSize = Plasmoid.configuration.iconSize;
        }
    }

    FolderView {
        id: folderView

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: folderViewLayerComponent.label !== null ? folderViewLayerComponent.label.height : 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        focus: true
        isRootView: Plasmoid.isContainment
        positionerApplet: Plasmoid

        url: root.pastaUrl   // pasta comum por file:// (desktop:/ não lança nem acompanha, ver main.qml)
        locked: (Plasmoid.configuration.locked || !Plasmoid.isContainment || folderViewLayerComponent.lockedByKiosk)
        filterMode: root.mimesFiltro.length ? 1 : Plasmoid.configuration.filterMode
        filterPattern: root.mimesFiltro.length ? "*" : Plasmoid.configuration.filterPattern
        filterMimeTypes: root.mimesFiltro.length ? root.mimesFiltro : Plasmoid.configuration.filterMimeTypes
        showHiddenFiles: Plasmoid.configuration.showHiddenFiles

        flow: (Plasmoid.configuration.arrangement === 0) ? GridView.FlowLeftToRight : GridView.FlowTopToBottom
        layoutDirection: (Plasmoid.configuration.alignment === 0) ? Qt.LeftToRight : Qt.RightToLeft

        onSortModeChanged: {
            Plasmoid.configuration.sortMode = sortMode;
        }

        Component.onCompleted: {
            folderView.sortMode = Plasmoid.configuration.sortMode;
        }
    }

    PlasmaCore.Action {
        id: viewPropertiesAction
        text: i18ndc("plasma_applet_org.kde.desktopcontainment", "@item:inmenu opens submenu with view options like sorting", "Icons")
        icon.name: "view-list-icons"
        menu: viewPropertiesMenu.menu
    }
    PlasmaCore.Action {
        id: actionSeparator
        isSeparator: true
    }

    Component.onCompleted: {
        for (let i = 0, len = sharedActions.length; i < len; i++) {
            const actionName = sharedActions[i];
            const modelAction = folderView.model.action(actionName);
            Plasmoid.contextualActions.push(modelAction)
            if (actionName === "emptyTrash") {
                Plasmoid.contextualActions.push(viewPropertiesAction)
            }
        }

        Plasmoid.contextualActions.push(actionSeparator);

        Plasmoid.contextualActionsAboutToShow.connect(updateContextualActions);
        Plasmoid.contextualActionsAboutToShow.connect(folderView.model.clearSelection);
    }
}
