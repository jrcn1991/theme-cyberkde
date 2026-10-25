import QtQuick

// Galeria de animações de abrir e fechar janelas (catálogo da Rachael, via "cyberkde efeito janelas
// --lista --json"): escolha separada para abrir e fechar, durações, intensidade e o botão TESTAR (uma
// janela de verdade, para ver o efeito real do KWin). Usada no grupo "Janelas" da SYS.CONFIG.
Column {
    id: s
    spacing: 20
    property bool ativa: false
    property bool entrando: false
    property var app
    readonly property Item corpo: s
    readonly property var fx: painel.fxJanelas
    readonly property var variantes: fx && fx.variantes ? fx.variantes : []
    readonly property bool suporte: fx.suporte === true

    // ---- escolha local (o que a usuária está montando), sincronizada com o CLI quando não há mudança
    property string modo: "abrir"            // filtro da galeria
    property string selAbrir: ""
    property string selFechar: ""
    property bool mesma: false               // fechar = a mesma do abrir
    property int durAbrir: 0                 // 0 = a duração da própria variante
    property int durFechar: 0
    property int intensidade: 60
    // primeira abertura de cada app: "padrao" = sem escolha (o efeito usa o de abrir)
    property string selPrimeira: "padrao"
    property int durPrimeira: 0
    readonly property bool temPrimeira: fx.suportePrimeiraVez === true
    readonly property var lados: temPrimeira ? ["abrir", "fechar", "primeira"] : ["abrir", "fechar"]
    property bool _sujo: false

    function _sincronizar() {
        if (_sujo || !fx) return
        const vs = fx.variantes || []
        // padrões do efeito (effects/cyberkde_scan/PEDIDO.md): abrir "scan", fechar = o de abrir,
        // intensidade 60, durações do catálogo
        selAbrir = fx.abrir || (vs.some(v => v.id === "scan") ? "scan" : (vs.length ? vs[0].id : ""))
        selFechar = fx.fechar || selAbrir
        durAbrir = fx.duracaoAbrir || 0
        durFechar = fx.duracaoFechar || 0
        intensidade = fx.intensidade !== undefined ? fx.intensidade : 60
        mesma = selFechar === selAbrir
        selPrimeira = fx.primeiraVez || "padrao"
        durPrimeira = fx.duracaoPrimeiraVez || 0
    }
    onFxChanged: _sincronizar()
    Component.onCompleted: _sincronizar()

    function variante(id) { return variantes.find(v => v.id === id) || null }
    readonly property var vAbrir: selAbrir === "nenhuma" ? null : variante(selAbrir)
    readonly property var vFechar: selFechar === "nenhuma" ? null : variante(selFechar)
    // "padrao" na primeira abertura mostra a mesma animação do abrir
    readonly property var vPrimeira: selPrimeira === "nenhuma" ? null : (selPrimeira === "padrao" ? vAbrir : variante(selPrimeira))

    function escolher(id) {
        _sujo = true
        if (modo === "abrir") {
            selAbrir = id
            if (mesma) { const v = variante(id); if (id === "nenhuma" || (v && v.fechar)) selFechar = id }
        } else if (modo === "primeira") {
            selPrimeira = id
        } else {
            selFechar = id
            mesma = id === selAbrir
        }
    }
    function aplicar() {
        painel.aplicarJanelas(selAbrir, selFechar, durAbrir, durFechar, intensidade,
                              temPrimeira ? selPrimeira : "", durPrimeira)
        _sujo = false
    }
    function descartar() { _sujo = false; _sincronizar() }

    readonly property var galeria: {
        let l = variantes.filter(v => modo === "fechar" ? v.fechar : v.abrir)
        if (modo === "primeira")
            l = [{ id: "padrao", nome: Txt.t("fx.primeiraPadrao"), descricao: Txt.t("fx.primeiraPadraoDesc"),
                   estilo: vAbrir ? vAbrir.estilo : "nenhuma", abrir: true, fechar: false,
                   duracaoAbrir: vAbrir ? vAbrir.duracaoAbrir : 0, previaAbrir: vAbrir ? vAbrir.previaAbrir : "" }].concat(l)
        // "nenhuma": sempre no fechar e na primeira abertura; no abrir, quando o CLI aceitar
        if (modo !== "abrir" || fx.abrirNenhuma === true) l = l.concat([{ id: "nenhuma", nome: Txt.t("fx.nenhuma"), descricao: Txt.t("fx.nenhumaDesc"),
                            estilo: "nenhuma", abrir: true, fechar: true, duracaoAbrir: 0, duracaoFechar: 0, previaAbrir: "", previaFechar: "" }])
        return l
    }
    readonly property real larguraSlot: Math.min(230, (s.width - 40 - (lados.length - 1) * 18) / lados.length)
    readonly property int colunas: corpo.width > 1150 ? 5 : (corpo.width > 700 ? 4 : 3)

    // ---- janela de teste
    property bool testando: false
    Loader {
        active: s.testando
        sourceComponent: JanelaTeste {
            x: s.app ? s.app.x + s.app.width / 2 - width / 2 : 200
            y: s.app ? s.app.y + s.app.height / 2 - height / 2 : 200
        }
    }
    Timer { id: cicloFecha; interval: 1600; onTriggered: s.testando = false }
    function testar() {
        // um clique = abre, mostra 1,6 s e fecha; clicar de novo durante o ciclo recomeça
        if (testando) { testando = false; cicloAbre.restart(); return }
        testando = true; cicloFecha.restart()
    }
    Timer { id: cicloAbre; interval: 450; onTriggered: { s.testando = true; cicloFecha.restart() } }
    onAtivaChanged: if (!ativa) { testando = false; cicloFecha.stop(); cicloAbre.stop() }

    // ================================================================ painel de escolha
    Bloco {
        id: escolha
        width: parent.width
        titulo: Txt.t("fx.janelas.titulo")
        codigo: "FX-00 // window.open/close"
        destaque: true
        Cascata { ativo: s.entrando; ordem: 0; alvo: escolha }

        // aviso: catálogo de exemplo / CLI sem suporte
        Item {
            visible: !s.suporte
            width: parent.width; height: semTx.implicitHeight + 16
            Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.alerta, 0.07); borda: Tema.alfa(Tema.alerta, 0.6) }
            Rectangle { width: Tema.marcador; height: parent.height - 10; y: 5; color: Tema.alerta }
            Leitura {
                id: semTx
                x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                tamanho: 12; color: Tema.texto
                text: Txt.t(s.fx.fonte === "arquivo" ? "fx.janelas.soCatalogo" : "fx.janelas.exemplo")
            }
        }

        // o efeito do KWin instalado ainda não entende as variantes (fase Janelas antiga)
        Item {
            visible: s.suporte && s.fx.disponivel === false
            width: parent.width; height: Math.max(dispTx.implicitHeight, 34) + 16
            Chanfro { anchors.fill: parent; preenchimento: Tema.alfa(Tema.alerta, 0.07); borda: Tema.alfa(Tema.alerta, 0.6) }
            Rectangle { width: Tema.marcador; height: parent.height - 10; y: 5; color: Tema.alerta }
            Leitura {
                id: dispTx
                x: 14; width: parent.width - 28 - religarJanelas.width - 14; anchors.verticalCenter: parent.verticalCenter
                tamanho: 12; color: Tema.texto
                text: Txt.t("fx.janelas.indisponivel")
            }
            Botao {
                id: religarJanelas
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: Txt.t("fx.janelas.religar"); icone: "⏻"; tamanho: 12; cor: Tema.alerta
                habilitado: !painel.ocupado
                onClicado: painel.alternarFase("janelas", true)
            }
        }

        Row {
            width: parent.width
            spacing: 18

            // "slots": ABRIR, FECHAR e 1ª ABERTURA, com a prévia da escolha
            Repeater {
                model: s.lados
                Item {
                    id: slot
                    required property string modelData
                    readonly property bool ehAbrir: modelData !== "fechar"
                    readonly property var v: modelData === "abrir" ? s.vAbrir : modelData === "fechar" ? s.vFechar : s.vPrimeira
                    readonly property bool ativoFiltro: s.modo === modelData
                    width: s.larguraSlot; height: 96 + s.larguraSlot * 0.44
                    Chanfro {
                        anchors.fill: parent
                        preenchimento: slot.ativoFiltro ? Tema.selecao : Tema.entrada
                        borda: slot.ativoFiltro ? Tema.destaque : Tema.linha
                    }
                    Column {
                        x: 10; y: 8; width: parent.width - 20
                        spacing: 6
                        Row {
                            spacing: 6
                            Codigo { text: Txt.t("fx.selo." + slot.modelData); tamanho: 9; font.bold: true; color: Tema.destaque }
                            Codigo {
                                visible: (slot.modelData === "fechar" && s.mesma) || (slot.modelData === "primeira" && s.selPrimeira === "padrao")
                                text: "= " + Txt.t("fx.selo.abrir"); tamanho: 9
                            }
                        }
                        PreviaJanela {
                            width: parent.width; height: width * 0.5
                            estilo: slot.v ? slot.v.estilo : "nenhuma"
                            modo: slot.ehAbrir ? "abrir" : "fechar"
                            fonte: slot.v ? (slot.ehAbrir ? slot.v.previaAbrir : slot.v.previaFechar) : ""
                            duracao: slot.modelData === "fechar" ? (s.durFechar || (slot.v ? slot.v.duracaoFechar : 200))
                                : slot.modelData === "primeira" ? (s.durPrimeira || (slot.v ? slot.v.duracaoAbrir : 280))
                                : (s.durAbrir || (slot.v ? slot.v.duracaoAbrir : 280))
                            tocar: hoverSlot.hovered
                        }
                        Rotulo {
                            text: slot.v ? slot.v.nome : Txt.t("fx.nenhuma")
                            tamanho: 15; width: parent.width; elide: Text.ElideRight
                        }
                        Codigo { text: Txt.t("fx.trocar"); tamanho: 8; color: slot.ativoFiltro ? Tema.secundaria : Tema.texto3 }
                    }
                    HoverHandler { id: hoverSlot }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.modo = slot.modelData }
                }
            }

        }

        // ajustes
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 24
            rowSpacing: 12
            readonly property real col: (width - columnSpacing) / 2
            Row {
                width: parent.col
                spacing: 10
                Interruptor {
                    ligado: s.mesma
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: (novo) => {
                        s._sujo = true; s.mesma = novo
                        if (novo) { const v = s.variante(s.selAbrir); if (s.selAbrir === "nenhuma" || (v && v.fechar)) s.selFechar = s.selAbrir }
                    }
                }
                Leitura { text: Txt.t("fx.mesma"); tamanho: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Deslizador {
                width: parent.col
                rotulo: Txt.t("fx.intensidade")
                de: 0; ate: 100; passo: 5
                valor: s.intensidade
                padrao: 60
                unidade: "%"
                onMovido: (v) => { s._sujo = true; s.intensidade = v }
            }
            Deslizador {
                width: parent.col
                rotulo: Txt.t("fx.durAbrir")
                de: 0; ate: 1500; passo: 20
                valor: s.durAbrir
                habilitado: s.selAbrir !== "nenhuma"
                textoValor: s.durAbrir === 0 ? Txt.t("fx.padraoVariante", { ms: s.vAbrir ? s.vAbrir.duracaoAbrir : "—" }) : s.durAbrir + " ms"
                onMovido: (v) => { s._sujo = true; s.durAbrir = v }
            }
            Deslizador {
                width: parent.col
                rotulo: Txt.t("fx.durFechar")
                de: 0; ate: 1500; passo: 20
                valor: s.durFechar
                habilitado: s.selFechar !== "nenhuma"
                textoValor: s.durFechar === 0 ? Txt.t("fx.padraoVariante", { ms: s.vFechar ? s.vFechar.duracaoFechar : "—" }) : s.durFechar + " ms"
                onMovido: (v) => { s._sujo = true; s.durFechar = v }
            }
            Deslizador {
                visible: s.temPrimeira
                width: parent.col
                rotulo: Txt.t("fx.durPrimeira")
                de: 0; ate: 2000; passo: 20
                valor: s.durPrimeira
                habilitado: s.selPrimeira !== "nenhuma"
                textoValor: s.durPrimeira === 0 ? Txt.t("fx.padraoVariante", { ms: s.vPrimeira ? s.vPrimeira.duracaoAbrir : "—" }) : s.durPrimeira + " ms"
                onMovido: (v) => { s._sujo = true; s.durPrimeira = v }
            }
            Leitura {
                visible: s.temPrimeira && s.fx.primeiraVezDisponivel === false
                width: parent.col
                tamanho: 11
                color: Tema.alerta
                text: Txt.t("fx.primeiraIndisponivel")
            }
        }

        // ações
        Row {
            spacing: 10
            Botao {
                text: Txt.t("comum.aplicar"); icone: "▶"; tipo: "primario"
                habilitado: s._sujo && s.suporte && !painel.ocupado
                onClicado: s.aplicar()
            }
            Botao {
                text: Txt.t("fx.descartar"); tipo: "sutil"
                habilitado: s._sujo
                onClicado: s.descartar()
            }
            Botao {
                text: s.testando ? Txt.t("fx.testando") : Txt.t("fx.testar"); icone: "◧"
                cor: Tema.secundaria
                onClicado: s.testar()
            }
            Leitura {
                anchors.verticalCenter: parent.verticalCenter
                width: escolha.width - 520
                tamanho: 11
                color: s._sujo ? Tema.alerta : Tema.texto3
                text: s._sujo ? Txt.t("fx.testarSujo") : Txt.t("fx.testarDica")
            }
        }
    }

    // ================================================================ galeria
    Row {
        id: abas
        spacing: 8
        Cascata { ativo: s.entrando; ordem: 1; alvo: abas }
        Repeater {
            model: s.lados
            Item {
                id: aba
                required property string modelData
                readonly property bool sel: s.modo === modelData
                width: 170; height: 34
                activeFocusOnTab: true
                Keys.onSpacePressed: s.modo = modelData
                Chanfro {
                    anchors.fill: parent
                    preenchimento: aba.sel ? Tema.destaque : Tema.entrada
                    borda: aba.activeFocus ? Tema.secundaria : (aba.sel ? Tema.destaque : Tema.linha)
                    espessura: aba.activeFocus ? 2 : 1
                }
                Rotulo {
                    anchors.centerIn: parent
                    text: Txt.t("fx.filtro." + aba.modelData) + "  ·  " + s.variantes.filter(v => aba.modelData === "fechar" ? v.fechar : v.abrir).length
                    tamanho: 14
                    color: aba.sel ? Tema.escuro : Tema.texto2
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.modo = aba.modelData }
            }
        }
        Codigo {
            anchors.verticalCenter: parent.verticalCenter
            text: "  " + Txt.t("fx.galeriaDica")
            tamanho: 9
        }
    }

    Grid {
        id: grade
        width: parent.width
        columns: s.colunas
        spacing: 12
        Repeater {
            model: s.galeria
            CartaoVariante {
                id: cv
                required property var modelData
                required property int index
                width: (grade.width - (s.colunas - 1) * 12) / s.colunas
                dados: modelData
                modo: s.modo
                numero: index + 1
                escolhidaAbrir: modelData.id === s.selAbrir
                escolhidaFechar: modelData.id === s.selFechar
                escolhidaPrimeira: modelData.id === s.selPrimeira
                onEscolhida: s.escolher(modelData.id)
                Cascata { ativo: s.entrando; ordem: 2 + cv.index; alvo: cv }
            }
        }
    }
}
