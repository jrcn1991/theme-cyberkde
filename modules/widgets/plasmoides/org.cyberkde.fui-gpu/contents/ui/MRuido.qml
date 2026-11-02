import QtQuick
import "comum"

// Coluna de ruído (os blocos pontilhados da referência): tipo "rx" = descida da rede, "io" = disco.
Modulo {
    id: m
    property string tipo: "rx"
    titulo: tipo === "rx" ? "RX" : "I/O"
    readonly property real valor: tipo === "rx" ? d.desce : d.esLeitura + d.esEscrita
    readonly property real niv: d.nivel(valor)
    dica: (tipo === "rx" ? d.t("Descida da rede: ", "Network download: ") : d.t("Disco (leitura + escrita): ", "Disk (read + write): "))
          + d.taxa(valor) + d.t(". A densidade dos pontos acompanha a taxa.", ". Dot density follows the rate.")
    Ruido { k: m.k; width: parent.width; height: m.u(96); nivel: m.niv * Math.min(1, m.montado * 1.5); semente: m.d.tique + (m.tipo === "rx" ? 0 : 7) }
    Rot { k: m.k; anchors.horizontalCenter: parent.horizontalCenter; y: m.u(102); text: Math.round(m.niv * 100) + "%"; color: Cores.texto }
}
