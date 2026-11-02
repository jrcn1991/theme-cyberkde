import QtQuick

// Seção CYBER FENCE: topo com ocultar/exibir, peek e os atalhos globais; abas CERCAS (lista, mapa e o
// inspetor da selecionada), ANIMAÇÕES (galeria, com "Testar"), REGRAS, LAYOUTS e BACKUP (PaginaCerca).
// Sem nenhuma cerca, o estado inicial é o botão de criar a primeira. Tudo pelo efeito widget-cerca.
Secao {
    id: s
    readonly property var fence: (painel.widgets || []).find(w => w.id === "widget-cerca") || null
    readonly property var instancias: fence ? fence.instancias || [] : []
    readonly property bool vazia: instancias.length === 0
    readonly property bool ocupado: painel.alvosNaFila.indexOf("fx:widget-cerca") >= 0 || painel.alvo === "fx:widget-cerca"
    readonly property bool lado: corpo.width >= 940
    property string aba: "cercas"
    property string instSel: ""
    readonly property string instAtual: (instancias.find(i => i.id === instSel) || instancias[0] || { id: "" }).id
    function opcao(id) { return s.fence ? s.fence.opcoes.find(x => x.id === id) || null : null }
    function valor(id) { const o = opcao(id); return o ? String(o.valor) : "" }

    Connections {
        target: painel
        function onInstanciaMudou(efeito, antiga, nova) {
            if (efeito === "widget-cerca" && (antiga === "" || antiga === s.instAtual)) s.instSel = nova
        }
    }

    // a animação vale para todas: grava nas do tema (o widget leva às postas à mão)
    function escolherAnimacao(id) {
        const alvo = s.instancias.filter(i => !i.manual)
        for (const i of (alvo.length ? alvo : s.instancias.slice(0, 1)))
            painel.aplicarOpcoesInstancia("widget-cerca", i.id, { animacao: id }, {})
    }
    function escolherAnimacaoIcones(id) {
        const alvo = s.instancias.filter(i => !i.manual)
        for (const i of (alvo.length ? alvo : s.instancias.slice(0, 1)))
            painel.aplicarOpcoesInstancia("widget-cerca", i.id, { animacaoIcones: id }, {})
    }
    readonly property string animacaoIconesAtual: (instancias.find(i => !i.manual) || instancias[0] || {}).animacaoIcones || valor("animacaoIcones") || "explosao"
    readonly property string animacaoAtual: (instancias.find(i => !i.manual) || instancias[0] || {}).animacao || valor("animacao") || "moldura"

    // ---- sem cerca
    Bloco {
        id: inicio
        visible: s.vazia
        width: s.corpo.width
        titulo: "CYBER FENCE"
        codigo: "NO.FENCES"
        Cascata { ativo: s.entrando; ordem: 0; alvo: inicio }
        Leitura { width: parent.width; tamanho: 15; color: Tema.texto; text: Txt.t("ce.inicio") }
        Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Txt.t("ce.inicioAjuda") }
        Botao {
            text: Txt.t("ce.criarPrimeira"); tipo: "primario"; tamanho: 18; implicitHeight: 56
            habilitado: !!s.fence && !s.ocupado
            onClicado: painel.novaInstancia("widget-cerca")
        }
        Leitura { visible: !s.fence; width: parent.width; tamanho: 12; color: Tema.alerta; text: Txt.t("ce.semSuporte") }
    }

    // ---- topo
    Bloco {
        id: topo
        visible: !s.vazia
        width: s.corpo.width
        titulo: "CYBER FENCE"
        codigo: "FENCES // " + s.instancias.length + " // " + s.instancias.filter(i => i.ligado).length + " ON"
        Cascata { ativo: s.entrando; ordem: 0; alvo: topo }
        Flow {
            width: parent.width; spacing: 8
            Botao { text: "+ " + Txt.t("wg.novaCerca"); tipo: "primario"; tamanho: 12; habilitado: !s.ocupado; onClicado: painel.novaInstancia("widget-cerca") }
            Botao {
                text: s.fence && s.fence.cercasOcultas ? Txt.t("ce.exibirTodas") : Txt.t("ce.ocultarTodas"); tamanho: 12; tipo: "secundario"
                habilitado: !s.ocupado
                onClicado: painel.cercaOcultar()
            }
            Botao {
                text: s.fence && s.fence.peek ? Txt.t("ce.peekDesligar") : Txt.t("ce.peekLigar"); tamanho: 12
                tipo: s.fence && s.fence.peek ? "primario" : "secundario"
                habilitado: !s.ocupado
                onClicado: painel.cercaPeek()
            }
        }
        // atalhos globais: mostrar e trocar as teclas
        Row {
            spacing: 10
            Interruptor {
                anchors.verticalCenter: parent.verticalCenter
                ligado: s.valor("atalhos") === "on"
                ocupado: s.ocupado
                onAlternado: (novo) => painel.aplicarOpcoes("widget-cerca", { atalhos: novo ? "on" : "off" })
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Rotulo { text: Txt.t("ce.atalhos"); tamanho: 13 }
                Leitura { text: Txt.t("ce.atalhosAjuda"); tamanho: 11; color: Tema.texto3 }
            }
        }
        Flow {
            visible: s.valor("atalhos") === "on"
            width: parent.width; spacing: 16
            Repeater {
                model: ["atalho-nova", "atalho-alternar", "atalho-peek"]
                Column {
                    id: ca
                    required property string modelData
                    readonly property var op: s.opcao(modelData)
                    visible: !!op
                    width: 300
                    spacing: 4
                    Codigo { text: ca.op ? ca.op.nome.toUpperCase() : ""; tamanho: 9 }
                    CampoTexto {
                        width: parent.width
                        valor: ca.op ? String(ca.op.valor || ca.op.padrao || "") : ""
                        habilitado: !s.ocupado
                        onConfirmado: (t) => { let m = {}; m[ca.modelData] = t; painel.aplicarOpcoes("widget-cerca", m) }
                    }
                }
            }
        }
    }

    // ---- abas
    Row {
        id: abas
        visible: !s.vazia
        spacing: 6
        Repeater {
            model: [{ id: "cercas", t: "ce.cercas" }, { id: "animacoes", t: "ce.animacoes" }, { id: "regras", t: "ce.regras" }, { id: "layouts", t: "ce.layouts" }, { id: "backup", t: "ce.backup" }]
            Botao {
                required property var modelData
                text: Txt.t(modelData.t); tamanho: 12
                tipo: s.aba === modelData.id ? "primario" : "secundario"
                onClicado: s.aba = modelData.id
            }
        }
    }

    // ---- CERCAS: lista e mapa; ao lado, o inspetor da selecionada
    Item {
        id: zona
        visible: !s.vazia && s.aba === "cercas"
        width: s.corpo.width
        readonly property real largEsq: s.lado ? (width - 20) * 0.52 : width
        height: s.lado ? Math.max(colEsq.implicitHeight, insp.implicitHeight) : colEsq.implicitHeight + 16 + insp.implicitHeight
        Column {
            id: colEsq
            width: zona.largEsq
            spacing: 16
            Bloco {
                id: blLista
                width: parent.width
                titulo: Txt.t("wg.cercas")
                codigo: String(s.instancias.length)
                Cascata { ativo: s.entrando; ordem: 1; alvo: blLista }
                ListaCercas {
                    width: parent.width
                    instancias: s.instancias
                    selecionada: s.instAtual
                    ocupado: s.ocupado
                    onEscolher: (id) => s.instSel = id
                }
            }
            Bloco {
                id: blMapa
                width: parent.width
                titulo: Txt.t("wg.mapa").toUpperCase()
                codigo: "SCREEN.0"
                Cascata { ativo: s.entrando; ordem: 2; alvo: blMapa }
                MapaWidgets {
                    width: parent.width
                    geo: painel.geometriaWidgets
                    widgets: s.fence ? [s.fence] : []
                    filtro: (n) => n.split("@")[0] === (s.fence ? s.fence.widgetNome : "")
                    rotulo: (n) => { const i = s.instancias.find(x => n === (s.fence.widgetNome + "@" + x.id)); return i ? (i.titulo || (i.pasta || "").split("/").pop() || i.id) : "" }
                    selecionado: s.fence ? s.fence.widgetNome + "@" + s.instAtual : ""
                    onEscolher: (n) => s.instSel = n.split("@")[1] || ""
                }
            }
        }
        InspetorWidget {
            id: insp
            x: s.lado ? zona.largEsq + 20 : 0
            y: s.lado ? 0 : colEsq.implicitHeight + 16
            width: s.lado ? zona.width - zona.largEsq - 20 : zona.width
            dados: s.fence
            app: s.app
            instSel: s.instAtual
            ocultarOpcoes: ["animacao", "animacaoIcones", "atalhos", "atalho-nova", "atalho-alternar", "atalho-peek", "vigiar", "por-resolucao"]
        }
    }

    // ---- ANIMAÇÕES
    Bloco {
        id: blAnim
        visible: !s.vazia && s.aba === "animacoes"
        width: s.corpo.width
        titulo: Txt.t("ce.animacoes")
        codigo: s.animacaoAtual.toUpperCase()
        Row {
            width: parent.width; spacing: 12
            Leitura { width: parent.width - btTestar.width - 12; anchors.verticalCenter: parent.verticalCenter; tamanho: 13; color: Tema.texto2; text: Txt.t("ce.animacoesAjuda") }
            Botao { id: btTestar; text: Txt.t("ce.testar"); tipo: "primario"; tamanho: 12; habilitado: !s.ocupado; onClicado: painel.testarOcultarCercas() }
        }
        Flow {
            id: galeria
            width: parent.width
            spacing: 10
            readonly property int colunas: Math.max(2, Math.floor((width + 10) / 200))
            Repeater {
                model: { const o = s.opcao("animacao"); return o ? o.valores : [] }
                TilePrevia {
                    required property var modelData
                    width: (galeria.width - (galeria.colunas - 1) * 10) / galeria.colunas
                    nome: modelData.nome
                    previa: modelData.previa
                    proporcao: 9 / 16
                    selecionado: s.animacaoAtual === modelData.id
                    ocupado: s.ocupado
                    onEscolhido: if (!s.ocupado && s.animacaoAtual !== modelData.id) s.escolherAnimacao(modelData.id)
                }
            }
        }
    }

    // ---- ANIMAÇÕES: a segunda galeria, a dos ícones dentro da cerca
    Bloco {
        visible: !s.vazia && s.aba === "animacoes"
        width: s.corpo.width
        titulo: Txt.t("ce.icones")
        codigo: s.animacaoIconesAtual.toUpperCase()
        Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Txt.t("ce.iconesAjuda") }
        Flow {
            id: galeriaIcones
            width: parent.width
            spacing: 10
            readonly property int colunas: Math.max(2, Math.floor((width + 10) / 200))
            Repeater {
                model: { const o = s.opcao("animacaoIcones"); return o ? o.valores : [] }
                TilePrevia {
                    required property var modelData
                    width: (galeriaIcones.width - (galeriaIcones.colunas - 1) * 10) / galeriaIcones.colunas
                    nome: modelData.nome
                    previa: modelData.previa
                    proporcao: 9 / 16
                    selecionado: s.animacaoIconesAtual === modelData.id
                    ocupado: s.ocupado
                    onEscolhido: if (!s.ocupado && s.animacaoIconesAtual !== modelData.id) s.escolherAnimacaoIcones(modelData.id)
                }
            }
        }
    }

    // ---- REGRAS, LAYOUTS e BACKUP
    PaginaCerca {
        visible: !s.vazia && (s.aba === "regras" || s.aba === "layouts" || s.aba === "backup")
        width: s.corpo.width
        app: s.app
        fence: s.fence
        aba: s.aba
    }
}
