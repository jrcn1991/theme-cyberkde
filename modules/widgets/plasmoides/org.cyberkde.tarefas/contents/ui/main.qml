import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Gigs: tarefas como os contratos do jogo (título, prioridade, prazo, contratante, status).
// Criar, editar, apagar, reordenar e filtrar; tudo salvo na configuração do widget (General/tarefas).
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- dados: leitura tolerante; ilegível = só leitura (não grava por cima)
    readonly property var _lido: {
        const bruto = cfg.tarefas || "[]"
        for (const s of [bruto, bruto.replace(/\r?\n/g, "\\n")]) {
            try { const l = JSON.parse(s); if (Array.isArray(l)) return { ok: true, l: l } } catch (e) {}
        }
        return { ok: false, l: [] }
    }
    readonly property bool ilegivel: !_lido.ok
    readonly property var tarefas: _lido.l
    function gravar(l) { if (!ilegivel) cfg.tarefas = JSON.stringify(l) }

    readonly property string filtro: ["ativos", "andamento", "concluidos", "todos"].indexOf(cfg.filtro) >= 0 ? cfg.filtro : "ativos"
    readonly property var visiveis: tarefas.filter(x => filtro === "todos" ? true
        : filtro === "concluidos" ? x.status === "concluido"
        : filtro === "andamento" ? x.status === "andamento" : x.status !== "concluido")
    readonly property int nAtivos: tarefas.filter(x => x.status !== "concluido").length
    readonly property var pesoPrioridade: ({ critica: 0, alta: 1, media: 2, baixa: 3 })
    // o mais urgente (cartão pequeno): prioridade, depois o prazo mais perto
    readonly property var urgente: {
        const a = tarefas.filter(x => x.status !== "concluido").slice()
        a.sort((p, q) => ((pesoPrioridade[p.prioridade] ?? 2) - (pesoPrioridade[q.prioridade] ?? 2)) || (p.prazo || "9999").localeCompare(q.prazo || "9999"))
        return a.length ? a[0] : null
    }

    property real editarId: -1
    property real _anterior: -1
    onEditarIdChanged: {
        // contrato novo que sai da edição sem título é descartado
        const id = _anterior
        _anterior = editarId
        if (id > 0) Qt.callLater(() => { const n = tarefas.find(x => x.id === id); if (n && !(n.titulo || "").trim() && editarId !== id) apagar(id) })
    }
    function alterar(id, f) { gravar(tarefas.map(x => x.id === id ? f(Object.assign({}, x)) : x)) }
    function nova() {
        const id = Date.now()
        if (filtro === "concluidos") cfg.filtro = "ativos"
        gravar([{ id: id, titulo: "", prioridade: "media", prazo: "", contratante: "", status: "aberto", criada: id }].concat(tarefas))
        editarId = id
    }
    function apagar(id) { if (editarId === id) editarId = -1; gravar(tarefas.filter(x => x.id !== id)) }
    function avancar(id) {
        alterar(id, x => {
            x.status = x.status === "aberto" ? "andamento" : x.status === "andamento" ? "concluido" : "aberto"
            x.concluida = x.status === "concluido" ? Date.now() : 0
            return x
        })
    }
    // troca com o vizinho na ordem exibida (filtrada)
    function mover(id, delta) {
        const i = visiveis.findIndex(x => x.id === id), j = i + delta
        if (i < 0 || j < 0 || j >= visiveis.length) return
        const a = tarefas.slice(), ia = a.findIndex(x => x.id === id), ib = a.findIndex(x => x.id === visiveis[j].id)
        const tmp = a[ia]; a[ia] = a[ib]; a[ib] = tmp
        gravar(a)
    }

    toolTipMainText: cfg.quadro || "Gigs"
    toolTipSubText: nAtivos + (nAtivos === 1 ? t(" contrato ativo", " active gig") : t(" contratos ativos", " active gigs"))

    // ---- tamanho na área de trabalho: livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    function corPrioridade(p) { return p === "critica" ? Cores.alerta : p === "alta" ? Cores.destaque : p === "media" ? Cores.secundaria : Cores.texto2 }

    // cartão enxuto: contagem e o contrato mais urgente
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 4
                Row {
                    spacing: 6
                    Codigo { text: (raiz.cfg.quadro || "Gigs").toUpperCase(); tamanho: 9; font.bold: true; color: Cores.destaque }
                    Codigo { text: "// " + String(raiz.nAtivos).padStart(2, "0") + raiz.t(" ATIVOS", " ACTIVE"); tamanho: 9 }
                }
                Item {
                    visible: !!raiz.urgente
                    width: parent.width; height: parent.height - 18
                    Rectangle { width: 3; height: parent.height; color: raiz.urgente ? raiz.corPrioridade(raiz.urgente.prioridade) : "transparent" }
                    Text {
                        x: 9; width: parent.width - 9
                        text: raiz.urgente ? raiz.urgente.titulo : ""
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.family: Cores.fTexto; font.pixelSize: 12; font.weight: Font.DemiBold
                        color: Cores.texto
                    }
                    Codigo {
                        x: 9; anchors.bottom: parent.bottom
                        text: raiz.urgente && raiz.urgente.prazo ? raiz.t("PRAZO ", "DUE ") + raiz.urgente.prazo.split("-").reverse().slice(0, 2).join(".") : ""
                        tamanho: 9; color: Cores.texto2
                    }
                }
                Leitura { visible: !raiz.urgente; text: raiz.t("Nenhum contrato ativo.", "No active gigs."); tamanho: 12; color: Cores.texto2 }
            }
        }
    }

    // barra: ícone e contagem
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linhaC.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Row {
                id: linhaC
                anchors.centerIn: parent
                spacing: 4
                Kirigami.Icon { width: 16; height: 16; source: "view-task"; isMask: true; color: Cores.destaque; anchors.verticalCenter: parent.verticalCenter }
                Text { text: raiz.nAtivos; font.family: Cores.fMono; font.pixelSize: 12; font.bold: true; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // versão completa: filtros e a lista de contratos (rola)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.cfg.quadro || "Gigs"
            codigo: "FIXER.NET // " + String(raiz.nAtivos).padStart(2, "0") + raiz.t(" ATIVOS", " ACTIVE")
            extra: [
                BotaoIcone { tamanho: 20; icone: "list-add"; habilitado: !raiz.ilegivel; dica: raiz.t("Novo contrato", "New gig"); onClicado: raiz.nova() }
            ]
            readonly property bool cabeFiltros: area.height >= 120

            // filtros
            Row {
                id: filtros
                visible: mold.cabeFiltros
                spacing: 4
                Repeater {
                    model: [["ativos", raiz.t("ATIVOS", "ACTIVE")], ["andamento", raiz.t("EM ANDAMENTO", "IN PROGRESS")], ["concluidos", raiz.t("CONCLUÍDOS", "DONE")], ["todos", raiz.t("TODOS", "ALL")]]
                    Item {
                        required property var modelData
                        readonly property bool ativo: raiz.filtro === modelData[0]
                        width: rf.implicitWidth + 12; height: 20
                        Rectangle {
                            anchors.fill: parent
                            color: parent.ativo ? Cores.alfa(Cores.destaque, 0.2) : (mf.containsMouse ? Cores.alfa(Cores.destaque, 0.08) : "transparent")
                            border.color: parent.ativo ? Cores.destaque : Cores.linha
                        }
                        Codigo { id: rf; anchors.centerIn: parent; text: parent.modelData[1]; tamanho: 8; font.bold: parent.ativo; color: parent.ativo ? Cores.destaque : Cores.texto2 }
                        MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: raiz.cfg.filtro = parent.modelData[0] }
                    }
                }
            }

            // vazio / ilegível
            Column {
                visible: raiz.visiveis.length === 0
                anchors.centerIn: parent
                spacing: 6
                Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.ilegivel ? raiz.t("DADOS CORROMPIDOS", "CORRUPTED DATA") : raiz.t("NENHUM CONTRATO", "NO GIGS"); color: raiz.ilegivel ? Cores.alerta : Cores.destaque; tamanho: 10 }
                Leitura {
                    anchors.horizontalCenter: parent.horizontalCenter; wrapMode: Text.NoWrap; color: Cores.texto2
                    text: raiz.ilegivel ? raiz.t("Os contratos salvos não puderam ser lidos; nada será gravado por cima.", "Saved gigs could not be read; nothing will be written over them.")
                                        : raiz.t("Use + para aceitar um contrato", "Use + to take a gig")
                }
            }

            Flickable {
                id: rolagem
                y: mold.cabeFiltros ? filtros.height + 8 : 0
                width: parent.width; height: parent.height - y
                clip: true
                contentWidth: width; contentHeight: lista.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: rolagem.contentHeight > rolagem.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }
                MouseArea { width: rolagem.width; height: Math.max(rolagem.height, lista.implicitHeight); onClicked: raiz.editarId = -1 }
                Column {
                    id: lista
                    width: rolagem.width - (rolagem.contentHeight > rolagem.height ? 10 : 0)
                    spacing: 6
                    Repeater {
                        model: raiz.visiveis
                        Contrato {
                            required property var modelData
                            required property int index
                            width: lista.width
                            height: implicitHeight
                            tarefa: modelData
                            posicao: index
                            total: raiz.visiveis.length
                            en: raiz.en
                            opacidade: raiz.opac
                            editando: raiz.editarId === modelData.id
                            onEditar: raiz.editarId = modelData.id
                            onFechar: if (raiz.editarId === modelData.id) raiz.editarId = -1
                            // fecha antes de gravar: gravar recria a lista (e este cartão)
                            onSalvar: (n) => { const id = modelData.id; raiz.editarId = -1; raiz.alterar(id, x => n) }
                            onAvancar: raiz.avancar(modelData.id)
                            onMover: (d) => raiz.mover(modelData.id, d)
                            onApagar: raiz.apagar(modelData.id)
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        limiteCartao: Qt.size(240, 160)
        tamanhoPequeno: Qt.size(250, 104)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 20, Kirigami.Units.gridUnit * 18)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 22, Kirigami.Units.gridUnit * 27)
    }
}
