import QtQuick
import "../comum"

// Neomilitar: placa chanfrada embaixo, marcador lateral, cantoneiras e micro-dados. Ao abrir, a moldura se traça a
// partir do canto de cima à esquerda, com um ponto na ponta (GIF "cc9790": canto, topo, lateral). Em repouso, parada.
Item {
    id: c
    property var tema
    property var ctx
    readonly property real k: Math.min(tema.corte, height / 2)
    readonly property var caminho: {
        const w = width, h = height, m = 0.5
        return [Qt.point(m, m), Qt.point(w - m, m), Qt.point(w - m, h - k - m), Qt.point(w - k - m, h - m), Qt.point(k + m, h - m), Qt.point(m, h - k - m), Qt.point(m, m)]
    }
    readonly property real traco: rel.running ? rel.p : 1
    readonly property bool alto: height > 80
    Contorno { anchors.fill: parent; pontos: c.caminho; preenchimento: c.tema.fundo; fracao: 0 }
    Contorno { id: linha; anchors.fill: parent; pontos: c.caminho; fracao: c.traco; cor: c.tema.borda }
    Rectangle { visible: rel.running; x: linha.ponta.x - 2; y: linha.ponta.y - 2; width: 4; height: 4; color: c.tema.texto }
    Rectangle { x: 0; y: 8; width: 3; height: Math.min(20, c.height - 16); color: c.ctx.nivel === "alerta" || c.ctx.nivel === "erro" ? c.tema.alerta : c.tema.acao }
    // cantoneiras
    Repeater {
        model: c.alto ? 2 : 0
        Item {
            required property int index
            x: index ? c.width - 5 : -3; y: c.height - 5; width: 8; height: 8
            Rectangle { y: 7; width: 8; height: 1; color: c.tema.trilha }
            Rectangle { x: parent.index ? 7 : 0; width: 1; height: 8; color: c.tema.trilha }
        }
    }
    // micro-dados na faixa do corte (decorativos)
    Text {
        visible: c.alto
        anchors.right: parent.right; anchors.rightMargin: c.k + 6; y: c.height - 10
        text: "SYS.ISLAND // " + (c.ctx.kind || "IDLE").toUpperCase()
        font.family: c.tema.fonteMono; font.pixelSize: 7; font.letterSpacing: 0.6
        color: c.tema.texto3
    }
    Row {
        visible: c.alto
        x: c.k + 6; y: c.height - 7; spacing: 2
        Repeater { model: 18; Rectangle { required property int index; width: index * 7 % 3 === 0 ? 3 : 1; height: 3; color: c.tema.trilha } }
    }
    Relogio { id: rel }
    Connections {
        target: c.ctx
        function onAbertaChanged() { if (!c.ctx.reduzir && c.ctx.aberta) rel.tocar(c.tema.tempos.abrir) }
    }
}
