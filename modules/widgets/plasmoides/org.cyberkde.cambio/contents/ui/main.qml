import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Câmbio ("EDDIES EXCHANGE"): cotações reais no visual da moeda do jogo. Valor, variação do
// dia e gráfico de 7/30 dias, pela AwesomeAPI (gratuita, sem chave: /json/last e /json/daily). As
// últimas cotações ficam em "cache" (config do applet): sem rede, o widget mostra a última leitura com
// o aviso "SEM SINAL".
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- moedas: "USD-BRL, EUR, btc-usd" -> ["USD-BRL", "EUR-BRL", "BTC-USD"] (até 8, sem repetir)
    readonly property var pares: {
        const r = []
        for (let s of String(cfg.moedas || "").split(/[\s,;|]+/)) {
            s = s.trim().toUpperCase().replace("/", "-")
            if (!/^[A-Z0-9]{2,6}(-[A-Z0-9]{2,6})?$/.test(s)) continue
            if (s.indexOf("-") < 0) s += "-BRL"
            if (r.indexOf(s) < 0 && r.length < 8) r.push(s)
        }
        return r.length ? r : ["USD-BRL"]
    }
    readonly property string principal: pares[0]
    readonly property string parGrafico: pares.indexOf(cfg.grafico) >= 0 ? cfg.grafico : principal
    readonly property int dias: cfg.periodo === "7" ? 7 : 30

    // ---- dados
    property var cotas: ({})          // par -> { par, de, para, nome, valor, pct, varia, maxima, minima }
    property var hist: ({})           // par -> [valores de fechamento, do mais antigo ao mais novo] (30 dias)
    property var histQuando: ({})     // par -> Date.now() da última busca do histórico
    property bool semSinal: false
    property bool carregando: false
    property date atualizado: new Date(0)
    readonly property bool temDados: Object.keys(cotas).length > 0

    // última leitura guardada: o widget abre já com números, e mostra algo sem rede
    Component.onCompleted: {
        if (cfg.modo !== modo) cfg.modo = modo
        try {
            const c = JSON.parse(cfg.cache || "{}")
            if (c.cotas) cotas = c.cotas
            if (c.hist) hist = c.hist
            if (c.quando) atualizado = new Date(c.quando)
        } catch (e) {}
        Qt.callLater(raiz.buscar)
    }
    function guardar() {
        cfg.cache = JSON.stringify({ cotas: cotas, hist: hist, quando: atualizado.getTime() })
    }

    function pedir(url, feito) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let j = null
            if (xhr.status === 200) { try { j = JSON.parse(xhr.responseText) } catch (e) {} }
            feito(xhr.status, j)
        }
        xhr.open("GET", url)
        xhr.send()
    }
    function lerCota(par, o) {
        const [de, para] = par.split("-")
        return { par: par, de: de, para: para, nome: String(o.name || "").split("/")[0],
                 valor: parseFloat(o.bid), pct: parseFloat(o.pctChange) || 0, varia: parseFloat(o.varBid) || 0,
                 maxima: parseFloat(o.high), minima: parseFloat(o.low) }
    }
    function buscar() {
        if (carregando) return
        carregando = true
        const lista = pares.slice()
        pedir("https://economia.awesomeapi.com.br/json/last/" + lista.join(","), function(st, j) {
            carregando = false
            if (st === 200 && j) { aplicar(lista, j); return }
            // um par inexistente derruba o pedido inteiro (404): pede um por um
            if (st >= 400 && st < 500 && lista.length > 1) {
                let faltam = lista.length, achou = {}
                for (const p of lista)
                    pedir("https://economia.awesomeapi.com.br/json/last/" + p, function(s2, j2) {
                        if (s2 === 200 && j2) Object.assign(achou, j2)
                        if (--faltam === 0) aplicar(lista, achou, Object.keys(achou).length === 0)
                    })
                return
            }
            semSinal = true
            nova.interval = 120000; nova.restart()       // tenta de novo em 2 min
        })
    }
    function aplicar(lista, j, falhou) {
        if (falhou) { semSinal = true; nova.interval = 120000; nova.restart(); return }
        const c = {}
        for (const p of lista) {
            const o = j[p.replace("-", "")]
            if (o && isFinite(parseFloat(o.bid))) c[p] = lerCota(p, o)
        }
        cotas = c
        semSinal = false
        atualizado = new Date()
        nova.interval = Math.max(5, cfg.intervaloMin) * 60000; nova.restart()
        historicos()
        guardar()
    }
    // histórico diário: no máximo uma vez por hora por par
    function historicos() {
        const agora = Date.now()
        for (const p of pares) {
            if (hist[p] && hist[p].length && agora - (histQuando[p] || 0) < 3600000) continue
            const par = p
            pedir("https://economia.awesomeapi.com.br/json/daily/" + par + "/30", function(st, j) {
                if (st !== 200 || !Array.isArray(j)) return
                const v = j.map(x => parseFloat(x.bid)).filter(x => isFinite(x)).reverse()
                const h = Object.assign({}, hist); h[par] = v; hist = h
                const q = Object.assign({}, histQuando); q[par] = Date.now(); histQuando = q
                guardar()
            })
        }
    }
    Timer {
        id: nova
        interval: Math.max(5, raiz.cfg.intervaloMin) * 60000
        running: true; repeat: false       // sem triggeredOnStart: cada restart() dispararia na hora, em laço com a resposta
        onTriggered: raiz.buscar()
    }
    Connections {
        target: raiz.cfg
        function onMoedasChanged() { atraso.restart() }
        function onIntervaloMinChanged() { nova.interval = Math.max(5, raiz.cfg.intervaloMin) * 60000; nova.restart(); raiz.buscar() }
    }
    Timer { id: atraso; interval: 800; onTriggered: raiz.buscar() }

    // ---- formatação
    readonly property var simbolos: ({ BRL: "R$", USD: "$", EUR: "€", GBP: "£", JPY: "¥", CNY: "¥", BTC: "₿",
                                       ETH: "Ξ", ARS: "$", CAD: "$", AUD: "$", CHF: "Fr", LTC: "Ł", XRP: "✕" })
    function simbolo(m) { return simbolos[m] || m.slice(0, 3) }
    function fmt(v, para) {
        if (!isFinite(v)) return "--"
        const casas = v >= 1000 ? 0 : v >= 10 ? 2 : v >= 0.1 ? 4 : 6
        return (simbolos[para] || para) + " " + Number(v).toLocaleString(Qt.locale(), "f", casas)
    }
    function fmtPct(p) { return (p >= 0 ? "+" : "") + Number(p).toLocaleString(Qt.locale(), "f", 2) + "%" }
    function hora(d) { return d.getTime() > 0 ? d.toLocaleTimeString(Qt.locale(), "HH:mm") : "--:--" }
    function serie(p, n) { const h = hist[p] || []; return h.slice(Math.max(0, h.length - n)) }
    readonly property var cotaPrincipal: cotas[principal] || null

    toolTipMainText: "EDDIES EXCHANGE"
    toolTipSubText: cotaPrincipal ? principal.replace("-", "/") + " " + fmt(cotaPrincipal.valor, cotaPrincipal.para) + " (" + fmtPct(cotaPrincipal.pct) + ")"
                                    + (semSinal ? t(" · sem sinal", " · no signal") : "")
                                  : t("Sem sinal", "No signal")

    // ---- tamanho na área de trabalho (padrão dos widgets do tema)
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // aviso "SEM SINAL" (pisca 3 vezes ao perder a rede e fica aceso)
    component AvisoSinal: Item {
        visible: raiz.semSinal
        width: av.implicitWidth + 12; height: 16
        Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.alerta, 0.15); border.color: Cores.alerta }
        Codigo { id: av; anchors.centerIn: parent; text: raiz.t("▲ SEM SINAL", "▲ NO SIGNAL"); color: Cores.alerta; tamanho: 9; font.bold: true }
        SequentialAnimation on opacity {
            running: raiz.semSinal && !Cores.reduzir
            loops: 3
            NumberAnimation { to: 0.2; duration: 120 }
            NumberAnimation { to: 1; duration: 120 }
        }
    }

    // ---- P: a moeda principal
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            id: car
            opacidade: raiz.opac
            readonly property var c: raiz.cotaPrincipal
            Eddie {
                id: emb
                height: Math.min(parent.height, 58); width: height
                anchors.verticalCenter: parent.verticalCenter
                apagado: raiz.semSinal
            }
            Column {
                x: emb.width + 10
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Codigo {
                    width: parent.width
                    text: raiz.semSinal ? raiz.t("EDDIES // ▲ SEM SINAL", "EDDIES // ▲ NO SIGNAL") : "EDDIES // " + raiz.principal.replace("-", "/")
                    color: raiz.semSinal ? Cores.alerta : Cores.destaque; tamanho: 8; font.bold: true
                }
                NumeroCintilante {
                    width: parent.width
                    valor: car.c ? raiz.fmt(car.c.valor, car.c.para) : "--"
                    intervaloMin: 4000
                    font.family: Cores.fIdentidade; font.weight: Font.Bold
                    font.pixelSize: Math.max(14, Math.min(24, car.height * 0.26))
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11
                    color: raiz.semSinal ? Cores.texto2 : Cores.texto
                }
                Text {
                    text: car.c ? (car.c.pct >= 0 ? "▲ " : "▼ ") + raiz.fmtPct(car.c.pct) + raiz.t(" hoje", " today") : raiz.t("aguardando sinal…", "waiting for signal…")
                    font.family: Cores.fMono; font.pixelSize: 10; font.bold: true
                    color: !car.c ? Cores.texto3 : car.c.pct >= 0 ? Cores.secundaria : Cores.alerta
                }
            }
        }
    }

    // ---- barra: €$ e o valor da principal
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linhaC.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Row {
                id: linhaC
                anchors.centerIn: parent
                spacing: 4
                Eddie { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; apagado: raiz.semSinal }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: raiz.cotaPrincipal ? Number(raiz.cotaPrincipal.valor).toLocaleString(Qt.locale(), "f", raiz.cotaPrincipal.valor >= 1000 ? 0 : 2) : "--"
                    font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                    color: raiz.semSinal ? Cores.texto3 : raiz.cotaPrincipal && raiz.cotaPrincipal.pct < 0 ? Cores.alerta : Cores.texto
                }
            }
        }
    }

    // ---- M: lista; G: lista + gráfico (pelo tamanho real)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: "Eddies Exchange"
            codigo: (raiz.semSinal ? raiz.t("SEM SINAL // ÚLTIMA ", "NO SIGNAL // LAST ") : "EDDY.XCHG // ") + raiz.hora(raiz.atualizado)
            readonly property real h: area.height
            readonly property int alturaLinha: 36
            readonly property bool cabeGrafico: h - raiz.pares.length * alturaLinha >= 104
            readonly property int linhasVisiveis: Math.max(1, Math.floor((cabeGrafico ? h - 104 : h) / alturaLinha))
            extra: [
                AvisoSinal {},
                BotaoIcone { visible: mold.cabeGrafico; tamanho: 18; glifo: "7"; ativo: raiz.dias === 7; dica: raiz.t("7 dias", "7 days"); onClicado: raiz.cfg.periodo = "7" },
                BotaoIcone { visible: mold.cabeGrafico; tamanho: 18; glifo: "30"; ativo: raiz.dias === 30; dica: raiz.t("30 dias", "30 days"); onClicado: raiz.cfg.periodo = "30" }
            ]

            Column {
                id: lista
                width: parent.width
                clip: true
                Repeater {
                    model: raiz.pares.slice(0, mold.linhasVisiveis)
                    LinhaMoeda {
                        required property string modelData
                        width: lista.width
                        height: mold.alturaLinha
                        cota: raiz.cotas[modelData] || null
                        par: modelData
                        carregado: raiz.temDados
                        simbolo: raiz.simbolo(modelData.split("-")[0])
                        serie: raiz.serie(modelData, 7)
                        mini: lista.width >= 300
                        escolhida: mold.cabeGrafico && modelData === raiz.parGrafico
                        clicavel: mold.cabeGrafico
                        semSinal: raiz.semSinal
                        fmt: raiz.fmt
                        fmtPct: raiz.fmtPct
                        onEscolher: raiz.cfg.grafico = modelData
                    }
                }
            }

            // médio com folga: máxima e mínima do dia da principal, e a fonte
            Column {
                visible: !mold.cabeGrafico && mold.h - lista.height >= 44
                y: lista.y + lista.height + 8
                width: parent.width
                spacing: 2
                readonly property var c: raiz.cotaPrincipal
                Codigo {
                    width: parent.width
                    text: parent.c ? raiz.principal.replace("-", "/") + raiz.t(" // DIA  MÁX ", " // DAY  HIGH ") + raiz.fmt(parent.c.maxima, parent.c.para)
                                     + raiz.t("  MÍN ", "  LOW ") + raiz.fmt(parent.c.minima, parent.c.para) : ""
                    tamanho: 9; color: Cores.texto2
                }
                Codigo {
                    width: parent.width
                    text: raiz.t("FONTE AWESOMEAPI // A CADA ", "SOURCE AWESOMEAPI // EVERY ") + Math.max(5, raiz.cfg.intervaloMin) + " MIN"
                    tamanho: 8
                }
            }

            // gráfico do par escolhido
            Item {
                visible: mold.cabeGrafico
                y: lista.y + lista.height + 10
                width: parent.width
                height: parent.height - y
                readonly property var s: raiz.serie(raiz.parGrafico, raiz.dias)
                readonly property real lo: s.length ? Math.min(...s) : 0
                readonly property real hi: s.length ? Math.max(...s) : 1
                readonly property var cg: raiz.cotas[raiz.parGrafico] || null
                Row {
                    id: leg
                    width: parent.width
                    spacing: 10
                    Codigo { text: raiz.parGrafico.replace("-", "/") + " // " + raiz.dias + "D"; color: Cores.destaque; tamanho: 9; font.bold: true }
                    Codigo {
                        visible: parent.parent.s.length > 1
                        readonly property var g: parent.parent
                        text: "MIN " + raiz.fmt(g.lo, g.cg ? g.cg.para : "") + "   MAX " + raiz.fmt(g.hi, g.cg ? g.cg.para : "")
                        tamanho: 9; color: Cores.texto2
                    }
                }
                GraficoHud {
                    y: leg.height + 4
                    width: parent.width
                    height: parent.height - y
                    readonly property var g: parent
                    series: g.s.length > 1 ? [{ valores: g.s.map(v => v - g.lo + (g.hi - g.lo) * 0.08 + 1e-9),
                                                cor: g.s[g.s.length - 1] >= g.s[0] ? Cores.secundaria : Cores.alerta }] : []
                }
                Codigo {
                    visible: parent.s.length < 2
                    anchors.centerIn: parent
                    text: raiz.semSinal ? raiz.t("SEM SINAL", "NO SIGNAL") : raiz.t("CARREGANDO HISTÓRICO…", "LOADING HISTORY…")
                    color: raiz.semSinal ? Cores.alerta : Cores.texto3
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
        limiteCartao: Qt.size(250, 130)
        tamanhoPequeno: Qt.size(240, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 18, Kirigami.Units.gridUnit * 11)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 21, Kirigami.Units.gridUnit * 20)
    }
}
