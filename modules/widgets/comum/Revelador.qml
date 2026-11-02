import QtQuick

// Mostra e esconde um controle de edição com uma montagem rápida (flicker de liga e desliga, ~110 ms).
// Escondido, o alvo fica invisível: o espaço volta para o conteúdo. Com o movimento em "mínimo", direto.
//   Revelador { alvo: meuItem; mostrar: condicao }
QtObject {
    id: r
    property Item alvo
    property bool mostrar: false
    property bool _pronto: false
    function _fixar(v) { if (alvo) { alvo.opacity = v; alvo.visible = v > 0 } }
    onMostrarChanged: {
        if (!alvo) return
        entra.stop(); sai.stop()
        if (!_pronto || Cores.reduzir) { _fixar(mostrar ? 1 : 0); return }
        if (mostrar) { alvo.visible = true; entra.start() } else sai.start()
    }
    onAlvoChanged: _fixar(mostrar ? 1 : 0)
    Component.onCompleted: { _fixar(mostrar ? 1 : 0); _pronto = true }
    property SequentialAnimation entra: SequentialAnimation {
        PropertyAction { target: r.alvo; property: "opacity"; value: 0.7 }
        PauseAnimation { duration: Cores.d(35) }
        PropertyAction { target: r.alvo; property: "opacity"; value: 0.15 }
        PauseAnimation { duration: Cores.d(35) }
        PropertyAction { target: r.alvo; property: "opacity"; value: 0.9 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: r.alvo; property: "opacity"; value: 1 }
    }
    property SequentialAnimation sai: SequentialAnimation {
        PropertyAction { target: r.alvo; property: "opacity"; value: 0.4 }
        PauseAnimation { duration: Cores.d(35) }
        PropertyAction { target: r.alvo; property: "opacity"; value: 0.85 }
        PauseAnimation { duration: Cores.d(35) }
        PropertyAction { target: r.alvo; property: "opacity"; value: 0 }
        PropertyAction { target: r.alvo; property: "visible"; value: false }
    }
}
