import QtQuick

// Atalho de teclado: cápsula angular curta, ao lado da ação correspondente.
Item {
    id: a
    property string tecla: ""
    property color cor: Tema.texto3
    implicitWidth: tx.implicitWidth + 12
    implicitHeight: 16
    Chanfro {
        anchors.fill: parent
        corte: 3
        preenchimento: Tema.alfa(a.cor, 0.08)
        borda: Tema.alfa(a.cor, 0.5)
    }
    Codigo {
        id: tx
        anchors.centerIn: parent
        text: a.tecla
        tamanho: 9
        color: a.cor
    }
}
