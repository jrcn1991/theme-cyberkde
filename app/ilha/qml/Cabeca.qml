import QtQuick

// Abas + fixar, silêncio e cafeína; com um anúncio vivo, ele toma o lugar dos botões.
Item {
    id: c
    property var ui
    property string aba: "inicio"
    signal escolher(string id)
    height: 42
    readonly property var abas: [
        { id: "inicio", nome: "Início", g: "House" }, { id: "modulos", nome: "Painéis", g: "GridFour" },
        { id: "gaveta", nome: "Gaveta", g: "Tray" }, { id: "janelas", nome: "Janelas", g: "AppWindow" },
        { id: "avisos", nome: "Avisos", g: "BellRinging" }, { id: "clips", nome: "Cópias", g: "Clipboard" },
        { id: "nota", nome: "Nota", g: "NotePencil" }
    ]
    function badge(id) {
        const s = c.ui.snap
        return id === "gaveta" ? (ilha.gaveta || []).length : id === "avisos" ? (s ? (s.notices || []).length : 0) : id === "clips" ? (s ? (s.clips || []).length : 0) : 0
    }
    Rectangle {
        id: barra
        x: 16; y: 10; height: 34; radius: c.ui.raioAba
        width: fileira.width + 6
        color: c.ui.tema.hover
        // a cápsula segue a aba ativa
        Rectangle {
            id: capsula
            y: 3; height: 28; radius: Math.min(14, c.ui.raioAba); color: c.ui.tema.ativo
            readonly property Item alvo: { const i = c.abas.findIndex(a => a.id === c.aba); return rep.count > i && i >= 0 ? rep.itemAt(i) : null }
            x: alvo ? alvo.x + 3 : 3
            width: alvo ? alvo.width : 0
            Behavior on x { NumberAnimation { duration: c.ui.tema.reduzir ? 0 : 320; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: c.ui.tema.reduzir ? 0 : 320; easing.type: Easing.OutCubic } }
        }
        Row {
            id: fileira
            x: 3; y: 3; spacing: 2
            Repeater {
                id: rep
                model: c.abas
                Item {
                    id: ab
                    required property var modelData
                    readonly property bool sel: modelData.id === c.aba
                    // largura fixa: nada anda sob o ponteiro; o nome vem na dica
                    width: 36; height: 28
                    Glifo { x: 11; anchors.verticalCenter: parent.verticalCenter; nome: ab.modelData.g; tamanho: 14; cheio: ab.sel; cor: ab.sel ? c.ui.tema.texto : c.ui.tema.texto2 }
                    Rectangle {
                        readonly property int n: c.badge(ab.modelData.id)
                        visible: n > 0
                        x: 19; y: 1; height: 12; radius: Math.min(6, c.ui.raioAba); width: Math.max(12, tb.implicitWidth + 6)
                        color: c.ui.tema.acao
                        Text { id: tb; anchors.centerIn: parent; text: parent.n > 99 ? "99+" : parent.n; color: c.ui.tema.ligadoTexto; font.family: c.ui.tema.fonte; font.pixelSize: 9; font.weight: Font.DemiBold }
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.escolher(ab.modelData.id); onContainsMouseChanged: c.ui.pedirDica(containsMouse ? c.ui.txt(ab.modelData.nome) : "", ab) }
                }
            }
        }
    }
    // o anúncio vivo, com a ilha aberta
    Anuncio {
        visible: !!c.ui.eventoVivo
        anchors.right: parent.right; anchors.rightMargin: 16; y: 16
        tema: c.ui.tema; ev: c.ui.eventoVivo || ({})
    }
    Row {
        visible: !c.ui.eventoVivo
        anchors.right: parent.right; anchors.rightMargin: 16; y: 14
        spacing: 2
        readonly property bool silencio: c.ui.ligado("kde", "silencio")
        readonly property bool cafeina: c.ui.ligado("kde", "cafeina")
        Acao { ui: c.ui; dica: c.ui.txt(c.ui.fixa ? "Soltar (fecha quando o mouse sai)" : "Segurar aberta"); glifo: "PushPin"; cheio: c.ui.fixa; ativa: c.ui.fixa; onClicado: c.ui.fixa = !c.ui.fixa }
        Acao { ui: c.ui; dica: c.ui.txt("Não perturbe") + ": " + c.ui.txt(parent.silencio ? "ligado" : "desligado"); glifo: parent.silencio ? "BellSlash" : "Bell"; cheio: parent.silencio; ativa: parent.silencio; pendente: c.ui.pendente("silencio-alternar"); onClicado: c.ui.agir("silencio-alternar") }
        Acao { ui: c.ui; dica: c.ui.txt("Cafeína") + ": " + c.ui.txt(parent.cafeina ? "ligada" : "desligada"); glifo: "Coffee"; cheio: parent.cafeina; ativa: parent.cafeina; pendente: c.ui.pendente("cafeina-alternar"); onClicado: c.ui.agir("cafeina-alternar") }
    }
}
