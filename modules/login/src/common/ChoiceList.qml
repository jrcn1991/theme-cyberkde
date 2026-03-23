// CyberKDE — lista de escolha (usuário, sessão): superfície chanfrada que se revela a partir do
// acionador (6 px, 140 ms). Item escolhido: marcador ciano; item em destaque: faixa vermelha a 20%.
// Teclado: ↑/↓ movem, Enter escolhe, Esc fecha.
import QtQuick
import "."

FocusScope {
    id: root

    property var entries: []
    property int currentIndex: 0
    property string title: ""
    property bool open: false
    property int hi: 0
    signal chosen(int index)
    signal dismissed()

    width: 300
    height: col.implicitHeight + 16
    z: 50
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: CK.dur(CK.fast); easing.type: Easing.OutCubic } }
    transform: Translate {
        y: root.open ? 0 : 6
        Behavior on y { NumberAnimation { duration: CK.dur(CK.fast); easing.type: Easing.OutCubic } }
    }

    onOpenChanged: {
        if (open) {
            hi = currentIndex
            forceActiveFocus()
        }
    }

    Chamfer {
        anchors.fill: parent
        fillColor: CK.raised
        borderColor: CK.alpha(CK.red, 0.6)
        tr: CK.chamferButton
    }
    Rectangle { width: CK.markerWidth; height: parent.height; color: CK.red }

    Column {
        id: col
        x: CK.markerWidth + 6
        y: 8
        width: root.width - x - 8

        Text {
            visible: root.title !== ""
            text: root.title
            color: CK.txt2
            font.family: CK.fontUi
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.6
            leftPadding: 10
            bottomPadding: 6
            topPadding: 2
        }

        Repeater {
            model: root.entries
            Item {
                width: col.width
                height: 36
                Rectangle {
                    anchors.fill: parent
                    color: index === root.hi ? CK.alpha(CK.red, CK.selected)
                                             : (ma.containsMouse ? CK.alpha(CK.txt1, 0.06) : "transparent")
                    Behavior on color { ColorAnimation { duration: CK.dur(CK.micro) } }
                }
                Rectangle {
                    width: 2
                    height: parent.height
                    color: CK.cyan
                    visible: index === root.currentIndex
                }
                Text {
                    x: 12
                    width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    elide: Text.ElideRight
                    color: CK.txt1
                    font.family: CK.fontUi
                    font.pixelSize: 15
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hi = index
                    onClicked: root.chosen(index)
                }
            }
        }
    }

    Keys.onUpPressed: hi = Math.max(0, hi - 1)
    Keys.onDownPressed: hi = Math.min(entries.length - 1, hi + 1)
    Keys.onReturnPressed: chosen(hi)
    Keys.onEnterPressed: chosen(hi)
    Keys.onEscapePressed: dismissed()
}
