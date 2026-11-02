import QtQuick
import org.kde.plasma.components as PC3
import "comum"

// Um módulo da grade FUI. As medidas da referência estão em unidades do painel-base (866×732); "k" é o
// fator da tela, e TUDO é convertido para pixel inteiro aqui (u), sem escala por transformação: o texto
// sai com o hinting da fonte e as linhas na espessura exata, em qualquer tamanho.
//   título técnico (y 3), ponto no fim, filete (y 18), conteúdo (y 24..148), filete fino com pontos (y 152)
//   e uma linha de microtexto (y 156).
// "montado" (0..1): montagem de entrada. glitch(): barras verticais no lugar do conteúdo, por um instante.
// "dica": de onde vem o dado (aparece ao passar o mouse).
Item {
    id: m
    property real k: 1
    property string titulo: ""
    property string codigo: ""            // complemento técnico do título ("CPU // LOAD")
    property string rodape: ""
    property string dica: ""
    property real montado: 1
    property bool glitchando: false
    default property alias conteudo: area.data
    property alias area: area
    property var d                        // os dados (Dados.qml)
    function u(v) { return Math.round(v * k) }                    // medida em pixel inteiro
    function fi(v) { return Math.max(11, Math.round(v * k)) }     // fonte de informação: nunca abaixo de 11 px
    function fr(v) { return Math.max(10, Math.round(v * k)) }     // rótulo (texto2)
    function lw(v) { return Math.max(1, Math.round(v * k)) }      // espessura de linha
    function conta(v) { return v * (montado >= 1 ? 1 : 1 - Math.pow(1 - montado, 3)) }   // número que cresce na montagem
    function digita(s, mm) { s = String(s); mm = mm === undefined ? montado : mm; return mm >= 1 ? s : s.slice(0, Math.floor(s.length * mm)) }
    height: u(172)

    function glitch(ms) {
        if (Cores.reduzir || !visible) return
        barras.semente = Math.random()
        glitchando = true
        fimGlitch.interval = ms || 220
        fimGlitch.restart()
    }
    Timer { id: fimGlitch; onTriggered: m.glitchando = false }

    // ---- cabeçalho: TÍTULO // CÓDIGO
    Row {
        y: m.u(2)
        spacing: m.u(5)
        opacity: Math.min(1, m.montado * 3)
        Text {
            id: tit
            text: m.titulo
            font.family: Cores.fTitulo; font.weight: Font.Bold; font.pixelSize: Math.max(11, m.u(12))
            font.capitalization: Font.AllUppercase; font.letterSpacing: 0.5
            color: Cores.texto
        }
        Text {
            visible: m.codigo !== "" && m.width - tit.width > m.u(40)
            anchors.baseline: tit.baseline
            width: Math.min(implicitWidth, m.width - tit.width - m.u(12)); elide: Text.ElideRight
            text: "// " + m.codigo
            font.family: Cores.fTitulo; font.weight: Font.DemiBold; font.pixelSize: Math.max(10, m.u(10))
            font.capitalization: Font.AllUppercase; font.letterSpacing: 0.5
            color: Cores.destaque
        }
    }
    Rectangle { x: m.width - m.u(4); y: m.u(6); width: Math.max(2, m.u(3)); height: width; color: Cores.destaque; opacity: m.montado > 0.15 ? 1 : 0 }
    Rectangle { x: 0; y: m.u(18); height: Math.max(1, m.u(2)); width: Math.round(m.width * Math.min(1, m.montado * 2.2)); color: Cores.texto }

    // ---- conteúdo
    Item {
        id: area
        x: 0; y: m.u(25)
        width: m.width; height: m.u(124)
        opacity: m.glitchando ? 0 : Math.max(0, Math.min(1, (m.montado - 0.25) * 4))
    }

    // ---- rodapé
    Item {
        y: m.u(152)
        width: m.width; height: m.u(20)
        opacity: Math.max(0, Math.min(1, (m.montado - 0.4) * 3))
        Rectangle { width: parent.width; height: 1; color: Cores.alfa(Cores.texto, 0.25) }
        Rectangle { x: 0; y: -1; width: 3; height: 3; color: Cores.texto }
        Rectangle { x: parent.width - 3; y: -1; width: 3; height: 3; color: Cores.texto }
        Text {
            y: m.u(5)
            width: parent.width; elide: Text.ElideRight
            text: m.rodape
            font.family: Cores.fMono; font.pixelSize: Math.max(9, m.u(8))
            color: Cores.texto3
        }
    }

    // ---- de onde vem o dado
    HoverHandler { id: sobre }
    PC3.ToolTip {
        visible: sobre.hovered && m.dica !== ""
        delay: 600
        text: m.dica
    }

    // ---- glitch: barras verticais de larguras e brilhos variados no lugar do conteúdo
    Item {
        id: barras
        visible: m.glitchando
        y: m.u(22); width: m.width; height: m.u(128)
        property real semente: 0
        readonly property int n: Math.max(6, Math.round(m.width / m.u(9)))
        Repeater {
            model: m.glitchando ? barras.n : 0
            Rectangle {
                required property int index
                readonly property real r: Math.abs(Math.sin((index + 1) * 12.9898 + barras.semente * 78.233) * 43758.5453) % 1
                x: Math.round(index * barras.width / barras.n + r * 3)
                width: Math.max(1, Math.round(1 + r * 6 * m.k))
                height: Math.round(barras.height * (0.55 + 0.45 * ((r * 7) % 1)))
                y: Math.round((barras.height - height) * ((r * 3) % 1))
                color: Cores.alfa(Cores.texto, 0.35 + 0.65 * ((r * 5) % 1))
            }
        }
    }
}
