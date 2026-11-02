import QtQuick
import "temas/comum"

// A pílula fundida à barra do Plasma: o filete da barra desce, contorna a gota e volta, num traçado só, e o fundo é
// o da barra. Vale para os 4 temas (forma "pilula": curvas; "chanfro": 45°); fica no lugar da Casca do tema.
Item {
    id: f
    property var tema
    property var barra: ({})
    property real raio: 0
    readonly property real ombro: 4
    readonly property real w: Math.round(width)
    readonly property real h: Math.round(height)
    readonly property real y0: barra.altura - 0.5                  // o meio do pixel do filete
    readonly property real margem: ombro + 2
    readonly property bool chanfro: tema.forma === "chanfro"
    readonly property real r: Math.max(1, Math.min(chanfro ? tema.corte : raio, h - y0 - ombro - 0.5, w / 2))
    function arco(cx, cy, raio_, ini, fim) {
        const v = []
        for (let i = 0; i <= 8; i++) { const a = ini + (fim - ini) * i / 8; v.push(Qt.point(cx + raio_ * Math.cos(a), cy + raio_ * Math.sin(a))) }
        return v
    }
    readonly property var linha: {
        const m = margem, e = m + 0.5, d = m + w - 0.5, b = h - 0.5, o = ombro, y = y0, P = Math.PI
        if (chanfro) return [Qt.point(e - o - 0.5, y), Qt.point(e, y + o), Qt.point(e, b - r), Qt.point(e + r, b), Qt.point(d - r, b), Qt.point(d, b - r), Qt.point(d, y + o), Qt.point(d + o + 0.5, y)]
        return arco(e - o, y + o, o, -P / 2, 0)
            .concat(arco(e + r, b - r, r, P, P / 2), arco(d - r, b - r, r, P / 2, 0), arco(d + o, y + o, o, P, 3 * P / 2))
    }
    readonly property var forma: [Qt.point(margem - ombro, 0)].concat(linha, [Qt.point(margem + w + ombro, 0)])
    Contorno {
        x: -f.margem; width: f.w + 2 * f.margem; height: f.h + 1
        pontos: f.forma; fracao: 0; preenchimento: f.barra.fundo || f.tema.fundo
    }
    Contorno {
        x: -f.margem; width: f.w + 2 * f.margem; height: f.h + 1
        pontos: f.linha; cor: f.barra.cor || f.tema.acao
    }
}
