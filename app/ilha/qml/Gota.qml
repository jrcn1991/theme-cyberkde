import QtQuick
import "Curvas.js" as Curvas
import "Atividades.js" as A
import "textos.js" as Textos

// A gota: fechada mostra uma atividade; aberta escorre e mostra o painel; um anúncio alarga a pílula.
// Porte de IslandApp.tsx + island.css do Halo. Ver docs/interno/ilha-temas.md.
Item {
    id: g
    property var tema
    property var janela: null
    property string temaId: "halo"
    property var barra: ({ altura: 0 })
    property bool fusao: false

    // ---- constantes do Halo
    readonly property int pairarMs: 320
    readonly property int sairMs: 140
    readonly property int ociosoMs: 2600
    readonly property int eventoSaidaMs: 180
    readonly property int rodaMs: 90
    readonly property int pilulaMin: 184
    readonly property int pilulaMax: satelites ? 600 : 320
    readonly property int pausaEsquecidaMs: 20000

    // ---- configuração
    readonly property var cfg: ilha.config || ({})
    readonly property string movimento: cfg.movimento || "gota"
    readonly property string estilo: cfg.estilo || "preto"
    // fundida, a pílula passa da barra o bastante para o filete contorná-la
    readonly property real alturaPilula: { const h = Math.max(24, Math.min(48, cfg.alturaPilula || 36)); return fusao ? Math.max(h, barra.altura + 9) : h }
    readonly property bool satelites: (cfg.pilula || "simples") === "satelites"
    readonly property bool trilho: (cfg.layout || "folha") === "trilho"
    readonly property real larguraCorpo: trilho ? 600 : tema.larguraAberta
    readonly property real alturaMaxPainel: 404
    readonly property real opacidadeOciosa: (cfg.opacidadeOciosa === undefined ? 55 : cfg.opacidadeOciosa) / 100
    readonly property bool abrirAoPairar: (cfg.abertura || "hover") !== "clique"

    // ---- estado
    property bool aberta: false
    property bool corpoVivo: false
    property bool hover: false
    property bool ocioso: false
    property bool fixa: false
    property bool arrastando: false
    property bool chegando: true
    property string aba: "inicio"
    property string direcao: "dir"
    property string focoId: ""
    property var pendentes: ({})
    property var niveis: []
    property real agora: Date.now()
    property var evento: null               // { id, dado, saindo }
    property var fila: []
    property int pico: 0
    readonly property var eventoVivo: evento && !evento.saindo ? evento.dado : null

    // ---- dados
    readonly property var snap: ilha.instantaneo
    readonly property var modulos: snap ? (snap.modules || []).filter(m => !(cfg.modulos || []).length || cfg.modulos.indexOf(m.id) >= 0) : []
    // os ids do back-end ("relogio", "kde") no lugar dos do Halo ("tempo", "desktop")
    // o corpo de cada tema (ilha-temas.md, seção 8); sem o token, os valores do Halo
    readonly property real raioAba: tema.raioAba ?? 17
    readonly property real raioItem: Math.min(14, tema.raioCartao)
    readonly property int segmentos: tema.segmentosBarra ?? 0
    function raioDe(lado) { return tema.raioIcone ?? lado / 2 }
    function mod(id) { const r = ({ tempo: "relogio", desktop: "kde" })[id] || id; return snap ? (snap.modules || []).find(m => m.id === r) : undefined }
    function ligado(m, r) { const v = String(valor(m, r)).toLowerCase(); return v === "ligado" || v === "ligada" || v === "on" }
    function ler(m, r) { return A.leitura(mod(m), r) }
    function valor(m, r) { const l = ler(m, r); return l ? l.value : "" }
    readonly property var modFoco: focoId ? mod(focoId) || null : null
    function txt(pt, args) { return Textos.t(ilha.idioma, pt, args) }
    function json(m, r) { const l = ler(m, r); try { return l ? JSON.parse(l.value) : [] } catch (e) { return [] } }
    // os volumes de todos os discos removíveis, cada um sabendo o disco de onde vem
    function volumes() {
        let r = []
        for (const d of json("discos", "discos-lista"))
            for (const v of (d.volumes && d.volumes.length ? d.volumes : [{ device: d.device, label: d.name }]))
                r.push(Object.assign({}, v, { disco: d.device, nomeDisco: d.name, tamanho: d.size || "" }))
        return r
    }
    function pendente(id) { return pendentes[id] === true }
    function agir(id, arg) {
        let p = Object.assign({}, pendentes); p[id] = true; pendentes = p
        ilha.agir(id, arg === undefined ? "" : String(arg))
    }
    function tempos(lado) {
        const pr = ler("midia", "midia-progresso")
        const m = pr ? /(\d+):(\d\d)\D+(\d+):(\d\d)/.exec(pr.value || "") : null
        if (!m) return ""
        return lado === 0 ? m[1] + ":" + m[2] : "-" + A.mmss((+m[3] * 60 + +m[4]) - (+m[1] * 60 + +m[2]))
    }
    readonly property string linhaLetra: {
        const l = snap ? snap.lyrics : null, pr = ler("midia", "midia-progresso")
        const m = pr ? /(\d+):(\d\d)/.exec(pr.value || "") : null
        if (!l || !l.length || !m) return ""
        const t = (+m[1] * 60 + +m[2]) * 1000
        let at = ""
        for (const x of l) { if (x.at <= t) at = x.text; else break }
        return at
    }

    // pausada há muito, a faixa sai da pílula até o play voltar
    property bool midiaEsquecida: false
    readonly property bool tocando: A.tocandoV(valor("midia", "midia-estado"))
    readonly property bool pausada: { const t = ler("midia", "midia-tocando"); return !!t && !A.nada(t.value) && !tocando }
    onPausadaChanged: { midiaEsquecida = false; if (pausada) esquecer.restart(); else esquecer.stop() }
    Timer { id: esquecer; interval: g.pausaEsquecidaMs; onTriggered: g.midiaEsquecida = true }

    property string horaLocal: Qt.formatTime(new Date(), "hh:mm")
    Timer { interval: 15000; repeat: true; running: true; onTriggered: g.horaLocal = Qt.formatTime(new Date(), "hh:mm") }
    readonly property var naPilula: A.lista(snap, midiaEsquecida, horaLocal)
    readonly property var principal: naPilula[0] || null
    readonly property var secundaria: { const s = naPilula[1]; return s && s.tipo !== "relogio" ? s : null }
    // dentro da pílula, depois da principal: em satélites até 3; fundida, a que seria a bolha
    readonly property var extras: { const l = naPilula.slice(1).filter(a => a.tipo !== "relogio"); return satelites ? l : l.slice(0, fusao ? 1 : 0) }
    function abrirDe(a) {
        if (a.tipo === "midia") abrirModulo("midia"); else escolherAba("inicio")
        aberta = true
    }

    // relógio só com contagem na tela (sem laço em repouso)
    Timer {
        interval: 1000; repeat: true
        running: !!g.snap && !!g.snap.timer
        onTriggered: g.agora = Date.now()
    }

    // ---- tinta: a cor média da capa
    readonly property string capa: { const t = ler("midia", "midia-tocando"); return t && !A.nada(t.value) && !midiaEsquecida ? t.art || "" : "" }
    property color tinta: tema.tinta
    Behavior on tinta { ColorAnimation { duration: g.tema.reduzir ? 0 : 600 } }
    Canvas {
        id: medeCapa
        width: 8; height: 8; visible: false
        onCapaChanged: {}
        property string capa: g.capa
        onImageLoaded: requestPaint()
        onPaint: {
            if (!capa || !isImageLoaded(capa)) return
            const x = getContext("2d")
            x.drawImage(capa, 0, 0, 8, 8)
            const d = x.getImageData(0, 0, 8, 8).data
            let r = 0, gg = 0, b = 0, n = 0
            for (let i = 0; i < d.length; i += 4) { r += d[i]; gg += d[i + 1]; b += d[i + 2]; n++ }
            if (n) g.tinta = Qt.tint(Qt.rgba(r / n / 255, gg / n / 255, b / n / 255, 1), Qt.rgba(1, 1, 1, 0.25))
        }
        Component.onCompleted: if (capa) loadImage(capa)
    }
    onCapaChanged: { if (capa) { if (medeCapa.isImageLoaded(capa)) medeCapa.requestPaint(); else medeCapa.loadImage(capa) } else tinta = tema.tinta }

    // ---- abas e módulos
    function escolherAba(id) {
        const ord = ["inicio", "modulos", "gaveta", "janelas", "avisos", "clips", "nota"]
        direcao = ord.indexOf(id) >= ord.indexOf(aba) ? "dir" : "esq"
        aba = id
        if (id !== "modulos") focoId = ""
        if (id === "janelas") agir("janelas-abertas")
    }
    function abrirModulo(id) { focoId = id; escolherAba("modulos") }

    // ---- abrir e fechar
    onAbertaChanged: {
        ilha.aberta(aberta)
        if (!aberta) soltarTeclado()
        if (aberta) { corpoVivo = true; matarCorpo.stop() } else matarCorpo.restart()
        mandarRegiao()
    }
    Timer { id: matarCorpo; interval: Math.max(1, g.tema.tempo(g.movimento, "conteudoSai")); onTriggered: g.corpoVivo = false }
    Timer { id: abrirTimer; interval: g.pairarMs; onTriggered: g.aberta = true }
    Timer { id: fecharTimer; interval: g.sairMs; onTriggered: g.aberta = false }
    Timer { interval: g.ociosoMs; running: !g.aberta && !g.hover; onTriggered: g.ocioso = true }
    // intenção: enquanto o ponteiro corre pela pílula, a espera recomeça (atravessar o topo não abre)
    property point _ultimoPonto
    property real _ultimoTempo: 0
    function _pairando(p) {
        const a = Date.now(), dt = Math.max(1, a - _ultimoTempo)
        const v = Math.hypot(p.x - _ultimoPonto.x, p.y - _ultimoPonto.y) / dt
        _ultimoPonto = p; _ultimoTempo = a
        if (v > 0.15 && abrirTimer.running) abrirTimer.restart()
    }
    onHoverChanged: {
        if (hover) {
            ocioso = false
            fecharTimer.stop()
            if (abrirAoPairar && !aberta) abrirTimer.restart()
        } else {
            abrirTimer.stop()
            if (!fixa) fecharTimer.restart()
        }
    }
    onFixaChanged: if (!fixa && !hover) aberta = false

    // ---- anúncios, um por vez (uma chave substitui o vivo da mesma chave)
    property int _seq: 0
    function anunciar(dado) {
        if (!dado) return
        const novo = { id: ++_seq, dado: dado, saindo: false }
        if (dado.key) {
            if (evento && evento.dado.key === dado.key && !evento.saindo) {
                evento = Object.assign({}, evento, { dado: dado })
                armarEvento(dado)
                return
            }
            const i = fila.findIndex(e => e.dado.key === dado.key)
            if (i >= 0) { fila[i] = novo; return }
        }
        fila.push(novo)
        if (!evento) proximoEvento()
    }
    function proximoEvento() {
        saidaEvento.stop(); fimEvento.stop()
        const p = fila.shift()
        evento = p || null
        if (p) { pico++; armarEvento(p.dado) }
    }
    function armarEvento(dado) {
        const ttl = dado.ttlMs || 2500
        saidaEvento.interval = Math.max(1, ttl - eventoSaidaMs)
        fimEvento.interval = ttl
        saidaEvento.restart(); fimEvento.restart()
    }
    Timer { id: saidaEvento; onTriggered: if (g.evento) g.evento = Object.assign({}, g.evento, { saindo: true }) }
    Timer { id: fimEvento; onTriggered: g.proximoEvento() }
    Connections {
        target: ilha
        function onEvento(e) { g.anunciar(e) }
        function onEspectro(l) { g.niveis = l }
        function onAcaoTerminou(id, ok, texto) {
            let p = Object.assign({}, g.pendentes); delete p[id]; g.pendentes = p
            if (id === "janelas-abertas") { try { g.janelasAbertas = ok ? JSON.parse(texto) : [] } catch (e) { g.janelasAbertas = [] } }
            if (!ok && texto) g.anunciar({ icon: "WarningCircle", text: texto, level: "alerta", ttlMs: 4500, kind: "aviso" })
        }
        function onDemonstrar(tipo) { g.demonstrar(tipo) }
        function onAtalhoAcionado(acao) { g.atalho(acao) }
        function onResultadoLancador(itens) { g.apps = itens }
        function onVoo(dado) { g.voar(dado) }
    }
    // ---- lançador e janelas
    property var apps: []
    property var janelasAbertas: null
    // ---- voo: fecha o painel (a pílula é a boca) e quica quando o fantasma chega
    property var vooAtual: null
    readonly property int vooMs: 560
    function voar(dado) {
        abrirTimer.stop(); fixa = false; hover = false; aberta = false
        if (tema.reduzir || dado.estilo === "nenhuma") return
        vooAtual = dado
        if (dado.sentido === "volta") quique.restart(); else quiqueDepois.restart()
    }
    Timer { id: quiqueDepois; interval: g.vooMs; onTriggered: quique.restart() }
    ParallelAnimation {
        id: quique
        NumberAnimation { target: esc; property: "xScale"; from: 1.04; to: 1; duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Curvas.curva("gelatina") }
        NumberAnimation { target: esc; property: "yScale"; from: 1.1; to: 1; duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Curvas.curva("gelatina") }
    }
    // atalho global: só a ilha da tela principal responde; a nota já abre pronta para digitar
    property bool querNota: false
    // ---- teclado: só com um campo em uso. O compositor só dá o foco depois de a superfície pedir
    property bool teclado: false
    property Item campoAtivo: null
    function pedirTeclado(campo) {
        campoAtivo = campo; teclado = true
        Qt.callLater(() => { if (janela) janela.requestActivate(); if (campoAtivo) campoAtivo.forceActiveFocus() })
    }
    function soltarTeclado() {
        const tinha = teclado
        if (campoAtivo) campoAtivo.focus = false
        campoAtivo = null; teclado = false
        if (tinha && janela) Qt.callLater(janela.religar)
    }
    onAbaChanged: soltarTeclado()
    function atalho(acao) {
        if (janela && janela.tela && janela.tela.principal === false && (ilha.telas || []).length > 1) return
        fecharTimer.stop(); abrirTimer.stop()
        if (acao === "nota") { querNota = true; escolherAba("nota"); aberta = true }
        else aberta = !aberta
    }
    // ---- dicas: nome e estado, 500 ms depois de parar sobre o controle
    property string dicaTexto: ""
    property Item dicaAlvo: null
    property string _dicaPedida: ""
    function pedirDica(texto, item) {
        dicaTexto = ""; _dicaPedida = texto; dicaAlvo = item
        if (texto && !tema.reduzir) esperaDica.restart(); else if (texto) dicaTexto = texto; else esperaDica.stop()
    }
    Timer { id: esperaDica; interval: 500; onTriggered: g.dicaTexto = g._dicaPedida }
    function demonstrar(tipo) {
        if (tipo === "abrir") { aberta = true; fecharDemo.restart() }
        else if (tipo === "voo") voar({ sentido: "ida", estilo: cfg.voo || "sugado", title: "CyberKDE", from: { x: 500, y: 300, width: 500, height: 320 } })
        else if (tipo === "hud") anunciar({ kind: "hud", icon: "SpeakerHigh", text: "Volume", level: "ok", ratio: 0.62, key: "demo", ttlMs: 1500 })
        else if (tipo === "aviso") anunciar({ kind: "aviso", icon: "Warning", text: txt("Avisos"), detail: "CyberKDE", level: "alerta", ttlMs: 4500 })
        else anunciar({ icon: "Sparkle", text: "CyberKDE", detail: temaId, level: "ok" })
    }
    Timer { id: fecharDemo; interval: 2200; onTriggered: if (!g.hover) g.aberta = false }

    // ---- geometria
    // fundida e fechada, a ponta direita é do Fusao.qml do tema (tema.reservaFusao px): o conteúdo não entra ali
    readonly property real reservaFusao: fusao ? Math.max(0, tema.reservaFusao || 0) : 0
    readonly property real larguraResumo: Math.max(pilulaMin, Math.min(pilulaMax, medeResumo.implicitWidth + 24) + reservaFusao)
    readonly property real larguraEvento: Math.max(200, Math.min(pilulaMax, medeAnuncio.implicitWidth + 28) + reservaFusao)
    readonly property real alturaCorpo: corpoCarga.item ? Math.min(456 + (fusao ? barra.altura : 0), corpoCarga.item.implicitHeight + 8 + (fusao ? barra.altura : 0)) : alturaPilula
    readonly property bool anunciando: !!evento && !aberta
    // movimento "expandir" e similares vêm do tema; "aberta" manda no tempo e na curva
    readonly property string _momento: aberta ? "abrir" : anunciando ? "anuncio" : "fechar"
    readonly property int _dur: tema.tempo(movimento, _momento)
    readonly property var _cur: Curvas.curva(tema.curva(movimento, _momento))

    property real raioBase: aberta ? (cfg.cantos === undefined || cfg.cantos < 0 ? tema.raioAberto : cfg.cantos) : alturaPilula / 2
    Behavior on raioBase { NumberAnimation { duration: g._dur; easing.type: Easing.BezierSpline; easing.bezierCurve: g._cur } }

    width: aberta ? larguraCorpo : anunciando ? larguraEvento : larguraResumo + (hover ? 8 : 0)
    height: aberta ? alturaCorpo : alturaPilula
    Behavior on width { NumberAnimation { id: anW; duration: g._dur; easing.type: Easing.BezierSpline; easing.bezierCurve: g._cur } }
    Behavior on height { NumberAnimation { id: anH; duration: g._dur; easing.type: Easing.BezierSpline; easing.bezierCurve: g._cur } }
    readonly property bool animando: anW.running || anH.running
    onAnimandoChanged: if (!animando) mandarRegiao()
    onWidthChanged: if (!animando) mandarRegiao()
    onHeightChanged: if (!animando) mandarRegiao()

    // fundida, a placa é parte da barra e não desbota; quem desbota é só o conteúdo
    readonly property real opacidadeRepouso: ocioso && !aberta && !anunciando ? opacidadeOciosa : 1
    opacity: fusao ? 1 : opacidadeRepouso
    Behavior on opacity { NumberAnimation { duration: g.tema.reduzir ? 0 : 500; easing.type: Easing.OutCubic } }
    transformOrigin: Item.Top

    // squash ao alargar, chegada ao subir
    transform: [
        Scale { id: esc; origin.x: g.width / 2; origin.y: 0 },
        Translate { id: chegar }
    ]
    SequentialAnimation {
        id: squash
        NumberAnimation { target: esc; property: "yScale"; to: 0.955; duration: 147 }
        NumberAnimation { target: esc; property: "yScale"; to: 1; duration: 273; easing.type: Easing.OutCubic }
    }
    onPicoChanged: if (!tema.reduzir && movimento !== "nenhuma" && movimento !== "desliza") squash.restart()
    Component.onCompleted: {
        if (!tema.reduzir && tema.tempo(movimento, "chegada") > 0) { chegar.y = -height; esc.xScale = 0.9; anChegada.start() } else chegando = false
        mandarRegiao()
        carregarPecas()
    }
    ParallelAnimation {
        id: anChegada
        NumberAnimation { target: chegar; property: "y"; to: 0; duration: g.tema.tempo(g.movimento, "chegada"); easing.type: Easing.BezierSpline; easing.bezierCurve: Curvas.curva(g.tema.curva(g.movimento, "chegada")) }
        NumberAnimation { target: esc; property: "xScale"; to: 1; duration: g.tema.tempo(g.movimento, "chegada") }
        onFinished: g.chegando = false
    }

    // ---- máscara: a região recebe o tamanho FINAL antes da animação
    property Item bolhaItem: null
    function mandarRegiao() {
        if (!janela) return
        const w = aberta ? larguraCorpo : Math.max(width, anunciando ? larguraEvento : larguraResumo + 8)
        const h = (aberta ? alturaCorpo : alturaPilula) + 6
        const cx = g.mapToItem(null, width / 2, 0).x, y0 = Math.round(parent ? parent.y : 0)   // o y sem a chegada, que anima por transform
        let r = [{ x: Math.round(cx - w / 2), y: y0, width: Math.round(w), height: Math.round(h) }]
        if (bolhaItem && bolhaItem.visible && bolhaItem.width > 0) r.push({ x: Math.round(bolhaItem.mapToItem(null, 0, 0).x), y: y0, width: Math.round(bolhaItem.width), height: Math.round(bolhaItem.height) })
        ilha.definirRegiao(janela, r)
    }
    onAlturaCorpoChanged: mandarRegiao()

    // ---- contexto do tema
    QtObject {
        id: ctxObj
        readonly property bool aberta: g.aberta
        readonly property bool hover: g.hover
        readonly property bool evento: g.anunciando
        readonly property string nivel: g.evento ? g.evento.dado.level || "ok" : "ok"
        readonly property string kind: g.evento ? g.evento.dado.kind || "comum" : "comum"
        readonly property bool chegando: g.chegando
        readonly property bool ocioso: g.ocioso
        readonly property bool arrastando: g.arrastando
        readonly property string estilo: g.estilo
        readonly property string movimento: g.movimento
        readonly property bool reduzir: g.tema.reduzir
        readonly property real alturaPilula: g.alturaPilula
        readonly property real alturaAberta: g.alturaCorpo
        readonly property color tinta: g.tinta
        readonly property real largura: g.width
        readonly property real altura: g.height
        readonly property real raio: g.raioBase
        readonly property int pico: g.pico
        readonly property bool fusao: g.fusao
        // a aba, ou "modulos/<id>" com um módulo aberto: muda a cada troca (ilha-temas.md)
        readonly property string modulo: g.aba === "modulos" && g.focoId ? "modulos/" + g.focoId : g.aba
    }
    Loader { id: cascaCarga; anchors.fill: parent; visible: !g.fusao }
    FusaoBarra { visible: g.fusao; anchors.fill: parent; tema: g.tema; barra: g.barra; raio: g.raioBase }
    // a identidade do tema dentro do traçado (Fusao.qml, opcional): sobre o fundo, sem tocar no filete
    Loader { id: fusaoCarga; anchors.fill: parent; visible: g.fusao }
    Component { id: cascaPadrao; CascaPadrao { tema: g.tema; ctx: ctxObj } }
    // Casca.qml e Efeito.qml são opcionais: basta o arquivo existir na pasta do tema
    function _temArquivo(nome) { return Qt.createComponent("temas/" + temaId + "/" + nome).status === Component.Ready }
    function carregarPecas() {
        if (_temArquivo("Fusao.qml")) fusaoCarga.setSource("temas/" + temaId + "/Fusao.qml", { tema: tema, ctx: ctxObj })
        else fusaoCarga.source = ""
        if (_temArquivo("Casca.qml")) cascaCarga.setSource("temas/" + temaId + "/Casca.qml", { tema: tema, ctx: ctxObj })
        else { cascaCarga.source = ""; cascaCarga.sourceComponent = cascaPadrao }
        if (!tema.reduzir && _temArquivo("Efeito.qml")) efeitoCarga.setSource("temas/" + temaId + "/Efeito.qml", { tema: tema, ctx: ctxObj })
        else efeitoCarga.source = ""
    }
    onTemaChanged: Qt.callLater(carregarPecas)

    // ---- gestos
    HoverHandler { onHoveredChanged: g.hover = hovered; onPointChanged: g._pairando(point.position) }
    TapHandler {
        enabled: !g.aberta
        onTapped: g.aberta = true
    }
    property real _ultimaRoda: 0
    WheelHandler {
        enabled: !g.aberta
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            const a = Date.now()
            if (a - g._ultimaRoda < g.rodaMs) return
            g._ultimaRoda = a
            const v = g.ler("audio", "volume")
            const atual = v && v.ratio !== null ? v.ratio * 100 : 50
            g.agir("volume-definir", String(Math.max(0, Math.min(100, Math.round(atual + (e.angleDelta.y > 0 ? 5 : -5))))))
        }
    }
    DropArea {
        anchors.fill: parent
        onEntered: { g.arrastando = true; abrirTimer.stop(); g.aberta = true }
        onExited: { g.arrastando = false; if (!g.hover && !g.fixa) fecharTimer.restart() }
        onDropped: (d) => {
            g.arrastando = false
            ilha.soltar(d.hasUrls ? d.urls.map(String) : [], d.hasText ? d.text : "")
            d.accept()
            g.escolherAba("gaveta")
        }
    }

    // ---- pílula
    Item {
        id: resumoCaixa
        width: g.width; height: g.alturaPilula
        readonly property bool some: g.aberta || (g.anunciando)
        opacity: some ? 0 : (g.fusao ? g.opacidadeRepouso : 1)
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: g.tema.reduzir ? 0 : 180 } }
        Row {
            id: medeResumo
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -g.reservaFusao / 2
            spacing: 10
            Resumo { tema: g.tema; ui: g; a: g.principal; niveis: g.niveis; alturaPilula: g.alturaPilula; agora: g.agora }
            Repeater {
                model: g.extras.slice(0, 3)
                Row {
                    id: sat
                    required property var modelData
                    spacing: 10
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: g.tema.bordaForte }
                    Resumo {
                        tema: g.tema; ui: g; a: sat.modelData; niveis: g.niveis; alturaPilula: g.alturaPilula; agora: g.agora
                        TapHandler { onTapped: g.abrirDe(sat.modelData) }
                    }
                }
            }
            Text {
                visible: g.extras.length > 3
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + (g.extras.length - 3); color: g.tema.texto2; font.family: g.tema.fonte; font.pixelSize: 12
            }
        }
    }
    // ---- anúncio
    Item {
        id: anuncioCaixa
        width: g.width; height: g.alturaPilula
        visible: g.anunciando
        opacity: g.evento && g.evento.saindo ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: g.tema.reduzir ? 0 : 180 } }
        Anuncio { id: medeAnuncio; anchors.centerIn: parent; anchors.horizontalCenterOffset: -g.reservaFusao / 2; tema: g.tema; ev: g.evento ? g.evento.dado : ({}) }
    }
    // ---- corpo
    // recorta só enquanto a geometria anima: parada, a gota não paga clip
    Item {
        id: corpoRecorte
        anchors.fill: parent
        clip: g.animando || !g.aberta
    Loader {
        id: corpoCarga
        active: g.corpoVivo
        width: g.larguraCorpo
        anchors.horizontalCenter: parent.horizontalCenter
        y: g.fusao ? g.barra.altura : 0
        opacity: g.aberta ? 1 : 0
        scale: g.aberta ? 1 : 0.96
        // a fusão desce o corpo: a faixa da barra continua da barra
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: g.tema.reduzir ? 0 : (g.aberta ? g.tema.tempo(g.movimento, "conteudoEntra") : g.tema.tempo(g.movimento, "conteudoSai")); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: g.tema.reduzir ? 0 : g._dur } }
        sourceComponent: Corpo { ui: g; width: g.larguraCorpo }
    }
    }
    // ---- efeito do tema
    Loader {
        id: efeitoCarga
        z: 100
        // o Efeito fica na gota, não no Loader: o glitch fotografa o parent dele
        onLoaded: { item.parent = g; item.anchors.fill = g; item.z = 100 }
    }
    // ---- dica
    Rectangle {
        z: 90
        visible: g.dicaTexto !== "" && !!g.dicaAlvo && g.aberta
        readonly property point p: g.dicaAlvo ? g.dicaAlvo.mapToItem(g, g.dicaAlvo.width / 2, g.dicaAlvo.height) : Qt.point(0, 0)
        x: Math.max(6, Math.min(g.width - width - 6, p.x - width / 2))
        y: Math.min(g.height - height - 6, p.y + 4)
        width: tDica.implicitWidth + 16; height: tDica.implicitHeight + 8
        radius: g.tema.raioControle
        color: g.tema.fundoForte; border.color: g.tema.bordaForte
        Text { id: tDica; x: 8; y: 4; text: g.dicaTexto; color: g.tema.texto; font.family: g.tema.fonte; font.pixelSize: 12 }
    }
}
