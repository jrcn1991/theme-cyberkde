import QtQuick

// Leitura de um valor: rótulo pequeno em cima, valor embaixo, filete à esquerda.
Item {
    id: d
    property string rotulo: ""
    property string valor: ""
    property color cor: Tema.texto
    property string nota: ""
    default property alias extra: linha.data
    implicitWidth: 160
    implicitHeight: Math.max(58, colDado.implicitHeight + 2)

    Rectangle { width: 1; height: parent.height; color: Tema.linha }
    Rectangle { width: 1; height: 14; color: Tema.destaque }
    Column {
        id: colDado
        x: 12
        spacing: 4
        Codigo { text: d.rotulo; tamanho: 10 }
        Row {
            id: linha
            spacing: 8
            NumeroCintilante {        // cintila ao mudar (A13)
                valor: d.valor
                font.family: Tema.fRotulo; font.pixelSize: 22; font.weight: Font.Bold
                color: d.cor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Leitura { text: d.nota; tamanho: 11; color: Tema.texto3; visible: text !== ""; width: d.width - 14 }
    }
}
