import QtQuick
import "comum"

// SENSORES: 8 knobs com valor, unidade e nome (CPU°, GPU°, GPU%, VRAM, RAM, SWAP, /, NET).
Modulo {
    id: m
    titulo: d.t("Sensores", "Sensors"); codigo: "ch.sys"
    rodape: d.t("temperaturas em °C · uso em %", "temperatures in °C · load in %")
    dica: d.t("CPU° e GPU°: temperaturas. GPU%: uso da placa de vídeo. VRAM: memória de vídeo usada. RAM e SWAP: memória usada. /: ocupação do disco do sistema. NET: atividade da rede (escala logarítmica). Fonte: ksystemstats e df.",
              "CPU° and GPU°: temperatures. GPU%: graphics card load. VRAM: video memory used. RAM and SWAP: memory used. /: system disk usage. NET: network activity (log scale). Source: ksystemstats and df.")
    readonly property real passo: (width - u(4)) / 4
    Repeater {
        model: 8
        Knob {
            required property int index
            readonly property var c: m.d.canais[index] || { v: 0, num: "--", nome: "", alerta: false }
            k: m.k
            x: Math.round(m.u(2) + (index % 4) * m.passo + (m.passo - width) / 2); y: index < 4 ? m.u(2) : m.u(63)
            valor: c.v; numero: c.num; nome: c.nome; alerta: c.alerta
            montado: m.montado
        }
    }
}
