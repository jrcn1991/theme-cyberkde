import QtQuick

// Número que cintila ao mudar (3–5 valores aleatórios em ~180 ms), com fonte mono para não mexer o
// layout. Com o movimento em "mínimo", troca direto. "intervaloMin" evita cintilar a cada amostra.
Text {
    id: n
    property string valor: ""
    property int intervaloMin: 0
    property string _mostrado: valor
    property real _ultimo: 0
    text: _mostrado
    font.family: Cores.fMono
    color: Cores.texto
    property int _passo: 0
    onValorChanged: {
        const agora = Date.now()
        if (Cores.reduzir || !visible || !/[0-9]/.test(valor) || agora - _ultimo < intervaloMin) { if (!tick.running) _mostrado = valor; return }
        _ultimo = agora
        _passo = 0
        tick.restart()
    }
    Timer {
        id: tick
        interval: 40; repeat: true
        onTriggered: {
            n._passo++
            if (n._passo > 4) { n._mostrado = n.valor; stop(); return }
            n._mostrado = n.valor.replace(/[0-9]/g, () => String(Math.floor(Math.random() * 10)))
        }
    }
}
