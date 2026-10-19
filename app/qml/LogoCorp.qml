import QtQuick
import QtQuick.Effects

// Logo da corporação. Ao trocar de imagem, o novo entra em varredura: é revelado de cima para baixo
// atrás de uma linha brilhante, enquanto o antigo some. Em repouso, uma varredura discreta passa de
// tempos em tempos (atmosférica; desligada com "reduzir animações").
// Aceita SVG e PNG de qualquer proporção: a imagem cabe na caixa sem distorcer e é rasterizada no
// tamanho certo (só uma dimensão no sourceSize, escolhida pela proporção lida da própria imagem).
Item {
    id: l
    property url source
    property bool brilho: true
    property bool varreduraOciosa: false
    property bool animarTroca: true   // false: troca seca (quem anima é o LogoMontagem)
    property real realce: 0           // 0..1: brilho extra (pulso ao assentar)
    property color cor: Tema.destaque
    property bool tingir: String(source) === painel.logoReserva   // marca neutra do painel: pinta na cor
    property real _revelado: 1
    property url _anterior
    // Área opaca da imagem (do backend, ver recorte_opaco). Com ela, a caixa enquadra só a parte
    // visível, sem a margem transparente do arquivo.
    property var recorte: null
    readonly property bool _rec: !!recorte && recorte.w > 0 && recorte.h > 0
    // largura/altura do que aparece (1 até carregar); quem usa pode dimensionar a caixa por ela
    readonly property real proporcao: _rec ? (recorte.w * recorte.a) / recorte.h
        : (sonda.status === Image.Ready && sonda.implicitHeight > 0 ? sonda.implicitWidth / sonda.implicitHeight : 1)
    // escala que faz a caixa opaca caber na caixa do componente (unidades: altura do quadro = 1)
    readonly property real _s: _rec ? Math.min(width / (recorte.w * recorte.a), height / recorte.h) : 1
    property real _proporcaoAnterior: 1
    readonly property real _caixa: height > 0 ? width / height : 1

    // sonda: carrega a imagem no tamanho natural, invisível, só para saber a proporção
    Image { id: sonda; visible: false; source: l.source; asynchronous: true }

    implicitWidth: 64; implicitHeight: 64

    Image {
        id: antigo
        anchors.fill: parent
        source: l._anterior
        sourceSize.width: l._proporcaoAnterior >= l._caixa ? width * 2 : -1
        sourceSize.height: l._proporcaoAnterior < l._caixa ? height * 2 : -1
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 1 - l._revelado
        visible: opacity > 0 && source != ""
    }

    Item {
        id: janela
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * l._revelado
        clip: true
        Image {
            id: img
            width: l._rec ? l._s * l.recorte.a : l.width
            height: l._rec ? l._s : l.height
            x: l._rec ? l.width / 2 - (l.recorte.x + l.recorte.w / 2) * width : 0
            y: l._rec ? l.height / 2 - (l.recorte.y + l.recorte.h / 2) * height : 0
            source: l.source
            sourceSize.width: l._rec || l.proporcao >= l._caixa ? width * 2 : -1
            sourceSize.height: !l._rec && l.proporcao < l._caixa ? height * 2 : -1
            fillMode: l._rec ? Image.Stretch : Image.PreserveAspectFit
            smooth: true
            layer.enabled: (l.brilho || l.tingir || l.realce > 0) && Tema.efeitos
            layer.effect: MultiEffect {
                colorization: l.tingir ? 1 : 0
                colorizationColor: l.cor
                brightness: (l.tingir ? 0.25 : 0) + l.realce * 0.45
                shadowEnabled: l.brilho || l.realce > 0
                shadowColor: Tema.alfa(l.cor, 0.85)
                shadowBlur: 0.6 + l.realce * 0.4
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 16
            }
        }
    }

    // linha de varredura na borda da revelação
    Rectangle {
        visible: l._revelado < 1
        width: parent.width + 16; x: -8
        height: 2
        y: janela.height - 1
        color: Tema.secundaria
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 8; color: Tema.alfa(Tema.secundaria, 0.18) }
    }

    onSourceChanged: {
        if (Tema.reduzir || !l.visible || !l.animarTroca) { _revelado = 1; _ultima = source; return }
        revelar.restart()
    }
    function revarrer() { if (!Tema.reduzir) revelar.restart() }

    property url _ultima
    property real _ultimaProporcao: 1
    onProporcaoChanged: _ultimaProporcao = proporcao
    Component.onCompleted: _ultima = source
    SequentialAnimation {
        id: revelar
        ScriptAction { script: { l._anterior = l._ultima; l._proporcaoAnterior = l._ultimaProporcao; l._ultima = l.source; l._revelado = 0 } }
        NumberAnimation { target: l; property: "_revelado"; from: 0; to: 1; duration: 460; easing.type: Easing.InOutQuad }
        ScriptAction { script: l._anterior = "" }
    }

    // varredura ociosa
    Rectangle {
        id: ociosa
        visible: false
        width: parent.width + 10; x: -5; height: 1
        color: Tema.alfa(Tema.secundaria, 0.7)
    }
    // disparada por Timer (não pede quadros em repouso, ao contrário de uma animação em laço)
    Timer {
        running: l.varreduraOciosa && !Tema.reduzir && l.visible
        interval: 12000
        repeat: true
        onTriggered: passagem.restart()
    }
    SequentialAnimation {
        id: passagem
        PropertyAction { target: ociosa; property: "visible"; value: true }
        NumberAnimation { target: ociosa; property: "y"; from: 0; to: l.height; duration: 700; easing.type: Easing.InOutSine }
        PropertyAction { target: ociosa; property: "visible"; value: false }
    }
}
