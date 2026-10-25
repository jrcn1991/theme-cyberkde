import QtQuick

// Rótulo curto (Rajdhani, caixa alta). Só para títulos e rótulos, nunca para texto de leitura.
Text {
    property int tamanho: 15
    font.family: Tema.fRotulo
    font.weight: Font.DemiBold
    font.pixelSize: tamanho
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.2
    color: Tema.texto
}
