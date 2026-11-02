import QtQuick
import "../comum"

// Exacerbado em repouso: placa dura, borda de 2 px, um eco fino na secundária e o letreiro na base. Tudo o que treme
// está no Efeito; aqui só o estado (borda em alerta enquanto há anúncio).
Item {
    id: c
    property var tema
    property var ctx
    readonly property real k: Math.min(tema.corte, height / 2)
    readonly property bool alerta: !!ctx.evento && (ctx.nivel === "alerta" || ctx.nivel === "erro")
    readonly property color cor: alerta ? tema.alerta : tema.borda
    readonly property var caminho: {
        const w = width, h = height, m = 1
        return [Qt.point(m, 0), Qt.point(w - m, 0), Qt.point(w - m, h - k - m), Qt.point(w - k - m, h - m), Qt.point(m, h - m), Qt.point(m, 0)]
    }
    Contorno { anchors.fill: parent; pontos: c.caminho; preenchimento: c.tema.fundo; cor: c.cor; espessura: 2 }
    // o eco: deslocado para baixo e à direita, atrás da placa (a dupla borda dos painéis da referência)
    Contorno {
        x: 4; y: 4; z: -1; width: parent.width; height: parent.height; visible: c.height > 60
        pontos: c.caminho; cor: c.tema.texto3
    }
    // letreiro: etiqueta pendurada fora da placa (o conteúdo do núcleo vai até a base), com a marca em Rajdhani
    Rectangle {
        visible: c.height > 80
        x: 0; y: c.height - 1; width: Math.min(190, c.width * 0.5); height: 13
        color: c.cor
        Text {
            x: 6; anchors.verticalCenter: parent.verticalCenter
            text: "DATA//LINK"
            font.family: c.tema.fonteRotulo; font.weight: Font.Bold; font.pixelSize: 11; font.letterSpacing: 1.5
            color: c.tema.fundoForte
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Repeater { model: 8; Rectangle { width: 5; height: 7; color: c.tema.fundoForte; transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.5, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) } } }
        }
    }
}
