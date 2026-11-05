/*
    SPDX-FileCopyrightText: 2014-2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later

    Derivado do org.kde.desktopcontainment (Plasma 6) para o widget Cyber Fence: mesmas funções,
    com as cores do tema (Cores) no lugar das do Plasma. GPL-2.0-or-later, como o original.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.kirigami as Kirigami

import org.kde.private.desktopcontainment.folder as Folder
import "comum"

Item {
    id: main

    required property var model

    property int index:          model.index
    property string name:        model.blank ? "" : model.display
    property string nameWrapped: model.blank ? "" : model.displayWrapped
    property bool blank:         model.blank
    property bool selected:      model.blank ? false : model.selected
    property bool isDir:           loader.item ? loader.item.isDir : false
    property bool isOnRootView: false
    property /*FolderViewDialog*/ Folder.SubDialog popupDialog: loader.item ? loader.item.popupDialog    : null
    property Item iconArea:        loader.item ? loader.item.iconArea       : null
    property Item label:           loader.item ? loader.item.label          : null
    property Item labelArea:       loader.item ? loader.item.labelArea      : null
    property Item actionsOverlay:  loader.item ? loader.item.actionsOverlay : null
    property Item hoverArea:       loader.item ? loader.item.hoverArea      : null
    property Item frame:           loader.item ? loader.item.frame          : null
    property PlasmaCore.ToolTipArea toolTip:         loader.item ? loader.item.toolTip        : null
    property real contentHeight:   loader.item && !main.emLinha && !main.emCelula ? loader.item.contentHeight : null
    // layout da cerca (root.layoutCerca): "dados" é uma linha por item, "inventario" é uma célula sem nome.
    // Tudo aqui continua sendo o mesmo delegate do FolderView: seleção, arraste, renomear e menu não mudam.
    readonly property bool emDados: root.layoutCerca === "dados"
    readonly property bool emLinha: root.useListViewMode || emDados
    readonly property bool emCelula: root.layoutCerca === "inventario"
    // a etiqueta de tipo: a extensão em maiúsculas, ou DIR
    readonly property string etiqueta: {
        if (model.blank) return ""
        if (isDir) return "DIR"
        const n = String(model.display), i = n.lastIndexOf(".")
        return i > 0 && n.length - i <= 6 ? n.slice(i + 1).toUpperCase() : ""
    }
    // animação dos ícones (AnimIcones.qml): "ani" é null fora dela, e aí nada aqui custa ou muda
    readonly property var animIcones: GridView.view ? GridView.view.animIcones : null
    readonly property bool animLigada: !!animIcones && animIcones.ligado && !model.blank
    readonly property var ani: {
        if (!animLigada) return null
        const a = animIcones, g = main.GridView.view
        const dx = g.width / 2 - (main.x - g.contentX + main.width / 2)
        const dy = g.height / 2 - (main.y - g.contentY + g.iconSize / 2 + Kirigami.Units.smallSpacing)
        a.p; a.preparando
        return a.estado(main.index - a.primeira, dx, dy)
    }
    Accessible.name: name
    Accessible.role: Accessible.Canvas

    // This MouseArea exists to intercept press and hold; preventing edit mode
    // from being triggered when pressing and holding on an icon (if there is one).
    MouseArea {
        anchors.fill: parent
        visible: !main.blank
    }

    function openPopup() {
        if (isDir) {
            loader.item.openPopup();
        }
    }

    function closePopup() {
        if (popupDialog && popupDialog.allowClosing) {
            (popupDialog as FolderViewDialog).requestDestroy();
            loader.item.popupDialog = null;
        }
    }

    Loader {
        id: loader

        // On the desktop we pad our cellSize to avoid a gap at the right/bottom of the screen.
        // The padding per item is quite small and causes the delegate to be positioned on fractional pixels
        // leading to blurry rendering. The Loader is offset to account for this.
        x: -main.x % 1
        y: -main.y % 1
        width: parent.width
        height: parent.height

        visible: status === Loader.Ready

        active: !main.model.blank

        sourceComponent: delegateImplementation

        asynchronous: true
    }

    function updateDragImage() {
        if (selected && !blank) {
            loader.grabToImage(result => {
                dir.addItemDragImage(positioner.map(index), main.x + loader.x, main.y + loader.y, loader.width, loader.height, result.image);
            });
        }
    }

    Component {
        id: delegateImplementation

        Item {
            id: impl

            anchors.fill: parent

            property bool blank: main.model.blank
            property bool isDir: main.model.blank ? false : main.model.isDir
            property bool hovered: (main.GridView.view.hoveredItem === main)
            property /*FolderViewDialog*/ Folder.SubDialog popupDialog: null
            property Item iconArea: icon
            property Item label: label
            property Item labelArea: label
            property Item actionsOverlay: actions
            property Item hoverArea: toolTip
            property Item frame: frameLoader
            property alias toolTip: toolTip
            property Item selectionButton: selectionButtonComponent.createObject(actions) as FolderItemActionButton
            property Item popupButton: null
            property int contentHeight: frameLoader.height + frameLoader.y * 2

            readonly property bool iconAndLabelsShouldlookSelected: impl.hovered


            Connections {
                target: main.model

                function onSelectedChanged() {
                    if (dir.usedByContainment && main.model.selected) {
                        gridView.currentIndex = main.model.index;
                    }
                }
            }

            onHoveredChanged: {
                if (hovered) {
                    if (Plasmoid.configuration.selectionMarkers && root.umClique) {
                        selectionButton.visible = true;
                    }

                    if (main.model.isDir) {
                        if (!main.GridView.view.isRootView || root.containsDrag) {
                            hoverActivateTimer.restart();
                        }

                        if (Plasmoid.configuration.popups && !root.useListViewMode) {
                            popupButton = popupButtonComponent.createObject(actions);
                        }
                    }
                } else if (!hovered) {
                    if (popupDialog != null) {
                        main.closePopup();
                    }

                    selectionButton.visible = false;

                    if (popupButton) {
                        popupButton.destroy();
                        popupButton = null;
                    }
                }
            }

            function openPopup() {
                if (folderViewDialogComponent.status === Component.Ready) {
                    impl.popupDialog = folderViewDialogComponent.createObject(impl);
                    impl.popupDialog.visualParent = icon;
                    impl.popupDialog.url = Folder.DesktopSchemeHelper.getDesktopUrl(main.model.linkDestinationUrl);
                    impl.popupDialog.visible = true;
                }
            }

            PlasmaCore.ToolTipArea {
                id: toolTip
                anchors.fill: impl

                active: (Plasmoid.configuration.toolTips || label.truncated || label.cortado || main.emCelula)
                        && impl.popupDialog === null
                        && !main.model.blank
                interactive: false
                location: root.useListViewMode ? (Plasmoid.location === PlasmaCore.Types.LeftEdge ? PlasmaCore.Types.LeftEdge : PlasmaCore.Types.RightEdge) : Plasmoid.location

                onContainsMouseChanged:  {
                    if (containsMouse && !main.model.blank) {
                        if (toolTip.active) {
                            toolTip.icon = main.model.decoration;
                            toolTip.mainText = main.model.display;

                            if (main.model.size !== undefined) {
                                toolTip.subText = main.model.type + "\n" + main.model.size;
                            } else {
                                toolTip.subText = main.model.type;
                            }
                        }

                        Qt.callLater(() => {
                            // Workaround for Qt Bug: https://bugreports.qt.io/browse/QTBUG-117444
                            // In some cases the signal order is reversed:
                            // - first it's delivered to the new object with "true" value
                            // - next it's delivered to the old object with "false" value
                            // In this case when the signal is emitted with "false" (to the old object),
                            // it's also delivered to the "FolderView" which sets the "hoveredItem" to
                            // "null" right after we set it here.
                            // The solution is to call later and check again to make sure if we still contains
                            // mouse and next set the "hoveredItem". In this approach the "FolderView" sets the
                            // old "hoveredItem" to "null" and next we set it to the new item here.
                            if (containsMouse && !main.model.blank) {
                                main.GridView.view.hoveredItem = main;
                            }
                        })
                    }
                }

                states: [
                    State { // icon view
                        when: !main.emLinha

                        AnchorChanges {
                            target: toolTip
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        PropertyChanges {
                            toolTip.y: frameLoader.y + icon.y
                            toolTip.width: Math.max(icon.paintedWidth, label.paintedWidth)
                            toolTip.height: (label.y + label.paintedHeight) - y
                        }
                    },
                    State { // list view
                        when: main.emLinha

                        AnchorChanges {
                            target: toolTip
                            anchors.horizontalCenter: undefined
                        }

                        PropertyChanges {
                            toolTip.x: frameLoader.x
                            toolTip.y: frameLoader.y
                            toolTip.width: frameLoader.width
                            toolTip.height: frameLoader.height
                        }
                    }
                ]
            }

            // o nome na largura da célula: quebra em espaço, "_" ou "-", nunca dentro de uma palavra nem antes da
            // extensão; o que não couber é cortado no meio, mantendo o começo e a extensão
            function larg(s) { return main.GridView.view.medida.advanceWidth(s) }
            function noMeio(s, w) {
                if (larg(s) <= w) return s
                const i = s.lastIndexOf("."), ext = i > 0 && s.length - i <= 8 ? s.slice(i) : ""
                let ini = s.slice(0, s.length - ext.length)
                while (ini.length > 1 && larg(ini + "…" + ext) > w) ini = ini.slice(0, -1)
                return ini + "…" + ext
            }
            function nomeCabe(s, w, max) {
                if (w <= 0) return s                  // ainda sem largura: não corta nada
                if (max <= 1 || larg(s) <= w) return noMeio(s, w)
                // pedaços que terminam no separador; uma palavra que sozinha não cabe é partida onde couber
                const pedacos = []
                for (const p of (s.match(/[^ _-]+[ _-]*|[ _-]+/g) || [s])) {
                    let r = p
                    while (larg(r.trim()) > w && r.length > 1) {
                        let k = r.length - 1
                        while (k > 1 && larg(r.slice(0, k)) > w) k--
                        pedacos.push(r.slice(0, k)); r = r.slice(k)
                    }
                    pedacos.push(r)
                }
                const linhas = []
                let atual = ""
                for (const p of pedacos) {
                    if (atual && larg((atual + p).trim()) > w) { linhas.push(atual); atual = "" }
                    atual += p
                }
                if (atual) linhas.push(atual)
                if (linhas.length <= max) return linhas.map(l => l.trim()).join("\n")
                // não cabe: as primeiras linhas inteiras e, na última, o resto cortado no meio (com a extensão)
                const ini = linhas.slice(0, max - 1)
                const resto = s.slice(ini.join("").length)
                return ini.map(l => l.trim()).concat([noMeio(resto.trim(), w)]).join("\n")
            }

            // listras do layout dados e a célula chanfrada do inventário
            Rectangle { visible: main.emDados && main.index % 2 === 1; anchors.fill: parent; color: Cores.alfa(Cores.texto, 0.035) }
            Chanfro {
                visible: main.emCelula; x: 2; y: 2; width: parent.width - 4; height: parent.height - 4; corte: 7
                preenchimento: Cores.alfa(Cores.fundo, 0.45); borda: Cores.alfa(root.corCerca !== undefined ? root.corCerca : Cores.destaque, 0.35)
            }

            // explosão e quickhack: atrás do ícone, o fio até o centro e o cartão ou a retícula (anim/deco.frag)
            Loader {
                id: decoIcone
                active: !!main.ani && main.ani.c !== undefined
                x: frameLoader.x + icon.x; y: frameLoader.y + icon.y
                width: icon.width; height: icon.height
                sourceComponent: Item {
                    id: deco
                    readonly property var e: main.ani
                    readonly property real fx: e?.x ?? 0
                    readonly property real fy: e?.y ?? 0
                    readonly property Item anima: main.animIcones
                    readonly property Item grade: main.GridView.view
                    Rectangle {          // o fio: da posição do ícone até o centro da cerca
                        readonly property real ax: parent.width / 2 + parent.fx
                        readonly property real ay: parent.height / 2 + parent.fy
                        readonly property real bx: parent.width / 2 + deco.grade.width / 2 - (main.x - deco.grade.contentX + main.width / 2)
                        readonly property real by: parent.height / 2 + deco.grade.height / 2 - (main.y - deco.grade.contentY + deco.grade.iconSize / 2 + Kirigami.Units.smallSpacing)
                        x: ax; y: ay; height: 1
                        width: Math.hypot(bx - ax, by - ay)
                        rotation: Math.atan2(by - ay, bx - ax) * 180 / Math.PI
                        transformOrigin: Item.Left
                        color: parent.anima ? parent.anima.corCartao : "transparent"
                        opacity: (parent.e?.fio ?? 0) * 0.5
                        visible: opacity > 0.01
                    }
                    ShaderEffect {
                        id: quadDeco
                        readonly property real ico: deco.grade.iconSize
                        width: ico + 52; height: ico + 58
                        x: deco.width / 2 - width / 2 + deco.fx; y: deco.height / 2 - height / 2 + deco.fy
                        transform: Scale { origin.y: quadDeco.height / 2; yScale: deco.e?.sy ?? 1 }
                        readonly property bool retic: deco.e?.trava !== undefined
                        readonly property size tam: Qt.size(width, height)
                        readonly property size miolo: retic ? Qt.size(ico, ico) : Qt.size(ico + 10, ico + 16)
                        readonly property real modo: retic ? 1 : deco.anima ? deco.anima.modoDeco : 0
                        readonly property real fl: deco.e?.fl ?? 0
                        readonly property real rasgo: deco.e?.rasgo ?? 0
                        readonly property real trava: deco.e?.trava ?? 0
                        readonly property real barra: deco.e?.barra ?? 0
                        readonly property real semente: main.index % 97
                        readonly property real quadro: deco.e?.quadro ?? 0
                        readonly property color cor: deco.anima ? deco.anima.cor : "transparent"
                        readonly property color alerta: deco.anima ? deco.anima.corCartao : "transparent"
                        opacity: deco.e?.c ?? 0
                        visible: opacity > 0.01
                        fragmentShader: Qt.resolvedUrl("anim/deco.frag.qsb")
                    }
                }
            }
            Loader {
                id: frameLoader

                x: main.emLinha ? 0 : Kirigami.Units.smallSpacing
                y: main.emLinha ? 0 : Kirigami.Units.smallSpacing

                property Item iconShadow: null
                property string prefix: ""

                sourceComponent: frameComponent
                active: impl.iconAndLabelsShouldlookSelected || (main.model?.selected ?? false)
                asynchronous: true

                width: {
                    if (main.emLinha) {
                        if (main.GridView.view.overflowing) {
                            return parent.width - Kirigami.Units.smallSpacing;
                        } else {
                            return parent.width;
                        }
                    }

                    return parent.width - (Kirigami.Units.smallSpacing * 2);
                }

                height: main.emLinha || main.emCelula
                                ? parent.height - (main.emCelula ? Kirigami.Units.smallSpacing * 2 : 0)
                                // the smallSpacings are for padding
                                : icon.height + label.implicitHeight + (Kirigami.Units.smallSpacing * 3)

                Kirigami.Icon {
                    id: icon

                    z: 2

                    states: [
                        State { // icon view
                            when: !main.emLinha

                            AnchorChanges {
                                target: icon
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        },
                        State { // list view
                            when: main.emLinha

                            AnchorChanges {
                                target: icon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    ]

                    anchors {
                        topMargin: Kirigami.Units.smallSpacing
                        leftMargin: Kirigami.Units.smallSpacing
                    }

                    width: main.emLinha ? main.GridView.view.iconSize : (parent.width - 2 * Kirigami.Units.smallSpacing)
                    height: main.GridView.view.iconSize

                    opacity: {
                        if (main.emLinha && impl.selectionButton.visible) {
                            return 0.3;
                        }

                        return (main.model.isHidden ? 0.6 : 1.0) * (main.ani?.o ?? 1);
                    }

                    animated: false

                    source: main.model.decoration

                    transform: [
                        Scale { origin.y: icon.height / 2; yScale: main.ani?.sy ?? 1 },
                        Translate { x: main.ani?.x ?? 0; y: main.ani?.y ?? 0 }
                    ]
                    // efeitos em shader: só enquanto este ícone anima
                    layer.enabled: !!main.ani && main.ani.q !== undefined && main.animIcones.modoShader >= 0
                    layer.samplerName: "fonte"
                    // o rastro do sandevistan cabe na própria camada: mais largura, nenhum item a mais
                    layer.sourceRect: main.ani?.g !== undefined ? Qt.rect(-130, 0, icon.width + 260, icon.height) : Qt.rect(0, 0, 0, 0)
                    layer.effect: ShaderEffect {
                        readonly property size tam: main.ani?.g !== undefined ? Qt.size(icon.width + 260, icon.height) : Qt.size(icon.width, icon.height)
                        readonly property real margem: main.ani?.g !== undefined ? 130 : 0
                        vertexShader: Qt.resolvedUrl("anim/icone.vert.qsb")
                        readonly property vector3d gx: main.ani?.g ?? Qt.vector3d(0, 0, 0)
                        readonly property vector3d go: main.ani?.go ?? Qt.vector3d(0, 0, 0)
                        readonly property real q: main.ani?.q ?? 1
                        readonly property real q2: main.ani?.q2 ?? 1
                        readonly property real flash: main.ani?.flash ?? 0
                        readonly property real ab: main.ani?.ab ?? 0
                        readonly property real modo: main.animIcones ? main.animIcones.modoShader : 0
                        readonly property real semente: main.index % 97
                        readonly property color cor: main.animIcones ? main.animIcones.cor : "white"
                        readonly property color cor2: main.animIcones ? main.animIcones.cor2 : "white"
                        fragmentShader: Qt.resolvedUrl("anim/icone.frag.qsb")
                    }
                }

                PlasmaExtras.ShadowedLabel {
                    id: label

                    readonly property bool renaming: (editor && editor.targetItem === main)
                    // Quem limita as linhas é impl.nomeCabe. NÃO usar maximumLineCount aqui: mudá-lo pelo estado,
                    // com o Text ainda sem largura, derrubava o plasmashell (QTextLine::setLineWidth, nomes de 1 letra).
                    readonly property int linhasNome: main.emLinha ? 1 : main.GridView.view.linhasNome
                    onTextChanged: if (!main.emLinha && label.text !== "" && main.GridView.view) main.GridView.view.pedirLinhas(label.text.split("\n").length)
                    // o nome foi encurtado por impl.nomeCabe: a dica mostra o nome inteiro
                    readonly property bool cortado: text.indexOf("…") >= 0 && String(main.model.display).indexOf("…") < 0

                    z: 2 // So it's always above the highlight effect

                    states: [
                        State { // icon view
                            when: !main.emLinha

                            AnchorChanges {
                                target: label
                                anchors.top: icon.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            PropertyChanges {
                                label.anchors.topMargin: Kirigami.Units.smallSpacing
                                label.width: label.parent.width - Kirigami.Units.smallSpacing
                                label.horizontalAlignment: Text.AlignHCenter
                            }
                        },
                        State { // list view
                            when: main.emLinha

                            AnchorChanges {
                                target: label
                                anchors.left: icon.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            PropertyChanges {
                                label.anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                                label.anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                                label.width: label.parent.width - icon.width - (Kirigami.Units.smallSpacing * 4) - colunas.width
                                label.horizontalAlignment: Text.AlignLeft
                            }
                        }
                    ]

                    color: {
                        if (main.isOnRootView) {
                            // In this situation there's a shadow or a background rect, both of which are always black
                            return "white";
                        }

                        return Cores.texto;   // nome de arquivo: fonte do sistema, cor de texto do tema

                    }
                    visible: !renaming && !main.emCelula
                    renderShadow: main.isOnRootView && !renaming
                    opacity: (main.model.isHidden ? 0.6 : 1) * (main.ani?.ol ?? 1)
                    // o nome acende por colunas no lugar: a letra não muda nem anda (texto de leitura não treme)
                    layer.enabled: main.ani?.dec !== undefined && main.ani.dec < 1
                    layer.samplerName: "fonte"
                    layer.effect: ShaderEffect {
                        readonly property size tam: Qt.size(label.width, label.height)
                        readonly property real q: main.ani?.dec ?? 1
                        readonly property real margem: 0
                        readonly property real q2: 1
                        readonly property real flash: 0
                        readonly property real ab: 0
                        readonly property vector3d gx: Qt.vector3d(0, 0, 0)
                        readonly property vector3d go: Qt.vector3d(0, 0, 0)
                        readonly property real modo: 10
                        readonly property real semente: main.index % 97
                        readonly property color cor: "transparent"
                        readonly property color cor2: "transparent"
                        fragmentShader: Qt.resolvedUrl("anim/icone.frag.qsb")
                    }

                    // nunca parte palavra nem extensão: ver impl.nomeCabe
                    text: main.model.blank ? "" : impl.nomeCabe(String(main.model.display), label.width - 2, label.linhasNome)
                    font.italic: (main.model?.isLink ?? false)
                    wrapMode: Text.NoWrap
                    elide: Text.ElideNone
                    horizontalAlignment: Text.AlignHCenter
                }

                // etiqueta de tipo sobre o ícone (na grade e no inventário)
                Rectangle {
                    z: 3
                    visible: !main.emLinha && main.etiqueta !== ""
                    opacity: main.ani?.ol ?? 1
                    readonly property real lado: Math.min(icon.width, main.GridView.view.iconSize)
                    x: icon.x + (icon.width + lado) / 2 - width + 3; y: icon.y + icon.height - height + 1
                    width: tEtiqueta.implicitWidth + 6; height: 13
                    color: Cores.alfa(Cores.escuro, 0.88)
                    border.color: Cores.alfa(root.corCerca !== undefined ? root.corCerca : Cores.destaque, 0.7)
                    Text { id: tEtiqueta; anchors.centerIn: parent; text: main.etiqueta; font.family: Cores.fMono; font.pixelSize: 9; color: Cores.texto }
                }
                // colunas de tipo e tamanho (layout dados)
                Row {
                    id: colunas
                    z: 2
                    visible: main.emDados
                    opacity: main.ani?.ol ?? 1
                    readonly property bool cabeTudo: frameLoader.width >= 220
                    width: visible ? (cabeTudo ? 96 : 40) : 0
                    anchors.right: parent.right; anchors.rightMargin: main.emDados ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: 40; text: main.etiqueta
                        font.family: Cores.fMono; font.pixelSize: 10; color: Cores.texto2
                    }
                    Text {
                        visible: colunas.cabeTudo
                        width: 56; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                        text: main.model.blank ? "" : String(main.model.size || "")
                        font.family: Cores.fMono; font.pixelSize: 10; color: Cores.texto2
                    }
                }

                Component {
                    id: frameComponent

                    // hover só tonal; seleção é persistente, mais forte e com marcador; foco do teclado, anel na
                    // secundária
                    Item {
                        // Workaround for a bug where the frameComponent does not
                        // get unloaded when items are dragged to a different
                        // place on the desktop.
                        visible: this === frameLoader.item
                        readonly property bool sel: main.model.selected
                        readonly property bool foco: main.GridView.isCurrentItem && main.GridView.view.activeFocus
                        readonly property color corF: root.corCerca !== undefined ? root.corCerca : Cores.destaque
                        Chanfro {
                            anchors.fill: parent
                            corte: main.emLinha ? 0 : 6
                            preenchimento: Cores.alfa(parent.corF, parent.sel ? 0.22 : 0.10)
                            borda: parent.foco ? Cores.secundaria : "transparent"
                        }
                        Rectangle { visible: parent.sel; width: 3; height: parent.height; color: parent.corF }
                    }
                }

                Component {
                    id: selectionButtonComponent

                    FolderItemActionButton {
                        element: main.model.selected ? "remove" : "add"

                        onClicked: {
                            dir.toggleSelected(positioner.map(main.index));
                            main.GridView.view.currentIndex = main.index;
                        }
                    }
                }

                Component {
                    id: popupButtonComponent

                    FolderItemActionButton {
                        visible: main.GridView.view.isRootView && (impl.popupDialog == null)

                        element: "open"

                        onClicked: {
                            dir.setSelected(positioner.map(main.index));
                            main.GridView.view.currentIndex = main.index;
                            main.openPopup();
                        }
                    }
                }

                Component {
                    id: iconShadowComponent

                    DropShadow {
                        anchors.fill: icon

                        z: 1

                        verticalOffset: 1

                        radius: 5.0
                        samples: radius * 2 + 1
                        spread: 0.05

                        color: "black"

                        opacity: main.model.isHidden ? 0.3 : 0.6

                        source: icon
                    }
                }
            }

            Column {
                id: actions

                visible: {
                    if (main.GridView.view.isRootView && root.containsDrag) {
                        return false;
                    }

                    if (!main.GridView.view.isRootView && main.GridView.view.dialog && main.GridView.view.dialog.containsDrag) {
                        return false;
                    }

                    if (main.popupDialog) {
                        return false;
                    }

                    return true;
                }

                anchors {
                    left: frameLoader.left
                    top: frameLoader.top
                    leftMargin: main.emLinha ? (icon.x + (icon.width / 2)) - (width / 2) : 0
                    topMargin: main.emLinha ? (icon.y + (icon.height / 2)) - (height / 2) : 0
                }

                width: implicitWidth
                height: implicitHeight
            }

            Component.onCompleted: {
                selectionButton.visible = false;
                if (Plasmoid.isContainment && main.GridView.view.isRootView && root.GraphicsInfo.api === GraphicsInfo.OpenGL) {
                    frameLoader.iconShadow = iconShadowComponent.createObject(frameLoader);
                }
            }
        }
    }
}
