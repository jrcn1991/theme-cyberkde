import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "comum"

// Níveis das 12 bandas do equalizador (40 Hz … 18 kHz), de 0 a 1.
// Padrão: SINTÉTICO, plausível e barato (batida no grave, variação por banda, agudos agitados), que só
// anda tocando e desce até o chão quando pausa.
// "Espectro real" (opção, desligada por padrão): o helper contents/code/espectro.py lê o monitor da
// saída de som (pw-record/parec), faz a FFT e escreve os níveis num arquivo em $XDG_RUNTIME_DIR; aqui o
// arquivo é lido ~20 vezes por segundo e o "aluguel" é renovado a cada 2 s. Parou de tocar, sumiu ou
// movimento mínimo: o helper é encerrado (e sai sozinho se o aluguel vencer). Sem pw-record/parec ou
// numpy, "disponivelReal" fica falso e o sintético segue.
Item {
    id: e
    property bool tocando: false
    property bool real: false                 // pedido pela opção
    property string chave: "0"                // id do applet (nome dos arquivos)
    property bool ativo: tocando && !Cores.reduzir && visible
    readonly property int bandas: 12
    property var niveis: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool disponivelReal: false       // pw-record (ou parec) e numpy presentes
    property string motivoIndisponivel: ""    // "captura" | "numpy" | ""
    property bool checado: false
    // falhouReal: o helper não entregou nada em 2 s (sem PipeWire rodando, por exemplo) → volta ao sintético
    property bool falhouReal: false
    property real _ultimo: 0
    readonly property bool usandoReal: real && disponivelReal && ativo && !falhouReal
    onRealChanged: falhouReal = false
    // (o padrão "^python3 …" não pega o próprio sh -c que roda o pgrep/pkill)

    // ---- sintético
    property real _t: 0
    property var _fase: []
    property real _batida: 0
    Component.onCompleted: { let f = []; for (let i = 0; i < bandas; i++) f.push(Math.random() * 6.28); _fase = f; checar() }
    Timer {
        interval: 33; repeat: true; running: e.ativo && !e.usandoReal
        onTriggered: {
            e._t += 0.033
            // batida a ~118 bpm com uma variação lenta; ataque rápido, queda lenta
            const fase = (e._t * 118 / 60) % 1
            e._batida = fase < 0.06 ? 1 : e._batida * 0.88
            let n = []
            for (let i = 0; i < e.bandas; i++) {
                const grave = Math.max(0, 1 - i / 4), agudo = Math.max(0, (i - 7) / 4)
                const base = 0.42 + 0.22 * Math.sin(e._t * (0.6 + i * 0.13) + e._fase[i])
                let v = base + grave * 0.45 * e._batida + agudo * 0.25 * (Math.random() - 0.3) + 0.12 * (Math.random() - 0.5)
                v *= 0.92 - 0.25 * Math.max(0, (i - 8) / 4)          // agudos um pouco mais baixos
                const ant = e.niveis[i] || 0
                v = Math.max(0, Math.min(1, v))
                n.push(v > ant ? ant + (v - ant) * 0.7 : ant + (v - ant) * 0.35)
            }
            e.niveis = n
        }
    }
    // parou: desce até o chão
    Timer {
        interval: 33; repeat: true; running: !e.ativo && e.niveis.some(v => v > 0.01)
        onTriggered: e.niveis = e.niveis.map(v => v * 0.8 < 0.01 ? 0 : v * 0.8)
    }

    // ---- real (helper)
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../code/espectro.py").toString().replace(/^file:\/\//, ""))
    readonly property string arq: '"${XDG_RUNTIME_DIR:-/tmp}/cyberkde-midia-' + chave + '.niveis"'
    readonly property string aluguel: '"${XDG_RUNTIME_DIR:-/tmp}/cyberkde-midia-' + chave + '.aluguel"'
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            exec.disconnectSource(fonte)
            const s = (dados.stdout || "").trim()
            if (fonte.indexOf("command -v") === 0) {
                e.checado = true
                e.disponivelReal = s === "ok"
                e.motivoIndisponivel = s === "ok" ? "" : s === "numpy" ? "numpy" : "captura"
            } else if (fonte.indexOf("cat ") === 0 && s) {
                const v = s.split(/\s+/).map(Number)
                if (v.length === e.bandas && v.every(x => isFinite(x))) { e.niveis = v; e._ultimo = Date.now() }
            }
        }
        function rodar(cmd) { if (connectedSources.indexOf(cmd) < 0) connectSource(cmd) }
    }
    function checar() {
        exec.rodar("command -v pw-record >/dev/null 2>&1 || command -v parec >/dev/null 2>&1 || { echo captura; exit; }; python3 -c 'import numpy' 2>/dev/null && echo ok || echo numpy")
    }
    function iniciarHelper() {
        exec.rodar("touch " + aluguel + "; pgrep -f '^python3 .*cyberkde-midia-" + chave + "[.]aluguel' >/dev/null || setsid python3 '" + script + "' --saida " + arq + " --aluguel " + aluguel + " >/dev/null 2>&1 < /dev/null & echo")
    }
    function pararHelper() { exec.rodar("rm -f " + aluguel + "; pkill -f '^python3 .*cyberkde-midia-" + chave + "[.]aluguel'; echo") }
    onUsandoRealChanged: { if (usandoReal) { _ultimo = Date.now(); iniciarHelper() } else pararHelper() }
    Timer { interval: 1000; repeat: true; running: e.usandoReal; onTriggered: if (Date.now() - e._ultimo > 2500) e.falhouReal = true }
    Component.onDestruction: if (usandoReal) pararHelper()
    Timer { interval: 2000; repeat: true; running: e.usandoReal; onTriggered: exec.rodar("touch " + e.aluguel + "; echo") }
    Timer { interval: 50; repeat: true; running: e.usandoReal; onTriggered: exec.rodar("cat " + e.arq + " 2>/dev/null") }
}
