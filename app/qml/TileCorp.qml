import QtQuick

// Miniatura de uma escolha de corporação na grade: ícone quadrado, nome, faixa da paleta e selo
// Txt.t("corp.emUso"). O mouse em cima mostra a paleta no painel inteiro; o clique seleciona (abre no inspetor).
Item {
    id: t
    // montagem (ver Cascata): moldura traçada, superfície, conteúdo acendendo, flash da borda
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0
    property var dados: ({})
    property int numero: 1
    property bool selecionado: false
    signal escolhido()
    signal sobre(bool dentro)

    readonly property var paleta: dados.paleta || ({ destaque: "#F75049", secundaria: "#5EF6FF", alerta: "#FB932E", fundo: "#0E0E17" })
    readonly property color corC: Tema.legivel(paleta.destaque)
    readonly property color fundoC: Tema.mistura(Qt.color(paleta.fundo), Tema.texto, 0.05)
    readonly property bool emUso: painel.corpAtual === dados.id
    readonly property bool aplicando: painel.alvo === dados.id || painel.alvosNaFila.indexOf(dados.id) >= 0
    readonly property bool _hover: area.containsMouse

    implicitHeight: 96
    readonly property bool vertical: height >= 132     // miniaturas altas: ícone grande em cima
    activeFocusOnTab: true
    Keys.onReturnPressed: t.escolhido()
    Keys.onSpacePressed: t.escolhido()

    scale: area.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Tema.press } }

    Chanfro {
        anchors.fill: parent
        traco: t.traco; superficie: t.superficie; realce: t.realce
        corte: Tema.chanfro + 2
        preenchimento: t.selecionado ? Tema.mistura(t.fundoC, t.corC, 0.12)
                     : t._hover ? Tema.mistura(t.fundoC, t.corC, 0.06) : Tema.alfa(t.fundoC, 0.96)
        borda: t.activeFocus ? Tema.secundaria : (t.selecionado ? t.corC : (t._hover || t.emUso ? Tema.alfa(t.corC, 0.6) : Tema.linha))
        espessura: t.selecionado || t.activeFocus ? 2 : 1
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
        Behavior on borda { ColorAnimation { duration: Tema.micro } }
    }
    Rectangle {
        x: 0; y: 12; width: Tema.marcador
        height: t.selecionado ? parent.height - 24 : 0
        color: t.corC
        Behavior on height { NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
    }

    Codigo {
        x: 12; y: 8
        text: ("0" + t.numero).slice(-2)
        tamanho: 9
        color: t.selecionado || t._hover ? t.corC : Tema.texto3
    }
    Rectangle {
        visible: t.emUso || t.aplicando
        anchors.right: parent.right; anchors.rightMargin: 8
        y: 7
        width: selo.implicitWidth + 10; height: 14
        color: t.aplicando ? "transparent" : t.corC
        border.color: t.corC; border.width: 1
        Codigo {
            id: selo
            anchors.centerIn: parent
            text: t.aplicando ? Txt.t("corp.aplicando") : Txt.t("corp.emUso")
            tamanho: 8; font.bold: true
            color: t.aplicando ? t.corC : Tema.escuro
        }
    }

    IconeMenu {
        id: ic
        // na horizontal, uma faixa fixa para o ícone (os nomes ficam alinhados entre miniaturas)
        readonly property real faixa: tamanho * 1.45
        x: t.vertical ? (t.width - width) / 2 : 14 + (faixa - width) / 2
        y: t.vertical ? 30 : (t.height - height) / 2 + 6
        tamanho: t.vertical ? Math.min(60, t.height * 0.4) : 36
        source: t.dados.icone || ""
        recorte: t.dados.iconeRecorte || null
        cor: t.corC
        visible: t.dados.id !== "personalizada"
    }
    // Personalizada: losango com o espectro
    Item {
        visible: t.dados.id === "personalizada"
        x: ic.x + (ic.width - ic.tamanho) / 2; y: ic.y; width: ic.tamanho; height: ic.tamanho
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: ic.tamanho * (0.82 - index * 0.2); height: width; rotation: 45
                color: index === 3 ? t.corC : "transparent"
                border.width: 2
                border.color: Qt.hsva(index / 4, 0.7, 1, 1)
            }
        }
    }

    Column {
        x: t.vertical ? 10 : 14 + ic.faixa + 10
        width: t.vertical ? t.width - 20 : t.width - x - 10
        y: t.vertical ? ic.y + ic.height + 14 : ic.y + (ic.height - height) / 2
        spacing: 6
        Rotulo {
            text: t.dados.nome || ""
            tamanho: 16
            width: parent.width
            horizontalAlignment: t.vertical ? Text.AlignHCenter : Text.AlignLeft
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 11
            elide: Text.ElideRight
            color: t.selecionado ? Tema.texto : Tema.texto2
        }
        Row {
            spacing: 2
            anchors.horizontalCenter: t.vertical ? parent.horizontalCenter : undefined
            Repeater {
                model: ["destaque", "secundaria", "alerta", "fundo"]
                Rectangle {
                    required property string modelData
                    width: modelData === "destaque" ? 22 : 11; height: 6
                    color: t.paleta[modelData]
                    border.width: modelData === "fundo" ? 1 : 0
                    border.color: Tema.alfa(Tema.texto, 0.3)
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: t.sobre(containsMouse)
        onClicked: t.escolhido()
    }

    // máscara do conteúdo durante a montagem (o conteúdo "acende" com flicker)
    Chanfro {
        visible: t.acender < 1
        z: 50
        anchors.fill: parent
        anchors.margins: 1
        corte: Tema.chanfro + 2
        preenchimento: Tema.base
        espessura: 0
        opacity: 1 - t.acender
    }
    QuadradosMontagem { z: 51; progresso: t.traco; n: 4 }
}
