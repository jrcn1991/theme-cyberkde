import QtQuick

// ▶ que toca uma prévia de som em volume baixo (painel.tocarSom, 30%); tocando, vira ■ e para.
// Nunca toca sozinho: só por clique (ou Espaço/Enter com foco).
Item {
    id: b
    property string arquivo: ""
    property string rotulo: ""
    readonly property bool tocando: arquivo !== "" && painel.somTocando === arquivo
    implicitWidth: rotulo !== "" ? linha.implicitWidth + 16 : 22
    implicitHeight: 22
    activeFocusOnTab: arquivo !== ""
    function acionar() { if (tocando) painel.pararSom(); else painel.tocarSom(arquivo) }
    Keys.onSpacePressed: acionar()
    Keys.onReturnPressed: acionar()

    Chanfro {
        anchors.fill: parent
        corte: 3
        preenchimento: b.tocando ? Tema.alfa(Tema.secundaria, 0.2) : (ma.containsMouse ? Tema.hover : Tema.entrada)
        borda: b.activeFocus ? Tema.secundaria : (b.tocando ? Tema.secundaria : Tema.linha)
        espessura: b.activeFocus ? 2 : 1
    }
    Row {
        id: linha
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: b.tocando ? "■" : "▶"
            font.pixelSize: 9
            color: b.tocando ? Tema.secundaria : Tema.texto2
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: b.rotulo !== ""
            text: b.rotulo
            font.family: Tema.fTexto; font.pixelSize: 11
            color: b.tocando ? Tema.texto : Tema.texto2
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.acionar() }
}
