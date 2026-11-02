import QtQuick
import "../comum"

// Neomilitar: no anúncio, uma barra sólida cresce da esquerda no topo da gota (GIF "0a9826"), segura e recua; ao
// fechar, uma linha corta a gota na altura da base; na troca de módulo, uma faixa acende em degraus (75, 10, 90, 35, 100).
Item {
    id: e
    property var tema
    property var ctx
    readonly property color cor: ctx.nivel === "alerta" || ctx.nivel === "erro" ? tema.alerta : tema.acao
    Relogio { id: barra; ms: 640 }
    Relogio { id: troca; ms: 170 }
    Rectangle {
        visible: barra.running; height: 4
        x: barra.p > 0.72 ? e.width * (barra.p - 0.72) / 0.28 : 0
        width: e.width * Math.min(1, barra.p / 0.3) - x
        color: e.cor
    }
    Rectangle {
        visible: troca.running; x: 3; y: 0; width: e.width - 6; height: 2; color: e.tema.acao
        opacity: { const f = troca.p; return f < 0.2 ? 0.75 : f < 0.4 ? 0.1 : f < 0.6 ? 0.9 : f < 0.8 ? 0.35 : 1 }
    }
    Connections { target: e.ctx; function onPicoChanged() { if (!e.ctx.reduzir) barra.tocar() } }
    readonly property var _mod: e.ctx.modulo
    on_ModChanged: if (!e.ctx.reduzir) troca.tocar()
}
