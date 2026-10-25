import QtQuick

// Interruptor com resposta mecânica: a trava cede ao apertar (60 ms), corre com um pequeno
// sobressalto (OutBack) e os segmentos do trilho acendem em sequência. "ocupado" faz a trava pulsar
// enquanto o CLI trabalha; "ligado: null" é estado desconhecido (CLI sem suporte), trava no meio.
Item {
    id: s
    property var ligado: false          // true | false | null (desconhecido)
    property bool ocupado: false
    property bool habilitado: true
    property color cor: Tema.destaque
    signal alternado(bool novo)

    implicitWidth: 64
    implicitHeight: 28
    opacity: habilitado ? 1 : 0.4
    activeFocusOnTab: habilitado

    readonly property bool _on: ligado === true
    readonly property bool _desconhecido: ligado !== true && ligado !== false

    function _acionar() { if (habilitado && !ocupado) s.alternado(!_on) }
    Keys.onPressed: (e) => { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { _acionar(); e.accepted = true } }

    // trilho
    Chanfro {
        id: trilho
        anchors.fill: parent
        corte: 5
        preenchimento: s._on ? Tema.alfa(s.cor, 0.14) : Tema.entrada
        borda: s.activeFocus ? Tema.secundaria : (s._on ? s.cor : (area.containsMouse ? Tema.texto3 : Tema.linha))
        espessura: s.activeFocus ? 2 : 1
        Behavior on preenchimento { ColorAnimation { duration: Tema.rapido } }
        Behavior on borda { ColorAnimation { duration: Tema.micro } }
    }

    // segmentos do lado ligado: acendem em sequência
    Row {
        id: segs
        x: 7; anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 3; height: 10
                color: s._on ? s.cor : Tema.linha
                opacity: s._on ? 1 : 0.6
                Behavior on color {
                    SequentialAnimation {
                        PauseAnimation { duration: Tema.reduzir ? 0 : (s._on ? index * 26 : (4 - index) * 18) }
                        ColorAnimation { duration: Tema.micro }
                    }
                }
            }
        }
    }
    Codigo {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right; anchors.rightMargin: 8
        text: Txt.t("comum.off")
        tamanho: 9
        visible: !s._on && !s._desconhecido
        color: Tema.texto3
    }

    // trava
    Item {
        id: trava
        width: 24; height: 20
        anchors.verticalCenter: parent.verticalCenter
        x: s._desconhecido ? (s.width - width) / 2 : (s._on ? s.width - width - 4 : 4)
        Behavior on x { NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        scale: area.pressed ? 0.86 : 1
        Behavior on scale { NumberAnimation { duration: Tema.press } }

        Chanfro {
            anchors.fill: parent
            corte: 4
            preenchimento: s._on ? s.cor : (s._desconhecido ? Tema.elevado : Tema.texto3)
            borda: s._on ? Qt.lighter(s.cor, 1.2) : Tema.texto3
            Behavior on preenchimento { ColorAnimation { duration: Tema.rapido } }
        }
        // ranhuras de pegada
        Row {
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: 3
                Rectangle { width: 1; height: 8; color: s._on ? Tema.escuro : Tema.base; opacity: 0.8 }
            }
        }
        Text {
            visible: s._desconhecido
            anchors.centerIn: parent
            text: "?"
            font.family: Tema.fIdentidade; font.pixelSize: 11; font.bold: true
            color: Tema.texto2
        }
        SequentialAnimation on opacity {
            running: s.ocupado && !Tema.reduzir
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.35; duration: 260 }
            NumberAnimation { to: 1; duration: 260 }
        }
    }

    // estalo: um clarão curto no trilho quando muda
    Chanfro {
        id: estalo
        anchors.fill: parent
        corte: 5
        preenchimento: s.cor
        espessura: 0
        opacity: 0
    }
    on_OnChanged: if (!Tema.reduzir) flash.restart()
    NumberAnimation { id: flash; target: estalo; property: "opacity"; from: 0.35; to: 0; duration: 220; easing.type: Easing.OutQuad }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: s.habilitado && !s.ocupado ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: s._acionar()
    }
}
