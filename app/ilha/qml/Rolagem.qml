import QtQuick

// Área dos painéis: até 404 de altura; o que passa rola. Desliza ao trocar de aba.
Flickable {
    id: f
    property var ui
    default property alias conteudo: col.data
    property alias coluna: col
    implicitHeight: Math.min(ui.alturaMaxPainel, contentHeight)
    contentWidth: width
    contentHeight: col.implicitHeight + 24
    clip: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    Column {
        id: col
        x: 16; y: 4
        width: f.width - 32
        spacing: 8
    }
    opacity: ui.tema.reduzir ? 1 : 0
    transform: Translate { id: tr; x: f.ui.tema.reduzir ? 0 : (f.ui.direcao === "dir" ? 16 : -16) }
    Component.onCompleted: if (!ui.tema.reduzir) an.start()
    ParallelAnimation {
        id: an
        NumberAnimation { target: f; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: tr; property: "x"; to: 0; duration: 300; easing.type: Easing.OutCubic }
    }
}
