import QtQuick
import "comum"

// DISCOS: as 4 unidades mais cheias; a altura da carta é a ocupação; % , nome e espaço livre embaixo.
// Clique numa unidade: abre a pasta no Dolphin.
Modulo {
    id: m
    titulo: d.t("Discos", "Drives"); codigo: d.t("ocupação", "usage")
    rodape: d.discos.length + d.t(" unidades · clique abre a pasta", " drives · click opens the folder")
    dica: d.t("Ocupação das unidades montadas (df), da mais cheia para a menos cheia; a altura da carta é a ocupação. Clique para abrir a pasta no Dolphin.",
              "Usage of the mounted drives (df), fullest first; the card height is the usage. Click to open the folder in Dolphin.")
    readonly property var lista: d.discos.slice().sort((a, b) => b.frac - a.frac).slice(0, 4)
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property var un: m.lista[index] || null
            readonly property bool cheio: un && un.frac >= m.d.limiar
            readonly property color cor: cheio ? Cores.alerta : Cores.texto
            x: Math.round(index * m.width / 4); y: 0
            width: Math.round(m.width / 4) - m.u(6); height: m.u(124)
            visible: !!un
            Rectangle {
                anchors.bottom: parent.bottom; anchors.bottomMargin: m.u(46)
                width: parent.width
                height: Math.max(m.u(6), Math.round(m.u(72) * (parent.un ? parent.un.frac : 0) * Math.min(1, m.montado * 1.3)))
                color: parent.cor
                Behavior on height { enabled: !Cores.reduzir; NumberAnimation { duration: Cores.d(300) } }
            }
            Rectangle { y: m.u(4); width: parent.width; height: 1; color: Cores.alfa(Cores.texto, 0.3) }
            Text {
                y: m.u(80); width: parent.width; elide: Text.ElideRight
                text: parent.un ? Math.round(parent.un.frac * 100) + " %" : ""
                font.family: Cores.fIdentidade; font.pixelSize: m.fi(13); font.weight: Font.Medium
                color: parent.cor
            }
            Text {
                y: m.u(98); width: parent.width; elide: Text.ElideRight
                text: parent.un ? parent.un.nome : ""
                font.family: Cores.fMono; font.pixelSize: m.fi(10.5); font.weight: Font.Bold
                color: Cores.texto2
            }
            Text {
                y: m.u(98) + m.fi(10.5) + m.u(2); width: parent.width; elide: Text.ElideRight
                text: parent.un ? m.d.bytes(parent.un.livre) + m.d.t(" livre", " free") : ""
                font.family: Cores.fMono; font.pixelSize: m.fr(9.5)
                color: Cores.texto3
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: m.d.abrir(parent.un) }
        }
    }
}
