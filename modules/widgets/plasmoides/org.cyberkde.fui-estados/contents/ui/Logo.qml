import QtQuick
import "comum"

// Logo no canto de baixo à direita: o arquivo da corporação (chave "logo", que o CLI pode preencher com o
// logo da corporação em uso) ou, sem ele, o emblema da referência (o "V" de traços) com o nome curto.
Item {
    id: g
    property var d
    property real k: 1
    readonly property string arquivo: d ? d.logo : ""
    Image {
        id: img
        visible: g.arquivo !== "" && status === Image.Ready
        anchors.fill: parent
        source: g.arquivo === "" ? "" : (g.arquivo.startsWith("/") ? "file://" + g.arquivo : g.arquivo)
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Item {
        visible: !img.visible
        anchors.fill: parent
        Canvas {
            width: Math.round(parent.width * 0.6); height: Math.round(width * 0.8)
            x: Math.round((parent.width - width) / 2); y: Math.round(g.k * 4)
            onPaint: {
                const c = getContext("2d"); c.reset()
                const w = width, h = height
                c.strokeStyle = Cores.texto; c.lineWidth = Math.max(1, Math.round(1.6 * g.k))
                c.beginPath(); c.moveTo(1, 2); c.lineTo(w - 1, 2); c.lineTo(w / 2, h - 1); c.closePath(); c.stroke()
                c.beginPath()
                for (const f of [0.27, 0.4, 0.5, 0.6, 0.73]) { c.moveTo(w * f, 2); c.lineTo(w / 2, h * 0.85) }
                c.stroke()
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(parent.height * 0.62)
            text: g.d ? g.d.corpCodigo : "CYKDE"
            font.family: Cores.fIdentidade; font.pixelSize: Math.max(10, Math.round(9 * g.k)); font.weight: Font.Bold
            color: Cores.texto
        }
    }
}
