import QtQuick
import "comum"

// Número grande com rótulo curto embaixo (cartão pequeno do Docker).
Column {
    id: c
    property string rotulo: ""
    property int valor: 0
    property color cor: Cores.destaque
    spacing: 0
    NumeroCintilante {
        valor: String(c.valor)
        font.family: Cores.fIdentidade; font.pixelSize: 30; font.weight: Font.Bold
        color: c.cor
    }
    Codigo { text: c.rotulo; tamanho: 8; color: Cores.texto2 }
}
