import QtQuick

// Código técnico pequeno (decorativo): identificadores, unidades, rótulos de dados.
Text {
    property int tamanho: 9
    font.family: Cores.fMono
    font.pixelSize: tamanho
    font.letterSpacing: 0.6
    color: Cores.texto3
    elide: Text.ElideRight
}
