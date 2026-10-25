import QtQuick

// Janela modal, montada como as janelas do Cyberpunk (coreografia A06 do app_portfolio_cyberpunk):
//   0–120 ms    o fundo escurece (#05050B a 72%)
//   60–340      a moldura se traça a partir do canto, com quadrados piscando
//   200–340     a superfície aparece
//   300–440     o conteúdo acende com flicker de liga e desliga; a borda pisca; título decodifica
// Esc ou clique fora cancelam. O conteúdo vai no corpo; os botões, em "acoes".
Item {
    id: m
    property string titulo: ""
    property string codigo: ""
    property color cor: Tema.destaque
    property real largura: 520
    property bool aberto: false
    default property alias corpo: corpo.data
    property alias acoes: acoes.data
    signal cancelado()

    anchors.fill: parent
    visible: opacity > 0
    opacity: aberto ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: m.aberto ? Tema.d(120) : Tema.fechar; easing.type: Easing.OutCubic } }
    z: 50

    function abrir() { aberto = true }
    onAbertoChanged: {
        if (!aberto) return
        foco.forceActiveFocus()
        montagem.stop()
        if (Tema.reduzir) { caixa.traco = 1; caixa.superficie = 1; caixa.acender = 1; caixa.realce = 0; return }
        caixa.traco = 0; caixa.superficie = 0; caixa.acender = 0; caixa.realce = 0
        montagem.start()
    }
    SequentialAnimation {
        id: montagem
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: caixa; property: "traco"; from: 0; to: 1; duration: 280; easing.type: Easing.Linear }
            SequentialAnimation {
                PauseAnimation { duration: 140 }
                NumberAnimation { target: caixa; property: "superficie"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 240 }
                PropertyAction { target: caixa; property: "acender"; value: 0.75 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "acender"; value: 0.1 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "acender"; value: 0.9 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "acender"; value: 0.35 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "acender"; value: 1 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 280 }
                PropertyAction { target: caixa; property: "realce"; value: 1 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "realce"; value: 0.2 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: caixa; property: "realce"; value: 0.8 }
                NumberAnimation { target: caixa; property: "realce"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
    function fechar() { aberto = false }

    Rectangle { anchors.fill: parent; color: Tema.escurecer; opacity: 0.72 }
    MouseArea { anchors.fill: parent; onClicked: m.cancelado(); hoverEnabled: true; onWheel: (w) => w.accepted = true }

    Item {
        id: foco
        focus: m.aberto
        Keys.onEscapePressed: m.cancelado()
    }

    Item {
        id: caixa
        width: Math.min(m.largura, m.width - 48)
        height: col.implicitHeight + 40
        anchors.centerIn: parent
        property real traco: 1
        property real superficie: 1
        property real acender: 1
        property real realce: 0
        MouseArea { anchors.fill: parent }   // não deixa o clique atravessar

        Chanfro {
            anchors.fill: parent
            corte: Tema.chanfroG
            preenchimento: Tema.elevado
            borda: Tema.alfa(m.cor, 0.7)
            traco: caixa.traco; superficie: caixa.superficie; realce: caixa.realce
        }
        QuadradosMontagem { progresso: caixa.traco; n: 6 }
        Rectangle {
            x: 0; y: Tema.chanfroG + 6; width: Tema.marcador
            height: 40 * Math.max(0, Math.min(1, (caixa.traco - 0.55) / 0.45))
            color: m.cor
        }
        Cantoneiras { cor: Tema.alfa(m.cor, 0.5); tamanho: 8; recuo: 5; opacity: caixa.superficie }

        Column {
            id: col
            opacity: caixa.acender
            x: 24; y: 20
            width: parent.width - 48
            spacing: 14
            Row {
                spacing: 10
                Codigo { text: m.codigo; color: m.cor; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 30; height: 1; color: Tema.alfa(m.cor, 0.5); anchors.verticalCenter: parent.verticalCenter }
            }
            TextoGlitch {
                text: m.aberto && caixa.traco >= 1 ? m.titulo : ""
                ocioso: false
                font.family: Tema.fRotulo; font.pixelSize: 26; font.weight: Font.Bold
                font.capitalization: Font.AllUppercase; font.letterSpacing: 1.5
                color: Tema.texto
            }
            Column { id: corpo; width: parent.width; spacing: 10 }
            Item { width: 1; height: 4 }
            Row { id: acoes; spacing: 10; anchors.right: parent.right }
        }
    }
}
