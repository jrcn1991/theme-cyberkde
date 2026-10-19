import QtQuick

// O ícone de uma escolha: o ícone quadrado da corporação ou, sem ele (Padrão, Personalizada), os
// quatro blocos do tema na cor de destaque.
// Com "recorte" (área opaca medida pelo backend), o tamanho é normalizado pela área visível: a caixa
// opaca de todo ícone fica com a área de um quadrado de 86% do "tamanho", limitada a 96% da altura e
// 1,7× a largura. Assim um ícone largo e baixo (Zetatech) não parece menor que um redondo (Arasaka).
// Sem recorte, a imagem ocupa o quadro inteiro, como o botão do menu de verdade.
Item {
    id: i
    property url source
    property color cor: Tema.destaque
    property var recorte: null
    property real tamanho: 32

    readonly property bool _rec: !!recorte && source != "" && recorte.w > 0 && recorte.h > 0
    readonly property real _ra: _rec ? (recorte.w * recorte.a) / recorte.h : 1
    readonly property real _wv0: 0.86 * tamanho * Math.sqrt(_ra)
    readonly property real _hv0: 0.86 * tamanho / Math.sqrt(_ra)
    readonly property real _k: Math.min(1, 0.96 * tamanho / _hv0, 1.7 * tamanho / _wv0)
    readonly property real larguraVisivel: _wv0 * _k
    readonly property real alturaVisivel: _hv0 * _k

    implicitWidth: _rec ? Math.max(tamanho, larguraVisivel) : tamanho
    implicitHeight: tamanho

    Image {
        visible: i.source != ""
        // com recorte: a imagem inteira é dimensionada para a caixa opaca ter o tamanho visível
        // calculado, e posicionada para essa caixa ficar centrada
        readonly property real dw: i._rec ? i.larguraVisivel / i.recorte.w : i.width
        readonly property real dh: i._rec ? i.alturaVisivel / i.recorte.h : i.height
        width: dw; height: dh
        x: i._rec ? i.width / 2 - (i.recorte.x + i.recorte.w / 2) * dw : 0
        y: i._rec ? i.height / 2 - (i.recorte.y + i.recorte.h / 2) * dh : 0
        source: i.source
        sourceSize.width: dw * 2
        fillMode: i._rec ? Image.Stretch : Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
    Grid {
        visible: i.source == ""
        anchors.centerIn: parent
        columns: 2
        spacing: Math.max(1, i.tamanho * 0.1)
        Repeater {
            model: 4
            Rectangle {
                width: i.tamanho * 0.42; height: width
                radius: width * 0.14
                color: i.cor
            }
        }
    }
}
