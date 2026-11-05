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
    // Neomilitar: a ordem do GIF "cc9790", no ritmo de painel do ui-kit (~220 ms): abre e fecha o tempo todo
    forma: "chanfro"
    corte: 10
    fundo: _al(_f, 0.96)
    fundoForte: _f
    borda: _al(_d, 0.9)
    bordaForte: _d
    trilha: _al(_d, 0.3)
    raioAberto: 0
    raioCartao: 4
    raioControle: 2
    sombraCor: Qt.rgba(0, 0, 0, 0.5)
    fonteRotulo: "Rajdhani"
        // corpo próprio (docs/interno/ilha-temas.md, seção 8): quando o núcleo lê, sem cápsulas nem círculos
    readonly property real raioAba: 2
    readonly property real raioIcone: 2
    readonly property int segmentosBarra: 14
    // o código de barras do Fusao.qml (14 px da borda, 16 px de largura) e 8 px até o conteúdo
    reservaFusao: 26
    tempos: ({ abrir: 220, fechar: 150, anuncio: 200, conteudoEntra: 110, conteudoSai: 70, chegada: 240 })
    curvas: ({ abrir: [[0.25, 0.7], [0.5, 0.93], [1, 1]], fechar: [[0.3, 0.75], [0.6, 0.97], [1, 1]], anuncio: [[0.2, 0.7], [0.5, 0.95], [1, 1]], entrar: "entrar", sair: "sair", chegada: [[0.2, 0.7], [0.5, 0.95], [1, 1]] })
    // Traço: a gota nasce inteira e quem a revela é a moldura traçada
    function movimento(id) { return id === "traco" ? { tempos: { abrir: 60, conteudoEntra: 130 } } : null }
}
