import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

// Tamanho de um widget na área de trabalho. O tamanho REAL é o do applet (a geometria que o Plasma
// grava): a pessoa redimensiona à mão no modo de edição e o widget respeita. P/M/G são PRESETS: só
// mudam o tamanho quando pedidos (seletor, chave "modo" mudada por fora, ou a primeira vez que o widget
// aparece). O conteúdo escolhe o que mostrar pelo tamanho real: abaixo de "limiteCartao" (largura OU
// altura) o cartão enxuto; acima, a moldura completa, que esconde partes por faixas de tamanho.
// Ao aplicar um preset, o canto que fica parado é o mais perto da borda e o widget não sai da tela;
// a troca anima com uma moldura que se redimensiona e o conteúdo que acende (movimento "mínimo": direto).
// Fora da área de trabalho (popup da barra), mostra a moldura no tamanho grande.
Item {
    id: t
    property string modo: "pequeno"               // último preset escolhido
    property int pedido: 0                        // muda a cada escolha de preset (mesmo repetida)
    property bool aplicarAoIniciar: false         // primeira vez: aplica o preset de "modo"
    property bool naMesa: true
    property Component pequeno
    property Component completo
    property size tamanhoPequeno: Qt.size(230, 90)
    property size tamanhoMedio: Qt.size(320, 240)
    property size tamanhoGrande: Qt.size(360, 420)
    property size limiteCartao: Qt.size(260, 140) // abaixo disto (largura ou altura): o cartão
    property real opacidade: 0.95
    property bool controlesDireita: false         // faixa de edição à direita (ver a Cerca recolhida)
    property bool controlesFora: false            // faixa abaixo do widget, sem cobrir o conteúdo
    property real alturaMinima: 60                // na área de trabalho (a Cerca recolhida fica mais baixa)
    signal presetAplicado()

    function _tam(m) { return m === "pequeno" ? tamanhoPequeno : m === "medio" ? tamanhoMedio : tamanhoGrande }
    readonly property bool cartao: naMesa && (width < limiteCartao.width || height < limiteCartao.height)
    // o preset que corresponde ao tamanho de agora (com a folga da grade da área de trabalho)
    readonly property string presetAtual: {
        if (!naMesa) return ""
        for (const m of ["pequeno", "medio", "grande"]) {
            const s = _tam(m)
            if (Math.abs(width - s.width) < 17 && Math.abs(height - s.height) < 17) return m
        }
        return ""
    }

    Layout.minimumWidth: naMesa ? 150 : tamanhoGrande.width
    Layout.minimumHeight: naMesa ? alturaMinima : tamanhoGrande.height
    // na área de trabalho, nenhum tamanho "preferido": o contêiner do Plasma adota o preferido quando as
    // dicas de tamanho mudam, e desfaria o tamanho manual. Os presets são aplicados por _aplicar().
    Layout.preferredWidth: naMesa ? -1 : tamanhoGrande.width
    Layout.preferredHeight: naMesa ? -1 : tamanhoGrande.height

    Loader {
        id: car
        anchors.fill: parent
        sourceComponent: t.cartao ? t.pequeno : t.completo
        opacity: t._trocando ? 0 : 1
    }

    // ---- ocultar e exibir com os outros widgets (estado global; Ocultacao.qml). Oculto = sem interação.
    property bool ocultavel: true
    Ocultacao {
        id: oc
        ativo: t.naMesa && t.ocultavel
        cont: t._c
        edicao: t._edicao
    }
    AnimacaoWidget {
        alvo: car
        variante: oc.variante
        visivel: !oc.ocultaAgora
        atraso: oc.atraso
        atrasoSaida: oc.atrasoSaida
        // o contêiner é desabilitado junto: o Binding daqui guardaria o false herdado e o devolveria
        onVisivelChanged: if (visivel) Qt.callLater(() => car.enabled = true)
    }
    Binding { when: !!t._c && oc.ocultaAgora; target: t._c; property: "enabled"; value: false; restoreMode: Binding.RestoreBindingOrValue }

    // ---- controles de edição: alça e presets P/M/G numa faixa presa ao CONTÊINER do applet, acima da
    //      camada de edição do Plasma (que fica com os cliques do conteúdo). Só no modo de edição.
    property var _c: null
    function _procurar() { if (!_c) _c = Cores.conteiner(t) }
    Timer { interval: 800; running: t.naMesa && t._c === null; repeat: true; onTriggered: t._procurar() }
    readonly property bool _edicao: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode === true : false
    Row {
        id: controles
        parent: t._c ? t._c : t
        z: 10000
        x: t.controlesDireita ? (parent ? parent.width : t.width) - width - 34 : 14
        y: t.controlesFora ? (parent ? parent.height : t.height) + 4 : (parent ? parent.height : t.height) - height - (t.controlesDireita ? 13 : 10)
        spacing: 6
        Revelador { alvo: controles; mostrar: t.naMesa && t._c !== null && t._edicao && !Plasmoid.immutable }
        Rectangle {
            width: faixa.width + 10; height: 22
            color: Cores.alfa(Cores.cartao, 0.92); border.color: Cores.alfa(Cores.destaque, 0.7)
            Row {
                id: faixa
                anchors.centerIn: parent
                spacing: 6
                Alca { anchors.verticalCenter: parent.verticalCenter }
                SeletorTamanho {
                    anchors.verticalCenter: parent.verticalCenter
                    atual: t.presetAtual
                    onEscolhido: (m) => t.escolherPreset(m)
                }
            }
        }
    }
    signal escolherPreset(string modo)

    // ---- presets
    property bool _pronto: false
    property bool _trocando: false
    onPedidoChanged: if (_pronto) Qt.callLater(() => _aplicar(true))
    onModoChanged: if (_pronto) Qt.callLater(() => _aplicar(true))
    Component.onCompleted: Qt.callLater(() => { if (aplicarAoIniciar) _aplicar(false); _pronto = true })
    property int _tentativas: 0
    Timer { id: retentar; interval: 600; onTriggered: t._aplicar(false) }

    function _aplicar(animar) {
        if (!naMesa) return
        const alvo = _tam(modo)
        const r = Cores.redimensionar(t, alvo.width, alvo.height)
        if (!r) { if (_tentativas++ < 5) retentar.restart(); return }
        presetAplicado()
        if (!animar || Cores.reduzir || !r.mudou) return
        fantasma.ancDir = r.direita; fantasma.ancBaixo = r.baixo
        fantasma.w0 = r.w0; fantasma.h0 = r.h0
        _trocando = true
        animTroca.restart()
    }
    function _acender() {
        _trocando = false
        if (car.item && car.item.montar) car.item.montar()
    }

    // moldura que se redimensiona do tamanho antigo ao novo (ancorada no canto que fica parado)
    Item {
        id: fantasma
        visible: t._trocando
        property bool ancDir: false
        property bool ancBaixo: false
        property real w0: 0
        property real h0: 0
        property real p: 1
        readonly property real e: p >= 1 ? 1 : 1 - Math.pow(2, -10 * p)
        width: w0 + (t.width - w0) * e
        height: h0 + (t.height - h0) * e
        x: ancDir ? t.width - width : 0
        y: ancBaixo ? t.height - height : 0
        z: 10
        Chanfro {
            anchors.fill: parent
            corte: 10
            preenchimento: Cores.alfa(Cores.cartao, t.opacidade)
            borda: Cores.alfa(Cores.destaque, 0.8)
        }
        Cantoneiras { anchors.margins: -4; cor: Cores.secundaria; tamanho: 8 }
        Rectangle {
            x: fantasma.ancDir ? -2 : parent.width - 1; width: 2; height: parent.height
            color: Cores.secundaria; opacity: 0.8
        }
    }
    SequentialAnimation {
        id: animTroca
        NumberAnimation { target: fantasma; property: "p"; from: 0; to: 1; duration: Cores.d(260); easing.type: Easing.Linear }
        ScriptAction { script: t._acender() }
    }
}
