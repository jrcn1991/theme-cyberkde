import QtQuick

// Trilha de progresso; com aoBuscar, clicar busca.
Item {
    id: b
    property var ui
    property real razao: 0
    property string nivel: "ok"
    property bool tinta: false
    property var aoBuscar: null
    height: 4
    readonly property color corCheia: b.nivel === "alerta" ? b.ui.tema.alerta : b.nivel === "erro" ? b.ui.tema.erro : b.tinta ? b.ui.tinta : b.ui.tema.texto
    readonly property real fracao: Math.max(0, Math.min(1, b.razao))
    readonly property int nSeg: b.ui.segmentos
    // lisa, ou segmentada onde o tema pede
    Rectangle { visible: b.nSeg === 0; anchors.fill: parent; radius: 2; color: b.ui.tema.trilha }
    Rectangle { visible: b.nSeg === 0; height: parent.height; radius: 2; width: parent.width * b.fracao; color: b.corCheia }
    Row {
        visible: b.nSeg > 0
        anchors.fill: parent; spacing: 2
        Repeater {
            model: b.nSeg
            Rectangle {
                required property int index
                width: (b.width - 2 * (b.nSeg - 1)) / b.nSeg; height: parent.height
                color: index < Math.round(b.fracao * b.nSeg) ? b.corCheia : b.ui.tema.trilha
            }
        }
    }
    MouseArea { enabled: !!b.aoBuscar; anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: (m) => b.aoBuscar(Math.max(0, Math.min(1, (m.x - 6) / b.width))) }
}
