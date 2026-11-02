import QtQuick
import "comum"

// Equalizador "SOUND MASTER" do jukebox: 12 bandas (40 Hz … 18 kHz) de segmentos. Aceso = nível; uma
// TAMPA de pico (na cor secundária) que cai devagar; o resto da coluna fica apagado (a cor bem fraca).
// "pontos": cada segmento vira uma fileira de pontos (o visor do rádio de neon). Rótulos de frequência em
// cima e embaixo quando há altura. Os níveis vêm do Espectro (sintético ou real).
Item {
    id: q
    property var niveis: []
    property bool rotulos: true
    property bool rotulosBaixo: false
    property bool pontos: false
    property color cor: Cores.destaque
    property color corPico: Cores.secundaria
    property real alturaSeg: pontos ? 4 : 6
    property real vaoSeg: pontos ? 3 : 3
    property real vaoBanda: 0.28                 // fração da largura de cada coluna entre colunas
    readonly property var nomes: ["40HZ", "100HZ", "300HZ", "600HZ", "1KHZ", "2KHZ", "4KHZ", "6KHZ", "9KHZ", "12KHZ", "16KHZ", "18KHZ"]
    readonly property real hRot: rotulos && height > 70 ? 13 : 0
    readonly property real hRotB: rotulosBaixo && height > 110 ? 13 : 0
    readonly property int nSeg: Math.max(3, Math.floor((height - hRot - hRotB + vaoSeg) / (alturaSeg + vaoSeg)))
    readonly property real largCol: width / 12

    // picos: sobem com o nível e caem devagar (≈ 1 segmento a cada 90 ms)
    property var picos: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    onNiveisChanged: {
        let p = picos.slice()
        for (let i = 0; i < 12; i++) p[i] = Math.max((niveis[i] || 0), p[i] - 0.015)
        picos = p
    }

    Repeater {
        model: 12
        Item {
            id: col
            required property int index
            readonly property real nivel: q.niveis[index] || 0
            readonly property int acesos: Math.round(nivel * q.nSeg)
            readonly property int topo: Math.min(q.nSeg - 1, Math.round((q.picos[index] || 0) * q.nSeg))
            x: index * q.largCol + q.largCol * q.vaoBanda / 2
            width: q.largCol * (1 - q.vaoBanda); height: q.height
            Text {
                visible: q.hRot > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: q.nomes[col.index]; font.family: Cores.fMono; font.pixelSize: 8; color: Cores.texto2
            }
            Text {
                visible: q.hRotB > 0
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                text: q.nomes[col.index]; font.family: Cores.fMono; font.pixelSize: 8; color: Cores.texto3
            }
            Repeater {
                model: q.nSeg
                Item {
                    required property int index                  // 0 = o de baixo
                    readonly property bool aceso: index < col.acesos
                    readonly property bool pico: index === col.topo && col.topo > 0
                    y: q.height - q.hRotB - (index + 1) * (q.alturaSeg + q.vaoSeg) + q.vaoSeg
                    width: col.width; height: q.alturaSeg
                    readonly property color c: pico ? q.corPico : q.cor
                    readonly property real a: pico ? 1 : aceso ? 0.55 + 0.45 * index / q.nSeg : 0.13
                    // segmento: barra levemente inclinada (como os do jukebox) ou fileira de pontos
                    Rectangle {
                        visible: !q.pontos
                        anchors.fill: parent; radius: height / 2
                        color: Cores.alfa(parent.c, parent.a)
                        antialiasing: true
                    }
                    Row {
                        visible: q.pontos
                        anchors.centerIn: parent
                        spacing: Math.max(1, q.alturaSeg * 0.5)
                        Repeater {
                            model: Math.max(1, Math.floor((col.width + q.alturaSeg * 0.5) / (q.alturaSeg * 1.5)))
                            Rectangle { width: q.alturaSeg; height: q.alturaSeg; radius: q.alturaSeg / 2; color: Cores.alfa(parent.parent.c, parent.parent.a) }
                        }
                    }
                }
            }
        }
    }
}
