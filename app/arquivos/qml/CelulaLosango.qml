import QtQuick
import "../../qml"

// Célula chanfrada com losango ao centro (a grade de células da referência "Modal do projeto alt3"):
// losango externo em contorno e um menor dentro. "aceso" preenche; "rotulo" embaixo (opcional).
Item {
    id: c
    property bool aceso: false
    property string rotulo: ""
    property string icone: ""            // image://icone/… (opcional, no lugar do losango menor)
    property color cor: Tema.destaque
    Chanfro {
        anchors.fill: parent
        corte: Math.min(width, height) * 0.16
        preenchimento: c.aceso ? Tema.alfa(c.cor, 0.3) : Tema.alfa(c.cor, 0.08)
        borda: Tema.alfa(c.cor, c.aceso ? 1 : 0.5)
    }
    Item {
        id: l
        readonly property real s: Math.min(c.width, c.height - (c.rotulo ? 16 : 0)) * 0.42
        width: s; height: s
        anchors.horizontalCenter: parent.horizontalCenter
        y: (c.height - (c.rotulo ? 16 : 0) - s) / 2
        Rectangle { anchors.centerIn: parent; width: l.s * 0.7; height: width; rotation: 45; color: "transparent"; border.color: Tema.alfa(c.cor, 0.85); border.width: 1 }
        Rectangle { visible: c.icone === ""; anchors.centerIn: parent; width: l.s * 0.32; height: width; rotation: 45; color: c.aceso ? c.cor : "transparent"; border.color: c.cor; border.width: 1 }
        Icone { visible: c.icone !== ""; anchors.centerIn: parent; width: l.s * 0.5; height: width; fonte: c.icone; cor: c.cor }
        Rectangle { x: -l.s * 0.18; anchors.verticalCenter: parent.verticalCenter; width: l.s * 0.14; height: 1; color: Tema.alfa(c.cor, 0.7) }
    }
    Text {
        visible: c.rotulo !== ""
        anchors.bottom: parent.bottom; anchors.bottomMargin: 4
        width: parent.width - 8; x: 4; horizontalAlignment: Text.AlignHCenter
        text: c.rotulo; elide: Text.ElideMiddle
        font.family: Tema.fTexto; font.pixelSize: 10; color: Tema.texto2
    }
}
