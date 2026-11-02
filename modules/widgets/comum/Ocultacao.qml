import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasma5support as P5Support
import "catalogoAnim.js" as Catalogo

// Ocultar e exibir TODOS os widgets do tema (generaliza o que o Cyber Fence faz com as cercas). O estado é
// global, em nomes de arquivo na pasta ~/.config/cyberkde/widgets, vigiada na hora:
//   ocultos            existe = ocultos            gesto  existe = duplo clique na mesa vazia ligado
//   junto              existe = o gesto leva as cercas junto
//   animacao.<id>      a variante; animacao.cercas (ou nenhum arquivo) = igual às cercas (cercas/animacao.<id>)
// O CLI ("cyberkde widgets ...", CONTRATO-CLI.md) e o painel só mexem nesses arquivos. Com "junto", o alvo
// vem do estado das cercas e cada um (widget ou cerca) grava os dois: todos calculam o mesmo alvo, então
// vários ouvintes no mesmo clique não se atrapalham. No modo de edição, tudo fica à vista.
Item {
    id: o
    property bool ativo: true
    property Item cont: null          // o contêiner do applet na área de trabalho
    property bool edicao: false

    property bool ocultos: false
    property bool gesto: false
    property bool junto: false
    property string escolhida: ""
    property string animCercas: ""
    property bool cercasOcultas: false
    readonly property bool ocultaAgora: ativo && ocultos && !edicao
    readonly property string variante: Catalogo.de(escolhida && escolhida !== "cercas" ? escolhida : animCercas).id

    function _local(u) { return decodeURIComponent(String(u).replace(/^file:\/\//, "")) }
    readonly property url _base: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
    readonly property string dirW: _local(_base) + "/cyberkde/widgets"
    readonly property string dirC: _local(_base) + "/cyberkde/cercas"
    function aspas(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    property int _seq: 0
    property var _depois: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte) => {
            const f = o._depois[fonte]
            delete o._depois[fonte]
            disconnectSource(fonte)
            if (f) f()
        }
    }
    function rodar(cmd, depois) {
        const fonte = cmd + " #" + (++_seq) + "." + Math.random()     // comando igual não pode cair na mesma fonte
        if (depois) _depois[fonte] = depois
        exec.connectSource(fonte)
    }
    onAtivoChanged: _vigiar()
    Component.onCompleted: _vigiar()
    property bool _vigiando: false
    function _vigiar() {     // o vigia não enxerga a pasta que nasce depois
        if (!ativo || _vigiando) return
        _vigiando = true
        rodar("mkdir -p " + aspas(dirW) + " " + aspas(dirC), () => {
            vigiaW.folder = "file://" + dirW
            vigiaC.folder = "file://" + dirC
        })
    }
    FolderListModel {
        id: vigiaW
        nameFilters: ["ocultos", "gesto", "junto", "animacao.*"]
        showDirs: false; showHidden: true
        onCountChanged: if (status === FolderListModel.Ready) o._lerW()
        onStatusChanged: if (status === FolderListModel.Ready) o._lerW()
    }
    FolderListModel {
        id: vigiaC
        nameFilters: ["ocultas", "animacao.*"]
        showDirs: false; showHidden: true
        onCountChanged: if (status === FolderListModel.Ready) o._lerC()
        onStatusChanged: if (status === FolderListModel.Ready) o._lerC()
    }
    function _lerW() {
        let oc = false, ge = false, ju = false, an = ""
        for (let i = 0; i < vigiaW.count; i++) {
            const n = vigiaW.get(i, "fileName")
            if (n === "ocultos") oc = true
            else if (n === "gesto") ge = true
            else if (n === "junto") ju = true
            else if (n.indexOf("animacao.") === 0) an = n.slice(9)
        }
        ocultos = oc; gesto = ge; junto = ju; escolhida = an
    }
    function _lerC() {
        let oc = false, an = ""
        for (let i = 0; i < vigiaC.count; i++) {
            const n = vigiaC.get(i, "fileName")
            if (n === "ocultas") oc = true
            else if (n.indexOf("animacao.") === 0) an = n.slice(9)
        }
        cercasOcultas = oc; animCercas = an
    }
    function _gravar(arq, sim) { return (sim ? "touch " : "rm -f ") + aspas(arq) }
    function alternar() {
        const alvo = junto ? !cercasOcultas : !ocultos
        ocultos = alvo
        rodar(_gravar(dirW + "/ocultos", alvo) + (junto ? " ; " + _gravar(dirC + "/ocultas", alvo) : ""))
    }

    // ---- ordem das animações que dependem da posição (a mesma conta das cercas)
    readonly property Item _mesa: cont ? cont.parent : null
    readonly property int atrasoCascata: {
        const L = _mesa
        return L && L.width > 0 && variante !== "cascata" ? Math.round(Cores.d(320) * (cont.x / L.width + cont.y / L.height) / 2) : 0
    }
    readonly property var _pilha: {
        const L = _mesa, v = []
        if (!L) return v
        for (const c of L.children) {
            const n = c.applet && c.applet.Plasmoid ? String(c.applet.Plasmoid.pluginName) : ""
            if (n.indexOf("org.cyberkde.") === 0 && n !== "org.cyberkde.cerca") v.push(c)
        }
        return v.sort((a, b) => Math.abs(a.y - b.y) > 24 ? a.y - b.y : a.x - b.x)
    }
    readonly property int _ordem: Math.max(0, _pilha.indexOf(cont))
    readonly property int atraso: variante === "empilhar" ? _ordem * Cores.d(180) : atrasoCascata
    readonly property int atrasoSaida: variante === "empilhar" ? (Math.max(1, _pilha.length) - 1 - _ordem) * Cores.d(90) : atrasoCascata

    // ---- duplo clique na mesa vazia. Um plasmoide não recebe clique fora dele, mas alcança a área de
    // trabalho: com ícones, ouve o MouseArea do FolderView do containment; sem ícones, o layout (TapHandler).
    property real _ultimo: 0
    property point _ponto
    function _toque(x, y) {
        const agora = Date.now()
        const perto = Math.abs(x - _ponto.x) + Math.abs(y - _ponto.y) < Application.styleHints.startDragDistance
        if (agora - _ultimo <= Application.styleHints.mouseDoubleClickInterval && perto) {
            _ultimo = 0
            alternar()
        } else {
            _ultimo = agora
            _ponto = Qt.point(x, y)
        }
    }
    readonly property Item ouvinte: {
        const g = _mesa ? _mesa.eventManagerToFilter : null
        for (let p = g; p; p = p.parent) if (p.pressX !== undefined && p.hoveredItem !== undefined) return p
        return null
    }
    Connections {
        target: o.ouvinte
        enabled: o.ativo && o.gesto && !o.edicao
        function onPressed(m) {
            const it = o.ouvinte.hoveredItem
            if (m.button === Qt.LeftButton && !m.modifiers && (!it || it.blank)) o._toque(m.x, m.y)
        }
    }
    TapHandler {
        parent: o._mesa ? o._mesa : o
        enabled: !!o._mesa && !o.ouvinte && o.ativo && o.gesto && !o.edicao
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.DragThreshold
        onDoubleTapped: { for (const k of parent.children) if (k.editModeCondition !== undefined && k.visible && k.enabled && k.contains(k.mapFromItem(parent, point.position))) return; o.alternar() }
    }
}
