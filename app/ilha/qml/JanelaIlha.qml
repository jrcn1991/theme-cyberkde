import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LS

// Uma janela por tela: 532×470, sempre; o que muda é a máscara de clique. Ver ilha-spec.md, seção 1.
Window {
    id: j
    property var tela: ({})
    // abaixo da barra: a janela cresce e a gota desce; a margem de layer-shell não é alcançável por QML (QMargins)
    readonly property real recuo: (ilha.config.assento || "sobre") === "abaixo" ? (ilha.alturaBarra || 0) : 0
    // satélites e trilho pedem mais largura; o que muda de verdade continua sendo a máscara
    readonly property bool larga: (ilha.config.pilula || "simples") === "satelites" || (ilha.config.layout || "folha") === "trilho"
    width: larga ? 668 : 532; height: 470 + recuo + (fusao ? barra.altura : 0)
    // a barra de cima desta tela, com as cores do tema; sem ela (Latte, solta) nada se funde
    readonly property var barra: { ilha.alturaBarra; ilha.paleta; return ilha.barraEm ? ilha.barraEm(tela.nome) : ({ altura: 0 }) }
    readonly property bool fusao: recuo === 0 && (ilha.config.assento || "sobre") === "sobre" && (barra.altura || 0) > 0
    color: "transparent"
    // ocultaNa é função: as duas leituras antes dela refazem a conta quando o estado muda
    visible: { ilha.oculta; ilha.telasEmTelaCheia; return !ilha.ocultaNa(tela.nome) && !religando }
    // devolver o teclado: o KWin não o passa adiante ao trocar para None; só ao sumir a superfície. Um instante basta.
    property bool religando: false
    function religar() { religando = true; volta.restart() }
    Timer { id: volta; interval: 40; onTriggered: j.religando = false }
    title: "CyberKDE Ilha"
    LS.Window.scope: "cyberkde-ilha"
    LS.Window.layer: LS.Window.LayerOverlay
    readonly property string alinhado: ilha.config.alinhamento || "centro"
    LS.Window.anchors: alinhado === "esquerda" ? (LS.Window.AnchorTop | LS.Window.AnchorLeft)
                     : alinhado === "direita" ? (LS.Window.AnchorTop | LS.Window.AnchorRight) : LS.Window.AnchorTop
    LS.Window.exclusionZone: -1
    // sem teclado em repouso: só um campo em uso o pede, e a Gota o devolve (ver pedirTeclado)
    LS.Window.activateOnShow: false
    LS.Window.keyboardInteractivity: gl.item && gl.item.teclado ? LS.Window.KeyboardInteractivityExclusive : LS.Window.KeyboardInteractivityNone
    LS.Window.screen: j.saidaQt
    // o QScreen de verdade: "Qt.application.screens" entrega um invólucro que a propriedade não aceita
    readonly property var saidaQt: ilha.telaQt(tela.nome)

    function nestaTela(v) {
        const f = v.from || {}, cx = (f.x || 0) + (f.width || 0) / 2
        return (ilha.telas || []).length < 2 || (cx >= tela.x && cx < tela.x + tela.largura)
    }
    // ---- tema: objeto criado aqui; sem o pedido, o halo
    readonly property string temaPedido: ilha.config.tema || "halo"
    property string temaId: "halo"
    property var tema: null
    function carregarTema() {
        let id = temaPedido
        let c = Qt.createComponent("temas/" + id + "/Tema.qml")
        if (c.status !== Component.Ready) { console.warn("ilha: tema indisponível:", id, c.errorString()); id = "halo"; c = Qt.createComponent("temas/halo/Tema.qml") }
        const t = c.createObject(j, { paleta: Qt.binding(() => ilha.paleta), reduzir: Qt.binding(() => ilha.reduzir), estilo: Qt.binding(() => ilha.config.estilo || "preto") })
        // "cor": um papel da paleta no lugar da cor de ação do tema. Só substitui quando pedida: guardar a cor do
        // tema aqui a congelaria na paleta da hora em que a ilha subiu (a troca de corporação não chegava)
        const c0 = ilha.config.cor
        if (c0 && c0 !== "tema") t.acao = Qt.binding(() => ilha.paleta[ilha.config.cor] || ilha.paleta.destaque)
        const velho = tema
        temaId = id
        tema = t
        if (velho) velho.destroy()
    }
    onTemaPedidoChanged: carregarTema()
    // voltar para "do tema" pede o tema de novo, com as ligações dele
    readonly property bool corPropria: !!ilha.config.cor && ilha.config.cor !== "tema"
    onCorPropriaChanged: carregarTema()
    Component.onCompleted: carregarTema()

    Item {
        anchors.fill: parent
        Loader {
            id: gl
            active: !!j.tema
            y: j.recuo
            // a janela vai à borda (âncoras); aqui a gota encosta no lado dela, sem colar na tela
            x: { const w = item ? item.width : 0; return Math.round(j.alinhado === "esquerda" ? 22 : j.alinhado === "direita" ? parent.width - w - 22 : (parent.width - w) / 2) }
            onYChanged: if (item) item.mandarRegiao()
            onXChanged: if (item) item.mandarRegiao()
            sourceComponent: Gota { tema: j.tema; temaId: j.temaId; janela: j; bolhaItem: bolhaCarga.item; barra: j.barra; fusao: j.fusao }
        }
        // o voo do fantasma: janela própria, só enquanto voa, nesta tela
        Loader {
            active: !!gl.item && !!gl.item.vooAtual && j.nestaTela(gl.item.vooAtual)
            sourceComponent: VooCamada { tela: j.tela; ui: gl.item; voo: gl.item.vooAtual }
        }
        Loader {
            id: bolhaCarga
            active: !!gl.item && !j.fusao && !gl.item.satelites   // nesses casos a segunda atividade vai dentro da pílula
            y: j.recuo
            // encostada à direita, a bolha vai para o lado de dentro
            x: !gl.item ? 0 : j.alinhado === "direita" ? gl.x - gl.item.alturaPilula - 8 : gl.x + gl.item.width + 8
            sourceComponent: Bolha { id: bolha; ui: gl.item; a: gl.item && !gl.item.aberta && !gl.item.evento ? gl.item.secundaria : null }
        }
    }
}
