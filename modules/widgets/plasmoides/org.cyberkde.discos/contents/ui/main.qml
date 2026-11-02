import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "comum"

// CyberKDE · Discos: espaço de cada unidade montada (df, pelo script contents/code/discos.sh, no engine
// "executable"), leitura e escrita ao vivo por disco físico (sensores do ksystemstats, disk/<sdX>/read e
// write) e a temperatura, quando o disco tem sensor (hwmon). Acima do limiar, a unidade vai para a cor
// de alerta. Clique numa unidade: abre a pasta no Dolphin.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }
    readonly property real limiar: Math.max(0.5, Math.min(0.99, cfg.limiar / 100))

    // ---- espaço (df)
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../code/discos.sh").toString().replace(/^file:\/\//, ""))
    readonly property string cmdDf: "sh '" + script.replace(/'/g, "'\\''") + "'"
    property var todas: []            // tudo o que o df mostrou (montagens reais)
    property bool lido: false
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            if (fonte === raiz.cmdDf) raiz.ler(dados["stdout"] || "")
            disconnectSource(fonte)
        }
    }
    function rodar(c) { exec.connectSource(c) }
    function ler(saida) {
        const r = [], vistos = {}
        for (const linha of saida.split("\n")) {
            const c = linha.split("\t")
            if (c.length < 8) continue
            const alvo = c.slice(7).join("\t")
            const total = parseFloat(c[2]), usado = parseFloat(c[3]), livre = parseFloat(c[4])
            if (!(total > 0) || vistos[c[0] + "|" + alvo]) continue
            vistos[c[0] + "|" + alvo] = true
            r.push({ disp: c[0], tipo: c[1], total: total, usado: usado, livre: livre, pk: c[5],
                     temp: c[6] ? parseFloat(c[6]) / 1000 : 0, alvo: alvo,
                     // ocupação como o df: usado / (usado + livre) (a reserva do root não conta como livre)
                     frac: usado + livre > 0 ? usado / (usado + livre) : 0 })
        }
        todas = r
        lido = true
    }
    Timer {
        interval: Math.max(5, raiz.cfg.intervalo) * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: raiz.rodar(raiz.cmdDf)
    }

    // unidades mostradas: as da chave "montagens" (na ordem dada) ou as reais: /, /home, /mnt/*, mídias
    function real(a) { return a === "/" || a === "/home" || /^\/(mnt|media|run\/media)\//.test(a) }
    readonly property var pedidas: String(cfg.montagens || "").split(",").map(x => x.trim().replace(/(.)\/+$/, "$1")).filter(x => x !== "")
    readonly property var unidades: {
        let lista
        if (pedidas.length) {
            lista = []
            for (const p of pedidas) { const u = todas.find(x => x.alvo === p); if (u) lista.push(u) }
        } else {
            const vistos = {}
            lista = todas.filter(u => real(u.alvo) && !vistos[u.disp] && (vistos[u.disp] = true))
        }
        return lista.map(u => Object.assign({}, u, { nome: nomeDe(u.alvo) }))
    }
    function nomeDe(a) {
        if (a === "/") return t("Sistema", "System")
        if (a === "/home") return t("Pessoal", "Home")
        return a.split("/").filter(x => x).pop() || a
    }
    readonly property var maisCheia: unidades.length ? unidades.reduce((m, u) => u.frac > m.frac ? u : m) : null
    readonly property int emAlerta: unidades.filter(u => u.frac >= limiar).length

    // ---- leitura e escrita (sensores por disco físico)
    readonly property var fisicos: { const r = []; for (const u of unidades) if (u.pk && r.indexOf(u.pk) < 0) r.push(u.pk); return r }
    property var _es: ({})
    property int esTick: 0
    Instantiator {
        model: raiz.fisicos
        delegate: QtObject {
            required property string modelData
            property Sensors.Sensor rd: Sensors.Sensor { sensorId: "disk/" + modelData + "/read"; updateRateLimit: 1000 }
            property Sensors.Sensor wr: Sensors.Sensor { sensorId: "disk/" + modelData + "/write"; updateRateLimit: 1000 }
        }
        onObjectAdded: (i, o) => { const m = Object.assign({}, raiz._es); m[o.modelData] = o; raiz._es = m }
        onObjectRemoved: (i, o) => { const m = Object.assign({}, raiz._es); delete m[o.modelData]; raiz._es = m }
    }
    function es(pk, qual) { esTick; const o = _es[pk]; return o ? (qual === "r" ? o.rd.value : o.wr.value) || 0 : 0 }
    Sensors.Sensor { id: totLeitura; sensorId: "disk/all/read"; updateRateLimit: 1000 }
    Sensors.Sensor { id: totEscrita; sensorId: "disk/all/write"; updateRateLimit: 1000 }
    property var hLeitura: []
    property var hEscrita: []
    function empurrar(a, v) { const b = a.length >= 60 ? a.slice(1) : a.slice(); b.push(v || 0); return b }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            raiz.esTick++
            raiz.hLeitura = raiz.empurrar(raiz.hLeitura, totLeitura.value)
            raiz.hEscrita = raiz.empurrar(raiz.hEscrita, totEscrita.value)
        }
    }

    // ---- abrir no Dolphin
    function abrir(u) {
        if (!u) return
        rodar("dolphin --new-window '" + u.alvo.replace(/'/g, "'\\''") + "'")
    }

    // ---- formatação (binária, como o Dolphin)
    function bytes(b) {
        if (!(b > 0)) return "0 B"
        const u = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return Number(b).toLocaleString(Qt.locale(), "f", b >= 100 || i === 0 ? 0 : 1) + " " + u[i]
    }
    function taxa(b) {
        if (!(b > 0)) return "0 B/s"
        const u = ["B/s", "KB/s", "MB/s", "GB/s"]
        let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i === 0 ? Math.round(b) : Number(b).toLocaleString(Qt.locale(), "f", b < 10 ? 1 : 0)) + " " + u[i]
    }

    toolTipMainText: t("Discos", "Drives")
    toolTipSubText: maisCheia ? maisCheia.nome + " " + Math.round(maisCheia.frac * 100) + "% · " + bytes(maisCheia.livre) + t(" livres", " free")
                                + (emAlerta > 1 ? t(" · " + emAlerta + " cheias", " · " + emAlerta + " full") : "") : ""

    // ---- tamanho na área de trabalho (padrão dos widgets do tema)
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // ---- P: a unidade mais cheia
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            id: car
            opacidade: raiz.opac
            readonly property var u: raiz.maisCheia
            readonly property bool cheio: u && u.frac >= raiz.limiar
            Column {
                anchors.fill: parent
                spacing: 3
                Codigo {
                    width: parent.width
                    text: car.cheio ? raiz.t("DRV.MON // ▲ QUASE CHEIO", "DRV.MON // ▲ NEARLY FULL")
                                    : "DRV.MON // " + raiz.unidades.length + raiz.t(raiz.unidades.length === 1 ? " UNIDADE" : " UNIDADES", raiz.unidades.length === 1 ? " DRIVE" : " DRIVES")
                    color: car.cheio ? Cores.alerta : Cores.destaque; tamanho: 8; font.bold: true
                }
                Item {
                    width: parent.width; height: nomeP.height
                    Text {
                        id: nomeP
                        width: parent.width - pctP.width - 6
                        text: car.u ? car.u.nome : (raiz.lido ? raiz.t("Nenhuma unidade", "No drive") : "…")
                        font.family: Cores.fTexto; font.pixelSize: 14; font.bold: true
                        color: Cores.texto; elide: Text.ElideRight
                    }
                    NumeroCintilante {
                        id: pctP
                        anchors.right: parent.right; anchors.baseline: nomeP.baseline
                        valor: car.u ? Math.round(car.u.frac * 100) + "%" : "--"
                        intervaloMin: 10000
                        font.family: Cores.fIdentidade; font.weight: Font.Bold; font.pixelSize: 18
                        color: car.cheio ? Cores.alerta : Cores.texto
                    }
                }
                BarraSegmentada { width: parent.width; height: 8; valor: car.u ? car.u.frac : 0; limiar: raiz.limiar }
                Text {
                    width: parent.width
                    text: car.u ? raiz.bytes(car.u.livre) + raiz.t(" livres de ", " free of ") + raiz.bytes(car.u.total) : ""
                    font.family: Cores.fMono; font.pixelSize: 9
                    color: car.cheio ? Cores.alerta : Cores.texto2; elide: Text.ElideRight
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: raiz.abrir(car.u) }
        }
    }

    // ---- barra: a ocupação da mais cheia
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linhaC.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Row {
                id: linhaC
                anchors.centerIn: parent
                height: parent.height * 0.7
                spacing: 3
                BarraSegmentada { vertical: true; width: 5; height: parent.height; valor: raiz.maisCheia ? raiz.maisCheia.frac : 0; limiar: raiz.limiar; tamSeg: 2; vao: 1 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: raiz.maisCheia ? Math.round(raiz.maisCheia.frac * 100) + "%" : "--"
                    font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                    color: raiz.maisCheia && raiz.maisCheia.frac >= raiz.limiar ? Cores.alerta : Cores.texto
                }
            }
        }
    }

    // ---- M: lista; G: lista + leitura/escrita (pelo tamanho real)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("Discos", "Drives")
            codigo: "DRV.MON // " + raiz.unidades.length + raiz.t(raiz.unidades.length === 1 ? " UNIDADE" : " UNIDADES", raiz.unidades.length === 1 ? " DRIVE" : " DRIVES")
            readonly property real h: area.height
            readonly property int alturaLinha: 46
            readonly property bool cabeES: h - Math.min(raiz.unidades.length, 3) * alturaLinha >= 112
            readonly property int linhas: Math.max(1, Math.floor((cabeES ? h - 112 : h) / alturaLinha))
            extra: [
                Item {
                    visible: raiz.emAlerta > 0
                    width: av.implicitWidth + 12; height: 16
                    Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.alerta, 0.15); border.color: Cores.alerta }
                    Codigo { id: av; anchors.centerIn: parent; text: raiz.t("▲ " + raiz.emAlerta + " CHEIA" + (raiz.emAlerta > 1 ? "S" : ""), "▲ " + raiz.emAlerta + " FULL"); color: Cores.alerta; tamanho: 9; font.bold: true }
                    SequentialAnimation on opacity {
                        running: raiz.emAlerta > 0 && !Cores.reduzir
                        loops: 3
                        NumberAnimation { to: 0.2; duration: 120 }
                        NumberAnimation { to: 1; duration: 120 }
                    }
                }
            ]

            Column {
                id: lista
                width: parent.width
                spacing: 2
                Repeater {
                    model: raiz.unidades.slice(0, mold.linhas)
                    LinhaDisco {
                        required property var modelData
                        width: lista.width
                        u: modelData
                        limiar: raiz.limiar
                        mostrarES: mold.cabeES
                        leitura: mold.cabeES ? raiz.es(modelData.pk, "r") : 0
                        escrita: mold.cabeES ? raiz.es(modelData.pk, "w") : 0
                        bytes: raiz.bytes
                        taxa: raiz.taxa
                        onAbrir: raiz.abrir(modelData)
                    }
                }
                Codigo {
                    visible: raiz.unidades.length > mold.linhas
                    text: raiz.t("+ " + (raiz.unidades.length - mold.linhas) + " unidade(s) (aumente o widget)",
                                 "+ " + (raiz.unidades.length - mold.linhas) + " more drive(s) (enlarge the widget)")
                    tamanho: 8
                }
            }

            // leitura e escrita somadas, com gráfico
            Item {
                visible: mold.cabeES
                y: lista.y + lista.height + 8
                width: parent.width
                height: parent.height - y
                Row {
                    id: cab
                    width: parent.width
                    spacing: 12
                    Codigo { text: "I/O"; color: Cores.destaque; tamanho: 9; font.bold: true }
                    Codigo { text: "■ " + raiz.t("LEITURA ", "READ ") + raiz.taxa(totLeitura.value); color: Cores.destaque; tamanho: 9 }
                    Codigo { text: "■ " + raiz.t("ESCRITA ", "WRITE ") + raiz.taxa(totEscrita.value); color: Cores.secundaria; tamanho: 9 }
                }
                GraficoHud {
                    y: cab.height + 4
                    width: parent.width
                    height: parent.height - y
                    series: [{ valores: raiz.hLeitura, cor: Cores.destaque }, { valores: raiz.hEscrita, cor: Cores.secundaria }]
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
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 18, Kirigami.Units.gridUnit * 15)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 21, Kirigami.Units.gridUnit * 28)
    }
}
