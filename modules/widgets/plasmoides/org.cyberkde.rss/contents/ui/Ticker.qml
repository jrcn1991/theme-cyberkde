import QtQuick
import "comum"

// Faixa de manchetes rolando (tamanho pequeno das Notícias). Só anda quando está visível; com
// movimento mínimo, troca a manchete a cada 6 s, sem rolar. Clique numa manchete abre a notícia.
Item {
    id: tk
    property var noticias: []
    property var lidas: ({})
    property bool en: false
    signal abrir(var n)
    clip: true

    // não lidas primeiro (até 12); sem nenhuma não lida, as mais recentes
    readonly property var fila: {
        const n = noticias.filter(x => !lidas[x.id])
        return (n.length ? n : noticias).slice(0, 12)
    }
    readonly property bool rolar: !Cores.reduzir && fila.length > 0 && tk.visible && tk.width > 0

    Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.fundo, 0.55) }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Cores.alfa(Cores.destaque, 0.5) }

    Row {
        id: faixa
        visible: tk.rolar
        height: parent.height
        Repeater {
            model: tk.rolar ? 2 : 0                          // duas cópias: a volta não tem emenda
            Row {
                height: faixa.height
                Repeater {
                    model: tk.fila
                    Item {
                        required property var modelData
                        width: rotulo.implicitWidth + 26; height: faixa.height
                        Text {
                            id: rotulo
                            anchors.verticalCenter: parent.verticalCenter
                            text: "<b>" + modelData.fonte.toUpperCase().replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</b>  "
                                  + modelData.titulo.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            textFormat: Text.StyledText
                            font.family: Cores.fTexto; font.pixelSize: 13
                            color: tk.lidas[modelData.id] ? Cores.texto2 : Cores.texto
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "◆"; font.pixelSize: 8; color: Cores.destaque
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tk.abrir(modelData) }
                    }
                }
            }
        }
        NumberAnimation on x {
            id: anda
            running: tk.rolar && faixa.width > 0
            loops: Animation.Infinite
            from: 0
            to: -faixa.width / 2
            duration: Math.max(4000, faixa.width / 2 / 60 * 1000)   // ~60 px/s
        }
        onWidthChanged: if (anda.running) anda.restart()
    }

    // movimento mínimo: uma manchete por vez, trocando a cada 6 s
    property int _i: 0
    Timer { interval: 6000; running: Cores.reduzir && tk.fila.length > 1 && tk.visible; repeat: true; onTriggered: tk._i = (tk._i + 1) % tk.fila.length }
    Text {
        visible: !tk.rolar && tk.fila.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        elide: Text.ElideRight
        readonly property var n: tk.fila[Math.min(tk._i, tk.fila.length - 1)] || null
        text: n ? n.fonte.toUpperCase() + "  " + n.titulo : ""
        textFormat: Text.PlainText
        font.family: Cores.fTexto; font.pixelSize: 13
        color: Cores.texto
        MouseArea { anchors.fill: parent; onClicked: if (parent.n) tk.abrir(parent.n) }
    }
    Text {
        visible: tk.fila.length === 0
        anchors.verticalCenter: parent.verticalCenter
        text: tk.en ? "Tuning in…" : "Sintonizando…"
        font.family: Cores.fTexto; font.pixelSize: 12
        color: Cores.texto3
    }
}
