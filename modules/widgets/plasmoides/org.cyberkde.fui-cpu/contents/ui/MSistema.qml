import QtQuick
import "comum"

// SISTEMA: ligado há, carga média (1/5/15 min), atualizações pendentes, contêineres Docker, unidades com
// falha e baterias de periféricos (mouse, fone… pelo upower); o kernel no rodapé.
Modulo {
    id: m
    titulo: d.t("Sistema", "System"); codigo: "uptime · load"
    rodape: d.sistema.kernel ? "kernel " + d.sistema.kernel : ""
    dica: d.t("Ligado há: tempo desde o boot. Carga: processos esperando CPU na média de 1, 5 e 15 min (compare com os núcleos). Atualizações: apt-check, a cada 30 min. Docker: contêineres rodando / total. Falhas: unidades do seu usuário com falha. Baterias: periféricos pelo upower.",
              "Up: time since boot. Load: processes waiting for CPU averaged over 1, 5 and 15 min (compare with the cores). Updates: apt-check, every 30 min. Docker: containers running / total. Failed: your user units that failed. Batteries: peripherals via upower.")
    readonly property var s: d.sistema
    readonly property int lh: fi(11.5) + u(5)
    component Linha: Item {
        property string rotulo
        property string valor
        property color cor: Cores.texto
        width: m.width; height: m.lh
        Rot { k: m.k; anchors.verticalCenter: parent.verticalCenter; text: parent.rotulo }
        Val { k: m.k; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: parent.valor; color: parent.cor
              width: Math.min(implicitWidth, m.width - m.u(70)) }
    }
    Column {
        width: m.width
        Linha { rotulo: m.d.t("LIGADO HÁ", "UP"); valor: m.d.uptime > 0 ? m.d.duracao(m.d.uptime) : "--" }
        Linha { rotulo: m.d.t("CARGA", "LOAD"); valor: m.s.carga.map(x => m.d.dec(x, 2)).join("  ")
                cor: m.s.carga[0] > m.d.nCores ? Cores.alerta : Cores.texto }
        Linha { rotulo: m.d.t("ATUALIZAÇÕES", "UPDATES"); visible: m.d.atualizacoes !== null
                valor: m.d.atualizacoes ? m.d.atualizacoes.total + (m.d.atualizacoes.seguranca ? m.d.t(" (", " (") + m.d.atualizacoes.seguranca + m.d.t(" seg.)", " sec.)") : "") : ""
                cor: m.d.atualizacoes && m.d.atualizacoes.seguranca > 0 ? Cores.alerta : Cores.texto }
        Linha { rotulo: "DOCKER"; visible: m.s.docker !== null; valor: m.s.docker ? m.s.docker.rodando + " / " + m.s.docker.total : "" }
        Linha { rotulo: m.d.t("FALHAS", "FAILED"); valor: String(m.s.falhas); cor: m.s.falhas > 0 ? Cores.alerta : Cores.texto }
        Repeater {
            model: m.s.baterias.slice(0, 2)
            Linha { required property var modelData; rotulo: modelData.nome.toUpperCase(); valor: modelData.pct + " %"
                    cor: modelData.pct <= 15 ? Cores.alerta : Cores.texto }
        }
    }
}
