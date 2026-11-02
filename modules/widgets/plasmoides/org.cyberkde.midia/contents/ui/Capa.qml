import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "comum"

// Capa do álbum numa moldura chanfrada. Ao trocar de faixa, glitch curto (~420 ms): a imagem chega
// em fatias deslocadas com franjas de cor e assenta com flicker. Sem capa: emblema de onda.
Item {
    id: c
    property url fonte: ""
    property string chave: ""          // muda a cada faixa (dispara o glitch)
    property real g: 0                 // 1 = glitch máximo, 0 = parado
    readonly property real corte: Math.max(8, width * 0.1)

    function _r(i, k) { const s = Math.sin(i * 12.9898 + k * 78.233 + c._semente) * 43758.5453; return s - Math.floor(s) }
    property real _semente: 0
    onChaveChanged: {
        if (Cores.reduzir || !visible) return
        _semente = Math.random() * 100
        anim.restart()
    }
    NumberAnimation { id: anim; target: c; property: "g"; from: 1; to: 0; duration: Cores.d(420); easing.type: Easing.OutCubic }

    Chanfro { anchors.fill: parent; corte: c.corte; preenchimento: Cores.escuro; borda: "transparent" }

    // imagem recortada no formato chanfrado
    Item {
        id: arte
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Image {
            id: img
            anchors.fill: parent
            source: c.fonte
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(256, 256)
        }
        Item {
            visible: img.status !== Image.Ready
            anchors.fill: parent
            Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.42; height: width; source: "audio-x-generic"; isMask: true; color: Cores.alfa(Cores.destaque, 0.6) }
        }
    }
    Item {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Chanfro { anchors.fill: parent; corte: c.corte; preenchimento: "white"; borda: "transparent" }
    }
    MultiEffect {
        id: recortada
        anchors.fill: parent
        source: arte
        maskEnabled: true
        maskSource: mascara
        visible: c.g <= 0
    }

    // ---- glitch: franjas de cor e fatias
    Repeater {
        model: c.g > 0 ? 2 : 0
        MultiEffect {
            required property int index
            anchors.fill: parent
            source: arte
            maskEnabled: true; maskSource: mascara
            x: (index ? 1 : -1) * c.g * c.width * 0.06
            colorization: 1
            colorizationColor: index ? Cores.secundaria : Cores.destaque
            opacity: 0.7 * c.g
        }
    }
    ShaderEffectSource { id: fonteFatia; sourceItem: recortada; live: c.g > 0; hideSource: false; visible: false }
    Repeater {
        model: c.g > 0 ? 7 : 0
        Item {
            id: fatia
            required property int index
            readonly property real h: c.height / 7
            y: index * h; width: c.width; height: h + 1
            clip: true
            ShaderEffect {
                property variant source: fonteFatia
                y: -fatia.y
                x: (c._r(fatia.index, 1) - 0.5) * c.width * 0.5 * c.g * c.g
                width: c.width; height: c.height
            }
        }
    }
    opacity: g > 0.15 && g < 0.35 ? (Math.floor(g * 40) % 2 ? 0.45 : 1) : 1

    // moldura e cantoneiras
    Chanfro { anchors.fill: parent; corte: c.corte; preenchimento: "transparent"; borda: Cores.alfa(Cores.destaque, 0.7) }
    Rectangle { x: c.width - 18; y: 4; width: 14; height: 2; color: Cores.secundaria }
    Rectangle { x: 4; y: c.height - 6; width: 2; height: 2; color: Cores.destaque }
}
