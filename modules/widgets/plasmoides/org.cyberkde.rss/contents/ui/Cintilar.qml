import QtQuick
import "comum"

// Pisca o "alvo" três vezes quando "pulso" muda (notícia nova). Com movimento mínimo, não pisca.
QtObject {
    id: c
    property Item alvo
    property int pulso: 0
    property int _visto: -1
    onPulsoChanged: {
        if (_visto < 0) { _visto = pulso; return }   // o valor inicial não pisca
        _visto = pulso
        if (alvo && !Cores.reduzir) anim.restart()
    }
    property SequentialAnimation anim: SequentialAnimation {
        loops: 3
        NumberAnimation { target: c.alvo; property: "opacity"; to: 0.15; duration: Cores.d(90) }
        NumberAnimation { target: c.alvo; property: "opacity"; to: 1; duration: Cores.d(90) }
    }
}
