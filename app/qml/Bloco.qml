import QtQuick

// Painel com moldura chanfrada, marcador lateral, código e título curtos.
Item {
    id: b
    property string titulo: ""
    property string codigo: ""
    property color cor: Tema.destaque
    property real preenchimentoAlfa: 0.92
    property bool destaque: false
    property real margem: 20
    default property alias conteudo: area.data
    property alias area: area
    property alias extra: extra.data

    // montagem (ver Cascata): moldura traçada, superfície, conteúdo acendendo, flash da borda
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0

    implicitHeight: area.y + area.implicitHeight + margem

    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfroG
        preenchimento: Tema.alfa(Tema.painel, b.preenchimentoAlfa)
        borda: b.destaque ? Tema.alfa(b.cor, 0.6) : Tema.linha
        Behavior on borda { ColorAnimation { duration: Tema.micro } }
        traco: b.traco; superficie: b.superficie; realce: b.realce
    }
    QuadradosMontagem { progresso: b.traco; n: 7 }
    // marcador lateral: cresce quando a moldura fecha
    Rectangle {
        x: 0; y: Tema.chanfroG + 8; width: Tema.marcador
        height: 26 * Math.max(0, Math.min(1, (b.traco - 0.55) / 0.45))
        color: b.cor
    }

    Row {
        visible: b.titulo !== "" || b.codigo !== ""
        opacity: b.acender
        x: b.margem; y: b.margem - 2
        spacing: 10
        Rotulo { text: b.titulo; tamanho: 18; anchors.verticalCenter: parent.verticalCenter }
        Codigo { text: b.codigo; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
        id: extra
        opacity: b.acender
        anchors.right: parent.right; anchors.rightMargin: b.margem
        y: b.margem - 6
        spacing: 8
    }
    Column {
        id: area
        opacity: b.acender
        x: b.margem
        y: (b.titulo || b.codigo ? 40 : 0) + b.margem
        width: b.width - b.margem * 2
        spacing: 12
    }
}
