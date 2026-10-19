import QtQuick

// Quadrados soltos que piscam enquanto uma moldura se traça (os "placeholders" das janelas do
// Cyberpunk, que surgem espalhados entre 330 e 500 ms e somem quando o conteúdo chega). Guiado só
// pelo "progresso" da moldura (0..1): não tem animação própria nem custo em repouso.
Item {
    id: q
    property real progresso: 1
    property int n: 6
    property color cor: Tema.secundaria
    readonly property real semente: Math.random() * 1000
    anchors.fill: parent
    visible: progresso > 0.05 && progresso < 1 && !Tema.reduzir && width > 60 && height > 40

    function _r(i, k) { const v = Math.sin((i + 1) * 12.9898 + k * 78.233 + semente) * 43758.5453; return v - Math.floor(v) }

    Repeater {
        model: q.visible ? q.n : 0
        Rectangle {
            required property int index
            readonly property real lado: 6 + q._r(index, 3) * 12
            readonly property real nasce: 0.12 + q._r(index, 4) * 0.5
            readonly property real fase: q.progresso - nasce
            x: 8 + q._r(index, 1) * Math.max(0, q.width - lado - 16)
            y: 8 + q._r(index, 2) * Math.max(0, q.height - lado - 16)
            width: lado; height: lado
            color: q._r(index, 5) > 0.75 ? Tema.alfa(q.cor, 0.5) : "transparent"
            border.color: q.cor
            border.width: 1
            // acende em degraus (pisca 2 vezes) e some ao fim
            opacity: fase < 0 || fase > 0.38 ? 0 : (Math.floor(fase * 34) % 2 === 0 ? 0.9 : 0.3)
        }
    }
}
