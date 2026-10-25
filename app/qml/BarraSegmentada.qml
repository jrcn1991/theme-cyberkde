import QtQuick

// Barra de progresso segmentada. "valor" de 0 a 1 acende os segmentos da esquerda para a direita
// (cada um com 80 ms de transição, o que dá a sensação de carga); o segmento da frente brilha em
// ciano. "indeterminado" corre um bloco de segmentos enquanto não se sabe o total.
Item {
    id: b
    property real valor: 0
    property bool indeterminado: false
    property color cor: Tema.destaque
    property real larguraSeg: 6
    property real vao: 3
    readonly property int n: Math.max(4, Math.floor((width + vao) / (larguraSeg + vao)))
    readonly property int acesos: Math.round(Math.max(0, Math.min(1, valor)) * n)
    property int _cabeca: 0

    implicitHeight: 12

    Timer {
        running: b.indeterminado && b.visible
        interval: Tema.reduzir ? 400 : 45
        repeat: true
        onTriggered: b._cabeca = (b._cabeca + 1) % (b.n + 8)
    }

    Row {
        anchors.fill: parent
        spacing: b.vao
        Repeater {
            model: b.n
            Rectangle {
                required property int index
                readonly property bool aceso: b.indeterminado
                    ? (index <= b._cabeca && index > b._cabeca - 8)
                    : index < b.acesos
                readonly property bool frente: !b.indeterminado ? index === b.acesos - 1 && b.valor < 1 : index === b._cabeca
                width: b.larguraSeg
                height: b.height
                color: frente ? Tema.secundaria : (aceso ? b.cor : Tema.alfa(b.cor, 0.12))
                Behavior on color { enabled: !b.indeterminado; ColorAnimation { duration: Tema.micro } }
            }
        }
    }
}
