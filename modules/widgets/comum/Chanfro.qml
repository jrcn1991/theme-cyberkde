import QtQuick
import QtQuick.Shapes

// Superfície com cantos cortados a 45° (canto de cima à esquerda e de baixo à direita). "traco" < 1
// desenha só parte do contorno (montagem: duas linhas que saem do canto e se encontram no oposto).
Shape {
    id: s
    property real corte: 8
    property color preenchimento: Cores.painel
    property color borda: Cores.linha
    property real espessura: 1
    property real traco: 1
    // Sem Shape.CurveRenderer: na janela da área de trabalho do Plasma em Wayland ele pinta o
    // preenchimento claro e "lavado" (mesmo opaco), e os widgets pareciam transparentes.

    readonly property var pontos: {
        const w = width, h = height, c = Math.min(corte, w / 2, h / 2), m = espessura / 2
        return [Qt.point(m, m + c), Qt.point(m + c, m), Qt.point(w - m, m), Qt.point(w - m, h - m - c),
                Qt.point(w - m - c, h - m), Qt.point(m, h - m), Qt.point(m, m + c)]
    }
    function _trecho(pts, comp) {
        let r = [pts[0]], falta = comp
        for (let i = 1; i < pts.length && falta > 0; i++) {
            const a = pts[i - 1], b = pts[i], d = Math.hypot(b.x - a.x, b.y - a.y)
            if (d <= falta) { r.push(b); falta -= d }
            else { const f = falta / d; r.push(Qt.point(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)); falta = 0 }
        }
        return r
    }
    readonly property real _perim: { let t = 0; for (let i = 1; i < pontos.length; i++) t += Math.hypot(pontos[i].x - pontos[i-1].x, pontos[i].y - pontos[i-1].y); return t }
    readonly property var _parciais: traco >= 1 || traco <= 0 ? [[], []]
        : [_trecho(pontos, _perim / 2 * traco), _trecho(pontos.slice().reverse(), _perim / 2 * traco)]

    ShapePath {
        fillColor: s.preenchimento
        strokeColor: s.traco >= 1 && s.espessura > 0 ? s.borda : "transparent"
        strokeWidth: s.espessura
        joinStyle: ShapePath.MiterJoin
        PathPolyline { path: s.pontos }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: s.traco > 0 && s.traco < 1 ? Cores.secundaria : "transparent"
        strokeWidth: Math.max(1, s.espessura)
        PathMultiline { paths: s._parciais }
    }
}
