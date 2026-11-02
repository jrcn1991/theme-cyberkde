import QtQuick

// Gráfico de linha estilo HUD: grade técnica, área translúcida, linha de dados e marca do pico.
// "series": lista de { valores: [..], cor } (mesma escala); "maximo" 0 = automático.
// Redesenha só quando os dados mudam (sem animação contínua).
Item {
    id: g
    property var series: []
    property real maximo: 0
    property real limiar: -1          // linha de alerta (mesma escala), -1 = sem
    property string unidadePico: ""
    property var formatar: (v) => Math.round(v)
    readonly property real _max: {
        if (maximo > 0) return maximo
        let m = 1
        for (const s of series) for (const v of s.valores || []) if (v > m) m = v
        return m * 1.15
    }
    onSeriesChanged: tela.requestPaint()
    onWidthChanged: tela.requestPaint()
    onHeightChanged: tela.requestPaint()

    Canvas {
        id: tela
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            // grade
            ctx.strokeStyle = Cores.alfa(Cores.linha, 0.6)
            ctx.lineWidth = 1
            ctx.beginPath()
            for (let i = 1; i < 4; i++) { const y = Math.round(h * i / 4) + 0.5; ctx.moveTo(0, y); ctx.lineTo(w, y) }
            for (let i = 1; i < 8; i++) { const x = Math.round(w * i / 8) + 0.5; ctx.moveTo(x, h - 3); ctx.lineTo(x, h) }
            ctx.stroke()
            // limiar
            if (g.limiar > 0 && g.limiar < g._max) {
                const y = Math.round(h - g.limiar / g._max * h) + 0.5
                ctx.strokeStyle = Cores.alfa(Cores.alerta, 0.55)
                ctx.setLineDash([3, 3]); ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); ctx.setLineDash([])
            }
            for (const s of g.series) {
                const vs = s.valores || []
                if (vs.length < 2) continue
                const passo = w / (vs.length - 1)
                const cor = Qt.color(s.cor)
                ctx.beginPath()
                for (let i = 0; i < vs.length; i++) {
                    const x = i * passo, y = h - Math.min(1, vs[i] / g._max) * (h - 2) - 1
                    i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
                }
                ctx.strokeStyle = cor; ctx.lineWidth = 1.5; ctx.stroke()
                ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath()
                ctx.fillStyle = Cores.alfa(cor, 0.12); ctx.fill()
                // pico: marca em losango e valor
                let ip = 0
                for (let i = 1; i < vs.length; i++) if (vs[i] > vs[ip]) ip = i
                if (vs[ip] > 0) {
                    const px = ip * passo, py = h - Math.min(1, vs[ip] / g._max) * (h - 2) - 1
                    ctx.fillStyle = cor
                    ctx.beginPath(); ctx.moveTo(px, py - 3); ctx.lineTo(px + 3, py); ctx.lineTo(px, py + 3); ctx.lineTo(px - 3, py); ctx.closePath(); ctx.fill()
                }
            }
        }
    }
}
