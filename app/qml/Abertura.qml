import QtQuick

// Abertura de "boot" no tempo da referência "Efeito de logo" (Portfolio Refeencias):
//   0–150 ms    escuro; microtexto de dados nos cantos acende com piscadas curtas
//   100–1350    o logo se monta (LogoMontagem "completo": feixes → circuito → fatias com aberração
//               cromática → flicker e brilho)
//   350–1250    log de boot digitado e barra segmentada
//   1150–1420   o nome da corporação é escrito letra a letra sobre uma linha que cresce (o "2077")
//   1450–1710   a cortina se abre ao meio
// Clique, Esc ou espaço pulam. Com "reduzir animações", não aparece.
Item {
    id: a
    objectName: "abertura"
    property url logo
    property var recorte: null
    property string corp: ""
    property string cor: ""
    property bool pronto: false   // primeiro status do CLI chegou (ou passou o tempo de espera)
    signal terminou()

    anchors.fill: parent
    z: 60
    focus: true
    Keys.onEscapePressed: pular()
    Keys.onSpacePressed: pular()

    property real ms: 0       // relógio da sequência
    property real abre: 0     // 0..1 da cortina
    readonly property int duracao: 1450

    function _lim(x) { return Math.max(0, Math.min(1, x)) }
    function pular() {
        if (fecha.running || !visible) return
        seq.stop()
        marca.pular()
        ms = duracao
        fecha.duration = Tema.reduzir ? 0 : 160
        fecha.start()
    }

    // cortina: duas metades que se afastam
    Rectangle { width: parent.width; height: parent.height / 2 + 1; y: -height * a.abre; color: Tema.fundo }
    Rectangle { width: parent.width; height: parent.height / 2 + 1; y: parent.height / 2 + height * a.abre; color: Tema.fundo }

    Item {
        anchors.fill: parent
        opacity: 1 - a.abre * 2.5

        // microtexto de dados nos cantos (a "tela escura com ruído de dados" do início)
        Repeater {
            model: 4
            Column {
                required property int index
                readonly property real nasce: 20 + index * 35
                x: index % 2 ? a.width - width - 28 : 28
                y: index < 2 ? 26 : a.height - height - 26
                spacing: 2
                // 2–3 piscadas de 40 ms e fica a 35%
                opacity: a.ms < nasce ? 0 : (a.ms < nasce + 120 ? (Math.floor((a.ms - nasce) / 40) % 2 ? 0.1 : 0.6) : 0.35)
                Repeater {
                    model: 6
                    Codigo {
                        required property int index
                        tamanho: 9
                        color: Tema.alfa(Tema.destaque, 0.7)
                        text: ["0x" + (0x3A00 + index * 0x91).toString(16).toUpperCase() + "  SYNC  " + (index * 17 % 97),
                               "NET.UPLINK // " + ("0" + (index * 7 % 60)).slice(-2) + " ms",
                               "BUF " + (index * 131 % 999) + "/999  ▮▮▮▯",
                               "KWIN://LAYER." + index + "  OK",
                               "SIG " + (index * 0.13).toFixed(2) + "  ·  DRIFT " + (index * 3 % 7),
                               "CORE.TEMP " + (41 + index) + "°  NOMINAL"][index]
                    }
                }
            }
        }

        // moldura
        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -marca.height / 2 + 60
            width: Math.max(600, marca.width + 140)
            height: Math.max(400, marca.height + 320)
            opacity: a.ms < 60 ? 0 : (a.ms < 160 ? (Math.floor(a.ms / 33) % 2 ? 0.3 : 1) : 1)
            Cantoneiras { cor: Tema.destaque; tamanho: 18; espessura: 2 }
        }

        LogoMontagem {
            id: marca
            // como o "CYBERPUNK" da referência: ~60% da largura da janela, limitado pela altura
            // (o logo fica acima do centro; o log e a barra, abaixo)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 30
            visible: seq.running || a.ms > 0
            readonly property real alturaMax: Math.max(90, a.height * 0.5 - 90)
            width: Math.min(a.width * 0.6, alturaMax * Math.max(0.5, proporcao))
            height: width / Math.max(0.5, proporcao)
            modo: "completo"
            source: a.logo
            recorte: a.recorte
        }

        // o "2077": nome da corporação escrito letra a letra, com uma linha que cresce da esquerda
        Item {
            id: subtitulo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: marca.bottom; anchors.topMargin: 18
            width: nome.implicitWidth + 40; height: 24
            readonly property real p: a._lim((a.ms - 1150) / 270)
            Rectangle {
                y: parent.height - 2
                width: parent.width * a._lim(subtitulo.p * 1.6); height: 1
                color: Tema.secundaria
            }
            Text {
                id: nome
                anchors.centerIn: parent
                text: a.corp.toUpperCase().split("").join(" ")
                visible: false
                font.family: Tema.fIdentidade; font.pixelSize: 13; font.letterSpacing: 4
            }
            Text {
                anchors.left: nome.left; anchors.verticalCenter: nome.verticalCenter
                text: nome.text.substring(0, Math.floor(nome.text.length * subtitulo.p))
                font: nome.font
                color: Tema.secundaria
            }
        }

        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 52
            height: 1
            width: a._lim(a.ms / 400) * Math.min(520, a.width - 80)
            color: Tema.alfa(Tema.destaque, 0.6)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 66
            spacing: 4
            width: Math.min(520, a.width - 80)
            Repeater {
                model: [
                    { quando: 350, txt: Txt.t("boot.l1") },
                    { quando: 560, txt: Txt.t("boot.l2") },
                    { quando: 770, txt: Txt.t("boot.l3", { corp: a.corp.toUpperCase() }) },
                    { quando: 980, txt: Txt.t("boot.l4", { cor: a.cor }) }
                ]
                Codigo {
                    required property var modelData
                    tamanho: 11
                    color: Tema.texto2
                    readonly property real p: a._lim((a.ms - modelData.quando) / 200)
                    text: modelData.txt.substring(0, Math.floor(modelData.txt.length * p))
                }
            }
            Item { width: 1; height: 8 }
            BarraSegmentada {
                width: parent.width
                height: 8
                valor: a._lim((a.ms - 250) / 1100)
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: a.pular() }

    SequentialAnimation {
        id: seq
        running: a.pronto && a.visible
        ScriptAction { script: marca.montar() }
        NumberAnimation { target: a; property: "ms"; from: 0; to: a.duracao; duration: a.duracao; easing.type: Easing.Linear }
        ScriptAction { script: fecha.start() }
    }
    NumberAnimation {
        id: fecha
        target: a; property: "abre"; to: 1; duration: 260; easing.type: Easing.InOutCubic
        onFinished: { a.visible = false; a.terminou() }
    }
}
