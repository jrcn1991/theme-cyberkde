import QtQuick
import "comum"

// NÚCLEOS: a CPU em 6 grupos de núcleos lógicos (C0-1 … C10-11), barra e % de cada um; o grupo mais
// carregado fica destacado (o destaque desliza de linha em linha, como a faixa F1–F6 da referência).
Modulo {
    id: m
    titulo: d.t("Núcleos", "Cores"); codigo: d.t("CPU por grupo", "CPU per group")
    rodape: d.nCores + d.t(" núcleos em 6 grupos · pico ", " cores in 6 groups · peak ") + d.bandasRot[d.bandaMax]
    dica: d.t("Uso de cada grupo de núcleos lógicos da CPU (média dos núcleos do grupo), pelos sensores do sistema (ksystemstats, cpu/cpuN/usage). O grupo mais carregado fica destacado.",
              "Load of each group of logical CPU cores (average of the group), from the system sensors (ksystemstats, cpu/cpuN/usage). The busiest group is highlighted.")
    readonly property int alt: u(19)
    Rectangle {
        y: m.u(4) + m.d.bandaMax * m.alt - m.u(2)
        width: m.width; height: m.alt
        color: Cores.alfa(Cores.destaque, 0.16)
        opacity: m.montado >= 1 ? 1 : 0
        Behavior on y { enabled: !Cores.reduzir; NumberAnimation { duration: Cores.d(150); easing.type: Easing.InOutQuad } }
        Rectangle { width: m.lw(3); height: parent.height; color: Cores.destaque }
    }
    Repeater {
        model: 6
        Item {
            required property int index
            readonly property real v: (m.d.bandas[index] || 0) / 100
            readonly property bool ativo: index === m.d.bandaMax
            readonly property bool quente: v >= m.d.limiar
            y: m.u(4) + index * m.alt; width: m.width; height: m.alt
            Text {
                x: m.u(8); anchors.verticalCenter: parent.verticalCenter
                text: m.d.bandasRot[index] || ""
                font.family: Cores.fMono; font.pixelSize: m.fi(11.5); font.weight: Font.Bold
                color: parent.ativo ? Cores.destaque : Cores.texto2
            }
            BarraSegmentada {
                x: m.u(78); anchors.verticalCenter: parent.verticalCenter
                width: m.width - m.u(78) - m.u(74); height: Math.max(4, m.u(6))
                tamSeg: Math.max(3, m.u(4)); vao: Math.max(1, m.u(2))
                valor: m.conta(parent.v); limiar: m.d.limiar
                cor: parent.ativo ? Cores.destaque : Cores.texto
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: m.u(6); anchors.verticalCenter: parent.verticalCenter
                text: Math.round(m.conta(parent.v) * 100) + " %"
                font.family: Cores.fMono; font.pixelSize: m.fi(12); font.weight: Font.Bold
                color: parent.quente ? Cores.alerta : parent.ativo ? Cores.destaque : Cores.texto
            }
        }
    }
}
