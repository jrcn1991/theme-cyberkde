import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Docker: contêineres (nome, imagem, estado, uptime, CPU e memória) e o estado do daemon, pelo
// comando docker da própria conta (engine "executable"): "docker ps -a --format json" a cada intervalo e
// "docker stats --no-stream --format json" só quando há contêiner rodando. Ações: iniciar, parar (com
// confirmação) e reiniciar, por id. Nada de porta nem serviço: só o cliente docker.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }
    readonly property int intervalo: Math.max(3, cfg.intervalo) * 1000

    // ---- estado
    // estado do daemon: "lendo" | "ok" | "ausente" (sem o comando) | "permissao" | "parado" | "erro"
    property string daemon: "lendo"
    property string erro: ""
    property string versao: ""
    property var conteineres: []          // [{id, nome, imagem, estado, status, uptime, saude}]
    property var stats: ({})              // id curto -> {cpu: "0.5%", mem: "25MiB", memPct: 0.3}
    property var pendentes: ({})          // id -> "start" | "stop" | "restart"
    property string confirmarParar: ""    // id esperando o segundo clique em "parar"

    readonly property var rodando: conteineres.filter(c => c.estado === "running")
    readonly property var parados: conteineres.filter(c => c.estado !== "running")
    readonly property var visiveis: cfg.mostrarParados ? conteineres : rodando
    readonly property int nRodando: rodando.length
    readonly property int nParados: parados.length
    readonly property int nDoentes: conteineres.filter(c => c.saude === "unhealthy").length

    // ---- comandos (engine executable; cada fonte é desconectada ao chegar a resposta)
    readonly property string cmdPs: "docker ps -a --format json"
    readonly property string cmdStats: "docker stats --no-stream --format json"
    readonly property string cmdVersao: "docker version --format '{{.Server.Version}}'"
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

    function atualizar() { exec.rodar(cmdPs) }
    Timer {
        interval: raiz.intervalo; running: true; repeat: true; triggeredOnStart: true
        onTriggered: raiz.atualizar()
    }
    Timer {  // versão do servidor: rara
        interval: 300000; running: raiz.daemon === "ok"; repeat: true; triggeredOnStart: true
        onTriggered: exec.rodar(raiz.cmdVersao)
    }

    function linhasJson(texto) {
        const r = []
        for (const l of String(texto || "").split("\n")) {
            const s = l.trim()
            if (!s.startsWith("{")) continue
            try { r.push(JSON.parse(s)) } catch (e) { }
        }
        return r
    }
    function classificarErro(saida, codigo) {
        const s = String(saida || "").toLowerCase()
        if (codigo === 127 || s.indexOf("not found") >= 0 && s.indexOf("docker") >= 0 && s.indexOf("container") < 0) return "ausente"
        if (s.indexOf("permission denied") >= 0) return "permissao"
        if (s.indexOf("cannot connect to the docker daemon") >= 0 || s.indexOf("is the docker daemon running") >= 0) return "parado"
        return "erro"
    }
    // "Up 3 hours (healthy)" → "3h"; "Exited (0) 2 days ago" → "2d"
    function abreviar(txt) {
        let s = String(txt || "").replace(/\s*\(.*?\)\s*/g, " ").trim()
        s = s.replace(/^(Up|Exited|Created|Restarting|Paused)\s*/i, "").replace(/\s*ago$/i, "")
        if (/less than a second|seconds?$/i.test(s)) return /^\d+/.test(s) ? parseInt(s) + "s" : "<1s"
        if (/^about a minute/i.test(s)) return "~1min"
        if (/^about an hour/i.test(s)) return "~1h"
        const m = s.match(/^(\d+)\s*(second|minute|hour|day|week|month|year)/i)
        if (!m) return s
        const u = { second: "s", minute: "min", hour: "h", day: "d", week: t("sem", "w"), month: t("mês", "mo"), year: t("a", "y") }
        return m[1] + u[m[2].toLowerCase()]
    }
    function recebido(fonte, dados) {
        const codigo = dados["exit code"]
        const saida = String(dados.stdout || "")
        const err = String(dados.stderr || "")
        if (fonte === cmdPs) {
            if (codigo !== 0) {
                daemon = classificarErro(err + " " + saida, codigo)
                erro = err.split("\n")[0].trim()
                conteineres = []; stats = {}
                return
            }
            daemon = "ok"; erro = ""
            const lista = linhasJson(saida).map(o => ({
                id: String(o.ID || ""),
                nome: String(o.Names || "").split(",")[0],
                imagem: String(o.Image || ""),
                estado: String(o.State || "").toLowerCase(),
                status: String(o.Status || ""),
                uptime: abreviar(o.Status),
                saude: /\(unhealthy\)/i.test(o.Status) ? "unhealthy" : (/\(healthy\)/i.test(o.Status) ? "healthy" : "")
            })).filter(c => /^[0-9a-f]{6,64}$/i.test(c.id))
            lista.sort((a, b) => (a.estado === "running" ? 0 : 1) - (b.estado === "running" ? 0 : 1) || a.nome.localeCompare(b.nome))
            conteineres = lista
            if (lista.some(c => c.estado === "running")) exec.rodar(cmdStats)
            else stats = {}
        } else if (fonte === cmdStats) {
            if (codigo !== 0) return
            const m = {}
            for (const o of linhasJson(saida)) {
                const id = String(o.ID || o.Container || "")
                m[id.slice(0, 12)] = { cpu: String(o.CPUPerc || "--"), mem: String(o.MemUsage || "").split("/")[0].trim(),
                                       memPct: (parseFloat(o.MemPerc) || 0) / 100, cpuNum: parseFloat(o.CPUPerc) || 0 }
            }
            stats = m
        } else if (fonte === cmdVersao) {
            if (codigo === 0) versao = saida.trim().replace(/^'|'$/g, "")
        } else if (fonte.startsWith("docker start ") || fonte.startsWith("docker stop ") || fonte.startsWith("docker restart ")) {
            // o comando só volta quando a ação termina: aí o "…" sai e a lista é relida
            if (codigo !== 0) erro = (err.split("\n")[0] || t("A ação falhou.", "The action failed.")).trim()
            const p = Object.assign({}, pendentes)
            delete p[fonte.split(" ")[2]]
            pendentes = p
            atualizar()
        }
    }
    function statsDe(id) { return stats[String(id).slice(0, 12)] || null }

    // ---- ações (ids só hexadecimais: nada de texto do Docker vai para o shell)
    function agir(acao, id) {
        if (!/^[0-9a-f]{6,64}$/i.test(id) || ["start", "stop", "restart"].indexOf(acao) < 0) return
        if (acao === "stop" && confirmarParar !== id) { confirmarParar = id; desarmar.restart(); return }
        confirmarParar = ""
        const p = Object.assign({}, pendentes); p[id] = acao; pendentes = p
        exec.rodar("docker " + acao + " " + id)
    }
    Timer { id: desarmar; interval: 4000; onTriggered: raiz.confirmarParar = "" }

    readonly property string mensagem: daemon === "ausente" ? t("Docker não instalado (comando docker não encontrado).", "Docker is not installed (no docker command).")
        : daemon === "permissao" ? t("Sem permissão para o Docker. Entre no grupo docker: sudo usermod -aG docker $USER, e entre de novo na sessão.",
                                     "No permission for Docker. Join the docker group: sudo usermod -aG docker $USER, then log in again.")
        : daemon === "parado" ? t("O daemon do Docker não está rodando.", "The Docker daemon is not running.")
        : daemon === "erro" ? (erro || t("Erro ao ler o Docker.", "Error reading Docker."))
        : ""
    readonly property string codigoDaemon: daemon === "ok" ? t("ONLINE", "ONLINE") + (versao ? " · v" + versao : "")
        : daemon === "lendo" ? t("LENDO", "READING") : daemon === "parado" ? "OFFLINE" : daemon === "permissao" ? t("SEM ACESSO", "NO ACCESS")
        : daemon === "ausente" ? t("AUSENTE", "MISSING") : t("ERRO", "ERROR")

    toolTipMainText: "Docker"
    toolTipSubText: daemon === "ok" ? t(nRodando + " rodando · " + nParados + " parados", nRodando + " running · " + nParados + " stopped") : mensagem

    // ---- tamanho na área de trabalho (não mexa): livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // ---- P: contagem de rodando e parados
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 4
                Codigo {
                    width: parent.width
                    text: "DOCKER // " + raiz.codigoDaemon
                    color: raiz.daemon === "ok" ? Cores.destaque : Cores.alerta
                    tamanho: 8; font.bold: true
                    elide: Text.ElideRight
                }
                Row {
                    visible: raiz.daemon === "ok"
                    spacing: 18
                    Contagem { rotulo: raiz.t("RODANDO", "RUNNING"); valor: raiz.nRodando; cor: Cores.destaque }
                    Contagem { rotulo: raiz.t("PARADOS", "STOPPED"); valor: raiz.nParados; cor: Cores.texto2 }
                    Contagem { visible: raiz.nDoentes > 0; rotulo: raiz.t("INSTÁVEIS", "UNHEALTHY"); valor: raiz.nDoentes; cor: Cores.alerta }
                }
                Leitura {
                    visible: raiz.daemon !== "ok"
                    width: parent.width
                    text: raiz.daemon === "lendo" ? raiz.t("Lendo o Docker…", "Reading Docker…") : raiz.mensagem
                    tamanho: 11; color: Cores.texto2
                    wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
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
                Kirigami.Icon { source: "package-x-generic"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter; color: Cores.texto; isMask: true }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: raiz.daemon === "ok" ? raiz.nRodando + "/" + raiz.conteineres.length : "--"
                    font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                    color: raiz.daemon === "ok" ? Cores.texto : Cores.alerta
                }
            }
        }
    }

    // ---- M e G: a lista; com espaço, CPU/memória e ações por contêiner
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: "Docker"
            codigo: "DOCK.CTL // " + raiz.codigoDaemon
            // pelo tamanho real: detalhes (CPU/mem) e ações entram quando há largura e altura
            readonly property bool detalhes: area.width >= 320 && area.height >= 200
            extra: [
                Row {
                    spacing: 6
                    Codigo {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: raiz.daemon === "ok"
                        text: "▶ " + raiz.nRodando + "  ■ " + raiz.nParados
                        color: Cores.texto2; tamanho: 8
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
                visible: raiz.daemon !== "ok"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: raiz.daemon === "lendo" ? raiz.t("Lendo o Docker…", "Reading Docker…") : raiz.mensagem
                color: raiz.daemon === "lendo" ? Cores.texto2 : Cores.alerta
                tamanho: 12
            }
            Leitura {
                anchors.centerIn: parent
                visible: raiz.daemon === "ok" && raiz.visiveis.length === 0
                text: raiz.conteineres.length === 0 ? raiz.t("Nenhum contêiner.", "No containers.") : raiz.t("Nenhum contêiner rodando.", "No running containers.")
                color: Cores.texto2; tamanho: 12
            }

            ListView {
                id: lista
                anchors.fill: parent
                anchors.bottomMargin: avisoErro.visible ? avisoErro.height + 4 : 0
                visible: raiz.daemon === "ok"
                clip: true
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                model: raiz.visiveis
                delegate: LinhaConteiner {
                    width: lista.width
                    c: modelData
                    st: raiz.statsDe(modelData.id)
                    detalhes: mold.detalhes
                    pendente: raiz.pendentes[modelData.id] || ""
                    armado: raiz.confirmarParar === modelData.id
                    en: raiz.en
                    onAcao: (a) => raiz.agir(a, modelData.id)
                }
            }
            Codigo {
                id: avisoErro
                anchors.bottom: parent.bottom
                width: parent.width
                visible: raiz.daemon === "ok" && raiz.erro !== ""
                text: "▲ " + raiz.erro
                color: Cores.alerta; tamanho: 8
                elide: Text.ElideRight
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
        limiteCartao: Qt.size(250, 140)
        tamanhoPequeno: Qt.size(240, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 17, Kirigami.Units.gridUnit * 13)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 24, Kirigami.Units.gridUnit * 20)
    }
}
