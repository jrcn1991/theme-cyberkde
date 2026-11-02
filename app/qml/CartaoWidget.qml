import QtQuick

// Um widget na galeria da seção WIDGETS: prévia, nome, categoria, descrição e o estado com um
// interruptor grande. A prévia só "toca" no hover ou na seleção (e nunca com "reduzir animações"):
// uma imagem animada (webp/gif com quadros) toca; uma imagem parada larga (P·M·G lado a lado) é
// percorrida da esquerda para a direita. Clique seleciona (o inspetor mostra as opções).
Item {
    id: c
    property var dados: ({})
    property bool selecionado: false
    signal escolhido()

    readonly property bool ligado: dados.ligado === true
    readonly property bool naFila: painel.alvosNaFila.indexOf("fx:" + (dados.id || "")) >= 0 || painel.alvo === "fx:" + (dados.id || "")
    readonly property bool _hover: area.containsMouse
    readonly property bool tocar: (_hover || selecionado || activeFocus) && !Tema.reduzir && visible

    implicitHeight: 268
    activeFocusOnTab: true
    Keys.onReturnPressed: c.escolhido()
    Keys.onSpacePressed: c.escolhido()

    // montagem (ver Cascata)
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0

    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfro
        traco: c.traco; superficie: c.superficie; realce: c.realce
        preenchimento: c.selecionado ? Tema.selecao : (c._hover ? Tema.hover : Tema.alfa(Tema.painel, 0.94))
        borda: c.activeFocus ? Tema.secundaria : c.selecionado ? Tema.destaque : (c._hover ? Tema.alfa(Tema.destaque, 0.5) : Tema.linha)
        espessura: c.selecionado || c.activeFocus ? 2 : 1
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
    }
    Rectangle { x: 0; y: 14; width: Tema.marcador; height: 26; color: c.ligado ? Tema.destaque : Tema.linha; opacity: c.acender }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { c.forceActiveFocus(); c.escolhido() } }

    Column {
        x: 12; y: 10
        width: parent.width - 24
        spacing: 8
        opacity: c.acender

        // ---- prévia
        Item {
            id: caixa
            width: parent.width; height: 118
            clip: true
            Rectangle { anchors.fill: parent; color: Tema.mistura(Tema.fundo, "#000000", 0.35) }
            AnimatedImage {
                id: img
                source: c.dados.previa || ""
                asynchronous: true
                cache: false
                height: caixa.height
                readonly property real razao: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
                width: height * razao
                readonly property bool animada: frameCount > 1
                readonly property bool larga: width > caixa.width + 4
                // parada: centrada se couber; senão começa na esquerda (o tamanho pequeno)
                x: larga ? 0 : (caixa.width - width) / 2
                playing: animada && c.tocar
                paused: !(animada && c.tocar)
                opacity: c.ligado ? 1 : 0.75
            }
            SequentialAnimation {
                running: c.tocar && img.larga && !img.animada
                loops: Animation.Infinite
                onRunningChanged: if (!running) volta.restart()
                PauseAnimation { duration: 500 }
                NumberAnimation { target: img; property: "x"; to: caixa.width - img.width; duration: Math.max(1600, (img.width - caixa.width) * 6); easing.type: Easing.InOutSine }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: img; property: "x"; to: 0; duration: 900; easing.type: Easing.InOutSine }
            }
            NumberAnimation { id: volta; target: img; property: "x"; to: 0; duration: Tema.d(200) }
            Codigo {
                visible: c.dados.previa === "" || img.status === Image.Error
                anchors.centerIn: parent
                text: Txt.t("wg.semPrevia"); tamanho: 9
            }
            // selo de dados guardados (notas, tarefas…)
            Rectangle {
                visible: c.dados.dadosGuardados === true && !c.ligado
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                width: selo.implicitWidth + 10; height: 16
                color: Tema.alfa(Tema.secundaria, 0.18); border.color: Tema.secundaria
                Codigo { id: selo; anchors.centerIn: parent; text: Txt.t("wg.guardados"); tamanho: 8; color: Tema.secundaria }
            }
        }

        // ---- nome e categoria
        Item {
            width: parent.width; height: 22
            Rotulo { text: c.dados.nomeCurto || ""; tamanho: 17; anchors.verticalCenter: parent.verticalCenter; width: parent.width - cat.width - 8; elide: Text.ElideRight }
            Codigo { id: cat; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Txt.t("wg.cat." + (c.dados.categoria || "outros")).toUpperCase(); tamanho: 8 }
        }
        Leitura {
            width: parent.width
            tamanho: 12; color: Tema.texto2
            text: c.dados.descricao || ""
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }

        // ---- estado
        Item {
            width: parent.width; height: 34
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Rotulo {
                    text: c.ligado ? Txt.t("comum.ligado").toUpperCase() : Txt.t("comum.desligado").toUpperCase()
                    tamanho: 13; color: c.ligado ? Tema.destaque : Tema.texto3
                }
                Codigo {
                    readonly property var insts: c.dados.instancias || []
                    visible: insts.length > 1 || (c.ligado && (c.dados.naMesa || 0) > 1)
                    text: insts.length > 1 ? Txt.t("wg.nCercas", { n: insts.length, l: insts.filter(i => i.ligado).length }) : Txt.t("wg.telas", { n: c.dados.naMesa || 0 }); tamanho: 8
                }
            }
            Interruptor {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 32
                ligado: c.ligado
                // otimista (W6): já mostra o estado pedido e fica OCUPADO até a resposta e a releitura;
                // clicar de novo na espera vale como a intenção final (o painel manda só o último)
                ocupado: c.naFila || c.dados.ocupado === true
                cliqueOcupado: true
                habilitado: c.dados.disponivel !== false
                onAlternado: (novo) => painel.aplicarOpcoes(c.dados.id, { ligado: novo })
            }
        }
    }
}
