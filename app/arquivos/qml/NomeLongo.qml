import QtQuick
import "../../qml"

// Nome de arquivo legível: quebra em até "linhas" linhas e, só se ainda não couber, corta NO MEIO
// (mantém o começo e o fim, onde ficam a versão e a extensão: "Keyboard tray v2 … 1306.zip").
// Cortado, o mouse em cima mostra o nome completo numa moldura chanfrada por cima do próprio rótulo.
Item {
    id: n
    property string texto: ""
    property int linhas: 2
    property int tamanho: 12
    property string familia: Tema.fTexto
    property int peso: Font.Normal
    property real espaco: 0
    property color cor: Tema.texto
    property int alinhamento: Text.AlignHCenter
    readonly property bool cortado: mostrado !== texto
    readonly property bool sobre: hh.hovered
    property string mostrado: texto
    implicitHeight: Math.ceil(tamanho * 1.35) * linhas
    z: cheio.visible ? 10 : 0                // o nome inteiro por cima do código e do tamanho que vêm depois

    // corte no meio: a maior quantidade de letras que ainda cabe nas linhas (busca binária)
    function ajustar() {
        med.text = texto
        if (width <= 0 || med.lineCount <= linhas) { mostrado = texto; return }
        let lo = 4, hi = texto.length - 1, melhor = texto.slice(0, 2) + "…" + texto.slice(-2)
        while (lo <= hi) {
            const k = Math.floor((lo + hi) / 2), ini = Math.ceil(k * 0.55), fim = k - ini
            const t = texto.slice(0, ini).replace(/\s+$/, "") + "…" + texto.slice(texto.length - fim).replace(/^\s+/, "")
            med.text = t
            if (med.lineCount <= linhas) { melhor = t; lo = k + 1 } else hi = k - 1
        }
        mostrado = melhor
    }
    onTextoChanged: ajustar()
    onWidthChanged: ajustar()
    onLinhasChanged: ajustar()
    Component.onCompleted: ajustar()

    Text {
        id: med
        visible: false
        width: n.width
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        font.family: n.familia; font.pixelSize: n.tamanho; font.weight: n.peso; font.letterSpacing: n.espaco
    }
    Text {
        width: n.width
        horizontalAlignment: n.alinhamento
        text: n.mostrado
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere; maximumLineCount: n.linhas; elide: Text.ElideRight
        font.family: n.familia; font.pixelSize: n.tamanho; font.weight: n.peso; font.letterSpacing: n.espaco
        color: n.cor
    }
    HoverHandler { id: hh }

    // nome completo (só quando cortado)
    Item {
        id: cheio
        visible: n.cortado && hh.hovered
        z: 100
        x: -8; y: -4
        width: n.width + 16; height: tc.implicitHeight + 12
        Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.fundo, 0.96); borda: Tema.destaque }
        Text {
            id: tc
            x: 8; y: 6; width: parent.width - 16
            horizontalAlignment: n.alinhamento
            text: n.texto
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.family: n.familia; font.pixelSize: n.tamanho; font.weight: n.peso
            color: Tema.texto
        }
    }
}
