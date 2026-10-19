import QtQuick
import QtQuick.Shapes

// Superfície com cantos cortados a 45° (a linguagem do tema). Por padrão corta o canto de cima à
// esquerda e o de baixo à direita, como as janelas do CyberKDE.
//
// Montagem (como as janelas do Cyberpunk): "traco" < 1 desenha só parte do contorno — duas linhas
// finas que saem do canto de cima à esquerda, uma pelo topo e outra pela lateral, e se encontram no
// canto oposto, com um ponto brilhante na ponta; "superficie" controla o preenchimento (aparece
// depois da moldura) e "realce" pisca a borda na secundária quando a moldura fecha.
Shape {
    id: s
    property real corte: Tema.chanfro
    property bool cortaSE: true    // superior esquerdo
    property bool cortaSD: false   // superior direito
    property bool cortaID: true    // inferior direito
    property bool cortaIE: false   // inferior esquerdo
    property color preenchimento: Tema.painel
    property color borda: Tema.linha
    property real espessura: 1

    property real traco: 1         // 0..1 do contorno desenhado
    property real superficie: 1    // 0..1 do preenchimento
    property real realce: 0        // 0..1: borda puxada para a secundária (flash ao fechar)
    property color corTraco: Tema.secundaria

    preferredRendererType: Shape.CurveRenderer

    readonly property var pontos: {
        const w = width, h = height, c = Math.min(corte, w / 2, h / 2), m = Math.max(espessura, 1) / 2
        let p = []
        if (cortaSE) p.push(Qt.point(m, m + c), Qt.point(m + c, m)); else p.push(Qt.point(m, m))
        if (cortaSD) p.push(Qt.point(w - m - c, m), Qt.point(w - m, m + c)); else p.push(Qt.point(w - m, m))
        if (cortaID) p.push(Qt.point(w - m, h - m - c), Qt.point(w - m - c, h - m)); else p.push(Qt.point(w - m, h - m))
        if (cortaIE) p.push(Qt.point(m + c, h - m), Qt.point(m, h - m - c)); else p.push(Qt.point(m, h - m))
        p.push(p[0])
        return p
    }

    // trecho do contorno com "comprimento" a partir do início, seguindo a lista de pontos
    function _trecho(pts, comprimento) {
        let r = [pts[0]], falta = comprimento
        for (let i = 1; i < pts.length && falta > 0; i++) {
            const a = pts[i - 1], b = pts[i]
            const d = Math.hypot(b.x - a.x, b.y - a.y)
            if (d <= falta) { r.push(b); falta -= d }
            else { const f = falta / d; r.push(Qt.point(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)); falta = 0 }
        }
        return r
    }
    readonly property real _perimetro: {
        let t = 0
        for (let i = 1; i < pontos.length; i++) t += Math.hypot(pontos[i].x - pontos[i - 1].x, pontos[i].y - pontos[i - 1].y)
        return t
    }
    // dois trechos a partir do canto de cima à esquerda (pontos[0]..pontos[1] é o chanfro):
    // um no sentido horário (topo) e outro no anti-horário (lateral esquerda)
    readonly property var _parciais: {
        if (traco >= 1 || traco <= 0) return [[], []]
        const metade = _perimetro / 2 * traco
        const ida = _trecho(pontos, metade)
        const volta = _trecho(pontos.slice().reverse(), metade)
        return [ida, volta]
    }

    ShapePath {
        fillColor: Qt.rgba(s.preenchimento.r, s.preenchimento.g, s.preenchimento.b, s.preenchimento.a * s.superficie)
        strokeColor: s.espessura > 0 && s.traco >= 1
            ? Qt.rgba(s.borda.r + (s.corTraco.r - s.borda.r) * s.realce, s.borda.g + (s.corTraco.g - s.borda.g) * s.realce,
                      s.borda.b + (s.corTraco.b - s.borda.b) * s.realce, s.borda.a + (1 - s.borda.a) * s.realce)
            : "transparent"
        strokeWidth: s.espessura
        joinStyle: ShapePath.MiterJoin
        PathPolyline { path: s.pontos }
    }
    // moldura sendo traçada
    ShapePath {
        fillColor: "transparent"
        strokeColor: s.traco > 0 && s.traco < 1 ? s.corTraco : "transparent"
        strokeWidth: Math.max(1, s.espessura)
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap
        PathMultiline { paths: s._parciais }
    }

    // pontas brilhantes do traço
    Repeater {
        model: s.traco > 0 && s.traco < 1 ? 2 : 0
        Rectangle {
            required property int index
            readonly property var lista: s._parciais[index]
            readonly property point ponta: lista.length ? lista[lista.length - 1] : Qt.point(0, 0)
            x: ponta.x - 2; y: ponta.y - 2
            width: 4; height: 4
            color: Tema.texto
            Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: Tema.alfa(s.corTraco, 0.35) }
        }
    }
}
