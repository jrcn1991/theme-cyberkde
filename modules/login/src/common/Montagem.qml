// CyberKDE — montagem em fatias: porte do LogoMontagem do painel (app/qml/LogoMontagem.qml, tempos de
// "Efeito de logo" em app/ANIMACOES.md) para o splash, o login e o bloqueio.
//   feixes horizontais de dados convergem → o alvo chega em fatias horizontais deslocadas, com um
//   fantasma deslocado e filetes ciano/destaque (a aberração cromática) → flicker de liga e desliga.
// Só ShaderEffectSource (com sourceRect) e retângulos: funciona também no renderizador por software
// (SDDM sem GPU, prévias offscreen), onde ShaderEffect e MultiEffect não desenham nada.
// Uso: irmão do alvo, cobrindo a mesma área (anchors.fill: alvo). Tudo o que a montagem mostra precisa
// estar DENTRO do retângulo do alvo: no renderizador por software, o que o sourceRect pega fora dele sai
// preto. Por isso quem tem partes para fora (a aba do painel de login) entra numa caixa com folga.
// "t" vai de 0 a 1; com t >= 1 nada daqui é desenhado e o alvo aparece normal.
// No renderizador por software as camadas saem sem transparência (caixa escura em volta do alvo): lá
// a montagem não roda ("ativa" falso) e quem a usa cai na apresentação simples.
import QtQuick
import "."

Item {
    id: m

    property Item alvo: null
    property real t: 1
    property int fatias: 9
    property int feixes: 24
    property real campo: 1.5         // largura do campo de dados em relação ao alvo
    property color cor: CK.red
    property color corDados: CK.cyan
    // fases (frações de t), como o modo "medio" do LogoMontagem
    property real dadosIni: 0.0
    property real dadosFim: 0.55
    property real fatIni: 0.30
    property real fatFim: 0.78
    property real flIni: 0.76
    property real flFim: 0.88

    anchors.fill: alvo

    readonly property bool ativa: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool animando: ativa && t < 1 && alvo !== null
    readonly property bool escondido: animando && t < flFim
    readonly property real _fl: !animando || t < flIni || t >= flFim ? 1
        : [1, 0.25, 1, 0.55, 0.15, 1][Math.min(5, Math.floor((t - flIni) / (flFim - flIni) * 6))]

    // sorteio estável por índice (prévias reproduzíveis)
    function r(i, k) { const x = Math.sin(i * 12.9898 + k * 78.233 + 3.1) * 43758.5453; return x - Math.floor(x) }
    function lim(x) { return Math.max(0, Math.min(1, x)) }
    function expo(x) { return x >= 1 ? 1 : 1 - Math.pow(2, -10 * x) }

    // Esconde o alvo enquanto as fatias e o flicker o desenham.
    ShaderEffectSource {
        sourceItem: m.alvo
        hideSource: m.escondido
        live: false
        visible: false
        width: 1; height: 1
    }

    // ---- campo de dados
    Item {
        id: dados
        visible: m.animando && m.t < m.dadosFim + 0.12
        width: m.width * m.campo
        height: m.height
        anchors.centerIn: parent
        readonly property real tl: m.lim((m.t - m.dadosIni) / (m.dadosFim - m.dadosIni))
        Repeater {
            model: dados.visible ? m.feixes : 0
            Rectangle {
                required property int index
                readonly property real nasce: m.r(index, 0) * 0.7
                readonly property real vida: 0.18 + m.r(index, 1) * 0.3
                readonly property real p: (dados.tl - nasce) / vida
                readonly property bool forte: index % 7 === 0
                readonly property real lado: m.r(index, 3) < 0.5 ? -1 : 1
                width: (forte ? 0.22 : 0.05 + m.r(index, 4) * 0.18) * dados.width
                height: forte ? 3 : (m.r(index, 4) > 0.7 ? 2 : 1)
                y: dados.height / 2 + ((m.r(index, 1) + m.r(index, 2)) / 2 - 0.5) * dados.height * 0.9
                x: dados.width / 2 + (m.r(index, 2) - 0.5) * dados.width * 0.8 - width / 2
                   + lado * dados.width * 0.25 * (1 - m.expo(m.lim(p)))
                color: forte ? m.cor : (m.r(index, 3) > 0.85 ? CK.txt1 : m.corDados)
                opacity: p < 0 || p > 1 ? 0 : (Math.floor(p * 9 + index) % 3 === 0 ? 0.35 : 1) * (1 - p * 0.4)
            }
        }
        Repeater {  // partículas que piscam
            model: dados.visible ? Math.round(m.feixes * 0.7) : 0
            Rectangle {
                required property int index
                readonly property real p: (dados.tl - m.r(index + 40, 0) * 0.8) / 0.25
                width: m.r(index + 40, 1) > 0.7 ? 3 : 2; height: 2
                x: m.r(index + 40, 2) * dados.width
                y: dados.height / 2 + (m.r(index + 40, 3) - 0.5) * dados.height
                color: m.r(index + 40, 4) > 0.8 ? m.cor : m.corDados
                opacity: p < 0 || p > 1 ? 0 : (Math.floor(p * 6) % 2 ? 0.4 : 1)
            }
        }
    }

    // ---- fatias horizontais que chegam deslocadas e deslizam para o lugar
    Repeater {
        model: m.animando && m.t >= m.fatIni && m.t < m.flIni ? m.fatias : 0
        Item {
            id: fatia
            required property int index
            readonly property real alt: m.height / m.fatias
            readonly property real inicio: m.fatIni + m.r(index + 30, 0) * 0.16
            readonly property real dur: (m.flIni - m.fatIni) * (0.45 + m.r(index + 30, 1) * 0.35)
            readonly property real p: m.lim((m.t - inicio) / dur)
            readonly property real desl: (m.r(index + 30, 2) - 0.5) * 2 * Math.max(20, m.width * 0.28) * (1 - m.expo(p))
            readonly property real ab: (1 - p) * Math.max(3, m.height * 0.03)
            visible: m.t >= inicio
            y: index * alt
            width: m.width
            height: alt + 1
            clip: true
            ShaderEffectSource {  // fantasma: a "outra cor" deslocada
                sourceItem: m.alvo
                sourceRect: Qt.rect(0, fatia.y, m.width, fatia.height)
                x: fatia.desl + fatia.ab * 2
                width: m.width; height: fatia.height
                opacity: 0.32 * (1 - fatia.p)
                live: true
            }
            ShaderEffectSource {
                sourceItem: m.alvo
                sourceRect: Qt.rect(0, fatia.y, m.width, fatia.height)
                x: fatia.desl
                width: m.width; height: fatia.height
                live: true
            }
            // filetes de cor nas bordas da fatia (franja ciano em cima, destaque embaixo)
            Rectangle {
                x: fatia.desl - fatia.ab; width: m.width * (0.3 + m.r(fatia.index, 5) * 0.5); height: 1
                color: m.corDados; opacity: 0.9 * (1 - fatia.p)
            }
            Rectangle {
                x: fatia.desl + fatia.ab + m.width * m.r(fatia.index, 6) * 0.4
                y: fatia.height - 2; width: m.width * 0.25; height: 1
                color: m.cor; opacity: 0.8 * (1 - fatia.p)
            }
        }
    }

    // ---- assentado, com flicker de liga e desliga
    ShaderEffectSource {
        visible: m.animando && m.t >= m.flIni && m.t < m.flFim
        sourceItem: m.alvo
        sourceRect: Qt.rect(0, 0, m.width, m.height)
        anchors.fill: parent
        opacity: m._fl
        live: true
    }
}
