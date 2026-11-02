import QtQuick

// O anúncio: ícone + texto; o HUD é ícone + trilha, sem rótulo.
Row {
    id: an
    property var tema
    property var ev: ({})
    readonly property bool hud: ev.kind === "hud" && ev.ratio !== null && ev.ratio !== undefined
    readonly property color corNivel: ev.level === "alerta" ? tema.alerta : ev.level === "erro" ? tema.erro : tema.ok
    readonly property int nSeg: an.tema.segmentosBarra ?? 0
    spacing: 8
    Rectangle { visible: !!an.ev.color; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 5; color: an.ev.color || "transparent"; border.color: an.tema.bordaForte }
    Glifo { visible: !an.ev.color; anchors.verticalCenter: parent.verticalCenter; tamanho: 16; nome: an.ev.icon || "Bell"; cor: an.corNivel }
    Item {
        visible: an.hud
        anchors.verticalCenter: parent.verticalCenter
        width: 120; height: 4
        Rectangle { anchors.fill: parent; radius: 2; color: an.tema.trilha }
        Rectangle {
            height: 4; radius: 2
            color: an.ev.level === "alerta" ? an.tema.alerta : an.tema.texto
            visible: !an.nSeg
            width: 120 * Math.max(0, Math.min(1, an.ev.ratio || 0))
            Behavior on width { NumberAnimation { duration: 180 } }
        }
        // chanfrado: segmentos, como as barras do tema
        Row {
            visible: an.nSeg > 0
            spacing: 2
            Repeater { model: an.nSeg; Rectangle { required property int index; width: (120 - 2 * (an.nSeg - 1)) / an.nSeg; height: 4; color: index < Math.round((an.ev.ratio || 0) * an.nSeg) ? (an.ev.level === "alerta" ? an.tema.alerta : an.tema.texto) : an.tema.trilha } }
        }
    }
    Text { visible: an.hud; anchors.verticalCenter: parent.verticalCenter; text: Math.round((an.ev.ratio || 0) * 100) + "%"; color: an.tema.texto; font.family: an.tema.fonteMono; font.pixelSize: 12; width: 34; horizontalAlignment: Text.AlignRight }
    Text { visible: !an.hud; anchors.verticalCenter: parent.verticalCenter; text: an.ev.text || ""; width: Math.min(implicitWidth, 200); elide: Text.ElideRight; color: an.tema.texto; font.family: an.tema.fonte; font.pixelSize: 13; font.weight: Font.DemiBold }
    Text { visible: !an.hud && !!an.ev.detail; anchors.verticalCenter: parent.verticalCenter; text: an.ev.detail || ""; width: Math.min(implicitWidth, 150); elide: Text.ElideRight; color: an.tema.texto2; font.family: an.tema.fonte; font.pixelSize: 13 }
}
