import QtQuick
import org.kde.plasma.plasmoid

// Alça de arraste (seis pontos), só no modo de edição do Plasma. Ao passar o mouse por ela, o contêiner
// do applet entra no modo de mover, e o arraste que começa nela move o widget; ao sair sem arrastar
// (ou ao soltar), volta ao normal. Some fora do modo de edição, sem contêiner (barra, teste) ou com os
// widgets travados.
Item {
    id: a
    property var _c: null
    property bool _ligou: false
    readonly property bool _edicao: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode === true : false
    property bool permitido: true
    readonly property bool _ativa: permitido && _c !== null && !Plasmoid.immutable && _edicao
    Revelador { alvo: a; mostrar: a._ativa }
    implicitWidth: 14; implicitHeight: 18
    // a árvore de pais só fica completa depois de criada: procura em seguida e ao mudar de pai
    function _procurar() { if (!_c) _c = Cores.conteiner(a) }
    Component.onCompleted: Qt.callLater(_procurar)
    onParentChanged: Qt.callLater(_procurar)
    property int _tentativas: 0
    Timer { interval: 1000; running: a._c === null && a._tentativas < 5; repeat: true; onTriggered: { a._tentativas++; a._procurar() } }

    function _soltar() {
        if (_c && _ligou && !_c.dragActive && !ma.containsMouse) { _c.editMode = false; _ligou = false }
    }
    Connections {
        target: a._c
        ignoreUnknownSignals: true
        function onDragActiveChanged() { if (!a._c.dragActive) Qt.callLater(a._soltar) }
    }

    Grid {
        anchors.centerIn: parent
        columns: 2; spacing: 3
        Repeater {
            model: 6
            Rectangle { width: 2; height: 2; color: ma.containsMouse || (a._c && a._c.dragActive) ? Cores.destaque : Cores.texto3 }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent; anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.SizeAllCursor
        acceptedButtons: Qt.NoButton          // o clique passa para o contêiner, que arrasta
        onContainsMouseChanged: {
            if (!a._ativa) return
            if (containsMouse && !a._c.editMode) { a._c.editMode = true; a._ligou = true }
            else if (!containsMouse) Qt.callLater(a._soltar)
        }
    }
}
