import QtQuick
import org.kde.kirigami as Kirigami

// Botão quadrado chanfrado com ícone (nome de ícone do tema) ou glifo; "ativo" acende no destaque.
Item {
    id: b
    property string icone: ""
    property string glifo: ""
    property bool ativo: false
    property bool habilitado: true
    property string dica: ""
    property real tamanho: 26
    signal clicado()
    implicitWidth: tamanho; implicitHeight: tamanho
    opacity: habilitado ? 1 : 0.4
    activeFocusOnTab: habilitado
    Keys.onSpacePressed: if (habilitado) clicado()
    Keys.onReturnPressed: if (habilitado) clicado()
    readonly property bool _hover: ma.containsMouse && habilitado
    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Cores.d(60) } }
    Chanfro {
        anchors.fill: parent
        corte: 4
        preenchimento: b.ativo ? Cores.alfa(Cores.destaque, 0.22) : (b._hover ? Cores.alfa(Cores.destaque, 0.12) : Cores.alfa(Cores.elevado, 0.8))
        borda: b.activeFocus ? Cores.secundaria : (b.ativo || b._hover ? Cores.destaque : Cores.linha)
        espessura: b.activeFocus ? 2 : 1
    }
    Kirigami.Icon {
        visible: b.icone !== ""
        anchors.centerIn: parent
        width: Math.round(b.tamanho * 0.58); height: width
        source: b.icone
        color: b.ativo ? Cores.destaque : Cores.texto
        isMask: true
    }
    Text {
        visible: b.glifo !== ""
        anchors.centerIn: parent
        text: b.glifo
        font.pixelSize: Math.round(b.tamanho * 0.45)
        font.bold: true
        color: b.ativo ? Cores.destaque : Cores.texto
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.habilitado) b.clicado() }
}
