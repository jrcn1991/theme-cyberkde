import QtQuick

// Uma animação de janela na galeria: prévia (toca no hover ou quando escolhida), nome, descrição,
// duração e selos ABRIR / FECHAR quando ela é a escolhida para cada lado. Clique: escolhe para o
// lado do filtro atual ("modo").
Item {
    id: c
    property var dados: ({})
    property string modo: "abrir"
    property bool escolhidaAbrir: false
    property bool escolhidaFechar: false
    property bool escolhidaPrimeira: false
    property int numero: 1
    signal escolhida()

    // montagem (ver Cascata)
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0

    readonly property bool escolhida_: modo === "abrir" ? escolhidaAbrir : modo === "primeira" ? escolhidaPrimeira : escolhidaFechar
    readonly property bool _ladoAbrir: modo !== "fechar"
    readonly property bool _hover: area.containsMouse
    onEscolhida_Changed: if (escolhida_ && !Tema.reduzir) umCiclo.restart()
    Timer {
        id: umCiclo
        interval: 260 + Math.max(150, (c._ladoAbrir ? c.dados.duracaoAbrir : c.dados.duracaoFechar) * 1.6) + 400
    }
    implicitHeight: 236
    activeFocusOnTab: true
    Keys.onReturnPressed: c.escolhida()
    Keys.onSpacePressed: c.escolhida()

    Chanfro {
        anchors.fill: parent
        traco: c.traco; superficie: c.superficie; realce: c.realce
        corte: Tema.chanfro + 2
        preenchimento: c.escolhida_ ? Tema.mistura(Tema.painel, Tema.destaque, 0.1) : (c._hover ? Tema.elevado : Tema.alfa(Tema.painel, 0.94))
        borda: c.activeFocus ? Tema.secundaria : (c.escolhida_ ? Tema.destaque : (c._hover ? Tema.alfa(Tema.destaque, 0.5) : Tema.linha))
        espessura: c.escolhida_ || c.activeFocus ? 2 : 1
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
    }

    Column {
        x: 10; y: 10
        width: parent.width - 20
        spacing: 8
        PreviaJanela {
            width: parent.width
            height: width * 0.56
            estilo: c.dados.estilo || "varredura"
            modo: c._ladoAbrir ? "abrir" : "fechar"
            fonte: c._ladoAbrir ? (c.dados.previaAbrir || "") : (c.dados.previaFechar || "")
            duracao: c._ladoAbrir ? (c.dados.duracaoAbrir || 280) : (c.dados.duracaoFechar || 200)
            // em laço só com o mouse em cima ou com o foco; ao ser escolhida, toca um ciclo e para
            tocar: c._hover || c.activeFocus || umCiclo.running
        }
        Row {
            width: parent.width
            spacing: 6
            Codigo { text: ("0" + c.numero).slice(-2); tamanho: 9; color: c.escolhida_ ? Tema.destaque : Tema.texto3; anchors.verticalCenter: parent.verticalCenter }
            Rotulo {
                text: c.dados.nome || ""
                tamanho: 15
                width: parent.width - 80
                elide: Text.ElideRight
                color: c.escolhida_ ? Tema.texto : Tema.texto2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Leitura {
            text: c.dados.descricao || ""
            width: parent.width
            tamanho: 11
            maximumLineCount: 2
            elide: Text.ElideRight
            height: 30
        }
        Row {
            spacing: 6
            Codigo {
                visible: c.dados.id !== "nenhuma"
                text: (c._ladoAbrir ? c.dados.duracaoAbrir : c.dados.duracaoFechar) + " ms"
                tamanho: 9
                anchors.verticalCenter: parent.verticalCenter
            }
            Repeater {
                model: [{ l: "abrir", s: c.escolhidaAbrir }, { l: "fechar", s: c.escolhidaFechar }, { l: "primeira", s: c.escolhidaPrimeira }]
                Rectangle {
                    required property var modelData
                    visible: modelData.s
                    width: selo.implicitWidth + 10; height: 14
                    color: Tema.destaque
                    anchors.verticalCenter: parent.verticalCenter
                    Codigo { id: selo; anchors.centerIn: parent; text: Txt.t("fx.selo." + parent.modelData.l); tamanho: 8; font.bold: true; color: Tema.escuro }
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { c.forceActiveFocus(); c.escolhida() }
    }

    Chanfro { visible: c.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfro + 2; preenchimento: Tema.base; espessura: 0; opacity: 1 - c.acender }
    QuadradosMontagem { z: 51; progresso: c.traco; n: 3 }
}
