import QtQuick
import "../comum"

// Exacerbado: abrir e fechar com barras verticais de 3 quadros (GIF "cc9790", quadros 50–64) e golpe de glitch;
// anúncio em bloco cheio, com letreiro que passa uma vez e o brilho pulsando como o intercom "CALLING", e o bloco se
// dissolve em 700 ms deixando o texto do núcleo; troca de módulo com um golpe curto. Nada fica rodando.
Item {
    id: e
    property var tema
    property var ctx
    readonly property color cor: ctx.nivel === "alerta" || ctx.nivel === "erro" ? tema.alerta : tema.acao
    Glitch { id: gl; anchors.fill: parent; fonte: e.parent }
    Relogio { id: barras; ms: 120 }
    Relogio { id: bloco; ms: 700 }
    Repeater {
        model: 3
        Rectangle {
            required property int index
            visible: barras.running
            x: index === 1 ? e.width + 6 : index === 0 ? -8 : e.width + 12
            y: 0; width: index === 1 ? 4 : 2
            height: e.height * (index === 2 ? 0.5 : 0.9)
            color: index === 1 ? e.tema.acao : e.tema.texto
        }
    }
    // o bloco é do anúncio, na pílula: nunca toma a gota aberta
    Item {
        width: parent.width; height: Math.min(parent.height, e.ctx.alturaPilula + 28)
        visible: bloco.running
        clip: true
        // CALLING: 3 pulsos e dissolve
        readonly property real pulso: 0.62 + 0.38 * Math.abs(Math.cos(Math.min(1, bloco.p / 0.6) * 3 * Math.PI))
        opacity: 1 - Math.max(0, (bloco.p - 0.6) / 0.4)
        Rectangle { anchors.fill: parent; color: e.cor; opacity: parent.pulso }
        Rectangle { x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; color: "transparent"; border.color: e.tema.fundoForte }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: e.width - (e.width + width) * Math.min(1, bloco.p / 0.75)
            text: e.ctx.nivel !== "alerta" && e.ctx.nivel !== "erro" ? "INCOMING // INCOMING // INCOMING" : "ALERTA // ALERTA // ALERTA // ALERTA"
            font.family: e.tema.fonteRotulo; font.weight: Font.Bold; font.pixelSize: Math.min(30, parent.height * 0.74); font.letterSpacing: 2
            color: e.tema.fundoForte
        }
    }
    Connections {
        target: e.ctx
        function onAbertaChanged() { if (e.ctx.reduzir) return; barras.tocar(); gl.tocar(240, 1) }
        // "pico" sobe antes de o evento chegar ao ctx: lê "kind" e "aberta" no fim do ciclo
        function onPicoChanged() { if (!e.ctx.reduzir) Qt.callLater(e._anuncio) }
    }
    // HUD (volume, brilho) repete a cada tique: só o golpe curto; o bloco é para anúncio de verdade
    function _anuncio() {
        if (ctx.kind !== "hud" && !ctx.aberta) bloco.tocar()
        gl.tocar(180, ctx.kind === "hud" ? 0.35 : 0.8)
    }
    readonly property var _mod: e.ctx.modulo
    on_ModChanged: if (!e.ctx.reduzir) gl.tocar(160, 0.7)
}
