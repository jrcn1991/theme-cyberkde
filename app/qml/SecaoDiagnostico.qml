import QtQuick

Secao {
    id: s
    readonly property var d: painel.diagnostico
    readonly property var resumo: {
        if (d.rodando) return { txt: Txt.t("diag.varrendo"), cor: Tema.secundaria, nota: Txt.t("diag.rodandoNota") }
        if (d.codigo === 0) return { txt: Txt.t("diag.ok"), cor: Tema.sucesso, nota: Txt.t("diag.okNota") }
        if (d.codigo === 2) return { txt: Txt.t("diag.corrigir"), cor: Tema.alerta, nota: Txt.t("diag.corrigirNota") }
        if (d.codigo === 1) return { txt: Txt.t("diag.bloqueio"), cor: Tema.erro, nota: Txt.t("diag.bloqueioNota") }
        if (d.codigo < 0 && d.hora) return { txt: Txt.t("diag.falha"), cor: Tema.erro, nota: Txt.t("diag.falhaNota") }
        return { txt: Txt.t("diag.aguardando"), cor: Tema.texto2, nota: Txt.t("diag.aguardandoNota") }
    }
    onAtivaChanged: if (ativa && !d.hora && !d.rodando) painel.checar()

    Item {
        id: topo
        // montagem (ver Cascata)
        property real traco: 1
        property real superficie: 1
        property real acender: 1
        property real realce: 0
        width: parent.width; height: 92
        Cascata { ativo: s.entrando; ordem: 0; vertical: true; alvo: topo }
        Chanfro { anchors.fill: parent; corte: Tema.chanfroG; preenchimento: Tema.alfa(Tema.painel, 0.92); borda: Tema.alfa(s.resumo.cor, 0.5) ; traco: topo.traco; superficie: topo.superficie; realce: topo.realce }
        Rectangle { y: 18; width: Tema.marcador; height: 30; color: s.resumo.cor }
        Column {
            x: 22; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Codigo { text: Txt.t("diag.codigo", { info: s.d.hora ? Txt.t("diag.ultima", { hora: s.d.hora, codigo: s.d.codigo }) : Txt.t("diag.nunca") }) }
            TextoGlitch {
                text: s.resumo.txt
                ocioso: false
                font.family: Tema.fRotulo; font.pixelSize: 28; font.weight: Font.Bold
                font.capitalization: Font.AllUppercase; font.letterSpacing: 1.5
                color: s.resumo.cor
            }
            Leitura { text: s.resumo.nota; tamanho: 12 }
        }
        Botao {
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: s.d.rodando ? Txt.t("diag.varrendo") : Txt.t("diag.executar")
            icone: "⌁"
            tipo: "primario"
            habilitado: !s.d.rodando
            onClicado: painel.checar()
        }
        // barra de varredura enquanto roda
        Rectangle {
            visible: s.d.rodando && !Tema.reduzir
            width: 120; height: 2
            y: parent.height - 2
            color: Tema.secundaria
            NumberAnimation on x { running: s.d.rodando && !Tema.reduzir; loops: Animation.Infinite; from: 0; to: topo.width - 120; duration: 900; easing.type: Easing.InOutSine }
        }
        Chanfro { visible: topo.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfroG; preenchimento: Tema.base; espessura: 0; opacity: 1 - topo.acender }
        QuadradosMontagem { z: 51; progresso: topo.traco; n: 3 }
    }

    Repeater {
        model: s.d.itens
        Item {
            id: it
            // montagem (ver Cascata)
            property real traco: 1
            property real superficie: 1
            property real acender: 1
            property real realce: 0
            required property var modelData
            required property int index
            readonly property color cor: modelData.nivel === "impede" ? Tema.erro : modelData.nivel === "corrigir" ? Tema.alerta
                : modelData.nivel === "aviso" ? Tema.secundaria : modelData.nivel === "ok" ? Tema.sucesso : Tema.texto3
            readonly property bool texto: modelData.nivel === "texto"
            width: s.corpo.width
            height: it.texto ? tx.implicitHeight + 6 : Math.max(48, colIt.implicitHeight + 24)
            Cascata { ativo: true; ordem: it.index; alvo: it }
            Chanfro {
                traco: it.traco; superficie: it.superficie; realce: it.realce
                visible: !it.texto
                anchors.fill: parent
                preenchimento: Tema.alfa(Tema.painel, 0.9)
                borda: Tema.alfa(it.cor, 0.35)
            }
            Rectangle { visible: !it.texto; y: 10; width: Tema.marcador; height: parent.height - 20; color: it.cor }
            Leitura {
                id: tx
                visible: it.texto
                x: 4
                width: parent.width
                text: it.modelData.texto
                color: Tema.texto2
            }
            Row {
                visible: !it.texto
                x: 18; y: 12
                spacing: 14
                Item {
                    width: 78; height: 18
                    Rectangle { anchors.fill: parent; color: Tema.alfa(it.cor, 0.12); border.color: it.cor }
                    Codigo {
                        anchors.centerIn: parent
                        tamanho: 9; font.bold: true
                        color: it.cor
                        text: ({ impede: Txt.t("diag.nivel.impede"), corrigir: Txt.t("diag.nivel.corrigir"), aviso: Txt.t("diag.nivel.aviso"), ok: Txt.t("comum.ok") })[it.modelData.nivel] || ""
                    }
                }
                Column {
                    id: colIt
                    width: it.width - 140
                    spacing: 6
                    Leitura { width: parent.width; text: it.modelData.texto; color: Tema.texto; tamanho: 13 }
                    Repeater {
                        model: it.modelData.correcao
                        Item {
                            required property string modelData
                            width: colIt.width; height: cmd.implicitHeight + 10
                            Rectangle { anchors.fill: parent; color: Tema.entrada }
                            Text {
                                id: cmd
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 80
                                text: parent.modelData
                                font.family: Tema.fMono; font.pixelSize: 12
                                color: Tema.texto2
                                wrapMode: Text.WrapAnywhere
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Txt.t("comum.copiarCaps")
                                font.family: Tema.fRotulo; font.pixelSize: 12; font.weight: Font.DemiBold
                                color: copia.containsMouse ? Tema.secundaria : Tema.texto3
                                MouseArea {
                                    id: copia
                                    anchors.fill: parent; anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { painel.copiar(parent.parent.modelData); painel.notificar("ok", Txt.t("notif.copiado")) }
                                }
                            }
                        }
                    }
                }
            }
            Chanfro { visible: it.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfro; preenchimento: Tema.base; espessura: 0; opacity: 1 - it.acender }
            QuadradosMontagem { z: 51; progresso: it.traco; n: 3 }
        }
    }
}
