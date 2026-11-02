import QtQuick

// Relógio de uma passada: "p" vai de 0 a 1 em "ms" e para (nada em laço). Por quadro, com passo limitado: o relógio
// das animações do Qt pula ao sair do repouso e o começo de um efeito curto se perderia.
FrameAnimation {
    id: r
    property real p: 0
    property real ms: 300
    readonly property bool andando: running
    signal terminou()
    function tocar(duracao) { if (duracao !== undefined) ms = duracao; p = 0; restart() }
    function zerar() { stop(); p = 0 }
    onTriggered: {
        p = Math.min(1, p + Math.min(frameTime, 0.05) * 1000 / Math.max(1, ms))
        if (p >= 1) { stop(); r.terminou() }
    }
}
