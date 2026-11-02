/*
    SPDX-FileCopyrightText: 2014-2017 Eike Hein <hein@kde.org>

    Área de soltar do fullRepresentation do Folder View (main.qml do org.kde.desktopcontainment), para o
    Cyber Fence: arquivo solto entra na pasta; arraste em cima de uma cerca recolhida a abre.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.private.desktopcontainment.folder as Folder

FolderViewDropArea {
    id: area
    preventStealing: true

    onDragMove: event => {
        root._ctrlArraste = !!(event.modifiers & Qt.ControlModifier);
        root.arrasteEm(area, event.x, event.y);
    }
    onDragEnter: event => {
        root._ctrlArraste = !!(event.modifiers & Qt.ControlModifier);
        // Don't allow any drops while listing.
        if (folderView && folderView.status === Folder.FolderModel.Listing) {
            event.ignore();
        }

        // Firefox tabs are regular drags. Since all of our drop handling is asynchronous
        // we would accept this drop and have Firefox not spawn a new window. (Bug 337711)
        if (event.mimeData.formats.indexOf("application/x-moz-tabbrowser-tab") !== -1) {
            event.ignore();
        }
        root.containsDrag = true;
        if (root.rolada) {
            root.abrir();
        }
    }
    onDragLeave: { root.containsDrag = false; root.arrasteFora(); }
    onDrop: { root.containsDrag = false; root.arrasteFora(); }
}
