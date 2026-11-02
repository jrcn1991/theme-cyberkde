import QtQuick
import "comum"

// Seta e taxa (cartão pequeno da Rede).
Row {
    id: v
    property string seta: "↓"
    property string valor: ""
    property color cor: Cores.destaque
    spacing: 4
    Text {
        anchors.baseline: num.baseline
        text: v.seta
        font.family: Cores.fMono; font.pixelSize: 14; font.bold: true
        color: v.cor
    }
    NumeroCintilante {
        id: num
        valor: v.valor
        intervaloMin: 3000
        font.family: Cores.fIdentidade; font.pixelSize: 17; font.weight: Font.Bold
        color: Cores.texto
    }
}
