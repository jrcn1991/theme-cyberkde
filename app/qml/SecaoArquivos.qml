import QtQuick

// Seção GERENCIADOR DE ARQUIVOS: o DATASHARD (app/arquivos). Topo com a prévia, a descrição e o botão
// grande que abre o app solto (cyberkde arquivos). Embaixo, a escolha de usá-lo como gerenciador padrão
// (efeito "datashard", padrão SEMPRE desligado; ligar pede confirmação), o padrão atual, quem atende o
// "Mostrar na pasta", os avisos da última troca e, se faltar pacote, a linha do apt.
Secao {
    id: s
    readonly property var ds: painel.datashard || ({})
    readonly property bool ocupado: painel.alvo === "datashard" || (painel.alvosNaFila || []).indexOf("datashard") >= 0
    readonly property bool lado: corpo.width >= 900

    // nome legível do padrão atual (padraoAtual = o .desktop do mimeapps.list; vazio = o do sistema)
    function nomePadrao(d) {
        const c = (d || "").split("/").pop()
        if (!c) return Txt.t("ds.padraoSistema")
        if (c.indexOf("cyberkde-arquivos") >= 0) return "DATASHARD"
        if (c.toLowerCase().indexOf("dolphin") >= 0) return "Dolphin"
        return Txt.t("ds.outro", { n: c.replace(/\.desktop$/, "") })
    }
    readonly property bool padraoEhDs: (ds.padraoAtual || "").indexOf("cyberkde-arquivos") >= 0

    // ---- topo: prévia, descrição e ABRIR
    Bloco {
        id: topo
        width: s.corpo.width
        titulo: "DATASHARD"
        codigo: "FILE.MANAGER // NFS · " + (s.ds.ligado ? "DEFAULT" : "STANDBY")
        destaque: s.padraoEhDs
        Cascata { ativo: s.entrando; ordem: 0; alvo: topo }

        Flow {
            width: parent.width
            spacing: 22
            // prévia (anima com o mouse em cima, se o movimento deixar)
            Item {
                width: s.lado ? Math.min(460, parent.width * 0.48) : parent.width
                height: width * 0.56
                Chanfro { anchors.fill: parent; corte: 10; preenchimento: Tema.alfa(Tema.fundo, 0.6); borda: Tema.alfa(Tema.destaque, hvP.hovered ? 0.9 : 0.4) }
                AnimatedImage {
                    id: previa
                    anchors.fill: parent; anchors.margins: 6
                    source: s.ds.previa || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    playing: hvP.hovered && !Tema.reduzir
                    paused: !playing
                }
                Codigo { visible: previa.status !== Image.Ready; anchors.centerIn: parent; text: "PREVIEW // —"; tamanho: 10 }
                HoverHandler { id: hvP }
            }
            Column {
                width: s.lado ? parent.width - Math.min(460, parent.width * 0.48) - 22 : parent.width
                spacing: 14
                Leitura { width: parent.width; tamanho: 14; color: Tema.texto; text: Txt.t("ds.descricao") }
                Botao {
                    text: Txt.t("ds.abrir"); icone: "◆"; tipo: "primario"; tamanho: 18
                    habilitado: s.ds.depsOk !== false && s.ds.disponivel !== false
                    onClicado: painel.abrirDatashard()
                }
                Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Txt.t("ds.abrirDica") }
                // faltando pacote: a linha do apt (cyberkde arquivos --checar saiu com 1)
                Column {
                    visible: s.ds.depsOk === false && !!s.ds.apt
                    width: parent.width
                    spacing: 6
                    Leitura { width: parent.width; tamanho: 12; color: Tema.alerta; text: Txt.t("ds.deps") }
                    Item {
                        width: parent.width; height: 34
                        Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.entrada; borda: Tema.alerta }
                        Text { x: 12; width: parent.width - 110; anchors.verticalCenter: parent.verticalCenter; text: s.ds.apt || ""; elide: Text.ElideRight; font.family: Tema.fMono; font.pixelSize: 12; color: Tema.texto }
                        Botao { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: Txt.t("ds.copiar"); tipo: "sutil"; tamanho: 11; onClicado: painel.copiar(s.ds.apt) }
                    }
                }
                Column {
                    visible: (s.ds.opcionais || []).length > 0
                    width: parent.width
                    spacing: 2
                    Codigo { text: Txt.t("ds.opcionais"); tamanho: 9 }
                    Repeater {
                        model: s.ds.opcionais || []
                        Text { required property string modelData; width: parent.width; text: modelData; elide: Text.ElideRight; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto3 }
                    }
                }
            }
        }
    }

    // ---- usar como gerenciador padrão
    Bloco {
        id: blocoPadrao
        width: s.corpo.width
        titulo: Txt.t("ds.padraoTitulo")
        codigo: "XDG.MIME // INODE/DIRECTORY"
        destaque: !!s.ds.ligado
        Cascata { ativo: s.entrando; ordem: 1; alvo: blocoPadrao }

        Row {
            spacing: 14
            Interruptor {
                id: chave
                anchors.verticalCenter: parent.verticalCenter
                ligado: s.ds.lido ? !!s.ds.ligado : null
                ocupado: s.ocupado
                habilitado: !!s.ds.suporte && !s.ocupado
                onAlternado: (novo) => { if (novo) s.app.pedirDatashard(); else painel.ligarDatashard(false) }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Rotulo {
                    text: (s.ds.ligado ? Txt.t("comum.ligado") : Txt.t("comum.desligado")).toUpperCase()
                    tamanho: 15; color: s.ds.ligado ? Tema.destaque : Tema.texto2
                }
                Row {
                    spacing: 8
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: Txt.t("ds.padraoAtual"); tamanho: 10; color: Tema.texto3 }
                    Rotulo {
                        text: s.ds.lido ? s.nomePadrao(s.ds.padraoAtual) : Txt.t("ds.lendo")
                        tamanho: 14; color: s.padraoEhDs ? Tema.destaque : Tema.texto
                    }
                }
            }
        }
        Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Txt.t("ds.ajuda") }
        Codigo {
            visible: !!s.ds.suporte
            width: parent.width
            text: Txt.t("ds.servico", { e: s.ds.servicoDBus ? Txt.t("ds.servicoSim") : Txt.t("ds.servicoNao") })
            tamanho: 10; color: s.ds.servicoDBus ? Tema.secundaria : Tema.texto3
        }
        Leitura { visible: s.ds.lido && !s.ds.suporte; width: parent.width; tamanho: 12; color: Tema.alerta; text: Txt.t("ds.semSuporte") }
        Leitura { visible: s.ds.disponivel === false; width: parent.width; tamanho: 12; color: Tema.alerta; text: Txt.t("ds.indisponivel") }
        // avisos da última troca (ex.: o Dolphin --daemon segue atendendo o "Mostrar na pasta" até o login)
        Column {
            visible: (s.ds.avisos || []).length > 0
            width: parent.width
            spacing: 4
            Codigo { text: Txt.t("ds.avisosTitulo"); tamanho: 9; color: Tema.alerta }
            Repeater {
                model: s.ds.avisos || []
                Row {
                    required property string modelData
                    width: parent.width; spacing: 8
                    Rectangle { width: 3; height: tav.implicitHeight; color: Tema.alerta }
                    Leitura { id: tav; width: parent.width - 11; tamanho: 12; color: Tema.texto; text: modelData }
                }
            }
        }
    }
}
