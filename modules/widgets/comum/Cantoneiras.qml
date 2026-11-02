import QtQuick

// Cantoneiras finas nos quatro cantos (moldura interrompida do UI kit).
Item {
    id: c
    property color cor: Cores.destaque
    property real tamanho: 8
    property real espessura: 1
    anchors.fill: parent
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool dir: index === 1 || index === 2
            readonly property bool baixo: index >= 2
            x: dir ? c.width - c.tamanho : 0
            y: baixo ? c.height - c.tamanho : 0
            width: c.tamanho; height: c.tamanho
            Rectangle { color: c.cor; width: c.tamanho; height: c.espessura; y: parent.baixo ? c.tamanho - c.espessura : 0 }
            Rectangle { color: c.cor; width: c.espessura; height: c.tamanho; x: parent.dir ? c.tamanho - c.espessura : 0 }
        }
    }
}
