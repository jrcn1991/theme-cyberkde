import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Notas: um quadro de notas por instância. Cada nota é um "datashard": cor (destaque,
// secundária ou alerta), fixar no topo, reordenar, checklist. Tudo salvo na configuração do widget.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- dados
    // leitura tolerante (quebras de linha cruas dentro das strings); se ainda assim não der para ler,
    // o quadro fica só leitura para não sobrescrever as notas
    readonly property var _lido: {
        const bruto = cfg.notas || "[]"
        for (const s of [bruto, bruto.replace(/\r?\n/g, "\\n")]) {
            try { const l = JSON.parse(s); if (Array.isArray(l)) return { ok: true, l: l } } catch (e) {}
        }
        return { ok: false, l: [] }
    }
    readonly property bool ilegivel: !_lido.ok
    readonly property var notas: _lido.l
    // fixadas primeiro, mantendo a ordem do quadro
    readonly property var ordenadas: notas.filter(n => n.fixada).concat(notas.filter(n => !n.fixada))
    // no cartão pequeno: a nota fixada (ou a primeira); checklist em ☐/☑
    readonly property var notaCapa: ordenadas.length ? ordenadas[0] : null
    readonly property string resumoCapa: !notaCapa ? "" : !notaCapa.checklist ? (notaCapa.texto || t("(nota vazia)", "(empty note)"))
        : (notaCapa.texto || "").split("\n").filter(l => l.replace(/^\[[ x]\]\s?/i, "").trim() !== "")
              .map(l => (/^\[x\]/i.test(l) ? "☑ " : "☐ ") + l.replace(/^\[[ x]\]\s?/i, "")).join("\n")
    property real editarId: -1
    // nota que sai da edição ainda vazia é descartada
    property real _anterior: -1
    onEditarIdChanged: {
        const id = _anterior
        _anterior = editarId
        if (id > 0) Qt.callLater(() => { const n = notas.find(x => x.id === id); if (n && !(n.texto || "").trim() && editarId !== id) apagar(id) })
    }

    function gravar(l) { if (!ilegivel) cfg.notas = JSON.stringify(l) }
    function alterar(id, f) { gravar(notas.map(n => n.id === id ? f(Object.assign({}, n)) : n)) }
    function nova() {
        const id = Date.now()
        // no início: aparece mesmo no tamanho médio (que mostra só as primeiras)
        gravar([{ id: id, texto: "", cor: "destaque", fixada: false, checklist: false, criada: id }].concat(notas))
        editarId = id
    }
    function apagar(id) { if (editarId === id) editarId = -1; gravar(notas.filter(n => n.id !== id)) }
    // move dentro do grupo (fixadas ou não), na ordem exibida
    function mover(id, delta) {
        const vis = ordenadas.slice()
        const i = vis.findIndex(n => n.id === id), j = i + delta
        if (i < 0 || j < 0 || j >= vis.length || !!vis[i].fixada !== !!vis[j].fixada) return
        const tmp = vis[i]; vis[i] = vis[j]; vis[j] = tmp
        gravar(vis)
    }
    function marcar(id, linha) {
        alterar(id, n => {
            let l = (n.texto || "").split("\n")
            l[linha] = /^\[x\]/i.test(l[linha]) ? l[linha].replace(/^\[x\]/i, "[ ]") : "[x] " + l[linha].replace(/^\[ \]\s?/, "")
            n.texto = l.join("\n"); return n
        })
    }
    function alternarChecklist(id) {
        alterar(id, n => {
            n.checklist = !n.checklist
            const l = (n.texto || "").split("\n")
            n.texto = (n.checklist ? l.map(x => /^\[[ x]\]/i.test(x) ? x : "[ ] " + x) : l.map(x => x.replace(/^\[[ x]\]\s?/i, ""))).join("\n")
            return n
        })
    }
    readonly property var _ciclo: ({ destaque: "secundaria", secundaria: "alerta", alerta: "destaque" })

    toolTipMainText: cfg.quadro || t("Notas", "Notes")
    toolTipSubText: notas.length + (notas.length === 1 ? t(" nota", " note") : t(" notas", " notes"))

    // ---- tamanho na área de trabalho: livre (a geometria do applet, redimensionável no modo de edição);
    //      P/M/G são presets, e "modo" guarda o último escolhido. Na barra, a forma compacta de sempre.
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    // valores antigos: compacto → pequeno, completo → grande
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0                  // muda a cada escolha de preset (até a mesma de novo)
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 5
                Row {
                    spacing: 6
                    Codigo { text: (raiz.cfg.quadro || raiz.t("Notas", "Notes")).toUpperCase(); color: Cores.destaque; tamanho: 9; font.bold: true }
                    Codigo { text: "// " + String(raiz.notas.length).padStart(2, "0") + (raiz.notas.length === 1 ? raiz.t(" NOTA", " NOTE") : raiz.t(" NOTAS", " NOTES")); tamanho: 9 }
                }
                Item {
                    visible: !!raiz.notaCapa
                    width: parent.width; height: parent.height - 19
                    Rectangle { width: 2; height: parent.height; color: raiz.notaCapa ? Cores.papel(raiz.notaCapa.cor) : "transparent" }
                    Text {
                        x: 8; width: parent.width - 8; height: parent.height
                        text: raiz.resumoCapa
                        wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 3
                        textFormat: Text.PlainText
                        font.family: Cores.fTexto; font.pixelSize: 12
                        lineHeight: 1.1
                        color: Cores.texto
                    }
                }
                Leitura {
                    visible: !raiz.notaCapa
                    text: raiz.t("Nenhuma nota. Clique para abrir o quadro.", "No notes. Click to open the board.")
                    tamanho: 12; color: Cores.texto2
                    width: parent.width
                }
            }
        }
    }

    Component {
        id: compactoBarra
    MouseArea {
        Layout.minimumWidth: linhaC.implicitWidth + 8
        onClicked: raiz.expanded = !raiz.expanded
        Row {
            id: linhaC
            anchors.centerIn: parent
            spacing: 4
            // mini datashard
            Item {
                width: 14; height: 16
                anchors.verticalCenter: parent.verticalCenter
                Chanfro { anchors.fill: parent; corte: 4; preenchimento: Cores.alfa(Cores.destaque, 0.15); borda: Cores.destaque }
                Repeater { model: 3; Rectangle { required property int index; x: 4; y: 5 + index * 3; width: index === 2 ? 4 : 6; height: 1; color: Cores.destaque } }
            }
            Text { text: raiz.notas.length; font.family: Cores.fMono; font.pixelSize: 12; font.bold: true; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    }

    // ---- médio e grande (a mesma moldura; o médio mostra menos partes)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.cfg.quadro || raiz.t("Notas", "Notes")
            codigo: "DATA.INTERCEPT // " + String(raiz.notas.length).padStart(2, "0")
            extra: [
                BotaoIcone { tamanho: 20; icone: "list-add"; habilitado: !raiz.ilegivel; dica: raiz.t("Nova nota", "New note"); onClicado: raiz.nova() }
            ]

            // quadro vazio
            Column {
                visible: raiz.notas.length === 0
                anchors.centerIn: parent
                spacing: 6
                Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.ilegivel ? raiz.t("DADOS CORROMPIDOS", "CORRUPTED DATA") : raiz.t("NENHUM DADO INTERCEPTADO", "NO DATA INTERCEPTED"); color: raiz.ilegivel ? Cores.alerta : Cores.destaque; tamanho: 10 }
                Leitura { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.ilegivel ? raiz.t("As notas salvas não puderam ser lidas; nada será gravado por cima.", "Saved notes could not be read; nothing will be written over them.") : raiz.t("Use + para criar uma nota", "Use + to create a note"); color: Cores.texto2; wrapMode: Text.NoWrap }
            }

            Flickable {
                id: rolagem
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: grade.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: rolagem.contentHeight > rolagem.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }
                // clique no vazio encerra a edição
                MouseArea { width: rolagem.width; height: Math.max(rolagem.height, grade.implicitHeight); onClicked: raiz.editarId = -1 }

                // colunas tipo "mural": cada nota vai para a coluna mais baixa
                Item {
                    id: grade
                    width: rolagem.width - (rolagem.contentHeight > rolagem.height ? 10 : 0)
                    readonly property int ncol: Math.max(1, Math.floor((width + 8) / (raiz.cfg.larguraCartao + 8)))
                    readonly property real lc: (width - (ncol - 1) * 8) / ncol
                    implicitHeight: 0
                    function arrumar() {
                        let alt = new Array(ncol).fill(0)
                        for (let i = 0; i < rep.count; i++) {
                            const it = rep.itemAt(i)
                            if (!it) continue
                            let k = 0
                            for (let j = 1; j < ncol; j++) if (alt[j] < alt[k] - 1) k = j
                            it.x = k * (lc + 8); it.y = alt[k]
                            alt[k] += it.implicitHeight + 8
                        }
                        implicitHeight = Math.max(0, Math.max(...alt) - 8)
                    }
                    onNcolChanged: Qt.callLater(arrumar)
                    onLcChanged: Qt.callLater(arrumar)
                    Repeater {
                        id: rep
                        model: raiz.ordenadas
                        Cartao {
                            required property var modelData
                            required property int index
                            width: grade.lc
                            height: implicitHeight
                            nota: modelData
                            posicao: index
                            total: raiz.ordenadas.length
                            en: raiz.en
                            opacidade: raiz.opac
                            editando: raiz.editarId === modelData.id
                            onImplicitHeightChanged: Qt.callLater(grade.arrumar)
                            onEditar: raiz.editarId = modelData.id
                            onEncerrarEdicao: if (raiz.editarId === modelData.id) raiz.editarId = -1
                            onSalvar: (texto) => raiz.alterar(modelData.id, n => { n.texto = texto; return n })
                            onFixar: raiz.alterar(modelData.id, n => { n.fixada = !n.fixada; return n })
                            onTrocarCor: raiz.alterar(modelData.id, n => { n.cor = raiz._ciclo[n.cor] || "destaque"; return n })
                            onAlternarChecklist: raiz.alternarChecklist(modelData.id)
                            onMover: (d) => raiz.mover(modelData.id, d)
                            onApagar: raiz.apagar(modelData.id)
                            onMarcar: (l) => raiz.marcar(modelData.id, l)
                        }
                        onItemAdded: Qt.callLater(grade.arrumar)
                        onItemRemoved: Qt.callLater(grade.arrumar)
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
        limiteCartao: Qt.size(240, 170)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        tamanhoPequeno: Qt.size(250, 112)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 21, Kirigami.Units.gridUnit * 17)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 26, Kirigami.Units.gridUnit * 20)
    }

}
