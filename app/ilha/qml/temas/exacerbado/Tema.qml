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
    // Exacerbado: degraus duros (o tempo da gota é curto) e tudo o mais no Efeito; em repouso, placa dura e estática
    forma: "chanfro"
    corte: 12
    fundo: _al(_f, 0.98)
    fundoForte: _f
    borda: _d
    bordaForte: _d
    trilha: _al(_d, 0.35)
    raioAberto: 0
    raioCartao: 0
    raioControle: 0
    sombraCor: _al(_d, 0.3)
    fonteRotulo: "Rajdhani"
        // corpo próprio (docs/interno/ilha-temas.md, seção 8): quando o núcleo lê, sem cápsulas nem círculos
    readonly property real raioAba: 0
    readonly property real raioIcone: 0
    readonly property int segmentosBarra: 10
    // os 4 traços do Fusao.qml (12 px da borda, ~30 px de largura com a inclinação) e 8 px até o conteúdo
    reservaFusao: 38
    tempos: ({ abrir: 200, fechar: 130, anuncio: 140, conteudoEntra: 100, conteudoSai: 60, chegada: 180 })
    readonly property var _degraus: [[0.17, 0.1], [0.171, 0.34], [0.34, 0.36], [0.341, 0.62], [0.55, 0.64], [0.551, 0.9], [0.75, 0.92], [0.751, 1], [1, 1]]
    curvas: ({ abrir: _degraus, fechar: [[0.5, 0.8], [0.501, 0.98], [1, 1]], anuncio: _degraus, entrar: "entrar", sair: "sair", chegada: _degraus })
    function movimento(id) { return id === "corte" ? { tempos: { abrir: 90, fechar: 70, anuncio: 70 } } : null }
}
