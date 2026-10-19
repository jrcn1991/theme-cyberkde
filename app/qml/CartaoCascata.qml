import QtQuick

// Cartão do efeito "cascata de dados" do Konsole animado (konsole/PEDIDO-CLI.md): interruptor,
// altura da faixa (2–20 linhas), cores (vídeo / tema) e a prévia animada. Fala com o CLI por
// "cyberkde efeito konsole-cascata on|off --linhas N --cores X --json" (painel.ajustarCascata).
// Mudanças na altura e nas cores esperam 450 ms paradas antes de ir ao CLI.
Bloco {
    id: b
    titulo: Txt.t("cascata.titulo")
    codigo: "FX-01 // konsole-cascata"
    destaque: estado.ligado === true

    readonly property var estado: painel.cascata
    readonly property bool suporte: estado.suporte === true
    readonly property bool indisponivel: estado.disponivel === false
    readonly property bool rodando: painel.alvo === "konsole-cascata"

    // valores locais (o que a usuária está escolhendo), sincronizados com o CLI quando ele responde
    property bool ligado: estado.ligado === true
    property int linhas: estado.linhas || 5
    property string cores: estado.cores || "video"
    property bool _pendente: false
    Connections {
        target: painel
        function onCascataMudou() {
            if (b._pendente) return
            b.ligado = painel.cascata.ligado === true
            b.linhas = painel.cascata.linhas || 5
            b.cores = painel.cascata.cores || "video"
        }
    }
    function enviar(imediato) {
        _pendente = true
        espera.interval = imediato ? 1 : 450
        espera.restart()
    }
    Timer {
        id: espera
        onTriggered: { b._pendente = false; painel.ajustarCascata(b.ligado, b.linhas, b.cores) }
    }

    readonly property bool _hover: hoverCartao.hovered
    HoverHandler { id: hoverCartao }

    Row {
        width: parent.width
        spacing: 22

        // ---- controles
        Column {
            id: controles
            width: Math.min(420, parent.width * 0.5)
            spacing: 14

            Row {
                spacing: 12
                Interruptor {
                    id: chave
                    ligado: b.suporte ? b.ligado : null
                    ocupado: b.rodando
                    habilitado: b.suporte && !b.rodando
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: (novo) => { b.ligado = novo; b.enviar(true) }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Rotulo { text: Txt.t("cascata.nome"); tamanho: 17 }
                    Codigo {
                        tamanho: 9
                        text: !b.suporte ? Txt.t("mod.semSuporte").toUpperCase()
                            : b.rodando ? Txt.t("fase.estado.processando")
                            : (b.ligado ? Txt.t("fase.estado.ativa") : Txt.t("fase.estado.inativa"))
                        color: b.ligado && b.suporte ? Tema.destaque : Tema.texto3
                    }
                }
            }
            Leitura {
                width: parent.width
                tamanho: 12
                text: Txt.t("cascata.descricao", { n: b.linhas })
            }

            // altura da faixa: 19 segmentos (2..20), clique ou arraste
            Column {
                spacing: 6
                width: parent.width
                opacity: b.suporte ? 1 : 0.45
                Row {
                    spacing: 8
                    Codigo { text: Txt.t("cascata.altura"); tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: Txt.t("cascata.linhasValor", { n: b.linhas })
                        font.family: Tema.fIdentidade; font.pixelSize: 12; font.weight: Font.Bold
                        color: Tema.destaque
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Item {
                    id: trilho
                    width: parent.width; height: 18
                    activeFocusOnTab: b.suporte
                    Keys.onLeftPressed: { if (b.linhas > 2) { b.linhas--; b.enviar(false) } }
                    Keys.onRightPressed: { if (b.linhas < 20) { b.linhas++; b.enviar(false) } }
                    Row {
                        anchors.fill: parent
                        spacing: 2
                        Repeater {
                            model: 19
                            Rectangle {
                                required property int index
                                width: (trilho.width - 18 * 2) / 19
                                height: trilho.height
                                color: index + 2 <= b.linhas ? Tema.destaque : Tema.alfa(Tema.destaque, 0.12)
                                border.width: index + 2 === 5 ? 1 : 0     // marca do padrão (5)
                                border.color: Tema.alfa(Tema.texto, 0.5)
                                Behavior on color { ColorAnimation { duration: Tema.micro } }
                            }
                        }
                    }
                    Rectangle {
                        visible: trilho.activeFocus
                        anchors.fill: parent; anchors.margins: -3
                        color: "transparent"; border.color: Tema.secundaria; border.width: 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: b.suporte
                        cursorShape: Qt.PointingHandCursor
                        function pegar(m) {
                            const v = Math.max(2, Math.min(20, 2 + Math.floor(m.x / width * 19)))
                            if (v !== b.linhas) { b.linhas = v; b.enviar(false) }
                        }
                        onPressed: (m) => pegar(m)
                        onPositionChanged: (m) => { if (pressed) pegar(m) }
                    }
                }
                Row {
                    width: parent.width
                    Codigo { text: "2"; tamanho: 8; width: parent.width / 2 }
                    Codigo { text: "20"; tamanho: 8; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
                }
            }

            // cores
            Column {
                spacing: 6
                opacity: b.suporte ? 1 : 0.45
                Codigo { text: Txt.t("cascata.coresRotulo"); tamanho: 9 }
                Row {
                    spacing: 8
                    Repeater {
                        model: [
                            { id: "video", paradas: ["#D9362B", "#F2792E", "#F2C14E", "#E9E4F7", "#9B7BE8"] },
                            { id: "tema", paradas: [Tema.destaque, Tema.alerta, "#ECEAF2", Tema.secundaria] }
                        ]
                        Item {
                            id: op
                            required property var modelData
                            readonly property bool sel: b.cores === modelData.id
                            width: 150; height: 34
                            activeFocusOnTab: b.suporte
                            Keys.onSpacePressed: escolher()
                            Keys.onReturnPressed: escolher()
                            function escolher() { if (b.suporte && b.cores !== modelData.id) { b.cores = modelData.id; b.enviar(true) } }
                            Chanfro {
                                anchors.fill: parent
                                preenchimento: op.sel ? Tema.selecao : Tema.entrada
                                borda: op.activeFocus ? Tema.secundaria : (op.sel ? Tema.destaque : Tema.linha)
                                espessura: op.activeFocus ? 2 : 1
                            }
                            Row {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: op.modelData.paradas
                                        Rectangle { required property var modelData; width: 7; height: 12; color: modelData }
                                    }
                                }
                                Rotulo {
                                    text: Txt.t("cascata.cores." + op.modelData.id)
                                    tamanho: 14
                                    color: op.sel ? Tema.texto : Tema.texto2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: op.escolher() }
                        }
                    }
                }
            }
        }

        // ---- prévia
        Column {
            width: parent.width - controles.width - 22
            spacing: 6
            Row {
                spacing: 8
                Codigo { text: Txt.t("cascata.previa"); tamanho: 9 }
                Codigo { text: b.ligado ? "" : Txt.t("cascata.previaDesligada"); tamanho: 9; color: Tema.texto3 }
            }
            Item {
                width: parent.width
                height: pluma.implicitHeight
                Chanfro { anchors.fill: parent; anchors.margins: -1; preenchimento: "transparent"; borda: Tema.linha }
                PlumaCascata {
                    id: pluma
                    anchors.fill: parent
                    linhas: b.linhas
                    cores: b.cores
                    // anima com o efeito ligado ou com o mouse em cima (desligado, a prévia fica parada)
                    animar: b.ligado || b._hover
                    opacity: b.ligado ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: Tema.padrao } }
                }
            }
        }
    }

    // avisos: CLI sem o comando, ou Konsole sem o efeito
    Item {
        visible: !b.suporte || b.indisponivel
        width: parent.width
        height: Math.max(avisoTx.implicitHeight, religar.visible ? religar.height : 0) + 18
        Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.alerta, 0.07); borda: Tema.alfa(Tema.alerta, 0.6) }
        Rectangle { width: Tema.marcador; height: parent.height - 12; y: 6; color: Tema.alerta }
        Leitura {
            id: avisoTx
            x: 14; width: parent.width - 28 - (religar.visible ? religar.width + 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            color: Tema.texto
            tamanho: 12
            text: !b.suporte ? Txt.t("cascata.semSuporteTexto")
                : (b.estado.disponivelAoReligar ? Txt.t("cascata.religarTexto") : Txt.t("cascata.indisponivelTexto"))
        }
        // a versão nova já está instalada: religar a fase "Konsole animado" passa a usá-la
        Botao {
            id: religar
            visible: b.suporte && b.estado.disponivelAoReligar === true
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Txt.t("cascata.religar"); icone: "⏻"; tamanho: 12
            cor: Tema.alerta
            habilitado: !painel.ocupado
            onClicado: painel.alternarFase("konsole-anim", true)
        }
    }
}
