import QtQuick
import "comum"

// Gráfico HUD com título no canto; "perdas" (lista de bool, mesmo tamanho da série) marca na cor de
// alerta os pings sem resposta.
Item {
    id: g
    property string titulo: ""
    property string textoTitulo: ""
    property var series: []
    property real limiar: -1
    property var perdas: []
    GraficoHud {
        id: graf
        anchors.fill: parent
        series: g.series
        limiar: g.limiar
    }
    Repeater {
        model: g.perdas.length
        Rectangle {
            required property int index
            visible: g.perdas[index] === true
            readonly property int n: Math.max(2, g.perdas.length)
            x: index / (n - 1) * (g.width - 2)
            y: g.height - 6
            width: 2; height: 6
            color: Cores.alerta
        }
    }
    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top
        width: cab.width + 8; height: cab.height + 4
        color: Cores.alfa(Cores.painel, 0.85)
    }
    Row {
        id: cab
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; anchors.leftMargin: 4
        spacing: 8
        Codigo { text: g.titulo; tamanho: 7; color: Cores.texto2; textFormat: Text.PlainText }
        Codigo { visible: g.textoTitulo !== ""; text: g.textoTitulo; tamanho: 7; color: Cores.destaque; font.bold: true }
    }
}
