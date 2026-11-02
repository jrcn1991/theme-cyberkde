import QtQuick
import "comum"

// Nós em circuito, com rótulos: LAN (esta máquina: interfaces ligadas) → GW (o gateway, com a latência)
// → INTERNET (alvos públicos que responderam ao ping, com a latência de cada um). "alcance" = quantos nós,
// nessa ordem, estão acesos. A cada sondagem ("pulso" muda) um anel percorre o caminho até onde o sinal
// chegou; em repouso, nada se mexe. Medidas em unidades da referência, convertidas para pixel inteiro.
Item {
    id: r
    property real k: 1
    property int alcance: 0
    property int pulso: 0
    property string textoLan: ""
    property string textoGw: ""
    property bool gwOk: false
    property string textoNet: ""         // a melhor latência dos alvos públicos
    function u(v) { return Math.round(v * k) }
    readonly property var nos: [
        [11, 30], [48.5, 30], [86, 30], [11, 60], [48.5, 60], [86, 60], [123.5, 60], [11, 90], [86, 90],
        [178.5, 44], [178.5, 78],
        [235, 30], [272, 30], [309, 30], [346, 30], [235, 60], [272, 60], [346, 60], [235, 90], [272, 90], [309, 90], [346, 90]]
    readonly property var ordem: [3, 0, 7, 4, 1, 5, 2, 8, 6, 9, 10, 15, 11, 16, 12, 18, 19, 13, 20, 14, 17, 21]
    readonly property var posicao: { const o = {}; ordem.forEach((n, i) => o[n] = i); return o }
    property int varrendo: -1

    onPulsoChanged: {
        if (Cores.reduzir || !visible) return
        varrendo = 0
        passo.restart()
    }
    Timer {
        id: passo
        interval: Cores.d(45); repeat: true
        onTriggered: { if (++r.varrendo >= Math.max(1, r.alcance)) { stop(); r.varrendo = -1 } }
    }

    // rótulos das três partes
    component Rot: Text {
        font.family: Cores.fTitulo; font.weight: Font.Bold; font.pixelSize: Math.max(10, r.u(10.5))
        font.letterSpacing: 0.5
        color: Cores.texto2
    }
    Rot { x: r.u(1); y: 0; text: "LAN" }
    Rot { x: r.u(178.5) - width / 2; y: 0; text: "GW" }
    Rot { x: r.u(225); y: 0; text: "INTERNET" }

    Canvas {
        anchors.fill: parent
        property var sinal: [r.alcance, width, height]
        onSinalChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"); g.reset()
            g.lineWidth = Math.max(1, Math.round(1.3 * r.k))
            const off = g.lineWidth % 2 ? 0.5 : 0
            const P = (x, y) => [Math.round(x * r.k) + off, Math.round(y * r.k) + off]
            const linha = (pts, aceso) => {
                g.strokeStyle = aceso ? Cores.texto : Cores.alfa(Cores.texto, 0.32)
                g.beginPath()
                pts.forEach((p, i) => { const q = P(p[0], p[1]); i ? g.lineTo(q[0], q[1]) : g.moveTo(q[0], q[1]) })
                g.stroke()
            }
            const ok = (n) => r.posicao[n] < r.alcance
            linha([[21, 30], [38.5, 30]], ok(1)); linha([[58.5, 30], [76, 30]], ok(2))
            linha([[21, 60], [38.5, 60]], ok(4)); linha([[58.5, 60], [76, 60]], ok(5)); linha([[96, 60], [113.5, 60]], ok(6))
            linha([[86, 40], [86, 50]], ok(2)); linha([[86, 70], [86, 80]], ok(8))
            linha([[21, 90], [40, 90], [40, 100], [62, 100], [62, 90], [76, 90]], ok(8))
            linha([[133.5, 60], [148, 60]], ok(9)); linha([[148, 44], [148, 78]], ok(9))
            linha([[148, 44], [168.5, 44]], ok(9)); linha([[148, 78], [168.5, 78]], ok(10))
            linha([[188.5, 44], [210, 44], [210, 78], [188.5, 78]], ok(15)); linha([[210, 60], [225, 60]], ok(15))
            linha([[245, 30], [262, 30]], ok(12)); linha([[282, 30], [299, 30]], ok(13)); linha([[319, 30], [336, 30]], ok(14))
            linha([[245, 60], [262, 60]], ok(16))
            linha([[245, 90], [262, 90]], ok(19)); linha([[282, 90], [299, 90]], ok(20)); linha([[319, 90], [336, 90]], ok(21))
            linha([[272, 40], [272, 50]], ok(16)); linha([[272, 70], [272, 80]], ok(19))
            linha([[282, 60], [296, 60], [296, 56], [306, 56]], ok(17)); linha([[312, 64], [322, 64], [322, 60], [336, 60]], ok(17))
            g.fillStyle = ok(17) ? Cores.texto : Cores.alfa(Cores.texto, 0.32)
            const a = P(307, 54), b = P(307, 62), t = Math.max(3, Math.round(4 * r.k))
            g.fillRect(a[0] - off, a[1] - off, t, t); g.fillRect(b[0] - off, b[1] - off, t, t)
        }
    }
    Repeater {
        model: r.nos.length
        Item {
            required property int index
            readonly property var c: r.nos[index]
            readonly property bool aceso: r.posicao[index] < r.alcance
            readonly property bool varrido: r.posicao[index] === r.varrendo
            readonly property int d: r.u(20) % 2 ? r.u(20) + 1 : r.u(20)
            x: r.u(c[0]) - d / 2; y: r.u(c[1]) - d / 2; width: d; height: d
            Rectangle {
                anchors.fill: parent; radius: width / 2; color: "transparent"
                border.color: parent.varrido ? Cores.destaque : parent.aceso ? Cores.texto : Cores.alfa(Cores.texto, 0.32)
                border.width: parent.varrido ? Math.max(2, r.u(2.2)) : Math.max(1, r.u(1.3))
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.aceso ? Math.max(4, r.u(6)) : Math.max(2, r.u(3)); height: width; radius: width / 2
                color: parent.aceso ? Cores.texto : Cores.alfa(Cores.texto, 0.32)
            }
        }
    }
    // valores: interfaces, latência do gateway e de cada alvo
    component Val: Text {
        font.family: Cores.fMono; font.pixelSize: Math.max(11, r.u(11)); font.weight: Font.Bold
        color: Cores.texto
        elide: Text.ElideRight
    }
    Val { x: 0; y: r.u(106); width: r.u(140); text: r.textoLan }
    Val { x: r.u(178.5) - width / 2; y: r.u(96); text: r.textoGw; color: r.gwOk ? Cores.texto : Cores.alerta }
    Val { x: r.u(290.5) - width / 2; y: r.u(106); text: r.textoNet }
}
