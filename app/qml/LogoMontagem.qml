import QtQuick
import QtQuick.Effects

// Logo que se monta como no Cyberpunk (Portfolio Refeencias, "Efeito de logo", "…logo2", "…logo3";
// tempos medidos quadro a quadro, ver app/ANIMACOES.md):
//   escuro → feixes horizontais de dados e partículas convergem (camada de "logo3")
//   → o circuito do logo se traça (wireframe de "logo2")
//   → o logo chega em fatias horizontais deslocadas, com aberração cromática (secundária / destaque)
//   → assenta com flicker de liga e desliga e um pulso de brilho.
// Tudo deriva de um único "t" (0..1) animado só durante a montagem: em repouso não há animação
// rodando nem camada de efeito ligada.
//
// modo: "completo" (abertura, 1,25 s), "medio" (inspetor e confirmação, 0,78 s) ou "compacto"
// (cabeçalho e menu lateral, 0,52 s). A montagem roda ao trocar "source" ou ao chamar montar().
Item {
    id: m
    property url source
    property var recorte: null
    property color cor: Tema.destaque
    property color corDados: Tema.secundaria
    property bool brilho: true
    property bool varreduraOciosa: false
    property string modo: "medio"
    property bool montarAoCarregar: false
    readonly property alias proporcao: base.proporcao

    property real t: 1
    readonly property bool animando: t < 1
    readonly property int duracao: modo === "completo" ? 1250 : (modo === "medio" ? 780 : 520)
    signal montado()

    implicitWidth: 64; implicitHeight: 64

    // ---- parâmetros por modo (frações de t)
    readonly property var _p: modo === "completo"
        ? { feixes: 52, particulas: 40, brilhos: 5, fatias: 11, contorno: true, fatIni: 0.48, fatJan: 0.14, fatFim: 0.80,
            abIni: 0.46, abFim: 0.86, flIni: 0.80, flFim: 0.90, campo: 2.4, dados: [0.18, 0.62] }
        : modo === "medio"
        ? { feixes: 24, particulas: 18, brilhos: 3, fatias: 8, contorno: true, fatIni: 0.30, fatJan: 0.16, fatFim: 0.74,
            abIni: 0.28, abFim: 0.84, flIni: 0.76, flFim: 0.88, campo: 1.6, dados: [0.02, 0.55] }
        : { feixes: 7, particulas: 6, brilhos: 0, fatias: 5, contorno: false, fatIni: 0.0, fatJan: 0.18, fatFim: 0.66,
            abIni: 0.0, abFim: 0.78, flIni: 0.68, flFim: 0.84, campo: 1.3, dados: [0.0, 0.45] }

    // sementes sorteadas a cada montagem
    property var _s: []
    function _novasSementes() {
        let a = []
        for (let i = 0; i < 64; i++) a.push([Math.random(), Math.random(), Math.random(), Math.random(), Math.random()])
        _s = a
    }
    function _sem(i, k) { return _s.length ? _s[i % _s.length][k] : 0.5 }
    function _lim(x) { return Math.max(0, Math.min(1, x)) }
    function _expo(x) { return x >= 1 ? 1 : 1 - Math.pow(2, -10 * x) }

    function montar() {
        anim.stop()
        if (Tema.reduzir || !Tema.efeitos || source == "") { t = 1; return }
        _novasSementes()
        _contorno = _p.contorno ? painel.contorno(String(source).split("?")[0]) : ""
        t = 0
        anim.start()
    }
    function pular() { anim.stop(); t = 1 }

    property bool _pronto: false
    onSourceChanged: {
        if (!_pronto) return
        if (source == "" || !visible) { pular(); return }
        montar()
    }
    Component.onCompleted: { _pronto = true; if (montarAoCarregar && source != "") montar() }

    NumberAnimation {
        id: anim
        target: m; property: "t"; from: 0; to: 1
        duration: m.duracao
        easing.type: Easing.Linear
        onFinished: m.montado()
    }

    // ---- fases derivadas de t
    readonly property bool _fatiando: animando && t >= _p.fatIni && t < _p.fatFim
    readonly property real _ab: animando ? (t < _p.abIni ? 0 : 1 - _lim((t - _p.abIni) / (_p.abFim - _p.abIni))) : 0
    // flicker de liga e desliga ao assentar (degraus de ~1 quadro)
    readonly property real _fl: !animando || t < _p.flIni || t >= _p.flFim ? 1
        : [1, 0.25, 1, 0.55, 0.15, 1][Math.floor((t - _p.flIni) / (_p.flFim - _p.flIni) * 6)]
    readonly property real _pulso: animando && t >= _p.flIni ? Math.sin(_lim((t - _p.flIni) / (1 - _p.flIni)) * Math.PI) : 0

    // ---- campo de dados (feixes, partículas, brilhos diagonais), maior que o logo e sem recorte
    Item {
        id: campo
        visible: m.animando && m._s.length > 0 && m.t > m._p.dados[0] - 0.02 && m.t < m._p.dados[1] + 0.12
        width: Math.max(m.width * m._p.campo, 80)
        height: Math.max(m.height * 1.25, 30)
        anchors.centerIn: parent
        readonly property real tl: m._lim((m.t - m._p.dados[0]) / (m._p.dados[1] - m._p.dados[0]))   // 0..1 da fase
        layer.enabled: visible && Tema.efeitos && m.modo !== "compacto"
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: m.corDados
            shadowBlur: 0.7
            shadowOpacity: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 20
        }

        // feixes horizontais: aparecem na faixa central, piscam e derivam em direção ao centro
        Repeater {
            model: campo.visible ? m._p.feixes : 0
            Rectangle {
                required property int index
                readonly property real nasce: m._sem(index, 0) * 0.7
                readonly property real vida: 0.18 + m._sem(index, 1) * 0.3
                readonly property real p: (campo.tl - nasce) / vida
                readonly property bool destaque: index % 7 === 0
                readonly property real alvoX: (m._sem(index, 2) - 0.5) * campo.width * 0.8
                readonly property real lado: m._sem(index, 3) < 0.5 ? -1 : 1
                width: (destaque ? 0.22 : 0.06 + m._sem(index, 4) * 0.2) * campo.width
                height: destaque ? 3 : (m._sem(index, 4) > 0.7 ? 2 : 1)
                // concentração no meio da faixa
                y: campo.height / 2 + ((m._sem(index, 1) + m._sem(index, 2)) / 2 - 0.5) * campo.height * 0.9
                x: campo.width / 2 + alvoX - width / 2 + lado * campo.width * 0.25 * (1 - m._expo(m._lim(p)))
                color: destaque ? m.cor : (m._sem(index, 3) > 0.85 ? Tema.texto : m.corDados)
                opacity: p < 0 || p > 1 ? 0 : (Math.floor(p * 9 + index) % 3 === 0 ? 0.35 : 1) * (1 - p * 0.4)
            }
        }
        // partículas: pontos que piscam espalhados
        Repeater {
            model: campo.visible ? m._p.particulas : 0
            Rectangle {
                required property int index
                readonly property real nasce: m._sem(index + 20, 0) * 0.8
                readonly property real p: (campo.tl - nasce) / 0.25
                width: m._sem(index + 20, 1) > 0.7 ? 3 : 2; height: 2
                x: m._sem(index + 20, 2) * campo.width
                y: campo.height / 2 + (m._sem(index + 20, 3) - 0.5) * campo.height
                color: m._sem(index + 20, 4) > 0.8 ? m.cor : m.corDados
                opacity: p < 0 || p > 1 ? 0 : (Math.floor(p * 6) % 2 ? 0.4 : 1)
            }
        }
        // brilhos diagonais (os "conectores" que atravessam as letras na referência)
        Repeater {
            model: campo.visible ? m._p.brilhos : 0
            Rectangle {
                required property int index
                readonly property real p: (m.t - (m._p.fatIni + m._sem(index + 50, 0) * 0.15)) / 0.12
                width: 1; height: campo.height * (0.4 + m._sem(index + 50, 1) * 0.5)
                x: campo.width * (0.3 + m._sem(index + 50, 2) * 0.4)
                y: (campo.height - height) / 2
                rotation: 35
                color: m.corDados
                opacity: p < 0 || p > 1 ? 0 : 1 - p
            }
        }
        // linha tracejada que corre pelo topo (430–470 ms na referência)
        Row {
            visible: m.modo === "completo" && campo.tl > 0.4 && campo.tl < 0.55
            y: -campo.height * 0.35
            x: campo.width * (campo.tl - 0.4) * 2
            spacing: 14
            Repeater { model: 8; Rectangle { width: 26; height: 2; color: m.corDados } }
        }
    }

    // ---- circuito (wireframe) traçado da esquerda para a direita antes do preenchimento
    property url _contorno: ""
    Item {
        id: fio
        visible: m.animando && m._contorno != "" && m.t > 0.12 && m.t < m._p.fatFim + 0.05
        anchors.fill: parent
        readonly property real p: m._lim((m.t - 0.15) / 0.3)
        Item {
            width: parent.width * fio.p; height: parent.height
            clip: true
            LogoCorp {
                width: m.width; height: m.height
                source: m._contorno
                recorte: m.recorte
                animarTroca: false
                brilho: false
                tingir: true
                cor: m.corDados
                // tremula enquanto se desenha e apaga quando as fatias chegam
                opacity: (Math.floor(m.t * 60) % 4 === 0 ? 0.45 : 0.9) * (m.t < m._p.fatIni ? 1 : 1 - m._lim((m.t - m._p.fatIni) / 0.15))
            }
        }
        // cabeça do traço
        Rectangle {
            visible: fio.p > 0 && fio.p < 1
            x: parent.width * fio.p - 1; width: 2; height: parent.height
            color: m.corDados
            opacity: 0.8
        }
    }

    // aberração cromática: duas cópias tingidas ATRÁS do logo, deslocadas para lados opostos (sobram
    // só as franjas ciano / destaque nas bordas, como na referência)
    Repeater {
        model: m._ab > 0 && Tema.efeitos ? 2 : 0
        MultiEffect {
            required property int index
            source: fonte
            width: m.width; height: m.height
            x: (index === 0 ? -1 : 1) * m._ab * Math.max(3, Math.min(m.width, m.height * 3) * 0.045)
            y: (index === 0 ? 1 : -1) * m._ab * 1.5
            colorization: 1
            colorizationColor: index === 0 ? m.corDados : Qt.lighter(m.cor, 1.25)
            opacity: 0.85 * Math.min(1, m._ab * 1.6)
        }
    }

    // ---- o logo final (fonte das fatias e da aberração)
    Item {
        id: palco
        anchors.fill: parent
        opacity: m._fl
        visible: !m.animando || m.t >= m._p.fatIni
        LogoCorp {
            id: base
            anchors.fill: parent
            source: m.source
            recorte: m.recorte
            cor: m.cor
            brilho: m.brilho
            animarTroca: false
            varreduraOciosa: m.varreduraOciosa && !m.animando
            realce: m._pulso
        }
    }
    ShaderEffectSource {
        id: fonte
        sourceItem: base
        hideSource: m._fatiando
        live: m.animando
        visible: false
    }

    // fatias horizontais que chegam deslocadas e deslizam para o lugar (expo.out)
    Repeater {
        model: m._fatiando ? m._p.fatias : 0
        Item {
            id: fatia
            required property int index
            readonly property real altura: m.height / m._p.fatias
            readonly property real inicio: m._p.fatIni + m._sem(index + 30, 0) * m._p.fatJan
            readonly property real dur: (m._p.fatFim - m._p.fatIni) * (0.45 + m._sem(index + 30, 1) * 0.35)
            readonly property real p: m._lim((m.t - inicio) / dur)
            readonly property real desl: (m._sem(index + 30, 2) - 0.5) * 2 * Math.max(20, m.width * 0.28)
            visible: m.t >= inicio
            y: index * altura
            width: m.width; height: altura + 1
            clip: true
            ShaderEffect {
                property variant source: fonte
                y: -fatia.y
                x: fatia.desl * (1 - m._expo(fatia.p))
                width: m.width; height: m.height
            }
        }
    }
}
