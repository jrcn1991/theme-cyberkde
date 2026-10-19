import QtQuick

// Título com glitch: ao trocar o texto, os caracteres "decodificam" (embaralham e assentam) e duas
// cópias deslocadas, no destaque e no ciano, cortadas em faixas, piscam por ~250 ms. De vez em quando
// repete um glitch curto (camada atmosférica; desligado com "reduzir animações").
Item {
    id: g
    property string text: ""
    property alias font: base.font
    property color color: Tema.texto
    property bool ocioso: true          // glitch espontâneo de tempos em tempos
    property string _mostrado: text

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    readonly property string _simbolos: "▚▞#/\\<>[]_=+*01ΞΔ¥"

    Text {
        id: base
        text: g._mostrado
        color: g.color
    }

    // Cópias de separação de cor, visíveis só durante o glitch.
    Repeater {
        id: copias
        model: [
            { cor: Tema.destaque },
            { cor: Tema.secundaria }
        ]
        Item {
            id: faixa
            required property var modelData
            required property int index
            property real dx: 0
            property real fy: 0
            property real fh: 0
            visible: false
            clip: true
            x: dx; y: fy
            width: base.width + 8; height: fh
            Text {
                y: -faixa.fy
                text: g._mostrado
                font: base.font
                color: faixa.modelData.cor
                opacity: 0.85
            }
        }
    }

    property int _passo: 0
    property int _passos: 7
    property string _alvo: text

    function disparar(decodificar) {
        // invisível (ou sem animação): troca seca, e um ciclo antigo não pode sobrescrever depois
        if (Tema.reduzir || !g.visible) { tick.stop(); base.x = 0; _alvo = text; _mostrado = text; return }
        _alvo = text
        _passo = 0
        _passos = decodificar ? 9 : 5
        tick.decodificar = decodificar
        tick.restart()
    }

    onTextChanged: disparar(true)

    Timer {
        id: tick
        property bool decodificar: false
        interval: 34
        repeat: true
        onTriggered: {
            g._passo++
            const fim = g._passo >= g._passos
            for (let i = 0; i < copias.count; i++) {
                const c = copias.itemAt(i)
                if (!c) continue
                c.visible = !fim && Math.random() < 0.85
                c.dx = (Math.random() - 0.5) * 8
                c.fy = Math.random() * base.height * 0.7
                c.fh = Math.max(3, Math.random() * base.height * 0.5)
            }
            base.x = fim ? 0 : (Math.random() < 0.3 ? (Math.random() - 0.5) * 3 : 0)
            if (tick.decodificar && !fim) {
                const resolvidos = Math.floor(g._alvo.length * g._passo / g._passos)
                let s = g._alvo.substring(0, resolvidos)
                for (let k = resolvidos; k < g._alvo.length; k++)
                    s += g._alvo[k] === " " ? " " : g._simbolos[Math.floor(Math.random() * g._simbolos.length)]
                g._mostrado = s
            } else {
                g._mostrado = fim ? g.text : g._alvo   // no fim, sempre o texto atual
            }
            if (fim) stop()
        }
    }

    Timer {
        running: g.ocioso && !Tema.reduzir && g.visible
        interval: 5200 + Math.random() * 6000
        repeat: true
        onTriggered: { interval = 5200 + Math.random() * 6000; g.disparar(false) }
    }
}
