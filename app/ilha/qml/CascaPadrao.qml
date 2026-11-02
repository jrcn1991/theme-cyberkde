import QtQuick
import QtQuick.Effects

// A placa: cantos de cima colados à borda da tela, raio embaixo; ou chanfro. Estilos só na gota aberta.
Item {
    id: c
    property var tema
    property var ctx
    readonly property bool vidro: ctx.aberta && ctx.estilo !== "preto"
    readonly property real raio: ctx.raio
    // no vidro não há sombra ("o vidro não precisa de sombra")
    RectangularShadow {
        anchors.fill: parent
        visible: !c.vidro && c.tema.forma === "pilula"
        offset.y: c.tema.sombraY
        blur: c.tema.sombraRaio
        radius: c.raio
        color: c.tema.sombraCor
    }
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            visible: c.tema.forma === "pilula"
            width: parent.width; y: -c.raio; height: parent.height + c.raio
            radius: c.raio
            color: c.ctx.estilo === "vidro" && c.ctx.aberta ? c.tema.vidroFundo : c.tema.fundo
            border.width: c.vidro ? 1 : 0
            border.color: c.tema.vidroBordaFraca
            // degrade: preto no alto, quase transparente embaixo
            gradient: c.ctx.estilo === "degrade" && c.ctx.aberta ? grad : null
            Gradient {
                id: grad
                GradientStop { position: 0.16; color: c.tema.fundo }
                GradientStop { position: 0.35; color: Qt.rgba(c.tema.fundo.r, c.tema.fundo.g, c.tema.fundo.b, 0.9) }
                GradientStop { position: 0.60; color: Qt.rgba(c.tema.fundo.r, c.tema.fundo.g, c.tema.fundo.b, 0.78) }
                GradientStop { position: 1.00; color: Qt.rgba(c.tema.fundo.r, c.tema.fundo.g, c.tema.fundo.b, 0.62) }
            }
        }
    }
    Canvas {
        // chanfro: desenho simples; temas com forma própria trazem Casca.qml
        visible: c.tema.forma === "chanfro"
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint(); onHeightChanged: requestPaint(); onVisibleChanged: requestPaint()
        onPaint: {
            const x = getContext("2d"), k = c.tema.corte, w = width, h = height
            x.reset(); x.beginPath(); x.moveTo(0, 0); x.lineTo(w, 0); x.lineTo(w, h - k); x.lineTo(w - k, h); x.lineTo(k, h); x.lineTo(0, h - k); x.closePath()
            x.fillStyle = c.tema.fundo; x.fill()
        }
    }
}
