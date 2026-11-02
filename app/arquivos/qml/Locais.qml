import QtQuick
import "../../qml"

// Barra de Locais (200 px): LOCAIS (HOME, XDG, favoritos), DISPOSITIVOS (uso em barra; não montado
// esmaecido), RECENTES, LIXEIRA. Clique abre; soltar arquivos num local/dispositivo montado copia ou
// move para lá; botão direito: montar/desmontar, tirar dos locais, esvaziar a lixeira.
// Teclado (F6 chega aqui): ↑/↓ andam, Enter abre, Menu abre o menu do local; anel secundário no foco.
Item {
    id: l
    readonly property string atual: arquivos.aba ? arquivos.aba.caminho : ""
    // lista plana do que é navegável pelo teclado: {secao, item, chave}
    readonly property var plano: {
        let p = []
        for (const sc of arquivos.locais || []) {
            if (sc.secao === "lixeira") p.push({ secao: "lixeira", item: { caminho: "lixeira:" }, chave: "lixeira" })
            for (const it of sc.itens || []) p.push({ secao: sc.secao, item: it, chave: sc.secao + "|" + (it.caminho || "") + "|" + (it.dispositivo || "") })
        }
        return p
    }
    property int cursor: -1
    readonly property bool focado: teclas.activeFocus
    function chaveDe(secao, it) { return secao === "lixeira" && !it ? "lixeira" : secao + "|" + (it.caminho || "") + "|" + (it.dispositivo || "") }
    function focar() {
        if (cursor < 0 || cursor >= plano.length) cursor = Math.max(0, plano.findIndex(p => p.item.caminho && p.item.caminho === atual))
        teclas.forceActiveFocus()
    }
    function ativar(p) {
        if (!p) return
        const it = p.item
        if (p.secao === "lixeira") arquivos.aba.irPara("lixeira:")
        else if (p.secao === "dispositivos" && !it.montado) arquivos.montar(it.dispositivo)
        else if (p.secao === "recentes") arquivos.aba.irPara(it.caminho.substring(0, it.caminho.lastIndexOf("/")))
        else arquivos.aba.irPara(it.caminho)
    }
    Item {
        id: teclas
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Down) { l.cursor = Math.min(l.plano.length - 1, l.cursor + 1); e.accepted = true }
            else if (e.key === Qt.Key_Up) { l.cursor = Math.max(0, l.cursor - 1); e.accepted = true }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { l.ativar(l.plano[l.cursor]); e.accepted = true }
            else if (e.key === Qt.Key_Menu) { const p = l.plano[l.cursor]; if (p) { if (p.secao === "lixeira") Ds.janela.menuLixeira(Qt.point(l.width, 200)); else Ds.janela.menuLocal(p.item, p.secao, Qt.point(l.width, 200)) } e.accepted = true }
            else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Right) { Ds.janela.focarArea(); e.accepted = true }
        }
    }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.alfa(Tema.destaque, 0.3) }
    Flickable {
        anchors.fill: parent; anchors.rightMargin: 1
        contentHeight: col.implicitHeight + 20
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            x: 10; y: 10
            width: l.width - 20
            spacing: 14
            Repeater {
                model: arquivos.locais
                Column {
                    id: sec
                    required property var modelData
                    width: col.width
                    spacing: 3
                    Item {
                        width: parent.width; height: 18
                        Rotulo { text: sec.modelData.titulo; tamanho: 12; color: Tema.destaque; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { x: 90; width: parent.width - 90; height: 1; color: Tema.alfa(Tema.destaque, 0.3); anchors.verticalCenter: parent.verticalCenter }
                        // a seção inteira (recentes, lixeira) é clicável
                        MouseArea {
                            anchors.fill: parent
                            enabled: !!sec.modelData.caminho
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (e) => {
                                if (e.button === Qt.RightButton && sec.modelData.secao === "lixeira") Ds.janela.menuLixeira(mapToItem(null, e.x, e.y))
                                else arquivos.aba.irPara(sec.modelData.caminho)
                            }
                        }
                    }
                    // lixeira: uma linha só
                    Item {
                        visible: sec.modelData.secao === "lixeira"
                        width: parent.width; height: 24
                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Tema.secundaria; visible: l.focado && l.plano[l.cursor] && l.plano[l.cursor].chave === "lixeira"; z: 2 }
                        Rectangle { anchors.fill: parent; color: soltaLx.containsDrag ? Tema.alfa(Tema.alerta, 0.35) : l.atual === "lixeira:" ? Tema.selecao : (mlx.containsMouse ? Tema.hover : "transparent"); border.width: soltaLx.containsDrag ? 1 : 0; border.color: Tema.alerta }
                        // lixeira: na cor de alerta quando tem itens
                        Icone {
                            x: 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16
                            fonte: "image://icone/" + (sec.modelData.cheia ? "user-trash-full" : "user-trash")
                            cor: sec.modelData.cheia ? Tema.alerta : Tema.destaque
                            colorir: 0.9
                            brilho: l.atual === "lixeira:" || mlx.containsMouse ? 0.35 : 0.08
                        }
                        Text { x: 30; anchors.verticalCenter: parent.verticalCenter; text: Ds.en ? "Trash" : "Lixeira"; font.family: Tema.fTexto; font.pixelSize: 13; color: sec.modelData.cheia ? Tema.alerta : Tema.texto }
                        Text { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: sec.modelData.quantidade || 0; font.family: Tema.fMono; font.pixelSize: 11; color: sec.modelData.cheia ? Tema.alerta : Tema.texto3 }
                        MouseArea {
                            id: mlx; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                            onClicked: (e) => { if (e.button === Qt.RightButton) Ds.janela.menuLixeira(mapToItem(null, e.x, e.y)); else arquivos.aba.irPara("lixeira:") }
                        }
                        DropArea { id: soltaLx; anchors.fill: parent; keys: ["text/uri-list"]; onDropped: (d) => Ds.janela.soltarNaLixeira(d) }
                        Text { visible: soltaLx.containsDrag; anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter; text: Ds.t("soltar.lixeira"); font.family: Tema.fMono; font.pixelSize: 9; font.bold: true; color: Tema.alerta }
                    }
                    Repeater {
                        model: sec.modelData.itens || []
                        Item {
                            id: it
                            required property var modelData
                            readonly property bool ehDisp: sec.modelData.secao === "dispositivos"
                            readonly property bool montado: !ehDisp || modelData.montado
                            readonly property bool sel: it.modelData.caminho !== "" && l.atual === it.modelData.caminho
                            width: sec.width; height: ehDisp ? 42 : 24
                            opacity: montado ? 1 : 0.55
                            Rectangle { anchors.fill: parent; color: alvo.sobre ? Tema.alfa(Tema.destaque, 0.3) : it.sel ? Tema.selecao : (mi.containsMouse ? Tema.hover : "transparent") }
                            Rectangle { visible: it.sel; width: 3; height: parent.height; color: Tema.destaque }
                            // anel do foco do teclado
                            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Tema.secundaria; z: 2
                                        visible: l.focado && !!l.plano[l.cursor] && l.plano[l.cursor].chave === l.chaveDe(sec.modelData.secao, it.modelData) }
                            // ícones coloridos: locais e discos na cor da corporação (como as pastas do tema),
                            // os recentes com as cores do próprio tipo; ativo/hover acende
                            Icone {
                                x: 8; y: 4; width: 16; height: 16
                                fonte: "image://icone/" + it.modelData.icone
                                cor: Tema.destaque
                                colorir: sec.modelData.secao === "recentes" ? 0 : 0.9
                                brilho: it.sel || mi.containsMouse ? 0.35 : 0.08
                            }
                            Text {
                                x: 30; y: 3; width: parent.width - 36
                                text: it.modelData.nome; elide: Text.ElideRight
                                font.family: Tema.fTexto; font.pixelSize: 13
                                color: it.sel ? Tema.texto : Tema.texto2
                            }
                            // dispositivo: livre + barra de uso
                            Text {
                                visible: it.ehDisp
                                x: 30; y: 19; width: parent.width - 36; elide: Text.ElideRight
                                text: it.montado ? Ds.t("local.livre", { v: it.modelData.livreTexto }) + " · " + it.modelData.sistema : Ds.t("local.naoMontado")
                                font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2
                            }
                            BarraSegmentada {
                                visible: it.ehDisp && it.montado
                                x: 30; y: 36; width: parent.width - 36; height: 3
                                valor: it.modelData.uso || 0
                                larguraSeg: 4; vao: 1
                                cor: (it.modelData.uso || 0) > 0.9 ? Tema.alerta : Tema.destaque
                            }
                            MouseArea {
                                id: mi
                                anchors.fill: parent; hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (e) => {
                                    if (e.button === Qt.RightButton) Ds.janela.menuLocal(it.modelData, sec.modelData.secao, mapToItem(null, e.x, e.y))
                                    else if (e.button === Qt.MiddleButton) { if (it.modelData.caminho) arquivos.novaAba(it.modelData.caminho) }
                                    else if (it.ehDisp && !it.montado) arquivos.montar(it.modelData.dispositivo)
                                    else if (sec.modelData.secao === "recentes") arquivos.aba.irPara(it.modelData.caminho.substring(0, it.modelData.caminho.lastIndexOf("/")))
                                    else arquivos.aba.irPara(it.modelData.caminho)
                                }
                            }
                            AlvoSoltar { id: alvo; anchors.fill: parent; destino: it.montado && sec.modelData.secao !== "recentes" ? (it.modelData.caminho || "") : "" }
                        }
                    }
                }
            }
        }
    }
}
