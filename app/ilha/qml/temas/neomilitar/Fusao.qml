import QtQuick

// Neomilitar fundido: marcador lateral e micro-dados dentro do traçado; o filete é da barra e não se toca.
Item {
    id: f
    property var tema
    property var ctx
    readonly property bool alto: height > 80
    readonly property color corNivel: ctx.nivel === "alerta" || ctx.nivel === "erro" ? tema.alerta : tema.acao
    Rectangle { x: 5; y: 8; width: 3; height: Math.min(20, f.height - 16); color: f.corNivel }
    // fechada: código de barras na ponta direita
    Row {
        visible: !f.alto && f.width > 170
        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Repeater { model: 5; Rectangle { required property int index; width: index % 2 ? 1 : 2; height: 9; color: f.tema.trilha } }
    }
    // aberta: a faixa de micro-dados, acima do corte
    Text {
        visible: f.alto
        anchors.right: parent.right; anchors.rightMargin: f.tema.corte + 8; y: f.height - 13
        text: "SYS.ISLAND // " + (f.ctx.modulo || "").toUpperCase()
        font.family: f.tema.fonteMono; font.pixelSize: 7; font.letterSpacing: 0.6; color: f.tema.texto3
    }
    Row {
        visible: f.alto
        x: f.tema.corte + 8; y: f.height - 10; spacing: 2
        Repeater { model: 18; Rectangle { required property int index; width: index * 7 % 3 === 0 ? 3 : 1; height: 3; color: f.tema.trilha } }
    }
}
