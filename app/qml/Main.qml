import QtQuick
import QtQml
import QtQuick.Window
import QtQuick.Dialogs

Window {
    id: janela
    width: opcoes.largura || 1320
    height: opcoes.altura || 860
    minimumWidth: 1000
    minimumHeight: 660
    visible: true
    color: Tema.base
    title: Txt.t("app.titulo")

    property int secao: opcoes.secao
    // seções por id (a ordem pode mudar sem quebrar quem pede "vá para a corporação")
    function indice(id) { return Math.max(0, secoes.findIndex(x => x.id === id)) }
    function irPara(id) {
        // "modulos" agora é a página "Partes do tema" da SYS.CONFIG
        if (id === "modulos") { secaoConfig.irGrupo("partes"); id = "config" }
        secao = indice(id)
    }
    readonly property string secaoId: secoes[secao] ? secoes[secao].id : ""
    onSecaoChanged: varredura.passar()

    // Fechar no meio de uma operação mataria o cyberkde no meio da aplicação (o QProcess morre com
    // o painel): espera terminar.
    onClosing: (fechamento) => {
        if (painel.ocupado) {
            fechamento.accepted = false
            avisos.mostrar("aviso", Txt.t("notif.esperaFechar"))
        }
    }
    readonly property var secoes: [
        { id: "status", titulo: Txt.t("secao.status"), caminho: "STATUS" },
        { id: "corporacao", titulo: Txt.t("secao.corporacao"), caminho: "CORP" },
        { id: "config", titulo: Txt.t("secao.config"), caminho: "SYS.CONFIG" },
        { id: "papel", titulo: Txt.t("secao.papel"), caminho: "PAPEL" },
        { id: "diagnostico", titulo: Txt.t("secao.diagnostico"), caminho: "DIAG", alerta: painel.diagnostico.codigo > 0 },
        { id: "registro", titulo: Txt.t("secao.registro"), caminho: "LOG" }
    ]

    // ---- paleta: a do sistema, a de prévia (mouse sobre um cartão, seletor de cor) e a travada
    // enquanto uma corporação é aplicada (até o status confirmar a troca)
    property var paletaHover: null
    property var paletaTrava: null
    property string logoTrava: ""
    property string nomeTrava: ""
    property var recorteTrava: null
    property bool _soltarNoStatus: false
    Binding { target: Tema; property: "reduzir"; value: painel.reduzirAnimacoes }
    Binding { target: Txt; property: "textos"; value: painel.textos }
    Binding { target: Tema; property: "efeitos"; value: janela.contentItem.GraphicsInfo.api !== GraphicsInfo.Software }
    Binding { target: Tema; property: "paletaSistema"; value: painel.paleta }
    Binding { target: Tema; property: "paletaPrevia"; value: janela.paletaTrava || janela.paletaHover }

    function previa(paleta) { paletaHover = paleta || null }

    // ---- confirmação de corporação/cor
    property var pedido: null    // { tipo: "corp"|"cor", id, nome, cor, secundaria, paleta, logo }
    function pedirCorp(c) {
        pedido = c
        confirma.abrir()
    }
    function confirmarPedido() { aplicarPedido(pedido) }
    function aplicarPedido(c) {
        confirma.fechar()
        seletor.fechar()
        glitch.disparar(function() {
            janela.paletaTrava = c.paleta
            janela.logoTrava = c.icone || c.logo || ""
            janela.recorteTrava = c.icone ? (c.iconeRecorte || null) : null
            janela.nomeTrava = c.nome || ""
            janela.paletaHover = null
        })
        if (c.tipo === "cor") painel.aplicarCor(c.cor, "personalizada", c.secundaria || "")
        else painel.aplicarCorp(c.id)
        _soltarNoStatus = false
    }
    function cancelarPedido() {
        confirma.fechar()
        paletaHover = null
    }
    // Desfazer: volta à corporação (ou cor) de antes da última troca, com a mesma transição.
    function desfazer() {
        const d = painel.desfazer
        if (!d || !d.tipo || painel.ocupado) return
        glitch.disparar(function() {
            janela.paletaTrava = d.paleta
            janela.logoTrava = d.logo || ""
            janela.recorteTrava = null
            janela.nomeTrava = d.nome || ""
        })
        painel.desfazerTroca()
        _soltarNoStatus = false
    }
    function soltarTrava() {
        janela.paletaTrava = null
        janela.logoTrava = ""
        janela.nomeTrava = ""
    }

    Connections {
        target: painel
        function onOperacaoTerminou(nome, codigo) {
            if (janela.paletaTrava === null) return
            if (codigo === 0 || codigo === 4) {
                janela._soltarNoStatus = true
            } else {
                // falhou: volta para a cor de verdade, com o mesmo glitch
                glitch.disparar(janela.soltarTrava)
            }
        }
        function onStatusMudou() {
            if (janela._soltarNoStatus && !painel.ocupado) {
                janela._soltarNoStatus = false
                janela.soltarTrava()
            }
        }
        function onNotificar(nivel, texto) { avisos.mostrar(nivel, texto) }
        function onSudoPendente(comando, frases) {
            sudo.comando = comando
            sudo.frases = frases
            sudo.abrir()
        }
    }

    function pedirDesligar() { desliga.abrir() }
    function escolherLogo(corp) { dlgLogo.corp = corp; dlgLogo.open() }
    function escolherPapel() { dlgPapel.open() }
    function abrirSeletor(paleta) { seletor.abrir(paleta) }

    // ---------------------------------------------------------------- interface
    Item {
        id: conteudo
        anchors.fill: parent

        Fundo { anchors.fill: parent }

        Navegacao {
            id: nav
            width: janela.width < 1180 ? 216 : 248
            anchors.top: parent.top; anchors.bottom: parent.bottom
            secoes: janela.secoes
            atual: janela.secao
            onEscolher: (i) => janela.secao = i
        }

        Item {
            id: principal
            anchors.left: nav.right; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: parent.bottom

            Cabecalho {
                id: cab
                width: parent.width
                numero: janela.secao + 1
                titulo: janela.secoes[janela.secao].titulo
                caminho: janela.secoes[janela.secao].caminho
                logo.source: janela.logoTrava || painel.logoAtual || painel.logoReserva
                logo.recorte: janela.logoTrava ? janela.recorteTrava : (painel.logoAtual ? painel.recorteAtual : null)
                nomeForcado: janela.nomeTrava
            }

            Item {
                id: area
                anchors.top: cab.bottom; anchors.bottom: rod.top
                width: parent.width
                SecaoStatus { anchors.fill: parent; app: janela; ativa: janela.secaoId === "status" }
                SecaoConfig { id: secaoConfig; anchors.fill: parent; app: janela; ativa: janela.secaoId === "config" }
                SecaoCorporacao { anchors.fill: parent; app: janela; ativa: janela.secaoId === "corporacao" }
                SecaoPapel { anchors.fill: parent; app: janela; ativa: janela.secaoId === "papel" }
                SecaoDiagnostico { anchors.fill: parent; app: janela; ativa: janela.secaoId === "diagnostico" }
                SecaoRegistro { anchors.fill: parent; app: janela; ativa: janela.secaoId === "registro" }
            }

            Rodape { id: rod; width: parent.width; anchors.bottom: parent.bottom }
        }

        Varredura { id: varredura; anchors.fill: parent }
    }

    // atalhos: Ctrl+1..6 trocam de seção, F5 atualiza
    Instantiator {
        model: janela.secoes.length
        delegate: Shortcut {
            required property int index
            sequences: ["Ctrl+" + (index + 1)]
            onActivated: janela.secao = index
        }
    }
    Shortcut { sequences: ["F5"]; onActivated: painel.atualizar() }
    Shortcut { sequences: ["F1"]; onActivated: atalhos.aberto ? atalhos.fechar() : atalhos.abrir() }
    Shortcut { sequences: [StandardKey.Undo]; onActivated: janela.desfazer() }

    GlitchTela { id: glitch; fonte: conteudo }

    // ---------------------------------------------------------------- notificações
    Column {
        id: avisos
        z: 45
        anchors.right: parent.right; anchors.rightMargin: 24
        y: 96
        spacing: 8
        width: 360
        function mostrar(nivel, texto) { modelo.append({ nivel: nivel, texto: texto, nasceu: Date.now() }) }
        ListModel { id: modelo }
        Timer {
            running: modelo.count > 0
            interval: 500; repeat: true
            onTriggered: { while (modelo.count && Date.now() - modelo.get(0).nasceu > 5000) modelo.remove(0) }
        }
        Repeater {
            model: modelo
            Item {
                id: aviso
                required property string nivel
                required property string texto
                required property int index
                width: avisos.width
                height: tx.implicitHeight + 22
                readonly property color cor: nivel === "erro" ? Tema.erro : nivel === "aviso" ? Tema.alerta : nivel === "ok" ? Tema.sucesso : Tema.secundaria
                Cascata { ativo: true; deslocamento: 18 }
                Chanfro { anchors.fill: parent; preenchimento: Tema.elevado; borda: Tema.alfa(aviso.cor, 0.7) }
                Rectangle { width: Tema.marcador; height: parent.height - 12; y: 6; color: aviso.cor }
                Leitura {
                    id: tx
                    x: 16; width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: aviso.texto
                    color: Tema.texto
                }
                MouseArea { anchors.fill: parent; onClicked: modelo.remove(aviso.index) }
            }
        }
    }

    // ---------------------------------------------------------------- modais
    Modal {
        id: confirma
        readonly property var p: janela.pedido || ({})
        titulo: p.tipo === "cor" ? Txt.t("conf.tituloCor") : (p.id === "nenhuma" ? Txt.t("corp.voltarPadrao") : Txt.t("conf.protocolo", { nome: p.nome || "" }))
        codigo: Txt.t("conf.codigo", { id: (p.id || "").toUpperCase() })
        cor: p.cor ? Tema.legivel(p.cor) : Tema.destaque
        largura: 580
        onCancelado: janela.cancelarPedido()
        Row {
            spacing: 18
            width: parent.width
            LogoMontagem {
                id: logoConf
                modo: "medio"
                height: 76; width: Math.min(150, height * Math.max(1, proporcao))
                visible: !!confirma.p.logo
                source: confirma.aberto && confirma.p.logo ? confirma.p.logo : ""
            }
            Column {
                width: parent.width - (logoConf.visible ? logoConf.width + 18 : 0)
                spacing: 8
                Leitura {
                    width: parent.width
                    color: Tema.texto
                    tamanho: 14
                    text: {
                        const p = confirma.p
                        if (p.tipo === "cor") return Txt.t("conf.textoCor", { cor: p.cor })
                        if (p.id === "nenhuma") return Txt.t("conf.textoPadrao")
                        return Txt.t("conf.textoCorp", { nome: p.nome })
                    }
                }
                TabelaPaleta {
                    width: parent.width
                    compacta: true
                    paleta: confirma.p.paleta || ({})
                }
                Leitura {
                    width: parent.width
                    text: painel.temaLigado
                        ? Txt.t("conf.reaplica")
                        : Txt.t("conf.desligado")
                }
                Leitura {
                    visible: confirma.p.tipo !== "cor" && !painel.suporteCorp
                    width: parent.width
                    color: Tema.alerta
                    text: Txt.t("conf.semCorp")
                }
            }
        }
        acoes: [
            Botao { text: Txt.t("comum.cancelar"); tipo: "sutil"; onClicado: janela.cancelarPedido() },
            Botao { text: Txt.t("comum.confirmar"); icone: "▶"; tipo: "primario"; cor: confirma.cor; onClicado: janela.confirmarPedido() }
        ]
    }

    Modal {
        id: desliga
        titulo: Txt.t("off.titulo")
        codigo: Txt.t("off.codigo")
        cor: Tema.alerta
        onCancelado: fechar()
        Leitura {
            width: parent.width
            color: Tema.texto
            tamanho: 14
            text: Txt.t("off.texto")
        }
        acoes: [
            Botao { text: Txt.t("comum.cancelar"); tipo: "sutil"; onClicado: desliga.fechar() },
            Botao { text: Txt.t("comum.desligar"); icone: "⏻"; tipo: "primario"; cor: Tema.alerta; onClicado: { desliga.fechar(); painel.desligarTema() } }
        ]
    }

    Modal {
        id: sudo
        property string comando: ""
        property var frases: []
        titulo: Txt.t("sudo.titulo")
        codigo: Txt.t("sudo.codigo")
        cor: Tema.alerta
        largura: 620
        onCancelado: fechar()
        Leitura {
            width: parent.width
            color: Tema.texto
            tamanho: 14
            text: Txt.t("sudo.texto")
        }
        Item {
            width: parent.width; height: 44
            Chanfro { anchors.fill: parent; preenchimento: Tema.entrada; borda: Tema.alfa(Tema.alerta, 0.5) }
            Text {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 120
                elide: Text.ElideMiddle
                text: "$ " + sudo.comando
                font.family: Tema.fMono; font.pixelSize: 13
                color: Tema.texto
            }
            Botao {
                anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: 30; implicitWidth: 92
                text: Txt.t("comum.copiar"); tamanho: 12; cor: Tema.alerta
                onClicado: { painel.copiar(sudo.comando); avisos.mostrar("ok", Txt.t("notif.comandoCopiado")) }
            }
        }
        Repeater {
            model: sudo.frases
            Leitura { required property string modelData; width: parent.width; text: "· " + modelData }
        }
        acoes: [ Botao { text: Txt.t("comum.entendi"); tipo: "primario"; cor: Tema.alerta; onClicado: sudo.fechar() } ]
    }

    Modal {
        id: seletor
        titulo: Txt.t("seletor.titulo")
        codigo: Txt.t("seletor.codigo")
        cor: sel.cor
        largura: 680
        readonly property var base: painel.especiais.personalizada ? painel.especiais.personalizada.paleta : painel.paleta
        readonly property var paletaEscolhida: ({
            destaque: sel.cor.toString().toUpperCase(),
            secundaria: sel.secundaria.toString().toUpperCase(),
            alerta: base.alerta, fundo: base.fundo
        })
        function abrir(atual) {
            aberto = true
            sel.definir(atual.destaque, atual.secundaria)
            janela.paletaHover = paletaEscolhida
        }
        onCancelado: { fechar(); janela.paletaHover = null }
        onAbertoChanged: if (!aberto && !confirma.aberto) janela.paletaHover = null
        onPaletaEscolhidaChanged: if (aberto) janela.paletaHover = paletaEscolhida
        SeletorCor { id: sel; width: parent.width }
        acoes: [
            Botao { text: Txt.t("comum.cancelar"); tipo: "sutil"; onClicado: { seletor.fechar(); janela.paletaHover = null } },
            Botao {
                text: Txt.t("comum.aplicar"); icone: "▶"; tipo: "primario"; cor: sel.cor
                onClicado: janela.aplicarPedido({
                    tipo: "cor", id: "personalizada", nome: Txt.t("nome.personalizada"),
                    cor: seletor.paletaEscolhida.destaque,
                    secundaria: painel.suporteSecundaria && sel.mexeuSecundaria ? seletor.paletaEscolhida.secundaria : "",
                    paleta: seletor.paletaEscolhida, logo: ""
                })
            }
        ]
    }

    Modal {
        id: atalhos
        titulo: Txt.t("atalhos.titulo")
        codigo: Txt.t("atalhos.codigo")
        largura: 520
        onCancelado: fechar()
        Repeater {
            model: [
                { t: "Ctrl+1 … Ctrl+" + janela.secoes.length, d: Txt.t("atalhos.secao", { n: janela.secoes.length }) },
                { t: "Ctrl+Z", d: Txt.t("atalhos.desfazer") },
                { t: "F5", d: Txt.t("atalhos.atualizar") },
                { t: Txt.t("atalhos.tabTecla"), d: Txt.t("atalhos.tab") },
                { t: "Esc", d: Txt.t("atalhos.esc") },
                { t: "F1", d: Txt.t("atalhos.f1") }
            ]
            Row {
                required property var modelData
                spacing: 14
                width: parent.width
                Item {
                    width: 130; height: 18
                    Atalho { tecla: modelData.t; cor: Tema.secundaria }
                }
                Leitura { width: parent.width - 144; text: modelData.d; color: Tema.texto }
            }
        }
        acoes: [ Botao { text: Txt.t("comum.fechar"); tipo: "primario"; onClicado: atalhos.fechar() } ]
    }

    FileDialog {
        id: dlgLogo
        property string corp: ""
        title: Txt.t("dlg.logo")
        nameFilters: [Txt.t("dlg.filtroLogo")]
        onAccepted: painel.escolherLogo(corp, selectedFile.toString())
    }
    FileDialog {
        id: dlgPapel
        title: Txt.t("secao.papel")
        nameFilters: [Txt.t("dlg.filtroPapel")]
        onAccepted: painel.escolherPapel(selectedFile.toString())
    }

    Abertura {
        id: abertura
        visible: !opcoes.semBoot && !painel.reduzirAnimacoes
        // o logo largo oficial da corporação (como o "CYBERPUNK" da referência); sem ele, o ícone
        readonly property var corpAtualDados: painel.corps.find(x => x.id === painel.corpAtual) || null
        logo: corpAtualDados && corpAtualDados.logo ? corpAtualDados.logo : (painel.logoAtual || painel.logoReserva)
        recorte: corpAtualDados && corpAtualDados.logo ? null : (painel.logoAtual ? painel.recorteAtual : null)
        corp: {
            const c = painel.corps.find(x => x.id === painel.corpAtual)
            return c ? c.nome : (painel.corpAtual === "personalizada" ? Txt.t("nome.personalizada") : Txt.t("nome.nenhuma"))
        }
        cor: painel.corSistema
        pronto: painel.statusOk || esperaBoot.disparou
        Timer { id: esperaBoot; property bool disparou: false; interval: 350; running: true; onTriggered: disparou = true }
    }

    // (testes) --previa: como se o mouse estivesse sobre o cartão da corporação
    Timer {
        running: opcoes.previa !== ""
        interval: 700
        onTriggered: {
            const c = painel.corps.find(x => x.id === opcoes.previa)
            if (c) janela.paletaHover = c.paleta
        }
    }
}
