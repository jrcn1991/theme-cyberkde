// GERADO por modules/widgets/plasmoides/cerca-anim-gerar.py a partir do AnimacaoCerca.qml do Cyber Fence: não editar.
import QtQuick
import "catalogoAnim.js" as Catalogo

// Exibição e ocultação do Cyber Fence (catálogo em contents/animacoes.json, padrão "tracado").
//   AnimacaoCerca { alvo: conteudo; variante: "tracado"; visivel: bool; atraso: ms; duracao: ms }
// Fica como irmão do alvo, por cima dele (assume o parent e a geometria do alvo sozinho). Enquanto anima,
// o alvo é desenhado pelo shader (anim/cerca.frag); parado, não há efeito nenhum: nem textura, nem quadro.
//  - visivel falso: a cerca para de receber eventos NA HORA e, ao terminar a saída, fica invisível (o alvo
//    não pega mouse nem soltar). O enabled e o visible do alvo ficam por conta deste componente enquanto
//    ele estiver oculto; ao voltar, os bindings originais são restaurados.
//  - o valor inicial de visivel vale sem animar; só as mudanças animam.
//  - atraso: ms antes de começar (nas duas direções, ou só na entrada, com atrasoSaida). duracao: ms; 0 = a da
//    variante no catálogo.
//  - "cascata": soma um atraso pela posição na tela (de cima à esquerda para baixo à direita; na saída, ao
//    contrário), então várias cercas se sequenciam sem se conhecer.
//  - pedido contrário no meio da animação: inverte de onde está.
//  - movimento: "mínimo" (Cores.reduzir) é instantâneo; "reduzido" (fator < 0,75) usa a dissolução curta.
Item {
    id: a
    property Item alvo: null
    property string variante: "tracado"
    property bool visivel: true
    property int atraso: 0
    property int atrasoSaida: -1       // na saída, no lugar de "atraso" (-1 = o mesmo)
    property int duracao: 0
    property color cor: Cores.destaque
    property color cor2: Cores.secundaria
    property int margem: 28            // brilho e peças podem passar do alvo até aqui
    readonly property bool animando: seq.running
    readonly property bool oculta: p <= 0 && !_desenhando       // terminou a saída (ou ainda espera a entrada)
    signal entrou()
    signal saiu()

    property real p: 1                 // atribuído, nunca binding: a animação parte de onde está
    property bool _desenhando: false
    property real _saida: 0
    property var _ativa: null          // a variante em uso (não troca no meio da passada)
    property bool _pronto: false

    readonly property bool _reduzido: Cores.fator < 0.75
    enabled: false
    parent: alvo ? alvo.parent : null
    z: alvo ? alvo.z + 1 : 0
    x: alvo ? alvo.x - margem : 0
    y: alvo ? alvo.y - margem : 0
    width: alvo ? alvo.width + 2 * margem : 0
    height: alvo ? alvo.height + 2 * margem : 0

    Binding { target: a.alvo; property: "enabled"; value: false; when: !!a.alvo && !a.visivel; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: a.alvo; property: "visible"; value: false; when: !!a.alvo && a.oculta; restoreMode: Binding.RestoreBindingOrValue }

    function _atrasoCascata(v, saida) {
        if (v.id !== "cascata" || !alvo || !a.Window.window) return 0
        const g = alvo.mapToItem(null, 0, 0), w = a.Window.window
        const f = Math.max(0, Math.min(1, (g.x + g.y) / Math.max(1, w.width + w.height)))
        return Math.round((saida ? 1 - f : f) * 520)
    }
    function _mudou() {
        if (!_pronto) return
        seq.stop()
        const alvoP = visivel ? 1 : 0
        if (Cores.reduzir || !alvo || alvo.width <= 0 || alvo.height <= 0) { _desenhando = false; p = alvoP; _fim(); return }
        const parada = p <= 0 || p >= 1
        if (parada) {                  // do repouso: escolhe a variante; invertendo, segue a mesma
            _ativa = _reduzido ? Catalogo.de("dissolucao") : Catalogo.de(variante)
            _saida = visivel ? 0 : 1
        }
        const v = _ativa, cheia = duracao > 0 ? duracao : (visivel ? v.duracaoEntrada : v.duracaoSaida)
        const d = _reduzido ? Math.min(cheia, visivel ? v.duracaoEntrada : v.duracaoSaida) : cheia
        pausa.duration = parada ? (!visivel && atrasoSaida >= 0 ? atrasoSaida : atraso) + (_reduzido ? 0 : _atrasoCascata(v, !visivel)) : 0
        anda.to = alvoP
        anda.duration = Math.max(1, Math.round(d * Math.abs(alvoP - p)))
        seq.start()
    }
    function _fim() { if (visivel) entrou(); else saiu() }
    onVisivelChanged: _mudou()
    Component.onCompleted: { p = visivel ? 1 : 0; _pronto = true }
    SequentialAnimation {
        id: seq
        PauseAnimation { id: pausa }
        ScriptAction { script: a._desenhando = true }
        NumberAnimation { id: anda; target: a; property: "p"; easing.type: Easing.Linear }
        ScriptAction { script: { a._desenhando = false; a._fim() } }
    }

    ShaderEffectSource {
        id: fonteAlvo
        sourceItem: a._desenhando ? a.alvo : null
        hideSource: true
        live: true
        smooth: true
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        visible: a._desenhando
        readonly property var fonte: fonteAlvo
        readonly property size tam: a.alvo ? Qt.size(a.alvo.width, a.alvo.height) : Qt.size(1, 1)
        readonly property real margem: a.margem
        readonly property real p: a.p
        readonly property real saida: a._saida
        readonly property real modo: a._ativa ? a._ativa.modo : 0
        readonly property real semente: a.alvo ? (a.alvo.x * 0.37 + a.alvo.y * 0.11) % 97 : 0
        readonly property color cor: a.cor
        readonly property color cor2: a.cor2
        fragmentShader: Qt.resolvedUrl("cerca.frag.qsb")
    }
}
