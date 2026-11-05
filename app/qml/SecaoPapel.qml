import QtQuick

// Seção PAPEL DE PAREDE: escolher entre o papel ANIMADO (o FUI, "cyberkde efeito papel fui") e os
// ESTÁTICOS (A, B, C, D, o da corporação e uma imagem própria, "cyberkde papel <imagem>"), conforme a
// máquina. Em cima, a seleção atual com o modo (fixo, ou acompanha a corporação) e o lembrete de que o
// bloqueio e o login seguem o papel; uma dica automática recomenda o estático sem placa de vídeo dedicada
// ou com renderização por software. Os controles do FUI só se ligam quando o CLI os expõe (estado.fui).
Secao {
    id: s
    readonly property var info: painel.papelInfo || ({})
    readonly property var stp: (painel.status && painel.status.papel) || ({})
    readonly property string modo: stp.modo || info.modo || ""
    readonly property bool propria: !!painel.papelCaminho
    readonly property string opcao: propria ? "propria" : (info.opcao || stp.opcao || "a")
    readonly property var valores: info.valores || []
    readonly property var fuiVal: valores.find(v => v.id === "fui") || null
    readonly property var estaticos: valores.filter(v => v.id !== "fui")
    readonly property var gpu: painel.gpu || ({})
    readonly property bool recomendaEstatico: gpu.lido && (gpu.software || !gpu.dedicada)
    readonly property bool ocupado: painel.alvo === "papel" || painel.alvo === "papeis-de-parede"
    readonly property var fui: info.fui || ({})
    readonly property bool lado: corpo.width >= 980
    readonly property var pp: painel.papelPasta || ({ suporte: false, itens: [] })
    readonly property bool temPasta: !!pp.pasta && pp.existe === true
    function escolherPasta() { s.app.escolherPasta(pp.pasta || "", (c) => painel.papelPastaEscolher(c)) }
    // deslizadores: aplica 600 ms depois que param de mexer (um comando, não um por passo)
    property var _pend: ({})
    function ajustarDepois(k, v) { let p = Object.assign({}, _pend); p[k] = v; _pend = p; aplicaDepois.restart() }
    Timer {
        id: aplicaDepois; interval: 600
        onTriggered: {
            for (const k in s._pend) painel.ajustarFui(k, s._pend[k])
            s._pend = ({})
        }
    }
    readonly property var itemPasta: (pp.itens || []).find(i => i.emUso) || null
    function nomeAtual() {
        if (propria) return Txt.t("papel.propria")
        if (opcao === "usuario") return itemPasta ? itemPasta.nome : Txt.t("papel.suaPasta")
        const v = valores.find(x => x.id === opcao)
        return v ? v.nome : opcao.toUpperCase()
    }
    function previaAtual() {
        if (propria) return painel.papel
        if (opcao === "usuario") return itemPasta ? itemPasta.previa : ""
        const v = valores.find(x => x.id === opcao)
        return v ? v.previa : ""
    }

    // ---- seleção atual
    Bloco {
        id: atual
        width: s.corpo.width
        titulo: Txt.t("papel.atual")
        codigo: "WALLPAPER // " + (s.opcao === "fui" ? "ANIMATED" : s.itemPasta && s.itemPasta.tipo === "video" ? "VIDEO" : "STATIC") + " · " + (s.modo === "corp" ? "CORP" : "FIXED")
        Cascata { ativo: s.entrando; ordem: 0; alvo: atual }
        Row {
            width: parent.width
            spacing: 18
            Item {
                width: Math.min(300, parent.width * 0.32); height: width * 9 / 16
                Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.entrada; borda: Tema.destaque }
                AnimatedImage {
                    anchors.fill: parent; anchors.margins: 2
                    source: s.previaAtual()
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false
                    playing: !Tema.reduzir && s.ativa
                    paused: !playing
                }
            }
            Column {
                width: parent.width - Math.min(300, parent.width * 0.32) - 18
                spacing: 8
                Row {
                    spacing: 10
                    // nome de arquivo da pessoa: fonte de leitura, com a caixa real
                    Rotulo { visible: s.opcao !== "usuario"; text: s.nomeAtual(); tamanho: 20; color: Tema.texto }
                    Text { visible: s.opcao === "usuario"; text: s.nomeAtual(); font.family: Tema.fTexto; font.pixelSize: 20; font.weight: Font.DemiBold; color: Tema.texto }
                    // o modo: fixo ou acompanhando a corporação
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: tm.implicitWidth + 16; height: 22
                        Chanfro { anchors.fill: parent; corte: 5; preenchimento: s.modo === "corp" ? Tema.alfa(Tema.secundaria, 0.18) : Tema.alfa(Tema.destaque, 0.15); borda: s.modo === "corp" ? Tema.secundaria : Tema.destaque }
                        Codigo { id: tm; anchors.centerIn: parent; tamanho: 10; font.bold: true; color: s.modo === "corp" ? Tema.secundaria : Tema.destaque
                                 text: s.modo === "corp" ? Txt.t("papel.modoCorp") : Txt.t("papel.modoFixo") }
                    }
                }
                Leitura { visible: s.propria; width: parent.width; tamanho: 12; color: Tema.texto2; text: painel.papelCaminho; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: s.modo === "corp" ? Txt.t("papel.modoCorpAjuda") : Txt.t("papel.modoFixoAjuda") }
                Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Txt.t("papel.seguem") }
                Leitura { width: parent.width; tamanho: 12; color: Tema.texto3; text: painel.temaLigado ? Txt.t("papel.ligado") : Txt.t("papel.desligado") }
            }
        }
        // dica automática pela máquina
        Item {
            visible: s.gpu.lido === true
            width: parent.width; height: dica.implicitHeight + 16
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(s.recomendaEstatico ? Tema.alerta : Tema.sucesso, 0.10); borda: Tema.alfa(s.recomendaEstatico ? Tema.alerta : Tema.sucesso, 0.6) }
            Leitura {
                id: dica
                x: 12; y: 8; width: parent.width - 24; tamanho: 13
                color: Tema.texto
                text: (s.gpu.software ? Txt.t("papel.gpuSoftware") : !s.gpu.dedicada ? Txt.t("papel.gpuIntegrada") : Txt.t("papel.gpuDedicada"))
                      + (s.gpu.nome ? "  ·  " + s.gpu.nome : "")
            }
        }
    }

    Flow {
        width: s.corpo.width
        spacing: 20
        // ---- ANIMADO
        Bloco {
            id: anim
            width: s.lado ? (s.corpo.width - 20) * 0.46 : s.corpo.width
            titulo: Txt.t("papel.animado")
            codigo: "FUI // " + (s.info.corp || "nenhuma").toUpperCase()
            destaque: s.opcao === "fui"
            Cascata { ativo: s.entrando; ordem: 1; alvo: anim }
            Item {
                width: parent.width; height: width * 9 / 16
                Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.entrada; borda: s.opcao === "fui" ? Tema.destaque : Tema.linha; espessura: s.opcao === "fui" ? 2 : 1 }
                AnimatedImage {
                    id: prevFui
                    anchors.fill: parent; anchors.margins: 2
                    source: s.fuiVal ? s.fuiVal.previa : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false
                    playing: !Tema.reduzir && s.ativa
                    paused: !playing
                }
                Codigo { visible: prevFui.status !== Image.Ready; anchors.centerIn: parent; text: "FUI // —"; tamanho: 11 }
                Codigo { visible: s.opcao === "fui"; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; text: "● " + Txt.t("papel.emUso"); tamanho: 10; font.bold: true; color: Tema.destaque; style: Text.Outline; styleColor: Tema.escuro }
            }
            Leitura { width: parent.width; tamanho: 12; color: Tema.texto2; text: Txt.t("papel.notaFui") }
            Botao {
                text: s.opcao === "fui" ? Txt.t("papel.emUso") : Txt.t("papel.usarAnimado"); icone: "▶"; tipo: "primario"
                habilitado: !s.ocupado && s.opcao !== "fui" && !!s.fuiVal
                onClicado: painel.escolherPapelOpcao("fui")
            }
            // controles do plugin (pelo CLI; desligados até ele expor estado.fui)
            Column {
                width: parent.width
                spacing: 8
                Rotulo { text: Txt.t("papel.controles"); tamanho: 13; color: Tema.texto2 }
                Leitura { visible: !s.info.fuiControles; width: parent.width; tamanho: 11; color: Tema.texto3; text: Txt.t("papel.controlesPendentes") }
                Deslizador { width: parent.width; rotulo: Txt.t("papel.intensidade"); de: 30; ate: 200; passo: 10; unidade: "%"; valor: s.fui.intensidade || 100; padrao: 100; habilitado: !!s.info.fuiControles && !s.ocupado; onMovido: (v) => s.ajustarDepois("intensidade", v) }
                Deslizador { width: parent.width; rotulo: Txt.t("papel.velocidade"); de: 25; ate: 300; passo: 25; unidade: "%"; valor: s.fui.velocidade || 100; padrao: 100; habilitado: !!s.info.fuiControles && !s.ocupado; onMovido: (v) => s.ajustarDepois("velocidade", v) }
                Row {
                    spacing: 8
                    opacity: s.info.fuiControles ? 1 : 0.45
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: "FPS"; tamanho: 11; color: Tema.texto2; width: 60 }
                    Repeater {
                        model: [30, 60]
                        Botao {
                            required property int modelData
                            text: String(modelData); tamanho: 11
                            tipo: (s.fui.fps || 30) === modelData ? "primario" : "secundario"
                            habilitado: !!s.info.fuiControles && !s.ocupado
                            onClicado: painel.ajustarFui("fps", modelData)
                        }
                    }
                }
                Repeater {
                    model: [{ k: "logo", t: "papel.logo" }, { k: "corLogo", t: "papel.corLogo", cli: "cor-logo" }, { k: "textos", t: "papel.textos" }, { k: "pausar", t: "papel.pausar" }]
                    Row {
                        required property var modelData
                        spacing: 10
                        opacity: s.info.fuiControles ? 1 : 0.45
                        Interruptor {
                            anchors.verticalCenter: parent.verticalCenter
                            // corLogo é escolha (tingido|original), não liga/desliga; sem ela no CLI, o interruptor fica apagado
                            readonly property bool ehCor: parent.modelData.k === "corLogo"
                            ligado: !s.info.fuiControles ? null : ehCor ? s.fui.corLogo === "original" : s.fui[parent.modelData.k] !== false
                            habilitado: !!s.info.fuiControles && !s.ocupado && (!ehCor || s.fui.corLogo !== undefined)
                            onAlternado: (v) => painel.ajustarFui(parent.modelData.cli || parent.modelData.k, v)
                        }
                        Leitura { anchors.verticalCenter: parent.verticalCenter; tamanho: 13; wrapMode: Text.NoWrap; text: Txt.t(parent.modelData.t) }
                    }
                }
            }
        }

        // ---- ESTÁTICO
        Bloco {
            id: est
            width: s.lado ? (s.corpo.width - 20) * 0.54 : s.corpo.width
            titulo: Txt.t("papel.estatico")
            codigo: "STATIC // A · B · C · D · CORP · IMG"
            destaque: s.opcao !== "fui"
            Cascata { ativo: s.entrando; ordem: 2; alvo: est }
            Leitura { width: parent.width; tamanho: 12; color: Tema.texto2; text: Txt.t("papel.notaEstatico") }
            Flow {
                width: parent.width
                spacing: 12
                readonly property real lt: (width - 2 * 12) / 3
                Repeater {
                    model: s.estaticos
                    TilePrevia {
                        required property var modelData
                        width: parent.lt
                        nome: modelData.nome
                        previa: modelData.previa
                        proporcao: 9 / 16
                        selecionado: s.opcao === modelData.id
                        ocupado: s.ocupado
                        onEscolhido: if (!s.ocupado && s.opcao !== modelData.id) painel.escolherPapelOpcao(modelData.id)
                    }
                }
                // imagem própria
                TilePrevia {
                    width: parent.lt
                    nome: Txt.t("papel.propria") + "…"
                    descricao: s.propria ? painel.papelCaminho.split("/").pop() : Txt.t("papel.propriaDica")
                    previa: s.propria ? painel.papel : ""
                    proporcao: 9 / 16
                    selecionado: s.propria
                    ocupado: s.ocupado
                    onEscolhido: if (!s.ocupado) s.app.escolherPapel()
                }
            }
            // ---- a pasta do usuário: cards depois dos do tema. Sem suporte no CLI, nada aparece; sem pasta (ou
            // pasta que sumiu), só um card discreto para escolher.
            Item {
                visible: s.pp.suporte === true
                width: parent.width; height: visible ? 1 : 0
                Rectangle { width: parent.width; height: 1; color: Tema.linha }
            }
            Item {
                visible: s.pp.suporte === true && s.temPasta
                width: parent.width; height: visible ? 30 : 0
                Codigo { anchors.verticalCenter: parent.verticalCenter; text: Txt.t("papel.suaPasta") + " · " + s.pp.itens.length; tamanho: 11; color: Tema.texto2 }
                Row {
                    id: acoesPasta
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Botao { text: Txt.t("papel.trocarPasta"); tipo: "sutil"; tamanho: 11; habilitado: !s.ocupado; onClicado: s.escolherPasta() }
                    Botao { text: Txt.t("papel.limparPasta"); tipo: "sutil"; tamanho: 11; habilitado: !s.ocupado; onClicado: painel.papelPastaLimpar() }
                }
            }
            Text {
                visible: s.pp.suporte === true && s.temPasta
                width: parent.width; text: s.pp.pasta; elide: Text.ElideMiddle
                font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto3
            }
            Flow {
                visible: s.pp.suporte === true
                width: parent.width
                spacing: 12
                readonly property real lt: (width - 2 * 12) / 3
                Repeater {
                    model: s.temPasta ? s.pp.itens : []
                    Item {
                        id: cp
                        required property var modelData
                        width: parent.lt; height: tile.implicitHeight
                        TilePrevia {
                            id: tile
                            width: parent.width
                            nome: cp.modelData.nome
                            // sem miniatura, o tipo vai no texto
                            descricao: cp.modelData.previa ? "" : (cp.modelData.tipo === "video" ? Txt.t("papel.seloVideo") : Txt.t("papel.seloImagem"))
                            previa: cp.modelData.previa || ""
                            proporcao: 9 / 16
                            selecionado: cp.modelData.emUso === true
                            ocupado: s.ocupado
                            onEscolhido: if (!s.ocupado && !cp.modelData.emUso) painel.papelPastaAplicar(cp.modelData.id)
                        }
                        // selo do tipo, no canto da miniatura
                        Rectangle {
                            visible: !!cp.modelData.previa
                            x: 12; y: 12
                            width: tSelo.implicitWidth + 10; height: 17
                            color: Tema.alfa(Tema.escuro, 0.85)
                            border.color: cp.modelData.tipo === "video" ? Tema.secundaria : Tema.linha
                            Codigo {
                                id: tSelo; anchors.centerIn: parent; tamanho: 9
                                color: cp.modelData.tipo === "video" ? Tema.secundaria : Tema.texto2
                                text: cp.modelData.tipo === "video" ? Txt.t("papel.seloVideo") : Txt.t("papel.seloImagem")
                            }
                        }
                    }
                }
                // sem pasta: o card discreto
                TilePrevia {
                    visible: !s.temPasta
                    width: parent.lt
                    nome: Txt.t("papel.escolherPasta")
                    descricao: s.pp.pasta && !s.pp.existe ? Txt.t("papel.pastaSumiu") : Txt.t("papel.escolherPastaDica")
                    ocupado: s.ocupado
                    onEscolhido: if (!s.ocupado) s.escolherPasta()
                }
            }
            Leitura {
                visible: s.pp.suporte === true && s.temPasta && s.pp.itens.length === 0
                width: parent.width; tamanho: 12; color: Tema.texto3; text: Txt.t("papel.pastaVazia")
            }
            Botao {
                visible: s.propria
                text: Txt.t("papel.voltar"); tipo: "sutil"
                habilitado: !s.ocupado
                onClicado: painel.papelPadrao()
            }
        }
    }
}
