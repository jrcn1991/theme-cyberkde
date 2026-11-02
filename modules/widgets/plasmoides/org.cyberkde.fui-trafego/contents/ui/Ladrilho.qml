import QtQuick
import org.kde.plasma.components as PC3
import "comum"

// Ladrilho de estado (as colunas "HDR" da referência): um glifo e, embaixo, o rótulo curto (NET, SOM…).
// "diagonal" = meio quadrado aceso (ligado) ou na fração "nivel"; "barra" = nível embaixo; "circulos" =
// dois círculos (cheios = sim). Pisca 3 vezes quando o estado muda (só aí). "dica" ao passar o mouse.
Item {
    id: l
    property real k: 1
    property string tipo: "diagonal"
    property string rotulo: ""
    property bool cheio: false
    property real nivel: 0
    property string dica: ""
    property bool alerta: false
    function u(v) { return Math.round(v * k) }
    width: u(27); height: u(36)
    readonly property string assinatura: tipo + cheio + Math.round(nivel * 10) + alerta
    property bool _pronto: false
    Component.onCompleted: _pronto = true
    onAssinaturaChanged: if (_pronto && !Cores.reduzir) pisca.restart()
    SequentialAnimation {
        id: pisca
        loops: 3
        PropertyAction { target: caixa; property: "opacity"; value: 0.15 }
        PauseAnimation { duration: 90 }
        PropertyAction { target: caixa; property: "opacity"; value: 1 }
        PauseAnimation { duration: 90 }
    }
    readonly property color cor: alerta ? Cores.alerta : Cores.texto
    Item {
        id: caixa
        width: l.width; height: l.u(23)
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: l.cor; border.width: Math.max(1, l.u(1.4)) }
        Canvas {
            visible: l.tipo === "diagonal"
            anchors.fill: parent; anchors.margins: Math.max(2, l.u(3))
            property var sinal: [l.cheio, l.nivel, l.cor, width]
            onSinalChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.reset()
                g.fillStyle = l.cor
                const f = l.cheio ? 1 : Math.max(0, Math.min(1, l.nivel))
                if (f <= 0) { g.strokeStyle = Cores.alfa(Cores.texto, 0.4); g.beginPath(); g.moveTo(0, height); g.lineTo(width, 0); g.stroke(); return }
                g.beginPath(); g.moveTo(width * (1 - f), height); g.lineTo(width, height * (1 - f)); g.lineTo(width, height); g.closePath(); g.fill()
            }
        }
        Rectangle {
            visible: l.tipo === "barra"
            x: Math.max(2, l.u(3)); y: parent.height - Math.max(2, l.u(3)) - height
            height: Math.max(3, l.u(5))
            width: Math.round((parent.width - 2 * x) * Math.max(0, Math.min(1, l.nivel)))
            color: l.cor
        }
        Row {
            visible: l.tipo === "circulos"
            anchors.centerIn: parent; spacing: Math.max(1, l.u(2))
            Repeater {
                model: 2
                Rectangle {
                    width: l.u(9); height: width; radius: width / 2
                    color: l.cheio ? l.cor : "transparent"; border.color: l.cor; border.width: 1
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: l.u(25)
        text: l.rotulo
        font.family: Cores.fTitulo; font.weight: Font.Bold; font.pixelSize: Math.max(10, l.u(10.5))
        color: l.alerta ? Cores.alerta : Cores.texto2
    }
    HoverHandler { id: sobre }
    PC3.ToolTip { visible: sobre.hovered && l.dica !== ""; delay: 300; text: l.dica }
}
