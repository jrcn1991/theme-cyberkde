import QtQuick

// Seletor grande de MOVIMENTO (SYS.CONFIG do NetWatch OS): Completo · Reduzido · Mínimo.
// Grava no tema ("cyberkde efeito movimento …", que mapeia para o AnimationDurationFactor do KDE) e
// comanda também o "reduzir animações" do próprio painel. Sem o efeito no CLI, só vale para o painel.
Item {
    id: m
    readonly property var efeito: painel.fxMovimento
    readonly property bool suporte: !!efeito && !!efeito.id
    readonly property var opcao: suporte ? (efeito.opcoes || []).find(o => o.id === "nivel") : null
    readonly property string nivel: opcao ? opcao.valor : (painel.reduzirAnimacoes ? "reduzido" : "completo")
    readonly property bool rodando: painel.alvo === "fx:movimento"
    property string _escolhido: ""
    readonly property string atual: _escolhido || nivel
    onNivelChanged: _escolhido = ""
    implicitHeight: 104

    function escolher(id) {
        if (id === atual) return
        _escolhido = id
        if (suporte) painel.aplicarOpcoes("movimento", { nivel: id })
        else painel.reduzirAnimacoes = id !== "completo"
    }

    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfroG
        preenchimento: Tema.alfa(Tema.painel, 0.94)
        borda: Tema.alfa(Tema.destaque, 0.5)
    }
    Rectangle { x: 0; y: 14; width: Tema.marcador; height: 30; color: Tema.destaque }
    Column {
        x: 20; y: 14
        width: 230
        spacing: 4
        Row {
            spacing: 8
            Rotulo { text: Txt.t("cfg.movimento"); tamanho: 18 }
            Codigo { text: "SYS.MOTION"; anchors.verticalCenter: parent.verticalCenter }
        }
        Leitura {
            width: parent.width
            tamanho: 11
            text: m.suporte ? Txt.t("cfg.movimentoAjuda") : Txt.t("cfg.movimentoSoPainel")
            color: m.suporte ? Tema.texto2 : Tema.alerta
        }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: [
                { id: "completo", barras: 5 },
                { id: "reduzido", barras: 2 },
                { id: "minimo", barras: 0 }
            ]
            Item {
                id: op
                required property var modelData
                readonly property bool sel: m.atual === modelData.id
                width: Math.max(150, (m.width - 300) / 3); height: 72
                activeFocusOnTab: true
                Keys.onSpacePressed: m.escolher(modelData.id)
                Keys.onReturnPressed: m.escolher(modelData.id)
                Chanfro {
                    anchors.fill: parent
                    preenchimento: op.sel ? Tema.selecao : (ma.containsMouse ? Tema.hover : Tema.entrada)
                    borda: op.activeFocus ? Tema.secundaria : (op.sel ? Tema.destaque : Tema.linha)
                    espessura: op.sel || op.activeFocus ? 2 : 1
                    Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
                }
                // "medidor" de movimento: barras que acendem
                Row {
                    x: 12; y: 12
                    spacing: 3
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: 4; height: 8 + index * 3
                            anchors.bottom: parent.bottom
                            color: index < op.modelData.barras ? (op.sel ? Tema.destaque : Tema.texto3) : Tema.alfa(Tema.texto3, 0.2)
                        }
                    }
                }
                Column {
                    x: 12; y: 34
                    width: parent.width - 24
                    spacing: 2
                    Rotulo { text: Txt.t("cfg.mov." + op.modelData.id); tamanho: 16; color: op.sel ? Tema.texto : Tema.texto2 }
                    Leitura {
                        width: parent.width
                        text: Txt.t("cfg.mov." + op.modelData.id + ".desc")
                        tamanho: 10; color: Tema.texto3
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
                Codigo {
                    visible: op.sel && m.rodando
                    anchors.right: parent.right; anchors.rightMargin: 8; y: 8
                    text: Txt.t("fase.estado.processando"); tamanho: 8; color: Tema.secundaria
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: m.escolher(op.modelData.id) }
            }
        }
    }
}
