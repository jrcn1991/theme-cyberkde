import QtQuick
import "../../qml"

// Faixa de código de barras decorativa, determinística a partir de "texto" (o código do item).
Item {
    id: b
    property string texto: ""
    property color cor: Tema.destaque
    readonly property var larguras: Ds.barras(texto, 48)
    clip: true
    Row {
        height: parent.height
        spacing: 1
        Repeater {
            model: b.larguras
            Rectangle {
                required property int modelData
                required property int index
                width: modelData; height: b.height
                color: index % 2 ? "transparent" : b.cor
            }
        }
    }
}
