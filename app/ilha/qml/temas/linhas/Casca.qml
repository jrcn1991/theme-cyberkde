import QtQuick
import "../comum"

// Linhas: fundo discreto e um fio de 1 px; ao abrir ou fechar, um segundo fio se desenha do centro do topo para os
// dois lados. Em repouso, nada se move.
Item {
    id: c
    property var tema
    property var ctx
    readonly property real r: Math.min(ctx.aberta ? tema.raioAberto : ctx.altura / 2, ctx.altura / 2, tema.raioAberto)
    function canto(cx, cy, ini) {
        const v = []
        for (let i = 0; i <= 5; i++) { const a = ini + (Math.PI / 2) * i / 5; v.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a))) }
        return v
    }
    readonly property var caminho: {
        const w = width, h = height, m = 0.5
        let p = [Qt.point(w / 2, m), Qt.point(w - m, m), Qt.point(w - m, h - r)]
        p = p.concat(canto(w - r - m, h - r - m, 0), canto(r + m, h - r - m, Math.PI / 2))
        p.push(Qt.point(m, m), Qt.point(w / 2, m))
        return p
    }
    Contorno { anchors.fill: parent; pontos: c.caminho; preenchimento: c.tema.fundo; cor: c.tema.borda }
    Contorno {
        anchors.fill: parent; visible: rel.running
        pontos: c.caminho; duasPontas: true; fracao: rel.p; cor: c.tema.texto; opacity: 1 - rel.p * rel.p
    }
    Relogio { id: rel }
    Connections {
        target: c.ctx
        function onAbertaChanged() { if (!c.ctx.reduzir) rel.tocar(c.tema.tempos.abrir) }
    }
}
