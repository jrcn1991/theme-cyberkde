import QtQuick

// Controle deslizante do tema: trilho chanfrado com preenchimento, alça, rótulo e valor. Arrastar,
// clicar ou usar as setas (Shift: passo ×5). "padrao" > 0 mostra uma marca no valor padrão.
Item {
    id: d
    property string rotulo: ""
    property real de: 0
    property real ate: 100
    property real passo: 1
    property real valor: 0
    property real padrao: -1
    property string unidade: ""
    property string textoValor: Math.round(valor) + unidade
    property bool habilitado: true
    signal movido(real valor)       // a cada mudança (arraste)

    implicitWidth: 260
    implicitHeight: 44
    opacity: habilitado ? 1 : 0.45
    activeFocusOnTab: habilitado

    function _definir(x) {
        const v = Math.max(de, Math.min(ate, Math.round(x / passo) * passo))
        if (v !== valor) { valor = v; movido(v) }
    }
    Keys.onLeftPressed: (e) => _definir(valor - passo * (e.modifiers & Qt.ShiftModifier ? 5 : 1))
    Keys.onRightPressed: (e) => _definir(valor + passo * (e.modifiers & Qt.ShiftModifier ? 5 : 1))

    Row {
        spacing: 8
        Codigo { text: d.rotulo; tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: d.textoValor
            font.family: Tema.fIdentidade; font.pixelSize: 11; font.weight: Font.Bold
            color: Tema.destaque
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Item {
        id: trilho
        y: 22; width: parent.width; height: 14
        readonly property real f: (d.valor - d.de) / Math.max(0.0001, d.ate - d.de)
        Chanfro { anchors.fill: parent; corte: 4; preenchimento: Tema.entrada; borda: d.activeFocus ? Tema.secundaria : Tema.linha; espessura: d.activeFocus ? 2 : 1 }
        Rectangle { x: 2; y: 3; height: parent.height - 6; width: Math.max(0, (parent.width - 4) * trilho.f); color: Tema.alfa(Tema.destaque, 0.55) }
        Rectangle {
            visible: d.padrao >= d.de
            x: 2 + (parent.width - 4) * (d.padrao - d.de) / Math.max(0.0001, d.ate - d.de)
            y: -3; width: 1; height: parent.height + 6
            color: Tema.alfa(Tema.texto, 0.5)
        }
        Rectangle {
            x: Math.min(parent.width - width, Math.max(0, (parent.width - width) * trilho.f))
            y: -2; width: 8; height: parent.height + 4
            color: Tema.destaque
        }
        MouseArea {
            anchors.fill: parent; anchors.margins: -6
            enabled: d.habilitado
            cursorShape: Qt.PointingHandCursor
            function pegar(m) { d.forceActiveFocus(); d._definir(d.de + Math.max(0, Math.min(1, (m.x - 6) / trilho.width)) * (d.ate - d.de)) }
            onPressed: (m) => pegar(m)
            onPositionChanged: (m) => { if (pressed) pegar(m) }
        }
    }
}
