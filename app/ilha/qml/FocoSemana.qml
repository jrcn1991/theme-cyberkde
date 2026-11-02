import QtQuick

// Os sete dias de foco: uma barra por dia, hoje à direita. Compacto, sem as letras, e só com algum foco.
Column {
    id: f
    property var ui
    property bool compacto: false
    readonly property var r: ilha.foco || ({})
    readonly property var dias: r.semana || []
    readonly property int total: dias.reduce((a, b) => a + b, 0)
    readonly property int maior: Math.max.apply(null, dias.concat([1]))
    visible: dias.length === 7 && (!compacto || total > 0)
    spacing: 3
    Row {
        width: parent.width; height: f.compacto ? 22 : 56; spacing: 3
        Repeater {
            model: f.dias
            Item {
                required property int modelData
                required property int index
                width: (parent.width - 18) / 7; height: parent.height
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; radius: 2
                    height: Math.max(2, parent.height * parent.modelData / f.maior)
                    color: parent.index === 6 ? f.ui.tinta : parent.modelData > 0 ? f.ui.tema.texto3 : f.ui.tema.trilha
                }
            }
        }
    }
    Row {
        visible: !f.compacto
        width: parent.width; spacing: 3
        Repeater {
            model: 7
            Text {
                required property int index
                width: (parent.width - 18) / 7; horizontalAlignment: Text.AlignHCenter
                text: new Date(Date.now() - (6 - index) * 86400000).toLocaleDateString(Qt.locale(), "ddd").charAt(0).toUpperCase()
                color: f.ui.tema.texto3; font.family: f.ui.tema.fonte; font.pixelSize: 10
            }
        }
    }
    Text {
        width: parent.width; elide: Text.ElideRight
        text: f.ui.txt("{valor} hoje", { valor: (f.r.hoje || 0) + " min" }) + (f.r.sequencia ? f.ui.txt(" · {valor} seguidos", { valor: f.r.sequencia }) : "")
        color: f.ui.tema.texto3; font.family: f.ui.tema.fonte; font.pixelSize: 11
    }
}
