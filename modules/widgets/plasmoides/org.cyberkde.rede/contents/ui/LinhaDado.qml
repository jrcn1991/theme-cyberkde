import QtQuick
import "comum"

// Linha "RÓTULO ........ valor" da Rede; "sinal" (0..1) mostra a força do Wi-Fi em segmentos.
Item {
    id: l
    property string rotulo: ""
    property string valor: ""
    property bool mono: false
    property color cor: Cores.texto
    property real sinal: -1
    property string dica: ""
    width: parent ? parent.width : 200
    height: 18
    Codigo {
        id: rot
        anchors.verticalCenter: parent.verticalCenter
        width: 86
        text: l.rotulo
        tamanho: 8; color: Cores.texto3
        elide: Text.ElideRight
    }
    Rectangle {  // filete pontilhado até o valor
        anchors.left: rot.right; anchors.right: val.left; anchors.margins: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Cores.alfa(Cores.linha, 0.6)
    }
    Row {
        id: val
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        BarraSegmentada {
            visible: l.sinal >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 6
            valor: Math.max(0, l.sinal)
            cor: Cores.secundaria
            tamSeg: 3; vao: 2
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, l.width - 86 - 40)
            text: l.valor
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            font.family: l.mono ? Cores.fMono : Cores.fTexto
            font.pixelSize: l.mono ? 11 : 12
            color: l.cor
        }
    }
}
