import QtQuick
import "comum"

// Uma manchete: fonte e hora, título (2 linhas) e, com espaço, o resumo. Lida = apagada. Nova = pisca
// ao aparecer. Clique abre a notícia (e a marca como lida).
Item {
    id: m
    property var n: ({})
    property bool lida: false
    property bool comResumo: false
    property string hora: ""
    signal abrir()
    height: col.height + 10

    Chanfro {
        id: fundo
        anchors.fill: parent
        corte: 5
        preenchimento: area.containsMouse ? Cores.alfa(Cores.destaque, 0.10) : Cores.alfa(Cores.elevado, m.lida ? 0.3 : 0.65)
        borda: area.containsMouse ? Cores.destaque : Cores.linha
    }
    Rectangle { x: 0; y: 4; width: 3; height: parent.height - 8; color: m.lida ? Cores.texto3 : Cores.destaque }
    Column {
        id: col
        x: 10; y: 5
        width: parent.width - 18
        spacing: 2
        Row {
            spacing: 6
            Codigo { text: (m.n.fonte || "").toUpperCase(); textFormat: Text.PlainText; tamanho: 8; font.bold: true; color: m.lida ? Cores.texto3 : Cores.secundaria }
            Codigo { text: "· " + m.hora; tamanho: 8; color: Cores.texto3 }
            Codigo { visible: m.n.novo === true && !m.lida; text: "● NOVA"; tamanho: 8; font.bold: true; color: Cores.destaque }
        }
        Leitura {
            width: parent.width
            text: m.n.titulo || ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            maximumLineCount: m.comResumo ? 2 : 1      // sem resumo (M): uma linha, para caberem 5
            elide: Text.ElideRight
            tamanho: 12
            font.weight: m.lida ? Font.Normal : Font.DemiBold
            color: m.lida ? Cores.texto2 : Cores.texto
        }
        Leitura {
            visible: m.comResumo && (m.n.resumo || "") !== ""
            width: parent.width
            text: m.n.resumo || ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            tamanho: 11
            color: Cores.texto2
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m.abrir()
    }
    // notícia nova: pisca ao aparecer (uma vez)
    SequentialAnimation {
        id: piscar
        loops: 3
        NumberAnimation { target: m; property: "opacity"; to: 0.25; duration: Cores.d(90) }
        NumberAnimation { target: m; property: "opacity"; to: 1; duration: Cores.d(90) }
    }
    Component.onCompleted: if (n.novo === true && !Cores.reduzir) piscar.start()
}
