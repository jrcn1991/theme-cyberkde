import QtQuick

// Presets de tamanho (P · M · G; em inglês S · M · L): aplicam um tamanho ao widget, que depois pode
// ser redimensionado à mão. Fica na faixa de edição do Tamanhos. "atual" acende o preset cujo tamanho é
// o de agora ("" depois de um ajuste manual).
Row {
    id: s
    property string atual: ""
    signal escolhido(string modo)
    spacing: 2
    Repeater {
        model: [["pequeno", Cores.en ? "S" : "P"], ["medio", "M"], ["grande", Cores.en ? "L" : "G"]]
        Item {
            required property var modelData
            readonly property bool ativo: s.atual === modelData[0]
            width: 16; height: 16
            Rectangle {
                anchors.fill: parent
                color: parent.ativo ? Cores.alfa(Cores.destaque, 0.25) : (ma.containsMouse ? Cores.alfa(Cores.destaque, 0.12) : Cores.alfa(Cores.cartao, 0.9))
                border.color: parent.ativo || ma.containsMouse ? Cores.destaque : Cores.alfa(Cores.texto3, 0.7)
                border.width: 1
            }
            Codigo {
                anchors.centerIn: parent
                text: parent.modelData[1]; tamanho: 8; font.bold: true
                color: parent.ativo ? Cores.destaque : Cores.texto
            }
            MouseArea {
                id: ma
                anchors.fill: parent; anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // no modo de edição o contêiner do Plasma toma o "soltar" (é dele o arraste): age no apertar
                onPressed: s.escolhido(parent.modelData[0])
            }
        }
    }
}
