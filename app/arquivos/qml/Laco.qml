import QtQuick
import "../../qml"

// Seleção por laço (rubber band) nas visões LISTA e GRADE: fica atrás dos itens, no conteúdo da
// vista. Arrastar a partir do vazio desenha o retângulo; "indicesNo(rect)" (da visão) diz quais itens
// ele pega. Ctrl soma à seleção. Clique no vazio limpa; botão direito abre o menu da pasta.
MouseArea {
    id: l
    property var indicesNo: (r) => []
    property bool ativo: false
    property var marcados: []
    property real x0: 0
    property real y0: 0
    property bool somar: false
    readonly property rect r: Qt.rect(Math.min(x0, mouseX), Math.min(y0, mouseY), Math.abs(mouseX - x0), Math.abs(mouseY - y0))
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true

    onPressed: (e) => {
        Ds.janela.focarArea()
        if (e.button === Qt.RightButton) return
        x0 = e.x; y0 = e.y; somar = (e.modifiers & Qt.ControlModifier) !== 0
        ativo = false; marcados = []
    }
    onPositionChanged: (e) => {
        if (!pressed || (pressedButtons & Qt.LeftButton) === 0) return
        if (!ativo && Math.abs(e.x - x0) + Math.abs(e.y - y0) > 6) ativo = true
        if (ativo) marcados = indicesNo(r)
    }
    onReleased: (e) => {
        if (e.button === Qt.RightButton) { Ds.janela.menuItem(-1, l.mapToItem(null, e.x, e.y)); return }
        if (ativo) arquivos.aba.selecionarIndices(marcados, somar)
        else if (!somar) arquivos.aba.limparSelecao()
        ativo = false; marcados = []
    }
    Rectangle {
        visible: l.ativo
        x: l.r.x; y: l.r.y; width: l.r.width; height: l.r.height
        color: Tema.alfa(Tema.secundaria, 0.12)
        border.color: Tema.secundaria
    }
}
