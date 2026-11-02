import QtQuick

// Layout "trilho": coluna de 112 px com as abas nomeadas e as três alternâncias embaixo.
Column {
    id: t
    property var ui
    width: 112
    spacing: 2
    topPadding: 12
    Repeater {
        model: [{ id: "inicio", nome: "Início", g: "House" }, { id: "modulos", nome: "Painéis", g: "GridFour" }, { id: "gaveta", nome: "Gaveta", g: "Tray" },
                { id: "janelas", nome: "Janelas", g: "AppWindow" }, { id: "avisos", nome: "Avisos", g: "BellRinging" }, { id: "clips", nome: "Cópias", g: "Clipboard" }, { id: "nota", nome: "Nota", g: "NotePencil" }]
        Item {
            id: it
            required property var modelData
            readonly property bool sel: modelData.id === t.ui.aba
            x: 8; width: 100; height: 30
            Rectangle { anchors.fill: parent; radius: t.ui.tema.raioControle; color: it.sel ? t.ui.tema.ativo : ma.containsMouse ? t.ui.tema.hover : "transparent" }
            Rectangle { visible: it.sel; width: 2; height: parent.height - 8; y: 4; color: t.ui.tema.acao }
            Glifo { x: 10; anchors.verticalCenter: parent.verticalCenter; nome: it.modelData.g; cheio: it.sel; cor: it.sel ? t.ui.tema.texto : t.ui.tema.texto2 }
            Text { x: 30; anchors.verticalCenter: parent.verticalCenter; text: t.ui.txt(it.modelData.nome); color: it.sel ? t.ui.tema.texto : t.ui.tema.texto2; font.family: t.ui.tema.fonte; font.pixelSize: 13 }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.ui.escolherAba(it.modelData.id) }
        }
    }
    Row {
        x: 10; topPadding: 6; spacing: 2
        readonly property bool silencio: t.ui.ligado("kde", "silencio")
        readonly property bool cafeina: t.ui.ligado("kde", "cafeina")
        Acao { ui: t.ui; dica: t.ui.txt("Segurar aberta"); glifo: "PushPin"; cheio: t.ui.fixa; ativa: t.ui.fixa; onClicado: t.ui.fixa = !t.ui.fixa }
        Acao { ui: t.ui; dica: t.ui.txt("Não perturbe"); glifo: parent.silencio ? "BellSlash" : "Bell"; ativa: parent.silencio; onClicado: t.ui.agir("silencio-alternar") }
        Acao { ui: t.ui; dica: t.ui.txt("Cafeína"); glifo: "Coffee"; ativa: parent.cafeina; onClicado: t.ui.agir("cafeina-alternar") }
    }
}
