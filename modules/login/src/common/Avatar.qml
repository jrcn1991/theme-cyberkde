// CyberKDE — avatar quadrado com canto chanfrado; sem foto, mostra a inicial (ou um ícone genérico).
import QtQuick
import QtQuick.Shapes
import "."

Item {
    id: root

    property string source: ""
    property string name: ""
    property bool generic: false
    property color cutColor: CK.panel     // cor do painel por trás, para "cortar" o canto da foto

    implicitWidth: 56
    implicitHeight: 56

    Rectangle { anchors.fill: parent; color: CK.raised }

    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 1
        source: root.generic ? "" : root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        smooth: true
        asynchronous: false
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: !root.generic && img.status !== Image.Ready
        text: (root.name || "?").charAt(0).toUpperCase()
        color: CK.txt1
        font.family: CK.fontUi
        font.pixelSize: 24
        font.weight: Font.Medium
    }

    CyberIcon {
        anchors.centerIn: parent
        visible: root.generic
        name: "user"
        width: 26
        height: 26
        color: CK.txt2
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            fillColor: root.cutColor
            strokeColor: "transparent"
            startX: root.width - 10; startY: -1
            PathLine { x: root.width + 1; y: -1 }
            PathLine { x: root.width + 1; y: 10 }
            PathLine { x: root.width - 10; y: -1 }
        }
    }

    Chamfer { anchors.fill: parent; borderColor: CK.controlLine; tr: 10 }
    Rectangle { x: 0; y: parent.height - 2; width: 12; height: 2; color: CK.red }
}
