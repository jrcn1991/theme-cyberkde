import QtQuick
import "comum"

// Arco de medidor (Canvas): trilho fraco, parte cheia até "valor" (0..1) e, opcional, ponto na ponta.
// Ângulos em graus, 0 = topo, sentido horário. Redesenha só quando o valor ou a cor mudam.
Canvas {
    id: c
    property real valor: 0
    property real inicio: 0
    property real abertura: 360
    property real espessura: 2
    property color cor: Cores.texto
    property color trilho: Cores.alfa(Cores.texto, 0.18)
    property bool ponto: false
    property bool trilhoVisivel: true
    onValorChanged: requestPaint()
    onCorChanged: requestPaint()
    onWidthChanged: requestPaint()
    renderStrategy: Canvas.Cooperative
    onPaint: {
        const g = getContext("2d")
        g.reset()
        const r = Math.min(width, height) / 2 - espessura / 2 - (ponto ? 2 : 0)
        const cx = width / 2, cy = height / 2
        const a0 = (inicio - 90) * Math.PI / 180
        const a1 = a0 + abertura * Math.PI / 180
        const v = Math.max(0, Math.min(1, valor))
        g.lineWidth = espessura
        g.lineCap = "butt"
        if (trilhoVisivel) { g.strokeStyle = trilho; g.beginPath(); g.arc(cx, cy, r, a0, a1, false); g.stroke() }
        if (v > 0) {
            g.strokeStyle = cor
            g.beginPath(); g.arc(cx, cy, r, a0, a0 + (a1 - a0) * v, false); g.stroke()
        }
        if (ponto) {
            const a = a0 + (a1 - a0) * v
            g.fillStyle = cor
            g.beginPath(); g.arc(cx + Math.cos(a) * (r - espessura * 2 - 2), cy + Math.sin(a) * (r - espessura * 2 - 2), 2.2, 0, Math.PI * 2); g.fill()
        }
    }
}
