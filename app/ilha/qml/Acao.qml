import QtQuick

// Botão de ícone (.acao do Halo): 28×26.
Item {
    id: b
    property var ui
    property string glifo: "Circle"
    property int tamanho: 14
    property bool cheio: false
    property bool ativa: false
    property bool pendente: false
    property string dica: ""
    signal clicado()
    HoverHandler { onHoveredChanged: if (b.ui && b.dica) b.ui.pedirDica(hovered ? b.dica : "", b) }
    width: 28; height: 26
    opacity: pendente ? 0.5 : 1
    Rectangle {
        anchors.fill: parent; radius: 8
        color: b.ativa ? b.ui.tema.acaoFraca : (m.containsMouse ? b.ui.tema.ativo : "transparent")
        Behavior on color { ColorAnimation { duration: b.ui.tema.reduzir ? 0 : 200 } }
    }
    Glifo { anchors.centerIn: parent; nome: b.glifo; tamanho: b.tamanho; cheio: b.cheio; cor: b.ativa ? b.ui.tema.acao : b.ui.tema.texto2 }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
}
