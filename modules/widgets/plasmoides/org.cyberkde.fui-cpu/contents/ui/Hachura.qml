import QtQuick
import "comum"

// Retângulo hachurado a 45° (as barras listradas da referência). "deslocar" anda com as listras (0..1).
Canvas {
    id: h
    property color cor: Cores.texto
    property real passo: 7
    property real traco: 3
    property bool contorno: false
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCorChanged: requestPaint()
    renderStrategy: Canvas.Cooperative
    onPaint: {
        const g = getContext("2d")
        g.reset()
        g.save()
        g.beginPath(); g.rect(0, 0, width, height); g.clip()
        g.strokeStyle = cor; g.lineWidth = traco
        g.beginPath()
        for (let x = -height; x < width + height; x += passo) { g.moveTo(x, height); g.lineTo(x + height, 0) }
        g.stroke()
        g.restore()
        if (contorno) { g.strokeStyle = cor; g.lineWidth = 1; g.strokeRect(0.5, 0.5, width - 1, height - 1) }
    }
}
