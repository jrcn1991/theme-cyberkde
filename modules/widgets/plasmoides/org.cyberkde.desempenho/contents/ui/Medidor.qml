import QtQuick
import "comum"

// Uma linha de medida: rótulo técnico, barra segmentada e valor (cintila ao mudar). Acima do
// limiar (0..1), barra e valor passam à cor de alerta.
Item {
    id: m
    property string rotulo: ""
    property real fracao: 0
    property real limiar: 2
    property string valor: ""
    property color cor: Cores.destaque
    property real larguraValor: 112
    readonly property bool alerta: fracao >= limiar
    width: parent ? parent.width : 200
    height: 16
    Codigo { id: r; width: 46; text: m.rotulo; tamanho: 9; anchors.verticalCenter: parent.verticalCenter; color: m.alerta ? Cores.alerta : Cores.texto2 }
    BarraSegmentada {
        x: r.width + 4
        width: m.width - r.width - m.larguraValor - 12
        height: 7
        anchors.verticalCenter: parent.verticalCenter
        valor: m.fracao; limiar: m.limiar; cor: m.cor
        tamSeg: 3; vao: 2
    }
    NumeroCintilante {
        anchors.right: parent.right
        width: m.larguraValor
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
        valor: m.valor
        intervaloMin: 2500
        font.pixelSize: 11
        color: m.alerta ? Cores.alerta : Cores.texto
    }
}
