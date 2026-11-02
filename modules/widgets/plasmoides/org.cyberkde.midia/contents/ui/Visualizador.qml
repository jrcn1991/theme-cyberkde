import QtQuick
import "comum"

// Visualizador decorativo (não lê o áudio): colunas segmentadas que mudam ~8x/s, só enquanto toca.
// Parado ou com o movimento em "mínimo", assenta numa linha baixa.
Item {
    id: v
    property bool tocando: false
    property int colunas: 24
    readonly property bool _anima: tocando && !Cores.reduzir && visible
    property var alturas: []
    function sortear() {
        let a = []
        for (let i = 0; i < colunas; i++) {
            // um pouco mais alto no meio-grave, como um espectro
            const f = 0.55 + 0.45 * Math.sin(Math.PI * (i + 2) / (colunas + 4))
            a.push(Math.max(0.08, Math.min(1, f * (0.25 + Math.random() * 0.75))))
        }
        alturas = a
    }
    Timer { interval: 125; running: v._anima; repeat: true; triggeredOnStart: true; onTriggered: v.sortear() }
    on_AnimaChanged: if (!_anima) alturas = []
    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: v.colunas
            Item {
                required property int index
                width: (v.width - (v.colunas - 1) * 2) / v.colunas
                height: v.height
                readonly property real alvo: v.alturas.length ? v.alturas[index] : 0.08
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, Math.round(parent.height * parent.alvo / 3) * 3)
                    Behavior on height { enabled: v._anima; NumberAnimation { duration: 110 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Cores.secundaria }
                        GradientStop { position: 1; color: Cores.destaque }
                    }
                    opacity: v.tocando ? 0.75 : 0.3
                }
                // segmentação: frestas horizontais a cada 3 px
                Column {
                    anchors.fill: parent
                    spacing: 2
                    Repeater { model: Math.floor(parent.height / 3); Rectangle { width: parent.width; height: 1; color: Cores.painel } }
                }
            }
        }
    }
}
