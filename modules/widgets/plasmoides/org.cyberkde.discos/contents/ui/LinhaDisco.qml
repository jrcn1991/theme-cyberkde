import QtQuick
import "comum"

// Uma unidade: nome (fonte de leitura), ponto de montagem, ocupação, barra segmentada e, se pedido,
// leitura/escrita e temperatura. Clique: abre a pasta (o widget decide como).
Item {
    id: l
    property var u: null                  // { nome, alvo, total, usado, livre, frac, temp, pk }
    property real limiar: 0.9
    property bool mostrarES: false
    property real leitura: 0
    property real escrita: 0
    property var bytes: (b) => String(b)
    property var taxa: (b) => String(b)
    signal abrir()
    height: 44
    readonly property bool cheio: u && u.frac >= limiar
    readonly property color cor: cheio ? Cores.alerta : Cores.destaque

    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Cores.alfa(Cores.destaque, 0.07) : "transparent"
        Behavior on color { ColorAnimation { duration: Cores.d(80) } }
    }
    Rectangle { visible: l.cheio; width: 2; height: parent.height - 6; y: 3; color: Cores.alerta }

    Text {
        id: nome
        x: 6; y: 3
        width: Math.min(implicitWidth, parent.width * 0.45)
        text: l.u ? l.u.nome : ""
        font.family: Cores.fTexto; font.pixelSize: 13; font.bold: true
        color: Cores.texto
        elide: Text.ElideRight
    }
    Codigo {
        anchors.left: nome.right; anchors.leftMargin: 8
        anchors.right: pct.left; anchors.rightMargin: 8
        anchors.baseline: nome.baseline
        text: l.u ? l.u.alvo + (l.u.temp > 0 ? "  ·  " + Math.round(l.u.temp) + "°C" : "") : ""
        tamanho: 9
    }
    Text {
        id: pct
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.baseline: nome.baseline
        text: l.u ? (l.cheio ? "▲ " : "") + Math.round(l.u.frac * 100) + "%" : "--"
        font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
        color: l.cheio ? Cores.alerta : Cores.texto
    }
    BarraSegmentada {
        id: barra
        x: 6; y: nome.y + nome.height + 3
        width: parent.width - 12; height: 7
        valor: l.u ? l.u.frac : 0
        limiar: l.limiar
        tamSeg: 4; vao: 2
    }
    Text {
        x: 6; y: barra.y + barra.height + 3
        text: l.u ? l.bytes(l.u.usado) + " / " + l.bytes(l.u.total) : ""
        font.family: Cores.fMono; font.pixelSize: 9
        color: Cores.texto3
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 6
        y: barra.y + barra.height + 3
        text: l.u ? (l.mostrarES ? "L " + l.taxa(l.leitura) + "  E " + l.taxa(l.escrita) + "  ·  " : "")
                    + l.bytes(l.u.livre) + (Cores.en ? " free" : " livres") : ""
        font.family: Cores.fMono; font.pixelSize: 9
        color: l.cheio ? Cores.alerta : Cores.texto2
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: l.abrir()
    }
}
