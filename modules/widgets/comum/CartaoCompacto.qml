import QtQuick

// Cartão dos tamanhos pequenos: superfície chanfrada (na opacidade do widget), marcador lateral e o
// conteúdo, que tem o espaço todo (os controles de edição ficam na faixa do Tamanhos).
Item {
    id: k
    property real opacidade: 0.95
    // montagem ao aparecer / trocar de tamanho: flicker de liga e desliga
    function montar() {
        if (Cores.reduzir) { opacity = 1; return }
        acende.restart()
    }
    Component.onCompleted: montar()
    SequentialAnimation {
        id: acende
        PropertyAction { target: k; property: "opacity"; value: 0.15 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: k; property: "opacity"; value: 0.8 }
        PauseAnimation { duration: Cores.d(33) }
        PropertyAction { target: k; property: "opacity"; value: 0.3 }
        PauseAnimation { duration: Cores.d(33) }
        PropertyAction { target: k; property: "opacity"; value: 1 }
    }
    property real margem: 10
    default property alias conteudo: area.data
    readonly property bool _hover: ma.containsMouse

    Chanfro {
        anchors.fill: parent
        corte: 9
        preenchimento: Cores.alfa(Cores.cartao, Cores.alfaSuperficie(k.opacidade))
        borda: Cores.alfa(Cores.destaque, k._hover ? 0.9 : 0.45)
    }
    Rectangle { x: 0; y: 10; width: 3; height: Math.min(22, parent.height - 20); color: Cores.destaque }
    Cantoneiras { anchors.margins: -3; cor: Cores.alfa(Cores.destaque, k._hover ? 0.6 : 0.3); tamanho: 5 }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton            // só o realce da borda
    }
    Item {
        id: area
        x: k.margem; y: k.margem
        width: k.width - 2 * k.margem
        height: k.height - 2 * k.margem
    }
}
