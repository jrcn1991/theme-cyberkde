import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LS

// O fantasma: um cartão do tamanho da janela que voa para a boca da pílula (Voo.tsx + voos.ts do Halo).
// Camada de tela cheia, sem entrada e sem teclado, que só existe durante o voo.
Window {
    id: c
    property var tela: ({})
    property var ui
    property var voo: ({})
    color: "transparent"
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput
    LS.Window.scope: "cyberkde-ilha-voo"
    LS.Window.layer: LS.Window.LayerOverlay
    LS.Window.anchors: LS.Window.AnchorTop | LS.Window.AnchorBottom | LS.Window.AnchorLeft | LS.Window.AnchorRight
    LS.Window.exclusionZone: -1
    LS.Window.keyboardInteractivity: LS.Window.KeyboardInteractivityNone
    LS.Window.activateOnShow: false
    LS.Window.screen: ilha.telaQt(tela.nome)

    readonly property var de: { const f = voo.from || {}; return { x: (f.x || 0) - (tela.x || 0), y: (f.y || 0) - (tela.y || 0), w: f.width || 400, h: f.height || 300 } }
    // boca da pílula
    readonly property real dx: width / 2 - (de.x + de.w / 2)
    readonly property real dy: (ui ? ui.alturaPilula / 2 : 18) - (de.y + de.h / 2)
    readonly property real sx: 44 / de.w
    readonly property real sy: 10 / de.h
    // [tempo, x, y, sx, sy, opacidade]; a volta é o caminho de trás para a frente
    readonly property var quadros: {
        const q = voo.estilo === "foguete"
            ? [[0, 0, 0, 1, 1, 0], [.12, 0, 5, .985, .985, 1], [.4, dx * .24, dy * .58, .72, .72, 1], [.68, dx * .82, dy * 1.14, .3, .3, 1], [.95, dx, dy, sx, sy, 1], [1, dx, dy, sx, sy, 0]]
            : [[0, 0, 0, 1, 1, 0], [.1, 0, -2, 1.003, 1.003, 1], [.2, 0, -6, 1.01, 1.01, 1], [.62, dx * .5, dy * .45, .38 + sx * .4, .55 + sy * .3, 1], [.94, dx, dy, sx, sy, 1], [1, dx, dy, sx, sy, 0]]
        return voo.sentido === "volta" ? q.slice().reverse().map(k => [1 - k[0]].concat(k.slice(1))) : q
    }
    property real t: 0
    function em(i) {
        const q = quadros
        for (let n = 1; n < q.length; n++)
            if (t <= q[n][0]) { const a = q[n - 1], b = q[n], p = (t - a[0]) / Math.max(.001, b[0] - a[0]); return a[i] + (b[i] - a[i]) * p }
        return q[q.length - 1][i]
    }
    NumberAnimation on t { from: 0; to: 1; duration: c.ui ? c.ui.vooMs : 560; onFinished: if (c.ui) c.ui.vooAtual = null }

    Rectangle {
        x: c.de.x; y: c.de.y; width: c.de.w; height: c.de.h
        radius: 12
        color: c.ui ? c.ui.tema.fundo : "black"
        border.color: c.ui ? c.ui.tema.bordaForte : "transparent"
        opacity: c.em(5)
        transform: [Scale { origin.x: c.de.w / 2; origin.y: c.de.h / 2; xScale: c.em(3); yScale: c.em(4) }, Translate { x: c.em(1); y: c.em(2) }]
        Column {
            anchors.centerIn: parent; spacing: 8
            opacity: c.voo.sentido === "volta" ? (c.t > .45 ? (c.t - .45) / .35 : 0) : (c.t < .25 ? 1 : Math.max(0, 1 - (c.t - .25) / .3))
            Glifo { anchors.horizontalCenter: parent.horizontalCenter; nome: "AppWindow"; tamanho: 20; cor: c.ui ? c.ui.tema.texto : "white" }
            Text { text: c.voo.title || ""; color: c.ui ? c.ui.tema.texto : "white"; font.pixelSize: 13; font.family: c.ui ? c.ui.tema.fonte : "" }
        }
    }
}
