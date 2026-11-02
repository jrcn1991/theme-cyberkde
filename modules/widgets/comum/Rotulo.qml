import QtQuick

// Título curto (Rajdhani, caixa alta). Só para rótulos; nunca para texto de leitura.
Text {
    property int tamanho: 14
    font.family: Cores.fTitulo
    font.weight: Font.DemiBold
    font.pixelSize: tamanho
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1
    color: Cores.texto
    elide: Text.ElideRight
}
