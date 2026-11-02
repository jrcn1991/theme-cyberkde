import QtQuick
import QtQuick.Effects
import "../../qml"

// Ícone do tema do sistema (image://icone/…) tingido numa cor da paleta: a interface fica
// monocromática como a referência (as cores do Breeze ficariam fora do tom da corporação).
// "colorir" 0 mostra o ícone com as cores dele (ex.: tipos de arquivo nos Recentes); "brilho" acende
// (item ativo/hover). Sem shaders (renderizador por software), mostra o ícone original.
Item {
    id: i
    property string fonte: ""
    property color cor: Tema.texto2
    property real nitidez: 1
    property real colorir: 1               // 0 = cores do próprio ícone … 1 = todo na cor "cor"
    property real brilho: 0.1
    Image {
        id: img
        anchors.fill: parent
        source: i.fonte
        sourceSize: Qt.size(i.width * 2, i.height * 2)
        visible: !Tema.efeitos || i.colorir <= 0
        opacity: (i.colorir <= 0 ? 1 : 0.7) * i.nitidez
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: Tema.efeitos && img.status === Image.Ready && i.colorir > 0
        colorization: i.colorir
        colorizationColor: i.cor
        brightness: i.brilho
        opacity: i.nitidez
    }
}
