import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "comum"

// CyberKDE · Rede: interface ativa (a da rota padrão, Wi-Fi ou cabo), IP local, gateway, velocidade em
// tempo real (sensores do ksystemstats), latência por ping a um host configurável, perda de pacotes e VPN
// (interfaces tun/wg/tap/ppp…). Só leitura: "ip -j route get", a lista de /sys/class/net e "ping -c 1".
// O IP público (api.ipify.org) fica desligado por padrão, por privacidade em capturas.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // host do ping: só caracteres de endereço/nome (nada de opção nem de shell); senão, 1.1.1.1
    readonly property string host: {
        const h = String(cfg.host || "").trim()
        return /^[A-Za-z0-9.:][A-Za-z0-9.:-]{0,252}$/.test(h) ? h : "1.1.1.1"
    }

    // ---- interface ativa e VPN
    property string dev: ""
    property string ipLocal: ""
    property string gateway: ""
    property bool wifi: false
    property var vpns: []
    property bool semRede: false
    readonly property bool viaVpn: vpns.indexOf(dev) >= 0
    function ehVpn(n) { return /^(tun|tap|wg|ppp|vpn|ipsec|nordlynx|proton|tailscale|zt|utun|mullvad)/i.test(n) }

    readonly property string cmdRota: "ip -j route get 1.1.1.1 2>/dev/null; echo @@; ls /sys/class/net; echo @@; ls -d /sys/class/net/*/wireless 2>/dev/null"
    readonly property string cmdPing: "ping -c 1 -n -W 2 " + host

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            exec.disconnectSource(fonte)
            raiz.recebido(fonte, dados)
        }
        function rodar(cmd) { if (connectedSources.indexOf(cmd) < 0) connectSource(cmd) }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.rodar(raiz.cmdRota) }
    Timer { interval: Math.max(2, raiz.cfg.intervaloPing) * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: exec.rodar(raiz.cmdPing) }

    // ---- latência: 40 amostras; -1 = sem resposta
    readonly property int amostrasPing: 40
    property var hPing: []
    property real ultimoPing: -1
    readonly property var pingsValidos: hPing.filter(v => v >= 0)
    readonly property real perda: hPing.length ? (hPing.length - pingsValidos.length) / hPing.length : 0
    readonly property real mediaPing: pingsValidos.length ? pingsValidos.reduce((a, b) => a + b, 0) / pingsValidos.length : -1

    // demonstração (prévias): nada da rede real aparece; só o ping é medido de verdade
    readonly property bool demo: cfg.demonstracao === true
    property real _fase: 0
    Timer {
        interval: 1500; running: raiz.demo; repeat: true; triggeredOnStart: true
        onTriggered: {
            raiz._fase += 0.7
            raiz.dev = "wlan0"; raiz.ipLocal = "10.0.77.23"; raiz.gateway = "10.0.77.1"; raiz.wifi = true
            raiz.vpns = ["wg0"]; raiz.semRede = false
            const d = 1.8e6 + 1.4e6 * Math.sin(raiz._fase) + 0.6e6 * Math.sin(raiz._fase * 2.7)
            const s = 0.35e6 + 0.25e6 * Math.sin(raiz._fase * 1.3 + 1)
            raiz.hDesce = raiz.empurrar(raiz.hDesce, d); raiz.hSobe = raiz.empurrar(raiz.hSobe, s)
        }
    }
    readonly property real _desceDemo: hDesce.length ? hDesce[hDesce.length - 1] : 0
    readonly property real _sobeDemo: hSobe.length ? hSobe[hSobe.length - 1] : 0

    function recebido(fonte, dados) {
        const saida = String(dados.stdout || "")
        if (fonte === cmdRota && demo) return
        if (fonte === cmdRota) {
            const partes = saida.split("@@")
            let rota = null
            try { rota = JSON.parse((partes[0] || "").trim() || "[]")[0] || null } catch (e) { rota = null }
            const ifaces = (partes[1] || "").split(/\s+/).filter(n => n)
            const sem = (partes[2] || "").split(/\s+/).filter(n => n).map(p => p.split("/")[4])
            semRede = !rota
            dev = rota ? String(rota.dev || "") : ""
            ipLocal = rota ? String(rota.prefsrc || "") : ""
            gateway = rota ? String(rota.gateway || "") : ""
            wifi = dev !== "" && sem.indexOf(dev) >= 0
            vpns = ifaces.filter(n => ehVpn(n))
        } else if (fonte === cmdPing) {
            const m = saida.match(/time[=<]\s*([\d.]+)\s*ms/)
            const v = dados["exit code"] === 0 && m ? parseFloat(m[1]) : -1
            ultimoPing = v
            const a = hPing.length >= amostrasPing ? hPing.slice(1) : hPing.slice()
            a.push(v)
            hPing = a
        }
    }

    // ---- velocidade e nome da rede (sensores da interface ativa)
    component S: Sensors.Sensor { updateRateLimit: 1500 }
    S { id: desceS; sensorId: raiz.dev && !raiz.demo ? "network/" + raiz.dev + "/download" : "" }
    S { id: sobeS; sensorId: raiz.dev && !raiz.demo ? "network/" + raiz.dev + "/upload" : "" }
    S { id: nomeRede; sensorId: raiz.dev && !raiz.demo ? "network/" + raiz.dev + "/network" : ""; updateRateLimit: 30000 }
    S { id: sinalS; sensorId: raiz.dev && raiz.wifi && !raiz.demo ? "network/" + raiz.dev + "/signal" : ""; updateRateLimit: 10000 }
    S { id: ipSensor; sensorId: raiz.dev && !raiz.demo ? "network/" + raiz.dev + "/ipv4address" : ""; updateRateLimit: 30000 }
    readonly property QtObject desce: QtObject { readonly property real value: raiz.demo ? raiz._desceDemo : (desceS.value || 0) }
    readonly property QtObject sobe: QtObject { readonly property real value: raiz.demo ? raiz._sobeDemo : (sobeS.value || 0) }
    readonly property QtObject sinal: QtObject { readonly property real value: raiz.demo ? 72 : (sinalS.value || 0) }
    readonly property string ip: ipLocal || String(ipSensor.value || "")
    readonly property string rede: demo ? "NIGHT-CITY-5G" : String(nomeRede.value || "")

    readonly property int amostras: 60
    property var hDesce: []
    property var hSobe: []
    function empurrar(a, v) { const b = a.length >= amostras ? a.slice(1) : a.slice(); b.push(v || 0); return b }
    Timer {
        interval: 1500; running: raiz.dev !== "" && !raiz.demo; repeat: true
        onTriggered: { raiz.hDesce = raiz.empurrar(raiz.hDesce, desceS.value); raiz.hSobe = raiz.empurrar(raiz.hSobe, sobeS.value) }
    }

    // ---- IP público: só com a opção ligada
    property string ipPublico: ""
    function buscarIpPublico() {
        if (!cfg.ipPublico) { ipPublico = ""; return }
        const x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            const r = String(x.responseText || "").trim()
            raiz.ipPublico = x.status === 200 && /^[0-9a-fA-F.:]{3,45}$/.test(r) ? r : ""
        }
        x.open("GET", "https://api.ipify.org")
        x.send()
    }
    Timer { interval: 600000; running: raiz.cfg.ipPublico; repeat: true; triggeredOnStart: true; onTriggered: raiz.buscarIpPublico() }
    Connections { target: raiz.cfg; function onIpPublicoChanged() { raiz.buscarIpPublico() } }

    // ---- formatação
    function taxa(b) {
        if (!(b > 0)) return "0 B/s"
        const u = ["B/s", "KB/s", "MB/s", "GB/s"]
        let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i === 0 ? Math.round(b) : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i]
    }
    function ms(v) { return v < 0 ? "--" : (v < 10 ? v.toFixed(1) : Math.round(v)) + " ms" }
    function corPing(v) { return v < 0 || v >= 150 ? Cores.alerta : v >= 60 ? Cores.secundaria : Cores.texto }
    readonly property string tipo: semRede ? t("SEM REDE", "OFFLINE") : (viaVpn ? "VPN" : (wifi ? "WI-FI" : t("CABO", "WIRED")))
    readonly property string vpnTexto: vpns.length ? (viaVpn ? t("ATIVA · ", "ACTIVE · ") : t("LIGADA · ", "UP · ")) + vpns.join(", ") : t("NENHUMA", "NONE")

    toolTipMainText: t("Rede", "Network")
    toolTipSubText: semRede ? t("Sem conexão", "No connection")
        : tipo + " " + dev + " · ↓ " + taxa(desce.value) + " ↑ " + taxa(sobe.value) + " · ping " + ms(ultimoPing)

    // ---- tamanho na área de trabalho (não mexa): livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // ---- P: tipo e nome, velocidade e ping
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 3
                Codigo {
                    width: parent.width
                    text: "NET.LINK // " + raiz.tipo + (raiz.dev ? " · " + (raiz.rede || raiz.dev) : "")
                    textFormat: Text.PlainText
                    color: raiz.semRede ? Cores.alerta : Cores.destaque
                    tamanho: 8; font.bold: true; elide: Text.ElideRight
                }
                Row {
                    spacing: 12
                    Velocidade { seta: "↓"; valor: raiz.taxa(desce.value); cor: Cores.destaque }
                    Velocidade { seta: "↑"; valor: raiz.taxa(sobe.value); cor: Cores.secundaria }
                }
                Codigo {
                    text: "PING " + raiz.ms(raiz.ultimoPing) + "  ·  " + raiz.t("PERDA ", "LOSS ") + Math.round(raiz.perda * 100) + "%"
                          + (raiz.vpns.length ? "  ·  VPN" : "")
                    color: raiz.corPing(raiz.ultimoPing); tamanho: 8
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
                Kirigami.Icon {
                    source: raiz.wifi ? "network-wireless" : "network-wired"
                    width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                    color: raiz.semRede ? Cores.alerta : Cores.texto; isMask: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: raiz.ms(raiz.ultimoPing)
                    font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                    color: raiz.corPing(raiz.ultimoPing)
                }
            }
        }
    }

    // ---- M e G: os dados em linhas; com altura, os gráficos de latência e de velocidade
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("Rede", "Network")
            codigo: "NET.LINK // " + raiz.tipo + (raiz.dev ? " · " + raiz.dev : "")
            readonly property real h: area.height
            readonly property bool cabeLatencia: h >= 230
            readonly property bool cabeVelocidade: h >= 300
            extra: [
                Codigo {
                    visible: raiz.vpns.length > 0
                    text: raiz.viaVpn ? "◆ VPN" : "◇ VPN"
                    color: raiz.viaVpn ? Cores.destaque : Cores.texto2
                    tamanho: 9; font.bold: true
                }
            ]

            Column {
                anchors.fill: parent
                spacing: 4
                LinhaDado {
                    rotulo: raiz.t("INTERFACE", "INTERFACE")
                    valor: raiz.semRede ? raiz.t("sem conexão", "no connection")
                           : (raiz.wifi ? "Wi-Fi " : raiz.t("Cabo ", "Wired ")) + raiz.dev + (raiz.rede && raiz.rede !== raiz.dev ? " · " + raiz.rede : "")
                    cor: raiz.semRede ? Cores.alerta : Cores.texto
                    sinal: raiz.wifi && sinal.value > 0 ? sinal.value / 100 : -1
                }
                LinhaDado { rotulo: raiz.t("IP LOCAL", "LOCAL IP"); valor: raiz.ip || "--"; mono: true }
                LinhaDado { rotulo: "GATEWAY"; valor: raiz.gateway || "--"; mono: true }
                LinhaDado {
                    visible: raiz.cfg.ipPublico
                    rotulo: raiz.t("IP PÚBLICO", "PUBLIC IP"); valor: raiz.ipPublico || raiz.t("consultando…", "checking…"); mono: true
                }
                LinhaDado { rotulo: "VPN"; valor: raiz.vpnTexto; mono: true; cor: raiz.viaVpn ? Cores.destaque : Cores.texto2 }
                LinhaDado {
                    rotulo: raiz.t("TRÁFEGO", "TRAFFIC")
                    valor: "↓ " + raiz.taxa(desce.value) + "    ↑ " + raiz.taxa(sobe.value)
                    mono: true
                }
                LinhaDado {
                    rotulo: raiz.t("LATÊNCIA", "LATENCY")
                    valor: raiz.ms(raiz.ultimoPing) + "  ø " + raiz.ms(raiz.mediaPing)
                           + "  " + Math.round(raiz.perda * 100) + raiz.t("% perda", "% loss")
                    mono: true
                    cor: raiz.corPing(raiz.ultimoPing)
                    dica: raiz.host
                }
                Grafico {
                    visible: mold.cabeLatencia
                    width: parent.width
                    height: visible ? Math.max(34, Math.min(70, (mold.h - 170) / (mold.cabeVelocidade ? 2 : 1) - 18)) : 0
                    titulo: "PING → " + raiz.host
                    textoTitulo: raiz.ms(raiz.ultimoPing)
                    series: [{ valores: raiz.hPing.map(v => v < 0 ? 0 : v), cor: Cores.destaque }]
                    limiar: 150
                    perdas: raiz.hPing.map(v => v < 0)
                }
                Grafico {
                    visible: mold.cabeVelocidade
                    width: parent.width
                    height: visible ? Math.max(34, Math.min(70, (mold.h - 170) / 2 - 18)) : 0
                    titulo: raiz.t("■ DESCIDA  ■ SUBIDA", "■ DOWN  ■ UP")
                    series: [{ valores: raiz.hDesce, cor: Cores.destaque }, { valores: raiz.hSobe, cor: Cores.secundaria }]
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
        tamanhoPequeno: Qt.size(240, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 18, Kirigami.Units.gridUnit * 13)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 20, Kirigami.Units.gridUnit * 22)
    }
}
