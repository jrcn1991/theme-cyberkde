import QtQuick

// Janelinha do tema para as prévias: moldura chanfrada, barra de título e linhas de conteúdo.
Item {
    id: j
    property color cor: Tema.destaque
    Chanfro {
        anchors.fill: parent
        corte: Math.max(4, Math.min(width, height) * 0.08)
        preenchimento: Tema.elevado
        borda: Tema.alfa(j.cor, 0.85)
    }
    Rectangle { x: 6; y: 6; width: parent.width - 12; height: Math.max(3, parent.height * 0.1); color: Tema.alfa(j.cor, 0.35) }
    Rectangle { x: 6; y: 6; width: parent.width * 0.3; height: Math.max(3, parent.height * 0.1); color: j.cor }
    Column {
        x: 8; y: parent.height * 0.26
        spacing: Math.max(2, parent.height * 0.06)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: (j.width - 16) * [0.85, 0.6, 0.72, 0.4][index]
                height: Math.max(2, j.height * 0.045)
                color: index === 1 ? Tema.alfa(Tema.secundaria, 0.7) : Tema.alfa(Tema.texto2, 0.5)
            }
        }
    }
}
