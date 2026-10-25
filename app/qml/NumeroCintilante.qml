import QtQuick

// Número com cintilação (A13 do catálogo de animações): quando o valor muda, mostra 3–5 valores
// aleatórios em ~180 ms antes do final, com largura fixa (fonte mono) para não mexer o layout.
// Com "reduzir animações", troca direto.
Text {
    id: n
    property string valor: ""
    property string _mostrado: valor
    text: _mostrado
    font.family: Tema.fMono
    property int _passo: 0
    onValorChanged: {
        if (Tema.reduzir || !visible || !/[0-9]/.test(valor)) { _mostrado = valor; return }
        _passo = 0
        tick.restart()
    }
    Timer {
        id: tick
        interval: 40
        repeat: true
        onTriggered: {
            n._passo++
            if (n._passo > 4) { n._mostrado = n.valor; stop(); return }
            n._mostrado = n.valor.replace(/[0-9]/g, () => String(Math.floor(Math.random() * 10)))
        }
    }
}
