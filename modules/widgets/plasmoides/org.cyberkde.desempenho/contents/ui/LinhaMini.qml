import QtQuick
import "comum"

// Linha do cartão enxuto: rótulo, mini-barra segmentada e valor (alerta acima do limiar).
Item {
    id: l
    property string rotulo: ""
    property real fracao: 0
    property real limiar: 2
    property string valor: ""
    property color cor: Cores.destaque
    readonly property bool alerta: fracao >= limiar
    width: parent ? parent.width : 180
    height: visible ? 15 : 0
    Codigo { id: r; width: 30; text: l.rotulo; tamanho: 9; color: l.alerta ? Cores.alerta : Cores.texto2; anchors.verticalCenter: parent.verticalCenter }
    BarraSegmentada {
        x: r.width + 2
        width: l.width - r.width - 46
        height: 7
        anchors.verticalCenter: parent.verticalCenter
        valor: l.fracao; limiar: l.limiar; cor: l.cor
        tamSeg: 3; vao: 2
    }
    Text {
        anchors.right: parent.right
        width: 40
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
        text: l.valor
        font.family: Cores.fMono; font.pixelSize: 11
        color: l.alerta ? Cores.alerta : Cores.texto
    }
}
