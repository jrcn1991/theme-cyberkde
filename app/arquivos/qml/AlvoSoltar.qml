import QtQuick
import "../../qml"

// Área onde se pode soltar arquivos (pasta, pilha, painel-subpasta, tile, linha, aba, migalha, local,
// área vazia). Aceita text/uri-list de dentro e de FORA (Dolphin, navegador, área de trabalho).
// Recusa soltar um item nele mesmo ou na pasta onde ele já está. Com algo por cima, acende (sobre) e
// mostra a etiqueta da ação: MOVER (Shift), COPIAR (Ctrl), LINK (Ctrl+Shift) ou "MOVER / COPIAR ▾"
// (sem modificador: ao soltar abre o menu Mover aqui / Copiar aqui / Criar link / Cancelar, como no
// Dolphin). A decisão fica no Main (Ds.janela.soltarEm).
DropArea {
    id: a
    property string destino: ""
    property bool etiqueta: true             // mostrar a etiqueta da ação
    property bool etiquetaNoTopo: false      // áreas grandes (fundo da visão): etiqueta no alto
    property bool etiquetaEmbaixo: false     // células de pilha: embaixo, longe da dica do painel
    readonly property bool sobre: containsDrag && destino !== "" && _valido
    property bool _valido: true
    property string acao: ""                 // "mover" | "copiar" | "link" | "menu"
    signal moveu(real x, real y)
    keys: ["text/uri-list"]

    function _checar(d) {
        const l = Ds.janela.caminhosDe(d)
        return destino !== "" && l.length > 0 && !l.some(c => c === destino || c.substring(0, c.lastIndexOf("/")) === destino || destino.startsWith(c + "/"))
    }
    onEntered: (d) => { _valido = _checar(d); acao = Ds.janela.acaoDoDrop(d); if (!_valido) d.accepted = false; moveu(d.x, d.y) }
    onPositionChanged: (d) => { acao = Ds.janela.acaoDoDrop(d); moveu(d.x, d.y) }
    onExited: { _valido = true; moveu(-1, -1) }
    onDestinoChanged: if (containsDrag) _valido = true
    onDropped: (d) => {
        const alvo = a.destino, ok = alvo !== "" && _checar(d)    // antes do moveu(-1): o destino pode ser o painel sob o mouse
        moveu(-1, -1)
        if (ok) Ds.janela.soltarEm(d, alvo, a.mapToItem(null, d.x, d.y))
        _valido = true
    }

    // etiqueta da ação
    Item {
        visible: a.etiqueta && a.sobre
        z: 60
        width: tA.implicitWidth + 18; height: 20
        x: (a.width - width) / 2
        y: a.etiquetaNoTopo ? 6 : a.etiquetaEmbaixo ? a.height - height - 2 : Math.max(-height - 2, (a.height - height) / 2)
        Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.destaque; borda: Tema.destaque }
        Text {
            id: tA
            anchors.centerIn: parent
            text: Ds.t("soltar." + (a.acao || "menu"))
            font.family: Tema.fMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
            color: Tema.escuro
        }
    }
}
