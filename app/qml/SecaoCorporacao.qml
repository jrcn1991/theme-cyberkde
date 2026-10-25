import QtQuick

// Corporação: grade 3×3 de miniaturas (7 corporações + Personalizada + Padrão) e um inspetor grande
// da selecionada. O mouse numa miniatura mostra a paleta dela no painel inteiro; o clique seleciona
// (a prévia fica na selecionada enquanto a seção está aberta). Nada muda no sistema sem confirmar.
Secao {
    id: s
    readonly property var esp: painel.especiais
    // Personalizada: a paleta em uso quando ela é a atual; senão, a de partida do tokens.
    readonly property var paletaPers: painel.corpAtual === "personalizada" ? painel.paleta
        : (esp.personalizada ? esp.personalizada.paleta : painel.paleta)
    readonly property var paletaPadrao: esp.nenhuma ? esp.nenhuma.paleta : painel.paleta

    readonly property var itens: painel.corps.concat([
        { id: "personalizada", nome: esp.personalizada ? esp.personalizada.nome : Txt.t("nome.personalizada"),
          lema: esp.personalizada ? esp.personalizada.lema : "", paleta: paletaPers, logo: "", icone: "" },
        { id: "nenhuma", nome: esp.nenhuma ? esp.nenhuma.nome : Txt.t("nome.nenhuma"),
          lema: esp.nenhuma ? esp.nenhuma.lema : "", paleta: paletaPadrao, logo: "", icone: "" }
    ])
    property string selecionado: ""
    property string sobre: ""
    readonly property string idInspetor: selecionado || painel.corpAtual
    readonly property int indiceInspetor: Math.max(0, itens.findIndex(x => x.id === idInspetor))
    readonly property var item: itens[indiceInspetor] || ({})

    // prévia: a miniatura sob o mouse ou, sem ela, a selecionada (se não for a que já está em uso)
    readonly property var paletaPrevia: {
        if (!ativa) return null
        const id = sobre || (selecionado !== painel.corpAtual ? selecionado : "")
        const it = itens.find(x => x.id === id)
        return it ? it.paleta : null
    }
    onPaletaPreviaChanged: if (app) app.previa(paletaPrevia)
    onAtivaChanged: if (!ativa) { sobre = ""; selecionado = "" }
    Connections {
        target: painel
        // depois de aplicar, a seleção volta a acompanhar a corporação em uso
        function onOperacaoTerminou(nome, codigo) { if (!painel.ocupado) s.selecionado = "" }
    }

    function aplicarItem(it) {
        if (it.id === "personalizada") { app.abrirSeletor(paletaPers); return }
        app.pedirCorp({ tipo: "corp", id: it.id, nome: it.nome, cor: it.paleta.destaque, paleta: it.paleta,
                        logo: it.logo || "", icone: it.icone || "", iconeRecorte: it.iconeRecorte || null })
    }

    readonly property bool lado: corpo.width >= 900
    readonly property real larguraGrade: lado ? Math.min(640, corpo.width * 0.56) : corpo.width
    // 15 escolhas: lado a lado, 4 colunas (4 linhas acompanham a altura do inspetor; a casa que
    // sobra vira um "slot livre" decorativo); empilhado, 5 colunas (5 × 3)
    readonly property int colunas: lado ? 4 : 5
    readonly property int linhas: Math.ceil(itens.length / colunas)
    readonly property int sobras: lado ? linhas * colunas - itens.length : 0
    readonly property real alturaTile: lado ? Math.max(96, (insp.implicitHeight - (linhas - 1) * 10) / linhas)
        : Math.max(132, (corpo.width - (colunas - 1) * 10) / colunas * 0.9)   // estreito: miniaturas verticais

    Item {
        id: intro
        width: parent.width; height: introTx.implicitHeight + 8
        Cascata { ativo: s.entrando; ordem: 0; vertical: true; alvo: intro }
        Leitura {
            id: introTx
            width: Math.min(parent.width, 820)
            color: Tema.texto2
            tamanho: 13
            text: Txt.t("corp.intro")
        }
    }

    // desfazer a última troca feita pelo painel
    Item {
        id: barraDesfazer
        // montagem (ver Cascata)
        property real traco: 1
        property real superficie: 1
        property real acender: 1
        property real realce: 0
        readonly property var d: painel.desfazer
        visible: !!d.tipo
        width: parent.width; height: 52
        Cascata { ativo: s.entrando; ordem: 1; vertical: true; alvo: barraDesfazer }
        Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.painel, 0.9); borda: Tema.linha ; traco: barraDesfazer.traco; superficie: barraDesfazer.superficie; realce: barraDesfazer.realce }
        Rectangle { width: Tema.marcador; height: 24; y: 14; color: Tema.secundaria }
        Row {
            x: 16; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Codigo { text: Txt.t("desfazer.anterior"); anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                color: barraDesfazer.d.cor || "transparent"
            }
            Rectangle {
                width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                color: barraDesfazer.d.paleta ? barraDesfazer.d.paleta.secundaria : "transparent"
            }
            Leitura {
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.NoWrap
                color: Tema.texto
                text: Txt.t("desfazer.antes", { nome: barraDesfazer.d.nome || "" }) + (barraDesfazer.d.tipo === "cor" ? " (" + barraDesfazer.d.cor + ")" : "")
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Atalho { tecla: "Ctrl+Z"; anchors.verticalCenter: parent.verticalCenter }
            Botao {
                text: Txt.t("comum.desfazer"); icone: "↶"; tamanho: 13
                habilitado: !painel.ocupado
                onClicado: s.app.desfazer()
            }
        }
        Chanfro { visible: barraDesfazer.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfro; preenchimento: Tema.base; espessura: 0; opacity: 1 - barraDesfazer.acender }
        QuadradosMontagem { z: 51; progresso: barraDesfazer.traco; n: 3 }
    }

    Flow {
        width: parent.width
        spacing: 20

        Grid {
            id: grade
            width: s.larguraGrade
            columns: s.colunas
            spacing: 10
            Repeater {
                model: s.itens
                TileCorp {
                    id: tile
                    required property var modelData
                    required property int index
                    width: (grade.width - (s.colunas - 1) * 10) / s.colunas
                    height: s.alturaTile
                    dados: modelData
                    numero: index + 1
                    selecionado: s.idInspetor === modelData.id
                    onEscolhido: s.selecionado = modelData.id
                    onSobre: (dentro) => {
                        if (dentro) s.sobre = modelData.id
                        else if (s.sobre === modelData.id) s.sobre = ""
                    }
                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Return && (e.modifiers & Qt.ControlModifier)) { s.aplicarItem(modelData); e.accepted = true }
                    }
                    Cascata { ativo: s.entrando; ordem: 2 + tile.index; alvo: tile }
                }
            }
            // casas que sobram na grade: slot livre com a contagem (decorativo)
            Repeater {
                model: s.sobras
                Item {
                    id: slot
                    // montagem (ver Cascata)
                    property real traco: 1
                    property real superficie: 1
                    property real acender: 1
                    property real realce: 0
                    required property int index
                    width: (grade.width - (s.colunas - 1) * 10) / s.colunas
                    height: s.alturaTile
                    Cascata { ativo: s.entrando; ordem: 2 + s.itens.length + slot.index; alvo: slot }
                    Chanfro {
                        traco: slot.traco; superficie: slot.superficie; realce: slot.realce
                        anchors.fill: parent
                        corte: Tema.chanfro + 2
                        preenchimento: "transparent"
                        borda: Tema.alfa(Tema.linha, 0.8)
                    }
                    Cantoneiras { cor: Tema.alfa(Tema.secundaria, 0.35); tamanho: 6; recuo: -6 }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ("0" + painel.corps.length).slice(-2)
                            font.family: Tema.fIdentidade; font.pixelSize: 26; font.weight: Font.Bold
                            color: Tema.alfa(Tema.secundaria, 0.7)
                        }
                        Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: Txt.t("corp.slotCorps"); tamanho: 9 }
                        Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: Txt.t("corp.slotLivre"); tamanho: 8; color: Tema.alfa(Tema.texto3, 0.7) }
                    }
                    Chanfro { visible: slot.acender < 1; z: 50; anchors.fill: parent; anchors.margins: 1; corte: Tema.chanfro + 2; preenchimento: Tema.base; espessura: 0; opacity: 1 - slot.acender }
                    QuadradosMontagem { z: 51; progresso: slot.traco; n: 3 }
                }
            }
        }

        InspetorCorp {
            id: insp
            width: s.lado ? s.corpo.width - s.larguraGrade - 20 : s.corpo.width
            height: implicitHeight
            dados: s.item
            numero: s.indiceInspetor + 1
            app: s.app
            onAplicar: s.aplicarItem(s.item)
            Cascata { ativo: s.entrando; ordem: 3; alvo: insp; vertical: true }
        }
    }

    Leitura {
        width: Math.min(parent.width, 820)
        tamanho: 12
        color: Tema.texto3
        text: Txt.t("corp.notaLogo")
    }
}
