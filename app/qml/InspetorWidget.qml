import QtQuick

// Inspetor do widget selecionado na seção WIDGETS: as opções do efeito, montadas pelo que o
// "efeito --lista --json" descreve (tela, canto, tamanho P/M/G, opacidade e as próprias do widget:
// texto, escolha, inteiro). As mudanças ficam PENDENTES até "Aplicar" (um comando só, com tudo).
Bloco {
    id: ins
    property var dados: null
    property var app: null
    property var ocultarOpcoes: []          // ids que têm lugar próprio na seção
    property var pendente: ({})
    property string _id: ""
    // várias instâncias (a cerca): as opções são as da selecionada; todo comando leva --instancia
    readonly property bool multi: !!dados && dados.multiInstancia === true
    readonly property var instancias: multi ? (dados.instancias || []) : []
    property string instSel: ""
    readonly property var inst: instancias.find(i => i.id === instSel) || instancias[0] || null
    readonly property string instAtual: inst ? inst.id : ""
    onInstAtualChanged: pendente = ({})
    function nomeInst(i) {
        if (i.titulo) return i.titulo
        if (i.pasta) return i.pasta.replace(/\/+$/, "").split("/").pop()
        return Txt.t("wg.cercaN", { n: i.id })
    }
    readonly property int nPendentes: Object.keys(pendente).length
    readonly property bool naFila: !!dados && (painel.alvosNaFila.indexOf("fx:" + dados.id) >= 0 || painel.alvo === "fx:" + dados.id)

    titulo: dados ? dados.nomeCurto.toUpperCase() : Txt.t("wg.inspetor")
    codigo: dados ? "INSP // " + dados.id : "INSP // --"
    destaque: nPendentes > 0

    // a lista é recriada a cada leitura do CLI: só zera o pendente quando o widget muda
    onDadosChanged: if (dados && dados.id !== _id) { _id = dados.id; pendente = ({}) }

    // valor da instância; tela, posição, tamanho e opacidade o CLI só manda da primeira (no topo do estado)
    function base(op) {
        if (!inst) return String(op.valor)
        const v = inst[op.id]
        if (v !== undefined && v !== null) return String(v)
        return inst === instancias[0] ? String(op.valor) : ""
    }
    function valor(op) { return pendente[op.id] !== undefined ? String(pendente[op.id]) : base(op) }
    function mudar(op, v) {
        let p = Object.assign({}, pendente)
        if (String(v) === base(op)) delete p[op.id]
        else p[op.id] = String(v)
        pendente = p
    }
    function aplicar() {
        if (!dados || nPendentes === 0) return
        let atuais = {}
        for (const op of dados.opcoes) atuais[op.id] = valor(op)
        if (inst) painel.aplicarOpcoesInstancia(dados.id, inst.id, pendente, atuais)
        else painel.aplicarOpcoes(dados.id, pendente, atuais)
        pendente = ({})
    }

    Leitura {
        visible: !ins.dados
        width: parent.width; tamanho: 13; color: Tema.texto3
        text: Txt.t("wg.selecione")
    }

    Column {
        visible: !!ins.dados
        width: parent.width
        spacing: 14

        Leitura { width: parent.width; tamanho: 12; color: Tema.texto2; text: ins.dados ? ins.dados.descricao : "" }
        Row {
            spacing: 8
            Rectangle {
                width: est.implicitWidth + 12; height: 18
                readonly property bool on: ins.inst ? ins.inst.ligado === true : (!!ins.dados && ins.dados.ligado)
                color: on ? Tema.alfa(Tema.destaque, 0.15) : "transparent"
                border.color: on ? Tema.destaque : Tema.linha
                Codigo { id: est; anchors.centerIn: parent; tamanho: 9; color: parent.on ? Tema.destaque : Tema.texto3
                         text: parent.on ? Txt.t("comum.ligado").toUpperCase() : Txt.t("comum.desligado").toUpperCase() }
            }
            Codigo {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!ins.dados && ins.dados.dadosGuardados === true
                text: Txt.t("wg.guardadosLonga"); tamanho: 9; color: Tema.secundaria
            }
        }

        Repeater {
            model: ins.dados ? ins.dados.opcoes.filter(o => ins.ocultarOpcoes.indexOf(o.id) < 0) : []
            Column {
                id: op
                required property var modelData
                width: parent.width
                spacing: 6
                readonly property string v: ins.valor(modelData)
                readonly property bool mudou: ins.pendente[modelData.id] !== undefined

                Row {
                    spacing: 8
                    visible: op.modelData.forma !== "inteiro"
                    Codigo { text: op.modelData.nome.toUpperCase(); tamanho: 9; color: op.mudou ? Tema.destaque : Tema.texto3 }
                    Codigo { visible: op.mudou; text: "● " + Txt.t("wg.pendente"); tamanho: 8; color: Tema.destaque }
                }
                // liga (escolha de dois valores on/off ou true/false)
                Interruptor {
                    visible: op.modelData.forma === "liga"
                    ligado: op.v === "on" || op.v === "true"
                    habilitado: !ins.naFila
                    onAlternado: (novo) => ins.mudar(op.modelData, op.modelData.valores.some(x => x.id === "true") ? (novo ? "true" : "false") : (novo ? "on" : "off"))
                }
                // escolha
                Flow {
                    visible: op.modelData.forma === "escolha" || op.modelData.forma === "previas"
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: op.modelData.forma === "escolha" || op.modelData.forma === "previas" ? op.modelData.valores : []
                        Botao {
                            required property var modelData
                            text: modelData.nome
                            tamanho: 12; implicitHeight: 28
                            tipo: op.v === modelData.id ? "primario" : "secundario"
                            habilitado: !ins.naFila
                            onClicado: ins.mudar(op.modelData, modelData.id)
                        }
                    }
                }
                // inteiro
                Deslizador {
                    visible: op.modelData.forma === "inteiro"
                    width: parent.width
                    rotulo: op.modelData.nome.toUpperCase() + (op.mudou ? "  ● " + Txt.t("wg.pendente") : "")
                    de: Number(op.modelData.min); ate: Number(op.modelData.max); passo: Number(op.modelData.passo) || 1
                    unidade: op.modelData.unidade ? " " + op.modelData.unidade : ""
                    valor: op.v === "" ? Number(op.modelData.padrao || op.modelData.min) : Number(op.v)
                    textoValor: op.v === "" ? Txt.t("cfg.padrao") : Math.round(valor) + unidade
                    habilitado: !ins.naFila
                    onMovido: (x) => ins.mudar(op.modelData, String(Math.round(x)))
                }
                // texto
                Item {
                    visible: op.modelData.forma === "texto"
                    width: parent.width; height: 32
                    // opção "pasta": campo + "Escolher pasta…" (o seletor do sistema, no Main)
                    readonly property bool ehPasta: op.modelData.id === "pasta"
                    Botao {
                        id: btPasta
                        visible: parent.ehPasta
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: Txt.t("wg.escolherPasta"); tamanho: 11
                        habilitado: !ins.naFila
                        onClicado: ins.app.escolherPasta(op.v, (c) => ins.mudar(op.modelData, c))
                    }
                    Chanfro { width: parent.ehPasta ? parent.width - btPasta.width - 8 : parent.width; height: parent.height; preenchimento: Tema.entrada; borda: campo.activeFocus ? Tema.secundaria : (op.mudou ? Tema.destaque : Tema.linha); espessura: campo.activeFocus ? 2 : 1 }
                    TextInput {
                        id: campo
                        x: 10; width: parent.width - 20 - (parent.ehPasta ? btPasta.width + 8 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Tema.fTexto; font.pixelSize: 13
                        color: Tema.texto
                        selectByMouse: true; clip: true
                        readOnly: ins.naFila
                        text: op.v
                        onTextEdited: ins.mudar(op.modelData, text)
                        onAccepted: ins.aplicar()
                        Text {
                            visible: campo.text === "" && !campo.activeFocus
                            text: op.modelData.padrao !== "" ? Txt.t("cfg.padraoEh", { v: op.modelData.padrao }) : Txt.t("cfg.padrao")
                            font: campo.font; color: Tema.texto3
                            width: parent.width; elide: Text.ElideRight
                        }
                    }
                }
                Leitura {
                    visible: (op.modelData.dica || "") !== ""
                    width: parent.width; tamanho: 11; color: Tema.texto3
                    text: op.modelData.dica || ""
                }
            }
        }

        // ações
        Flow {
            width: parent.width
            spacing: 10
            Botao {
                text: ins.nPendentes > 0 ? Txt.t("wg.aplicarN", { n: ins.nPendentes }) : Txt.t("comum.aplicar")
                icone: "⏎"
                tipo: ins.nPendentes > 0 ? "primario" : "secundario"
                habilitado: ins.nPendentes > 0 && !ins.naFila
                onClicado: ins.aplicar()
            }
            Botao {
                visible: ins.nPendentes > 0
                text: Txt.t("wg.descartar"); tipo: "sutil"; tamanho: 12
                onClicado: ins.pendente = ({})
            }
            Botao {
                visible: !!ins.inst
                text: Txt.t("wg.removerCerca"); tipo: "sutil"; tamanho: 12; cor: Tema.alerta
                habilitado: !ins.naFila
                onClicado: ins.app.pedirRemoverCerca(ins.dados.id, ins.inst.id, ins.nomeInst(ins.inst))
            }
        }
    }
}
