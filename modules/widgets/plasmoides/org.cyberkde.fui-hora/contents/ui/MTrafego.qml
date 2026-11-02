import QtQuick
import "comum"

// TRÁFEGO: a grade de pontos da referência como histograma (13 amostras de 2 s, escala log) e ↓/↑.
Modulo {
    id: m
    titulo: d.t("Rede", "Network"); codigo: d.t("tráfego", "traffic")
    rodape: d.t("26 s · escala log", "26 s · log scale")
    dica: d.t("Tráfego de rede somado (descida + subida) dos últimos 26 s, uma coluna a cada 2 s; quanto mais pontos acesos, mais tráfego (escala logarítmica). Fonte: network/all do ksystemstats.",
              "Total network traffic (down + up) for the last 26 s, one column every 2 s; more lit dots, more traffic (log scale). Source: ksystemstats network/all.")
    readonly property int passo: Math.max(5, Math.floor((width - u(4)) / 13))
    Repeater {
        model: 13
        Repeater {
            id: col
            required property int index
            readonly property int acesos: Math.round((m.d.hRede[index] || 0) * 7 * Math.min(1, m.montado * 1.5))
            model: 7
            Rectangle {
                required property int index
                readonly property bool aceso: (6 - index) < col.acesos
                x: m.u(3) + col.index * m.passo; y: index * m.u(9)
                width: aceso ? Math.max(3, m.u(4)) : Math.max(1, m.u(1.5)); height: width
                color: aceso ? Cores.texto : Cores.alfa(Cores.texto, 0.25)
            }
        }
    }
    Val { k: m.k; y: m.u(70); text: "↓ " + m.d.taxa(m.d.desce) }
    Val { k: m.k; y: m.u(88); text: "↑ " + m.d.taxa(m.d.sobe); color: Cores.texto2 }
}
