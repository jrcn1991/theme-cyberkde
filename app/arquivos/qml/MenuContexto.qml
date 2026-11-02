import QtQuick
import "../../qml"

// Menu de contexto do DATASHARD: painel chanfrado com entradas {texto, atalho, acao, perigo, sub,
// desabilitado} e separadores {sep: true}. Submenu abre ao lado (Abrir com ▸, Compactar ▸). Teclado:
// ↑/↓, Enter, → abre submenu, ←/Esc fecha. Clique fora fecha. Montagem curta (traço + acender).
Item {
    id: m
    anchors.fill: parent
    visible: aberto
    z: 80
    property bool aberto: false
    property var itens: []
    property point pos: Qt.point(0, 0)
    property int foco: -1
    property var sub: null               // {itens, y}
    property int focoSub: -1

    function abrir(lista, p) {
        itens = lista; pos = p; foco = -1; sub = null; focoSub = -1
        aberto = true
        teclado.forceActiveFocus()
        if (!Tema.reduzir) { principal.traco = 0; montagem.restart() }
    }
    function fechar() { aberto = false; sub = null; Ds.janela.focarArea() }
    function executar(e) {
        if (!e || e.sep || e.desabilitado) return
        if (e.sub) { abrirSub(itens.indexOf(e)); return }
        fechar()
        if (e.acao) e.acao()
    }
    function abrirSub(i) {
        const e = itens[i]
        if (!e || !e.sub) return
        const it = principal.repetidor.itemAt(i)
        sub = { itens: e.sub, y: it ? it.y : 0 }
        focoSub = 0
    }
    function proximo(lista, f, d) {
        if (!lista.length) return -1
        let k = f
        for (let n = 0; n < lista.length; n++) {
            k = (k + d + lista.length) % lista.length
            if (!lista[k].sep && !lista[k].desabilitado) return k
        }
        return f
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: m.fechar() }

    Item {
        id: teclado
        focus: m.aberto
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { if (m.sub) m.sub = null; else m.fechar() }
            else if (e.key === Qt.Key_Left) m.sub = null
            else if (m.sub) {
                if (e.key === Qt.Key_Down) m.focoSub = m.proximo(m.sub.itens, m.focoSub, 1)
                else if (e.key === Qt.Key_Up) m.focoSub = m.proximo(m.sub.itens, m.focoSub, -1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) m.executar(m.sub.itens[m.focoSub])
            } else {
                if (e.key === Qt.Key_Down) m.foco = m.proximo(m.itens, m.foco, 1)
                else if (e.key === Qt.Key_Up) m.foco = m.proximo(m.itens, m.foco, -1)
                else if (e.key === Qt.Key_Right) m.abrirSub(m.foco)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) m.executar(m.itens[m.foco])
            }
            e.accepted = true
        }
    }

    component Lista: Item {
        id: li
        property var entradas: []
        property int focoL: -1
        property bool ehSub: false
        property alias painel: chf
        property alias repetidor: rr
        // largura pelo maior rótulo + atalho (U14): de 250 a 420 px; o que passar disso corta no meio
        // (FontMetrics.advanceWidth é uma função pura: mexer no texto de um TextMetrics dentro do binding
        // fazia laço de binding)
        FontMetrics { id: fmR; font.family: Tema.fTexto; font.pixelSize: 13 }
        FontMetrics { id: fmA; font.family: Tema.fMono; font.pixelSize: 10 }
        readonly property real precisa: {
            let mr = 0, ma = 0
            for (const e of entradas || []) {
                if (e.sep) continue
                mr = Math.max(mr, fmR.advanceWidth(e.texto || ""))
                ma = Math.max(ma, fmA.advanceWidth(e.sub ? "▸" : (e.atalho || "")))
            }
            return mr + ma + 48 + 12
        }
        width: Math.max(250, Math.min(420, precisa))
        height: colL.implicitHeight + 12
        property real traco: 1
        Chanfro { id: chf; anchors.fill: parent; corte: 8; preenchimento: Tema.elevado; borda: Tema.alfa(Tema.destaque, 0.7); traco: li.traco }
        Rectangle { x: 0; y: 8; width: 3; height: 18; color: Tema.destaque }
        MouseArea { anchors.fill: parent }    // não fecha ao clicar dentro
        Column {
            id: colL
            x: 6; y: 6
            width: parent.width - 12
            Repeater {
                id: rr
                model: li.entradas
                Item {
                    id: en
                    required property int index
                    required property var modelData
                    width: colL.width
                    height: modelData.sep ? 9 : 26
                    readonly property bool focado: li.focoL === index || me.containsMouse
                    Rectangle { visible: en.modelData.sep === true; y: 4; width: parent.width; height: 1; color: Tema.alfa(Tema.linha, 0.9) }
                    Rectangle {
                        visible: !en.modelData.sep && en.focado && !en.modelData.desabilitado
                        anchors.fill: parent
                        color: en.modelData.perigo ? Tema.alfa(Tema.alerta, 0.18) : Tema.selecao
                    }
                    Text {
                        visible: !en.modelData.sep
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20 - atl.implicitWidth - 14
                        text: en.modelData.texto || ""; elide: Text.ElideMiddle
                        font.family: Tema.fTexto; font.pixelSize: 13
                        color: en.modelData.desabilitado ? Tema.texto3 : en.modelData.perigo ? Tema.alerta : Tema.texto
                    }
                    Text {
                        id: atl
                        visible: !en.modelData.sep
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        text: en.modelData.sub ? "▸" : (en.modelData.atalho || "")
                        font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3
                    }
                    MouseArea {
                        id: me
                        anchors.fill: parent
                        enabled: !en.modelData.sep
                        hoverEnabled: true
                        onEntered: { if (li.ehSub) m.focoSub = en.index; else { m.foco = en.index; if (en.modelData.sub) m.abrirSub(en.index); else m.sub = null } }
                        onClicked: m.executar(en.modelData)
                    }
                }
            }
        }
    }

    Lista {
        id: principal
        entradas: m.itens
        focoL: m.foco
        x: Math.max(4, Math.min(m.pos.x, m.width - width - 4))
        y: Math.max(4, Math.min(m.pos.y, m.height - height - 4))
    }
    NumberAnimation { id: montagem; target: principal; property: "traco"; from: 0; to: 1; duration: Tema.d(160) }
    Lista {
        visible: !!m.sub
        ehSub: true
        entradas: m.sub ? m.sub.itens : []
        focoL: m.focoSub
        x: principal.x + principal.width + width + 4 > m.width ? principal.x - width - 2 : principal.x + principal.width + 2
        y: Math.max(4, Math.min(principal.y + (m.sub ? m.sub.y : 0), m.height - height - 4))
    }
}
