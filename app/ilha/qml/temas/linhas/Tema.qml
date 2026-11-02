import QtQuick
import "../.."

TemaBase {
    id: t
    readonly property color _d: paleta.destaque || "#F75049"
    readonly property color _s: paleta.secundaria || "#DCDCE4"
    readonly property color _a: paleta.alerta || "#FB932E"
    readonly property color _f: paleta.fundo || "#0E0E17"
    function _al(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    texto: _s
    texto2: _al(_s, 0.74)
    texto3: _al(_s, 0.58)
    texto4: _al(_s, 0.42)
    alerta: _a
    erro: _a
    acao: _d
    acaoFraca: _al(_d, 0.24)
    ligado: _d
    ligadoTexto: _f
    hover: _al(_s, 0.07)
    ativo: _al(_d, 0.18)
    // Linhas: fundo discreto, um fio fino e curvas calmas
    fundo: _al(_f, 0.9)
    fundoForte: _f
    borda: _al(_d, 0.85)
    bordaForte: _d
    trilha: _al(_d, 0.25)
    raioAberto: 16
    raioCartao: 10
    raioControle: 8
    sombraCor: "transparent"
    tempos: ({ abrir: 220, fechar: 160, anuncio: 220, conteudoEntra: 130, conteudoSai: 80, chegada: 280 })
    // tabela própria e curta: a "assentar" de Curvas.js em BezierSpline passou do alvo e corrompeu o heap nos testes
    readonly property var _calma: [[0.25, 0.68], [0.5, 0.92], [1, 1]]
    curvas: ({ abrir: _calma, fechar: _calma, anuncio: _calma, entrar: "entrar", sair: "sair", chegada: _calma })
}
