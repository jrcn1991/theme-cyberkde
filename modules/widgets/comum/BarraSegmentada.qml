import QtQuick

// Barra segmentada (0..1). Acima de "limiar" (0..1, opcional) os segmentos acesos ficam na cor de
// alerta. "vertical" para colunas (núcleos). A ponta acesa fica na secundária.
Item {
    id: b
    property real valor: 0
    property real limiar: 2
    property color cor: Cores.destaque
    property bool vertical: false
    property real tamSeg: 4
    property real vao: 2
    readonly property real _comp: vertical ? height : width
    readonly property int n: Math.max(3, Math.floor((_comp + vao) / (tamSeg + vao)))
    readonly property int acesos: Math.round(Math.max(0, Math.min(1, valor)) * n)
    readonly property color _corAtiva: valor >= limiar ? Cores.alerta : cor
    implicitHeight: vertical ? 40 : 8
    implicitWidth: vertical ? 6 : 120
    Repeater {
        model: b.n
        Rectangle {
            required property int index
            readonly property bool aceso: index < b.acesos
            x: b.vertical ? 0 : index * (b.tamSeg + b.vao)
            y: b.vertical ? b.height - (index + 1) * (b.tamSeg + b.vao) + b.vao : 0
            width: b.vertical ? b.width : b.tamSeg
            height: b.vertical ? b.tamSeg : b.height
            color: aceso ? (index === b.acesos - 1 && b.valor < 1 ? Cores.secundaria : b._corAtiva) : Cores.alfa(b.cor, 0.13)
            Behavior on color { ColorAnimation { duration: Cores.d(80) } }
        }
    }
}
