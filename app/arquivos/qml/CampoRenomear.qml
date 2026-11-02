import QtQuick
import "../../qml"

// Campo de renomear no lugar (F2): seleciona o nome sem a extensão; Enter confirma
// (arquivos.renomear), Esc cancela. Erros voltam como aviso e o campo continua aberto.
Item {
    id: c
    property bool ativo: false
    property string nome: ""
    property string caminho: ""
    Rectangle { anchors.fill: parent; color: Tema.entrada; border.color: Tema.secundaria; border.width: 1 }
    TextInput {
        id: campo
        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
        verticalAlignment: TextInput.AlignVCenter
        font.family: Tema.fTexto; font.pixelSize: 13
        color: Tema.texto
        selectionColor: Tema.alfa(Tema.destaque, 0.5)
        selectedTextColor: Tema.texto
        clip: true
        Keys.onEscapePressed: Ds.janela.fimRenomear()
        onAccepted: Ds.janela.confirmarRenomear(c.caminho, text)
    }
    onAtivoChanged: if (ativo) {
        campo.text = nome
        campo.forceActiveFocus()
        const p = nome.lastIndexOf(".")
        campo.select(0, p > 0 ? p : nome.length)
    }
}
