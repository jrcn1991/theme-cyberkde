import QtQuick

// As cinco barras: medidas pelo espectro quando há; senão dançam só enquanto toca. Parado: baixas e sem laço.
Row {
    id: o
    property var tema
    property bool parado: false
    property var niveis: []
    property color cor: tema.tinta
    property real alturaMax: 14
    readonly property bool medido: !parado && niveis.length === 5
    readonly property bool dancar: !parado && !medido && !tema.reduzir
    spacing: 2
    height: alturaMax
    Repeater {
        model: 5
        Rectangle {
            id: b
            required property int index
            width: 3; radius: 1.5; color: o.cor
            anchors.bottom: parent.bottom
            property real f: 0.3
            height: o.alturaMax * (o.medido ? Math.max(0.1, o.niveis[index] || 0.1) : f)
            Behavior on height { enabled: o.medido; NumberAnimation { duration: 66 } }
            SequentialAnimation {
                running: o.dancar
                loops: Animation.Infinite
                onRunningChanged: if (!running) b.f = 0.3
                PauseAnimation { duration: 1 + b.index * 140 }
                NumberAnimation { target: b; property: "f"; to: 1; duration: 525; easing.type: Easing.InOutSine }
                NumberAnimation { target: b; property: "f"; to: 0.3; duration: 525; easing.type: Easing.InOutSine }
            }
        }
    }
}
