// CyberKDE — grupo que entra na apresentação: opacidade + deslocamento curto (até 8 px).
// "t" é o relógio da apresentação (ms) vindo da raiz; "start" e "dur" situam o grupo na coreografia.
import QtQuick
import "."

Item {
    id: root

    property real t: 100000
    property real start: 0
    property real dur: 200
    property real dx: -8
    property real dy: 0

    readonly property real p: CK.ramp(t, start, dur)

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    // Só opacidade (sem "visible: false"): o campo de senha já pode receber o foco durante a apresentação.
    opacity: p
    transform: Translate { x: root.dx * (1 - root.p); y: root.dy * (1 - root.p) }
}
