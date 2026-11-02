import QtQuick

// Seção WIDGETS: os widgets do tema na área de trabalho. Topo com o modo de edição do Plasma, o resumo
// e "ligar/desligar todos"; filtros por estado e categoria; a galeria (um cartão por widget, com prévia,
// estado e interruptor); o inspetor do selecionado (opções com "Aplicar") e o mapa da tela principal.
Secao {
    id: s
    property string sel: ""                 // widgetNome do selecionado
    property string filtroEstado: "todos"   // todos | ligados | desligados
    property string filtroCat: "todas"      // todas | sistema | informacao | produtividade

    // o Cyber Fence tem seção própria: aqui, só o cartão-atalho (fora da contagem e do "ligar todos")
    readonly property var fence: (painel.widgets || []).find(w => w.id === "widget-cerca") || null
    readonly property var todos: (painel.widgets || []).filter(w => w.id !== "widget-cerca")
    readonly property int nLigados: todos.filter(w => w.ligado).length
    readonly property var lista: todos.filter(w =>
        (filtroEstado === "todos" || (filtroEstado === "ligados") === (w.ligado === true))
        && (filtroCat === "todas" || w.categoria === filtroCat))
    readonly property var atual: todos.find(w => w.widgetNome === sel) || null

    // inspetor ao lado quando há largura; senão, abaixo da galeria
    readonly property bool lado: corpo.width >= 940
    readonly property real largInsp: lado ? 380 : corpo.width
    readonly property real largGal: lado ? corpo.width - largInsp - 20 : corpo.width
    readonly property int colunas: Math.max(1, Math.floor((largGal + 12) / 280))
    readonly property real largCartao: (largGal - (colunas - 1) * 12) / colunas

    // ---- topo
    Bloco {
        id: topo
        width: s.corpo.width
        titulo: Txt.t("secao.widgets").toUpperCase()
        codigo: "DESK.MODULES // " + ("0" + s.nLigados).slice(-2) + "/" + ("0" + s.todos.length).slice(-2)
        destaque: painel.edicao
        Cascata { ativo: s.entrando; ordem: 0; alvo: topo }

        Item {
            width: parent.width; height: 44
            // modo de edição
            Row {
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter
                Interruptor {
                    ligado: painel.edicao
                    ocupado: painel.edicaoOcupada
                    habilitado: !painel.edicaoOcupada
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: painel.alternarEdicao()
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Rotulo { text: Txt.t("cfg.edicao").toUpperCase() + " · " + (painel.edicao ? Txt.t("comum.ligado") : Txt.t("comum.desligado")).toUpperCase(); tamanho: 14; color: painel.edicao ? Tema.destaque : Tema.texto }
                    Leitura { text: Txt.t("cfg.edicaoAjuda"); tamanho: 11; color: Tema.texto3 }
                }
            }
            // resumo e ações
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    NumeroCintilante { valor: ("0" + s.nLigados).slice(-2); font.family: Tema.fIdentidade; font.pixelSize: 24; font.weight: Font.Bold; color: s.nLigados > 0 ? Tema.destaque : Tema.texto3; anchors.horizontalCenter: parent.horizontalCenter }
                    Codigo { text: Txt.t("wg.ligadosDe", { n: s.todos.length }); tamanho: 8; anchors.horizontalCenter: parent.horizontalCenter }
                }
                Botao {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Txt.t("wg.ligarTodos"); icone: "⏻"; tamanho: 12
                    habilitado: s.nLigados < s.todos.length
                    onClicado: s.app.pedirTodosWidgets(true)
                }
                Botao {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Txt.t("wg.desligarTodos"); tamanho: 12; tipo: "sutil"
                    habilitado: s.nLigados > 0
                    onClicado: s.app.pedirTodosWidgets(false)
                }
            }
        }
        Row {
            spacing: 8
            Rectangle { width: 7; height: 7; rotation: 45; color: Tema.secundaria; anchors.verticalCenter: parent.verticalCenter }
            Leitura { text: Txt.t("wg.avisoDados"); tamanho: 12; color: Tema.texto2 }
        }
    }

    // ---- ocultar e exibir os widgets ("cyberkde widgets", CONTRATO-CLI.md): interruptor no topo e galeria
    //      das animações, separada da das cercas ("igual às cercas" é a primeira)
    property bool verAnim: false
    readonly property var oc: painel.widgetsOcultar || ({})
    readonly property var opAnim: s.fence ? (s.fence.opcoes || []).find(x => x.id === "animacao") || null : null
    readonly property var valAnim: s.opAnim ? s.opAnim.valores || [] : []
    readonly property var galeriaOc: {
        const efetiva = s.valAnim.find(v => v.id === s.oc.animacaoEfetiva)
        return [{ id: "cercas", nome: Txt.t("wg.ocIgual"), previa: efetiva ? efetiva.previa : "" }].concat(s.valAnim)
    }
    Bloco {
        id: blOcultar
        width: s.corpo.width
        titulo: Txt.t("wg.ocTitulo")
        codigo: s.oc.suporte ? "QUICK.HIDE // " + String(s.oc.animacao || "cercas").toUpperCase() : "QUICK.HIDE"
        destaque: s.oc.ocultos === true
        Cascata { ativo: s.entrando; ordem: 1; alvo: blOcultar }
        Item {
            width: parent.width; height: 40
            Row {
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter
                Interruptor {
                    ligado: s.oc.suporte ? s.oc.gesto === true : null
                    ocupado: s.oc.ocupado === true
                    habilitado: s.oc.suporte === true && !s.oc.ocupado
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: (novo) => painel.widgetsGesto(novo)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Rotulo { text: Txt.t("wg.ocGesto").toUpperCase(); tamanho: 14; color: s.oc.gesto ? Tema.destaque : Tema.texto }
                    Leitura { text: s.oc.suporte ? Txt.t("wg.ocAjuda") : Txt.t("wg.ocSemSuporte"); tamanho: 11; color: Tema.texto3 }
                }
            }
        }
        Item {
            width: parent.width; height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Interruptor {
                    ligado: s.oc.suporte ? s.oc.junto === true : null
                    ocupado: s.oc.ocupado === true
                    habilitado: s.oc.suporte === true && !s.oc.ocupado
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: (novo) => painel.widgetsJunto(novo)
                }
                Leitura { text: Txt.t("wg.ocJunto"); tamanho: 12; color: Tema.texto2; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Botao {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Txt.t("wg.ocAnimacoes"); tamanho: 12; tipo: s.verAnim ? "primario" : "secundario"
                    onClicado: s.verAnim = !s.verAnim
                }
                Botao {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Txt.t("ce.testar"); tamanho: 12; tipo: "sutil"
                    habilitado: s.oc.suporte === true && !s.oc.ocupado
                    onClicado: painel.widgetsTestar()
                }
            }
        }
        Flow {
            id: galeriaAnim
            visible: s.verAnim
            width: parent.width
            spacing: 10
            readonly property int colunas: Math.max(2, Math.floor((width + 10) / 200))
            Repeater {
                model: s.verAnim ? s.galeriaOc : []
                TilePrevia {
                    required property var modelData
                    width: (galeriaAnim.width - (galeriaAnim.colunas - 1) * 10) / galeriaAnim.colunas
                    nome: modelData.nome
                    previa: modelData.previa
                    proporcao: 9 / 16
                    selecionado: (s.oc.animacao || "cercas") === modelData.id
                    ocupado: s.oc.ocupado === true
                    onEscolhido: if (s.oc.suporte && !s.oc.ocupado && (s.oc.animacao || "cercas") !== modelData.id) painel.widgetsAnimacao(modelData.id)
                }
            }
        }
    }

    // ---- layout dos widgets (widget-layout): não é um widget, é um controle da seção (W7)
    Row {
        id: linhaLayout
        visible: !!(painel.widgetLayout || {}).suporte
        spacing: 8
        Codigo { anchors.verticalCenter: parent.verticalCenter; text: Txt.t("wg.layout"); tamanho: 11; color: Tema.texto2 }
        Repeater {
            model: [{ id: "fui", t: "wg.layoutFui" }, { id: "livre", t: "wg.layoutLivre" }]
            Botao {
                required property var modelData
                text: Txt.t(modelData.t); tamanho: 11
                tipo: (painel.widgetLayout || {}).layout === modelData.id ? "primario" : "secundario"
                habilitado: !(painel.widgetLayout || {}).ocupado
                onClicado: if ((painel.widgetLayout || {}).layout !== modelData.id) painel.escolherLayoutWidgets(modelData.id)
            }
        }
        Leitura { anchors.verticalCenter: parent.verticalCenter; tamanho: 11; color: Tema.texto3; wrapMode: Text.NoWrap; text: Txt.t("wg.layoutDica") }
    }

    // ---- filtros
    Flow {
        id: filtros
        width: s.corpo.width
        spacing: 6
        property real traco: 1
        property real superficie: 1
        property real acender: 1
        property real realce: 0
        opacity: acender
        Cascata { ativo: s.entrando; ordem: 1; alvo: filtros }
        Repeater {
            model: ["todos", "ligados", "desligados"]
            Botao {
                required property string modelData
                text: Txt.t("wg.f." + modelData) + (modelData === "todos" ? " · " + s.todos.length : modelData === "ligados" ? " · " + s.nLigados : " · " + (s.todos.length - s.nLigados))
                tamanho: 12; implicitHeight: 28
                tipo: s.filtroEstado === modelData ? "primario" : "secundario"
                onClicado: s.filtroEstado = modelData
            }
        }
        Item { width: 18; height: 28; Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: Tema.linha } }
        Repeater {
            model: ["todas", "sistema", "informacao", "produtividade"]
            Botao {
                required property string modelData
                text: Txt.t("wg.cat." + modelData)
                tamanho: 12; implicitHeight: 28
                tipo: s.filtroCat === modelData ? "primario" : "secundario"
                onClicado: s.filtroCat = modelData
            }
        }
    }

    // ---- galeria + inspetor (ao lado, o inspetor acompanha a rolagem e fica sempre à vista)
    Item {
        id: zona
        width: s.corpo.width
        height: s.lado ? Math.max(galeria.implicitHeight, colDir.implicitHeight) : galeria.implicitHeight + 20 + colDir.implicitHeight

        Flow {
            id: galeria
            width: s.largGal
            spacing: 12
            // atalho para a seção CYBER FENCE
            Item {
                id: atalhoCerca
                visible: !!s.fence
                width: s.largGal; height: 72
                activeFocusOnTab: true
                Keys.onReturnPressed: s.app.irPara("cerca")
                Keys.onSpacePressed: s.app.irPara("cerca")
                Chanfro { anchors.fill: parent; preenchimento: maCerca.containsMouse ? Tema.hover : Tema.entrada; borda: atalhoCerca.activeFocus ? Tema.secundaria : (maCerca.containsMouse ? Tema.destaque : Tema.linha); espessura: atalhoCerca.activeFocus ? 2 : 1 }
                Column {
                    x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Rotulo { text: "Cyber Fence →"; tamanho: 16; color: Tema.destaque }
                    Leitura {
                        width: parent.width; tamanho: 12; color: Tema.texto2
                        text: { const l = s.fence ? s.fence.instancias || [] : []; return Txt.t("wg.atalhoCerca", { n: l.length, l: l.filter(i => i.ligado).length }) }
                    }
                }
                MouseArea { id: maCerca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.app.irPara("cerca") }
            }
            Repeater {
                model: s.lista
                CartaoWidget {
                    id: cw
                    required property var modelData
                    required property int index
                    width: s.largCartao
                    height: implicitHeight
                    dados: modelData
                    selecionado: s.sel === modelData.widgetNome
                    onEscolhido: s.sel = modelData.widgetNome
                    Cascata { ativo: s.entrando; ordem: 2 + cw.index; alvo: cw }
                }
            }
            Leitura {
                visible: s.lista.length === 0
                width: s.largGal; tamanho: 13; color: Tema.texto3
                text: s.todos.length === 0 ? Txt.t("wg.nenhum") : Txt.t("wg.nenhumFiltro")
            }
        }

        Column {
            id: colDir
            x: s.lado ? s.largGal + 20 : 0
            y: s.lado ? Math.max(0, Math.min(s.flick.contentY - (zona.y + s.corpo.y) + 12, zona.height - implicitHeight))
                      : galeria.implicitHeight + 20
            width: s.largInsp
            spacing: 16

            InspetorWidget {
                id: insp
                width: parent.width
                dados: s.atual
                app: s.app
                Cascata { ativo: s.entrando; ordem: 3; alvo: insp }
            }
            Bloco {
                id: blocoMapa
                width: parent.width
                titulo: Txt.t("wg.mapa").toUpperCase()
                codigo: "SCREEN.0"
                Cascata { ativo: s.entrando; ordem: 4; alvo: blocoMapa }
                MapaWidgets {
                    width: parent.width
                    geo: painel.geometriaWidgets
                    widgets: s.todos
                    filtro: (n) => !s.fence || n.split("@")[0] !== s.fence.widgetNome
                    selecionado: s.sel
                    onEscolher: (n) => s.sel = n.split("@")[0]
                }
            }
        }
    }
}
