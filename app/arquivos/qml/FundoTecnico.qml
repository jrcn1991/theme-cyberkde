import QtQuick
import "../../qml"

// Fundo técnico da área das pilhas: grade fina de cruzes (desenhada uma vez, por Canvas) e, de tempos em
// tempos, uma varredura clara que desce (só com a janela ativa e o movimento completo). Em repouso não
// pede quadro: a grade é estática e a varredura é uma passada a cada ~25 s.
Item {
    id: f
    property color cor: Tema.destaque
    property int passo: 32
    enabled: false
    Canvas {
        id: grade
        anchors.fill: parent
        opacity: 0.55
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = Tema.alfa(f.cor, 0.10)
            const p = f.passo
            for (let x = p / 2; x < width; x += p)
                for (let y = p / 2; y < height; y += p) {
                    ctx.fillRect(x - 2, y, 5, 1)
                    ctx.fillRect(x, y - 2, 1, 5)
                }
        }
        Connections { target: Tema; function onDestaqueChanged() { grade.requestPaint() } }
    }
    Rectangle {
        id: faixa
        width: parent.width; height: 90
        visible: desce.running
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.9; color: Tema.alfa(Tema.secundaria, 0.025) }
            GradientStop { position: 1; color: Tema.alfa(Tema.secundaria, 0.07) }
        }
        NumberAnimation { id: desce; target: faixa; property: "y"; from: -90; to: f.height; duration: 1600; easing.type: Easing.InOutSine }
    }
    function passar() { if (!Tema.reduzir && arquivos.movimento === "completo" && f.visible) desce.restart() }
    Timer {
        interval: 25000; repeat: true
        running: f.visible && !Tema.reduzir && arquivos.movimento === "completo" && Qt.application.state === Qt.ApplicationActive
        onTriggered: f.passar()
    }
}
