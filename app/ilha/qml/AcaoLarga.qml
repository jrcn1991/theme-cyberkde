import QtQuick

// Botão com rótulo (.acaoLarga do Halo).
Item {
    id: b
    property var ui
    property string glifo: ""
    property string texto: ""
    property bool ativa: false
    property bool pendente: false
    signal clicado()
    property string dica: ""
    HoverHandler { onHoveredChanged: if (b.ui && b.dica) b.ui.pedirDica(hovered ? b.dica : "", b) }
    width: l.implicitWidth + 20; height: 28
    opacity: pendente ? 0.5 : 1
    Rectangle { anchors.fill: parent; radius: b.ui.tema.raioControle; color: b.ativa ? b.ui.tema.acaoFraca : (m.containsMouse ? b.ui.tema.ativo : b.ui.tema.hover) }
    Row {
        id: l
        anchors.centerIn: parent; spacing: 6
        Glifo { visible: b.glifo !== ""; nome: b.glifo; tamanho: 12; cor: b.ui.tema.texto2; anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.texto; color: b.ui.tema.texto; font.family: b.ui.tema.fonte; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
}
