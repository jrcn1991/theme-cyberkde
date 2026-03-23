// CyberKDE — varredura ciano de cima para baixo (acento breve): filete, rastro e separação de cor.
// "progress" de 0 a 1; fora desse intervalo não desenha nada.
import QtQuick
import "."

Item {
    id: root

    property real progress: -1
    property color color: CK.cyan

    readonly property real yy: Math.max(0, Math.min(1, progress)) * height

    clip: true
    visible: progress > 0 && progress < 1

    Rectangle {
        width: parent.width
        height: 40
        y: root.yy - height
        gradient: Gradient {
            GradientStop { position: 0.0; color: CK.alpha(root.color, 0) }
            GradientStop { position: 1.0; color: CK.alpha(root.color, 0.14) }
        }
    }
    Rectangle { width: parent.width; height: 1; y: root.yy; color: root.color; opacity: 0.85 }
    Rectangle { width: parent.width; height: 1; y: root.yy + 2; color: CK.red; opacity: 0.35 }
    Rectangle { x: 0; y: root.yy - 1; width: 18; height: 3; color: root.color }
    Rectangle { x: parent.width - width; y: root.yy - 1; width: 18; height: 3; color: root.color }
}
