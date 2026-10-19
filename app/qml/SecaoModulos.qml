import QtQuick

Secao {
    id: s
    readonly property var grupos: {
        let g = [], vistos = {}
        for (const f of painel.fases) {
            const nome = f.grupo || Txt.t("grupo.outras")
            if (!(nome in vistos)) { vistos[nome] = g.length; g.push({ nome: nome, fases: [] }) }
            g[vistos[nome]].fases.push(f)
        }
        return g
    }
    readonly property int ligadas: painel.fases.filter(f => f.ligada === true).length
    readonly property int colunas: width > 1250 ? 3 : 2
    readonly property bool estadoConhecido: painel.suporteFases && painel.registroPorFase

    // resumo
    Item {
        id: resumo
        width: parent.width; height: 64
        Cascata { ativo: s.entrando; ordem: 0; vertical: true; alvo: resumo }
        Row {
            spacing: 26
            anchors.verticalCenter: parent.verticalCenter
            Column {
                spacing: 2
                Codigo { text: Txt.t("mod.fasesAtivas") }
                Text {
                    text: s.estadoConhecido ? ("0" + s.ligadas).slice(-2) + " / " + ("0" + painel.fases.length).slice(-2) : "?? / " + ("0" + painel.fases.length).slice(-2)
                    font.family: Tema.fIdentidade; font.pixelSize: 26; font.weight: Font.Bold
                    color: Tema.destaque
                }
            }
            BarraSegmentada {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(360, s.width * 0.3)
                height: 14
                larguraSeg: 10; vao: 4
                valor: painel.fases.length ? s.ligadas / painel.fases.length : 0
            }
            Leitura {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(420, s.width * 0.34)
                text: Txt.t("mod.intro")
            }
        }
    }

    // registro antigo: o CLI não sabe de qual fase veio cada chave
    Item {
        id: registroAntigo
        // montagem (ver Cascata)
        property real traco: 1
        property real superficie: 1
        property real acender: 1
        property real realce: 0
        visible: painel.suporteFases && !painel.registroPorFase
        width: parent.width; height: Math.max(raTx.implicitHeight, 40) + 24
        Cascata { ativo: s.entrando; ordem: 1; vertical: true; alvo: registroAntigo }
        Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.alerta, 0.07); borda: Tema.alfa(Tema.alerta, 0.6) ; traco: registroAntigo.traco; superficie: registroAntigo.superficie; realce: registroAntigo.realce }
        Rectangle { width: Tema.marcador; height: parent.height - 16; y: 8; color: Tema.alerta }
        Rotulo {
            id: raTit
            x: 16; anchors.verticalCenter: parent.verticalCenter
            text: Txt.t("mod.registroAntigo"); color: Tema.alerta; tamanho: 15
        }
        Leitura {
            id: raTx
            anchors.left: raTit.right; anchors.leftMargin: 14
            anchors.right: raBotao.left; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Tema.texto
            text: Txt.t("mod.registroAntigoTexto")
        }
        Botao {
            id: raBotao
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Txt.t("comum.ligar"); icone: "⏻"; tipo: "primario"; cor: Tema.alerta
            habilitado: !painel.ocupado
            onClicado: painel.ligarTema()
        }
        Chanfro { visible: registroAntigo.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfro; preenchimento: Tema.base; espessura: 0; opacity: 1 - registroAntigo.acender }
        QuadradosMontagem { z: 51; progresso: registroAntigo.traco; n: 3 }
    }

    // CLI sem suporte
    Item {
        visible: !painel.suporteFases
        width: parent.width; height: aviso.implicitHeight + 20
        Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.alerta, 0.07); borda: Tema.alfa(Tema.alerta, 0.6) }
        Rectangle { width: Tema.marcador; height: parent.height - 16; y: 8; color: Tema.alerta }
        Row {
            x: 16; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rotulo { text: Txt.t("mod.semSuporte"); color: Tema.alerta; tamanho: 15; anchors.verticalCenter: parent.verticalCenter }
            Leitura {
                id: aviso
                width: s.corpo.width - 190
                color: Tema.texto
                text: Txt.t("mod.semSuporteTexto")
            }
        }
    }

    Repeater {
        model: s.grupos
        Column {
            id: grupo
            required property var modelData
            required property int index
            width: s.corpo.width
            spacing: 12
            readonly property int base: {
                let n = 0
                for (let i = 0; i < index; i++) n += s.grupos[i].fases.length
                return n
            }
            Item {
                id: cab
                width: parent.width; height: 22
                Cascata { ativo: s.entrando; ordem: grupo.base + grupo.index; alvo: cab }
                Text {
                    id: letra
                    text: String.fromCharCode(65 + grupo.index)
                    font.family: Tema.fIdentidade; font.pixelSize: 13; font.weight: Font.Bold
                    color: Tema.destaque
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rotulo {
                    id: nomeGrupo
                    x: letra.width + 10
                    text: grupo.modelData.nome; tamanho: 17; color: Tema.texto2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    anchors.left: nomeGrupo.right; anchors.leftMargin: 12
                    anchors.right: contagem.left; anchors.rightMargin: 12
                    height: 1
                    color: Tema.linha
                    anchors.verticalCenter: parent.verticalCenter
                }
                Codigo {
                    id: contagem
                    anchors.right: parent.right
                    text: s.estadoConhecido ? grupo.modelData.fases.filter(f => f.ligada === true).length + "/" + grupo.modelData.fases.length : Txt.t("mod.nFases", { n: grupo.modelData.fases.length })
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Grid {
                columns: s.colunas
                spacing: 12
                width: parent.width
                Repeater {
                    model: grupo.modelData.fases
                    CartaoFase {
                        id: cf
                        required property var modelData
                        required property int index
                        fase: modelData
                        numero: painel.fases.findIndex(f => f.id === modelData.id) + 1
                        width: (grupo.width - (s.colunas - 1) * 12) / s.colunas
                        Cascata { ativo: s.entrando; ordem: grupo.base + grupo.index + 1 + cf.index; alvo: cf }
                        entrando: s.entrando
                        ordemStatus: grupo.base + cf.index
                    }
                }
            }
            Item { width: 1; height: 6 }
        }
    }
}
