import QtQuick
import "../../qml"

// Ficha clicável (filtros, etiquetas, modos): chanfrada, cheia quando ativa. "fechar" mostra um ×
// (etiqueta removível) que emite removido().
Item {
    id: ch
    property string texto: ""
    property bool ativo: false
    property bool fechar: false
    property color cor: Tema.destaque
    signal clicado()
    signal removido()
    implicitWidth: tx.implicitWidth + (fechar ? 34 : 20); implicitHeight: 24
    Chanfro {
        anchors.fill: parent; corte: 5
        preenchimento: ch.ativo ? ch.cor : (hv.hovered ? Tema.alfa(ch.cor, 0.15) : Tema.alfa(ch.cor, 0.05))
        borda: Tema.alfa(ch.cor, ch.ativo || hv.hovered ? 1 : 0.5)
    }
    Text {
        id: tx
        x: 10; anchors.verticalCenter: parent.verticalCenter
        text: ch.texto; font.family: Tema.fMono; font.pixelSize: 11; font.letterSpacing: 0.5
        color: ch.ativo ? Tema.escuro : Tema.texto
    }
    Text {
        visible: ch.fechar
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: "×"; font.pixelSize: 14; font.bold: true; color: ch.ativo ? Tema.escuro : Tema.texto2
        TapHandler { onTapped: ch.removido() }
    }
    HoverHandler { id: hv; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ch.clicado() }
}
