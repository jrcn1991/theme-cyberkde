pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

// Cores e ritmo dos widgets. As cores vêm do singleton Paleta (gerado pelo install_widgets com a
// paleta aplicada; o "cyberkde cor"/"corp" o regrava e o reinício do plasmashell que eles já fazem
// carrega as novas). Movimento: as durações seguem o AnimationDurationFactor do KDE (o "movimento"
// do tema). Nenhuma cor fixa aqui.
QtObject {
    id: c
    // ---- cores da corporação
    readonly property color destaque: Paleta.destaque
    readonly property color secundaria: Paleta.secundaria
    readonly property color alerta: Paleta.alerta
    readonly property color sucesso: Kirigami.Theme.positiveTextColor
    // ---- superfícies, da mais funda para a mais clara
    readonly property color fundo: Paleta.fundo
    readonly property color escuro: Paleta.fundo
    readonly property color painel: Paleta.painel
    readonly property color elevado: Paleta.elevado
    readonly property color linha: Paleta.linha
    // superfície dos cartões: perto do fundo da corporação (aplicada com a opacidade do widget)
    readonly property color cartao: mistura(Paleta.fundo, Paleta.painel, 0.45)
    function alfaSuperficie(op) { return Math.max(0, Math.min(1, op)) }
    // ---- texto (nunca branco puro: TXT1 do tema)
    readonly property color texto: Paleta.texto
    readonly property color texto2: Paleta.textoSecundario
    readonly property color texto3: Paleta.textoDesativado

    function alfa(cor, a) { const q = Qt.color(cor); return Qt.rgba(q.r, q.g, q.b, a) }
    function mistura(a, b, f) {
        const x = Qt.color(a), y = Qt.color(b)
        return Qt.rgba(x.r + (y.r - x.r) * f, x.g + (y.g - x.g) * f, x.b + (y.b - x.b) * f, 1)
    }
    // cor por nome de papel (notas): destaque | secundaria | alerta
    function papel(nome) { return nome === "secundaria" ? secundaria : nome === "alerta" ? alerta : destaque }

    // ---- contêiner do applet na área de trabalho (ItemContainer do Plasma): tamanho e edição
    function conteiner(item) {
        let p = item ? item.parent : null
        while (p) { if (p.editModeCondition !== undefined && p.editMode !== undefined && p.layout !== undefined) return p; p = p.parent }
        return null
    }
    // muda o tamanho do applet na área de trabalho, mantendo parado o canto mais perto da borda (à
    // direita cresce para a esquerda, embaixo cresce para cima) e sem sair da área; grava a geometria.
    // -> null sem contêiner; senão { mudou, w0, h0, direita, baixo }
    property Timer _gravar: Timer {
        property var layouts: []
        interval: 1200
        onTriggered: { const l = layouts; layouts = []; for (const x of l) x.save() }
    }
    function gravarLayout(l) { if (l && l.save) { _gravar.layouts.push(l); _gravar.restart() } }
    function redimensionar(item, w, h) {
        const c = conteiner(item)
        if (!c) return null
        const L = c.parent
        const W = L ? L.width : 0, H = L ? L.height : 0
        const w0 = c.width, h0 = c.height
        const direita = W > 0 && c.x + w0 / 2 > W / 2
        const baixo = H > 0 && c.y + h0 / 2 > H / 2
        // o layout da área de trabalho arredonda posição e tamanho para a grade dele: já pede assim,
        // para não brigar com ela (e não andar alguns pixels) a cada reinício
        const cw = c.layout && c.layout.cellWidth > 0 ? c.layout.cellWidth : 1
        const ch = c.layout && c.layout.cellHeight > 0 ? c.layout.cellHeight : 1
        w = Math.ceil(Math.round(w) / cw) * cw; h = Math.ceil(Math.round(h) / ch) * ch
        if (Math.abs(w0 - w) < 1 && Math.abs(h0 - h) < 1) return { mudou: false, w0: w0, h0: h0, direita: direita, baixo: baixo }
        let x = direita ? c.x + w0 - w : c.x
        let y = baixo ? c.y + h0 - h : c.y
        x = Math.round(x / cw) * cw; y = Math.round(y / ch) * ch
        if (W > 0) x = Math.max(0, Math.min(x, Math.floor((W - w) / cw) * cw))
        if (H > 0) y = Math.max(0, Math.min(y, Math.floor((H - h) / ch) * ch))
        c.x = Math.round(x); c.y = Math.round(y); c.width = w; c.height = h
        // o contêiner anima a mudança de posição: grava depois que ela termina (gravar já gravaria um
        // ponto do meio do caminho, e o widget voltaria para lá ao reiniciar)
        if (c.layout && c.layout.save) { _gravar.layouts.push(c.layout); _gravar.restart() }
        return { mudou: true, w0: w0, h0: h0, direita: direita, baixo: baixo }
    }

    // ---- movimento (Kirigami.Units já vem multiplicado pelo AnimationDurationFactor)
    readonly property real fator: Math.max(0, Kirigami.Units.longDuration / 200)
    readonly property bool reduzir: fator < 0.05
    function d(ms) { return Math.round(ms * fator) }

    // ---- fontes: títulos curtos no estilo do tema; leitura na fonte do sistema
    readonly property string fTitulo: "Rajdhani"
    readonly property string fIdentidade: "Orbitron"
    readonly property string fMono: "JetBrains Mono"
    readonly property string fTexto: Kirigami.Theme.defaultFont.family

    // ---- idioma
    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
}
