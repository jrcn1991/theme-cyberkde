import QtQuick

// Botão chanfrado. tipo: "primario" (preenchido no destaque, texto escuro), "secundario" (contorno)
// ou "sutil" (só texto e filete). Hover 80 ms, pressão 60 ms, foco por teclado com anel ciano.
Item {
    id: b
    property string text: ""
    property string icone: ""             // um caractere/glifo opcional à esquerda
    property string tipo: "secundario"
    property color cor: Tema.destaque
    property bool habilitado: true
    property int tamanho: 14
    signal clicado()

    implicitWidth: Math.max(96, linha.implicitWidth + 32)
    implicitHeight: 34
    opacity: habilitado ? 1 : 0.42
    activeFocusOnTab: habilitado

    readonly property bool _hover: area.containsMouse && habilitado
    readonly property bool _press: area.pressed && habilitado

    Keys.onPressed: (e) => {
        if (habilitado && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) {
            b.clicado(); e.accepted = true
        }
    }

    scale: _press ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Tema.press } }

    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfro
        preenchimento: b.tipo === "primario"
            ? (b._press ? Qt.darker(b.cor, 1.25) : b._hover ? Qt.lighter(b.cor, 1.12) : b.cor)
            : (b._press ? Tema.alfa(b.cor, 0.30) : b._hover ? Tema.alfa(b.cor, 0.12) : (b.tipo === "sutil" ? "transparent" : Tema.alfa(b.cor, 0.04)))
        borda: b.tipo === "primario" ? b.cor : (b._hover ? b.cor : Tema.alfa(b.cor, b.tipo === "sutil" ? 0.0 : 0.55))
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
        Behavior on borda { ColorAnimation { duration: Tema.micro } }
    }
    // marcador inferior no estilo "sutil"
    Rectangle {
        visible: b.tipo === "sutil"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
        height: 1
        color: b._hover ? b.cor : Tema.alfa(b.cor, 0.35)
    }
    // anel de foco por teclado
    Chanfro {
        visible: b.activeFocus
        anchors.fill: parent
        anchors.margins: -3
        corte: Tema.chanfro + 1
        preenchimento: "transparent"
        borda: Tema.secundaria
        espessura: 2
    }

    Row {
        id: linha
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: b.icone !== ""
            text: b.icone
            font.pixelSize: b.tamanho + 1
            color: rot.color
            anchors.verticalCenter: parent.verticalCenter
        }
        Rotulo {
            id: rot
            text: b.text
            tamanho: b.tamanho + 1
            color: b.tipo === "primario" ? Tema.escuro : (b._hover ? Tema.texto : Tema.mistura(Tema.texto, b.cor, 0.25))
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: b.habilitado ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.habilitado) b.clicado()
    }
}
