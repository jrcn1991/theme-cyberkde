import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Notícias: manchetes de feeds RSS e Atom (XMLHttpRequest, a cada intervaloMin) no estilo de um
// noticiário do jogo: fonte e hora, cintilação ao chegar notícia nova, ticker rolando no tamanho pequeno.
// Clique abre a notícia no navegador e a marca como lida (chave "lidas"). Só leitura dos feeds.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    readonly property int maxNoticias: 40
    readonly property var feeds: String(cfg.feeds || "").split(/[\s|]+/).filter(u => /^(https?|file):\/\//i.test(u)).slice(0, 12)

    // ---- estado
    property var porFeed: ({})           // url -> {nome, itens: [...], erro, quando}
    property var noticias: []            // [{id, titulo, link, resumo, data, fonte, novo}]
    property var conhecidos: ({})        // ids já vistos nesta sessão (para "nova")
    property bool primeiraCarga: true
    property int lendo: 0
    property int pulso: 0                // muda quando chegam notícias novas (cintilação)
    property var lidas: { try { const a = JSON.parse(cfg.lidas || "[]"); return Array.isArray(a) ? a : [] } catch (e) { return [] } }
    readonly property var lidasSet: { const s = {}; for (const x of lidas) s[x] = true; return s }
    readonly property int naoLidas: noticias.filter(n => !lidasSet[n.id]).length
    readonly property int feedsComErro: Object.keys(porFeed).filter(u => porFeed[u].erro).length

    // ---- leitura dos feeds
    function atualizar() {
        for (const url of feeds) buscar(url)
    }
    Timer {
        interval: Math.max(5, raiz.cfg.intervaloMin) * 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: raiz.atualizar()
    }
    Connections { target: raiz.cfg; function onFeedsChanged() { raiz.porFeed = ({}); raiz.atualizar() } }

    function buscar(url) {
        const x = new XMLHttpRequest()
        lendo++
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            raiz.lendo = Math.max(0, raiz.lendo - 1)
            if (raiz.feeds.indexOf(url) < 0) return           // a lista mudou enquanto lia
            const p = Object.assign({}, raiz.porFeed)
            const ok = (x.status === 200 || (x.status === 0 && url.startsWith("file:"))) && x.responseText
            if (ok) {
                try {
                    const r = raiz.ler(String(x.responseText), url)
                    p[url] = { nome: r.nome, itens: r.itens, erro: r.itens.length ? "" : raiz.t("sem notícias", "no stories"), quando: Date.now() }
                } catch (e) {
                    p[url] = { nome: raiz.hostDe(url), itens: (p[url] || {}).itens || [], erro: raiz.t("feed ilegível", "unreadable feed") }
                }
            } else {
                p[url] = { nome: (p[url] || {}).nome || raiz.hostDe(url), itens: (p[url] || {}).itens || [],
                           erro: x.status ? "HTTP " + x.status : raiz.t("sem conexão", "offline") }
            }
            raiz.porFeed = p
            raiz.juntar()
        }
        x.open("GET", url)
        x.send()
    }

    // ---- RSS 2.0 / RSS 1.0 (RDF) / Atom, sem depender de DOM
    function decodificar(s) {
        return String(s || "").replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
            .replace(/&#x([0-9a-f]+);/gi, (m, h) => { try { return String.fromCodePoint(parseInt(h, 16)) } catch (e) { return "" } })
            .replace(/&#(\d+);/g, (m, d) => { try { return String.fromCodePoint(parseInt(d, 10)) } catch (e) { return "" } })
            .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
    }
    function texto(s) {
        // decodifica, tira o HTML (que pode vir escapado) e junta os espaços
        let t = decodificar(s).replace(/<(script|style)[\s\S]*?<\/\1>/gi, " ").replace(/<[^>]*>/g, " ")
        t = decodificar(t).replace(/<[^>]*>/g, " ")
        return t.replace(/\s+/g, " ").trim()
    }
    function tag(bloco, nome) {
        const m = bloco.match(new RegExp("<" + nome + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + nome + ">", "i"))
        return m ? m[1] : ""
    }
    function hostDe(url) { const m = String(url).match(/^\w+:\/\/(?:www\.|feeds\.)?([^/]+)/); return m ? m[1] : url }
    function nomeFonte(bruto, url) {
        let n = texto(bruto).split(/\s+[-–|:]\s+/)[0].replace(/\s*>\s*/g, " › ").trim()
        if (!n) n = hostDe(url)
        return n.length > 22 ? n.slice(0, 21) + "…" : n
    }
    function ler(xml, url) {
        const atom = /<feed[\s>]/i.test(xml.slice(0, 2000)) && !/<rss[\s>]/i.test(xml.slice(0, 2000))
        const blocos = xml.match(atom ? /<entry[\s>][\s\S]*?<\/entry>/gi : /<item[\s>][\s\S]*?<\/item>/gi) || []
        const cabeca = xml.split(atom ? /<entry[\s>]/i : /<item[\s>]/i)[0]
        const nome = nomeFonte(tag(cabeca, "title"), url)
        const itens = []
        for (const b of blocos.slice(0, 30)) {
            const titulo = texto(tag(b, "title"))
            let link = ""
            if (atom) {
                const ls = b.match(/<link\b[^>]*>/gi) || []
                const alt = ls.find(l => /rel=["']alternate["']/i.test(l)) || ls.find(l => !/rel=/i.test(l)) || ls[0] || ""
                const h = alt.match(/href=["']([^"']+)["']/i)
                link = h ? decodificar(h[1]) : ""
            } else {
                link = texto(tag(b, "link")) || texto(tag(b, "guid"))
            }
            const quando = Date.parse(texto(tag(b, "pubDate") || tag(b, "dc:date") || tag(b, "published") || tag(b, "updated")))
            let resumo = texto(tag(b, "description") || tag(b, "summary") || tag(b, "content:encoded") || tag(b, "content"))
            if (resumo.length > 260) resumo = resumo.slice(0, 257).replace(/\s+\S*$/, "") + "…"
            if (!titulo) continue
            itens.push({ id: link || titulo, titulo: titulo, link: link, resumo: resumo, data: isFinite(quando) ? quando : 0, fonte: nome })
        }
        return { nome: nome, itens: itens }
    }

    function juntar() {
        let todas = []
        for (const url of feeds) if (porFeed[url]) todas = todas.concat(porFeed[url].itens)
        const vistos = {}
        todas = todas.filter(n => vistos[n.id] ? false : (vistos[n.id] = true))
        todas.sort((a, b) => b.data - a.data)
        todas = todas.slice(0, maxNoticias)
        const c = Object.assign({}, conhecidos)
        let chegaram = 0
        for (const n of todas) {
            n.novo = !primeiraCarga && !c[n.id]
            if (n.novo) chegaram++
            c[n.id] = true
        }
        conhecidos = c
        noticias = todas
        if (lendo === 0) primeiraCarga = false
        if (chegaram > 0) pulso++
    }

    // ---- lidas
    function marcarLida(id) {
        if (!id || lidasSet[id]) return
        const a = lidas.concat([id])
        cfg.lidas = JSON.stringify(a.slice(Math.max(0, a.length - 400)))
    }
    function marcarTodas() {
        const a = lidas.concat(noticias.filter(n => !lidasSet[n.id]).map(n => n.id))
        cfg.lidas = JSON.stringify(a.slice(Math.max(0, a.length - 400)))
    }
    function abrir(n) {
        if (n && /^https?:\/\//i.test(n.link)) Qt.openUrlExternally(n.link)
        if (n) marcarLida(n.id)
    }

    function hora(ms) {
        if (!ms) return "--:--"
        const d = new Date(ms), hoje = new Date()
        const hh = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
        if (d.toDateString() === hoje.toDateString()) return hh
        return String(d.getDate()).padStart(2, "0") + "/" + String(d.getMonth() + 1).padStart(2, "0") + " " + hh
    }
    readonly property string estadoTexto: feeds.length === 0 ? t("NENHUM FEED", "NO FEEDS")
        : (lendo > 0 && noticias.length === 0 ? t("SINTONIZANDO", "TUNING IN")
        : feeds.length + (feeds.length === 1 ? t(" FONTE", " SOURCE") : t(" FONTES", " SOURCES"))
          + " · " + naoLidas + t(" NÃO LIDAS", " UNREAD") + (feedsComErro ? " · ▲" + feedsComErro : ""))

    toolTipMainText: t("Notícias", "News")
    toolTipSubText: noticias.length ? noticias[0].fonte + ": " + noticias[0].titulo : estadoTexto

    // ---- tamanho na área de trabalho (não mexa): livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // ---- P: ticker
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            id: cartao
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 6
                Row {
                    width: parent.width
                    spacing: 6
                    Rectangle {  // "AO VIVO": acende ao chegar notícia
                        id: aoVivo
                        anchors.verticalCenter: parent.verticalCenter
                        width: lv.implicitWidth + 8; height: 13
                        color: Cores.destaque
                        Codigo { id: lv; anchors.centerIn: parent; text: raiz.t("AO VIVO", "LIVE"); tamanho: 7; font.bold: true; color: Cores.fundo }
                        Cintilar { alvo: aoVivo; pulso: raiz.pulso }
                    }
                    Codigo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - aoVivo.width - 6
                        text: "NEWS.FEED // " + raiz.estadoTexto
                        tamanho: 8; color: Cores.texto2; elide: Text.ElideRight
                    }
                }
                Ticker {
                    width: parent.width
                    height: 22
                    noticias: raiz.noticias
                    lidas: raiz.lidasSet
                    en: raiz.en
                    onAbrir: (n) => raiz.abrir(n)
                }
                Codigo {
                    width: parent.width
                    visible: raiz.noticias.length > 0
                    text: raiz.noticias.length ? "▸ " + raiz.noticias[0].fonte.toUpperCase() + " · " + raiz.hora(raiz.noticias[0].data) : ""
                    tamanho: 8; color: Cores.texto3; elide: Text.ElideRight
                }
            }
        }
    }

    // ---- barra (painel)
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linhaC.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Row {
                id: linhaC
                anchors.centerIn: parent
                spacing: 4
                Kirigami.Icon { source: "application-rss+xml"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter; color: Cores.texto; isMask: true }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(raiz.naoLidas)
                    font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                    color: raiz.naoLidas ? Cores.destaque : Cores.texto2
                }
            }
        }
    }

    // ---- M (manchetes) e G (manchetes com resumo), pelo tamanho real
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("Notícias", "News")
            codigo: "NEWS.FEED // " + raiz.estadoTexto
            readonly property bool comResumo: area.height >= 300 && area.width >= 300
            extra: [
                Row {
                    spacing: 4
                    BotaoIcone {
                        visible: raiz.naoLidas > 0
                        glifo: "✓"; tamanho: 20
                        dica: raiz.t("Marcar todas como lidas", "Mark all as read")
                        onClicado: raiz.marcarTodas()
                    }
                    BotaoIcone {
                        icone: "view-refresh"; tamanho: 20
                        dica: raiz.t("Atualizar agora", "Refresh now")
                        onClicado: raiz.atualizar()
                    }
                }
            ]
            Leitura {
                anchors.centerIn: parent
                width: parent.width - 20
                visible: raiz.noticias.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                tamanho: 12
                color: raiz.feedsComErro && raiz.lendo === 0 ? Cores.alerta : Cores.texto2
                text: raiz.feeds.length === 0 ? raiz.t("Nenhum feed. Escolha os endereços na configuração.", "No feeds. Choose the addresses in the settings.")
                    : raiz.lendo > 0 ? raiz.t("Sintonizando os feeds…", "Tuning in to the feeds…")
                    : raiz.t("Nenhuma notícia: os feeds não responderam.", "No stories: the feeds did not answer.")
            }
            ListView {
                id: lista
                anchors.fill: parent
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: raiz.noticias
                delegate: Manchete {
                    width: lista.width
                    n: modelData
                    lida: raiz.lidasSet[modelData.id] === true
                    comResumo: mold.comResumo
                    hora: raiz.hora(modelData.data)
                    onAbrir: raiz.abrir(modelData)
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        limiteCartao: Qt.size(250, 150)
        tamanhoPequeno: Qt.size(320, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 19, Kirigami.Units.gridUnit * 16)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 22, Kirigami.Units.gridUnit * 26)
    }
}
