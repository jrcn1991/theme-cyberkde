import QtQuick
import "comum"

// Redimensiona a cerca sem o modo de edição. Ao soltar, a altura fecha em linhas inteiras de ícones.
MouseArea {
    id: alca
    property var cerca: null
    property Item grade: null                // a camada do FolderView
    property Item caixa: null                // a área visível dos ícones
    property bool lx: true
    property bool ly: true
    visible: !!cerca && cerca.podeMexer && !cerca.rolada && !cerca.animando && !cerca._modoEdicao
    hoverEnabled: true
    preventStealing: true
    property point inicio
    property size tam0
    onPressed: (m) => {
        inicio = mapToItem(null, m.x, m.y)
        tam0 = Qt.size(cerca.cont.width, cerca.cont.height)
        cerca.cont.layout.releaseSpace(cerca.cont)
    }
    onPositionChanged: (m) => {
        if (!pressed) return
        const p = mapToItem(null, m.x, m.y), L = cerca.cont.parent
        if (lx) cerca.cont.width = Math.max(256, Math.min(tam0.width + p.x - inicio.x, L.width - cerca.cont.x))
        if (ly) cerca.cont.height = Math.max(176, Math.min(tam0.height + p.y - inicio.y, L.height - cerca.cont.y))
    }
    onReleased: {
        const g = grade && grade.view ? grade.view.view : null
        if (ly && g && g.cellHeight > 0) {
            const cab = cerca.cont.height - caixa.height
            cerca.cont.height = Math.ceil((cab + Math.max(1, Math.round(caixa.height / g.cellHeight)) * g.cellHeight) / cerca.celula) * cerca.celula
        }
        cerca.cont.layout.positionItem(cerca.cont)
        Cores.gravarLayout(cerca.cont.layout)
        cerca.assentar()
    }
}
