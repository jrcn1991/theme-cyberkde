// CyberKDE — botão chanfrado (canto inferior direito). Repouso: contorno vermelho a 35%;
// hover: preenchimento a 10%; pressionado: 30%; principal: vermelho a 24%. Foco pelo teclado: anel ciano.
// Com "busy", mostra uma barra segmentada correndo na base do botão.
import QtQuick
import "."

FocusScope {
    id: root

    property string text: ""
    property string icon: ""
    property string trailing: ""
    property bool primary: false
    property bool busy: false
    property bool compact: false
    property bool alignLeft: false
    property int chamfer: CK.chamferButton
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool down: mouse.pressed
    readonly property real pad: compact ? 12 : 18

    activeFocusOnTab: true
    implicitHeight: compact ? 32 : 44
    // largura natural a partir do texto (sem depender da largura do próprio botão, que cria laço)
    implicitWidth: (icon !== "" ? (compact ? 14 : 18) + row.spacing : 0) + label.implicitWidth
                   + (trailing !== "" ? 14 + row.spacing : 0) + 2 * pad
    opacity: enabled ? 1 : 0.45

    Chamfer {
        anchors.fill: parent
        br: root.chamfer
        fillColor: CK.alpha(CK.raised, 0.92)
    }
    Chamfer {
        anchors.fill: parent
        br: root.chamfer
        fillColor: CK.alpha(CK.red, root.down ? CK.pressed
                                   : root.primary ? (root.hovered ? 0.34 : 0.24)
                                   : (root.hovered ? CK.hover : 0))
        borderColor: root.primary || root.hovered ? CK.red : CK.alpha(CK.red, CK.brand)
        Behavior on fillColor { ColorAnimation { duration: CK.dur(CK.micro) } }
        Behavior on borderColor { ColorAnimation { duration: CK.dur(CK.micro) } }
    }

    // anel de foco
    Chamfer {
        anchors.fill: parent
        anchors.margins: -3
        br: root.chamfer + 1
        borderWidth: CK.focusWidth
        borderColor: CK.cyan
        visible: root.activeFocus
    }

    // atividade verdadeira (login em andamento)
    Row {
        id: busyBar
        property int step: 0
        visible: root.busy
        x: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        spacing: 3
        Repeater {
            model: 10
            Rectangle {
                width: (root.width - 20 - 27) / 10
                height: 2
                color: index === busyBar.step ? CK.cyan : CK.alpha(CK.txt1, 0.18)
            }
        }
        Timer {
            interval: 70
            repeat: true
            running: root.busy && CK.factor > 0
            onTriggered: busyBar.step = (busyBar.step + 1) % 10
        }
    }

    Row {
        id: row
        x: root.alignLeft ? root.pad : (root.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        CyberIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== "" && !root.busy
            name: root.icon
            color: CK.txt1
            width: root.compact ? 14 : 18
            height: width
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: CK.txt1
            font.family: CK.fontUi
            font.pixelSize: root.compact ? 13 : 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - 2 * root.pad
                            - (root.icon !== "" ? 28 : 0) - (root.trailing !== "" ? 24 : 0))
        }
        CyberIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing !== ""
            name: root.trailing
            color: CK.txt2
            width: 14
            height: 14
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
