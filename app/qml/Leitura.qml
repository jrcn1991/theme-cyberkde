import QtQuick

// Texto de leitura: fonte do sistema (Noto Sans), cor TXT1/TXT2, com quebra de linha.
Text {
    property int tamanho: 13
    font.family: Tema.fTexto
    font.pixelSize: tamanho
    color: Tema.texto2
    wrapMode: Text.Wrap
    lineHeight: 1.15
}
