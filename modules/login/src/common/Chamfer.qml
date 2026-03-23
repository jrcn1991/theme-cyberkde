// CyberKDE — peça chanfrada (preenchimento + contorno de 1 px) usada em painéis, campos e botões.
// Os cantos cortados são a 45°; cada canto recebe o tamanho do corte em px (0 = canto reto).
import QtQuick
import QtQuick.Shapes
import "."

Item {
    id: root

    property color fillColor: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 1
    property real tl: 0
    property real tr: 0
    property real br: 0
    property real bl: 0

    // O traço fica todo por dentro da peça (meio traço de recuo), para o filete sair nítido.
    readonly property real h: borderWidth > 0 ? borderWidth / 2 : 0

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            startX: root.h + root.tl; startY: root.h
            PathLine { x: root.width - root.h - root.tr; y: root.h }
            PathLine { x: root.width - root.h; y: root.h + root.tr }
            PathLine { x: root.width - root.h; y: root.height - root.h - root.br }
            PathLine { x: root.width - root.h - root.br; y: root.height - root.h }
            PathLine { x: root.h + root.bl; y: root.height - root.h }
            PathLine { x: root.h; y: root.height - root.h - root.bl }
            PathLine { x: root.h; y: root.h + root.tl }
            PathLine { x: root.h + root.tl; y: root.h }
        }
    }
}
