import QtQuick

// Texto de leitura: fonte do sistema, cor TXT1/TXT2 do tema.
Text {
    property int tamanho: 12
    font.family: Cores.fTexto
    font.pixelSize: tamanho
    color: Cores.texto2
    wrapMode: Text.Wrap
}
