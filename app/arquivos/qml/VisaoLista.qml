import QtQuick
import "../../qml"

// Visão LISTA DE DADOS (referência "Modal do projeto alt3", a lista "nome · hex"): ▸ | nome | tipo |
// tamanho | modificado | hex | permissões. Clique direito no cabeçalho mostra/esconde colunas (guardado
// na interface); estreito (tela dividida, janela pequena), HEX e PERM. somem antes de cortar o nome. Na
// lixeira, ORIGEM e APAGADO EM no lugar de TIPO e PERM.; na busca, NOME e PASTA dividem o espaço. Linhas de 22 px com alternância sutil; cabeçalho ordena (clique) e as
// colunas se redimensionam (arrastar o filete). Selecionada: fundo de seleção + marcador; atual: borda
// secundária. Laço (rubber band) começando no espaço vazio. Na busca, entra a coluna PASTA. Zoom
// (Ctrl +/−/0) escala linhas e letras; AGRUPAR (aba.agrupar) põe cabeçalhos de seção (papel "secao").
Item {
    id: v
    property var aba: arquivos.aba
    readonly property bool busca: !!aba && aba.modoBusca
    readonly property bool lixeira: !!aba && aba.ehLixeira
    readonly property var pc: Ds.janela.prefsLista
    readonly property bool estreito: width < 820
    readonly property bool vHex: pc.hex && !estreito
    readonly property bool vPerm: pc.perm && !estreito
    readonly property bool vTipo: pc.tipo || lixeira
    readonly property bool vTam: pc.tamanho
    readonly property bool vData: pc.data
    // larguras das colunas (o nome fica com o resto; na busca, nome e pasta dividem o resto)
    property real wCod: 78
    property real wTipo: busca ? 110 : 150
    property real wTam: 90
    property real wData: 128
    property real wPerm: 92
    readonly property real _resto: width - 24 - 20 - (vHex ? wCod : 0) - (vTipo ? wTipo : 0) - (vTam ? wTam : 0) - (vData ? wData : 0) - (vPerm ? wPerm : 0)
    readonly property real wPasta: busca ? Math.max(120, _resto * 0.42) : 0
    readonly property real wNome: Math.max(140, _resto - wPasta)
    readonly property real zm: Math.max(0.5, Math.min(3, (arquivos.zoom || 100) / 100))
    readonly property int alturaLinha: Math.round(22 * zm)
    function px(n) { return Math.round(n * Math.sqrt(zm)) }

    function moverFoco(dx, dy, shift) {
        if (!aba || lista.count === 0) return
        const novo = Math.max(0, Math.min(lista.count - 1, aba.atual + dy + dx))
        aba.selecionar(novo, shift ? "intervalo" : "unico")
        if (!shift) aba.atual = novo
        lista.positionViewAtIndex(novo, ListView.Contain)
    }
    function paginar(d) { moverFoco(0, d * Math.max(1, Math.floor(lista.height / alturaLinha) - 1), false) }
    function indiceAtual() { return aba ? aba.atual : -1 }
    function mostrar(i) { lista.positionViewAtIndex(i, ListView.Contain) }

    // ---- cabeçalho
    Item {
        id: cab
        width: parent.width; height: 26
        Rectangle { anchors.fill: parent; color: Tema.alfa(Tema.painel, 0.9) }
        Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Tema.alfa(Tema.destaque, 0.5) }
        Row {
            x: 12 + 20
            height: parent.height
            Coluna { largura: v.wNome; texto: Ds.t("col.nome"); chave: "nome"; redimensiona: false }
            Coluna { visible: v.busca; largura: v.wPasta; texto: Ds.t("col.pasta"); chave: ""; redimensiona: false }
            Coluna { visible: v.vTipo; largura: v.wTipo; texto: v.lixeira ? Ds.t("col.origem") : Ds.t("col.tipo"); chave: v.lixeira ? "" : "tipo"; onRedimensionado: (w) => v.wTipo = w }
            Coluna { visible: v.vTam; largura: v.wTam; texto: Ds.t("col.tamanho"); chave: "tamanho"; direita: true; onRedimensionado: (w) => v.wTam = w }
            Coluna { visible: v.vData; largura: v.wData; texto: Ds.t("col.modificado"); chave: "data"; direita: true; onRedimensionado: (w) => v.wData = w }
            Coluna { visible: v.vHex; largura: v.wCod; texto: "HEX"; chave: ""; onRedimensionado: (w) => v.wCod = w }
            Coluna { visible: v.vPerm; largura: v.wPerm; texto: v.lixeira ? Ds.t("col.apagadoEm") : Ds.t("col.permissoes"); chave: ""; onRedimensionado: (w) => v.wPerm = w }
        }
        // clique direito no cabeçalho: mostrar/esconder colunas (como no Dolphin)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (e) => {
                const item = (k, rot) => ({ texto: (v.pc[k] ? "✓  " : "     ") + rot, acao: () => v.pc[k] = !v.pc[k] })
                Ds.janela.abrirMenu([item("tipo", Ds.t("col.tipo")), item("tamanho", Ds.t("col.tamanho")), item("data", Ds.t("col.modificado")),
                                     item("hex", "HEX"), item("perm", Ds.t("col.permissoes"))], mapToItem(null, e.x, e.y))
            }
        }
    }
    component Coluna: Item {
        id: c
        property real largura: 80
        property string texto: ""
        property string chave: ""
        property bool direita: false
        property bool redimensiona: true
        signal redimensionado(real w)
        width: largura; height: parent.height
        readonly property bool ativa: c.chave !== "" && v.aba && v.aba.ordem === c.chave
        Codigo {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: c.direita ? parent.right : undefined; anchors.rightMargin: 10
            x: c.direita ? 0 : 4
            text: c.texto + (c.ativa ? (v.aba.decrescente ? " ▾" : " ▴") : "")
            tamanho: 10; font.bold: c.ativa
            color: c.ativa ? Tema.destaque : Tema.texto2
        }
        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 6
            enabled: c.chave !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (c.ativa) v.aba.decrescente = !v.aba.decrescente; else { v.aba.ordem = c.chave; v.aba.decrescente = false } }
        }
        // filete de redimensionar
        Rectangle {
            visible: c.redimensiona
            anchors.right: parent.right; width: 1; height: parent.height - 8; y: 4
            color: Tema.alfa(Tema.linha, 0.9)
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.SplitHCursor
                property real x0: 0
                onPressed: (e) => x0 = e.x
                onPositionChanged: (e) => { if (pressed) c.redimensionado(Math.max(50, c.width + e.x - x0)) }
            }
        }
    }

    // soltar no vazio = na pasta aberta (também o que vem de fora: Dolphin, navegador, área de trabalho)
    AlvoSoltar { etiquetaNoTopo: true; anchors.fill: parent; destino: v.aba && !v.aba.ehLixeira && !v.aba.ehRecentes && !v.aba.modoBusca ? v.aba.caminho : "" }
    // ---- linhas
    ListView {
        id: lista
        x: 12; y: cab.height + 4
        width: parent.width - 24; height: parent.height - y
        clip: true
        model: v.aba ? v.aba.modelo : null
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        currentIndex: v.aba ? v.aba.atual : -1
        highlightFollowsCurrentItem: false
        section.property: v.aba && v.aba.agrupar && !v.busca ? "secao" : ""
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            required property string section
            width: lista.width; height: 30
            Row {
                x: 8; y: 9; spacing: 10
                Rotulo { text: parent.parent.section; tamanho: 13; color: Tema.secundaria }
            }
            Rectangle { y: parent.height - 3; x: 8; width: parent.width - 16; height: 1; color: Tema.alfa(Tema.secundaria, 0.5) }
        }

        // laço e cliques no vazio (atrás das linhas)
        Laco {
            id: laco
            parent: lista.contentItem
            z: -1
            width: lista.width
            height: Math.max(lista.height, lista.contentHeight + 60)
            indicesNo: (r) => {
                let l = []
                // indexAt: vale também com cabeçalhos de seção (as linhas não ficam a múltiplos da altura)
                let a = lista.indexAt(30, r.y), b = lista.indexAt(30, r.y + r.height)
                if (a < 0) a = r.y <= 0 ? 0 : lista.indexAt(30, r.y + 30)
                if (b < 0) b = lista.count - 1
                a = Math.max(0, a)
                for (let i = a; i <= b; i++) l.push(i)
                return r.x < 20 + v.wNome ? l : []
            }
        }

        delegate: Item {
            id: d
            required property int index
            required property var model
            width: lista.width; height: v.alturaLinha
            readonly property bool atual: v.aba && v.aba.atual === index && Ds.janela.focoNaArea
            readonly property bool editando: Ds.janela.renomeando === model.caminho
            Rectangle {
                anchors.fill: parent
                color: d.model.selecionado ? Tema.selecao : (ia.containsMouse ? Tema.hover : (d.index % 2 ? Tema.alfa(Tema.alternado, 0.6) : "transparent"))
                border.width: d.atual ? 1 : 0
                border.color: Tema.secundaria
                // (laço) pré-seleção
                Rectangle { anchors.fill: parent; color: Tema.alfa(Tema.secundaria, 0.15); visible: laco.ativo && laco.marcados.indexOf(d.index) >= 0 }
            }
            Rectangle { visible: d.model.selecionado; width: 3; height: parent.height; color: Tema.destaque }
            AlvoSoltar { id: alvoL; anchors.fill: parent; destino: d.model.ehPasta ? d.model.caminho : "" }
            Rectangle { anchors.fill: parent; color: "transparent"; border.color: Tema.destaque; visible: alvoL.sobre }
            Row {
                x: 8; height: parent.height
                Text { width: 12; anchors.verticalCenter: parent.verticalCenter; text: d.model.ehPasta ? "▸" : ""; color: Tema.destaque; font.pixelSize: v.px(11) }
                Item {
                    width: v.wNome; height: parent.height
                    Icone {
                        id: ic
                        width: v.px(16); height: width; anchors.verticalCenter: parent.verticalCenter
                        fonte: d.model.iconeUrl
                        cor: d.model.ehPasta ? Tema.destaque : Tema.texto3
                        nitidez: d.model.oculto ? 0.5 : 1
                    }
                    Text {
                        visible: !d.editando
                        x: 22; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                        text: d.model.nome + (d.model.ehLink ? "  →" : ""); elide: Text.ElideMiddle
                        font.family: Tema.fTexto; font.pixelSize: v.px(13)
                        color: d.model.oculto ? Tema.texto3 : (d.model.selecionado ? Tema.texto : (d.model.ehPasta ? Tema.texto : Tema.texto2))
                    }
                    CampoRenomear { visible: d.editando; x: 20; width: parent.width - 24; height: parent.height - 2; anchors.verticalCenter: parent.verticalCenter; ativo: d.editando; nome: d.model.nome; caminho: d.model.caminho }
                }
                Text {
                    visible: v.busca; width: v.wPasta; anchors.verticalCenter: parent.verticalCenter
                    text: d.model.local || d.model.pastaPai; elide: Text.ElideLeft
                    font.family: Tema.fTexto; font.pixelSize: v.px(12); color: Tema.texto2
                }
                Text {
                    visible: v.vTipo; width: v.wTipo - 8; anchors.verticalCenter: parent.verticalCenter
                    text: v.lixeira ? (d.model.origem || "").replace(/^\/home\/[^/]+/, "~") : Ds.tipoDe({ ehPasta: d.model.ehPasta, grupo: d.model.grupo, nome: d.model.nome })
                    elide: v.lixeira ? Text.ElideLeft : Text.ElideRight
                    font.family: Tema.fTexto; font.pixelSize: v.px(12); color: Tema.texto2
                }
                Item { visible: v.vTipo; width: 8; height: 1 }
                Text {
                    visible: v.vTam
                    width: v.wTam - 10; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                    text: d.model.ehPasta ? (d.model.filhos < 0 ? "…" : (d.model.filhosLimite || d.model.filhos >= 999 ? "999+" : d.model.filhos) + " it.") : d.model.tamanhoTexto
                    font.family: Tema.fMono; font.pixelSize: v.px(11); color: Tema.texto2
                }
                Item { visible: v.vTam; width: 10; height: 1 }
                Text { visible: v.vData; width: v.wData - 10; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: d.model.modificadoTexto; font.family: Tema.fMono; font.pixelSize: v.px(11); color: Tema.texto2 }
                Item { visible: v.vData; width: 10; height: 1 }
                Text {
                    visible: v.vHex; width: v.wCod; anchors.verticalCenter: parent.verticalCenter
                    text: d.model.codigo; font.family: Tema.fMono; font.pixelSize: v.px(11)
                    color: d.model.selecionado ? Tema.texto2 : Tema.texto3          // decorativo
                }
                Text {
                    visible: v.vPerm; width: v.wPerm; anchors.verticalCenter: parent.verticalCenter
                    text: v.lixeira ? (d.model.apagadoEm || "") : d.model.permissoes
                    elide: Text.ElideRight
                    font.family: Tema.fMono; font.pixelSize: v.px(11); color: Tema.texto2
                }
            }
            Interacao {
                id: ia
                anchors.fill: parent
                enabled: !d.editando
                indice: d.index; caminho: d.model.caminho; ehPasta: d.model.ehPasta; selecionado: d.model.selecionado
            }
        }
    }
    // roda com passo de 3 linhas e barra arrastável (U4)
    Rolagem { x: lista.x; y: lista.y; width: lista.width + 10; height: lista.height; alvo: lista; passo: 3 * v.alturaLinha }
}
