import QtQuick
import QtQuick.Shapes

// Botão grande de energia: anel de 40 segmentos que acendem em sequência ao ligar e apagam ao
// desligar; durante uma operação, um cometa ciano gira pelo anel. Centro com o símbolo de energia.
Item {
    id: a
    property bool ligado: false
    property bool ocupado: false
    property color cor: Tema.destaque
    signal acionado()

    implicitWidth: 230; implicitHeight: 230
    readonly property int n: 40
    property real nivel: ligado ? n : 0
    Behavior on nivel { NumberAnimation { duration: Tema.reduzir ? 0 : 700; easing.type: Easing.OutCubic } }
    property int cometa: 0
    activeFocusOnTab: true
    Keys.onReturnPressed: acionado()
    Keys.onSpacePressed: acionado()

    Timer {
        running: a.ocupado && a.visible
        interval: Tema.reduzir ? 250 : 28
        repeat: true
        onTriggered: a.cometa = (a.cometa + 1) % a.n
    }

    // anel externo fino com marcas
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Tema.linha; strokeWidth: 1; fillColor: "transparent"
            PathAngleArc { centerX: a.width / 2; centerY: a.height / 2; radiusX: a.width / 2 - 1; radiusY: a.height / 2 - 1; startAngle: -80; sweepAngle: 340 }
        }
        ShapePath {
            strokeColor: Tema.alfa(a.cor, 0.6); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: a.width / 2; centerY: a.height / 2; radiusX: a.width / 2 - 1; radiusY: a.height / 2 - 1; startAngle: -100; sweepAngle: 20 }
        }
    }

    Repeater {
        model: a.n
        Item {
            required property int index
            anchors.fill: parent
            rotation: index * 360 / a.n
            readonly property bool aceso: index < a.nivel
            readonly property int dist: (a.cometa - index + a.n) % a.n
            Rectangle {
                x: a.width / 2 - width / 2
                y: 10
                width: 5; height: 18
                antialiasing: true
                color: a.ocupado && parent.dist < 6 ? Tema.alfa(Tema.secundaria, 1 - parent.dist / 6)
                     : parent.aceso ? a.cor : Tema.alfa(a.cor, 0.10)
            }
        }
    }

    // núcleo
    Item {
        id: nucleo
        anchors.centerIn: parent
        width: a.width - 76; height: width
        scale: area.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: Tema.press } }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: area.containsMouse ? Tema.alfa(a.cor, a.ligado ? 0.22 : 0.10) : Tema.alfa(a.cor, a.ligado ? 0.14 : 0.04)
            border.color: a.activeFocus ? Tema.secundaria : (a.ligado ? a.cor : Tema.linha)
            border.width: a.activeFocus ? 2 : 1
            Behavior on color { ColorAnimation { duration: Tema.micro } }
        }
        // símbolo de energia
        Shape {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12
            width: 52; height: 52
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: a.ligado ? a.cor : Tema.texto3; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: 26; centerY: 28; radiusX: 21; radiusY: 21; startAngle: -55; sweepAngle: 290 }
            }
            ShapePath {
                strokeColor: a.ligado ? a.cor : Tema.texto3; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: 26; startY: 0
                PathLine { x: 26; y: 26 }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            text: a.ocupado ? "· · ·" : (a.ligado ? Txt.t("estado.online") : Txt.t("estado.offline"))
            font.family: Tema.fIdentidade; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 2
            color: a.ligado ? a.cor : Tema.texto2
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: a.ocupado ? Qt.BusyCursor : Qt.PointingHandCursor
            onClicked: if (!a.ocupado) a.acionado()
        }
    }
}
