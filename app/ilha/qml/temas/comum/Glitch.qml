import QtQuick

// Fatias deslocadas e aberração cromática sobre o que a gota já mostra, por no máximo "ms". Fotografa a gota uma
// vez, sem si mesmo, e desenha por cima; em repouso não existe textura nem camada. Fora disso, nada acontece.
Item {
    id: g
    property Item fonte: parent ? parent.parent : null   // a gota
    property real forca: 0
    function tocar(ms, f) { clock.tocar(ms); forcaMax = f === undefined ? 1 : f; foto.sourceItem = fonte; foto.scheduleUpdate() }
    property real forcaMax: 1
    readonly property real atual: clock.running ? forcaMax * (1 - clock.p * clock.p) : 0
    Relogio { id: clock; onTerminou: foto.sourceItem = null }
    ShaderEffectSource { id: foto; live: false; recursive: false; visible: false; smooth: false; hideSource: false }
    ShaderEffect {
        anchors.fill: parent
        visible: clock.running && clock.p > 0
        readonly property var fonte: foto
        readonly property size tam: Qt.size(width, height)
        readonly property real forca: g.atual
        readonly property real passo: Math.floor(clock.p * clock.ms / 34)
        fragmentShader: Qt.resolvedUrl("glitch.frag.qsb")
    }
}
