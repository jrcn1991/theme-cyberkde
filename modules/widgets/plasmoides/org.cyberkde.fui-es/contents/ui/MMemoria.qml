import QtQuick
import "comum"

// MEMÓRIA: a barra hachurada da referência dividida em RAM (esquerda) e swap (direita), com legenda, os
// valores em GiB e o total; cache e buffers no rodapé.
Modulo {
    id: m
    titulo: d.t("Memória", "Memory"); codigo: "ram + swap"
    rodape: "cache " + d.bytes(d.memCache) + " · buffer " + d.bytes(d.memBuffer)
    dica: d.t("RAM usada (sem cache) e swap usada, pelos sensores memory/* do ksystemstats. A barra é dividida: RAM à esquerda, swap à direita.",
              "RAM in use (without cache) and swap in use, from the ksystemstats memory/* sensors. The bar is split: RAM on the left, swap on the right.")
    readonly property int wr: Math.round(width * 0.68)
    readonly property real fRam: conta(d.fRam)
    readonly property real fSwap: conta(d.fSwap)
    Rot { k: m.k; tam: 11.5; x: 0; y: 0; text: "RAM  " + Math.round(m.d.fRam * 100) + " %"; color: m.d.fRam >= m.d.limiar ? Cores.alerta : Cores.texto }
    Rot { k: m.k; tam: 11.5; x: m.wr + m.u(6); y: 0; text: "SWAP  " + Math.round(m.d.fSwap * 100) + " %"; color: Cores.texto }
    Item {
        y: m.u(18); width: m.width; height: m.u(30)
        Hachura { x: 0; width: Math.round(m.wr * m.fRam); height: parent.height
                  passo: Math.max(5, m.u(7)); traco: Math.max(2, m.u(3))
                  cor: m.d.fRam >= m.d.limiar ? Cores.alerta : Cores.texto }
        Hachura { x: m.wr; width: Math.round((m.width - m.wr) * m.fSwap); height: parent.height
                  passo: Math.max(5, m.u(7)); traco: Math.max(2, m.u(3)); cor: Cores.destaque }
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: Cores.texto; border.width: m.lw(1.5) }
        Rectangle { x: m.wr; width: m.lw(1.5); height: parent.height; color: Cores.texto }
        Repeater {
            model: [0.25, 0.5, 0.75]
            Rectangle { required property var modelData; x: Math.round(m.wr * modelData); width: 1; height: m.u(5); color: Cores.alfa(Cores.texto, 0.6) }
        }
    }
    Val { k: m.k; x: 0; y: m.u(56); text: "RAM  " + m.d.bytes(m.d.memUsada) + " / " + m.d.bytes(m.d.memTotal) }
    Val { k: m.k; x: 0; y: m.u(74); text: "SWAP " + m.d.bytes(m.d.swapUsada) + " / " + m.d.bytes(m.d.swapTotal); color: Cores.texto2 }
    Rot { k: m.k; x: 0; y: m.u(98); text: "TOTAL (RAM + SWAP)" }
    Text {
        anchors.right: parent.right; y: m.u(84)
        text: Math.round(m.conta(m.d.fTotal) * 100) + " %"
        font.family: Cores.fIdentidade; font.pixelSize: m.fi(24); font.weight: Font.Medium
        color: Cores.texto
    }
}
