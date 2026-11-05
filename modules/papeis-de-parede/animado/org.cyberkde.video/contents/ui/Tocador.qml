import QtQuick
import QtMultimedia

// O vídeo em si, sem nada do Plasma (o teste roda este arquivo sozinho). Em loop, sem som (nenhum
// AudioOutput: o áudio nem é decodificado), preenchendo a tela. Com "ativo" falso pausa no quadro em que
// está; sem vídeo ou com erro (arquivo sumiu, formato que não abre), mostra a imagem de reserva, que é o
// papel padrão do tema. A decodificação é a do QtMultimedia (FFmpeg), que escolhe sozinho a da placa
// quando há (CUDA na NVIDIA).
// Pausa longa (mais de "folga" ms): o quadro atual vira imagem e o tocador é destruído (decodificador,
// threads e memória dele); ao voltar, um tocador novo retoma da mesma posição.
Item {
    id: raiz
    property url fonte
    property url reserva
    property string preenchimento: "cortar"   // cortar | ajustar | esticar
    property bool ativo: true
    property int folga: 15000

    property bool _erro: false
    readonly property bool falhou: _erro || fonte.toString() === ""
    readonly property bool tocando: carga.item ? carga.item.playbackState === MediaPlayer.PlayingState : false
    property bool _solto: false        // tocador destruído na pausa longa
    property int _posicao: 0           // onde retomar

    Rectangle { anchors.fill: parent; color: "black" }

    Image {
        anchors.fill: parent
        visible: raiz.falhou
        source: raiz.falhou ? raiz.reserva : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: width
        sourceSize.height: height
    }

    VideoOutput {
        id: saida
        anchors.fill: parent
        visible: !raiz.falhou
        fillMode: raiz.preenchimento === "ajustar" ? VideoOutput.PreserveAspectFit
                : raiz.preenchimento === "esticar" ? VideoOutput.Stretch
                : VideoOutput.PreserveAspectCrop
    }

    // quadro congelado enquanto o tocador está solto (e até o novo mostrar o primeiro quadro)
    Image {
        id: congelado
        anchors.fill: parent
        visible: source.toString() !== "" && !raiz.falhou
        cache: false
    }

    Loader {
        id: carga
        active: !raiz.falhou && !raiz._solto
        sourceComponent: MediaPlayer {
            id: tocador
            source: raiz.fonte
            videoOutput: saida
            loops: MediaPlayer.Infinite
            onErrorOccurred: (codigo, texto) => {
                console.warn("org.cyberkde.video:", texto)
                raiz._erro = true
            }
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.InvalidMedia) raiz._erro = true
                else if (mediaStatus === MediaPlayer.LoadedMedia && raiz._posicao > 0 && seekable) {
                    position = raiz._posicao
                    raiz._posicao = 0
                }
            }
            // o primeiro quadro novo já está na tela: tira o congelado
            onPositionChanged: if (congelado.visible && playbackState === MediaPlayer.PlayingState) congelado.source = ""
            // (aqui o carga.item ainda não aponta para este tocador)
            Component.onCompleted: raiz.sincronizar(tocador)
            Component.onDestruction: stop()
        }
    }

    Timer {
        id: soltar
        interval: raiz.folga
        onTriggered: {
            const p = carga.item
            if (raiz.ativo || raiz.falhou || !p) return
            saida.grabToImage(r => {
                if (raiz.ativo || !carga.item) return
                congelado.source = r.url
                raiz._posicao = carga.item.position
                raiz._solto = true
            })
        }
    }

    // pause() a partir de parado carrega e mostra o primeiro quadro: coberto desde o início, a tela não
    // fica preta e nada roda.
    function sincronizar(novo) {
        const p = novo || carga.item
        if (raiz.ativo) {
            soltar.stop()
            if (raiz._solto) { raiz._solto = false; return }   // o tocador novo se inicia ao nascer
            if (p) p.play()
        } else {
            if (p) p.pause()
            if (!raiz._solto) soltar.restart()
        }
    }
    onAtivoChanged: sincronizar(null)
    onFonteChanged: { raiz._erro = false; raiz._posicao = 0; congelado.source = "" }
    onFalhouChanged: { congelado.source = ""; raiz._posicao = 0; raiz._solto = false }
}
