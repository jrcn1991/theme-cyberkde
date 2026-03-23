// CyberKDE — fundo: imagem (papel de parede de login ou o fundo gerado), escurecimento para leitura,
// trama técnica sutil só nas margens e brackets vermelhos nos quatro cantos.
import QtQuick
import "."

Item {
    id: root

    property url source
    property real t: 100000
    property real imageOpacity: 1

    Rectangle { anchors.fill: parent; color: CK.base }

    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        opacity: root.imageOpacity * CK.ramp(root.t, 0, 260)
    }

    // proteção de leitura: mais escuro atrás do conteúdo central e nas bordas de cima e de baixo
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: CK.alpha(CK.base, 0.70) }
            GradientStop { position: 0.5; color: CK.alpha(CK.base, 0.50) }
            GradientStop { position: 1.0; color: CK.alpha(CK.base, 0.70) }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: CK.alpha(CK.base, 0.55) }
            GradientStop { position: 0.22; color: CK.alpha(CK.base, 0.0) }
            GradientStop { position: 0.78; color: CK.alpha(CK.base, 0.0) }
            GradientStop { position: 1.0; color: CK.alpha(CK.base, 0.70) }
        }
    }

    Canvas {
        id: marks
        anchors.fill: parent
        // o papel de parede de login já traz moldura e réguas; as marcas só entram no fundo de reserva
        visible: CK.backdropMarks
        opacity: CK.ramp(root.t, 40, 240)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const m = 24, step = 16, arm = 28, clear = 56
            // trama: marcas de régua a 10% nas quatro margens
            ctx.fillStyle = CK.css(CK.txt1, 0.10)
            for (let x = m + clear; x <= width - m - clear; x += step) {
                const l = Math.round((x - m - clear) / step) % 8 === 0 ? 7 : 3
                ctx.fillRect(x, m, 1, l)
                ctx.fillRect(x, height - m - l, 1, l)
            }
            for (let y = m + clear; y <= height - m - clear; y += step) {
                const l = Math.round((y - m - clear) / step) % 8 === 0 ? 7 : 3
                ctx.fillRect(m, y, l, 1)
                ctx.fillRect(width - m - l, y, l, 1)
            }
            // brackets nos cantos
            ctx.fillStyle = CK.css(CK.red, 0.85)
            ctx.fillRect(m, m, arm, 1); ctx.fillRect(m, m, 1, arm)
            ctx.fillRect(width - m - arm, m, arm, 1); ctx.fillRect(width - m - 1, m, 1, arm)
            ctx.fillRect(m, height - m - 1, arm, 1); ctx.fillRect(m, height - m - arm, 1, arm)
            ctx.fillRect(width - m - arm, height - m - 1, arm, 1); ctx.fillRect(width - m - 1, height - m - arm, 1, arm)
        }
    }
}
