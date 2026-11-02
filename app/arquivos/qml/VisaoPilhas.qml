import QtQuick
import "../../qml"

// Visão PILHAS: uma pilha por pasta (camadas = filhos) e uma por grupo de arquivos (imagens, vídeos…).
// Clique seleciona (pasta) ou foca (grupo); Enter/duplo clique entra na pasta ou ABRE O LEQUE do grupo:
// Nas pastas, cada painel é uma subpasta: hover destaca o painel e mostra a dica (nome decodificando,
// itens, código); clique no painel abre a subpasta direto. O painel da FRENTE é a própria pasta: clicar
// nele (ou no rótulo, ou no resto da célula) é clicar na pasta. Teclado: Enter abre a pasta; Tab/
// Shift+Tab entram nos painéis de subpasta e ↑/↓ andam entre eles; Enter abre a focada; ←/→/Esc saem.
// a pilha se desdobra numa fileira de painéis, um por arquivo, que funciona como lista horizontal.
// AGRUPAR TIPOS (Ctrl+G; padrão desligado): ligado, os arquivos soltos viram pilhas por tipo (com leque);
// desligado, cada arquivo é o seu próprio cartão na grade, na ordem da pasta, e abre direto.
// Movimento: as pilhas se montam a partir de wireframe (referência 18; só as 60 primeiras, as outras
// aparecem prontas); ao ENTRAR numa pasta, a pilha clicada abre em leque e vira a tela seguinte, e ao
// VOLTAR o leque se recolhe na pilha de onde se veio (referência 17, LequeTransicao); no fundo, a grade
// técnica com uma varredura ocasional (FundoTecnico).
Item {
    id: v
    property var aba: arquivos.aba
    property int cursor: 0                      // índice em "entradas"
    property int subFoco: -1                    // painel-subpasta focado pelo teclado na pilha do cursor
    onCursorChanged: subFoco = -1
    property var leque: null                    // grupo aberto em leque (ou null)
    property int paginaLeque: 0
    readonly property var grupos: aba ? aba.grupos : []
    readonly property var gPastas: grupos.find(g => g.id === "pastas") || null
    readonly property var gArquivos: grupos.filter(g => g.id !== "pastas")
    readonly property bool agruparTipos: Ds.janela.agruparTiposDe(aba)
    // entradas na ordem da tela: agrupando, as pastas e depois os grupos; sem agrupar, pastas e arquivos
    // na ordem do modelo (a ordenação da aba decide se misturam ou se as pastas vêm antes)
    readonly property var entradas: {
        const pastas = gPastas ? gPastas.indices : []
        if (agruparTipos) return pastas.map(i => ({ tipo: "pasta", indice: i })).concat(gArquivos.map(g => ({ tipo: "grupo", grupo: g })))
        const ehP = {}
        for (const i of pastas) ehP[i] = true
        let todos = pastas.slice()
        for (const g of gArquivos) todos = todos.concat(g.indices)
        todos.sort((a, b) => a - b)
        return todos.map(i => ({ tipo: ehP[i] ? "pasta" : "arquivo", indice: i }))
    }
    readonly property var entradaAtual: entradas[cursor] || null
    readonly property var grupoAtual: entradaAtual && entradaAtual.tipo === "grupo" ? entradaAtual.grupo : null
    // grade regular: células de tamanho fixo (a pilha tem caixa fixa), colunas centradas
    readonly property real zoom: Math.max(0.5, Math.min(3, (arquivos.zoom || 100) / 100))     // Ctrl +/−/0
    readonly property real celW: Math.round(168 * zoom)
    readonly property real celH: Math.round(190 * zoom)
    readonly property int colunasW: Math.max(1, Math.floor((width - 24) / celW))

    // ---- montagem a cada pasta nova
    property int geracao: 0
    readonly property int maxMontagem: 60       // pilhas que se montam; as outras (longe do topo) aparecem prontas
    Connections { target: v.aba; function onCarregou() { v.leque = null; v.subFoco = -1; v.cursor = Math.max(0, Math.min(v.cursor, v.entradas.length - 1)); v.tGeracao = Date.now(); v.geracao++; v.aoCarregar() } }
    Connections { target: v.aba; function onCaminhoMudou() { v.cursor = 0; v.aoMudarCaminho() } }

    // ---- transição em leque entre pastas
    property var origem: null                   // {caixa, n, cor, escala, quando}: a pilha que se abriu
    property string _caminho: ""                // caminho ANTERIOR (atribuído, não binding: senão já chega igual ao novo)
    Component.onCompleted: _caminho = aba ? aba.caminho : ""
    onAbaChanged: { _caminho = aba ? aba.caminho : ""; origem = null; _voltarPara = "" }
    property string _voltarPara: ""             // subpasta de onde se voltou (a pilha onde o leque recolhe)
    function marcarOrigem(pl) {
        if (!pl) return
        origem = { caixa: pl.mapToItem(v, 0, 0, pl.width, pl.height), n: pl.n, cor: pl.cor, escala: pl.escala, quando: Date.now() }
    }
    function dentroDe(filho, pai) { return pai !== "" && filho !== pai && filho.startsWith(pai === "/" ? "/" : pai + "/") }
    function caixaPadrao() { return Qt.rect(v.width / 2 - celW / 2, 40, celW, celH * 0.7) }
    function aoMudarCaminho() {
        const novo = aba ? aba.caminho : "", ant = _caminho
        _caminho = novo
        _voltarPara = ""
        if (dentroDe(novo, ant)) {
            const o = origem && Date.now() - origem.quando < 2500 ? origem : null
            lequeT.entrar(o ? o.caixa : caixaPadrao(), o ? o.n : 5, o ? o.cor : Tema.destaque, o ? o.escala : zoom)
        } else if (dentroDe(ant, novo)) {
            _voltarPara = (novo === "/" ? "/" : novo + "/") + ant.slice(novo === "/" ? 1 : novo.length + 1).split("/")[0]
        }
        origem = null
    }
    function aoCarregar() {
        fundo.passar()
        if (!_voltarPara) return
        const alvo = _voltarPara
        _voltarPara = ""
        // a pilha da pasta de onde se voltou (se estiver na tela), senão o centro
        // (rola até ela: a vista é virtualizada, a célula só existe na tela)
        const ind = aba.indiceDe(alvo), k = entradas.findIndex(e => e.tipo === "pasta" && e.indice === ind)
        if (k >= 0) {
            cursor = k
            grade.forceLayout()
            grade.positionViewAtIndex(k, GridView.Contain)
            const c = grade.itemAtIndex(k)
            if (c) { const pl = c.pilha; lequeT.voltar(pl.mapToItem(v, 0, 0, pl.width, pl.height), pl.n, pl.cor, pl.escala); return }
        }
        lequeT.voltar(caixaPadrao(), 5, Tema.destaque, zoom)
    }
    Connections { target: v.aba; function onSelecaoMudou() { v.sincronizarCursor() } }

    function sincronizarCursor() {
        if (!aba) return
        const k = entradas.findIndex(e => e.tipo !== "grupo" && e.indice === aba.atual)
        if (k >= 0) cursor = k
    }
    // ---- teclado (chamado pelo Main)
    // pilha (Pilha) da entrada do cursor, se for pasta
    function pilhaAtual() {
        const e = entradaAtual
        if (!e || e.tipo !== "pasta") return null
        const c = grade.itemAtIndex(cursor)
        return c ? c.pilha : null
    }
    // Tab/Shift+Tab e ↑/↓ dentro da pilha: percorre os painéis-subpasta (devolve false se não há)
    function ciclarSub(d) {
        const pl = pilhaAtual()
        if (!pl || !pl.modoSub) return false
        // só os painéis de trás (1..n-1); a frente é a pasta, que o Enter já abre
        const m = pl.n - 1
        if (m < 1) return false
        subFoco = subFoco < 1 ? (d > 0 ? 1 : m) : ((subFoco - 1 + d + m) % m) + 1
        return true
    }
    function sairSub() { if (subFoco < 0) return false; subFoco = -1; return true }
    // abre a subpasta do painel i da pilha pl (o painel "+N" abre a própria pasta)
    function abrirPainel(pl, i, indicePasta) {
        const d = pl ? pl.painel(i) : null
        if (!d) return false
        if (d.mais || d.raiz) aba.ativar(indicePasta)
        else aba.irPara(d.caminho)
        return true
    }
    function moverFoco(dx, dy, shift) {
        if (leque) { moverLeque(dx + dy * fileira.colunas); return }
        if (subFoco >= 0 && dy !== 0 && !shift) { ciclarSub(dy); return }
        subFoco = -1
        if (entradas.length === 0) return
        const novo = Math.max(0, Math.min(entradas.length - 1, cursor + dx + dy * colunasW))
        focar(novo, shift ? "intervalo" : "unico")
    }
    function focar(k, modo) {
        cursor = k
        const e = entradas[k]
        if (!e) return
        if (e.tipo !== "grupo") aba.selecionar(e.indice, modo || "unico")
        else aba.limparSelecao()
        rolarAte(k)
    }
    function ativarAtual() {
        const e = entradaAtual
        if (!e) return
        if (e.tipo === "pasta") marcarOrigem(pilhaAtual())
        if (subFoco >= 0 && e.tipo === "pasta" && abrirPainel(pilhaAtual(), subFoco, e.indice)) return
        if (e.tipo === "pasta" || e.tipo === "arquivo") aba.ativar(e.indice)
        else abrirLeque(e.grupo)
    }
    function abrirLeque(g) {
        const c = celulaDoGrupo(g)
        if (c) lequeT.entrar(c.pilha.mapToItem(v, 0, 0, c.pilha.width, c.pilha.height), c.pilha.n, c.pilha.cor, c.pilha.escala)
        leque = g; paginaLeque = 0; posLeque = 0; if (g.indices.length) aba.selecionar(g.indices[0], "unico")
    }
    function fecharLeque() {
        const g = leque
        leque = null; aba.limparSelecao()
        const c = g ? celulaDoGrupo(g) : null
        if (c) Qt.callLater(() => lequeT.voltar(c.pilha.mapToItem(v, 0, 0, c.pilha.width, c.pilha.height), c.pilha.n, c.pilha.cor, c.pilha.escala))
    }
    function celulaDoGrupo(g) { const k = entradas.findIndex(e => e.tipo === "grupo" && e.grupo === g); return k >= 0 ? grade.itemAtIndex(k) : null }
    property int posLeque: 0
    readonly property var indicesLeque: leque ? leque.indices.slice(paginaLeque * 60, paginaLeque * 60 + 60) : []
    function moverLeque(d) {
        if (!leque) return
        let p = posLeque + d
        if (p < 0 && paginaLeque > 0) { paginaLeque--; p = 59 }
        else if (p >= indicesLeque.length && (paginaLeque + 1) * 60 < leque.indices.length) { paginaLeque++; p = 0 }
        posLeque = Math.max(0, Math.min(indicesLeque.length - 1, p))
        aba.selecionar(indicesLeque[posLeque], "unico")
        fileira.positionViewAtIndex(posLeque, GridView.Contain)
    }
    function rolarAte(k) { if (k >= 0) grade.positionViewAtIndex(k, GridView.Contain) }
    // índice do modelo do item sob o cursor (para o Main: menu, renomear…)
    // (arquivo selecionado de fora — busca, prévia, Recentes — vale mais que o cursor numa pasta)
    function indiceAtual() {
        if (leque) return indicesLeque[posLeque] ?? -1
        const pasta = entradaAtual && entradaAtual.tipo !== "grupo" ? entradaAtual.indice : -1
        if (aba && aba.atual >= 0 && aba.atual !== pasta && aba.qtdSelecionados > 0 && aba.item(aba.atual).selecionado) return aba.atual
        return pasta
    }

    // ---- dica do painel-subpasta (hover ou teclado): moldura chanfrada, nome decodificando letra a letra
    readonly property var dicaPilha: {
        if (pilhaHover && pilhaHover.painelHover >= 0) return pilhaHover
        const pl = subFoco >= 0 ? pilhaAtual() : null
        return pl && pl.destacado >= 0 ? pl : null
    }

    // ---- fundo técnico (grade estática + varredura ocasional)
    FundoTecnico { id: fundo; anchors.fill: parent; z: -1; cor: Tema.destaque }
    // ---- camada da transição em leque (entre pastas e no leque dos grupos)
    LequeTransicao { id: lequeT; anchors.fill: parent }

    // ---- grade de pilhas: GridView VIRTUALIZADA (só as células visíveis existem, e são reaproveitadas
    //      ao rolar). O modelo é a contagem de "entradas"; cada célula lê a sua linha com aba.item() e
    //      relê quando o modelo avisa mudança nela (dataChanged) ou em geral (linhas entrando/saindo).
    property int revModelo: 0
    Connections {
        target: v.aba ? v.aba.modelo : null
        function onRowsInserted() { v.revModelo++ }
        function onRowsRemoved() { v.revModelo++ }
        function onModelReset() { v.revModelo++ }
        function onLayoutChanged() { v.revModelo++ }
    }
    property real tGeracao: 0                   // quando a pasta carregou: só células criadas logo depois se montam
    property var pilhaHover: null               // pilha com um painel sob o mouse (para a dica)
    // soltar / clicar no vazio (inclusive nas margens dos lados da grade)
    AlvoSoltar { etiquetaNoTopo: true; anchors.fill: parent; visible: !v.leque; destino: v.aba && !v.aba.ehLixeira && !v.aba.ehRecentes ? v.aba.caminho : "" }
    MouseArea {
        anchors.fill: parent
        visible: !v.leque
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => { if (e.button === Qt.RightButton) Ds.janela.menuItem(-1, mapToItem(null, e.x, e.y)); else v.aba.limparSelecao() }
    }
    GridView {
        id: grade
        x: Math.max(0, (v.width - width) / 2)
        width: Math.min(v.width, v.colunasW * v.celW)
        height: v.height
        visible: !v.leque
        cellWidth: v.celW; cellHeight: v.celH
        topMargin: 16; bottomMargin: 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.round(v.celH * 2)
        reuseItems: true
        model: v.entradas.length
        // a contagem mudou (pasta nova, arquivo entrando/saindo): a vista recomeça; volta ao lugar se era a mesma pasta
        property real _y: 0
        property string _pasta: ""
        onContentYChanged: if (count > 0) _y = contentY
        onCountChanged: {
            const pasta = v.aba ? v.aba.caminho : ""
            if (pasta === _pasta && _y > 0) { const y = _y; Qt.callLater(() => { grade.contentY = Math.min(y, Math.max(grade.originY - grade.topMargin, grade.contentHeight - grade.height + grade.originY + grade.bottomMargin)) }) }
            _pasta = pasta
        }
        MouseArea {
            parent: grade.contentItem
            z: -1
            y: -grade.topMargin
            width: grade.width; height: Math.max(grade.height, grade.contentHeight + grade.topMargin + grade.bottomMargin)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (e) => { if (e.button === Qt.RightButton) Ds.janela.menuItem(-1, mapToItem(null, e.x, e.y)); else v.aba.limparSelecao() }
        }
        DicaPainel { parent: grade.contentItem; z: 10; pilha: v.dicaPilha; area: grade.contentItem; topo: grade.contentY }

        delegate: Item {
            id: dp
            required property int index
            readonly property int k: index
            readonly property var e: v.entradas[index] || null
            readonly property bool grupo: !!e && e.tipo === "grupo"
            readonly property var g: grupo ? e.grupo : null
            readonly property int ind: e && !grupo ? e.indice : -1
            // a linha do modelo (pasta/arquivo); relida quando muda
            property int rev: 0
            readonly property var m: { dp.rev; v.revModelo; return ind >= 0 && v.aba ? v.aba.item(ind) : ({}) }
            Connections {
                target: dp.ind >= 0 && v.aba ? v.aba.modelo : null
                function onDataChanged(a, b) { if (dp.ind >= a.row && dp.ind <= b.row) dp.rev++ }
            }
            readonly property bool arq: !grupo && !m.ehPasta
            readonly property bool sel: grupo ? v.cursor === k : !!m.selecionado
            readonly property string caminho: m.caminho || ""
            property alias pilha: pilha
            z: pilha.destacado >= 0 ? 2 : 0
            width: v.celW; height: v.celH

            // reaproveitamento: ao sair da tela a célula vai para o "pool"; ao voltar com outra entrada, aparece
            // pronta (sem montar, sem acender, sem feixe: nada disso é para quem só rolou)
            GridView.onPooled: { pilha.quieta = true; pilha.painelHover = -1 }
            GridView.onReused: { pilha.assentar(); pilha.quieta = false; dp.pedir() }
            function pedir() { if (dp.ind >= 0 && m.ehPasta && v.aba && v.aba.pedirSubpastas) v.aba.pedirSubpastas([dp.ind]) }
            // pedido preguiçoso das subpastas (spec 19), agora só das células que aparecem
            Component.onCompleted: {
                pedir()
                pilha.animarMontagem = k < v.maxMontagem && Date.now() - v.tGeracao < 500
                pilha.iniciarMontagem()
            }
            Component.onDestruction: if (v.pilhaHover === pilha) v.pilhaHover = null
            Connections { target: v; function onGeracaoChanged() { pilha.animarMontagem = dp.k < v.maxMontagem; pilha.iniciarMontagem() } }
            Connections {
                target: pilha
                function onPainelHoverChanged() { if (pilha.painelHover >= 0) v.pilhaHover = pilha; else if (v.pilhaHover === pilha) v.pilhaHover = null }
            }

            Pilha {
                id: pilha
                visible: !dp.arq
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                escala: v.zoom
                itens: dp.grupo ? dp.g.quantidade : (dp.m.filhos ?? -1)
                itensLimite: !dp.grupo && !!dp.m.filhosLimite
                subpastas: dp.grupo ? [] : (dp.m.subpastas || [])
                subpastasTotal: dp.grupo ? -1 : (dp.m.subpastasTotal ?? -1)
                arquivosTotal: dp.grupo ? -1 : (dp.m.arquivosTotal ?? -1)
                raizNome: dp.grupo ? "" : (dp.m.nome || ""); raizCaminho: dp.grupo ? "" : dp.caminho; raizCodigo: dp.grupo ? "" : (dp.m.codigo || "")
                painelFoco: !dp.grupo && v.cursor === dp.k ? v.subFoco : -1
                acesa: dp.sel
                foco: v.cursor === dp.k && Ds.janela.focoNaArea
                hover: dp.grupo ? mg.containsMouse : ia.containsMouse
                alvoSoltar: !dp.grupo && alvo.sobre
                cor: dp.grupo ? Tema.secundaria : Tema.destaque
                atraso: Math.min(180, dp.k * 12)
            }
            // arquivo solto (sem agrupar): cartão do tamanho da pilha, com miniatura ou ícone.
            // Selecionado (U20): cheio no destaque a 85%, ícone e código no escuro (como o tile da GRADE)
            Item {
                id: cartaoArq
                visible: dp.arq
                width: Math.round(124 * v.zoom); height: pilha.height - 6
                anchors.horizontalCenter: parent.horizontalCenter
                y: 9 + (dp.sel ? -4 : 0)
                Behavior on y { enabled: !Tema.reduzir && !pilha.quieta; NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
                Chanfro {
                    x: 5; y: -5; width: parent.width; height: parent.height; corte: 9
                    preenchimento: Tema.alfa(Tema.secundaria, 0.03); borda: Tema.alfa(dp.sel ? Tema.destaque : Tema.secundaria, dp.sel ? 0.5 : 0.22)
                }
                Chanfro {
                    anchors.fill: parent; corte: 9
                    preenchimento: dp.sel ? Tema.alfa(Tema.destaque, 0.85) : Tema.alfa(Tema.secundaria, ia.containsMouse ? 0.12 : 0.06)
                    borda: dp.sel ? Tema.destaque : Tema.alfa(Tema.secundaria, ia.containsMouse ? 1 : 0.55)
                    espessura: dp.sel || (dp.k === v.cursor && Ds.janela.focoNaArea) ? 2 : 1
                }
                Image {
                    id: miniA
                    // miniatura que falha (ou vem vazia) cai no ícone do tipo (U16)
                    readonly property bool ok: status === Image.Ready && implicitWidth > 1
                    anchors.fill: parent; anchors.margins: 8; anchors.topMargin: 18
                    fillMode: Image.PreserveAspectFit
                    source: dp.arq ? (dp.m.miniatura || "") : ""
                    sourceSize.width: 260
                    asynchronous: true
                    visible: ok
                    opacity: dp.m.oculto ? 0.5 : 1
                }
                Icone {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: 5
                    width: Math.round(46 * v.zoom); height: width
                    visible: dp.arq && !miniA.ok
                    fonte: dp.arq ? (dp.m.iconeUrl || "") : ""
                    cor: dp.sel ? Tema.escuro : Tema.secundaria
                }
                Codigo { x: 9; y: 5; text: dp.m.codigo || ""; tamanho: 8; color: dp.sel ? Tema.escuro : Tema.texto3 }
            }
            // marcador de 3 px ao lado do nome (U20)
            Rectangle {
                visible: dp.sel
                x: 3; y: rotulo.y + 2; width: 3; height: 14
                color: dp.grupo ? Tema.secundaria : Tema.destaque
            }
            RotuloPilha {
                id: rotulo
                y: pilha.y + pilha.height + 6; x: 8; width: parent.width - 16
                aceso: dp.sel; titulo: dp.grupo
                nome: dp.grupo ? dp.g.rotulo : (dp.m.nome || "")
                codigo: dp.grupo ? dp.g.codigo + " · " + dp.g.quantidade + " · " + dp.g.tamanhoTexto
                      : dp.arq ? Ds.tipoDe({ ehPasta: false, grupo: dp.m.grupo, nome: dp.m.nome }).replace(/^.* · /, "") + " · " + (dp.m.tamanhoTexto || "")
                      : (dp.m.codigo || "") + " · " + (dp.m.filhos === undefined || dp.m.filhos < 0 ? "…" : (dp.m.filhosLimite ? "999+" : dp.m.filhos))
            }
            // soltar na pilha = na pasta; em cima de um painel-subpasta = direto nela (o painel sobe e a dica mostra qual)
            AlvoSoltar {
                id: alvo; anchors.fill: parent; etiquetaEmbaixo: true
                enabled: !dp.grupo
                readonly property var sub: pilha.painel(pilha.painelHover)
                destino: dp.grupo || dp.arq ? "" : sub && !sub.mais ? sub.caminho : dp.caminho
                onMoveu: (x, y) => pilha.painelHover = x < 0 ? -1 : pilha.painelEm(x - pilha.x, y - pilha.y)
            }
            Interacao {
                id: ia
                anchors.fill: parent
                z: -1           // abaixo do rótulo: o nome cortado mostra o nome inteiro no hover
                visible: !dp.grupo; enabled: !dp.grupo
                indice: dp.ind; caminho: dp.caminho; ehPasta: !dp.arq; selecionado: dp.sel
                onPressed: { v.cursor = dp.k; if (!dp.arq) v.marcarOrigem(pilha) }
                function sondar() { pilha.painelHover = containsMouse && !dp.arq ? pilha.painelEm(mouseX - pilha.x, mouseY - pilha.y) : -1 }
                onPositionChanged: sondar()
                onContainsMouseChanged: sondar()
                // painel de trás: abre a subpasta; a frente (a pasta) segue a regra da célula
                aoClicar: (e) => { if (dp.arq) return false; const i = pilha.painelEm(e.x - pilha.x, e.y - pilha.y); return i > 0 && v.abrirPainel(pilha, i, dp.ind) }
            }
            // grupo de arquivos (só com "agrupar tipos"): clique foca, duplo clique abre o leque
            MouseArea {
                id: mg
                anchors.fill: parent
                visible: dp.grupo; enabled: dp.grupo
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (e) => { v.cursor = dp.k; v.aba.limparSelecao(); Ds.janela.focarArea(); if (e.button === Qt.RightButton) Ds.janela.menuItem(-1, mapToItem(null, e.x, e.y)) }
                onDoubleClicked: v.abrirLeque(dp.g)
            }
        }
    }
    // roda (uma fileira por clique) e barra arrastável na borda direita (U4, Rolagem do Deckard)
    Rolagem { visible: !v.leque; x: 0; y: 0; width: v.width; height: v.height; alvo: grade; passo: v.celH }

    // ---- leque
    Item {
        id: caixaLeque
        anchors.fill: parent
        visible: !!v.leque
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.rapido } }
        Row {
            x: 16; y: 14
            spacing: 12
            Rotulo { text: v.leque ? v.leque.rotulo : ""; tamanho: 18; color: Tema.secundaria }
            Codigo { anchors.verticalCenter: parent.verticalCenter; tamanho: 10; text: v.leque ? v.leque.codigo + " // " + v.leque.quantidade + " · " + v.leque.tamanhoTexto : "" }
            Codigo {
                visible: !!v.leque && v.leque.indices.length > 60
                anchors.verticalCenter: parent.verticalCenter; tamanho: 10; color: Tema.destaque
                text: v.leque ? Ds.t("leque.pagina", { a: v.paginaLeque * 60 + 1, b: Math.min(v.leque.indices.length, v.paginaLeque * 60 + 60), n: v.leque.indices.length }) : ""
            }
        }
        Codigo { anchors.right: parent.right; anchors.rightMargin: 16; y: 18; tamanho: 9; text: Ds.t("leque.fechar") }
        Rectangle { x: 16; y: 44; width: parent.width - 32; height: 1; color: Tema.alfa(Tema.secundaria, 0.5) }
        // fileira do leque: cartões largos (o nome cabe em até 3 linhas), miniatura/ícone grande e
        // extensão · tamanho embaixo; quebra em linhas (←/→ andam um, ↑/↓ uma linha)
        GridView {
            id: fileira
            x: 16; y: 56
            width: parent.width - 32; height: parent.height - 64
            readonly property int colunas: Math.max(1, Math.floor(width / cellWidth))
            cellWidth: 212; cellHeight: 236
            clip: true
            model: v.indicesLeque
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: dl
                required property int index
                required property int modelData
                readonly property var it: v.aba ? v.aba.item(modelData) : ({})
                readonly property bool sel: v.posLeque === index
                readonly property string ext: { const nm = it.nome || "", p = nm.lastIndexOf("."); return p > 0 && nm.length - p <= 8 ? nm.slice(p + 1).toUpperCase() : Ds.tipoDe(it) }
                width: fileira.cellWidth; height: fileira.cellHeight
                // cartão: duas lâminas atrás (o eco da pilha) e a da frente com a miniatura
                Item {
                    id: cartao
                    x: 10; y: 14 + (dl.sel ? -6 : 0)
                    Behavior on y { enabled: !Tema.reduzir; NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
                    width: parent.width - 20; height: 128
                    Repeater {
                        model: 2
                        Chanfro {
                            required property int index
                            x: (2 - index) * 5; y: -(2 - index) * 5
                            width: cartao.width; height: cartao.height
                            corte: 10
                            preenchimento: Tema.alfa(Tema.secundaria, 0.03)
                            borda: Tema.alfa(dl.sel ? Tema.destaque : Tema.secundaria, dl.sel ? 0.5 : 0.22)
                        }
                    }
                    // selecionado (U20): cheio no destaque a 85%, ícone e código no escuro
                    Chanfro {
                        anchors.fill: parent
                        corte: 10
                        preenchimento: dl.sel ? Tema.alfa(Tema.destaque, 0.85) : Tema.alfa(Tema.secundaria, ml.containsMouse ? 0.12 : 0.06)
                        borda: dl.sel ? Tema.destaque : Tema.alfa(Tema.secundaria, ml.containsMouse ? 1 : 0.55)
                        espessura: dl.sel ? 2 : 1
                    }
                    Image {
                        id: miniL
                        // miniatura que falha (ou vem vazia) cai no ícone do tipo (U16)
                        readonly property bool ok: status === Image.Ready && implicitWidth > 1
                        anchors.fill: parent; anchors.margins: 8
                        fillMode: Image.PreserveAspectFit
                        source: dl.it.miniatura || ""
                        sourceSize.width: 360
                        asynchronous: true
                        visible: ok
                    }
                    Icone {
                        anchors.centerIn: parent
                        width: 64; height: 64
                        visible: !miniL.ok
                        fonte: dl.it.iconeUrl || ""
                        cor: dl.sel ? Tema.escuro : Tema.secundaria
                    }
                    Codigo { x: 10; y: 6; text: dl.it.codigo || ""; tamanho: 8; color: dl.sel ? Tema.escuro : Tema.texto3 }
                }
                NomeLongo {
                    id: nomeL
                    x: 8; y: cartao.y + cartao.height + 8
                    width: parent.width - 16
                    texto: dl.it.nome || ""; linhas: 3; tamanho: 12
                    cor: dl.sel ? Tema.texto : Tema.texto2
                }
                Codigo {
                    x: 8; y: nomeL.y + nomeL.height + 2; width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    text: dl.ext + (dl.it.tamanhoTexto ? " · " + dl.it.tamanhoTexto : "")
                    tamanho: 9; color: dl.sel ? Tema.secundaria : Tema.texto3
                }
                Interacao {
                    id: ml
                    anchors.fill: parent
                    z: -1
                    indice: dl.modelData; caminho: dl.it.caminho || ""; selecionado: dl.sel
                    onPressed: v.posLeque = dl.index
                }
            }
        }
        Rolagem { x: fileira.x; y: fileira.y; width: fileira.width + 10; height: fileira.height; alvo: fileira; passo: fileira.cellHeight }
    }
}
