import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "comum"

// Uma nota como "datashard interceptado": faixa de código, marcador na cor da nota, corpo na fonte
// do sistema (ou checklist) e carimbo de interceptação. Ferramentas aparecem ao passar o mouse.
Item {
    id: c
    property var nota: ({})
    property int posicao: 0
    property int total: 1
    property bool editando: false
    property bool en: false
    property real opacidade: 0.95
    function t(pt, ing) { return en ? ing : pt }

    signal salvar(string texto)
    signal fixar()
    signal trocarCor()
    signal alternarChecklist()
    signal mover(int delta)
    signal apagar()
    signal marcar(int linha)
    signal editar()
    signal encerrarEdicao()

    readonly property color cor: Cores.papel(nota.cor)
    readonly property var linhas: (nota.texto || "").split("\n")
    readonly property string codigo: "0x" + ((nota.id || 0) % 65536).toString(16).toUpperCase().padStart(4, "0")
    readonly property bool _hover: hover.hovered || editando

    implicitHeight: col.implicitHeight + 22
    HoverHandler { id: hover }

    // montagem ao surgir
    property real acender: 1
    Component.onCompleted: {
        if (Cores.reduzir) return
        acender = 0
        surgir.start()
    }
    SequentialAnimation {
        id: surgir
        PropertyAction { target: c; property: "acender"; value: 0.6 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: c; property: "acender"; value: 0.1 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: c; property: "acender"; value: 1 }
    }
    opacity: acender

    Chanfro {
        anchors.fill: parent
        corte: 10
        preenchimento: Cores.alfa(Cores.mistura(Cores.elevado, c.cor, 0.05), Cores.alfaSuperficie(Math.max(c.opacidade, 0.85)))
        borda: Cores.alfa(c.cor, c._hover ? 0.85 : 0.45)
    }
    Rectangle { x: 0; y: 12; width: 3; height: Math.min(28, parent.height - 24); color: c.cor }
    // faixa de "dados" no topo
    Rectangle { x: 14; y: 6; width: parent.width - 28; height: 1; color: Cores.alfa(c.cor, 0.25) }

    Column {
        id: col
        x: 12; y: 10
        width: parent.width - 22
        spacing: 6

        // cabeçalho: código e ferramentas
        Item {
            width: parent.width; height: 18
            Row {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Codigo { text: (c._hover ? "" : "DATA.SHARD // ") + c.codigo; color: c.cor; tamanho: 8; font.bold: true }
                Kirigami.Icon {
                    visible: !!c.nota.fixada
                    width: 11; height: 11
                    anchors.verticalCenter: parent.verticalCenter
                    source: "window-pin"; isMask: true; color: c.cor
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: c._hover
                BotaoIcone { tamanho: 18; icone: "window-pin"; ativo: !!c.nota.fixada; dica: c.t("Fixar no topo", "Pin to top"); onClicado: c.fixar() }
                BotaoIcone {
                    tamanho: 18; dica: c.t("Cor", "Color"); onClicado: c.trocarCor()
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; rotation: 45; color: Cores.papel(c.nota.cor === "destaque" ? "secundaria" : c.nota.cor === "secundaria" ? "alerta" : "destaque") }
                }
                BotaoIcone { tamanho: 18; glifo: "✓"; ativo: !!c.nota.checklist; dica: c.t("Checklist", "Checklist"); onClicado: c.alternarChecklist() }
                BotaoIcone { tamanho: 18; icone: "go-previous"; habilitado: c.posicao > 0; dica: c.t("Mover para trás", "Move back"); onClicado: c.mover(-1) }
                BotaoIcone { tamanho: 18; icone: "go-next"; habilitado: c.posicao < c.total - 1; dica: c.t("Mover para frente", "Move forward"); onClicado: c.mover(1) }
                BotaoIcone {
                    id: lixo
                    property bool confirmar: false
                    tamanho: 18
                    icone: confirmar ? "" : "edit-delete"
                    glifo: confirmar ? "?" : ""
                    ativo: confirmar
                    dica: confirmar ? c.t("Clique de novo para apagar", "Click again to delete") : c.t("Apagar", "Delete")
                    onClicado: { if (confirmar) c.apagar(); else { confirmar = true; desarmar.restart() } }
                    Timer { id: desarmar; interval: 3000; onTriggered: lixo.confirmar = false }
                }
            }
        }

        // ---- corpo: leitura
        Text {
            visible: !c.editando && !c.nota.checklist
            width: parent.width
            text: c.nota.texto ? c.nota.texto : c.t("Nota vazia — clique para escrever", "Empty note — click to write")
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font.family: Cores.fTexto; font.pixelSize: 13
            lineHeight: 1.15
            color: c.nota.texto ? Cores.texto : Cores.texto3
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: c.editar() }
        }
        // ---- corpo: checklist
        Column {
            visible: !c.editando && !!c.nota.checklist
            width: parent.width
            spacing: 4
            Repeater {
                model: c.nota.checklist ? c.linhas : []
                Item {
                    id: item
                    required property string modelData
                    required property int index
                    readonly property bool feito: /^\[x\]\s?/i.test(modelData)
                    readonly property string rotulo: modelData.replace(/^\[[ x]\]\s?/i, "")
                    visible: rotulo.trim() !== "" || c.linhas.length === 1
                    width: parent.width; height: visible ? Math.max(18, tx.implicitHeight) : 0
                    Rectangle {
                        id: caixa
                        y: 3; width: 12; height: 12
                        color: item.feito ? Cores.alfa(c.cor, 0.25) : "transparent"
                        border.color: item.feito ? c.cor : Cores.texto3
                        Text { anchors.centerIn: parent; visible: item.feito; text: "✓"; font.pixelSize: 10; font.bold: true; color: c.cor }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: c.marcar(item.index) }
                    }
                    Text {
                        id: tx
                        x: 20; width: parent.width - 20
                        text: item.rotulo || c.t("(item vazio)", "(empty item)")
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: Cores.fTexto; font.pixelSize: 13
                        font.strikeout: item.feito
                        color: item.feito ? Cores.texto3 : Cores.texto
                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: c.editar() }
                    }
                }
            }
        }
        // ---- corpo: edição
        QQC2.TextArea {
            id: area
            visible: c.editando
            width: parent.width
            wrapMode: TextEdit.Wrap
            font.family: Cores.fTexto; font.pixelSize: 13
            color: Cores.texto
            selectionColor: Cores.alfa(c.cor, 0.45)
            selectedTextColor: Cores.texto
            placeholderText: c.nota.checklist ? c.t("Um item por linha", "One item per line") : c.t("Escreva a nota…", "Write the note…")
            placeholderTextColor: Cores.texto3
            background: Rectangle { color: Cores.escuro; border.color: Cores.alfa(c.cor, 0.6) }
            Keys.onEscapePressed: c.encerrarEdicao()
            onActiveFocusChanged: if (!activeFocus && c.editando) c.encerrarEdicao()
        }
        onVisibleChanged: {}

        // carimbo
        Codigo {
            width: parent.width
            tamanho: 8
            text: c.editando ? c.t("EDITANDO · ESC OU CLIQUE FORA PARA SALVAR", "EDITING · ESC OR CLICK OUTSIDE TO SAVE")
                : c.t("INTERCEPTADO ", "INTERCEPTED ") + Qt.formatDateTime(new Date(c.nota.criada || 0), "dd.MM · HH:mm")
                  + (c.nota.checklist ? " · " + c.linhas.filter(l => /^\[x\]/i.test(l)).length + "/" + c.linhas.filter(l => l.replace(/^\[[ x]\]\s?/i, "").trim() !== "").length : "")
        }
    }

    // abrir/fechar a edição: no checklist, edita sem as marcas e as devolve ao salvar
    onEditandoChanged: {
        if (editando) {
            area.text = nota.checklist ? linhas.map(l => l.replace(/^\[[ x]\]\s?/i, "")).join("\n") : (nota.texto || "")
            area.forceActiveFocus()
            area.cursorPosition = area.length
        } else {
            let novo = area.text
            if (nota.checklist) {
                const feitos = new Set(linhas.filter(l => /^\[x\]/i.test(l)).map(l => l.replace(/^\[x\]\s?/i, "")))
                novo = novo.split("\n").map(l => (feitos.has(l) ? "[x] " : "[ ] ") + l).join("\n")
            }
            if (novo !== (nota.texto || "")) salvar(novo)
        }
    }
}
