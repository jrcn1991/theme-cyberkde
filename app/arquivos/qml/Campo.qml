import QtQuick
import "../../qml"

// Campo de texto de uma linha dos modais do DATASHARD (chanfrado; secundária no foco). "texto" segue
// o que se digita; Enter emite aceito(); Esc emite cancelado().
Item {
    id: c
    property alias texto: ent.text
    property string dica: ""
    property bool mono: false
    property alias entrada: ent
    signal aceito()
    signal cancelado()
    signal editado()
    implicitWidth: 240; implicitHeight: 28
    function focar() { ent.forceActiveFocus(); ent.selectAll() }
    Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.entrada; borda: ent.activeFocus ? Tema.secundaria : Tema.linha; espessura: ent.activeFocus ? 2 : 1 }
    TextInput {
        id: ent
        x: 8; width: parent.width - 16
        anchors.verticalCenter: parent.verticalCenter
        font.family: c.mono ? Tema.fMono : Tema.fTexto; font.pixelSize: 13
        color: Tema.texto; selectionColor: Tema.destaque; selectedTextColor: Tema.escuro
        selectByMouse: true; clip: true
        onAccepted: c.aceito()
        onTextEdited: c.editado()
        Keys.onEscapePressed: (e) => { c.cancelado(); e.accepted = true }
    }
    Text {
        x: 8; anchors.verticalCenter: parent.verticalCenter
        visible: !ent.text && !ent.activeFocus
        text: c.dica; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto3
    }
}
