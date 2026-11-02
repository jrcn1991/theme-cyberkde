import QtQuick
import QtQuick.Shapes
import "comum"

// Knob circular do jukebox: arco de 270° (fundo fraco, valor aceso), um ponto no fim do valor e o número
// no meio (0–100). "interativo": arrastar (para cima/baixo ou em volta) e a roda mudam o valor (5 por
// clique) e emitem mudou(v); senão é só leitura (os "presets").
Item {
    id: k
    property real valor: 0                   // 0..1
    property bool interativo: false
    property bool numero: true
    property color cor: Cores.destaque
    property color corNumero: cor
    property real espessura: Math.max(2, width * 0.045)
    signal mudou(real v)
    implicitWidth: 80; implicitHeight: 80
    readonly property real r: Math.min(width, height) / 2 - espessura - 1
    readonly property real ini: 135                     // graus (0 = 3 h, sentido horário)
    readonly property real ang: ini + 270 * Math.max(0, Math.min(1, valor))
    function emitir(v) { v = Math.max(0, Math.min(1, v)); mudou(v) }

    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: Cores.alfa(k.cor, 0.22); strokeWidth: k.espessura; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: k.width / 2; centerY: k.height / 2; radiusX: k.r; radiusY: k.r; startAngle: k.ini; sweepAngle: 270 }
        }
        ShapePath {
            strokeColor: k.cor; strokeWidth: k.espessura; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: k.width / 2; centerY: k.height / 2; radiusX: k.r; radiusY: k.r; startAngle: k.ini; sweepAngle: 270 * Math.max(0.001, Math.min(1, k.valor)) }
        }
    }
    // o ponto no fim do arco
    Rectangle {
        readonly property real a: k.ang * Math.PI / 180
        width: k.espessura * 2.6; height: width; radius: width / 2
        x: k.width / 2 + Math.cos(a) * k.r - width / 2
        y: k.height / 2 + Math.sin(a) * k.r - height / 2
        color: Cores.texto
    }
    Text {
        visible: k.numero
        anchors.centerIn: parent
        text: Math.round(k.valor * 100)
        font.family: Cores.fTitulo; font.pixelSize: Math.max(10, k.r * 0.85); font.weight: Font.Bold
        color: k.corNumero
    }
    MouseArea {
        enabled: k.interativo
        anchors.fill: parent
        cursorShape: enabled ? Qt.SizeVerCursor : Qt.ArrowCursor
        preventStealing: true
        property real y0: 0
        property real v0: 0
        onPressed: (m) => { y0 = m.y; v0 = k.valor }
        onPositionChanged: (m) => { if (pressed) k.emitir(v0 + (y0 - m.y) / 120) }
        onWheel: (w) => k.emitir(k.valor + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
