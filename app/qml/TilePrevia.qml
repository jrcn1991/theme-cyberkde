import QtQuick

// Miniatura de uma escolha: prévia (png, ou webp/gif animado que só toca com o mouse em cima, com
// foco ou logo depois de escolhida), nome e, se houver, uma linha de descrição. Sem prévia, só o nome.
Item {
    id: t
    property string nome: ""
    property string descricao: ""
    property url previa: ""
    property bool selecionado: false
    property bool ocupado: false
    property bool padrao: false            // marca "PADRÃO" (o valor de fábrica)
    property real proporcao: 0.62           // altura/largura da prévia
    property string som: ""                  // prévia de som (arquivo): mostra o botão ▶
    signal escolhido()

    readonly property bool _anim: String(previa).match(/\.(webp|gif)(\?|$)/i) !== null
    readonly property bool _hover: area.containsMouse
    implicitWidth: 168
    implicitHeight: (previa != "" ? width * proporcao + 12 : 0) + rot.implicitHeight + (desc.visible ? desc.implicitHeight + 4 : 0) + 22
    activeFocusOnTab: true
    Keys.onReturnPressed: t.escolhido()
    Keys.onSpacePressed: t.escolhido()

    onSelecionadoChanged: if (selecionado && _anim && !Tema.reduzir) umCiclo.restart()
    Timer { id: umCiclo; interval: 2200 }

    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfro
        preenchimento: t.selecionado ? Tema.selecao : (t._hover ? Tema.hover : Tema.alfa(Tema.entrada, 0.9))
        borda: t.activeFocus ? Tema.secundaria : (t.selecionado ? Tema.destaque : (t._hover ? Tema.alfa(Tema.destaque, 0.5) : Tema.linha))
        espessura: t.selecionado || t.activeFocus ? 2 : 1
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
    }
    Column {
        x: 6; y: 6
        width: parent.width - 12
        spacing: 6
        Item {
            visible: t.previa != ""
            width: parent.width; height: width * t.proporcao
            Rectangle { anchors.fill: parent; color: Tema.mistura(Tema.fundo, "#000000", 0.3) }
            Image {
                visible: !t._anim
                anchors.fill: parent
                source: t._anim ? "" : t.previa
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: width * 2
                smooth: true
            }
            AnimatedImage {
                visible: t._anim
                anchors.fill: parent
                source: t._anim ? t.previa : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                readonly property bool tocar: (t._hover || t.activeFocus || umCiclo.running) && !Tema.reduzir
                playing: tocar
                paused: !tocar
                // parada, mostra o quadro do meio (o primeiro costuma ser a tela ainda vazia)
                onStatusChanged: if (status === AnimatedImage.Ready && !tocar) currentFrame = Math.floor(frameCount / 2)
                onTocarChanged: if (!tocar && status === AnimatedImage.Ready) currentFrame = Math.floor(frameCount / 2)
            }
        }
        Row {
            width: parent.width
            spacing: 6
            Rectangle {
                width: 7; height: 7; rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                color: t.selecionado ? Tema.destaque : "transparent"
                border.color: t.selecionado ? Tema.destaque : Tema.texto3
                // piscando enquanto o CLI aplica
                SequentialAnimation on opacity {
                    running: t.ocupado && !Tema.reduzir
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.2; duration: 250 }
                    NumberAnimation { to: 1; duration: 250 }
                }
            }
            Text {
                id: rot
                width: parent.width - 13 - (selo.visible ? selo.width + 6 : 0) - (t.som !== "" ? 28 : 0)
                text: t.nome
                elide: Text.ElideRight
                font.family: Tema.fTexto; font.pixelSize: 12
                font.weight: t.selecionado ? Font.DemiBold : Font.Normal
                color: t.selecionado ? Tema.texto : Tema.texto2
            }
            Codigo { id: selo; visible: t.padrao; text: Txt.t("cfg.selo.padrao"); tamanho: 8; anchors.verticalCenter: parent.verticalCenter }
            BotaoSom { visible: t.som !== ""; arquivo: t.som; anchors.verticalCenter: parent.verticalCenter }
        }
        Leitura {
            id: desc
            visible: t.descricao !== ""
            width: parent.width
            text: t.descricao
            tamanho: 11
            color: Tema.texto3
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { t.forceActiveFocus(); t.escolhido() }
    }
}
