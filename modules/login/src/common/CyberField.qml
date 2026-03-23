// CyberKDE — campo de texto: contorno fino neutro, foco ciano (contorno + marcador + halo curto),
// vermelho quando há erro. Usa TextInput puro para não depender de estilos do Qt Quick Controls.
import QtQuick
import "."

FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    property bool error: false
    signal accepted()

    readonly property bool focused: input.activeFocus
    readonly property color accent: error ? CK.danger : CK.cyan

    implicitWidth: 320
    implicitHeight: 46
    opacity: enabled ? 1 : 0.55

    // halo de 3 px, só no foco ou no erro
    Chamfer {
        anchors.fill: parent
        anchors.margins: -3
        br: CK.chamferButton + 1
        borderColor: CK.alpha(root.accent, 0.28)
        opacity: root.focused || root.error ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: CK.dur(CK.micro) } }
    }

    Chamfer {
        anchors.fill: parent
        br: CK.chamferButton
        fillColor: CK.input
        borderColor: root.error ? CK.danger : (root.focused ? CK.cyan : CK.controlLine)
        Behavior on borderColor { ColorAnimation { duration: CK.dur(CK.micro) } }
    }

    // marcador lateral
    Rectangle {
        x: 0
        y: 0
        width: 2
        height: parent.height
        color: root.accent
        opacity: root.focused || root.error ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: CK.dur(CK.micro) } }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        verticalAlignment: TextInput.AlignVCenter
        color: CK.txt1
        selectionColor: CK.alpha(CK.cyan, 0.35)
        selectedTextColor: CK.txt1
        font.family: CK.fontUi
        font.pixelSize: 16
        font.letterSpacing: root.password && text.length > 0 ? 2 : 0
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        passwordMaskDelay: 0
        clip: true
        focus: true
        activeFocusOnTab: true
        selectByMouse: true
        onAccepted: root.accepted()
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 16
        width: parent.width - 32
        elide: Text.ElideRight
        text: root.placeholder
        color: CK.txtd
        font.family: CK.fontUi
        font.pixelSize: 16
        visible: input.text.length === 0 && input.preeditText.length === 0
    }
}
