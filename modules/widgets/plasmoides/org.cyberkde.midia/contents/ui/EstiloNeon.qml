import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "comum"

// Estilo RÁDIO NEON (o rádio de mesa do jogo): visor com moldura de néon recortada (degrau à direita,
// ligada ao selo por um fio), que BRILHA (MultiEffect: blur forte na cor de destaque) e cintila de leve
// como tubo de néon, com uma "falha" ocasional; "NOW PLAYING" e o título passando em letreiro contínuo
// (direita → esquerda); equalizador de pontos que acompanha a música (o mesmo Espectro do jukebox); o selo
// redondo com a capa do álbum (sem capa: o dial "FM"); e a linha de néon embaixo com o reflexo.
// Movimento mínimo: sem cintilar e sem letreiro (o título corta com reticências).
Item {
    id: n
    property var r
    property bool compacto: false
    readonly property bool tem: r.tem
    readonly property bool calmo: Cores.reduzir
    readonly property color neon: Qt.lighter(r.corBarra, 1.35)
    readonly property color tubo: r.corBarra

    // ---- cintilar: 0,9–1 o tempo todo; de vez em quando, uma falha (apaga e volta em duas batidas)
    property real luz: 1
    Timer {
        interval: 80; repeat: true; running: n.visible && !n.calmo && !falha.running
        onTriggered: { if (Math.random() < 0.006) falha.start(); else n.luz = 0.9 + Math.random() * 0.1 }
    }
    SequentialAnimation {
        id: falha
        PropertyAction { target: n; property: "luz"; value: 0.18 }
        PauseAnimation { duration: 60 }
        PropertyAction { target: n; property: "luz"; value: 1 }
        PauseAnimation { duration: 70 }
        PropertyAction { target: n; property: "luz"; value: 0.4 }
        PauseAnimation { duration: 45 }
        PropertyAction { target: n; property: "luz"; value: 1 }
    }
    onCalmoChanged: if (calmo) { falha.stop(); luz = 1 }

    // ---- geometria
    readonly property real mg: compacto ? 6 : 12
    readonly property real hRef: compacto ? 0 : Math.max(10, height * 0.08)       // reflexo embaixo
    readonly property real dSelo: Math.min(height - hRef - mg * 2 - 8, width * (compacto ? 0.24 : 0.3))
    readonly property real visorL: mg
    readonly property real visorT: mg
    readonly property real visorR: width - dSelo - mg * 2.4
    readonly property real visorB: height - hRef - mg - 6
    readonly property real degrau: Math.min(18, (visorB - visorT) * 0.18)         // o recorte da direita

    // corpo do rádio
    Chanfro {
        anchors.fill: parent; anchors.bottomMargin: n.hRef
        corte: n.compacto ? 8 : 14
        preenchimento: Cores.alfa(Cores.mistura(Cores.cartao, n.tubo, 0.05), n.r.opac)
        borda: Cores.alfa(n.tubo, 0.25)
    }

    // ---- os tubos de néon, duas vezes: a primeira camada sai borrada (layer.effect MultiEffect, o brilho) e
    // a segunda, nítida, vai por cima.
    readonly property real tamLetreiro: compacto ? 15 : Math.min(26, height * 0.12)
    readonly property real yLetreiro: compacto ? visorT + 4 : visorT + 20
    readonly property real hLetreiro: Math.ceil(tamLetreiro * 1.3)
    Repeater {
        id: camadas
        model: 2                         // 0 = a fonte (oculta) do brilho; 1 = os tubos nítidos
        Item {
        required property int index
        anchors.fill: parent
        opacity: index === 1 ? n.luz : 0.95 * n.luz
        // a camada 0 sai só borrada (o brilho); a 1, nítida por cima
        layer.enabled: index === 0
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 1.0; blurMax: n.compacto ? 20 : 40; blurMultiplier: 0.8
            brightness: 0.25; saturation: 0.4
            autoPaddingEnabled: false
        }
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: n.neon; strokeWidth: n.compacto ? 1.6 : 2.2; fillColor: index === 1 ? Cores.alfa(n.tubo, 0.05) : "transparent"   // o borrão só dos tubos
                joinStyle: ShapePath.RoundJoin
                readonly property real c: 8
                startX: n.visorL + c; startY: n.visorT
                PathLine { x: n.visorR - 10; y: n.visorT }
                PathLine { x: n.visorR; y: n.visorT + 10 }
                PathLine { x: n.visorR; y: n.visorT + (n.visorB - n.visorT) * 0.42 }
                PathLine { x: n.visorR + n.degrau; y: n.visorT + (n.visorB - n.visorT) * 0.42 + n.degrau }
                PathLine { x: n.visorR + n.degrau; y: n.visorB - 8 }
                PathLine { x: n.visorR + n.degrau - 8; y: n.visorB }
                PathLine { x: n.visorL + 8; y: n.visorB }
                PathLine { x: n.visorL; y: n.visorB - 8 }
                PathLine { x: n.visorL; y: n.visorT + 8 }
                PathLine { x: n.visorL + 8; y: n.visorT }
            }
            // fio do visor até o selo
            ShapePath {
                strokeColor: n.neon; strokeWidth: 1.4; fillColor: "transparent"
                startX: n.visorR + n.degrau; startY: n.visorT + (n.visorB - n.visorT) * 0.7
                PathLine { x: selo.x - 2; y: n.visorT + (n.visorB - n.visorT) * 0.7 }
            }
            // a linha de néon embaixo do rádio
            ShapePath {
                strokeColor: n.neon; strokeWidth: n.compacto ? 1.4 : 2; fillColor: "transparent"
                startX: n.mg * 0.5; startY: n.height - n.hRef - 1
                PathLine { x: n.width - n.mg * 0.5; y: n.height - n.hRef - 1 }
            }
        }
        // o anel do selo
        Rectangle {
            x: selo.x - 3; y: selo.y - 3; width: selo.width + 6; height: width; radius: width / 2
            color: "transparent"; border.width: n.compacto ? 1.6 : 2.2; border.color: n.neon
        }
        // NOW PLAYING e o letreiro (o texto também brilha)
        Text {
            visible: !n.compacto
            x: n.visorL + 12; y: n.visorT + 6
            width: n.visorR - n.visorL - 24; horizontalAlignment: Text.AlignHCenter
            text: "NOW PLAYING"; font.family: Cores.fTitulo; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
            color: n.neon
        }
        Item {
            id: janelaLetreiro
            x: n.visorL + 10; y: n.yLetreiro
            width: n.visorR - n.visorL - 20; height: n.hLetreiro
            clip: true
            readonly property string texto: n.tem ? (n.r.player.track + (n.r.player.artist ? "  ·  " + n.r.player.artist : "")).toUpperCase() : n.r.t("SEM SINAL  ·  FM 88.9", "NO SIGNAL  ·  FM 88.9")
            readonly property bool rola: !n.calmo
            Row {
                id: faixa
                spacing: 40
                Text { id: tl; text: janelaLetreiro.texto; font.family: Cores.fTitulo; font.pixelSize: n.tamLetreiro; font.weight: Font.Bold; color: Qt.lighter(n.neon, 1.25)
                       width: janelaLetreiro.rola ? implicitWidth : janelaLetreiro.width; elide: janelaLetreiro.rola ? Text.ElideNone : Text.ElideRight }
                Text { visible: janelaLetreiro.rola; text: tl.text; font: tl.font; color: tl.color }
            }
            NumberAnimation {
                target: faixa; property: "x"
                running: janelaLetreiro.rola && n.visible
                from: 0; to: -(tl.implicitWidth + faixa.spacing)
                duration: Math.max(4000, (tl.implicitWidth + faixa.spacing) * 28)
                loops: Animation.Infinite
                onRunningChanged: if (!running) faixa.x = 0
            }
        }
    }
    }
    // reflexo da linha de baixo
    Rectangle {
        visible: n.hRef > 0
        y: n.height - n.hRef; width: parent.width; height: n.hRef
        opacity: 0.35 * n.luz
        gradient: Gradient {
            GradientStop { position: 0; color: Cores.alfa(n.neon, 0.35) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ---- o equalizador de pontos dentro do visor
    Equalizador {
        x: n.visorL + 10; y: n.yLetreiro + n.hLetreiro + (n.compacto ? 3 : 8)
        width: n.visorR - n.visorL - 20; height: n.visorB - y - (n.compacto ? 4 : 8)
        niveis: n.r.espectro.niveis
        pontos: true; rotulos: false; rotulosBaixo: !n.compacto && height > 70
        alturaSeg: n.compacto ? 2.5 : height > 80 ? 4 : 3; vaoSeg: n.compacto ? 1.5 : 2.5
        vaoBanda: 0.18
        cor: n.neon; corPico: Qt.lighter(n.neon, 1.4)
        opacity: 0.85 + 0.15 * n.luz
    }

    // ---- o selo: a capa do álbum em círculo (sem capa: o dial FM)
    Item {
        id: selo
        width: n.dSelo; height: width
        x: n.width - width - n.mg * 1.2; y: (n.height - n.hRef - height) / 2
        Image {
            id: capaSelo
            anchors.fill: parent
            source: n.tem ? (n.r.player.artUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }
        Rectangle { id: mascara; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect {
            anchors.fill: parent
            visible: capaSelo.status === Image.Ready
            source: capaSelo
            maskEnabled: true; maskSource: mascara
            opacity: 0.9
        }
        Column {
            visible: capaSelo.status !== Image.Ready
            anchors.centerIn: parent
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "FM"; font.family: Cores.fIdentidade; font.pixelSize: n.dSelo * 0.28; font.weight: Font.Bold; color: n.neon }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: n.tem ? n.r.nomePlayer.toUpperCase() : "88.9"; font.family: Cores.fMono; font.pixelSize: Math.max(8, n.dSelo * 0.11); color: Cores.texto2; width: n.dSelo * 0.8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        }
    }
    // ▶ no canto (tocar/pausar) e clique no visor faz o mesmo; roda = volume
    Text {
        visible: !n.compacto
        x: selo.x + selo.width - width; y: n.mg * 0.6
        text: n.r.tocando ? "❚❚" : "▶"; font.pixelSize: 13; color: n.neon
    }
    MouseArea {
        anchors.fill: parent
        enabled: n.tem
        cursorShape: Qt.PointingHandCursor
        onClicked: n.r.player.PlayPause()
        onWheel: (w) => n.r.player.changeVolume(w.angleDelta.y > 0 ? 0.05 : -0.05, false)
    }
}
