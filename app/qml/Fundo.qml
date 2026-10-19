import QtQuick

// Fundo: grade técnica bem discreta, marcas "+" nas interseções maiores e linhas de varredura.
// Tudo desenhado uma vez (Canvas) e redesenhado só quando o tamanho ou a cor mudam.
Item {
    id: f
    property color cor: Tema.destaque

    Rectangle { anchors.fill: parent; color: Tema.base }

    Canvas {
        id: grade
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        property color cor: f.cor
        onCorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.022)
            ctx.lineWidth = 1
            const passo = 32
            ctx.beginPath()
            for (let x = 0.5; x < width; x += passo) { ctx.moveTo(x, 0); ctx.lineTo(x, height) }
            for (let y = 0.5; y < height; y += passo) { ctx.moveTo(0, y); ctx.lineTo(width, y) }
            ctx.stroke()
            ctx.strokeStyle = Qt.rgba(cor.r, cor.g, cor.b, 0.16)
            ctx.beginPath()
            for (let x = passo * 4 + 0.5; x < width; x += passo * 8)
                for (let y = passo * 4 + 0.5; y < height; y += passo * 8) {
                    ctx.moveTo(x - 4, y); ctx.lineTo(x + 5, y)
                    ctx.moveTo(x, y - 4); ctx.lineTo(x, y + 5)
                }
            ctx.stroke()
        }
    }

    // brilho no canto de baixo, na cor de destaque
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.75; color: "transparent" }
            GradientStop { position: 1.0; color: Tema.alfa(f.cor, 0.06) }
        }
    }
}
