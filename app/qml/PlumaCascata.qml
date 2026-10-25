import QtQuick

// Prévia da "cascata de dados" do Konsole (efeito da Rachael, konsole/PEDIDO-CLI.md): as linhas que
// saem pelo topo do terminal viram uma pluma de glifos minúsculos que nasce rente ao horizonte, faz a
// curva para cima e se desintegra em lascas na borda de fora. As cores atravessam a faixa: "video"
// vai de vermelho a violeta; "tema", do destaque ao alerta, ao texto claro e à secundária.
//
// A faixa tem a altura de "linhas" linhas de terminal; abaixo do horizonte, o texto (nunca coberto).
// Tudo deriva de uma "fase" só; anima apenas com "animar" (e nunca com "reduzir animações").
Item {
    id: p
    property int linhas: 5
    property string cores: "video"
    property bool animar: false
    property real fase: 0.37
    readonly property real alturaLinha: 8
    readonly property real horizonte: 20 + linhas * alturaLinha    // y da linha do horizonte
    implicitWidth: 320
    implicitHeight: horizonte + 30

    // ---- cores atravessando a faixa (0 = borda de dentro, 1 = borda de fora)
    readonly property var paradas: cores === "tema"
        ? [Tema.destaque, Tema.alerta, Qt.color("#ECEAF2"), Tema.secundaria]
        : [Qt.color("#D9362B"), Qt.color("#F2792E"), Qt.color("#F2C14E"), Qt.color("#E9E4F7"), Qt.color("#9B7BE8")]
    function corEm(v) {
        const n = paradas.length - 1
        const x = Math.max(0, Math.min(1, v)) * n
        const i = Math.min(n - 1, Math.floor(x))
        return Tema.mistura(Qt.color(paradas[i]), Qt.color(paradas[i + 1]), x - i)
    }

    // ---- a curva: corre rente ao horizonte e faz o "cotovelo" para cima, quase vertical no fim
    //      x = x0 + (xr − x0)·(1 − (1 − u)³),  y = h − (h − 2)·u³
    readonly property real x0: width * 0.03
    readonly property real xr: width * 0.6
    function ponto(u) {
        const a = 1 - u
        return Qt.point(x0 + (xr - x0) * (1 - a * a * a), horizonte - (horizonte - 2) * u * u * u)
    }
    function normal(u) {
        // tangente; a normal aponta para fora da curva (direita / baixo)
        const a = 1 - u
        const tx = 3 * (xr - x0) * a * a, ty = -3 * (horizonte - 2) * u * u
        const l = Math.max(0.001, Math.hypot(tx, ty))
        return Qt.point(-ty / l, tx / l)
    }
    function largura(u) { return 1.5 + Math.pow(u, 1.3) * Math.min(width * 0.33, 50 + linhas * 7) }

    clip: true

    Rectangle { anchors.fill: parent; color: Tema.mistura(Tema.fundo, "#000000", 0.35) }

    // régua: uma marca por linha reservada
    Repeater {
        model: p.linhas
        Rectangle {
            required property int index
            x: 3; width: index % 5 === 4 ? 6 : 3; height: 1
            y: p.horizonte - (index + 1) * p.alturaLinha
            color: Tema.alfa(Tema.texto3, 0.7)
        }
    }

    // partículas: ~2200 "glifos" de 1–3 px (dentro da faixa, mais densos na borda de dentro) e lascas
    // (além da borda de fora). Canvas: um desenho por quadro, só enquanto anima.
    property var _sementes: []
    property var _lut: []
    function _prepararCores() {
        let l = []
        for (let k = 0; k <= 32; k++) { const c = corEm(k / 32); l.push(Qt.rgba(c.r, c.g, c.b, 1).toString()) }
        _lut = l
    }
    onParadasChanged: { _prepararCores(); tela.requestPaint() }
    // ~30 desenhos por segundo bastam para a pluma (metade do custo de 60)
    property int _quadro: -1
    onFaseChanged: { const q = Math.floor(fase * 180); if (q !== _quadro) { _quadro = q; tela.requestPaint() } }
    onLinhasChanged: tela.requestPaint()
    Component.onCompleted: {
        let a = []
        for (let i = 0; i < 2200; i++) {
            const r1 = Math.random(), r2 = Math.random()
            // mais partículas perto da borda de dentro; ~12% viram lascas além da borda
            const v = r2 < 0.12 ? 1 + Math.random() * 0.35 : Math.pow(Math.random(), 0.8)
            a.push({ u: r1, v: v, k: Math.random() < 0.3 ? 2 : 1, w: 1 + Math.floor(Math.random() * 2), h: 1 + Math.floor(Math.random() * 3) })
        }
        _sementes = a
        _prepararCores()
        tela.requestPaint()
    }
    Canvas {
        id: tela
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const S = p._sementes, L = p._lut
            if (!S.length || !L.length) return
            for (let i = 0; i < S.length; i++) {
                const e = S[i]
                const u = (e.u + p.fase * e.k) % 1
                const lasca = e.v > 1
                const c = p.ponto(u), n = p.normal(u)
                const off = (lasca ? 1 + (e.v - 1) * (1.5 + u * 4) : e.v) * p.largura(u)
                const x = c.x + n.x * off
                const y = Math.min(p.horizonte - 1, c.y + n.y * off + (lasca ? u * 6 : 0))
                const alfa = (u < 0.04 ? u / 0.04 : 1) * (u > 0.93 ? (1 - u) / 0.07 : 1) * (lasca ? 0.8 * (1 - (e.v - 1) * 2.4) : 0.95)
                if (alfa <= 0.02) continue
                ctx.globalAlpha = alfa
                ctx.fillStyle = L[Math.min(32, Math.round(Math.min(1, e.v) * 32))]
                ctx.fillRect(Math.round(x), Math.round(y), e.w, lasca ? e.w : e.h)
            }
            ctx.globalAlpha = 1
        }
    }

    // horizonte e texto do terminal (nunca coberto)
    Rectangle { y: p.horizonte; width: parent.width * 0.88; height: 1; color: Tema.alfa(Tema.texto3, 0.8) }
    Column {
        x: 10; y: p.horizonte + 5
        spacing: 2
        Text { text: "$ make -j8"; font.family: Tema.fMono; font.pixelSize: 9; color: Tema.texto2 }
        Text { text: "[ 42%] Building CXX object…"; font.family: Tema.fMono; font.pixelSize: 9; color: Tema.texto3 }
    }

    NumberAnimation on fase {
        running: p.animar && p.visible && !Tema.reduzir && Qt.application.state === Qt.ApplicationActive
        from: 0; to: 1
        duration: 6000
        loops: Animation.Infinite
    }
}
