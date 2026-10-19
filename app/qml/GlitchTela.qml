import QtQuick

// Transição de corporação: congela a interface na cor antiga, aplica a cor nova por baixo e varre a
// tela de cima para baixo, revelando a nova; nos primeiros ~200 ms, faixas da imagem antiga se
// deslocam com separação de cor (glitch). Total ~520 ms. Com "reduzir animações", troca direto.
Item {
    id: g
    property Item fonte
    property real _linha: 0          // posição da varredura (0..1)
    property bool _rodando: false
    property var _depois: null

    anchors.fill: parent
    visible: _rodando
    z: 40

    ShaderEffectSource {
        id: foto
        sourceItem: g.fonte
        live: false
        hideSource: false
        visible: false
        width: g.width; height: g.height
    }

    function disparar(aplicar) {
        if (Tema.reduzir || !Tema.efeitos || !fonte) { if (aplicar) aplicar(); return }
        _depois = aplicar
        foto.scheduleUpdate()
        anim.stop()
        espera.restart()   // um quadro para a foto sair com a cor antiga
    }
    Timer {
        id: espera
        interval: 32
        onTriggered: {
            g._rodando = true
            g._linha = 0
            if (g._depois) { g._depois(); g._depois = null }
            let d = []
            for (let i = 0; i < 18; i++)
                d.push({ y: Math.random(), h: Math.random() > 0.75 ? 2 : 1, w: 0.08 + Math.random() * 0.35,
                         nasce: Math.random() * 0.55, vida: 0.25 + Math.random() * 0.3, dir: 1, cor: Math.random() })
            g._dados = d
            anim.start()
            faixas.passo = 0
            faixas.start()
        }
    }

    // a interface antiga, ainda não varrida (abaixo da linha)
    Item {
        y: g.height * g._linha
        width: g.width; height: g.height - y
        clip: true
        ShaderEffect {
            y: -parent.y
            width: g.width; height: g.height
            property variant source: foto
        }
    }

    // faixas deslocadas com tinta (glitch)
    Repeater {
        id: bandas
        model: 7
        Item {
            id: banda
            property real fy: 0
            property real fh: 0
            property real dx: 0
            property color tinta: "transparent"
            visible: false
            y: fy; width: g.width; height: fh
            clip: true
            ShaderEffect {
                x: banda.dx; y: -banda.fy
                width: g.width; height: g.height
                property variant source: foto
            }
            Rectangle { anchors.fill: parent; color: banda.tinta }
        }
    }
    Timer {
        id: faixas
        property int passo: 0
        interval: 30
        repeat: true
        onTriggered: {
            passo++
            const fim = passo > 7
            for (let i = 0; i < bandas.count; i++) {
                const b = bandas.itemAt(i)
                b.visible = !fim && Math.random() < 0.7
                b.fy = Math.random() * g.height
                b.fh = 4 + Math.random() * 38
                b.dx = (Math.random() - 0.5) * 46
                const r = Math.random()
                b.tinta = r < 0.33 ? Tema.alfa(Tema.secundaria, 0.22) : (r < 0.66 ? Tema.alfa(Tema.destaque, 0.25) : "transparent")
            }
            if (fim) stop()
        }
    }

    // linhas de dados que atravessam a tela durante a troca (A24 do app_portfolio_cyberpunk: "linhas
    // horizontais de dados atravessam a tela enquanto a janela antiga fecha e a nova monta")
    property var _dados: []
    Repeater {
        model: g._rodando ? g._dados.length : 0
        Rectangle {
            required property int index
            readonly property var d: g._dados[index]
            readonly property real p: Math.max(0, Math.min(1, (g._linha - d.nasce) / d.vida))
            y: d.y * g.height
            height: d.h
            width: d.w * g.width
            x: -width + (g.width + width) * p
            color: d.cor > 0.8 ? Tema.destaque : (d.cor > 0.65 ? Tema.texto : Tema.secundaria)
            opacity: p <= 0 || p >= 1 ? 0 : (Math.floor(p * 12) % 3 === 0 ? 0.35 : 0.9)
        }
    }

    // a linha de varredura
    Rectangle {
        y: g.height * g._linha - height / 2
        width: g.width; height: 2
        color: Tema.secundaria
        Rectangle {
            anchors.bottom: parent.top
            width: parent.width; height: 40
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Tema.alfa(Tema.destaque, 0.28) }
            }
        }
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: g; property: "_linha"; from: 0; to: 1; duration: 480; easing.type: Easing.InOutCubic }
        ScriptAction { script: g._rodando = false }
    }
}
