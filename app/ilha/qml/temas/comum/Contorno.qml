import QtQuick

// Polilinha traçada, comum aos temas: "fracao" 0–1 de "pontos"; "duasPontas" traça dos dois lados, a partir do
// primeiro ponto, até se encontrarem. "preenchimento" pinta a forma inteira. Só repinta quando algo muda.
Canvas {
    id: c
    property var pontos: []
    property real fracao: 1
    property bool duasPontas: false
    property color cor: "#DCDCE4"
    property color preenchimento: "transparent"
    property real espessura: 1
    renderStrategy: Canvas.Cooperative
    function _simples(pts) { const r = []; for (let i = 0; i < pts.length; i++) r.push({ x: pts[i].x, y: pts[i].y }); return r }
    function _inverso(pts) { const r = []; for (let i = pts.length - 1; i >= 0; i--) r.push({ x: pts[i].x, y: pts[i].y }); return r }
    function _trecho(pts, comp) {
        const r = [pts[0]]
        let falta = comp
        for (let i = 1; i < pts.length && falta > 0; i++) {
            const a = pts[i - 1], b = pts[i], d = Math.hypot(b.x - a.x, b.y - a.y)
            if (d <= falta) { r.push(b); falta -= d }
            else { const f = falta / d; r.push({ x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f }); falta = 0 }
        }
        return r
    }
    readonly property real perimetro: {
        let s = 0
        for (let i = 1; i < pontos.length; i++) s += Math.hypot(pontos[i].x - pontos[i-1].x, pontos[i].y - pontos[i-1].y)
        return s
    }
    readonly property var trecho1: pontos.length < 2 || fracao <= 0 ? [] : fracao >= 1 ? _simples(pontos) : _trecho(_simples(pontos), perimetro * (duasPontas ? fracao / 2 : fracao))
    readonly property var trecho2: !duasPontas || fracao <= 0 || fracao >= 1 || pontos.length < 2 ? [] : _trecho(_inverso(pontos), perimetro * fracao / 2)
    readonly property point ponta: trecho1.length ? Qt.point(trecho1[trecho1.length - 1].x, trecho1[trecho1.length - 1].y) : Qt.point(0, 0)
    function _linha(x, pts) { pts.forEach((p, i) => i ? x.lineTo(p.x, p.y) : x.moveTo(p.x, p.y)) }
    onPaint: {
        const x = getContext("2d")
        x.reset()
        if (preenchimento.a > 0 && pontos.length > 2) { x.fillStyle = preenchimento; x.beginPath(); _linha(x, pontos); x.closePath(); x.fill() }
        if (trecho1.length < 2) return
        x.strokeStyle = cor; x.lineWidth = espessura; x.lineJoin = "miter"
        x.beginPath(); _linha(x, trecho1); if (trecho2.length > 1) _linha(x, trecho2); x.stroke()
    }
    onPontosChanged: requestPaint()
    onFracaoChanged: requestPaint()
    onCorChanged: requestPaint()
    onPreenchimentoChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
}
