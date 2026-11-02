import QtQuick

// Mouse de um item (qualquer visão): clique (Ctrl alterna, Shift intervalo), duplo clique ativa, botão
// do meio abre pasta em aba nova, botão direito abre o menu; arrastar leva a seleção como
// text/uri-list (outros apps entendem), num QDrag de verdade (Drag.Automatic). As decisões ficam no Main (Ds.janela).
MouseArea {
    id: m
    property int indice: -1
    property string caminho: ""
    property bool ehPasta: false
    property bool selecionado: false
    property var aoClicar: null          // function(e) → true se tratou o clique esquerdo (painel-subpasta)
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // arrastar: limiar próprio (sem drag.target: "Drag.active: drag.active" fazia laço de binding e a
    // arrastada morria) e sem deixar a Flickable/ListView roubar o mouse
    preventStealing: true
    property point _ini
    property bool _arrastando: false
    onPressed: (e) => { _ini = Qt.point(e.x, e.y); _arrastando = false; if (e.button === Qt.LeftButton) Ds.janela.pressionar(m.indice, e.modifiers, m.selecionado) }
    onPositionChanged: (e) => {
        if (!(e.buttons & Qt.LeftButton) || _arrastando || m.indice < 0) return
        if (Math.abs(e.x - _ini.x) + Math.abs(e.y - _ini.y) < 10) return
        const sel = arquivos.aba.selecionados
        if (!sel || !sel.length) return
        _arrastando = true
        const it = arquivos.aba.item(m.indice)
        proxy.x = e.x; proxy.y = e.y
        proxy.Drag.imageSource = it.miniatura || it.iconeUrl || ""
        proxy.Drag.mimeData = { "text/uri-list": arquivos.urisDe(sel), "text/plain": sel.join("\n") }
        Ds.janela.arrastando = sel.length
        proxy.Drag.active = true
    }
    onClicked: (e) => {
        if (e.button === Qt.RightButton) Ds.janela.menuItem(m.indice, m.mapToItem(null, e.x, e.y))
        else if (e.button === Qt.MiddleButton) { if (m.ehPasta) arquivos.novaAba(m.caminho) }
        else if (!(m.aoClicar && !(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && m.aoClicar(e))) Ds.janela.clicar(m.indice, e.modifiers)
    }
    onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) Ds.janela.ativar(m.indice) }

    Item {
        id: proxy
        width: 1; height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot: Qt.point(-12, -12)
        Drag.onDragFinished: (acao) => { proxy.Drag.active = false; m._arrastando = false; Ds.janela.arrastando = 0 }
    }
}
