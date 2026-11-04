import QtQuick
import "../exacerbado" as Exacerbado

// Sandevistan: o Punk exacerbado (herdado, sem mudar nada lá) com outra curva e o rastro no Efeito.
// A curva é o efeito do jogo: dispara (55% do caminho em 18% do tempo), quase para (só +11% até 78%) e volta de
// uma vez. Splines curtas: Curvas.curva() fica em 4 trechos.
Exacerbado.Tema {
    id: t
    // o "verde-ciano" do jogo vem da paleta: a secundária, ou o alerta quando ela é quase branca (Arasaka…)
    readonly property color corRastro: _s.hslSaturation >= 0.45 && _s.hslLightness < 0.8 ? _s : _a
    sombraCor: _al(corRastro, 0.3)
    tempos: ({ abrir: 260, fechar: 150, anuncio: 200, conteudoEntra: 100, conteudoSai: 60, chegada: 240 })
    readonly property var _sande: [[0.18, 0.55], [0.5, 0.6], [0.78, 0.66], [1, 1]]
    curvas: ({ abrir: _sande, fechar: [[0.2, 0.5], [0.6, 0.58], [1, 1]], anuncio: _sande, entrar: "entrar", sair: "sair", chegada: _sande })
    // onde o tempo "volta", na fração do tempo do momento (o Efeito sincroniza com a curva)
    readonly property var voltaEm: ({ abrir: 0.78, fechar: 0.6, anuncio: 0.78 })
    function movimento(id) { return null }
}
