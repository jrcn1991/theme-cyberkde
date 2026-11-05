import QtQuick

// Tokens de um tema da ilha: ver docs/interno/ilha-temas.md. Os padrões são os do tema "halo".
QtObject {
    id: t
    property var paleta: ({})
    property bool reduzir: false
    property string estilo: "preto"

    // ---- superfície
    property color fundo: "#000000"
    property color fundoForte: "#000000"
    property color borda: Qt.rgba(1, 1, 1, 0.08)
    property color bordaForte: Qt.rgba(1, 1, 1, 0.14)
    property color hover: Qt.rgba(1, 1, 1, 0.06)
    property color ativo: Qt.rgba(1, 1, 1, 0.12)
    property color trilha: Qt.rgba(1, 1, 1, 0.14)
    // ---- texto
    property color texto: "#DCDCE4"
    property color texto2: Qt.rgba(0.863, 0.863, 0.894, 0.72)
    property color texto3: Qt.rgba(0.863, 0.863, 0.894, 0.56)
    property color texto4: Qt.rgba(0.863, 0.863, 0.894, 0.40)
    property string fonte: Qt.application.font.family
    property string fonteMono: "JetBrains Mono"
    property string fonteRotulo: Qt.application.font.family
    // ---- semânticas
    property color ok: "#30D158"
    property color alerta: "#FF9F0A"
    property color erro: "#FF453A"
    property color acao: "#0A84FF"
    property color acaoFraca: Qt.rgba(0.04, 0.52, 1, 0.24)
    property color ligado: "#DCDCE4"
    property color ligadoTexto: "#000000"
    property color tinta: "#78E2B0"
    // ---- forma
    property string forma: "pilula"          // pilula | chanfro
    property real corte: 10
    // px da ponta direita da pílula fundida e fechada que o Fusao.qml do tema ocupa: o núcleo alarga a pílula e afasta
    // o conteúdo (espectro, título) dali. 0 = o Fusao não desenha nada na pílula fechada.
    property real reservaFusao: 0
    property real larguraAberta: 488
    property real raioAberto: 40
    property real raioCartao: 24
    property real raioControle: 12
    // ---- sombra
    property color sombraCor: Qt.rgba(0, 0, 0, 0.55)
    property real sombraRaio: 28
    property real sombraY: 10
    // ---- vidro (sem desfoque: tinta translúcida sobre o que está atrás)
    property color vidroFundo: Qt.rgba(0.06, 0.06, 0.06, 0.72)
    property color vidroPiso: Qt.rgba(0, 0, 0, 0.86)
    property color vidroBorda: Qt.rgba(1, 1, 1, 0.2)
    property color vidroBordaFraca: Qt.rgba(1, 1, 1, 0.1)
    // ---- movimento
    property var tempos: ({ abrir: 480, fechar: 380, anuncio: 420, conteudoEntra: 200, conteudoSai: 180, chegada: 600 })
    property var curvas: ({ abrir: "gota", fechar: "assentar", anuncio: "viva", entrar: "entrar", sair: "sair", chegada: "viva" })
    // variações do tema: devolve { tempos, curvas } parciais, ou null
    function movimento(id) { return null }

    // ---- o que o núcleo usa
    function _base(id) {
        if (id === "elastico") return { curvas: { abrir: "gelatina", anuncio: "gelatina" } }
        if (id === "desliza") return { tempos: { abrir: 260, fechar: 260, chegada: 0 }, curvas: { abrir: "assentar", fechar: "assentar", anuncio: "assentar" } }
        if (id === "expandir") return { tempos: { chegada: 0 } }
        if (id === "nenhuma") return { tempos: { abrir: 0, fechar: 0, anuncio: 0, chegada: 0 } }
        return null
    }
    function tempo(mov, chave) {
        if (reduzir && chave !== "conteudoEntra" && chave !== "conteudoSai") return 0
        const m = movimento(mov) || _base(mov)
        return m && m.tempos && m.tempos[chave] !== undefined ? m.tempos[chave] : tempos[chave]
    }
    function curva(mov, chave) {
        const m = movimento(mov) || _base(mov)
        return m && m.curvas && m.curvas[chave] !== undefined ? m.curvas[chave] : curvas[chave]
    }
}
