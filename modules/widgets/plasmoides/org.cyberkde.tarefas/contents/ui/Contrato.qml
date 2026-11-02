import QtQuick
import QtQuick.Controls as QQC2
import "comum"

// Um contrato (tarefa) no estilo dos gigs do jogo: faixa de código e prioridade, título, contratante,
// prazo e status. Ações ao passar o mouse: avançar status (iniciar → concluir → reabrir), editar, mover,
// apagar (o segundo clique confirma). Ao concluir, o carimbo "CONTRATO CONCLUÍDO" monta por cima.
Item {
    id: c
    property var tarefa: ({})
    property int posicao: 0
    property int total: 1
    property bool editando: false
    property bool en: false
    property real opacidade: 0.95
    function t(pt, ing) { return en ? ing : pt }

    signal salvar(var nova)
    signal avancar()
    signal mover(int delta)
    signal apagar()
    signal editar()
    signal fechar()

    readonly property var prioridades: ["baixa", "media", "alta", "critica"]
    function corPrioridade(p) { return p === "critica" ? Cores.alerta : p === "alta" ? Cores.destaque : p === "media" ? Cores.secundaria : Cores.texto2 }
    function nomePrioridade(p) {
        return ({ baixa: t("BAIXA", "LOW"), media: t("MÉDIA", "MEDIUM"), alta: t("ALTA", "HIGH"), critica: t("CRÍTICA", "CRITICAL") })[p] || t("MÉDIA", "MEDIUM")
    }
    readonly property color cor: corPrioridade(tarefa.prioridade)
    readonly property bool concluido: tarefa.status === "concluido"
    readonly property bool andamento: tarefa.status === "andamento"
    readonly property string codigo: "GIG-" + ((tarefa.id || 0) % 65536).toString(16).toUpperCase().padStart(4, "0")

    // prazo relativo a hoje
    function diasAte(iso) {
        if (!iso) return null
        const p = iso.split("-").map(Number)
        const alvo = new Date(p[0], p[1] - 1, p[2]), h = new Date()
        return Math.round((alvo - new Date(h.getFullYear(), h.getMonth(), h.getDate())) / 86400000)
    }
    readonly property var dias: diasAte(tarefa.prazo)
    readonly property string textoPrazo: dias === null ? "" : concluido ? t("PRAZO ", "DUE ") + dataCurta(tarefa.prazo)
        : dias < 0 ? t("ATRASADO ", "OVERDUE ") + (-dias) + t("D", "D")
        : dias === 0 ? t("PRAZO: HOJE", "DUE: TODAY")
        : dias === 1 ? t("PRAZO: AMANHÃ", "DUE: TOMORROW")
        : t("PRAZO ", "DUE ") + dataCurta(tarefa.prazo) + " · " + dias + "D"
    readonly property color corPrazo: concluido ? Cores.texto3 : dias !== null && dias < 0 ? Cores.alerta : dias !== null && dias <= 2 ? Cores.destaque : Cores.texto2
    function dataCurta(iso) { const p = iso.split("-"); return p[2] + "." + p[1] }

    readonly property bool _hover: hover.hovered || editando
    HoverHandler { id: hover }
    implicitHeight: (editando ? editor.implicitHeight : leitura.implicitHeight) + 20

    // ---- montagem ao surgir e carimbo ao concluir
    property real acender: 1
    property real carimbo: concluido ? 1 : 0
    property bool _pronto: false
    Component.onCompleted: { _pronto = true; if (!Cores.reduzir) { acender = 0; surgir.start() } }
    onConcluidoChanged: if (_pronto && concluido && !Cores.reduzir) { carimbo = 0; animCarimbo.restart() } else carimbo = concluido ? 1 : 0
    SequentialAnimation {
        id: surgir
        PropertyAction { target: c; property: "acender"; value: 0.6 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: c; property: "acender"; value: 0.1 }
        PauseAnimation { duration: Cores.d(40) }
        PropertyAction { target: c; property: "acender"; value: 1 }
    }
    SequentialAnimation {
        id: animCarimbo
        NumberAnimation { target: c; property: "carimbo"; from: 0; to: 1; duration: Cores.d(260); easing.type: Easing.OutBack }
    }
    opacity: acender

    Chanfro {
        anchors.fill: parent
        corte: 10
        preenchimento: Cores.alfa(Cores.mistura(Cores.elevado, c.cor, c.concluido ? 0.0 : 0.05), Cores.alfaSuperficie(Math.max(c.opacidade, 0.85)))
        borda: Cores.alfa(c.concluido ? Cores.linha : c.cor, c._hover ? 0.9 : 0.5)
    }
    Rectangle { x: 0; y: 10; width: 3; height: parent.height - 20; color: c.concluido ? Cores.texto3 : c.cor }

    // ---- leitura
    Column {
        id: leitura
        visible: !c.editando
        x: 12; y: 10
        width: parent.width - 22
        spacing: 4
        opacity: c.concluido ? 0.55 : 1

        Item {
            width: parent.width; height: 16
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Codigo { text: c.codigo; tamanho: 8; color: Cores.texto3; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: tagP.implicitWidth + 8; height: 13
                    color: Cores.alfa(c.cor, 0.15); border.color: c.cor
                    anchors.verticalCenter: parent.verticalCenter
                    Codigo { id: tagP; anchors.centerIn: parent; text: c.nomePrioridade(c.tarefa.prioridade); tamanho: 8; font.bold: true; color: c.cor }
                }
                Codigo {
                    visible: c.andamento
                    text: c.t("● EM ANDAMENTO", "● IN PROGRESS"); tamanho: 8; color: Cores.secundaria
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            // ações
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: c._hover
                BotaoIcone {
                    tamanho: 18
                    glifo: c.concluido ? "↺" : c.andamento ? "✓" : "▶"
                    ativo: c.andamento
                    dica: c.concluido ? c.t("Reabrir", "Reopen") : c.andamento ? c.t("Concluir", "Complete") : c.t("Iniciar", "Start")
                    onClicado: c.avancar()
                }
                BotaoIcone { tamanho: 18; icone: "document-edit"; dica: c.t("Editar", "Edit"); onClicado: c.editar() }
                BotaoIcone { tamanho: 18; icone: "go-up"; habilitado: c.posicao > 0; dica: c.t("Subir", "Move up"); onClicado: c.mover(-1) }
                BotaoIcone { tamanho: 18; icone: "go-down"; habilitado: c.posicao < c.total - 1; dica: c.t("Descer", "Move down"); onClicado: c.mover(1) }
                BotaoIcone {
                    id: lixo
                    property bool confirmar: false
                    tamanho: 18
                    icone: confirmar ? "" : "edit-delete"; glifo: confirmar ? "?" : ""
                    ativo: confirmar
                    dica: confirmar ? c.t("Clique de novo para apagar", "Click again to delete") : c.t("Apagar", "Delete")
                    onClicado: { if (confirmar) c.apagar(); else { confirmar = true; desarmar.restart() } }
                    Timer { id: desarmar; interval: 3000; onTriggered: lixo.confirmar = false }
                }
            }
        }
        Text {
            width: parent.width
            text: c.tarefa.titulo || c.t("Contrato sem título", "Untitled contract")
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: Cores.fTexto; font.pixelSize: 13; font.weight: Font.DemiBold
            font.strikeout: c.concluido
            color: Cores.texto
        }
        Item {
            width: parent.width; height: 14
            Codigo {
                width: parent.width - prazo.implicitWidth - 8
                text: c.tarefa.contratante ? c.t("CONTRATANTE: ", "CLIENT: ") + c.tarefa.contratante.toUpperCase() : ""
                tamanho: 9; color: Cores.texto2
            }
            Codigo { id: prazo; anchors.right: parent.right; text: c.textoPrazo; tamanho: 9; color: c.corPrazo; font.bold: c.dias !== null && c.dias < 0 && !c.concluido }
        }
    }

    // carimbo de concluído
    Item {
        visible: c.concluido && !c.editando
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: selo.implicitWidth + 14; height: 22
        rotation: -6
        scale: 0.6 + 0.4 * c.carimbo
        opacity: c.carimbo < 1 ? (Math.floor(c.carimbo * 12) % 2 ? 0.4 : 1) * c.carimbo : 1
        Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.sucesso, 0.12); border.color: Cores.sucesso; border.width: 2 }
        Codigo { id: selo; anchors.centerIn: parent; text: c.t("CONTRATO CONCLUÍDO", "GIG COMPLETE"); tamanho: 10; font.bold: true; color: Cores.sucesso }
    }

    // ---- edição
    Column {
        id: editor
        visible: c.editando
        x: 12; y: 10
        width: parent.width - 22
        spacing: 6
        property string prioridade: "media"
        function abrir() {
            campoTitulo.text = c.tarefa.titulo || ""
            campoContratante.text = c.tarefa.contratante || ""
            campoPrazo.text = c.tarefa.prazo ? c.tarefa.prazo.split("-").reverse().join("/") : ""
            prioridade = c.tarefa.prioridade || "media"
            campoTitulo.forceActiveFocus()
        }
        function iso(txt) {
            const m = txt.trim().match(/^(\d{1,2})[\/.-](\d{1,2})(?:[\/.-](\d{2,4}))?$/)
            if (!m) return ""
            const ano = m[3] ? (m[3].length === 2 ? 2000 + Number(m[3]) : Number(m[3])) : new Date().getFullYear()
            return ano + "-" + String(m[2]).padStart(2, "0") + "-" + String(m[1]).padStart(2, "0")
        }
        function confirmar() {
            let n = Object.assign({}, c.tarefa)
            n.titulo = campoTitulo.text.trim()
            n.contratante = campoContratante.text.trim()
            n.prazo = iso(campoPrazo.text)
            n.prioridade = prioridade
            c.salvar(n)
        }
        function emDias(n) { const d = new Date(); d.setDate(d.getDate() + n); campoPrazo.text = String(d.getDate()).padStart(2, "0") + "/" + String(d.getMonth() + 1).padStart(2, "0") + "/" + d.getFullYear() }

        Codigo { text: c.codigo + c.t(" // EDITANDO", " // EDITING"); tamanho: 8; color: c.cor }
        component Campo: QQC2.TextField {
            width: parent.width
            font.family: Cores.fTexto; font.pixelSize: 13
            color: Cores.texto
            placeholderTextColor: Cores.texto3
            selectionColor: Cores.alfa(Cores.destaque, 0.45)
            background: Rectangle { color: Cores.fundo; border.color: parent.activeFocus ? Cores.secundaria : Cores.linha }
            Keys.onEscapePressed: c.fechar()
            onAccepted: editor.confirmar()
        }
        Campo { id: campoTitulo; placeholderText: c.t("Título do contrato", "Contract title") }
        Campo { id: campoContratante; placeholderText: c.t("Contratante (opcional)", "Client (optional)") }
        Row {
            spacing: 4
            Repeater {
                model: c.prioridades
                Item {
                    required property string modelData
                    readonly property bool ativo: editor.prioridade === modelData
                    width: rot.implicitWidth + 12; height: 20
                    Rectangle { anchors.fill: parent; color: parent.ativo ? Cores.alfa(c.corPrioridade(parent.modelData), 0.25) : "transparent"; border.color: c.corPrioridade(parent.modelData) }
                    Codigo { id: rot; anchors.centerIn: parent; text: c.nomePrioridade(parent.modelData); tamanho: 8; font.bold: true; color: c.corPrioridade(parent.modelData) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: editor.prioridade = parent.modelData }
                }
            }
        }
        Row {
            spacing: 4
            width: parent.width
            Campo { id: campoPrazo; width: 110; placeholderText: c.t("dd/mm/aaaa", "dd/mm/yyyy") }
            BotaoIcone { tamanho: 24; glifo: c.t("H", "T"); dica: c.t("Hoje", "Today"); onClicado: editor.emDias(0) }
            BotaoIcone { tamanho: 24; glifo: "+1"; dica: c.t("Amanhã", "Tomorrow"); onClicado: editor.emDias(1) }
            BotaoIcone { tamanho: 24; glifo: "+7"; dica: c.t("Em uma semana", "In a week"); onClicado: editor.emDias(7) }
            BotaoIcone { tamanho: 24; glifo: "∅"; dica: c.t("Sem prazo", "No deadline"); onClicado: campoPrazo.text = "" }
        }
        Row {
            spacing: 6
            BotaoIcone { tamanho: 24; icone: "dialog-ok-apply"; ativo: true; dica: c.t("Salvar (Enter)", "Save (Enter)"); onClicado: editor.confirmar() }
            BotaoIcone { tamanho: 24; icone: "dialog-cancel"; dica: c.t("Cancelar (Esc)", "Cancel (Esc)"); onClicado: c.fechar() }
        }
    }
    onEditandoChanged: if (editando) editor.abrir()
}
