import QtQuick
import QtQuick.Window

// Janela do atalho "nova cerca" (app/cerca-nome.py): só o nome e a pasta que vai nascer.
Window {
    id: j
    width: 460; height: 168
    visible: true
    flags: Qt.Dialog | Qt.FramelessWindowHint
    color: "transparent"
    title: "Cyber Fence"
    readonly property color destaque: cerca.cores.destaque
    readonly property color fundo: cerca.cores.fundo
    readonly property color texto: "#E8E8F0"
    function t(pt, ing) { return cerca.en ? ing : pt }
    Component.onCompleted: { requestActivate(); campo.forceActiveFocus() }

    Canvas {
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d"), k = 14, w = width - 1, h = height - 1
            c.reset()
            c.beginPath(); c.moveTo(k, 0.5); c.lineTo(w, 0.5); c.lineTo(w, h - k); c.lineTo(w - k, h); c.lineTo(0.5, h); c.lineTo(0.5, k); c.closePath()
            c.fillStyle = j.fundo; c.fill()
            c.strokeStyle = j.destaque; c.lineWidth = 1; c.stroke()
        }
    }
    Rectangle { x: 0; y: 20; width: 3; height: 22; color: j.destaque }
    Column {
        x: 22; y: 18; width: parent.width - 44
        spacing: 10
        Text { text: "CYBER.FENCE // " + j.t("NOVA CERCA", "NEW FENCE"); color: j.destaque; font.family: "JetBrains Mono"; font.pixelSize: 12; font.letterSpacing: 1 }
        Rectangle {
            width: parent.width; height: 36
            color: "transparent"; border.color: j.destaque
            TextInput {
                id: campo
                anchors.fill: parent; anchors.margins: 9
                clip: true
                maximumLength: 120
                color: j.texto; selectionColor: j.destaque; selectedTextColor: j.fundo
                font.pixelSize: 15
                focus: true
                Keys.onReturnPressed: cerca.criar(text)
                Keys.onEnterPressed: cerca.criar(text)
                Keys.onEscapePressed: Qt.quit()
                Text { visible: !campo.text; anchors.verticalCenter: parent.verticalCenter; text: j.t("Nome da cerca", "Fence name"); color: "#8A8A99"; font: campo.font }
            }
        }
        Text {
            width: parent.width
            text: j.t("PASTA: ", "FOLDER: ") + cerca.pastaDe(campo.text)
            elide: Text.ElideMiddle
            color: "#B4B4C2"; font.pixelSize: 12
        }
        Text {
            width: parent.width
            text: cerca.erro || j.t("Enter cria · Esc cancela", "Enter creates · Esc cancels")
            elide: Text.ElideRight
            color: cerca.erro ? j.destaque : "#8A8A99"; font.pixelSize: 11
        }
    }
}
