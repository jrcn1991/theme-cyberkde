import QtQuick
import "comum"

// E/S POR DISCO: leitura (barra cheia) e escrita (listrada) de cada disco físico, com os valores.
Modulo {
    id: m
    property bool logo: true
    titulo: "E/S"; codigo: d.t("por disco", "per drive")
    rodape: d.t("■ leitura  ▨ escrita · 100 % = maior taxa recente", "■ read  ▨ write · 100 % = highest recent rate")
    dica: d.t("Leitura e escrita de cada disco físico agora (disk/<disco>/read e write do ksystemstats). As barras usam a maior taxa recente como 100 %.",
              "Read and write rate of each physical disk right now (ksystemstats disk/<disk>/read and write). Bars use the highest recent rate as 100 %.")
    readonly property int wb: logo ? width - u(64) : width
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property var e: m.d.es[index] || null
            y: index * m.u(31); width: m.wb; height: m.u(30)
            visible: !!e
            Text {
                text: parent.e ? parent.e.pk + " " + parent.e.alvo : ""
                width: Math.max(0, m.wb - taxas.implicitWidth - m.u(8)); elide: Text.ElideRight
                font.family: Cores.fMono; font.pixelSize: m.fr(10); font.weight: Font.Bold; color: Cores.texto2
            }
            Text {
                id: taxas
                anchors.right: parent.right
                text: parent.e ? "L " + m.d.taxa(parent.e.rb) + "  E " + m.d.taxa(parent.e.wb) : ""
                font.family: Cores.fMono; font.pixelSize: m.fr(10); font.weight: Font.Bold; color: Cores.texto
            }
            Rectangle { y: m.u(15); height: Math.max(3, m.u(5)); width: Math.max(1, Math.round(m.wb * (parent.e ? parent.e.r : 0) * Math.min(1, m.montado * 1.3))); color: Cores.texto
                        Behavior on width { enabled: !Cores.reduzir; NumberAnimation { duration: Cores.d(250) } } }
            Hachura { y: m.u(22); height: Math.max(3, m.u(5)); passo: Math.max(4, m.u(7)); traco: Math.max(2, m.u(3)); cor: Cores.destaque
                      width: Math.max(1, Math.round(m.wb * (parent.e ? parent.e.w : 0) * Math.min(1, m.montado * 1.3)))
                      Behavior on width { enabled: !Cores.reduzir; NumberAnimation { duration: Cores.d(250) } } }
        }
    }
    Logo { visible: m.logo; x: m.width - m.u(54); y: m.u(64); width: m.u(54); height: m.u(58); d: m.d; k: m.k }
}
