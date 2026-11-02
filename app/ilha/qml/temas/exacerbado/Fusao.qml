import QtQuick

// Exacerbado fundido: o letreiro vai por dentro, sem pendurar para fora do filete; fechada, as listras de aviso.
Item {
    id: f
    property var tema
    property var ctx
    readonly property bool alto: height > 80
    readonly property color cor: ctx.nivel === "alerta" || ctx.nivel === "erro" ? tema.alerta : tema.acao
    Row {
        visible: !f.alto && f.width > 170
        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 3
        Repeater {
            model: 4
            Rectangle { width: 4; height: 9; color: f.cor; transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.5, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) } }
        }
    }
    Rectangle {
        visible: f.alto
        x: f.tema.corte + 6; y: f.height - 16; width: Math.min(170, f.width * 0.4); height: 12
        color: f.cor
        Text {
            x: 6; anchors.verticalCenter: parent.verticalCenter
            text: "DATA//LINK"
            font.family: f.tema.fonteRotulo; font.weight: Font.Bold; font.pixelSize: 10; font.letterSpacing: 1.5
            color: f.tema.fundoForte
        }
    }
}
