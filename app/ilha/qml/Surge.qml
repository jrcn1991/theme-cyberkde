import QtQuick

// A entrada em cascata (.cascata do Halo), uma vez, ao nascer. Com "reduzir", nada.
Item {
    id: s
    property int ordem: 0
    property var ui
    default property alias conteudo: dentro.data
    implicitHeight: dentro.childrenRect.height
    implicitWidth: dentro.childrenRect.width
    Item { id: dentro; anchors.fill: parent }
    opacity: ui.tema.reduzir ? 1 : 0
    transform: Translate { id: tr; y: s.ui.tema.reduzir ? 0 : 6 }
    Component.onCompleted: if (!ui.tema.reduzir) an.start()
    SequentialAnimation {
        id: an
        PauseAnimation { duration: 30 * s.ordem }
        ParallelAnimation {
            NumberAnimation { target: s; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: tr; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
    }
}
