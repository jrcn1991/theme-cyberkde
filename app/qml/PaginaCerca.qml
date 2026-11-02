import QtQuick

// Abas da seção CYBER FENCE: REGRAS de organização, LAYOUTS (snapshots, por resolução) e BACKUP.
// Tudo pelo CLI ("cyberkde cerca ..."; modules/widgets/CONTRATO-CLI.md). A simulação mostra o que moveria
// antes de aplicar; aplicar deixa um lote que dá para desfazer.
Column {
    id: pg
    property var app
    property var fence: null                // o efeito widget-cerca
    spacing: 16
    property string aba: "regras"            // quem escolhe é a SecaoCerca
    readonly property var d: painel.cercaDados
    readonly property bool ocupado: painel.alvosNaFila.indexOf("fx:widget-cerca") >= 0 || painel.alvo === "fx:widget-cerca"
    onVisibleChanged: if (visible) Qt.callLater(painel.cercaLer)
    function opcao(id) { const o = fence ? fence.opcoes.find(x => x.id === id) : null; return o ? String(o.valor) : "" }
    function hora(t) {
        const m = String(t || "").match(/^(\d{4})-?(\d\d)-?(\d\d)[T-](\d\d):?(\d\d)/)
        return m ? m[3] + "/" + m[2] + "/" + m[1] + " " + m[4] + ":" + m[5] : String(t || "")
    }

    component Campo: Item {
        id: cp
        property alias text: entrada.text
        property string dica: ""
        height: 32
        Chanfro { anchors.fill: parent; preenchimento: Tema.entrada; borda: entrada.activeFocus ? Tema.secundaria : Tema.linha; espessura: entrada.activeFocus ? 2 : 1 }
        TextInput {
            id: entrada
            x: 10; width: parent.width - 20
            anchors.verticalCenter: parent.verticalCenter
            font.family: Tema.fTexto; font.pixelSize: 13
            color: Tema.texto; selectByMouse: true; clip: true
            Text { visible: !entrada.text; text: cp.dica; font: entrada.font; color: Tema.texto3 }
        }
    }
    component Linha: Item {
        id: ln
        default property alias conteudo: dentro.data
        width: parent.width; height: 48
        Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.entrada; borda: Tema.linha }
        Item { id: dentro; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8 }
    }

    Leitura { visible: pg.d.erro !== ""; width: parent.width; tamanho: 13; color: Tema.alerta; text: pg.d.erro }

    // ---- REGRAS
    Bloco {
        id: blRegras
        visible: pg.aba === "regras"
        width: parent.width
        titulo: Txt.t("ce.regras")
        codigo: pg.d.regras.length + " // " + pg.d.regras.filter(r => r.ativa !== false).length + " ON"
        Row {
            spacing: 10
            Interruptor {
                anchors.verticalCenter: parent.verticalCenter
                ligado: pg.opcao("vigiar") === "on"
                ocupado: pg.ocupado
                onAlternado: (novo) => painel.aplicarOpcoes("widget-cerca", { vigiar: novo ? "on" : "off" })
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Rotulo { text: Txt.t("ce.vigiar"); tamanho: 13 }
                Leitura { text: Txt.t("ce.vigiarAjuda"); tamanho: 11; color: Tema.texto3 }
            }
        }
        Leitura { visible: pg.d.regras.length === 0; width: parent.width; tamanho: 13; color: Tema.texto3; text: Txt.t("ce.semRegras") }
        Repeater {
            model: pg.d.regras
            Linha {
                id: lr
                required property var modelData
                required property int index
                Column {
                    width: parent.width - 330
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; text: lr.modelData.nome; elide: Text.ElideRight; font.family: Tema.fTexto; font.pixelSize: 13; color: lr.modelData.ativa === false ? Tema.texto3 : Tema.texto }
                    Text {
                        width: parent.width; elide: Text.ElideMiddle
                        text: ((lr.modelData.extensoes || []).map(x => "." + x).join(" ") + " " + (lr.modelData.nomeContem || "")).trim() + "  →  " + lr.modelData.destino
                        font.family: Tema.fTexto; font.pixelSize: 11; color: Tema.texto3
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: Txt.t("ce.conf." + (lr.modelData.conflito || "renomear")).toUpperCase(); tamanho: 8 }
                    Botao { text: "▲"; tamanho: 11; tipo: "sutil"; habilitado: lr.index > 0 && !pg.ocupado; onClicado: painel.cercaMover(lr.modelData.id, -1) }
                    Botao { text: "▼"; tamanho: 11; tipo: "sutil"; habilitado: lr.index < pg.d.regras.length - 1 && !pg.ocupado; onClicado: painel.cercaMover(lr.modelData.id, 1) }
                    Interruptor {
                        anchors.verticalCenter: parent.verticalCenter
                        ligado: lr.modelData.ativa !== false
                        ocupado: pg.ocupado
                        onAlternado: (novo) => painel.cercaAtivar(lr.modelData.id, novo)
                    }
                    Botao { text: Txt.t("ce.editar"); tamanho: 11; tipo: "secundario"; onClicado: form.editar(lr.modelData) }
                    Botao {
                        text: "✕"; tamanho: 11; tipo: "sutil"; cor: Tema.alerta
                        onClicado: pg.app.confirmar(Txt.t("ce.removerRegra"), lr.modelData.nome, Txt.t("ce.remover"), () => painel.cercaRemoverRegra(lr.modelData.id))
                    }
                }
            }
        }
        Row {
            spacing: 8
            Botao { text: "+ " + Txt.t("ce.novaRegra"); tamanho: 12; tipo: "secundario"; onClicado: form.editar(null) }
            Botao { text: Txt.t("ce.simular"); tamanho: 12; tipo: "secundario"; habilitado: !pg.ocupado && pg.d.regras.length > 0; onClicado: painel.cercaSimular() }
            Botao { text: Txt.t("ce.aplicar"); tamanho: 12; tipo: "primario"; habilitado: !pg.ocupado && !!pg.d.simulacao && pg.d.simulacao.movidos.length > 0; onClicado: painel.cercaAplicar() }
        }
    }
    // o formulário de uma regra
    Bloco {
        id: form
        visible: pg.aba === "regras" && aberto
        width: parent.width
        property bool aberto: false
        property string rid: ""
        property string conflito: "renomear"
        property bool esperar: true
        property bool podeEsperar: true
        titulo: rid ? Txt.t("ce.editarRegra") : Txt.t("ce.novaRegra")
        codigo: rid || "NEW"
        function editar(r) {
            rid = r ? r.id : ""
            fNome.text = r ? r.nome : ""
            fExt.text = r ? (r.extensoes || []).join(", ") : ""
            fContem.text = r ? (r.nomeContem || "") : ""
            fDestino.text = r ? r.destino : ""
            conflito = r ? (r.conflito || "renomear") : "renomear"
            esperar = r ? r.esperarDestravar !== false : true
            podeEsperar = !r || r.esperarDestravar !== false      // o CLI não religa a espera numa regra existente
            aberto = true
        }
        readonly property bool valido: fDestino.text.trim() !== "" && (fExt.text.trim() !== "" || fContem.text.trim() !== "")
        Column {
            width: parent.width
            spacing: 8
            Codigo { text: Txt.t("ce.nome").toUpperCase(); tamanho: 9 }
            Campo { id: fNome; width: parent.width; dica: Txt.t("ce.nomeDica") }
            Codigo { text: Txt.t("ce.extensoes").toUpperCase(); tamanho: 9 }
            Campo { id: fExt; width: parent.width; dica: "pdf, docx, odt" }
            Codigo { text: Txt.t("ce.contem").toUpperCase(); tamanho: 9 }
            Campo { id: fContem; width: parent.width; dica: Txt.t("ce.contemDica") }
            Codigo { text: Txt.t("ce.destino").toUpperCase(); tamanho: 9 }
            Row {
                width: parent.width; spacing: 8
                Campo { id: fDestino; width: parent.width - btDest.width - 8; dica: "~/Documentos/PDFs" }
                Botao { id: btDest; text: Txt.t("wg.escolherPasta"); tamanho: 11; tipo: "secundario"; onClicado: pg.app.escolherPasta(fDestino.text, (c) => fDestino.text = c) }
            }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: pg.fence ? (pg.fence.instancias || []).filter(i => !i.manual) : []
                    Botao {
                        required property var modelData
                        text: "▸ " + (modelData.titulo || (modelData.pasta || "").split("/").pop() || modelData.id); tamanho: 10; tipo: "sutil"
                        onClicado: fDestino.text = "cerca:" + modelData.id
                    }
                }
            }
            Codigo { text: Txt.t("ce.conflito").toUpperCase(); tamanho: 9 }
            Row {
                spacing: 6
                Repeater {
                    model: ["renomear", "pular", "sobrescrever"]
                    Botao { required property string modelData; text: Txt.t("ce.conf." + modelData); tamanho: 11; tipo: form.conflito === modelData ? "primario" : "secundario"; onClicado: form.conflito = modelData }
                }
            }
            Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Txt.t("ce.confAjuda." + form.conflito) }
            Row {
                spacing: 10
                Interruptor { anchors.verticalCenter: parent.verticalCenter; ligado: form.esperar; habilitado: form.podeEsperar; onAlternado: (n) => form.esperar = n }
                Leitura { anchors.verticalCenter: parent.verticalCenter; tamanho: 12; text: Txt.t(form.podeEsperar ? "ce.esperar" : "ce.semEsperarFixo") }
            }
            Row {
                spacing: 8
                Botao {
                    text: Txt.t("comum.salvar"); tipo: "primario"; tamanho: 12
                    habilitado: form.valido && !pg.ocupado
                    onClicado: {
                        painel.cercaSalvarRegra(form.rid, { nome: fNome.text.trim(), extensoes: fExt.text.replace(/\s+/g, ""), contem: fContem.text.trim(),
                                                            destino: fDestino.text.trim(), conflito: form.conflito, semEsperar: !form.esperar })
                        form.aberto = false
                    }
                }
                Botao { text: Txt.t("comum.cancelar"); tipo: "sutil"; tamanho: 12; onClicado: form.aberto = false }
            }
        }
    }
    // a prévia do que moveria
    Bloco {
        visible: pg.aba === "regras" && !!pg.d.simulacao
        width: parent.width
        titulo: Txt.t("ce.previa")
        codigo: pg.d.simulacao ? pg.d.simulacao.movidos.length + " // " + pg.d.simulacao.pulados.length + " SKIP // " + pg.d.simulacao.semRegra + " NO.RULE" : ""
        Leitura { width: parent.width; tamanho: 12; color: Tema.texto3; text: pg.d.simulacao ? Txt.t("ce.origem", { p: pg.d.simulacao.origem || "" }) : "" }
        Repeater {
            model: pg.d.simulacao ? pg.d.simulacao.movidos.slice(0, 200) : []
            Text {
                required property var modelData
                width: parent.width; elide: Text.ElideMiddle
                text: modelData.arquivo.split("/").pop() + "  →  " + modelData.destino + "   [" + modelData.acao + "]"
                font.family: Tema.fTexto; font.pixelSize: 12; color: modelData.acao === "sobrescrever" ? Tema.alerta : Tema.texto
            }
        }
        Repeater {
            model: pg.d.simulacao ? pg.d.simulacao.pulados.slice(0, 50) : []
            Text {
                required property var modelData
                width: parent.width; elide: Text.ElideMiddle
                text: modelData.arquivo.split("/").pop() + "  —  " + modelData.motivo
                font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto3
            }
        }
        Leitura { visible: !!pg.d.simulacao && pg.d.simulacao.movidos.length === 0; width: parent.width; tamanho: 13; color: Tema.texto3; text: Txt.t("ce.nadaMover") }
    }
    Bloco {
        visible: pg.aba === "regras"
        width: parent.width
        titulo: Txt.t("ce.historico")
        codigo: pg.d.lotes.length + " LOTS"
        Leitura { visible: pg.d.lotes.length === 0; width: parent.width; tamanho: 13; color: Tema.texto3; text: Txt.t("ce.semHistorico") }
        Repeater {
            model: pg.d.lotes.slice(0, 20)
            Linha {
                id: ll
                required property var modelData
                required property int index
                Text { width: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                       text: pg.hora(ll.modelData.quando) + "  ·  " + Txt.t("ce.nArquivos", { n: ll.modelData.arquivos.length !== undefined ? ll.modelData.arquivos.length : ll.modelData.arquivos })
                       font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
                Botao {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: Txt.t("ce.desfazer"); tamanho: 11; tipo: ll.index === 0 ? "secundario" : "sutil"
                    habilitado: !pg.ocupado
                    onClicado: painel.cercaDesfazer(ll.modelData.lote)
                }
            }
        }
    }

    // ---- LAYOUTS
    Bloco {
        visible: pg.aba === "layouts"
        width: parent.width
        titulo: Txt.t("ce.layouts")
        codigo: pg.d.snapshots.length + " SNAP"
        Row {
            spacing: 10
            Interruptor {
                anchors.verticalCenter: parent.verticalCenter
                ligado: pg.opcao("por-resolucao") === "on"
                ocupado: pg.ocupado
                onAlternado: (novo) => painel.aplicarOpcoes("widget-cerca", { "por-resolucao": novo ? "on" : "off" })
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Rotulo { text: Txt.t("ce.porResolucao"); tamanho: 13 }
                Leitura { text: Txt.t("ce.porResolucaoAjuda"); tamanho: 11; color: Tema.texto3 }
            }
        }
        Row {
            width: parent.width; spacing: 8
            Campo { id: fSnap; width: parent.width - btSnap.width - 8; dica: Txt.t("ce.snapNome") }
            Botao {
                id: btSnap
                text: Txt.t("ce.salvarLayout"); tamanho: 12; tipo: "primario"
                habilitado: /^[A-Za-zÀ-ÿ0-9 ._-]{1,60}$/.test(fSnap.text.trim()) && !pg.ocupado
                onClicado: { painel.cercaSnapshot("salvar", fSnap.text.trim()); fSnap.text = "" }
            }
        }
        Leitura { visible: pg.d.snapshots.length === 0; width: parent.width; tamanho: 13; color: Tema.texto3; text: Txt.t("ce.semSnapshots") }
        Repeater {
            model: pg.d.snapshots
            Linha {
                id: ls
                required property var modelData
                Column {
                    width: parent.width - 220
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; text: ls.modelData.nome; elide: Text.ElideRight; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
                    Text { width: parent.width; elide: Text.ElideMiddle; text: Txt.t("ce.nCercas", { n: ls.modelData.cercas }) + "  ·  " + pg.hora(ls.modelData.criado) + "  ·  " + (ls.modelData.resolucao || ""); font.family: Tema.fTexto; font.pixelSize: 11; color: Tema.texto3 }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Botao {
                        text: Txt.t("ce.restaurar"); tamanho: 11; tipo: "secundario"; habilitado: !pg.ocupado
                        onClicado: pg.app.confirmar(Txt.t("ce.restaurarTitulo"), Txt.t("ce.restaurarTexto", { n: ls.modelData.nome }), Txt.t("ce.restaurar"), () => painel.cercaSnapshot("restaurar", ls.modelData.nome))
                    }
                    Botao {
                        text: "✕"; tamanho: 11; tipo: "sutil"; cor: Tema.alerta
                        onClicado: pg.app.confirmar(Txt.t("ce.apagarSnap"), ls.modelData.nome, Txt.t("ce.apagar"), () => painel.cercaSnapshot("apagar", ls.modelData.nome))
                    }
                }
            }
        }
    }

    // ---- BACKUP
    Bloco {
        visible: pg.aba === "backup"
        width: parent.width
        titulo: Txt.t("ce.backup")
        codigo: "EXPORT // IMPORT"
        Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Txt.t("ce.backupAjuda") }
        Flow {
            width: parent.width; spacing: 8
            Botao { text: Txt.t("ce.backupAgora"); tamanho: 12; tipo: "secundario"; habilitado: !pg.ocupado; onClicado: painel.cercaBackup() }
            Botao { text: Txt.t("ce.exportar"); tamanho: 12; tipo: "secundario"; habilitado: !pg.ocupado; onClicado: pg.app.escolherArquivo(true, (u) => painel.cercaExportar(u)) }
            Botao {
                text: Txt.t("ce.importar"); tamanho: 12; tipo: "secundario"; habilitado: !pg.ocupado
                onClicado: pg.app.escolherArquivo(false, (u) => pg.app.confirmar(Txt.t("ce.importarTitulo"), Txt.t("ce.importarTexto"), Txt.t("ce.importar"), () => painel.cercaImportar(u, aplicarImp.ligado)))
            }
        }
        Row {
            spacing: 10
            Interruptor { id: aplicarImp; anchors.verticalCenter: parent.verticalCenter; ligado: false; onAlternado: (n) => ligado = n }
            Leitura { anchors.verticalCenter: parent.verticalCenter; tamanho: 12; text: Txt.t("ce.importarAplicar") }
        }
        Leitura { visible: pg.d.info !== ""; width: parent.width; tamanho: 12; color: Tema.sucesso; text: pg.d.info }
    }
}
