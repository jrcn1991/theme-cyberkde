import QtQuick
import "../../qml"

// Feixe de luz diagonal que varre a superfície UMA vez (referência 15: shards com o brilho passando).
// Filho de quem recebe o brilho (que precisa de clip). passar() dispara; só no movimento completo.
// Em repouso não existe nada desenhando: a faixa só fica visível durante a passada.
Item {
    id: f
    property color cor: Tema.secundaria
    property real largura: Math.max(18, parent ? parent.width * 0.8 : 24)
    property int duracao: 420
    anchors.fill: parent
    enabled: false
    function passar() {
        if (Tema.reduzir || arquivos.movimento !== "completo" || width <= 0) return
        anda.restart()
    }
    signal acabou()
    property real _p: -1
    Rectangle {
        visible: anda.running
        width: f.largura
        height: Math.hypot(f.width, f.height) * 1.6
        x: -width + (f.width + width * 2) * f._p - width / 2
        y: (f.height - height) / 2
        rotation: 32
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.35; color: Tema.alfa(f.cor, 0.35) }
            GradientStop { position: 0.5; color: Tema.alfa(f.cor, 0.85) }
            GradientStop { position: 0.65; color: Tema.alfa(f.cor, 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    NumberAnimation { id: anda; target: f; property: "_p"; from: 0; to: 1; duration: f.duracao; easing.type: Easing.InOutQuad
                      onFinished: f.acabou() }
}
