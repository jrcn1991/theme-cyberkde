/*
    SPDX-FileCopyrightText: 2013-2017 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2026 CyberKDE

    Liga o FolderView da KDE (org.kde.desktopcontainment) a uma moldura do tema. A parte que vem do
    main.qml do Folder View (propriedades que o FolderView lê em "root", área de soltar) segue a mesma
    licença do original.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.private.desktopcontainment.folder as Folder
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Shapes
import "comum"
import "anim/catalogo.js" as Catalogo
import "anim/catalogoIcones.js" as CatIcones

// Cyber Fence: uma pasta na área de trabalho, numa moldura com título (grade, miniaturas, arraste,
// renomear e menu de contexto são os do Folder View, por KIO). RECOLHER: a cerca encolhe até só o título.
// Estado: IsRolled + UnrolledHeight separados (main.xml). A geometria do applet (Cores.redimensionar)
// arredonda para a grade, grava depois da animação e mantém parado o canto mais perto da borda. O desenho
// anima por dentro: ao recolher, o contêiner só encolhe no fim; ao abrir, cresce antes, e a moldura cresce
// dentro dele. O conteúdo é escondido junto. Gatilho: Ctrl+clique no título (ou clique, por opção);
// "ao sair o mouse" confere a posição do ponteiro contra o retângulo da cerca.
// O TÍTULO funciona como a barra de uma janela: arrastar move a cerca, duplo clique renomeia a cerca e a
// pasta. NOVA CERCA (novaCerca=true) nasce com o título em edição e sem pasta: Enter cria, Esc desiste.
// SOLTAR move direto, por contents/code/cerca.py (Ctrl copia), com "desfazer" num aviso dentro da cerca.
// OCULTAR: o arquivo ~/.config/cyberkde/cercas/ocultas vale para todas; duplo clique na mesa vazia alterna.
// A animação (AnimacaoCerca) também é comum a todas: arquivo cercas/animacao.<id>. PEEK: arquivo cercas/peek.
// TIPO "lista": itens avulsos, links numa pasta só dela. ABAS: mais pastas na mesma cerca.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- o que o FolderView da KDE lê em "root"
    readonly property bool isContainment: false
    readonly property bool isPopup: false
    readonly property bool useListViewMode: false
    // "Abrir com": um clique, dois, ou o que o KDE usa. Com dois, um clique só seleciona.
    readonly property bool umClique: cfg.cliques === "um" ? true : cfg.cliques === "dois" ? false : Application.styleHints.singleClickActivation
    // layout: grade, dados (uma linha por item) ou inventario (células, com o item no rodapé). Densidade compacta
    // é o layout dados. O FolderView só recalcula o ícone ao mudar o iconSize: o layout passa por aqui
    readonly property string layoutCerca: cfg.layout === "inventario" ? "inventario" : cfg.layout === "dados" || cfg.densidade === "compacta" ? "dados" : "grade"
    onLayoutCercaChanged: if (camada && camada.view) camada.view.view.iconSize = camada.view.view.makeIconSize()
    readonly property bool isFolder: true
    property bool containsDrag: false
    property int hoverActivateDelay: 750
    function isDrag(fromX, fromY, toX, toY) {
        return Math.abs(fromX - toX) + Math.abs(fromY - toY) >= Application.styleHints.startDragDistance
    }

    // ---- pasta e título. Só pasta comum por file://: desktop:/ mostra os .desktop mas não lança nem
    // percebe arquivo novo, então vira a pasta real da área de trabalho.
    function _urlDe(t) {
        const u = String(t || "").trim()
        if (!u) return StandardPaths.writableLocation(StandardPaths.DownloadLocation).toString()
        if (u.indexOf("desktop:") === 0) return StandardPaths.writableLocation(StandardPaths.DesktopLocation).toString()
        if (u.charAt(0) === "/") return "file://" + u
        return u                // ~/… e file:// o FolderModel resolve
    }
    function _localDe(u) {
        return (u.indexOf("file://") === 0 ? decodeURIComponent(u.slice(7)) : u).replace(/\/+$/, "")
    }
    readonly property bool ehLista: cfg.tipoCerca === "lista"
    readonly property string pastaPrincipal: ehLista ? (cfg.pastaLista ? "file://" + cfg.pastaLista : "") : _urlDe(cfg.url)
    onEhListaChanged: _garantirLista()
    function _garantirLista() {
        if (ehLista && !cfg.pastaLista) chamar(["lista"], (r) => { if (r.ok) cfg.pastaLista = r.caminho })
    }
    // abas: a primeira é a pasta da cerca, as outras vêm de "abas"
    readonly property var pastas: {
        const extras = String(cfg.abas || "").split(";").map(x => x.trim()).filter(x => x !== "")
        return [pastaPrincipal].concat(extras.map(_urlDe))
    }
    readonly property int aba: Math.max(0, Math.min(cfg.abaAtual, pastas.length - 1))
    readonly property string pastaUrl: pastas[aba]
    // Depois de renomear, o KDirLister do plasmashell não acompanha mais a pasta (nem soltando a pasta antes
    // do rename) e só volta ao reiniciar: até lá, um vigia daqui percebe a mudança e pede a recarga.
    property bool _renomeada: false
    function _renomearPasta(nome, depois) {
        const antiga = _absoluto(cfg.url) || pastaLocal
        chamar(["renomear", cfg.url || pastaLocal, nome], (r) => {
            if (r.ok) { depois(r); _renomeada = true; recarga.restart(); _propagarRenome(antiga, r.caminho) }
            else _falhaTitulo(r)
        })
    }
    function _absoluto(u) {
        let p = String(u || "").trim()
        if (p.indexOf("file://") === 0) p = decodeURIComponent(p.slice(7))
        if (p.indexOf("~/") === 0) p = _local(StandardPaths.HomeLocation) + p.slice(1)
        while (p.length > 1 && p.charAt(p.length - 1) === "/") p = p.slice(0, -1)
        return p
    }
    // as outras cercas e abas na pasta renomeada (ou em subpasta dela), em todas as telas; aqui também, nas abas
    function _propagarRenome(antiga, nova) {
        const js = "var A=" + JSON.stringify(antiga) + ",N=" + JSON.stringify(nova) + ",H=" + JSON.stringify(_local(StandardPaths.HomeLocation)) + ";"
            + "function f(v){var s=String(v||'').trim(),p=s;if(p.indexOf('file://')==0)p=decodeURIComponent(p.slice(7));"
            + "if(p.indexOf('~/')==0)p=H+p.slice(1);while(p.length>1&&p.charAt(p.length-1)=='/')p=p.slice(0,-1);"
            + "if(p==A)return N;if(p.indexOf(A+'/')==0)return N+p.slice(A.length);return s}"
            + "var ds=desktops();for(var i=0;i<ds.length;i++){var ws=ds[i].widgets();for(var j=0;j<ws.length;j++){var w=ws[j];"
            + "if(w.type!='org.cyberkde.cerca')continue;w.currentConfigGroup=['General'];"
            + "var u=String(w.readConfig('url','')),b=String(w.readConfig('abas',''));"
            + "var nu=u?f(u):u,nb=b?b.split(';').map(f).join(';'):b;"
            + "if(nu!=u)w.writeConfig('url',nu);if(nb!=b)w.writeConfig('abas',nb);}}"
        rodar("timeout 5 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + aspas(js) + " >/dev/null 2>&1")
    }
    // pasta trocada por fora (o renome de outra cerca): o lister pode não acompanhar a pasta nova
    Connections {
        target: root.cfg
        function onUrlChanged() { root._renomeada = true; recarga.restart() }
        function onAbasChanged() { root._renomeada = true; recarga.restart() }
    }
    Timer { id: recarga; interval: 250; onTriggered: if (root.camada && root.camada.view) root.camada.view.model.refresh() }
    FolderListModel {
        folder: root._renomeada ? root.pastaUrl : ""
        showHidden: root.cfg.showHiddenFiles
        showDotAndDotDot: false
        onRowsInserted: recarga.restart()
        onRowsRemoved: recarga.restart()
    }
    function nomeAba(i) { return i === 0 && ehLista ? t("Lista", "List") : _localDe(pastas[i]).split("/").pop() }
    function _gravarAbas(lista) { cfg.abas = lista.map(_localDe).join(";") }
    function adicionarAba(url) {
        const extras = pastas.slice(1)
        if (pastas.indexOf(String(url)) < 0) { _gravarAbas(extras.concat([String(url)])); cfg.abaAtual = extras.length + 1 }
    }
    function pedirAba() { dlgAba.open() }
    // arraste por cima: rótulo do alvo, e parar sobre uma aba a abre (U12)
    property bool _ctrlArraste: false
    property Item fitaAbas: null
    property int _abaAlvo: -1
    Timer { id: abrirAba; interval: 700; onTriggered: if (root._abaAlvo >= 0) root.cfg.abaAtual = root._abaAlvo }
    function arrasteEm(area, x, y) {
        let alvo = -1
        if (fitaAbas && fitaAbas.visible) {
            const p = area.mapToItem(fitaAbas, x, y)
            if (p.y >= 0 && p.y < fitaAbas.height)
                for (let i = 0; i < fitaAbas.children.length; i++) {
                    const c = fitaAbas.children[i]
                    if (c.index !== undefined && p.x >= c.x && p.x < c.x + c.width) alvo = c.index
                }
        }
        if (alvo !== _abaAlvo) { _abaAlvo = alvo; if (alvo >= 0 && alvo !== aba) abrirAba.restart(); else abrirAba.stop() }
    }
    function arrasteFora() { _abaAlvo = -1; abrirAba.stop() }
    function removerAba() {
        if (aba === 0) return
        const extras = pastas.slice(1)
        extras.splice(aba - 1, 1)
        cfg.abaAtual = aba - 1
        _gravarAbas(extras)
    }
    // filtro por tipo: FilterShowMatches, com a lista do preset
    readonly property var _mimes: ({
        imagens: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp", "image/tiff", "image/heif", "image/avif"],
        documentos: ["text/plain", "application/pdf", "application/rtf", "application/msword", "application/vnd.ms-excel", "application/vnd.ms-powerpoint",
            "application/vnd.oasis.opendocument.text", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.oasis.opendocument.presentation",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"],
        audio: ["audio/mpeg", "audio/ogg", "audio/flac", "audio/x-flac", "audio/x-wav", "audio/mp4", "audio/aac", "audio/x-opus+ogg"],
        video: ["video/mp4", "video/webm", "video/x-matroska", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg"],
        pastas: ["inode/directory"]
    })
    readonly property var mimesFiltro: _mimes[cfg.filtroTipo] || []
    readonly property color corCerca: Cores.papel(cfg.cor)
    property Item camada: null
    readonly property string tituloCerca: String(cfg.titulo || "").trim() || (nova ? "" : ehLista ? t("Lista", "List") : _localDe(pastaPrincipal).split("/").pop())
    toolTipMainText: tituloCerca

    // ---- tamanho e recolher
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ["pequeno", "medio", "grande"].indexOf(cfg.modo) >= 0 ? cfg.modo : "medio"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    // abaixo de 60% o texto deixa de ler sobre papel claro (contraste < 4:1)
    // piso de 70%: o texto fica com 4,5:1 até em papel quase branco (#F0F0EA), sem depender de ler o papel
    readonly property real opac: Math.max(0.7, Math.min(1, cfg.opacidade / 100))

    property var cont: null                  // ItemContainer do applet (null fora da área de trabalho)
    property Item corpo: null                // o Item do fullRepresentation (Tamanhos)
    readonly property bool rolada: cfg.IsRolled
    readonly property int celula: cont && cont.layout && cont.layout.cellHeight > 0 ? cont.layout.cellHeight : 16
    readonly property int alturaRolada: Math.ceil(alturaTitulo / celula) * celula
    readonly property int alturaTitulo: 40
    // altura desenhada: durante a animação difere da do contêiner
    property real alturaDesenho: -1
    property bool animando: false
    property bool ancBaixo: false
    readonly property real alturaAtual: cont ? cont.height : (corpo ? corpo.height : 0)
    readonly property real alturaMoldura: alturaDesenho >= 0 ? alturaDesenho : (corpo ? corpo.height : 0)

    NumberAnimation {
        id: animAltura
        target: root; property: "alturaDesenho"
        duration: Cores.d(240); easing.type: Easing.InOutQuad
        onFinished: root._fimAnim()
    }
    property bool _recolhendo: false
    property bool _restaurada: false         // a geometria restaurada pelo Plasma já foi conferida
    function _noBaixo() {
        const L = cont ? cont.parent : null
        return !!L && L.height > 0 && cont.y + cont.height / 2 > L.height / 2
    }
    // estado já aplicado à geometria; IsRolled mudado por fora (painel, CLI) anima igual
    property bool _aplicada: cfg.IsRolled
    onRoladaChanged: if (rolada !== _aplicada) { if (rolada) recolher(); else abrir() }
    function recolher() {
        if (_aplicada || animando || !corpo) return
        _aplicada = true
        const h = Math.round(alturaAtual)
        if (h > alturaRolada) cfg.UnrolledHeight = h
        cfg.IsRolled = true
        ancBaixo = _noBaixo()
        _recolhendo = true
        if (_animI) _animI.sair(Cores.d(200), 0)
        _animar(h, alturaRolada)
    }
    function abrir() {
        if (!_aplicada || animando || !corpo) return
        _aplicada = false
        ancBaixo = _noBaixo()
        const alvo = Math.max(cfg.UnrolledHeight, alturaRolada + 4 * celula)
        cfg.IsRolled = false
        _recolhendo = false
        animando = true
        // cresce primeiro (o desenho fica na altura rolada e sobe dentro do contêiner já maior)
        alturaDesenho = alturaRolada
        Cores.redimensionar(corpo, cont ? cont.width : corpo.width, alvo)
        if (_animI) { _animI.preparar(); _animI.tocar(Cores.d(120)) }
        _animar(alturaRolada, alvo)
    }
    function alternar() { if (rolada) abrir(); else recolher() }
    function _animar(de, ate) {
        animando = true
        if (Cores.reduzir) { alturaDesenho = ate; _fimAnim(); return }
        animAltura.stop(); animAltura.from = de; animAltura.to = ate; animAltura.start()
    }
    function _fimAnim() {
        if (_recolhendo && corpo) Cores.redimensionar(corpo, cont ? cont.width : corpo.width, alturaRolada)
        _recolhendo = false
        alturaDesenho = -1
        Qt.callLater(() => {
            animando = false; assenta.restart()
            if (rolada !== _aplicada) { if (rolada) recolher(); else abrir() }   // pedido no meio da animação
        })
    }

    // tamanho mudado por fora (alça, preset, CLI): aberta, é a nova altura aberta; recolhida e bem mais
    // alta que o título, deixa de estar recolhida. Espera assentar (o contêiner também anima).
    Connections {
        target: root.cont
        function onHeightChanged() { if (!root.animando) assenta.restart() }
        function onYChanged() { if (!root.animando) assenta.restart() }
    }
    Timer {
        id: assenta
        interval: 1500
        onTriggered: {
            if (root.animando || !root.cont) return
            const h = Math.round(root.cont.height)
            const primeira = !root._restaurada
            if (root.rolada && h > root.alturaRolada + 2 * root.celula) { root._aplicada = false; root.cfg.IsRolled = false; root.cfg.UnrolledHeight = h }
            else if (root.rolada && !root._restaurada) {
                // ao restaurar, o layout impõe a altura mínima dele (minimumItemHeight) à cerca recolhida e
                // ainda pode empurrá-la: volta à altura e ao y guardados
                if (root.cfg.RolledY >= 0) root.cont.y = root.cfg.RolledY
                root.cont.height = root.alturaRolada
                Cores.gravarLayout(root.cont.layout)
            }
            else if (root.rolada && h !== root.alturaRolada) Cores.redimensionar(root.corpo, root.cont.width, root.alturaRolada)
            else if (root.rolada) root.cfg.RolledY = Math.round(root.cont.y)
            else if (!root.rolada && h > root.alturaRolada && h !== root.cfg.UnrolledHeight) root.cfg.UnrolledHeight = h
            if (primeira) root._restaurada = true
        }
    }
    // ao iniciar: procura o contêiner
    Timer {
        id: procura
        interval: 300; repeat: true; running: root.cont === null; property int n: 0
        onTriggered: {
            if (++n > 20) { stop(); return }
            root.cont = Cores.conteiner(root.corpo)
            if (root.cont) {
                if (!root.rolada && root.cfg.UnrolledHeight <= 0) root.cfg.UnrolledHeight = Math.round(root.cont.height)
                assenta.restart()
            }
        }
    }

    // ---- recolher ao sair o mouse. O evento de saída escapa (menus, arraste, janelas por cima): a cada
    // 400 ms confere o ponteiro contra o retângulo da cerca, pela posição vista por toda a área de trabalho.
    readonly property bool _modoEdicao: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode === true : false
    readonly property bool autoRecolher: cfg.gatilho === "sair" && !_modoEdicao && naMesa
    HoverHandler {
        id: hvMesa
        parent: root.cont ? root.cont.parent : root
        enabled: root.autoRecolher
        blocking: false
    }
    property real _segurarAte: 0              // depois do botão direito o menu fica aberto fora do retângulo
    property int _foras: 0
    function _noRetangulo(p) { return !!cont && p.x >= cont.x && p.x <= cont.x + cont.width && p.y >= cont.y && p.y <= cont.y + cont.height }
    // hvMesa só vê o ponteiro onde nenhuma área de dentro da cerca o consumiu: se ela o vê fora do retângulo,
    // está fora, mesmo que a saída de uma área de dentro tenha escapado
    function _ponteiroDentro() {
        if (hvMesa.hovered) return _noRetangulo(hvMesa.point.position)
        const v = camada ? camada.view : null
        return !!(areaTitulo && areaTitulo.containsMouse) || (!_desconfiar && !!(v && v.ponteiroDentro))
    }
    property Item areaTitulo: null
    // o menu de contexto come a saída da área de dentro: depois dele ela não vale mais, até recolher
    property bool _desconfiar: false
    function _ocupada() {
        const v = camada ? camada.view : null
        return animando || containsDrag || Date.now() < _segurarAte || (v && (v.dragging || (v.editor && v.editor.targetItem)))
    }
    Timer {
        interval: 400; repeat: true; running: root.autoRecolher
        onTriggered: {
            const dentro = root._ponteiroDentro()
            if (root.rolada) {
                root._foras = 0; root._desconfiar = false
                if (dentro && !root._ocupada()) root.abrir()
            } else if (dentro || root._ocupada()) root._foras = 0
            else if (++root._foras >= 2) { root._foras = 0; root.recolher() }
        }
    }

    // ---- comandos curtos (auxiliar da cerca e o arquivo de ocultar)
    readonly property string auxiliar: decodeURIComponent(Qt.resolvedUrl("../code/cerca.py").toString().replace(/^file:\/\//, ""))
    function aspas(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    property int _seq: 0
    property var _pendentes: ({})
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            exec.disconnectSource(fonte)
            const f = root._pendentes[fonte]
            delete root._pendentes[fonte]
            if (!f) return
            let r = { ok: false, erro: "sistema", detalhe: dados.stderr || "" }
            try { r = JSON.parse(dados.stdout) } catch (e) { }
            f(r)
        }
    }
    function rodar(cmd, depois) {
        const fonte = cmd + " #" + Plasmoid.id + "." + (++_seq)          // comando igual não pode cair na mesma fonte
        if (depois) _pendentes[fonte] = depois
        exec.connectSource(fonte)
    }
    function chamar(args, depois) { rodar("python3 " + aspas(auxiliar) + " " + args.map(aspas).join(" "), depois) }

    // ---- aviso dentro da cerca (com "desfazer", quando houver)
    property string avisoTexto: ""
    property string avisoDiario: ""
    function avisar(texto, diario) { avisoTexto = texto; avisoDiario = diario || ""; fimAviso.restart() }
    Timer { id: fimAviso; interval: 8000; onTriggered: root.avisoTexto = "" }
    function desfazer() {
        const d = avisoDiario
        avisoTexto = ""; avisoDiario = ""
        if (d) chamar(["desfazer", d], (r) => avisar(r.ok && !r.falhas.length ? t("Desfeito", "Undone") : t("Nem tudo voltou", "Not everything went back")))
    }

    // ---- soltar: mover direto
    function _urlsLocais(ev) {
        const u = (ev.mimeData.urls || []).map(String)
        return u.length && u.every(x => x.indexOf("file:") === 0) ? u : null
    }
    function soltarArquivos(ev, pos) {
        if (ev.mimeData.formats.indexOf("text/x-plasmoidinstanceid") >= 0) return false
        const v = camada ? camada.view : null
        // a cerca "lista" não move nada: guarda um link (na primeira aba; as outras são pastas comuns)
        if (ehLista && aba === 0 && v && !v.arrasteInterno) {
            const todas = (ev.mimeData.urls || []).map(String)
            if (!todas.length || !cfg.pastaLista) return false
            ev.accept(Qt.CopyAction)
            chamar(["ligar", cfg.pastaLista].concat(todas), (r) => {
                if (r.ok && r.n > 0) avisar(t(r.n + (r.n > 1 ? " itens adicionados" : " item adicionado"), r.n + (r.n > 1 ? " items added" : " item added")), r.diario)
                else avisar(t("Nada foi adicionado", "Nothing was added"))
            })
            return true
        }
        if (cfg.soltar !== "mover") return false
        const urls = _urlsLocais(ev)
        if (!urls || !v) return false            // trash:/, remoto...: o caminho normal da KDE
        // em cima de uma subpasta, entra nela; fora disso, na pasta da cerca
        const g = v.view
        const c = v.mapToItem(g.contentItem, pos.x, pos.y)
        const alvo = g.safeItemAt(c.x, c.y)
        const naSubpasta = !!alvo && !alvo.blank && alvo.isDir
        if (v.arrasteInterno && !naSubpasta) return false                // arrumar a própria grade
        const destino = decodeURIComponent((naSubpasta ? String(alvo.model.url) : pastaUrl).replace(/^file:\/\//, ""))
        // só o Ctrl diz: no Wayland, proposedAction vem Copy de qualquer jeito
        const copiar = !!(ev.modifiers & Qt.ControlModifier)
        ev.accept(Qt.CopyAction)                 // quem arrastou não precisa apagar nada: já foi feito aqui
        chamar(["soltar", copiar ? "copiar" : "mover", destino].concat(urls), (r) => {
            if (!r.ok) { avisar(t("Não deu para soltar aqui", "Could not drop here")); return }
            if (r.n > 0 && r.acao === "mover") avisar(t(r.n + (r.n > 1 ? " itens movidos" : " item movido"), r.n + (r.n > 1 ? " items moved" : " item moved")), r.diario)
            else if (r.n > 0) avisar(t(r.n + (r.n > 1 ? " itens copiados" : " item copiado"), r.n + (r.n > 1 ? " items copied" : " item copied")))
            else if (r.falhas.length) avisar(t("Nada foi movido", "Nothing was moved"))
        })
        return true
    }

    // ---- título em edição: nova cerca e renomear
    readonly property bool nova: cfg.novaCerca
    property bool editando: false
    property string proposta: ""              // nome livre, depois de um conflito
    property Item campoTitulo: null
    readonly property string pastaLocal: _localDe(pastaPrincipal)
    // o CLI já mandou o título (janela do atalho): a cerca nasce pronta, sem edição
    readonly property bool _comTitulo: nova && String(cfg.titulo || "").trim() !== ""
    on_ComTituloChanged: if (_comTitulo) { editando = false; cfg.novaCerca = false }
    function _local(l) { return decodeURIComponent(StandardPaths.writableLocation(l).toString().replace(/^file:\/\//, "")) }
    readonly property string basePadrao: _local(StandardPaths.DocumentsLocation) + "/Cercas"
    // pastas do sistema nunca mudam de nome: nelas só o título da cerca muda
    readonly property var protegidas: [StandardPaths.HomeLocation, StandardPaths.DesktopLocation, StandardPaths.DocumentsLocation,
        StandardPaths.DownloadLocation, StandardPaths.PicturesLocation, StandardPaths.MusicLocation, StandardPaths.MoviesLocation].map(_local)
    function _ativarTeclado() {
        const j = root.Window.window
        if (j) j.requestActivate()
        if (campoTitulo) campoTitulo.forceActiveFocus(Qt.OtherFocusReason)
    }
    function editarTitulo() {
        if (editando) return
        proposta = ""
        editando = true
        if (campoTitulo) { campoTitulo.text = nova ? "" : tituloCerca; campoTitulo.selectAll() }
        Qt.callLater(_ativarTeclado)
    }
    function cancelarTitulo() {
        editando = false
        proposta = ""
        if (nova) {
            if (cfg.url) chamar(["remover-vazia", cfg.url])       // a "Cerca N" que o CLI criou para ela
            cfg.url = ""
            _removerSemAviso()
        }
    }
    // o "remove" do applet avisa "Widget removido: <título>" e oferece Desfazer, que não cabe a uma cerca que
    // nem nasceu; pelo script do shell não há aviso. Sem o script (mesa travada), título neutro, e o Desfazer
    // a traz de volta pedindo o nome (novaCerca fica ligada).
    function _removerSemAviso() {
        const js = "var ds=desktops();for(var i=0;i<ds.length;i++){var w=ds[i].widgetById(" + Plasmoid.id + ");if(w)w.remove()}"
        rodar("timeout 5 qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript " + aspas(js)
              + " >/dev/null 2>&1 && echo '{\"ok\":true}' || echo '{\"ok\":false}'", (r) => {
            if (r.ok) return
            Plasmoid.title = t("Cerca sem nome", "Unnamed fence")
            Plasmoid.internalAction("remove").trigger()
        })
    }
    function confirmarTitulo() {
        const nome = campoTitulo.text.trim()
        if (nova) {
            if (!nome) return
            const pronta = (r) => { cfg.url = r.caminho; cfg.titulo = ""; cfg.novaCerca = false; editando = false; proposta = "" }
            if (cfg.url) _renomearPasta(nome, pronta)
            else chamar(["criar", cfg.base || basePadrao, nome], (r) => { if (r.ok) pronta(r); else _falhaTitulo(r) })
            return
        }
        const pasta = pastaLocal.split("/").pop()
        if (ehLista) { cfg.titulo = nome; editando = false; return }
        if (!nome || nome === pasta) { cfg.titulo = ""; editando = false; return }
        if (protegidas.indexOf(pastaLocal) >= 0 || pastaPrincipal.indexOf("file://") !== 0) {
            cfg.titulo = nome; editando = false
            avisar(t("Só o título mudou: esta pasta é do sistema", "Only the title changed: this is a system folder"))
            return
        }
        _renomearPasta(nome, (r) => { cfg.url = r.caminho; cfg.titulo = ""; editando = false; proposta = "" })
    }
    function _falhaTitulo(r) {
        if (r.erro === "conflito") {
            proposta = r.proposta
            campoTitulo.text = r.proposta
            campoTitulo.selectAll()
        } else avisar(r.erro === "nome" ? t("Nome inválido", "Invalid name") : t("Não deu para usar este nome", "Could not use this name"))
    }

    // ---- mover pelo título (e redimensionar pelo canto), sem o modo de edição
    readonly property bool podeMexer: !Plasmoid.immutable && naMesa && !!cont
    property real _x0: 0
    property real _y0: 0
    property bool movendo: false
    function iniciarMover() {
        _x0 = cont.x; _y0 = cont.y
        movendo = true
        cont.layout.releaseSpace(cont)
    }
    function mover(dx, dy) {
        const L = cont.parent
        cont.x = Math.max(0, Math.min(_x0 + dx, L.width - cont.width))
        cont.y = Math.max(0, Math.min(_y0 + dy, L.height - cont.height))
    }
    function assentar() { assenta.restart() }
    function terminarMover() {
        movendo = false
        cont.layout.positionItem(cont)
        // o layout impõe a altura mínima dele: recolhida, volta ao título e guarda o y (ver "assenta")
        if (rolada) { cont.height = alturaRolada; cfg.RolledY = Math.round(cont.y) }
        Cores.gravarLayout(cont.layout)
        assenta.restart()
    }

    // ---- ocultar e exibir todas
    readonly property url pastaEstado: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/cyberkde/cercas"
    readonly property string arqOcultas: _local(StandardPaths.GenericConfigLocation) + "/cyberkde/cercas/ocultas"
    property bool ocultas: false
    // no modo de edição, todas à vista; "não ocultar" é por cerca
    readonly property bool ocultaAgora: ocultas && !_modoEdicao && !cfg.quickhideExcluir
    // ocultas: só a primeira da mesa avisa, uma vez, para ninguém achar que perdeu tudo
    function _cercasOcultaveis() {
        const c = Plasmoid.containment
        return (c && c.applets ? Array.from(c.applets) : []).filter(a => a.pluginName === "org.cyberkde.cerca" && !(a.configuration && a.configuration.quickhideExcluir))
    }
    property int nOcultas: 0
    Timer { id: fimAvisoOculta; interval: 5000; onTriggered: root.nOcultas = 0 }
    onOcultaAgoraChanged: {
        fimAvisoOculta.stop()
        nOcultas = 0
        if (!ocultaAgora) return
        const l = _cercasOcultaveis()
        if (l.length && Math.min.apply(null, l.map(a => a.id)) === Plasmoid.id) { nOcultas = l.length; fimAvisoOculta.restart() }
    }
    // estado comum em nomes de arquivo na pasta: "ocultas", "peek" e "animacao.<id>"
    property string animacaoComum: ""
    property bool espiando: false
    readonly property string animacaoAtiva: Catalogo.de(animacaoComum || cfg.animacao).id
    property string animIconesComum: ""
    readonly property string animacaoIconesAtiva: CatIcones.de(animIconesComum || cfg.animacaoIcones).id
    readonly property var _animI: camada && camada.view ? camada.view.animIcones : null
    function _lerEstado() {
        let o = false, pk = false, an = "", ai = ""
        for (let i = 0; i < vigia.count; i++) {
            const n = vigia.get(i, "fileName")
            if (n === "ocultas") o = true
            else if (n === "peek") pk = true
            else if (n.indexOf("animacao.") === 0) an = n.slice(9)
            else if (n.indexOf("animicones.") === 0) ai = n.slice(11)
        }
        ocultas = o; espiando = pk; animacaoComum = an; animIconesComum = ai
    }
    // escolhida em qualquer cerca (CLI, painel, configurar), vale para todas
    readonly property string _dirEstado: arqOcultas.replace(/\/[^/]*$/, "")
    Connections {
        target: root.cfg
        function onAnimacaoChanged() {
            const id = Catalogo.de(root.cfg.animacao).id
            if (id === root.animacaoComum) return
            root.animacaoComum = id
            root.rodar("rm -f " + root.aspas(root._dirEstado) + "/animacao.* && touch " + root.aspas(root._dirEstado + "/animacao." + id))
        }
        function onAnimacaoIconesChanged() {
            const id = CatIcones.de(root.cfg.animacaoIcones).id
            if (id === root.animIconesComum) return
            root.animIconesComum = id
            root.rodar("rm -f " + root.aspas(root._dirEstado) + "/animicones.* && touch " + root.aspas(root._dirEstado + "/animicones." + id))
        }
    }
    FolderListModel {
        id: vigia             // a pasta precisa existir antes: o vigia não enxerga a que nasce depois
        nameFilters: ["ocultas", "peek", "animacao.*", "animicones.*"]
        showDirs: false
        showHidden: true
        onCountChanged: if (status === FolderListModel.Ready) root._lerEstado()
        onStatusChanged: if (status === FolderListModel.Ready) root._lerEstado()
    }
    function definirOcultas(sim) {
        ocultas = sim
        rodar((sim ? "touch " : "rm -f ") + aspas(arqOcultas))
    }
    // "ocultar cercas junto" dos widgets (comum/Ocultacao.qml): o gesto daqui leva os widgets também, e
    // todos calculam o mesmo alvo a partir do estado das cercas
    readonly property string _dirWidgets: _dirEstado.replace(/[^/]*$/, "") + "widgets"
    property bool _gestoJunto: false
    function _lerWidgets() {
        let ge = false, ju = false
        for (let i = 0; i < vigiaWidgets.count; i++) {
            const n = vigiaWidgets.get(i, "fileName")
            if (n === "gesto") ge = true
            else if (n === "junto") ju = true
        }
        _gestoJunto = ge && ju
    }
    FolderListModel {
        id: vigiaWidgets
        nameFilters: ["gesto", "junto"]
        showDirs: false
        showHidden: true
        onCountChanged: if (status === FolderListModel.Ready) root._lerWidgets()
        onStatusChanged: if (status === FolderListModel.Ready) root._lerWidgets()
    }
    function _alternarGesto() {
        const alvo = !ocultas
        definirOcultas(alvo)
        if (_gestoJunto) rodar((alvo ? "touch " : "rm -f ") + aspas(_dirWidgets + "/ocultos"))
    }
    // 1 linha de cascata: a ordem vem da posição na mesa ("cascata" do catálogo já se sequencia sozinha)
    readonly property int atrasoCascata: {
        const L = cont ? cont.parent : null
        return L && L.width > 0 && animacaoAtiva !== "cascata" ? Math.round(Cores.d(320) * (cont.x / L.width + cont.y / L.height) / 2) : 0
    }
    // "empilhar": a ordem depende de quantas cercas há na mesa (de cima, depois da esquerda)
    readonly property var _cercasPilha: {
        const L = cont ? cont.parent : null, v = []
        if (!L) return v
        for (const c of L.children) if (c.applet && c.applet.Plasmoid && c.applet.Plasmoid.pluginName === Plasmoid.pluginName) v.push(c)
        return v.sort((a, b) => Math.abs(a.y - b.y) > 24 ? a.y - b.y : a.x - b.x)
    }
    readonly property int ordemPilha: Math.max(0, _cercasPilha.indexOf(cont))
    readonly property int totalPilha: Math.max(1, _cercasPilha.length)
    Binding { when: !!root.cont; target: root.cont; property: "enabled"; value: !root.ocultaAgora; restoreMode: Binding.RestoreBindingOrValue }

    // a mesa vazia. Um plasmoide não recebe clique fora dele, mas alcança a área de trabalho: com ícones (a
    // mesa padrão), quem fica com o clique é o MouseArea do FolderView do containment, e aqui só se ouve o
    // sinal dele (o que vale para qualquer papel de parede). Sem ícones, o layout fica com o clique.
    property real _ultimoClique: 0
    property point _pontoClique
    function _toqueNaMesa(x, y) {
        const agora = Date.now()
        const perto = Math.abs(x - _pontoClique.x) + Math.abs(y - _pontoClique.y) < Application.styleHints.startDragDistance
        if (agora - _ultimoClique <= Application.styleHints.mouseDoubleClickInterval && perto) {
            _ultimoClique = 0
            _alternarGesto()
        } else {
            _ultimoClique = agora
            _pontoClique = Qt.point(x, y)
        }
    }
    readonly property Item ouvinteMesa: {
        const g = cont && cont.parent ? cont.parent.eventManagerToFilter : null
        for (let p = g; p; p = p.parent) if (p.pressX !== undefined && p.hoveredItem !== undefined) return p
        return null
    }
    Connections {
        target: root.ouvinteMesa
        enabled: !root._modoEdicao && root.cfg.gestoOcultar
        function onPressed(m) {
            const it = root.ouvinteMesa.hoveredItem
            if (m.button === Qt.LeftButton && !m.modifiers && (!it || it.blank)) root._toqueNaMesa(m.x, m.y)
        }
    }
    TapHandler {
        parent: root.cont ? root.cont.parent : root
        enabled: !!root.cont && !root.ouvinteMesa && !root._modoEdicao && root.cfg.gestoOcultar
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.DragThreshold
        onDoubleTapped: { for (const k of parent.children) if (k.editModeCondition !== undefined && k.visible && k.enabled && k.contains(k.mapFromItem(parent, point.position))) return; root._alternarGesto() }
    }

    PlasmaCore.Action {
        id: acaoRolar
        text: root.rolada ? root.t("Abrir o Cyber Fence", "Open Cyber Fence") : root.t("Recolher o Cyber Fence", "Roll up Cyber Fence")
        icon.name: root.rolada ? "go-down" : "go-up"
        onTriggered: root.alternar()
    }
    Component.onCompleted: {
        Plasmoid.contextualActions.push(acaoRolar)
        Plasmoid.contextualActions.push(acaoAba)
        Plasmoid.contextualActions.push(acaoTirarAba)
        const remover = Plasmoid.internalAction("remove")
        if (remover) remover.text = t("Remover a cerca (a pasta e os arquivos ficam)", "Remove the fence (the folder and files stay)")
        rodar("mkdir -p " + aspas(_dirEstado) + " " + aspas(_dirWidgets), () => {
            vigia.folder = pastaEstado
            vigiaWidgets.folder = "file://" + _dirWidgets
        })
        _garantirLista()
    }
    // a chave pode vir no carregamento ou logo depois (o CLI grava depois de criar o applet)
    onCampoTituloChanged: if (campoTitulo && nova) editarTitulo()
    onNovaChanged: if (campoTitulo && nova) editarTitulo()
    onContChanged: if (cont && editando) Qt.callLater(_ativarTeclado)

    PlasmaCore.Action {
        id: acaoAba
        text: root.t("Adicionar aba…", "Add tab…")
        icon.name: "tab-new"
        onTriggered: dlgAba.open()
    }
    PlasmaCore.Action {
        id: acaoTirarAba
        text: root.t("Remover esta aba", "Remove this tab")
        icon.name: "tab-close"
        visible: root.aba > 0
        onTriggered: root.removerAba()
    }
    FolderDialog { id: dlgAba; onAccepted: root.adicionarAba(selectedFolder) }

    // ---- peek: as cercas por cima das janelas, enquanto "peek" existir (uma janela própria, por cerca)
    function _papelDeParede() {
        for (let p = cont ? cont.parent : null; p; p = p.parent)
            for (const k of p.children)
                if (k.pluginName !== undefined && k.configuration !== undefined) return k
        return null
    }
    Loader {
        active: root.espiando && !!root.cont && !root.ocultaAgora
        sourceComponent: PlasmaCore.Dialog {
            id: dlgPeek
            visible: true
            type: PlasmaCore.Dialog.OnScreenDisplay
            flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
            hideOnWindowDeactivate: false
            backgroundHints: PlasmaCore.Types.NoBackground
            outputOnly: false
            readonly property point g: root.cont.mapToGlobal(0, 0)
            x: g.x; y: g.y
            mainItem: Item {
                width: root.cont.width; height: root.cont.height
                Moldura {
                    anchors.fill: parent
                    margem: 10
                    cor: root.corCerca
                    opacidade: 1
                    titulo: root.tituloCerca
                    codigo: "PEEK"
                    tituloSistema: true
                    FitaAbas { id: fitaPeek; cerca: root; width: parent.width }
                    FolderViewLayer {
                        visible: !root.rolada
                        anchors.fill: parent
                        anchors.topMargin: fitaPeek.height + (fitaPeek.visible ? 4 : 0)
                        isPopup: false
                        useListViewMode: false
                    }
                }
            }
        }
    }

    Component {
        id: painel
        Item {
            id: pn
            anchors.fill: parent
            // ocultar e exibir: AnimacaoCerca desenha este item pelo shader (sem clip aqui)
            Item {
                id: conteudo
                anchors.fill: parent
            // blur: o próprio papel de parede, desfocado, atrás da moldura
            Loader {
                active: root.cfg.blur
                anchors.fill: parent
                sourceComponent: Item {
                    readonly property Item papel: root._papelDeParede()
                    readonly property point o: papel && root.cont ? root.cont.mapToItem(papel, 0, 0) : Qt.point(0, 0)
                    ShaderEffectSource {
                        id: fonteBlur
                        anchors.fill: parent
                        visible: false
                        sourceItem: parent.papel
                        live: !anim.oculta
                        sourceRect: Qt.rect(parent.o.x, parent.o.y, width, height)
                    }
                    Chanfro { id: formaBlur; anchors.fill: parent; corte: 12; preenchimento: "white"; borda: "transparent"; visible: false; layer.enabled: true }
                    MultiEffect {
                        anchors.fill: parent
                        source: fonteBlur
                        blurEnabled: true; blur: 1; blurMax: 48
                        maskEnabled: true; maskSource: formaBlur
                        autoPaddingEnabled: false
                    }
                }
            }
            // a moldura desenhada, presa ao topo ou (na metade de baixo) à base
            FolderViewDropAreaCerca {
                id: soltar
                width: parent.width
                height: root.alturaMoldura
                y: root.ancBaixo && root.alturaDesenho >= 0 ? parent.height - height : 0
                folderView: cam.view
                interceptar: root.soltarArquivos
                Moldura {
                    id: mold
                    anchors.fill: parent
                    margem: 10
                    cor: root.corCerca
                    opacidade: root.opac
                    tituloSistema: true
                    titulo: root.editando ? "" : root.tituloCerca
                    codigo: mouseTitulo.containsMouse ? "CYBER.FENCE" : ""
                    extra: [
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cam.view ? cam.view.view.count : 0
                            font.family: Cores.fMono; font.pixelSize: 11; color: Cores.texto2
                        },
                        Text {
                            visible: !root.editando
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.rolada ? "▸" : "▾"
                            font.pixelSize: 13; color: areaSeta.containsMouse ? root.corCerca : Cores.texto2
                        }
                    ]
                    // abas: só com mais de uma pasta
                    FitaAbas {
                        id: fitaAbas
                        cerca: root
                        width: parent.width
                        Component.onCompleted: root.fitaAbas = fitaAbas
                        opacity: !root.rolada || root.animando ? 1 : 0
                    }
                    Item {
                        id: janela
                        anchors.fill: parent
                        anchors.topMargin: fitaAbas.height + (fitaAbas.visible ? 4 : 0)
                        // a grade usa a altura toda (cortar em linhas inteiras escondia uma fileira que cabia)
                        anchors.bottomMargin: root.layoutCerca === "inventario" ? 38 : 0
                        clip: true
                        visible: (!root.rolada || root.animando) && !root.nova
                        opacity: root.rolada ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Cores.d(160) } }
                        FolderViewLayer {
                            id: cam
                            width: parent.width
                            height: root.animando ? Math.max(parent.height, root.cfg.UnrolledHeight - 56) : parent.height
                            isPopup: false
                            useListViewMode: false
                            Component.onCompleted: root.camada = cam
                            // clicar num item leva o teclado para a grade, como o containment faz na mesa
                            Connections { target: cam.view; function onPressed() { const j = root.Window.window; if (j) j.requestActivate(); cam.forceActiveFocus() } }
                            onActiveFocusChanged: if (!activeFocus && cam.view && !cam.view.dragging) cam.view.model.clearSelection()
                            Connections { target: cam.view; function onMenuPedido() { root._segurarAte = Date.now() + 10000; root._desconfiar = true } }
                        }
                    }
                    // inventário: a zona de inspeção, com o item sob o mouse ou o selecionado
                    Column {
                        visible: root.layoutCerca === "inventario" && !root.rolada
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        spacing: 1
                        readonly property var it: cam.view ? cam.view.inspecionado : null
                        Rectangle { width: parent.width; height: 1; color: root.corCerca; opacity: 0.4 }
                        Text {
                            width: parent.width; elide: Text.ElideMiddle
                            text: parent.it ? parent.it.name : root.t("Passe o mouse sobre um item", "Hover an item")
                            font.family: Cores.fTexto; font.pixelSize: 12; color: parent.it ? Cores.texto : Cores.texto2
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: parent.it ? [parent.it.etiqueta, String(parent.it.model.size || "")].filter(x => x).join(" · ") : ""
                            font.family: Cores.fMono; font.pixelSize: 10; color: Cores.texto2
                        }
                    }
                    // vazia: diz o que fazer
                    Item {
                        visible: !root.nova && !!cam.view && cam.view.view.count === 0 && cam.view.status === Folder.FolderModel.Ready && (!root.rolada || root.animando)
                        anchors.fill: parent
                        anchors.topMargin: fitaAbas.height + 4
                        anchors.bottomMargin: 4
                        Item { id: vazia; anchors.fill: parent }
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: Cores.alfa(root.corCerca, 0.5); strokeWidth: 1; fillColor: "transparent"
                                strokeStyle: ShapePath.DashLine; dashPattern: [5, 4]
                                startX: 0; startY: 0
                                PathLine { relativeX: vazia.width; relativeY: 0 }
                                PathLine { relativeX: 0; relativeY: vazia.height }
                                PathLine { relativeX: -vazia.width; relativeY: 0 }
                                PathLine { relativeX: 0; relativeY: -vazia.height }
                            }
                        }
                        Text {
                            anchors.centerIn: parent; width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            text: root.mimesFiltro.length ? root.t("Nada deste tipo aqui", "Nothing of this type here") : root.t("Solte arquivos aqui", "Drop files here")
                            font.family: Cores.fTexto; font.pixelSize: 13; color: Cores.texto2
                        }
                    }
                    // nova cerca: ainda sem pasta
                    Text {
                        visible: root.nova
                        anchors.fill: parent; anchors.margins: 6
                        wrapMode: Text.WordWrap
                        text: root.t("Digite o nome e Enter para criar a pasta. Esc desiste.", "Type the name and press Enter to create the folder. Esc cancels.")
                        font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto2
                    }
                }
                // o título: mover, recolher e renomear
                MouseArea {
                    id: mouseTitulo
                    Component.onCompleted: root.areaTitulo = mouseTitulo
                    width: parent.width; height: root.alturaTitulo
                    hoverEnabled: true
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    enabled: !root._modoEdicao && !root.editando
                    cursorShape: root.movendo ? Qt.ClosedHandCursor : root.podeMexer ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property point inicio
                    property bool arrastou: false
                    onPressed: (m) => { inicio = mapToItem(null, m.x, m.y); arrastou = false }
                    onPositionChanged: (m) => {
                        if (!pressed || !root.podeMexer) return
                        const p = mapToItem(null, m.x, m.y)
                        const dx = p.x - inicio.x, dy = p.y - inicio.y
                        if (!arrastou && Math.abs(dx) + Math.abs(dy) >= Application.styleHints.startDragDistance) {
                            arrastou = true
                            cliqueSimples.stop()
                            root.iniciarMover()
                        }
                        if (arrastou) root.mover(dx, dy)
                    }
                    onReleased: if (arrastou) root.terminarMover()
                    onCanceled: if (arrastou) root.terminarMover()
                    onClicked: (m) => {
                        if (arrastou) return
                        if (m.modifiers & Qt.ControlModifier) root.alternar()
                        else if (root.cfg.gatilho === "clique") cliqueSimples.restart()   // pode ser o início de um duplo
                    }
                    onDoubleClicked: { cliqueSimples.stop(); root.editarTitulo() }
                    Timer { id: cliqueSimples; interval: Application.styleHints.mouseDoubleClickInterval; onTriggered: root.alternar() }
                    Timer { id: esperaDica; interval: 900; onTriggered: { dicaTitulo.visible = true; fimDica.restart() } }
                    Timer { id: fimDica; interval: 4000; onTriggered: dicaTitulo.visible = false }
                    readonly property bool parado: containsMouse && !pressed && !root.movendo
                    onParadoChanged: { dicaTitulo.visible = false; if (parado) esperaDica.restart(); else esperaDica.stop() }
                }
                // a seta recolhe sempre, em qualquer gatilho
                MouseArea {
                    id: areaSeta
                    anchors.right: parent.right; anchors.rightMargin: 4
                    y: 3; width: 28; height: 28
                    hoverEnabled: true
                    enabled: !root._modoEdicao && !root.editando
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.alternar()
                }
                // faixa da cor da cerca, em todo o título
                Rectangle {
                    x: 10; y: 33; width: parent.width - 20; height: 1
                    color: root.corCerca
                    opacity: 0.4
                }
                // dica do título (com o nome inteiro, que pode estar cortado)
                Rectangle {
                    id: dicaTitulo
                    visible: false
                    x: 10; y: 36; z: 20
                    width: Math.min(parent.width - 20, tDica.implicitWidth + 12); height: tDica.implicitHeight + 8
                    color: Cores.alfa(Cores.escuro, 0.95); border.color: Cores.alfa(root.corCerca, 0.7)
                    Text {
                        id: tDica
                        x: 6; y: 4; width: Math.min(implicitWidth, dicaTitulo.parent.width - 32)
                        wrapMode: Text.WordWrap
                        text: root.tituloCerca + (root.rolada ? "  ·  " + (cam.view ? cam.view.view.count : 0) + root.t(" itens", " items") : "") + "\n"
                              + root.t("Arraste para mover · duplo clique renomeia · ▾ recolhe", "Drag to move · double-click renames · ▾ rolls up")
                        font.family: Cores.fTexto; font.pixelSize: 11; color: Cores.texto
                    }
                }
                // o nome em edição, no lugar do título
                Item {
                    visible: root.editando
                    x: 10; y: 4
                    width: parent.width - 20; height: 28
                    Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.escuro, 0.7); border.color: Cores.destaque }
                    TextInput {
                        id: campo
                        Component.onCompleted: root.campoTitulo = campo
                        anchors.fill: parent; anchors.margins: 5
                        clip: true
                        selectByMouse: true
                        maximumLength: 120
                        font.family: Cores.fTexto; font.pixelSize: 14
                        color: Cores.texto
                        selectionColor: Cores.destaque
                        selectedTextColor: Cores.escuro
                        onTextEdited: root.proposta = ""
                        Keys.onReturnPressed: root.confirmarTitulo()
                        Keys.onEnterPressed: root.confirmarTitulo()
                        Keys.onEscapePressed: root.cancelarTitulo()
                        Text {
                            visible: !campo.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.t("Nome da cerca", "Fence name")
                            font: campo.font; color: Cores.texto3
                        }
                    }
                }
                // arraste por cima: "solte aqui"
                Item {
                    visible: root.containsDrag && !(cam.view && cam.view.arrasteInterno)
                    anchors.fill: parent
                    z: 15
                    Chanfro { anchors.fill: parent; corte: 12; preenchimento: Cores.alfa(root.corCerca, 0.10); borda: root.corCerca; espessura: 2 }
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width - 20, linhaAlvo.width + 16); height: 24; clip: true
                        color: Cores.alfa(Cores.escuro, 0.92); border.color: root.corCerca
                        Row {
                            id: linhaAlvo
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.ehLista && root.aba === 0 ? root.t("ADICIONAR A", "ADD TO") : root.cfg.soltar !== "mover" ? root.t("SOLTAR EM", "DROP IN")
                                      : root._ctrlArraste ? root.t("COPIAR PARA", "COPY TO") : root.t("MOVER PARA", "MOVE TO")
                                font.family: Cores.fTitulo; font.pixelSize: 11; font.weight: Font.Bold; color: root.corCerca
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.nomeAba(root.aba); font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto }
                        }
                    }
                }
                // conflito de nome: propõe outro
                Rectangle {
                    visible: root.proposta !== ""
                    x: 10; y: 34
                    width: parent.width - 20; height: tConflito.implicitHeight + 8
                    color: Cores.alfa(Cores.escuro, 0.92); border.color: Cores.alerta
                    Text {
                        id: tConflito
                        anchors.fill: parent; anchors.margins: 4
                        wrapMode: Text.WordWrap
                        text: root.t("Já existe uma pasta com esse nome. Enter usa o nome acima.", "A folder with that name exists. Enter uses the name above.")
                        font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto
                    }
                }
                // aviso: "N itens movidos · DESFAZER"
                Rectangle {
                    visible: root.avisoTexto !== ""
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 10
                    height: 30
                    color: Cores.alfa(Cores.escuro, 0.94); border.color: Cores.destaque
                    Text {
                        x: 8; width: parent.width - 16 - (btDesfazer.visible ? btDesfazer.width + 8 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.avisoTexto; elide: Text.ElideRight
                        font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto
                    }
                    Text {
                        id: btDesfazer
                        visible: root.avisoDiario !== ""
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        text: root.t("DESFAZER", "UNDO")
                        font.family: Cores.fTitulo; font.pixelSize: 12; font.weight: Font.Bold
                        color: maDesfazer.containsMouse ? Cores.texto : Cores.destaque
                        MouseArea { id: maDesfazer; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.desfazer() }
                    }
                }
                // redimensionar sem o modo de edição: canto (◢ a 40% com o mouse na cerca) e bordas
                AlcaCerca { cerca: root; grade: cam; caixa: janela; anchors.right: parent.right; y: 40; width: 6; height: parent.height - 60; ly: false; cursorShape: Qt.SizeHorCursor }
                AlcaCerca { cerca: root; grade: cam; caixa: janela; anchors.bottom: parent.bottom; width: parent.width - 20; height: 6; lx: false; cursorShape: Qt.SizeVerCursor }
                AlcaCerca {
                    id: canto
                    cerca: root; grade: cam; caixa: janela
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    width: 20; height: 20
                    cursorShape: Qt.SizeFDiagCursor
                    Text {
                        visible: sobreCerca.hovered
                        opacity: canto.containsMouse || canto.pressed ? 1 : 0.4
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 2
                        text: "◢"; font.pixelSize: 12; color: root.corCerca
                    }
                }
                HoverHandler { id: sobreCerca }
            }
            }
            AnimacaoCerca {
                id: anim
                alvo: conteudo
                variante: root.animacaoAtiva
                visivel: !root.ocultaAgora
                atraso: root.animacaoAtiva === "empilhar" ? root.ordemPilha * Cores.d(260) : root.atrasoCascata
                atrasoSaida: root.animacaoAtiva === "empilhar" ? (root.totalPilha - 1 - root.ordemPilha) * Cores.d(130) : root.atrasoCascata
                cor: root.corCerca
                // o contêiner é desabilitado junto: o Binding daqui guardaria o false herdado e o devolveria
                onVisivelChanged: {
                    if (visivel) Qt.callLater(() => conteudo.enabled = true)
                    const v = Catalogo.de(root.animacaoAtiva), ai = root._animI
                    if (!ai) return
                    // os ícones entram quando o corpo da cerca já apareceu, e saem antes dela
                    if (visivel) { ai.preparar(); ai.tocar(atraso + v.duracaoEntrada * 0.45 * Cores.fator) }
                    else ai.sair(Math.min(v.duracaoSaida, 320) * Cores.fator, atrasoSaida >= 0 ? atrasoSaida : atraso)
                }
            }
            // ocultas: fica este aviso por alguns segundos (sem nada permanente na mesa)
            Rectangle {
                visible: root.nOcultas > 0
                x: 10; y: 10; z: 30
                width: tOcultas.implicitWidth + 20; height: 30
                color: Cores.alfa(Cores.escuro, 0.9); border.color: root.corCerca
                Text {
                    id: tOcultas
                    anchors.centerIn: parent
                    text: root.t(root.nOcultas + (root.nOcultas > 1 ? " CERCAS OCULTAS" : " CERCA OCULTA"), root.nOcultas + (root.nOcultas > 1 ? " FENCES HIDDEN" : " FENCE HIDDEN"))
                          + (root.cfg.gestoOcultar ? root.t(" · duplo clique para exibir", " · double-click to show") : "")
                    font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        ocultavel: false       // as cercas têm estado e animação próprios
        id: tam
        modo: root.modo
        pedido: root.pedidoPreset
        aplicarAoIniciar: !root.cfg.ajustado
        onPresetAplicado: if (!root.cfg.ajustado) root.cfg.ajustado = true
        onEscolherPreset: (m) => root.mudarModo(m)
        limiteCartao: Qt.size(0, 0)              // a mesma moldura em qualquer tamanho
        alturaMinima: root.alturaRolada
        controlesDireita: root.rolada            // recolhida, a faixa de edição não cobre o título
        // abaixo da cerca, sem cobrir os ícones, se houver espaço na mesa
        controlesFora: !root.rolada && !!root.cont && !!root.cont.parent && root.cont.y + root.cont.height + 30 < root.cont.parent.height
        naMesa: root.naMesa
        opacidade: root.opac
        pequeno: painel
        completo: painel
        tamanhoPequeno: Qt.size(256, 176)
        tamanhoMedio: Qt.size(352, 256)
        tamanhoGrande: Qt.size(480, 368)
        Component.onCompleted: root.corpo = tam
    }
}
