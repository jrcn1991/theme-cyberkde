import QtQuick

// Linhas de varredura sobre a janela inteira (bem fracas, para não atrapalhar a leitura) e uma faixa
// clara que desce uma vez a cada troca de seção (passar()). Camada atmosférica: some com "reduzir
// animações". Não há laço: em repouso, nada aqui pede quadro.
Item {
    id: v
    visible: !Tema.reduzir
    enabled: false

    Canvas {
        anchors.fill: parent
        opacity: 0.05
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#000000"
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1)
        }
    }
    Rectangle {
        id: faixa
        width: parent.width; height: 120
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.92; color: Tema.alfa(Tema.secundaria, 0.018) }
            GradientStop { position: 1; color: Tema.alfa(Tema.secundaria, 0.03) }
        }
        visible: desce.running
        NumberAnimation {
            id: desce
            target: faixa; property: "y"
            from: -120; to: v.height + 120
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }

    function passar() { if (v.visible) desce.restart() }
}
