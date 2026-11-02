import QtQuick
import "../../qml"

// Visão GRADE (referência "Generic monitors"): tiles 128×112 com moldura chanfrada, faixa de código de
// barras no topo (do código do item), miniatura ou ícone ao centro e o nome embaixo (2 linhas,
// cortado no meio). Selecionado = tile invertido (preenchido no destaque, texto escuro), o atual com a
// marca ENTER, como o DRUGSTORE da referência. Laço a partir do vazio. Zoom (Ctrl +/−/0) escala os
// tiles. AGRUPAR (aba.agrupar, papel "secao"): a GridView não tem seções, então a grade agrupada é
// desenhada à parte — um bloco por seção (cabeçalho + tiles em linhas), com altura própria.
Item {
    id: v
    property var aba: arquivos.aba
    readonly property real zm: Math.max(0.5, Math.min(3, (arquivos.zoom || 100) / 100))
    readonly property int cw: Math.round(140 * zm)
    readonly property int ch: Math.round(128 * zm)
    readonly property int colunas: Math.max(1, Math.floor((width - 24) / cw))
    readonly property bool agrupada: !!aba && aba.agrupar && !aba.modoBusca
    readonly property int cab: 36                 // altura do cabeçalho de seção

    // ---- seções da grade agrupada: [{rotulo, n, indices, y}] (y = topo do bloco)
    property var secoes: []
    property var ordemAgr: []                     // índices do modelo na ordem da tela
    property var posDe: ({})                      // índice → {s, j}
    property int revisao: 0                      // seleção mudou (os tiles agrupados leem aba.item())
    function montar() {
        if (!agrupada) { secoes = []; ordemAgr = []; posDe = ({}); return }
        let out = [], n = aba.modelo.rowCount(), atual = null, ordem = [], pos = {}
        for (let i = 0; i < n; i++) {
            const s = aba.item(i).secao || ""
            if (s !== atual || !out.length) { out.push({ rotulo: s, indices: [] }); atual = s }
            const sec = out[out.length - 1]
            pos[i] = { s: out.length - 1, j: sec.indices.length }
            sec.indices.push(i); ordem.push(i)
        }
        let y = 4
        for (const sec of out) { sec.n = sec.indices.length; sec.y = y; y += cab + Math.ceil(sec.n / colunas) * ch + 6 }
        secoes = out; ordemAgr = ordem; posDe = pos
    }
    function montarDepois() { Qt.callLater(montar) }
    onAgrupadaChanged: montarDepois()
    onColunasChanged: if (agrupada) montarDepois()
    Connections { target: v.aba; function onCarregou() { v.montarDepois() } function onSelecaoMudou() { v.revisao++ } function onOpcoesMudou() { v.montarDepois() } }
    Connections {
        target: v.aba ? v.aba.modelo : null; ignoreUnknownSignals: true
        function onModelReset() { v.montarDepois() } function onLayoutChanged() { v.montarDepois() }
        function onRowsInserted() { v.montarDepois() } function onRowsRemoved() { v.montarDepois() }
        function onDataChanged() { if (v.agrupada) { v.revisao++; v.montarDepois() } }
    }
    Component.onCompleted: montar()
    // retângulo (no conteúdo da grade agrupada) do item i
    function retDe(i) {
        const p = posDe[i]; if (!p) return null
        const sec = secoes[p.s]
        return Qt.rect((p.j % colunas) * cw, sec.y + cab + Math.floor(p.j / colunas) * ch, cw, ch)
    }

    function moverFoco(dx, dy, shift) {
        if (!aba || aba.modelo.rowCount() === 0) return
        let novo
        if (agrupada) {
            const p = posDe[aba.atual] || { s: 0, j: 0 }
            if (dx) {
                const k = Math.max(0, Math.min(ordemAgr.length - 1, ordemAgr.indexOf(aba.atual) + dx))
                novo = ordemAgr[k]
            } else {
                const col = p.j % colunas
                let s2 = p.s, j2 = p.j + dy * colunas
                if (j2 >= secoes[p.s].n) { if (p.s + 1 >= secoes.length) return; s2 = p.s + 1; j2 = Math.min(col, secoes[s2].n - 1) }
                else if (j2 < 0) { if (p.s === 0) return; s2 = p.s - 1; const n2 = secoes[s2].n; j2 = Math.min(Math.floor((n2 - 1) / colunas) * colunas + col, n2 - 1) }
                novo = secoes[s2].indices[j2]
            }
        } else novo = Math.max(0, Math.min(grade.count - 1, aba.atual + dx + dy * colunas))
        if (novo === undefined) return
        aba.selecionar(novo, shift ? "intervalo" : "unico")
        if (!shift) aba.atual = novo
        mostrar(novo)
    }
    function paginar(d) { moverFoco(0, d * Math.max(1, Math.floor(grade.height / ch) - 1), false) }
    function indiceAtual() { return aba ? aba.atual : -1 }
    function mostrar(i) {
        if (!agrupada) { grade.positionViewAtIndex(i, GridView.Contain); return }
        const r = retDe(i); if (!r) return
        if (r.y - cab < agr.contentY) agr.contentY = Math.max(0, r.y - cab)
        else if (r.y + r.height > agr.contentY + agr.height) agr.contentY = r.y + r.height - agr.height
    }
    // nome em até 2 linhas, cortado no meio
    function nomeMeio(n) { return n.length > 36 ? n.slice(0, 17) + "…" + n.slice(-17) : n }

    // ---- um tile (comum à grade normal e à agrupada)
    component Tile: Item {
        id: d
        property int idx: -1
        property string nome: ""
        property string caminho: ""
        property string codigo: ""
        property string miniatura: ""
        property string iconeUrl: ""
        property bool ehPasta: false
        property bool oculto: false
        property bool sel: false
        property int filhos: -1
        property bool limite: false
        readonly property bool atual: v.aba && v.aba.atual === idx && Ds.janela.focoNaArea
        readonly property bool editando: Ds.janela.renomeando === caminho
        width: v.cw; height: v.ch
        Item {
            id: tile
            width: v.cw - 12; height: v.ch - 16
            Chanfro {
                anchors.fill: parent
                corte: 8
                preenchimento: d.sel ? Tema.destaque : (ia.containsMouse ? Tema.alfa(Tema.destaque, 0.10) : Tema.alfa(Tema.painel, 0.85))
                borda: alvo.sobre ? Tema.destaque : d.atual ? Tema.secundaria : (d.sel || ia.containsMouse ? Tema.destaque : Tema.alfa(Tema.destaque, 0.4))
                espessura: d.atual || alvo.sobre ? 2 : 1
            }
            Rectangle { anchors.fill: parent; anchors.margins: 2; color: Tema.alfa(Tema.secundaria, 0.15); visible: (laco.ativo && laco.marcados.indexOf(d.idx) >= 0) || (lacoAgr.ativo && lacoAgr.marcados.indexOf(d.idx) >= 0) }
            CodigoBarras { x: 10; y: 8; width: d.ehPasta && d.filhos >= 0 ? Math.min(44, parent.width * 0.36) : Math.min(70, parent.width * 0.55); height: 10; texto: d.codigo; cor: d.sel ? Tema.escuro : Tema.alfa(Tema.destaque, 0.85) }
            // pasta: a contagem (informação, "999+" no limite); arquivo: o código (decorativo)
            Text {
                anchors.right: parent.right; anchors.rightMargin: 8; y: d.ehPasta && d.filhos >= 0 ? 5 : 7
                text: d.ehPasta && d.filhos >= 0 ? (d.limite || d.filhos >= 999 ? "999+" : d.filhos) + " it." : d.codigo.slice(2)
                font.family: Tema.fMono; font.pixelSize: d.ehPasta && d.filhos >= 0 ? 11 : 8
                color: d.sel ? Tema.escuro : d.ehPasta && d.filhos >= 0 ? Tema.texto2 : Tema.texto3
            }
            // miniatura ou ícone
            Item {
                x: 10; y: 22; width: parent.width - 20; height: parent.height - 60
                Image {
                    id: mini
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: d.miniatura
                    sourceSize: Qt.size(Math.round(216 * v.zm), Math.round(104 * v.zm))
                    asynchronous: true
                    // miniatura que falhou (imagem vazia) cai no ícone do tipo
                    readonly property bool ok: status === Image.Ready && implicitWidth > 1
                    visible: ok
                    opacity: d.oculto ? 0.5 : 1
                }
                Icone {
                    anchors.centerIn: parent
                    width: Math.round(36 * v.zm); height: width
                    visible: !mini.ok
                    fonte: d.iconeUrl
                    cor: d.sel ? Tema.escuro : (d.ehPasta ? Tema.destaque : Tema.texto2)
                    nitidez: d.oculto ? 0.5 : 0.95
                }
            }
            // nome em até 2 linhas, quebrando nos espaços; se não couber, corta no meio e guarda a extensão
            NomeLongo {
                visible: !d.editando
                x: 6; y: parent.height - 35; width: parent.width - 12
                texto: d.nome; linhas: 2
                tamanho: Math.round(11 * Math.sqrt(v.zm))
                cor: d.sel ? Tema.escuro : (d.oculto ? Tema.texto3 : Tema.texto)
            }
            CampoRenomear { visible: d.editando; x: 4; y: parent.height - 32; width: parent.width - 8; height: 22; ativo: d.editando; nome: d.nome; caminho: d.caminho }
            // marca ENTER no atual selecionado (o "DRUGSTORE / ENTER" da referência)
            Rectangle {
                visible: d.sel && d.atual
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 4
                width: ent.implicitWidth + 6; height: 11
                color: Tema.escuro
                Text { id: ent; anchors.centerIn: parent; text: "ENTER"; font.family: Tema.fMono; font.pixelSize: 7; font.bold: true; color: Tema.destaque }
            }
        }
        AlvoSoltar { id: alvo; anchors.fill: tile; destino: d.ehPasta ? d.caminho : "" }
        Interacao {
            id: ia
            anchors.fill: tile
            enabled: !d.editando
            indice: d.idx; caminho: d.caminho; ehPasta: d.ehPasta; selecionado: d.sel
        }
    }

    // soltar no vazio = na pasta aberta (também o que vem de fora: Dolphin, navegador, área de trabalho)
    AlvoSoltar { etiquetaNoTopo: true; anchors.fill: parent; destino: v.aba && !v.aba.ehLixeira && !v.aba.ehRecentes && !v.aba.modoBusca ? v.aba.caminho : "" }
    GridView {
        id: grade
        x: 12; y: 12
        width: parent.width - 24; height: parent.height - 12
        cellWidth: v.cw; cellHeight: v.ch
        clip: true
        visible: !v.agrupada
        model: v.agrupada ? null : (v.aba ? v.aba.modelo : null)
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600

        Laco {
            id: laco
            parent: grade.contentItem
            z: -1
            width: grade.width
            height: Math.max(grade.height, grade.contentHeight + 60)
            indicesNo: (r) => {
                let l = []
                for (let k = 0; k < grade.count; k++) {
                    const cx = (k % v.colunas) * v.cw, cy = Math.floor(k / v.colunas) * v.ch
                    if (cx < r.x + r.width && cx + v.cw - 12 > r.x && cy < r.y + r.height && cy + v.ch - 16 > r.y) l.push(k)
                }
                return l
            }
        }

        delegate: Tile {
            required property var model
            idx: model.index; nome: model.nome; caminho: model.caminho; codigo: model.codigo
            miniatura: model.miniatura; iconeUrl: model.iconeUrl; ehPasta: model.ehPasta
            oculto: model.oculto; sel: model.selecionado
            filhos: model.filhos ?? -1; limite: !!model.filhosLimite
        }
    }
    // ---- grade agrupada: um bloco por seção (cabeçalho + tiles)
    Flickable {
        id: agr
        visible: v.agrupada
        x: 12; y: 12
        width: parent.width - 24; height: parent.height - 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: v.secoes.length ? v.secoes[v.secoes.length - 1].y + v.cab + Math.ceil(v.secoes[v.secoes.length - 1].n / v.colunas) * v.ch + 20 : 0
        Laco {
            id: lacoAgr
            width: agr.width
            height: Math.max(agr.height, agr.contentHeight + 60)
            indicesNo: (r) => v.ordemAgr.filter(i => { const t = v.retDe(i); return t && t.x < r.x + r.width && t.x + v.cw - 12 > r.x && t.y < r.y + r.height && t.y + v.ch - 16 > r.y })
        }
        Repeater {
            model: v.secoes
            Item {
                id: bloco
                required property var modelData
                y: modelData.y
                width: agr.width; height: v.cab + Math.ceil(modelData.n / v.colunas) * v.ch
                Row {
                    y: 8; spacing: 10
                    Rotulo { text: bloco.modelData.rotulo; tamanho: 15; color: Tema.secundaria }
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: "// " + bloco.modelData.n; tamanho: 9 }
                }
                Rectangle { y: v.cab - 8; width: parent.width - 12; height: 1; color: Tema.alfa(Tema.secundaria, 0.5) }
                Repeater {
                    model: bloco.modelData.indices
                    Tile {
                        required property int modelData
                        required property int index
                        readonly property var it: v.aba.item(modelData)
                        x: (index % v.colunas) * v.cw; y: v.cab + Math.floor(index / v.colunas) * v.ch
                        idx: modelData        // índice no modelo ("index" é a posição na seção)
                        nome: it.nome || ""; caminho: it.caminho || ""; codigo: it.codigo || ""
                        miniatura: it.miniatura || ""; iconeUrl: it.iconeUrl || ""; ehPasta: !!it.ehPasta; oculto: !!it.oculto
                        filhos: it.filhos ?? -1; limite: !!it.filhosLimite
                        sel: v.revisao >= 0 && !!v.aba.item(modelData).selecionado
                    }
                }
            }
        }
    }
    // roda (uma linha de tiles por clique) e barra arrastável (U4)
    Rolagem { visible: !v.agrupada; x: grade.x; y: grade.y; width: grade.width + 10; height: grade.height; alvo: grade; passo: v.ch }
    Rolagem { visible: v.agrupada; x: agr.x; y: agr.y; width: agr.width + 10; height: agr.height; alvo: agr; passo: v.ch }
}
