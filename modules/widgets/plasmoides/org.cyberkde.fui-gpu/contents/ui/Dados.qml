import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import "comum"

// Todos os dados do Painel FUI e dos módulos avulsos (org.cyberkde.fui-*), só leitura:
//   ksystemstats (CPU, núcleos, temperaturas, GPU, memória, rede, discos), contents/code/coleta.sh (df, ps,
//   journal, estados, sistema, atualizações, ping) e Open-Meteo (clima).
// "partes" diz o que coletar (vazio = tudo): cpu, nucleos, temp, gpu, memoria, rede, discos, es, processos,
// log, estado, ping, sistema, atualizacoes, clima. Sensor, comando e timer de parte não pedida ficam parados.
Item {
    id: dd
    property var cfg
    property var partes: []
    function quer(x) { return partes.length === 0 || partes.indexOf(x) >= 0 }
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    readonly property int intervalo: Math.max(500, cfg.intervalo || 1500)
    readonly property real limiar: Math.max(0.5, Math.min(0.99, (cfg.limiar || 85) / 100))
    readonly property var ocultos: (String(cfg.ocultos || "") + "," + String(cfg.ocultosLayout || "")).toLowerCase().split(/[\s,;]+/).filter(x => x)
    function oculto(id) { return ocultos.indexOf(id) >= 0 }

    // ---------------------------------------------------------------- formatação (com a vírgula do idioma)
    function dec(v, c) { return Number(v).toLocaleString(Qt.locale(), "f", c) }
    function bytes(b) {
        if (!(b > 0)) return "0 B"
        const u = ["B", "KiB", "MiB", "GiB", "TiB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return dec(b, b >= 100 || i === 0 ? 0 : 1) + " " + u[i]
    }
    function taxa(b) {
        if (!(b > 0)) return "0 B/s"
        const u = ["B/s", "kB/s", "MB/s", "GB/s"]
        let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i === 0 ? Math.round(b) : dec(b, b < 10 ? 1 : 0)) + " " + u[i]
    }
    function nivel(bps) { return bps > 0 ? Math.max(0, Math.min(1, Math.log(1 + bps / 1000) / Math.log(1 + 100000))) : 0 }
    function duracao(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "min" : m + " min"
    }

    // ---------------------------------------------------------------- sensores
    component S: Sensors.Sensor { updateRateLimit: dd.intervalo }
    S { id: sCpu; sensorId: dd.quer("cpu") || dd.quer("nucleos") ? "cpu/all/usage" : "" }
    S { id: sNucleos; sensorId: "cpu/all/coreCount"; updateRateLimit: 60000 }
    S { id: sCpuTemp; sensorId: dd.quer("cpu") || dd.quer("temp") ? "cpu/all/maximumTemperature" : "" }
    S { id: sMem; sensorId: dd.quer("memoria") || dd.quer("temp") ? "memory/physical/used" : "" }
    S { id: sMemTotal; sensorId: dd.quer("memoria") || dd.quer("temp") ? "memory/physical/total" : ""; updateRateLimit: 60000 }
    S { id: sCache; sensorId: dd.quer("memoria") ? "memory/physical/cache" : "" }
    S { id: sBuffer; sensorId: dd.quer("memoria") ? "memory/physical/buffer" : "" }
    S { id: sSwap; sensorId: dd.quer("memoria") || dd.quer("temp") ? "memory/swap/used" : "" }
    S { id: sSwapTotal; sensorId: dd.quer("memoria") || dd.quer("temp") ? "memory/swap/total" : ""; updateRateLimit: 60000 }
    S { id: sDesce; sensorId: dd.quer("rede") || dd.quer("temp") ? "network/all/download" : "" }
    S { id: sSobe; sensorId: dd.quer("rede") || dd.quer("temp") ? "network/all/upload" : "" }
    S { id: sLeitura; sensorId: dd.quer("es") ? "disk/all/read" : "" }
    S { id: sEscrita; sensorId: dd.quer("es") ? "disk/all/write" : "" }
    S { id: sUptime; sensorId: dd.quer("sistema") || dd.quer("hora") ? "os/system/uptime" : ""; updateRateLimit: 60000 }

    readonly property int nCores: Math.max(1, sNucleos.value || 1)
    property var _nuc: []
    Instantiator {
        model: dd.quer("nucleos") ? dd.nCores : 0
        delegate: S { required property int index; sensorId: "cpu/cpu" + index + "/usage" }
        onObjectAdded: (i, o) => { const a = dd._nuc.slice(); a[i] = o; dd._nuc = a }
    }
    // GPU: a primeira gpuN com nome de placa dedicada
    readonly property bool querGpu: quer("gpu") || quer("temp") || quer("estado")
    property string gpuId: ""
    property var _gpuNomes: ({})
    Instantiator {
        model: dd.querGpu ? 4 : 0
        delegate: S {
            required property int index
            sensorId: "gpu/gpu" + index + "/name"; updateRateLimit: 60000
            onValueChanged: { const m = Object.assign({}, dd._gpuNomes); m[index] = String(value || ""); dd._gpuNomes = m; dd.escolherGpu() }
        }
    }
    function escolherGpu() {
        let melhor = ""
        for (let i = 0; i < 4; i++) {
            const v = _gpuNomes[i] || ""
            if (!v) continue
            if (/nvidia|geforce|radeon|amd|arc/i.test(v)) { melhor = "gpu" + i; break }
            if (!melhor) melhor = "gpu" + i
        }
        gpuId = melhor
    }
    readonly property string gpuNome: gpuId ? String(_gpuNomes[parseInt(gpuId.slice(3))] || "").replace(/^NVIDIA\s+/i, "").replace(/^GeForce\s+/i, "") : ""
    S { id: sGpuTemp; sensorId: dd.querGpu && dd.gpuId ? "gpu/" + dd.gpuId + "/temperature" : "" }
    S { id: sGpuUso; sensorId: dd.querGpu && dd.gpuId ? "gpu/" + dd.gpuId + "/usage" : "" }
    S { id: sGpuVram; sensorId: dd.querGpu && dd.gpuId ? "gpu/" + dd.gpuId + "/usedVram" : "" }
    S { id: sGpuVramTotal; sensorId: dd.querGpu && dd.gpuId ? "gpu/" + dd.gpuId + "/totalVram" : ""; updateRateLimit: 60000 }
    S { id: sGpuEnergia; sensorId: dd.querGpu && dd.gpuId ? "gpu/" + dd.gpuId + "/power" : "" }
    readonly property bool temGpu: gpuId !== "" && sGpuTemp.value > 0

    // ---------------------------------------------------------------- valores
    property int tique: 0
    readonly property real cpu: sCpu.value || 0
    readonly property real cpuTemp: sCpuTemp.value || 0
    readonly property string cpuTempTxt: cpuTemp > 0 ? Math.round(cpuTemp) + " °C" : "-- °C"
    property var bandas: [0, 0, 0, 0, 0, 0]
    property int bandaMax: 0
    // rótulos dos grupos: C0-1 … C10-11 (núcleos lógicos de cada grupo)
    readonly property var bandasRot: {
        const r = []
        for (let g = 0; g < 6; g++) {
            const a = Math.floor(g * nCores / 6), z = Math.max(a + 1, Math.floor((g + 1) * nCores / 6))
            r.push(z - 1 > a ? "C" + a + "-" + (z - 1) : "C" + a)
        }
        return r
    }
    function lerBandas() {
        const n = nCores, b = []
        for (let g = 0; g < 6; g++) {
            const a = Math.floor(g * n / 6), z = Math.max(a + 1, Math.floor((g + 1) * n / 6))
            let s = 0, c = 0
            for (let i = a; i < z && i < n; i++) { const o = _nuc[i]; if (o) { s += o.value || 0; c++ } }
            b.push(c ? s / c : 0)
        }
        bandas = b
    }
    Timer { interval: dd.intervalo; running: dd.quer("nucleos"); repeat: true; triggeredOnStart: true; onTriggered: dd.lerBandas() }
    // o destaque vai para o grupo mais carregado no máximo a cada 2,5 s e só com folga de 5 pontos
    Timer {
        interval: 2500; running: dd.quer("nucleos"); repeat: true
        onTriggered: {
            const b = dd.bandas
            let m = 0
            for (let g = 1; g < 6; g++) if (b[g] > b[m]) m = g
            if (b[m] > (b[dd.bandaMax] || 0) + 5) dd.bandaMax = m
        }
    }
    readonly property real fRam: sMemTotal.value > 0 ? sMem.value / sMemTotal.value : 0
    readonly property real fSwap: sSwapTotal.value > 0 ? sSwap.value / sSwapTotal.value : 0
    readonly property real fTotal: (sMemTotal.value + sSwapTotal.value) > 0 ? (sMem.value + sSwap.value) / (sMemTotal.value + sSwapTotal.value) : 0
    readonly property real memUsada: sMem.value || 0
    readonly property real memTotal: sMemTotal.value || 0
    readonly property real swapUsada: sSwap.value || 0
    readonly property real swapTotal: sSwapTotal.value || 0
    readonly property real memCache: sCache.value || 0
    readonly property real memBuffer: sBuffer.value || 0
    readonly property real desce: sDesce.value || 0
    readonly property real sobe: sSobe.value || 0
    readonly property real nivelRede: nivel(desce + sobe)
    readonly property real esLeitura: sLeitura.value || 0
    readonly property real esEscrita: sEscrita.value || 0
    readonly property real nivelDisco: nivel(esLeitura + esEscrita)
    readonly property real gpuUso: sGpuUso.value || 0
    readonly property real gpuTemp: sGpuTemp.value || 0
    readonly property real gpuEnergia: sGpuEnergia.value || 0
    readonly property real vramUsada: sGpuVram.value || 0
    readonly property real vramTotal: sGpuVramTotal.value || 0
    readonly property real uptime: sUptime.value || sistema.uptime || 0
    property var hRede: []
    property var hDesce: []
    property var hSobe: []
    property var hCpu: []
    readonly property real raizFrac: { const u = discos.find(x => x.alvo === "/"); return u ? u.frac : 0 }
    // os 8 canais dos knobs: valor 0..1, número com unidade e nome
    readonly property var canais: [
        { nome: "CPU°", v: cpuTemp / 100, num: cpuTemp > 0 ? Math.round(cpuTemp) + "°C" : "--", alerta: cpuTemp >= 85 },
        { nome: "GPU°", v: gpuTemp / 100, num: gpuTemp > 0 ? Math.round(gpuTemp) + "°C" : "--", alerta: gpuTemp >= 85 },
        { nome: "GPU%", v: gpuUso / 100, num: gpuId ? Math.round(gpuUso) + "%" : "--", alerta: gpuUso >= limiar * 100 },
        { nome: "VRAM", v: vramTotal > 0 ? vramUsada / vramTotal : 0, num: vramTotal > 0 ? Math.round(vramUsada / vramTotal * 100) + "%" : "--", alerta: false },
        { nome: "RAM", v: fRam, num: Math.round(fRam * 100) + "%", alerta: fRam >= limiar },
        { nome: "SWAP", v: fSwap, num: Math.round(fSwap * 100) + "%", alerta: fSwap >= limiar },
        { nome: "/", v: raizFrac, num: Math.round(raizFrac * 100) + "%", alerta: raizFrac >= limiar },
        { nome: "NET", v: nivelRede, num: Math.round(nivelRede * 100) + "%", alerta: false }]
    readonly property bool anelGpu: temGpu
    readonly property string anelExtra: anelGpu ? "VRAM " + bytes(vramUsada) + " / " + bytes(vramTotal) + (gpuEnergia > 0 ? " · " + Math.round(gpuEnergia) + " W" : "")
                                                : "RAM " + bytes(memUsada) + " / " + bytes(memTotal)
    readonly property real anelValor: anelGpu ? Math.min(1, gpuTemp / 100) : fRam
    readonly property real anelNumero: anelGpu ? gpuTemp : fRam * 100
    readonly property string anelUnidade: anelGpu ? "°C" : "%"

    function empurrar(a, v, n) { const b = a.length >= n ? a.slice(1) : a.slice(); b.push(v || 0); return b }
    Timer {
        interval: 2000; running: dd.quer("rede") || dd.quer("cpu") || dd.quer("es"); repeat: true
        onTriggered: {
            dd.tique++
            if (dd.quer("rede")) {
                dd.hRede = dd.empurrar(dd.hRede, dd.nivelRede, 13)
                dd.hDesce = dd.empurrar(dd.hDesce, dd.desce, 60)
                dd.hSobe = dd.empurrar(dd.hSobe, dd.sobe, 60)
            }
            if (dd.quer("cpu")) dd.hCpu = dd.empurrar(dd.hCpu, dd.cpu, 60)
            if (dd.quer("es")) dd.atualizarES()
        }
    }

    // ---------------------------------------------------------------- relógio
    property date agora: new Date()
    property int segundo: 0
    property int horaVista: -1
    readonly property string fuso: { const o = -agora.getTimezoneOffset() / 60; return (o >= 0 ? "+" : "-") + String(Math.abs(o)).padStart(2, "0") }
    signal horaCheia()
    Timer {
        interval: dd.quer("hora") ? 1000 : 60000   // o módulo de clima só mostra o dia da semana
        running: dd.quer("hora") || dd.quer("clima"); repeat: true; triggeredOnStart: true
        onTriggered: {
            dd.agora = new Date()
            dd.segundo = dd.agora.getSeconds()
            const h = dd.agora.getHours()
            if (dd.horaVista >= 0 && h !== dd.horaVista) dd.horaCheia()
            dd.horaVista = h
        }
    }

    // ---------------------------------------------------------------- coleta (só leitura)
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../code/coleta.sh").toString().replace(/^file:\/\//, ""))
    function cmd(parte, args) { return "sh '" + script.replace(/'/g, "'\\''") + "' " + parte + (args ? " " + args : "") }
    function aspas(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            const o = dados["stdout"] || ""
            const parte = fonte.split("' ")[1] ? fonte.split("' ")[1].split(" ")[0] : ""
            if (parte === "discos") dd.lerDiscos(o)
            else if (parte === "processos") dd.lerProcessos(o)
            else if (parte === "log") dd.lerLog(o)
            else if (parte === "estado") dd.lerEstado(o)
            else if (parte === "ping") dd.lerPing(o)
            else if (parte === "sistema") dd.lerSistema(o)
            else if (parte === "atualizacoes") dd.lerAtualizacoes(o)
            disconnectSource(fonte)
        }
    }
    function rodar(c) { exec.connectSource(c) }
    Timer { interval: 30000; running: dd.quer("discos") || dd.quer("es") || dd.quer("temp"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("discos")) }
    Timer { interval: 3000; running: dd.quer("processos"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("processos")) }
    Timer { interval: 20000; running: dd.quer("log"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("log", dd.logNivel)) }
    Timer { interval: 5000; running: dd.quer("estado") || dd.quer("ping"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("estado")) }
    Timer { interval: 30000; running: dd.quer("sistema"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("sistema")) }
    Timer { interval: 30 * 60000; running: dd.quer("atualizacoes"); repeat: true; triggeredOnStart: true; onTriggered: dd.rodar(dd.cmd("atualizacoes")) }
    readonly property int pingSeg: Math.max(15, cfg.pingSeg || 60)
    Timer { interval: dd.pingSeg * 1000; running: dd.quer("ping"); repeat: true; onTriggered: dd.sondar() }
    Timer { interval: 2500; running: dd.quer("ping"); onTriggered: dd.sondar() }     // a primeira, já com o gateway

    // discos (df) e E/S por disco físico
    property var discos: []
    function lerDiscos(s) {
        const r = []
        for (const l of s.split("\n")) {
            const c = l.split("\t")
            if (c.length < 6) continue
            const total = parseFloat(c[1]), usado = parseFloat(c[2]), livre = parseFloat(c[3])
            const alvo = c.slice(5).join("\t")
            if (!(total > 0)) continue
            r.push({ disp: c[0], total: total, usado: usado, livre: livre, pk: c[4], alvo: alvo,
                     frac: usado + livre > 0 ? usado / (usado + livre) : 0,
                     nome: alvo === "/" ? t("sistema", "system") : alvo === "/home" ? "home" : alvo.split("/").pop() })
        }
        discos = r
    }
    function abrir(u) { if (u) rodar("dolphin --new-window " + aspas(u.alvo)) }
    readonly property var fisicos: { const r = []; for (const u of discos) if (u.pk && !r.find(x => x.pk === u.pk) && r.length < 4) r.push({ pk: u.pk, alvo: u.alvo === "/" ? "/" : u.nome }); return r }
    property var _es: ({})
    Instantiator {
        model: dd.quer("es") ? dd.fisicos : []
        delegate: QtObject {
            required property var modelData
            property Sensors.Sensor rd: Sensors.Sensor { sensorId: "disk/" + modelData.pk + "/read"; updateRateLimit: 2000 }
            property Sensors.Sensor wr: Sensors.Sensor { sensorId: "disk/" + modelData.pk + "/write"; updateRateLimit: 2000 }
        }
        onObjectAdded: (i, o) => { const m = Object.assign({}, dd._es); m[o.modelData.pk] = o; dd._es = m }
    }
    property var es: []
    property real _esMax: 1e6
    function atualizarES() {
        const r = []
        let mx = _esMax * 0.97      // o teto desce devagar: a escala acompanha o que está acontecendo
        for (const f of fisicos) { const o = _es[f.pk]; if (o) mx = Math.max(mx, o.rd.value || 0, o.wr.value || 0) }
        _esMax = Math.max(1e6, mx)
        for (const f of fisicos) {
            const o = _es[f.pk]
            const rb = o ? o.rd.value || 0 : 0, wb = o ? o.wr.value || 0 : 0
            r.push({ pk: f.pk, alvo: f.alvo, rb: rb, wb: wb, r: rb / _esMax, w: wb / _esMax })
        }
        es = r
    }

    // processos
    property var procs: []
    function lerProcessos(s) {
        const r = []
        for (const l of s.split("\n")) {
            const c = l.split("\t")
            if (c.length < 4) continue
            r.push({ pid: c[0], cpu: parseFloat(c[1]) || 0, mem: parseFloat(c[2]) || 0, nome: c[3] })
        }
        procs = r
    }

    // journal do usuário (resumido)
    readonly property string logNivel: ["emerg", "alert", "crit", "err", "warning", "notice", "info"].indexOf(cfg.logNivel) >= 0 ? cfg.logNivel : "warning"
    property var logLinhas: []
    property real logNova: 1
    NumberAnimation { id: digitar; target: dd; property: "logNova"; from: 0; to: 1; duration: Cores.d(700) }
    function lerLog(s) {
        const r = []
        for (const l of s.split("\n")) {
            const c = l.split("\t")
            if (c.length < 3) continue
            r.push({ hora: c[0], origem: c[1].trim(), msg: c.slice(2).join(" ").trim() })
        }
        const ultima = logLinhas.length ? JSON.stringify(logLinhas[logLinhas.length - 1]) : ""
        logLinhas = r
        if (r.length && JSON.stringify(r[r.length - 1]) !== ultima && !Cores.reduzir) digitar.restart()
    }

    // estados: som, microfone, energia, interfaces, gateway
    property var hdr: ({ rede: false, som: 0, somMudo: false, mic: 0, micMudo: false, energia: "AC", lat: -1 })
    property string gateway: ""
    property var interfaces: []
    function lerEstado(s) {
        const h = Object.assign({}, hdr), ifs = []
        for (const l of s.split("\n")) {
            const c = l.split("\t")
            if (c.length < 2) continue
            if (c[0] === "som" || c[0] === "mic") {
                h[c[0]] = parseFloat(c[1]) || 0; h[c[0] + "Mudo"] = /MUTED/.test(c[1])
            } else if (c[0] === "energia") h.energia = c[1].trim().split(" ")[0] || "AC"
            else if (c[0] === "gateway") gateway = c[1].trim()
            else if (c[0] === "if") { const [n, st] = c[1].trim().split(" "); ifs.push({ nome: n, up: st === "up" }) }
        }
        h.rede = ifs.some(x => x.up)
        hdr = h
        interfaces = ifs
    }

    // rede: ping no gateway e nos alvos públicos (o script recusa endereço privado que não seja o gateway)
    readonly property var alvos: String(cfg.alvos || "").split(/[\s,;]+/).filter(x => /^[0-9.]+$/.test(x)).slice(0, 4)
    property var lat: ({})
    property int pulsoRede: 0
    function sondar() { rodar(cmd("ping", [gateway].concat(alvos).filter(x => x).join(" "))) }
    function lerPing(s) {
        const m = {}
        for (const l of s.split("\n")) { const c = l.split("\t"); if (c.length === 2) m[c[0]] = c[1] === "x" ? -1 : parseFloat(c[1]) }
        lat = m
        pulsoRede++
        const pub = alvos.map(a => m[a]).filter(v => v !== undefined && v >= 0)
        const h = Object.assign({}, hdr); h.lat = pub.length ? Math.min(...pub) : -1; hdr = h
    }
    readonly property bool gwOk: gateway !== "" && lat[gateway] !== undefined && lat[gateway] >= 0
    readonly property int alvosOk: alvos.filter(a => lat[a] !== undefined && lat[a] >= 0).length
    readonly property int alcance: !hdr.rede ? 0 : !gwOk ? 9 : 11 + (alvos.length ? Math.round(11 * alvosOk / alvos.length) : 0)
    function ms(v) { return v >= 0 ? (v < 10 ? dec(v, 1) : Math.round(v)) + " ms" : "--" }
    readonly property string redeLan: interfaces.filter(x => x.up).map(x => x.nome).join(" ") || t("sem link", "no link")
    readonly property string redeGw: gateway ? ms(gwOk ? lat[gateway] : -1) : "--"
    readonly property string redeNet: hdr.lat >= 0 ? ms(hdr.lat) : "--"                        // a melhor dos alvos
    readonly property string redeAlvos: alvos.map(a => a + " " + ms(lat[a] !== undefined ? lat[a] : -1)).join(" · ")

    // sistema: uptime, carga, kernel, Docker, falhas, baterias; atualizações
    property var sistema: ({ uptime: 0, carga: [0, 0, 0], kernel: "", docker: null, falhas: 0, baterias: [] })
    function lerSistema(s) {
        const r = { uptime: 0, carga: [0, 0, 0], kernel: "", docker: null, falhas: 0, baterias: [] }
        for (const l of s.split("\n")) {
            const c = l.split("\t")
            if (c[0] === "uptime") r.uptime = parseFloat(c[1]) || 0
            else if (c[0] === "carga") r.carga = c[1].split(" ").map(x => parseFloat(x) || 0)
            else if (c[0] === "kernel") r.kernel = c[1]
            else if (c[0] === "docker") { const [a, b] = c[1].split(" "); r.docker = { rodando: parseInt(a) || 0, total: parseInt(b) || 0 } }
            else if (c[0] === "falhas") r.falhas = parseInt(c[1]) || 0
            else if (c[0] === "bateria" && c.length >= 3) r.baterias.push({ nome: c[1], pct: parseInt(c[2]) || 0 })
        }
        sistema = r
    }
    property var atualizacoes: null          // { total, seguranca } ou null (sem apt-check)
    function lerAtualizacoes(s) {
        const c = s.trim().split("\t")
        atualizacoes = c.length === 2 ? { total: parseInt(c[0]) || 0, seguranca: parseInt(c[1]) || 0 } : null
    }

    // ---------------------------------------------------------------- clima (Open-Meteo, como o widget de clima)
    property var clima: ({ ok: false, temp: 0, codigo: 0, dia: true, umidade: 0, vento: 0 })
    property date climaQuando: new Date(0)
    readonly property string cidade: cfg.cidadeResolvida || cfg.cidade || ""
    readonly property string climaAtualizado: climaQuando.getTime() > 0 ? climaQuando.toLocaleTimeString(Qt.locale(), "HH:mm") : t("sem sinal", "no signal")
    readonly property string diaSemana: agora.toLocaleDateString(Qt.locale(), "ddd").replace(".", "").toUpperCase()
    function buscarClima() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return
            try {
                const c = JSON.parse(xhr.responseText).current
                clima = { ok: true, temp: c.temperature_2m, codigo: c.weather_code, dia: c.is_day === 1,
                          umidade: c.relative_humidity_2m, vento: c.wind_speed_10m }
                climaQuando = new Date()
            } catch (e) {}
        }
        xhr.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + cfg.latitude + "&longitude=" + cfg.longitude
                 + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m,wind_speed_10m&timezone=auto")
        xhr.send()
    }
    readonly property bool precisaResolver: (cfg.cidade || "").trim() !== "" && cfg.cidade !== cfg.cidadeResolvida
    function resolver() {
        const pedida = cfg.cidade
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || pedida !== cfg.cidade || xhr.status !== 200) return
            let r = []
            try { r = JSON.parse(xhr.responseText).results || [] } catch (e) {}
            if (!r.length) return
            cfg.latitude = r[0].latitude; cfg.longitude = r[0].longitude; cfg.cidadeResolvida = cfg.cidade
            buscarClima()
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&language=" + (en ? "en" : "pt")
                 + "&name=" + encodeURIComponent(String(cfg.cidade).split(",")[0].trim()))
        xhr.send()
    }
    Timer {
        interval: 30 * 60000; running: dd.quer("clima"); repeat: true; triggeredOnStart: true
        onTriggered: dd.precisaResolver ? dd.resolver() : dd.buscarClima()
    }
    readonly property var wmo: ({
        0: ["weather-clear", "Céu limpo", "Clear sky"], 1: ["weather-few-clouds", "Poucas nuvens", "Mainly clear"],
        2: ["weather-clouds", "Parcialmente nublado", "Partly cloudy"], 3: ["weather-overcast", "Nublado", "Overcast"],
        45: ["weather-fog", "Neblina", "Fog"], 48: ["weather-fog", "Neblina com geada", "Rime fog"],
        51: ["weather-showers-scattered", "Garoa fraca", "Light drizzle"], 53: ["weather-showers-scattered", "Garoa", "Drizzle"],
        55: ["weather-showers", "Garoa forte", "Dense drizzle"], 61: ["weather-showers-scattered", "Chuva fraca", "Light rain"],
        63: ["weather-showers", "Chuva", "Rain"], 65: ["weather-showers", "Chuva forte", "Heavy rain"],
        71: ["weather-snow-scattered", "Neve fraca", "Light snow"], 73: ["weather-snow", "Neve", "Snow"], 75: ["weather-snow", "Neve forte", "Heavy snow"],
        80: ["weather-showers-scattered", "Pancadas de chuva", "Rain showers"], 81: ["weather-showers", "Pancadas fortes", "Heavy showers"],
        82: ["weather-showers", "Temporal", "Violent showers"], 95: ["weather-storm", "Trovoadas", "Thunderstorm"],
        96: ["weather-storm", "Trovoadas com granizo", "Thunderstorm, hail"], 99: ["weather-storm", "Trovoadas com granizo", "Thunderstorm, hail"] })
    readonly property var _w: wmo[clima.codigo] || ["weather-none-available", "--", "--"]
    readonly property string climaIcone: clima.ok ? (_w[0] === "weather-clear" && !clima.dia ? "weather-clear-night" : _w[0]) : "weather-none-available"
    readonly property string climaDesc: clima.ok ? (en ? _w[2] : _w[1]) : t("Sem sinal da estação", "No signal from station")

    // ---------------------------------------------------------------- logo
    readonly property string logo: String(cfg.logo || "")
    readonly property string corpCodigo: ({ nenhuma: "CYBRKD", personalizada: "CYBRKD" })[Paleta.corp] || String(Paleta.corp || "cybrkd").toUpperCase().slice(0, 7)
}
