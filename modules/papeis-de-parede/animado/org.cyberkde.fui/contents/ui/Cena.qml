import QtQuick

// Cena do papel FUI: o fundo animado (shaders/fui.frag) e, por cima, o logo da corporação com o
// subtítulo, a marca e o texto técnico vertical da lateral esquerda e o emblema embaixo à direita.
// Não depende do Plasma (o main.qml só a configura), então também roda direto num QQuickView para
// testes, prévias e o quadro estático.
//
// Entrada (medida na referência, quadros de 30 ms): o fundo surge primeiro (250 ms); o logo pisca e
// assenta aos ~90 ms; o emblema aos ~850 ms; a marca, o texto vertical e o glifo aos ~1,3 s, com o
// texto se "digitando". Depois disso, só o fundo anima.
Item {
    id: c
    // ---- cores e marca (da corporação)
    property color corLuz: "#D91212"
    property color corNevoa: "#330000"
    property color corBase: "#111111"
    property color corTexto: "#EEEEEE"
    property url logo: ""
    property url emblema: ""
    property var tonsLogo: [0, 0]          // [escura, clara] do SVG (gen_fui.py), para a tinta em dois tons
    property var tonsEmblema: [0, 0]
    property string corLogo: "tingido"     // tingido (na cor do texto) | original (as cores do arquivo)
    property string nome: "ARASAKA"
    property string lema: ""
    property string codigo: "ARS-54"
    // ---- configuração
    property real intensidade: 1.0
    property real velocidade: 1.0
    property bool mostrarLogo: true
    property bool mostrarTextos: true
    property int fps: 30
    property bool ativo: true             // falso: congela (janela maximizada por cima, tela desligada…)
    property string nivel: "completo"     // completo | reduzido | minimo (movimento do tema)
    property real tempoFixo: -1           // ≥ 0: quadro fixo nesse tempo (quadro estático, prévias, testes)
    property real grao: 1                 // 0..1 (o estático em alta resolução usa menos)
    property bool comEntrada: true

    readonly property real ciclo: 14.4
    readonly property bool parado: nivel === "minimo" || tempoFixo >= 0
    // tempo da cena (com a velocidade) e quadro (grão)
    property real t: tempoFixo >= 0 ? tempoFixo : 1.52
    property real quadro: 0
    property real decorrido: 0            // tempo real desde a entrada (s)
    property real glitch: 0

    function passo(dt) {
        dt = Math.min(dt, 0.1)
        if (decorrido < 2) decorrido += dt   // a entrada acaba em 1,4 s: depois disso, nenhum binding de entrada a recalcular
        quadro += 1
        const antes = (t % ciclo) / ciclo
        t = (t + dt * velocidade * (nivel === "reduzido" ? 0.6 : 1)) % 3600
        const agora = (t % ciclo) / ciclo
        // glitch de 3 quadros a 75% do ciclo (quadros 361–363 de 481 na referência); não no reduzido
        if (nivel === "completo" && antes < 0.75 && agora >= 0.75) fimGlitch.restart()
        glitch = fimGlitch.running ? 1 : 0
    }
    Timer { id: fimGlitch; interval: 95 }
    property double _ultimo: 0
    Timer {
        id: relogio
        interval: Math.round(1000 / Math.max(1, c.fps))
        repeat: true
        running: c.ativo && !c.parado && c.visible
        onRunningChanged: c._ultimo = Date.now()
        onTriggered: {
            const agora = Date.now()
            c.passo((agora - c._ultimo) / 1000)
            c._ultimo = agora
        }
    }
    // (em quadro fixo com entrada, quem avança "decorrido" é quem captura)
    readonly property bool semEntrada: !comEntrada || nivel === "minimo"
    readonly property real entrada: semEntrada ? 1 : Math.min(1, decorrido / 0.12)
    // instantes da montagem (s de tempo real)
    function apos(s) { return semEntrada || decorrido >= s }

    ShaderEffect {
        anchors.fill: parent
        readonly property size res: Qt.size(width, height)
        readonly property real t: c.t
        // quadro fixo: o grão e o glitch saem do tempo (sequências de prévia reproduzíveis)
        readonly property real quadro: c.tempoFixo >= 0 ? Math.floor(c.tempoFixo * 33.3) : (c.nivel === "minimo" ? 7 : c.quadro)
        readonly property real intensidade: c.intensidade
        readonly property real glitch: {
            if (c.tempoFixo < 0) return c.glitch
            const f = (c.tempoFixo % c.ciclo) / c.ciclo
            return f >= 0.75 && f < 0.75 + 0.095 / c.ciclo ? 1 : 0
        }
        readonly property real entrada: c.entrada
        readonly property real respira: 0.9 + 0.1 * Math.cos(2 * Math.PI * (c.t % c.ciclo) / c.ciclo)
        readonly property real grao: c.grao
        readonly property color corLuz: c.corLuz
        readonly property color corNevoa: c.corNevoa
        readonly property color corBase: c.corBase
        fragmentShader: Qt.resolvedUrl("../shaders/fui.frag.qsb")
    }

    // ---- camadas (medidas na referência em altura de tela: alt = c.height)
    readonly property real alt: height
    // silhueta de uma imagem numa cor
    component Tingida: ShaderEffect {
        property alias fonteUrl: img.source
        property color cor: c.corTexto
        property var tons: [0, 0]
        property bool original: false
        readonly property real orig: original ? 1 : 0
        readonly property size tam: Qt.size(width, height)
        readonly property real lo: tons[0] || 0
        readonly property real hi: tons[1] || 0
        readonly property var fonte: img
        fragmentShader: Qt.resolvedUrl("../shaders/tingir.frag.qsb")
        Image { id: img; visible: false; sourceSize.height: Math.ceil(parent.height * 2); fillMode: Image.PreserveAspectFit; smooth: true }
        readonly property real proporcao: img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 4
    }
    // pisca e assenta (o "liga" de painel da referência): 0 → 1 → 0,25 → 1 em ~120 ms
    component Pisca: Item {
        id: pi
        property bool ligado: false
        opacity: 0
        onLigadoChanged: if (ligado) { if (c.parado || !c.comEntrada) opacity = 1; else seq.restart() }
        Component.onCompleted: if (ligado) opacity = 1
        SequentialAnimation {
            id: seq
            PropertyAction { target: pi; property: "opacity"; value: 1 }
            PauseAnimation { duration: 40 }
            PropertyAction { target: pi; property: "opacity"; value: 0.25 }
            PauseAnimation { duration: 40 }
            PropertyAction { target: pi; property: "opacity"; value: 1 }
        }
    }
    // texto que se digita (letra a letra) ao ligar
    component Digita: Text {
        id: dg
        property string alvo: ""
        property bool ligado: false
        property int _n: 0
        text: alvo.slice(0, _n)
        onLigadoChanged: if (ligado) { if (c.parado || !c.comEntrada) _n = alvo.length; else { _n = 0; tDig.start() } }
        Component.onCompleted: if (ligado) _n = alvo.length
        Timer { id: tDig; interval: 14; repeat: true; onTriggered: { dg._n += 2; if (dg._n >= dg.alvo.length) stop() } }
    }

    // logo + subtítulo (topo à esquerda)
    Pisca {
        id: blocoLogo
        visible: c.mostrarLogo && c.logo != ""
        ligado: c.apos(0.09)
        x: c.alt * 0.088; y: c.alt * 0.056
        Tingida {
            id: logoT
            fonteUrl: c.logo
            tons: c.tonsLogo
            original: c.corLogo === "original"
            height: c.alt * 0.04
            width: Math.min(c.alt * 0.34, height * proporcao)
        }
        Text {
            y: logoT.height + c.alt * 0.006
            width: Math.max(logoT.width, implicitWidth)
            text: c.lema.toUpperCase()
            font.family: "Rajdhani"; font.weight: Font.DemiBold
            font.pixelSize: Math.max(7, Math.round(c.alt * 0.0095)); font.letterSpacing: c.alt * 0.0008
            color: Qt.alpha(c.corTexto, 0.85)
        }
    }

    // lateral esquerda: marca, texto técnico vertical e o glifo grande
    Item {
        visible: c.mostrarTextos
        anchors.fill: parent
        Pisca {
            ligado: c.apos(1.25)
            x: c.alt * 0.026; y: c.alt * 0.058
            width: c.alt * 0.019; height: width
            // a marca "Z" (quadrado partido na diagonal)
            Rectangle { width: parent.width; height: parent.height * 0.26; color: c.corTexto }
            Rectangle { y: parent.height * 0.74; width: parent.width; height: parent.height * 0.26; color: c.corTexto }
            Rectangle { anchors.centerIn: parent; width: parent.width * 1.2; height: parent.height * 0.24; rotation: -45; color: c.corTexto; antialiasing: true }
        }
        // três colunas de microtexto, lidas de cima para baixo
        Repeater {
            model: [
                "SYS.FUI // " + c.codigo + " // BUILD 2077.10",
                "NODE 0x" + Qt.md5(c.nome).slice(0, 6).toUpperCase() + " · SECURE CHANNEL",
                c.nome.toUpperCase() + " NETWORK ACCESS"
            ]
            Digita {
                required property int index
                required property string modelData
                alvo: modelData
                ligado: c.apos(1.3 + index * 0.06)
                font.family: "JetBrains Mono"; font.pixelSize: Math.max(6, Math.round(c.alt * 0.0068))
                color: Qt.alpha(c.corTexto, index === 0 ? 0.7 : 0.45)
                rotation: 90
                transformOrigin: Item.TopLeft
                x: c.alt * (0.046 - index * 0.0085); y: c.alt * 0.095
            }
        }
        Pisca {
            ligado: c.apos(1.35)
            x: c.alt * 0.058; y: c.alt * 0.315
            Text {
                text: "CK+"
                font.family: "Rajdhani"; font.weight: Font.Bold
                font.pixelSize: Math.round(c.alt * 0.036)
                color: Qt.alpha(c.corTexto, 0.95)
                rotation: 90; transformOrigin: Item.TopLeft
            }
            Text {
                x: -c.alt * 0.03; y: 0
                text: "UNIT " + c.codigo
                font.family: "JetBrains Mono"; font.pixelSize: Math.max(6, Math.round(c.alt * 0.0058))
                color: Qt.alpha(c.corTexto, 0.5)
                rotation: 90; transformOrigin: Item.TopLeft
            }
        }
    }

    // emblema embaixo à direita
    Pisca {
        visible: c.mostrarLogo && c.emblema != ""
        ligado: c.apos(0.85)
        width: c.alt * 0.06
        height: emb.height + rotEmb.height + c.alt * 0.006
        x: c.width - width - c.alt * 0.07; y: c.height - height - c.alt * 0.07
        Tingida { id: emb; fonteUrl: c.emblema; tons: c.tonsEmblema; width: parent.width; height: width; cor: Qt.alpha(c.corTexto, 0.9) }
        Text {
            id: rotEmb
            y: emb.height + c.alt * 0.006
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: c.codigo
            font.family: "Rajdhani"; font.weight: Font.Bold
            font.pixelSize: Math.round(c.alt * 0.0135); font.letterSpacing: c.alt * 0.0008
            color: Qt.alpha(c.corTexto, 0.9)
        }
    }
}
