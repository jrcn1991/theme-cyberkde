import QtQuick

// Miniatura 16:9 da tela principal com um retângulo por widget do tema que está lá, pela geometria
// (painel.geometriaWidgets). Só visualização: mover e redimensionar continuam no modo de edição.
// Clique num retângulo seleciona o widget. Ligados e não posicionados ainda não aparecem.
Item {
    id: m
    property var geo: ({})
    property var widgets: []
    property string selecionado: ""
    property var filtro: null                // (nome) => bool: só estes entram no mapa
    property var rotulo: null                // (nome) => texto
    signal escolher(string nome)

    readonly property var tela: geo && geo.tela ? geo.tela : [1920, 1080]
    readonly property var itens: {
        const todos = geo && geo.itens ? geo.itens : ({})
        if (!filtro) return todos
        let r = {}
        for (const k in todos) if (filtro(k)) r[k] = todos[k]
        return r
    }
    readonly property var nomes: Object.keys(itens)
    implicitHeight: width * 9 / 16 + 22

    // área da tela dentro da caixa 16:9, na proporção dela
    readonly property real caixaA: width * 9 / 16
    readonly property real esc: Math.min(width / tela[0], caixaA / tela[1])
    readonly property real ox: (width - tela[0] * esc) / 2
    readonly property real oy: (caixaA - tela[1] * esc) / 2

    Chanfro { width: m.width; height: m.caixaA; corte: 8; preenchimento: Tema.mistura(Tema.fundo, "#000000", 0.35); borda: Tema.linha }
    Rectangle {
        x: m.ox; y: m.oy; width: m.tela[0] * m.esc; height: m.tela[1] * m.esc
        color: "transparent"; border.color: Tema.alfa(Tema.texto3, 0.5)
        // grade discreta
        Repeater {
            model: 3
            Rectangle { required property int index; x: (index + 1) * parent.width / 4; width: 1; height: parent.height; color: Tema.alfa(Tema.linha, 0.5) }
        }
    }
    Repeater {
        model: m.nomes
        Item {
            id: r
            required property string modelData
            readonly property var g: m.itens[modelData]
            readonly property bool sel: m.selecionado === modelData
            readonly property var dado: m.widgets.find(w => w.widgetNome === modelData.split("@")[0]) || null
            x: m.ox + g[0] * m.esc; y: m.oy + g[1] * m.esc
            width: Math.max(4, g[2] * m.esc); height: Math.max(4, g[3] * m.esc)
            Rectangle {
                anchors.fill: parent
                color: Tema.alfa(r.sel ? Tema.destaque : Tema.secundaria, r.sel ? 0.35 : 0.16)
                border.color: r.sel ? Tema.destaque : Tema.alfa(Tema.secundaria, 0.7)
                border.width: r.sel ? 2 : 1
            }
            Codigo {
                anchors.centerIn: parent
                width: parent.width - 4; horizontalAlignment: Text.AlignHCenter
                visible: parent.width > 26 && parent.height > 12
                text: (m.rotulo && m.rotulo(r.modelData) || (r.dado ? r.dado.nomeCurto : r.modelData.split("@")[0])).toUpperCase(); tamanho: 7
                color: r.sel ? Tema.texto : Tema.texto2
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: m.escolher(r.modelData) }
        }
    }
    Codigo {
        visible: m.nomes.length === 0
        x: 12; y: m.caixaA / 2 - 6
        width: m.width - 24; horizontalAlignment: Text.AlignHCenter
        text: Txt.t("wg.mapaVazio"); tamanho: 9
    }
    Codigo {
        y: m.caixaA + 6
        text: Txt.t("wg.mapaLegenda", { l: m.tela[0], a: m.tela[1], n: m.nomes.length }); tamanho: 8
    }
}
