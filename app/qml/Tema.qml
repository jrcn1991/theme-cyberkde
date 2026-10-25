pragma Singleton
import QtQuick

// Cores, medidas, fontes e tempos do painel. Valores de tokens/cyberkde.json.
// A cor de destaque vem da corporação em uso; o ciano é a secundária (foco e dados).
Item {
    id: t

    // ---- estado
    property bool reduzir: false            // "reduzir animações" (preferência do painel)
    property bool efeitos: true             // false no renderizador por software (sem shaders)

    // Paleta da corporação: destaque, secundária (no lugar do ciano), alerta e fundo. A do sistema vem
    // do backend; a prévia (mouse sobre um cartão, seletor de cor, aplicação em andamento) a substitui.
    property var paletaSistema: ({ destaque: "#F75049", secundaria: "#5EF6FF", alerta: "#FB932E", fundo: "#0E0E17" })
    property var paletaPrevia: null
    readonly property bool emPrevia: paletaPrevia !== null
    readonly property var paletaAlvo: emPrevia ? paletaPrevia : paletaSistema
    readonly property color alvo: paletaAlvo.destaque            // cor pedida (para mostrar o hex)

    // Cores animadas: a interface inteira acompanha a troca. Destaque, secundária e alerta escuros
    // demais (como o azul #2570D4) são clareados até 4,5:1 sobre a base, como o tema faz no sistema.
    property color destaque: legivel(paletaAlvo.destaque)
    property color secundaria: legivel(paletaAlvo.secundaria)
    property color alerta: legivel(paletaAlvo.alerta)
    property color fundo: paletaAlvo.fundo
    Behavior on destaque { ColorAnimation { duration: t.reduzir ? 0 : 360; easing.type: Easing.OutCubic } }
    Behavior on secundaria { ColorAnimation { duration: t.reduzir ? 0 : 360; easing.type: Easing.OutCubic } }
    Behavior on alerta { ColorAnimation { duration: t.reduzir ? 0 : 360; easing.type: Easing.OutCubic } }
    Behavior on fundo { ColorAnimation { duration: t.reduzir ? 0 : 360; easing.type: Easing.OutCubic } }

    // ---- superfícies: derivadas do fundo da corporação, clareando rumo ao TXT1 (com o fundo
    // #0E0E17 dão exatamente as superfícies de tokens/cyberkde.json)
    readonly property color base: mistura(fundo, texto, 0.02)
    readonly property color painel: mistura(fundo, texto, 0.05)
    readonly property color elevado: mistura(fundo, texto, 0.085)
    readonly property color entrada: mistura(fundo, texto, 0.03)
    readonly property color alternado: mistura(fundo, texto, 0.04)
    readonly property color linha: mistura(fundo, texto, 0.17)

    // ---- cores fixas
    readonly property color texto: "#DCDCE4"       // nunca branco puro em texto
    readonly property color texto2: "#A9A9BA"
    readonly property color texto3: "#76768A"
    readonly property color sucesso: "#1DED83"
    // erros usam o alerta da corporação, como no sistema (tokens/corporacoes.json: "alerta" = erros)
    readonly property color erro: alerta
    readonly property color escuro: "#0E0E17"      // texto sobre preenchimento de destaque
    readonly property color escurecer: "#05050B"   // fundo atrás dos modais

    function alfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function luminancia(c) {
        const f = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function legivel(c) {
        c = Qt.color(c)
        for (let k = 0; k <= 1.0001; k += 0.05) {
            const m = mistura(c, Qt.color("#FFFFFF"), k)
            if (luminancia(m) >= 0.205) return m
        }
        return c
    }
    function mistura(a, b, f) {
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1)
    }
    readonly property color linhaMarca: alfa(destaque, 0.35)
    readonly property color hover: alfa(destaque, 0.10)
    readonly property color selecao: alfa(destaque, 0.20)
    readonly property color pressionado: alfa(destaque, 0.30)

    // ---- geometria (px lógicos; o Qt cuida do HiDPI)
    readonly property int u: 4
    readonly property int chanfroP: 4
    readonly property int chanfro: 6
    readonly property int chanfroG: 12
    readonly property int marcador: 3

    // ---- fontes: Orbitron e Rajdhani só em títulos curtos e rótulos; leitura na fonte do sistema.
    readonly property string fIdentidade: "Orbitron"
    readonly property string fRotulo: "Rajdhani"
    readonly property string fTexto: Qt.application.font.family
    readonly property string fMono: "JetBrains Mono"

    // ---- tempos (ms); zerados com "reduzir animações"
    function d(ms) { return reduzir ? 0 : ms }
    readonly property int press: d(60)
    readonly property int micro: d(80)
    readonly property int rapido: d(140)
    readonly property int padrao: d(220)
    readonly property int fechar: d(160)
    readonly property int modal: d(240)
    readonly property int contexto: d(320)
}
