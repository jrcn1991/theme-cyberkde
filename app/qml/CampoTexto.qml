import QtQuick

// Campo de texto livre de uma opção (tipo "texto" do CLI, ex.: a cidade do widget-clima). Enter ou
// "Aplicar" confirma; Esc desfaz. Enquanto o campo não está em edição, acompanha o valor do estado.
Row {
    id: ct
    property string valor: ""
    property string dica: ""
    property bool habilitado: true
    signal confirmado(string texto)
    spacing: 8

    readonly property bool alterado: campo.text.trim() !== ct.valor
    function confirmar() { if (ct.habilitado && ct.alterado) { ct.confirmado(campo.text.trim()); campo.focus = false } }
    onValorChanged: if (!campo.activeFocus) campo.text = valor
    Component.onCompleted: campo.text = valor

    Item {
        width: Math.min(320, ct.parent ? ct.parent.width - botao.width - 8 : 320); height: 32
        Chanfro { anchors.fill: parent; preenchimento: Tema.entrada; borda: campo.activeFocus ? Tema.secundaria : Tema.linha; espessura: campo.activeFocus ? 2 : 1 }
        TextInput {
            id: campo
            x: 10; width: parent.width - 20
            anchors.verticalCenter: parent.verticalCenter
            font.family: Tema.fTexto; font.pixelSize: 13
            color: Tema.texto
            selectByMouse: true
            clip: true
            readOnly: !ct.habilitado
            onAccepted: ct.confirmar()
            Keys.onEscapePressed: { text = ct.valor; focus = false }
            Text {
                visible: campo.text === "" && !campo.activeFocus
                text: ct.dica
                font: campo.font
                color: Tema.texto3
            }
        }
    }
    Botao {
        id: botao
        text: Txt.t("comum.aplicar"); tamanho: 12; implicitHeight: 32
        tipo: ct.alterado ? "primario" : "secundario"
        habilitado: ct.habilitado && ct.alterado
        onClicado: ct.confirmar()
    }
}
