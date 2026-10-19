import QtQuick

// Entrada em sequência, no tempo das janelas do Cyberpunk (Portfolio Refeencias, "Animação de
// janelas": quadros de 33 ms). Põe-se dentro de um item; quando "ativo" liga, o alvo entra depois de
// "ordem" × 45 ms:
//  - alvo com moldura (propriedades traco/superficie/acender/realce, ver Bloco): a moldura se traça
//    (280 ms, linear), a superfície aparece (a partir de 180 ms), o conteúdo acende com flicker de
//    "liga e desliga" (a partir de 220 ms) e a borda pisca na secundária ao fechar (280 ms);
//  - outro alvo: só o flicker de liga e desliga (sem deslizar).
// Com "reduzir animações", tudo aparece direto.
Item {
    id: c
    property Item alvo: parent
    property int ordem: 0
    property bool ativo: false
    // compatibilidade com o uso antigo (deslizava): ignoradas
    property real deslocamento: 0
    property bool vertical: false
    visible: false

    readonly property int atraso: Math.min(ordem, 14) * 45
    readonly property bool _montavel: !!alvo && alvo.traco !== undefined

    Component.onCompleted: if (ativo) entrar()
    onAtivoChanged: if (ativo) entrar()

    function entrar() {
        montar.stop(); piscar.stop()
        if (!alvo) return
        if (Tema.reduzir) {
            alvo.opacity = 1
            if (_montavel) { alvo.traco = 1; alvo.superficie = 1; alvo.acender = 1; alvo.realce = 0 }
            return
        }
        if (_montavel) {
            alvo.opacity = 1
            alvo.traco = 0; alvo.superficie = 0; alvo.acender = 0; alvo.realce = 0
            montar.start()
        } else {
            alvo.opacity = 0
            piscar.start()
        }
    }

    // flicker de liga e desliga: valores de opacidade em quadros de 33 ms
    readonly property var _flicker: [0.75, 0.1, 0.9, 0.35, 1]

    SequentialAnimation {
        id: montar
        PauseAnimation { duration: c.atraso }
        ParallelAnimation {
            NumberAnimation { target: c.alvo; property: "traco"; from: 0; to: 1; duration: 280; easing.type: Easing.Linear }
            SequentialAnimation {
                PauseAnimation { duration: 180 }
                NumberAnimation { target: c.alvo; property: "superficie"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 220 }
                PropertyAction { target: c.alvo; property: "acender"; value: c._flicker[0] }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "acender"; value: c._flicker[1] }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "acender"; value: c._flicker[2] }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "acender"; value: c._flicker[3] }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "acender"; value: c._flicker[4] }
            }
            SequentialAnimation {
                PauseAnimation { duration: 280 }
                PropertyAction { target: c.alvo; property: "realce"; value: 1 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "realce"; value: 0.2 }
                PauseAnimation { duration: 33 }
                PropertyAction { target: c.alvo; property: "realce"; value: 0.8 }
                NumberAnimation { target: c.alvo; property: "realce"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    SequentialAnimation {
        id: piscar
        PauseAnimation { duration: c.atraso + 200 }
        PropertyAction { target: c.alvo; property: "opacity"; value: c._flicker[0] }
        PauseAnimation { duration: 33 }
        PropertyAction { target: c.alvo; property: "opacity"; value: c._flicker[1] }
        PauseAnimation { duration: 33 }
        PropertyAction { target: c.alvo; property: "opacity"; value: c._flicker[2] }
        PauseAnimation { duration: 33 }
        PropertyAction { target: c.alvo; property: "opacity"; value: c._flicker[3] }
        PauseAnimation { duration: 33 }
        PropertyAction { target: c.alvo; property: "opacity"; value: c._flicker[4] }
    }
}
