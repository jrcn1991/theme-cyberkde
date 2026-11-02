import QtQuick
import QtQuick.Window
import QtCore
import "../../qml"

// DATASHARD: gerenciador de arquivos do CyberKDE (docs/interno/arquivos-spec.md). Interface do Deckard;
// back-end do Arquivista (objeto de contexto "arquivos"). Cabeçalho de sistema, abas, barra de comando,
// Locais | visão (PILHAS, LISTA, GRADE) | LOG, rodapé; modais de prévia, propriedades, confirmação,
// conflito e fila; menu de contexto; teclado (seção 11); transições (seção 12, em PainelVisao).
// Paridade com o Dolphin (spec 20): tela dividida (F3), desfazer, duplicar, criar novo (link, modelos),
// renomeação em lote, etiquetas/estrelas/comentário, ServiceMenus, propriedades e permissões em lote,
// desmontar/ejetar com confirmação, seleção por padrão, histórico, agrupar, filtros da busca, zoom e
// atalhos configuráveis (arquivos.atalhos; tela em F1).
Window {
    id: janela
    width: (opcoes && opcoes.largura) || 1440
    height: (opcoes && opcoes.altura) || 900
    minimumWidth: 900
    minimumHeight: 560
    visible: true
    color: Tema.base
    title: "DATASHARD // " + (arquivos.aba ? arquivos.aba.titulo : "")

    // ---- estado da janela
    property bool logVisivel: true
    property bool locaisVisiveis: true
    readonly property bool logGaveta: width < 1100       // abaixo de 1100 px o LOG vira gaveta
    // a gaveta começa fechada (e fecha ao estreitar): abre por ≡ ou F11; Esc e clique fora fecham
    onLogGavetaChanged: if (logGaveta) logVisivel = false
    property string renomeando: ""                       // caminho em renomeação
    readonly property bool dividido: !!arquivos.dividido && !!arquivos.painelDireito
    readonly property var painelAtivo: dividido && arquivos.ladoAtivo === "direito" ? painelD : painelE
    readonly property bool focoNaArea: painelAtivo.focado
    readonly property var aba: arquivos.aba
    readonly property var visao: painelAtivo.visao
    readonly property bool modalAberto: previa.aberto || props.aberto || confirmar.aberto || conflito.aberto || fila.aberto
                                        || disco.aberto || entrada.aberto || lote.aberto || propVarias.aberto || apps.aberto || atalhosTela.aberto
    function passarVarredura() { varredura.passar() }

    // ---- PILHAS: agrupar os arquivos soltos por tipo (padrão: desligado, cada arquivo é um cartão).
    // Se o back-end der aba.agruparTipos (lembrado por pasta), vale ele; senão fica aqui, global, num
    // .ini da interface (~/.config/cyberkde/datashard-interface.ini).
    Settings {
        id: prefsUi
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/cyberkde/datashard-interface.ini"
        category: "pilhas"
        property bool agruparTipos: false
    }
    // colunas da LISTA (clique direito no cabeçalho)
    Settings {
        id: prefsListaObj
        location: prefsUi.location
        category: "lista"
        property bool tipo: true
        property bool tamanho: true
        property bool data: true
        property bool hex: true
        property bool perm: true
    }
    property alias prefsLista: prefsListaObj
    function abrirMenu(lista, ponto) { menu.abrir(lista, ponto) }
    function agruparTiposDe(a) { return a && typeof a.agruparTipos === "boolean" ? a.agruparTipos : prefsUi.agruparTipos }
    function alternarAgruparTipos() {
        if (aba && typeof aba.agruparTipos === "boolean") aba.agruparTipos = !aba.agruparTipos
        else prefsUi.agruparTipos = !prefsUi.agruparTipos
    }
    property string roteiroJs: ""                        // (testes) JS avaliado depois de carregar
    // agenda uma função (roteiros de teste e ações que esperam a interface assentar)
    function depois(ms, f) {
        const t = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", janela)
        t.interval = ms
        t.triggered.connect(() => { f(); t.destroy() })
        t.start()
    }
    onRoteiroJsChanged: if (roteiroJs) { try { (new Function("janela", "arquivos", roteiroJs))(janela, arquivos) } catch (e) { console.log("roteiro:", e) } }

    Binding { target: Tema; property: "paletaSistema"; value: arquivos.paleta }
    Binding { target: Tema; property: "reduzir"; value: arquivos.reduzir }
    Binding { target: Tema; property: "efeitos"; value: janela.contentItem.GraphicsInfo.api !== GraphicsInfo.Software }
    Binding { target: Ds; property: "idioma"; value: arquivos.idioma }
    Binding { target: Ds; property: "catalogo"; value: arquivos.textos }
    Binding { target: Txt; property: "textos"; value: ({ "comum.off": "OFF", "comum.on": "ON" }) }
    Component.onCompleted: { Ds.janela = janela; if (logGaveta) logVisivel = false; focarArea() }

    // ---- avisos
    function avisar(nivel, texto) { avisos.mostrar(nivel, texto, "", false) }
    Connections {
        target: arquivos
        function onNotificar(nivel, texto) { avisos.mostrar(nivel, texto, "", false) }
        // D-Bus ShowItemProperties (FileManager1): abre o modal de propriedades do item
        function onPedirPropriedades(caminho) { props.mostrar(caminho) }
        // desmontar/ejetar só com a confirmação (abas e operações afetadas)
        function onConfirmacaoNecessaria(acao, mapa) { disco.pedir(acao, mapa) }
        // criado por modelo/link: entra em renomeação quando a pasta recarregar
        function onItemCriado(caminho) { janela._renomearNovo = caminho }
        function onOperacaoTerminou(id, estado, texto, criados) {
            avisos.mostrar(estado === "ok" ? "ok" : estado === "cancelada" ? "info" : "erro", texto + " · " + Ds.t("op." + estado),
                           "op" + id, estado === "ok")
            // o resultado fica selecionado: pelos "criados" do back-end; sem eles, pelo que ficou novo na pasta
            if (estado === "ok") { if (criados && criados.length) janela.selecionarCriados(criados); else janela.procurarNovos() }
        }
        function onOperacoesMudou() {
            const c = (arquivos.operacoes || []).find(o => o.estado === "conflito")
            if (c && (!conflito.aberto || conflito.op.id !== c.id)) conflito.pedir(c)
        }
    }

    // ---- seleção (chamado pelos itens)
    function focarArea() { if (painelAtivo) painelAtivo.focar() }
    function pressionar(i, mods, jaSel) {
        focarArea()
        if (i < 0) return
        if (mods & Qt.ControlModifier || mods & Qt.ShiftModifier) return      // decide no clique
        if (!jaSel) aba.selecionar(i, "unico")
    }
    function clicar(i, mods) {
        if (i < 0) return
        if (mods & Qt.ShiftModifier) aba.selecionar(i, "intervalo")
        else if (mods & Qt.ControlModifier) aba.selecionar(i, "alternar")
        else aba.selecionar(i, "unico")
        if (visao && visao.sincronizarCursor) visao.sincronizarCursor()
    }
    // duplo clique / Enter: pasta entra; arquivo "visualizável" abre a prévia (duplo clique) ou o app (Enter)
    function visualizavel(it) {
        return ["imagem", "video", "audio", "codigo"].indexOf(it.grupo) >= 0 || /^text\//.test(it.mime) || it.mime === "application/pdf"
    }
    function ativar(i) {
        if (i < 0) return
        const it = aba.item(i)
        if (it.ehPasta || !visualizavel(it)) aba.ativar(i)
        else previa.mostrar(it.caminho)
    }
    function selecao() { return aba ? aba.selecionados : [] }
    function indiceAtual() { return visao && visao.indiceAtual ? visao.indiceAtual() : (aba ? aba.atual : -1) }

    // ---- ações
    // (copiar/recortar só mudam a área: o rodapé mostra "ÁREA: n", sem aviso a mais)
    function copiar() { if (selecao().length) arquivos.copiarArea(selecao()) }
    function recortar() { if (selecao().length) arquivos.recortarArea(selecao()) }
    function colar(destino) { marcarAntes(destino || aba.caminho); if (arquivos.colar(destino || aba.caminho) < 0) avisar("aviso", Ds.en ? "Nothing to paste." : "Nada para colar.") }

    // ---- o resultado de colar/duplicar/soltar/extrair na pasta aberta fica SELECIONADO (como no Dolphin):
    // guarda o que havia antes e, quando a operação termina e a pasta relê, seleciona o que é novo
    property var _antes: null
    property var _abaAntes: null
    function marcarAntes(destino) {
        if (!aba || destino !== aba.caminho) return
        let m = {}
        for (let i = 0; i < aba.modelo.rowCount(); i++) m[aba.item(i).caminho] = true
        _antes = m; _abaAntes = aba
    }
    property bool _esperandoNovos: false
    property var _criados: null
    function selecionarCriados(l) {
        if (!aba) return
        const daqui = l.filter(c => c.substring(0, c.lastIndexOf("/")) === aba.caminho)
        if (!daqui.length) { _antes = null; return }
        _criados = daqui; _antes = null
        if (!_selecionarCriadosJa()) _esperandoNovos = true        // a pasta ainda não releu: na próxima leitura
    }
    function _selecionarCriadosJa() {
        if (!_criados || !aba) return false
        const ix = _criados.map(c => aba.indiceDe(c)).filter(i => i >= 0)
        if (!ix.length) return false
        aba.selecionarIndices(ix, false); aba.atual = ix[0]
        if (visao && visao.mostrar) visao.mostrar(ix[0])
        if (visao && visao.sincronizarCursor) visao.sincronizarCursor()
        _criados = null; _esperandoNovos = false
        return true
    }
    function procurarNovos() { if (_antes) { _esperandoNovos = true; Qt.callLater(selecionarNovos) } }
    function selecionarNovos() {
        if (!_antes || !aba || aba !== _abaAntes) return false
        let novos = []
        for (let i = 0; i < aba.modelo.rowCount(); i++) if (!_antes[aba.item(i).caminho]) novos.push(i)
        if (!novos.length) return false
        aba.selecionarIndices(novos, false)
        aba.atual = novos[0]
        if (visao && visao.mostrar) visao.mostrar(novos[0])
        if (visao && visao.sincronizarCursor) visao.sincronizarCursor()
        _antes = null; _esperandoNovos = false
        return true
    }
    Connections { target: janela.aba; function onCarregou() { if (janela._esperandoNovos) { if (janela._criados) janela._selecionarCriadosJa(); else janela.selecionarNovos() } } }
    function paraLixeira() { if (selecao().length && !aba.ehLixeira) arquivos.lixeira(selecao()) }
    function duplicar() { if (selecao().length && !aba.ehLixeira) { marcarAntes(aba.caminho); arquivos.duplicar(selecao()) } }
    function desfazer() {
        const d = arquivos.desfazerInfo || {}
        if (!d.pode) { avisar("info", Ds.t("desf.nada")); return }
        arquivos.desfazer()
    }
    function criarLinkPara() {
        entrada.pedir({ titulo: Ds.t("novo.linkTitulo"), texto: Ds.t("novo.linkTexto"), dica: "~/…", mono: true, botao: Ds.t("novo.criar"), codigo: "LN -S // " + aba.titulo },
                      (v) => { const c = arquivos.novoLink(v.trim(), aba.caminho, ""); if (c) janela._renomearNovo = c })
    }
    function novoDeModelo(m) { const c = arquivos.novoDeModelo(m.id, aba.caminho, ""); if (c) janela._renomearNovo = c }
    function selecionarPorPadrao() {
        entrada.pedir({ titulo: Ds.t("selp.titulo"), texto: Ds.t("selp.texto"), valor: "*.", dica: "*.jpg *.png · re:^IMG_\\d+", mono: true, marcador: Ds.t("selp.somar"), botao: Ds.t("selp.botao"), codigo: "GLOB // " + aba.titulo },
                      (v, somar) => { const n = aba.selecionarPorPadrao(v, somar); avisar(n < 0 ? "erro" : "info", n < 0 ? Ds.t("selp.invalido") : Ds.t("selp.feito", { n: n })) })
    }
    function escolherApp(lista, mime, padrao) { apps.pedir(lista, mime, padrao) }
    function abrirAtalhos() { atalhosTela.mostrar() }
    function zoom(d) { arquivos.zoom = d === 0 ? 100 : Math.max(50, Math.min(300, arquivos.zoom + d * 10)) }
    function outroLado(mover) {
        if (!dividido || !selecao().length) return
        if (mover) arquivos.moverParaOutroLado(selecao()); else arquivos.copiarParaOutroLado(selecao())
    }
    function apagarDefinitivo() { if (selecao().length) confirmar.pedir(arquivos.prepararApagar(selecao()), false) }
    function esvaziar() { confirmar.pedir(arquivos.prepararEsvaziar(), true) }
    // F2: um item renomeia no lugar; vários abrem a RENOMEAÇÃO EM LOTE (prévia viva)
    function renomear() {
        const s = selecao()
        if (s.length > 1) { lote.pedir(s); return }
        const i = indiceAtual()
        if (i < 0) return
        renomeando = aba.item(i).caminho
    }
    function confirmarRenomear(c, nome) {
        const e = arquivos.renomear(c, nome)
        if (e) avisar("erro", e)
        else { renomeando = ""; focarArea() }
    }
    function fimRenomear() { renomeando = ""; focarArea() }
    property string _renomearNovo: ""
    function novaPasta() {
        const c = arquivos.novaPasta(aba.caminho, "")
        if (c) { _renomearNovo = c }
    }
    function novoArquivo() { const c = arquivos.novoArquivo(aba.caminho, ""); if (c) _renomearNovo = c }
    Connections {
        target: janela.aba
        function onCarregou() {
            if (janela._renomearNovo) {
                const i = janela.aba.indiceDe(janela._renomearNovo)
                if (i >= 0) { janela.aba.selecionar(i, "unico"); if (janela.visao && janela.visao.mostrar) janela.visao.mostrar(i); janela.renomeando = janela._renomearNovo }
                janela._renomearNovo = ""
            }
        }
    }
    function propriedades() {
        const s = selecao()
        if (s.length > 1) propVarias.mostrar(s)
        else props.mostrar(s.length ? s[0] : aba.caminho)
    }
    function abrirFila() { fila.abrir() }
    function abrirPrevia() {
        const i = indiceAtual()
        if (i >= 0) previa.mostrar(aba.item(i).caminho)
    }
    // ←/→ no modal de prévia
    function vizinhoPrevia(d) {
        const i = aba.indiceDe(previa.caminho)
        let k = i + d
        while (k >= 0 && k < aba.modelo.rowCount() && aba.item(k).ehPasta && !aba.item(i).ehPasta) k += d
        if (k < 0 || k >= aba.modelo.rowCount()) return
        aba.selecionar(k, "unico")
        previa.mostrar(aba.item(k).caminho)
    }

    // ---- arrastar e soltar
    // ---- arrastar e soltar
    property int arrastando: 0                  // itens numa arrastada que saiu daqui (0 = nenhuma)
    function urisDoDrop(d) {
        if (d.hasUrls && d.urls.length) return d.urls.map(u => String(u)).join("\r\n") + "\r\n"
        return d.getDataAsString ? d.getDataAsString("text/uri-list") : ""
    }
    function caminhosDe(d) {
        const l = d.hasUrls && d.urls.length ? d.urls.map(u => String(u)) : (urisDoDrop(d) || "").split(/\r?\n/)
        return l.filter(u => u && u.startsWith("file://")).map(u => decodeURIComponent(u.replace(/^file:\/\/[^/]*/, "")))
    }
    // ação pelos modificadores: Shift move, Ctrl copia, Ctrl+Shift link, nada = menu (como no Dolphin).
    // O QML não vê o teclado durante a arrastada: se o back-end der arquivos.modificadores(), usa;
    // senão, pela ação proposta (Ctrl → Copy, Ctrl+Shift → Link; Move = Shift ou nada → menu).
    function acaoDoDrop(d) {
        if (typeof arquivos.modificadores === "function") {
            const m = arquivos.modificadores() || {}
            return m.ctrl && m.shift ? "link" : m.shift ? "mover" : m.ctrl ? "copiar" : "menu"
        }
        return d.proposedAction === Qt.LinkAction ? "link" : d.proposedAction === Qt.CopyAction ? "copiar" : "menu"
    }
    function soltarEm(d, destino, ponto) {
        const uris = urisDoDrop(d)
        if (!uris) return
        const acao = acaoDoDrop(d)
        // aceita como cópia: quem arrastou de fora nunca apaga nada por conta própria
        d.action = acao === "mover" ? Qt.MoveAction : acao === "link" ? Qt.LinkAction : Qt.CopyAction
        d.accept()
        marcarAntes(destino)
        if (acao !== "menu") { arquivos.soltar(uris, destino, acao); return }
        const n = uris.split(/\r?\n/).filter(x => x).length
        menu.abrir([
            { texto: Ds.t("soltar.moverAqui", { n: n }), atalho: "Shift", acao: () => arquivos.soltar(uris, destino, "mover") },
            { texto: Ds.t("soltar.copiarAqui", { n: n }), atalho: "Ctrl", acao: () => arquivos.soltar(uris, destino, "copiar") },
            { texto: Ds.t("soltar.linkAqui"), atalho: "Ctrl+Shift", acao: () => arquivos.soltar(uris, destino, "link") },
            { sep: true },
            { texto: Ds.t("soltar.cancelar"), atalho: "Esc", acao: () => {} }
        ], ponto || Qt.point(janela.width / 2, janela.height / 2))
    }
    function soltarNaLixeira(d) {
        const l = caminhosDe(d)
        d.action = Qt.CopyAction; d.accept()
        if (l.length) arquivos.lixeira(l)
    }

    // ---- menus de contexto (seção 8 + paridade com o Dolphin, spec 20)
    function at(acao) { return (arquivos.atalhos || {})[acao] || "" }
    function itemDesfazer() {
        const d = arquivos.desfazerInfo || {}
        // desfazerInfo.efeito diz antes o que acontece ("2 itens vão para a lixeira")
        return { texto: d.pode ? d.texto + (d.efeito ? " — " + d.efeito : "") : Ds.t("desf.rotulo"), atalho: at("desfazer"), desabilitado: !d.pode, acao: () => desfazer() }
    }
    // "Criar novo": pasta, arquivo de texto, link e os modelos (~/Modelos e os do KDE/LibreOffice)
    function subCriarNovo() {
        let l = [{ texto: Ds.t("menu.novaPasta"), atalho: at("novaPasta"), acao: () => novaPasta() },
                 { texto: Ds.t("menu.novoArquivo"), atalho: at("novoArquivo"), acao: () => novoArquivo() },
                 { texto: Ds.t("novo.link"), acao: () => criarLinkPara() }]
        const ms = arquivos.modelos || []
        if (ms.length) l.push({ sep: true })
        for (const m of ms) l.push({ texto: m.nome + (m.extensao ? "  " + m.extensao : ""), acao: () => novoDeModelo(m) })
        return l
    }
    // ServiceMenus do KDE: os soltos vão em "Ações"; os com "submenu", num submenu com esse nome
    function itensServicos(s) {
        const sv = arquivos.servicosPara ? (arquivos.servicosPara(s) || []) : []
        if (!sv.length) return []
        let soltos = [], grupos = {}, ordem = []
        for (const x of sv) {
            const e = { texto: x.nome, acao: () => arquivos.executarServico(x.id, s) }
            if (x.submenu) { if (!grupos[x.submenu]) { grupos[x.submenu] = []; ordem.push(x.submenu) } grupos[x.submenu].push(e) }
            else soltos.push(e)
        }
        let out = [{ sep: true }]
        if (soltos.length) out.push({ texto: Ds.t("menu.acoes"), sub: soltos })
        for (const g of ordem) out.push({ texto: g, sub: grupos[g] })
        return out
    }
    function menuItem(i, ponto) {
        focarArea()
        if (i < 0 && aba) aba.limparSelecao()          // o menu do vazio é o da pasta, não o da seleção
        if (i >= 0 && !aba.item(i).selecionado) aba.selecionar(i, "unico")
        const s = selecao()
        const it = i >= 0 ? aba.item(i) : null
        const varios = s.length > 1
        let m = []
        if (aba.ehLixeira) {
            if (s.length) m.push({ texto: Ds.t("menu.restaurar"), acao: () => arquivos.restaurar(s) },
                                 { texto: Ds.t("menu.apagar"), atalho: at("apagar"), perigo: true, acao: () => apagarDefinitivo() }, { sep: true })
            m.push(itemDesfazer(), { texto: Ds.t("menu.esvaziar"), perigo: true, acao: () => esvaziar() })
        } else if (it) {
            const compactado = it.grupo === "compactado"
            m.push({ texto: Ds.t("menu.abrir"), atalho: "Enter", acao: () => aba.ativar(i) })
            if (!it.ehPasta) {
                const apps0 = arquivos.appsPara(it.caminho)
                let sub = apps0.map(a => ({ texto: a.nome + (a.padrao ? "  ★" : ""), acao: () => { for (const c of s) arquivos.abrirCom(c, a.id) } }))
                if (sub.length) sub.push({ sep: true })
                sub.push({ texto: Ds.t("apps.outro"), acao: () => escolherApp(s, it.mime, false) },
                         { texto: Ds.t("apps.padraoMenu"), acao: () => escolherApp([it.caminho], it.mime, true) })
                m.push({ texto: Ds.t("menu.abrirCom"), sub: sub })
                m.push({ texto: Ds.t("menu.previa"), atalho: at("previa"), acao: () => previa.mostrar(it.caminho) })
            } else m.push({ texto: Ds.t("menu.novaAba"), atalho: Ds.en ? "Middle" : "Meio", acao: () => arquivos.novaAba(it.caminho) },
                          { texto: Ds.t("menu.novaJanela"), acao: () => arquivos.novaJanela(it.caminho) })
            // terminal: na própria pasta clicada, ou na pasta onde o arquivo está
            if (!varios) m.push({ texto: Ds.t("menu.terminal"), atalho: at("terminal"), acao: () => arquivos.abrirTerminal(it.ehPasta ? it.caminho : aba.caminho) })
            m.push({ sep: true },
                   { texto: Ds.t("menu.recortar"), atalho: at("recortar"), acao: () => recortar() },
                   { texto: Ds.t("menu.copiar"), atalho: at("copiar"), acao: () => copiar() },
                   { texto: Ds.t("menu.colar"), atalho: at("colar"), desabilitado: !arquivos.area || !arquivos.area.quantidade, acao: () => colar(it.ehPasta && !varios ? it.caminho : aba.caminho) },
                   { texto: Ds.t("menu.duplicar"), atalho: at("duplicar"), acao: () => duplicar() },
                   { texto: Ds.t("menu.copiarCaminho"), atalho: at("copiarCaminho"), acao: () => arquivos.copiarCaminhos(s) },
                   { texto: Ds.t("menu.copiarPara"), acao: () => arquivos.copiarPara(s) },
                   { texto: Ds.t("menu.moverPara"), acao: () => arquivos.moverPara(s) })
            if (dividido) m.push({ texto: Ds.t("menu.copiarLado"), atalho: at("copiarOutroLado"), acao: () => outroLado(false) },
                                 { texto: Ds.t("menu.moverLado"), atalho: at("moverOutroLado"), acao: () => outroLado(true) })
            m.push({ sep: true },
                   { texto: varios ? Ds.t("menu.renomearLote", { n: s.length }) : Ds.t("menu.renomear"), atalho: at("renomear"), acao: () => renomear() },
                   { texto: Ds.t("novo.linkAqui"), acao: () => { for (const c of s) arquivos.novoLink(c, aba.caminho, "") } },
                   { texto: Ds.t("menu.lixeira"), atalho: at("lixeira"), perigo: true, acao: () => paraLixeira() },
                   { texto: Ds.t("menu.apagar"), atalho: at("apagar"), perigo: true, acao: () => apagarDefinitivo() })
            const cp = arquivos.compactadores || {}
            let comp = []
            if (cp.zip) comp.push({ texto: "zip", acao: () => arquivos.compactar(s, aba.caminho + "/" + (s.length === 1 ? it.nome : "arquivos") + ".zip", "zip") })
            if (cp["7z"]) comp.push({ texto: "7z", acao: () => arquivos.compactar(s, aba.caminho + "/" + (s.length === 1 ? it.nome : "arquivos") + ".7z", "7z") })
            if (cp.targz) comp.push({ texto: "tar.gz", acao: () => arquivos.compactar(s, aba.caminho + "/" + (s.length === 1 ? it.nome : "arquivos") + ".tar.gz", "targz") })
            if (comp.length || (compactado && cp.extrair)) m.push({ sep: true })
            if (comp.length) m.push({ texto: Ds.t("menu.compactar"), sub: comp })
            if (compactado && cp.extrair) m.push({ texto: Ds.t("menu.extrairAqui"), acao: () => { marcarAntes(aba.caminho); arquivos.extrair(it.caminho, "") } },
                                                 { texto: Ds.t("menu.extrairPara"), acao: () => arquivos.extrairPara(it.caminho) })
            if (s.some(c => !aba.item(aba.indiceDe(c)).ehPasta)) m.push({ texto: Ds.t("menu.email"), acao: () => arquivos.enviarEmail(s) })
            m = m.concat(itensServicos(s))
            m.push({ sep: true }, itemDesfazer())
            if (it.ehPasta && !varios) m.push({ texto: Ds.t("menu.addLocal"), acao: () => arquivos.adicionarLocal(it.caminho) })
            m.push({ texto: Ds.t("menu.propriedades"), atalho: at("propriedades"), acao: () => propriedades() })
        } else {
            m.push({ texto: Ds.t("novo.menu"), sub: subCriarNovo() },
                   { texto: Ds.t("menu.colar"), atalho: at("colar"), desabilitado: !arquivos.area || !arquivos.area.quantidade, acao: () => colar(aba.caminho) },
                   itemDesfazer(),
                   { sep: true },
                   { texto: Ds.t("menu.selTudo"), atalho: at("selecionarTudo"), acao: () => aba.selecionarTudo() },
                   { texto: Ds.t("menu.inverter"), atalho: at("inverterSelecao"), acao: () => aba.inverterSelecao() },
                   { texto: Ds.t("menu.selPadrao"), atalho: at("selecionarPorPadrao"), acao: () => selecionarPorPadrao() },
                   { sep: true },
                   { texto: Ds.t("menu.ocultos") + (aba.mostrarOcultos ? "  ✓" : ""), atalho: at("ocultos"), acao: () => aba.mostrarOcultos = !aba.mostrarOcultos },
                   { texto: Ds.t("menu.agrupar") + (aba.agrupar ? "  ✓" : ""), acao: () => aba.agrupar = !aba.agrupar },
                   { texto: Ds.t("menu.dividir") + (dividido ? "  ✓" : ""), atalho: at("dividir"), acao: () => arquivos.alternarDivisao() },
                   { texto: Ds.t("menu.recarregar"), atalho: at("recarregar"), acao: () => aba.recarregar() },
                   { sep: true },
                   { texto: Ds.t("menu.terminal"), atalho: at("terminal"), acao: () => arquivos.abrirTerminal(aba.caminho) },
                   { texto: Ds.t("menu.novaJanela"), atalho: at("novaJanela"), acao: () => arquivos.novaJanela(aba.caminho) },
                   { texto: Ds.t("menu.propriedades"), atalho: at("propriedades"), acao: () => props.mostrar(aba.caminho) })
        }
        menu.abrir(m, ponto)
    }
    function menuLocal(l, secao, ponto) {
        let m = []
        if (secao === "dispositivos") {
            // desmontar/ejetar: o back-end pede confirmação (confirmacaoNecessaria → modal do disco)
            if (l.montado) m.push({ texto: Ds.t("menu.desmontar"), acao: () => arquivos.desmontar(l.dispositivo) })
            else m.push({ texto: Ds.t("menu.montar"), acao: () => arquivos.montar(l.dispositivo) })
            if (l.removivel) m.push({ texto: Ds.t("disco.ejetar"), acao: () => { const f = arquivos.prepararEjetar(l.dispositivo); if (f && f.ficha) disco.pedir("ejetar", f) } })
        }
        if (l.caminho) m.push({ texto: Ds.t("menu.novaAba"), acao: () => arquivos.novaAba(l.caminho) },
                              { texto: Ds.t("menu.novaJanela"), acao: () => arquivos.novaJanela(l.caminho) },
                              { texto: Ds.t("menu.terminal"), acao: () => arquivos.abrirTerminal(l.caminho) })
        if (l.tipo === "favorito") m.push({ sep: true }, { texto: Ds.t("menu.remLocal"), acao: () => arquivos.removerLocal(l.caminho) })
        if (m.length) menu.abrir(m, ponto)
    }
    function menuLixeira(ponto) { menu.abrir([{ texto: Ds.t("menu.esvaziar"), perigo: true, acao: () => esvaziar() }], ponto) }
    // botão direito em voltar (d < 0) / avançar (d > 0): o histórico daquele lado, do mais perto ao mais longe
    function menuHistorico(d, ponto) {
        const h = (aba ? aba.historico : []).filter(x => d < 0 ? x.k < 0 : x.k > 0).sort((a, b) => Math.abs(a.k) - Math.abs(b.k)).slice(0, 15)
        if (!h.length) return
        menu.abrir(h.map(x => ({ texto: x.titulo, atalho: (x.k > 0 ? "+" : "−") + Math.abs(x.k), acao: () => aba.irHistorico(x.k) })), ponto)
    }

    // ---- teclado (seção 11)
    property string _digitado: ""
    Timer { id: limpaDigitado; interval: 900; onTriggered: janela._digitado = "" }
    // ações com tecla configurável (arquivos.atalhos), testadas antes das teclas fixas de navegação
    readonly property var _acoesArea: ({
        desfazer: () => desfazer(), duplicar: () => duplicar(), copiar: () => copiar(), recortar: () => recortar(),
        colar: () => colar(""), selecionarTudo: () => aba.selecionarTudo(), inverterSelecao: () => aba.inverterSelecao(),
        selecionarPorPadrao: () => selecionarPorPadrao(), renomear: () => renomear(), lixeira: () => paraLixeira(),
        apagar: () => apagarDefinitivo(), propriedades: () => propriedades(), previa: () => abrirPrevia(),
        copiarCaminho: () => { if (selecao().length) arquivos.copiarCaminhos(selecao()) },
        copiarOutroLado: () => outroLado(false), moverOutroLado: () => outroLado(true),
        voltar: () => aba.voltar(), avancar: () => aba.avancar(), subir: () => aba.subir(), home: () => aba.irPara("~"),
        novoArquivo: () => novoArquivo()
    })
    function tecla(e) {
        const shift = e.modifiers & Qt.ShiftModifier, alt = e.modifiers & Qt.AltModifier, ctrl = e.modifiers & Qt.ControlModifier
        const lequeAberto = visao && visao.leque
        for (const acao in _acoesArea) if (Ds.casa(e, acao)) { _acoesArea[acao](); return true }
        switch (e.key) {
        case Qt.Key_Left: visao.moverFoco(-1, 0, shift); return true
        case Qt.Key_Right: visao.moverFoco(1, 0, shift); return true
        case Qt.Key_Up: visao.moverFoco(0, -1, shift); return true
        case Qt.Key_Down: visao.moverFoco(0, 1, shift); return true
        case Qt.Key_PageDown: if (visao.paginar) visao.paginar(1); return true
        case Qt.Key_PageUp: if (visao.paginar) visao.paginar(-1); return true
        case Qt.Key_Home: aba.selecionar(0, "unico"); if (visao.mostrar) visao.mostrar(0); return true
        case Qt.Key_End: { const n = aba.modelo.rowCount() - 1; aba.selecionar(n, "unico"); if (visao.mostrar) visao.mostrar(n); return true }
        case Qt.Key_Return: case Qt.Key_Enter:
            if (visao.ativarAtual && !lequeAberto) visao.ativarAtual()
            else { const i = indiceAtual(); if (i >= 0) aba.ativar(i) }
            return true
        case Qt.Key_Backspace: if (lequeAberto) visao.fecharLeque(); else aba.subir(); return true
        case Qt.Key_Tab: case Qt.Key_Backtab:
            if (visao.ciclarSub && visao.ciclarSub(e.key === Qt.Key_Backtab || shift ? -1 : 1)) return true
            return false
        case Qt.Key_Escape:
            if (barra.filtrosAbertos) barra.fecharFiltros()
            else if (logGaveta && logVisivel) logVisivel = false
            else if (lequeAberto) visao.fecharLeque()
            else if (visao.sairSub && visao.sairSub()) {}
            else if (aba.modoBusca) aba.sairBusca()
            else if (aba.filtro) aba.filtro = ""
            else aba.limparSelecao()
            return true
        case Qt.Key_Menu: menuItem(indiceAtual(), Qt.point(meio.x + areaVisao.x + painelAtivo.x + painelAtivo.width / 3, meio.y + 120)); return true
        }
        if (ctrl || alt) return false
        // digitar letras: pula para o primeiro item que começa assim
        if (e.text && e.text.length === 1 && e.text.trim() !== "" && e.text.charCodeAt(0) >= 32) {
            _digitado += e.text
            limpaDigitado.restart()
            const i = aba.pularPara(_digitado)
            if (i >= 0) { aba.selecionar(i, "unico"); if (visao.mostrar) visao.mostrar(i); if (visao.sincronizarCursor) visao.sincronizarCursor() }
            return true
        }
        return false
    }
    // atalhos da janela, lidos de arquivos.atalhos (configuráveis em F1); desligados com modal aberto
    component Atalho: Shortcut {
        property string acao: ""
        property var extra: []
        sequences: [((arquivos.atalhos || {})[acao] || "")].concat(extra).filter(x => x)
        enabled: !janela.modalAberto
        context: Qt.WindowShortcut
    }
    Atalho { acao: "busca"; onActivated: barra.focarBusca() }
    Atalho { acao: "filtro"; onActivated: barra.focarFiltro() }
    Atalho { acao: "caminho"; onActivated: barra.editarCaminho() }
    Atalho { acao: "novaAba"; onActivated: arquivos.novaAba("") }
    Atalho { acao: "fecharAba"; onActivated: arquivos.fecharAba(arquivos.abaAtual) }
    Atalho { acao: "proximaAba"; onActivated: arquivos.abaAtual = (arquivos.abaAtual + 1) % arquivos.abas.length }
    Atalho { acao: "abaAnterior"; onActivated: arquivos.abaAtual = (arquivos.abaAtual - 1 + arquivos.abas.length) % arquivos.abas.length }
    Atalho { acao: "novaJanela"; onActivated: arquivos.novaJanela(aba.caminho) }
    Atalho { acao: "dividir"; onActivated: arquivos.alternarDivisao() }
    Atalho { acao: "terminal"; onActivated: arquivos.abrirTerminal(aba.caminho) }
    Atalho { acao: "recarregar"; onActivated: aba.recarregar() }
    Atalho { acao: "locais"; onActivated: janela.locaisVisiveis = !janela.locaisVisiveis }
    Atalho { acao: "painelLog"; onActivated: janela.logVisivel = !janela.logVisivel }
    Atalho { acao: "ocultos"; onActivated: aba.mostrarOcultos = !aba.mostrarOcultos }
    Atalho { acao: "visaoPilhas"; onActivated: aba.visao = "pilhas" }
    Atalho { acao: "visaoLista"; onActivated: aba.visao = "lista" }
    Atalho { acao: "visaoGrade"; onActivated: aba.visao = "grade" }
    Atalho { acao: "agruparTipos"; extra: (arquivos.atalhos || {}).agruparTipos ? [] : ["Ctrl+G"]; onActivated: janela.alternarAgruparTipos() }
    Atalho { acao: "novaPasta"; onActivated: janela.novaPasta() }
    Atalho { acao: "zoomMais"; extra: ["Ctrl+=", "Ctrl+Shift+="]; onActivated: janela.zoom(1) }
    Atalho { acao: "zoomMenos"; onActivated: janela.zoom(-1) }
    Atalho { acao: "zoomPadrao"; onActivated: janela.zoom(0) }
    Shortcut { sequence: "F1"; enabled: !janela.modalAberto; onActivated: janela.abrirAtalhos() }
    // F6 (como no Dolphin): Locais → busca → itens → Locais…
    Shortcut {
        sequence: "F6"; enabled: !janela.modalAberto
        onActivated: {
            if (locais.focado) barra.focarBusca()
            else if (barra.buscaFocada) janela.focarArea()
            else if (janela.locaisVisiveis) locais.focar()
            else barra.focarBusca()
        }
    }
    // modal de prévia: ←/→ vizinho, 1 = 1:1
    Shortcut { sequence: "Left"; enabled: previa.aberto; onActivated: janela.vizinhoPrevia(-1) }
    Shortcut { sequence: "Right"; enabled: previa.aberto; onActivated: janela.vizinhoPrevia(1) }
    Shortcut { sequence: "1"; enabled: previa.aberto; onActivated: previa.zoom = 1 }
    Shortcut { sequence: "Space"; enabled: previa.aberto; onActivated: previa.espaco() }

    // ================================================================ layout
    Item {
        id: conteudo
        anchors.fill: parent

        // fundo: grade fina e brilho de canto, no tom da corporação
        Rectangle { anchors.fill: parent; color: Tema.base }
        Repeater {
            model: Math.ceil(conteudo.width / 64)
            Rectangle { required property int index; x: index * 64; width: 1; height: conteudo.height; color: Tema.alfa(Tema.linha, 0.18) }
        }

        DsCabecalho { id: cabecalho; width: parent.width }
        BarraAbas { id: abas; y: cabecalho.height + 4; width: parent.width }
        BarraComando { id: barra; y: abas.y + abas.height + 2; width: parent.width; z: 20 }
        // painel de filtros aberto: clique fora fecha (como um menu)
        MouseArea {
            anchors.fill: parent
            z: 19
            visible: barra.filtrosAbertos
            onPressed: barra.fecharFiltros()
        }

        Item {
            id: meio
            y: barra.y + barra.height + 4
            width: parent.width
            height: rodape.y - y - 4

            Locais {
                id: locais
                width: janela.locaisVisiveis ? 210 : 0
                height: parent.height
                visible: width > 0
                clip: true
                Behavior on width { NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
            }

            // ---- área de itens: um painel, ou dois lado a lado na TELA DIVIDIDA (F3)
            Item {
                id: areaVisao
                x: locais.width + 8
                width: parent.width - x - (janela.logVisivel && !janela.logGaveta ? log.width + 16 : 8)
                height: parent.height
                PainelVisao {
                    id: painelE
                    lado: "esquerdo"
                    width: janela.dividido ? (parent.width - 8) / 2 : parent.width
                    height: parent.height
                    aba: arquivos.painelEsquerdo || arquivos.aba
                    dividido: janela.dividido
                    ativo: !janela.dividido || arquivos.ladoAtivo !== "direito"
                }
                PainelVisao {
                    id: painelD
                    lado: "direito"
                    visible: janela.dividido
                    x: painelE.width + 8
                    width: (parent.width - 8) / 2
                    height: parent.height
                    aba: janela.dividido ? arquivos.painelDireito : null
                    dividido: janela.dividido
                    ativo: janela.dividido && arquivos.ladoAtivo === "direito"
                }
            }
            // o foco do teclado acompanha o lado ativo
            Connections { target: arquivos; function onAbasMudou() { Qt.callLater(janela.focarArea) } }

            // gaveta do LOG aberta (janela estreita): clique fora fecha
            MouseArea {
                anchors.fill: parent
                z: 4
                visible: janela.logGaveta && janela.logVisivel
                onPressed: janela.logVisivel = false
            }
            // ---- LOG
            Item {
                id: log
                width: 310
                height: parent.height
                x: parent.width - width - 8
                visible: janela.logVisivel
                z: janela.logGaveta ? 5 : 0
                Chanfro { anchors.fill: parent; corte: Tema.chanfroG; preenchimento: janela.logGaveta ? Tema.elevado : Tema.alfa(Tema.painel, 0.35); borda: Tema.alfa(Tema.destaque, 0.3) }
                PainelLog {
                    id: painelLog
                    x: 14; y: 10; width: parent.width - 28; height: parent.height - 20
                    dados: janela.dadosLog
                    extra: janela.extraLog
                    carregando: !!janela.aba && janela.aba.carregando
                }
            }
        }

        DsRodape {
            id: rodape
            width: parent.width
            anchors.bottom: parent.bottom
            onAbrirFila: janela.abrirFila()
        }
        Varredura { id: varredura; anchors.fill: parent }

        // ---- avisos: embaixo à direita, acima do rodapé; cada um com o seu tempo (4 s, saem em paralelo);
        // um por operação (a mesma chave substitui), com DESFAZER no sucesso quando há o que desfazer
        Column {
            id: avisos
            z: 60
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.bottom: rodape.top; anchors.bottomMargin: 10
            spacing: 6
            property var lista: []
            function mostrar(n, t, chave, desfazer) {
                let l = lista.filter(a => !chave || a.chave !== chave).slice(-3)
                l.push({ n: n, t: t, chave: chave || "", desfazer: !!desfazer, id: Date.now() + Math.random() })
                lista = l
            }
            function tirar(id) { lista = lista.filter(a => a.id !== id) }
            Repeater {
                model: avisos.lista
                Item {
                    id: av
                    required property var modelData
                    width: Math.min(460, tx.implicitWidth + 36 + (bDesf.visible ? bDesf.width + 10 : 0)); height: 32
                    readonly property color cor: modelData.n === "erro" ? Tema.alerta : modelData.n === "aviso" ? Tema.alerta : modelData.n === "ok" ? Tema.sucesso : Tema.secundaria
                    Timer { interval: av.modelData.desfazer ? 7000 : 4000; running: !hvA.hovered; onTriggered: avisos.tirar(av.modelData.id) }
                    HoverHandler { id: hvA }       // com o mouse em cima, o aviso espera
                    Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.elevado; borda: av.cor }
                    Rectangle { x: 0; y: 7; width: 3; height: 18; color: av.cor }
                    Text { id: tx; x: 14; width: Math.min(implicitWidth, 400); anchors.verticalCenter: parent.verticalCenter; text: av.modelData.t; elide: Text.ElideRight; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
                    Botao {
                        id: bDesf
                        // o back-end registra o desfazer logo depois de avisar o fim: o botão segue desfazerInfo
                        visible: av.modelData.desfazer && !!(arquivos.desfazerInfo || {}).pode
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        text: Ds.t("aviso.desfazer"); tipo: "sutil"; tamanho: 10
                        onClicado: { const id = av.modelData.id; Ds.janela.desfazer(); avisos.tirar(id) }   // (tirar destrói este delegado: por último)
                    }
                }
            }
        }

        // campo de renomear da visão PILHAS (as outras renomeiam no lugar)
        Item {
            visible: janela.renomeando !== "" && !!janela.aba && janela.aba.visao === "pilhas"
            x: meio.x + areaVisao.x + (areaVisao.width - width) / 2
            y: meio.y + 40
            width: 420; height: 60
            z: 40
            Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.elevado; borda: Tema.secundaria }
            Codigo { x: 12; y: 6; text: "RENAME // " + Ds.t("ren.dica"); tamanho: 9; color: Tema.secundaria }
            CampoRenomear {
                x: 12; y: 24; width: parent.width - 24; height: 26
                ativo: parent.visible
                caminho: janela.renomeando
                nome: janela.renomeando.substring(janela.renomeando.lastIndexOf("/") + 1)
            }
        }

        MenuContexto { id: menu }
        ModalPrevia { id: previa; onVizinho: (d) => janela.vizinhoPrevia(d); onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalPropriedades { id: props; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalConfirmar { id: confirmar; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalConflito { id: conflito }
        ModalFila { id: fila; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalDisco { id: disco; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalEntrada { id: entrada; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalRenomearLote { id: lote; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalPropVarias { id: propVarias; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalApps { id: apps; onAbertoChanged: if (!aberto) janela.focarArea() }
        ModalAtalhos { id: atalhosTela; onAbertoChanged: if (!aberto) janela.focarArea() }
    }

    // ---- LOG: o que mostrar
    property var dadosLog: null
    property string extraLog: ""
    property string _pastaPedida: ""
    function atualizarLog() {
        extraLog = ""
        if (!aba) { dadosLog = null; return }
        const s = aba.selecionados
        if (s.length > 1) {
            const d = arquivos.detalhesSelecao(s)
            dadosLog = { linhas: [{ rotulo: Ds.t("log.selecao"), valor: d.quantidade + " · " + d.tamanhoTexto }].concat(d.linhas || []), codigo: aba.codigo,
                         meta: aba.ehLixeira ? null : { caminhos: s, tags: [], avaliacao: 0, comentario: "" } }
        } else if (s.length === 1) {
            let d = arquivos.detalhes(s[0])
            const k = aba.indiceDe(s[0]), it = k >= 0 ? aba.item(k) : {}
            if (!aba.ehLixeira) d.meta = { caminhos: [s[0]], tags: it.tags || [], avaliacao: it.avaliacao || 0, comentario: it.comentario || "" }
            dadosLog = d
            if (d.ehPasta) { _pastaPedida = s[0]; arquivos.propriedades(s[0]) }
        } else if (visao && visao.grupoAtual) {
            const g = visao.grupoAtual
            dadosLog = { codigo: g.codigo.replace(/_.*/, "") + "00", linhas: [{ rotulo: "GROUP", valor: g.rotulo }, { rotulo: Ds.en ? "ITEMS" : "ITENS", valor: String(g.quantidade) }, { rotulo: Ds.en ? "SIZE" : "TAMANHO", valor: g.tamanhoTexto }] }
        } else if (!aba.ehLixeira && !aba.ehRecentes && !aba.modoBusca) {
            // nada selecionado: o resumo da pasta aberta (a coluna LOG da referência nunca fica parada)
            let d = arquivos.detalhes(aba.caminho)
            d.linhas = [{ rotulo: Ds.t("log.pastaAtual"), valor: aba.contagem || "" }].concat(d.linhas || [])
            dadosLog = d
        } else dadosLog = null
    }
    Timer { id: atrasoLog; interval: 40; onTriggered: janela.atualizarLog() }
    Connections { target: janela.aba; function onSelecaoMudou() { atrasoLog.restart() } function onCarregou() { atrasoLog.restart() } }
    Connections { target: janela.visao; ignoreUnknownSignals: true; function onGrupoAtualChanged() { atrasoLog.restart() } }
    Connections {
        target: arquivos
        function onPropriedadesProntas(c, mapa) { if (c === janela._pastaPedida) janela.extraLog = (Ds.en ? "TOTAL " : "TOTAL ") + (mapa.tamanhoRecursivoTexto || mapa.tamanhoTexto || "") }
        function onAbasMudou() { atrasoLog.restart() }
    }

}
