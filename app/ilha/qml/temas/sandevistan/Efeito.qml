import QtQuick
import "../comum"

// Sandevistan: ao abrir, fechar e anunciar, a gota dispara e o tempo quase para (a curva do Tema): ficam no ar três
// fantasmas dela, em fatias, cada um numa cor da paleta, com o halo na cor do rastro. Crescendo (abrir, anunciar), são
// clones da gota no fim do disparo, deslocados para os lados; encolhendo (fechar), fotos de três instantes do caminho.
// Quando o tempo volta, de uma vez, vem a onda em duas cores separadas e os fantasmas se recolhem para a gota em
// degraus. Sem o Glitch comum: ele separa canais RGB, e aqui toda cor sai da paleta. Trocar de módulo é um disparo curto para o lado. Até ~380 ms; em repouso, nada existe
// (as fotos são soltas no fim). Movimento reduzido: o núcleo nem carrega o Efeito.
Item {
    id: e
    property var tema
    property var ctx
    // a gota: o núcleo põe o Efeito nela; se ficou no Loader que o carregou (cenas de teste), é o pai dele
    readonly property Item gota: parent && parent.item === e ? parent.parent : parent
    readonly property color c1: tema.acao
    readonly property color c2: tema.corRastro
    property real dur: 260          // o tempo do momento na gota
    property real volta: 0.78       // onde a curva volta a andar (fração de dur)
    property bool lado: false       // troca de módulo: rastro lateral, sem mudar a geometria
    property bool expande: true     // abrir e anunciar crescem; fechar encolhe
    property real dir: 1
    property var cap: [null, null, null]
    property point aqui: Qt.point(0, 0)
    readonly property real t: rel.p * rel.ms
    // tempos do efeito (ms): entre fotos, quando os fantasmas aparecem, o recolher, a onda, o halo, a troca lateral
    readonly property var ms: ({ quadro: 16, foto: 14, mostra: 46, recolhe: 110, onda: 160, halo: 40, apaga: 60, resto: 170, lado: 200, ladoIni: 30, ladoAnda: 150 })
    readonly property real tVolta: dur * volta
    readonly property real tFoto: dur * 0.17           // o fim do disparo, na curva do Tema
    readonly property real ativo: rel.running ? 1 : 0

    ShaderEffectSource { id: f0; live: false; recursive: false; visible: false; hideSource: false }
    ShaderEffectSource { id: f1; live: false; recursive: false; visible: false; hideSource: false }
    ShaderEffectSource { id: f2; live: false; recursive: false; visible: false; hideSource: false }
    readonly property var fotos: [f0, f1, f2]
    Relogio {
        id: rel
        onPChanged: e._quadro()
        onTerminou: { for (const f of e.fotos) f.sourceItem = null; e.cap = [null, null, null] }
    }
    function _quadro() {
        // o tempo direto do relógio: ao recomeçar, "p" volta a 0 antes de a ligação de "t" se refazer
        const t = rel.p * rel.ms
        const o = gota.mapToItem(null, 0, 0); aqui = Qt.point(o.x, o.y)
        if (lado) { if (!cap[0]) _foto(0); return }
        // crescendo: uma foto no fim do disparo; encolhendo: três instantes do caminho, antes de qualquer fantasma
        // aparecer (senão um entraria na foto do seguinte)
        if (expande) { if (!cap[0] && t >= tFoto) _foto(0) }
        else for (let k = 0; k < 3; k++) if (!cap[k] && t >= k * ms.foto) { _foto(k); break }
    }
    function _foto(k) {
        fotos[k].sourceItem = gota; fotos[k].scheduleUpdate()
        const c = cap.slice(); c[k] = { x: aqui.x, y: aqui.y, w: gota.width, h: gota.height }; cap = c
    }
    function _rastro(momento) {
        if (ctx.reduzir || ctx.movimento === "nenhuma") return
        dur = tema.tempo(ctx.movimento, momento); volta = tema.voltaEm[momento] || 0.78
        lado = false; expande = momento !== "fechar"; cap = [null, null, null]
        rel.tocar(dur * volta + ms.resto)
    }
    function _lateral() {
        if (ctx.reduzir || rel.running) return
        lado = true; dir = -dir; cap = [null, null, null]
        rel.tocar(ms.lado)
    }

    // os fantasmas: o mais antigo é o mais fraco
    Repeater {
        model: 3
        ShaderEffect {
            id: fa
            required property int index
            readonly property var c: e.lado || e.expande ? e.cap[0] : e.cap[index]
            // recolher: depois da volta, em 3 degraus, para onde a gota está agora
            readonly property real s: e.lado ? Math.floor(Math.min(1, Math.max(0, (e.t - e.ms.ladoIni) / e.ms.ladoAnda)) * 4) / 4
                                             : Math.floor(Math.min(1, Math.max(0, (e.t - e.tVolta) / e.ms.recolhe)) * 3) / 3
            readonly property real dx: (e.lado ? e.dir * (3 - index) * 9 : e.expande ? [-30, 20, -11][index] : 0) * (1 - s)
            // presente (com tamanho 0) desde a foto: um ShaderEffectSource com live: false só desenha a textura
            // quando um consumidor visível a pede, e ela precisa sair no quadro da foto
            readonly property bool mostra: e.lado ? e.t >= e.ms.ladoIni : e.expande ? e.t >= e.tFoto + e.ms.quadro : e.t >= e.ms.mostra
            visible: !!c && e.ativo > 0 && s < 1
            x: c ? (c.x + (e.aqui.x - c.x) * s) - e.aqui.x + dx : 0
            y: c ? (c.y + (e.aqui.y - c.y) * s) - e.aqui.y : 0
            width: c && mostra ? c.w + (e.gota.width - c.w) * s : 0
            height: c && mostra ? c.h + (e.gota.height - c.h) * s : 0
            z: -1 - index
            opacity: (e.expande && !e.lado ? [0.5, 0.6, 0.72] : [0.18, 0.26, 0.36])[e.lado ? 2 - index : index] * (1 - s * 0.6)
            readonly property var fonte: e.lado ? f0 : e.fotos[index]
            readonly property size tam: Qt.size(width, height)
            readonly property color cor: index === 1 ? e.c1 : e.c2
            readonly property real come: s
            readonly property vector4d dentro: Qt.vector4d(-x, -y, -x + e.width, -y + e.height)
            readonly property real passo: index * 5 + (e.t > e.tVolta ? Math.floor((e.t - e.tVolta) / 33) : 0)
            fragmentShader: Qt.resolvedUrl("fantasma.frag.qsb")
        }
    }
    // halo enquanto o tempo está parado; a onda quando ele volta
    ShaderEffect {
        readonly property real m: 34
        x: -m; y: -m; width: e.width + 2 * m; height: e.height + 2 * m
        z: -0.5
        readonly property real ini: e.expande ? e.tFoto + e.ms.quadro : e.ms.mostra
        visible: e.ativo > 0 && !e.lado && e.t >= ini
        readonly property size tam: Qt.size(width, height)
        readonly property size caixa: Qt.size(e.width, e.height)
        readonly property real corte: Math.min(e.tema.corte, e.height / 2)
        readonly property real halo: e.t < e.tVolta ? Math.min(1, (e.t - ini) / e.ms.halo) : Math.max(0, 1 - (e.t - e.tVolta) / e.ms.apaga)
        readonly property real onda: e.t >= e.tVolta ? Math.min(1, (e.t - e.tVolta) / e.ms.onda) : -1
        readonly property real topo: e.ctx.fusao ? 1 : 0
        readonly property color cor1: e.c1
        readonly property color cor2: e.c2
        fragmentShader: Qt.resolvedUrl("onda.frag.qsb")
    }

    Connections {
        target: e.ctx
        function onAbertaChanged() { e._rastro(e.ctx.aberta ? "abrir" : "fechar") }
        // "pico" sobe antes de o evento chegar ao ctx: lê "kind" e "aberta" no fim do ciclo
        function onPicoChanged() { if (!e.ctx.reduzir) Qt.callLater(e._anuncio) }
    }
    // HUD (volume, brilho) repete a cada tique: nada; o rastro é para anúncio de verdade
    function _anuncio() {
        if (ctx.kind !== "hud" && !ctx.aberta) _rastro("anuncio")
    }
    readonly property var _mod: e.ctx.modulo
    on_ModChanged: if (e.ctx.aberta) e._lateral()
}
