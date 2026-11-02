import QtQuick
import "Atividades.js" as A

// A bolha: a segunda atividade, destacada à direita da pílula.
Item {
    id: b
    property var ui
    property var a: null
    property var ultima: null
    onAChanged: if (a) ultima = a
    readonly property var v: a || ultima
    readonly property string tipo: v ? v.tipo : ""
    readonly property bool viva: !!a
    width: viva && ui ? ui.alturaPilula : 0
    height: ui ? ui.alturaPilula : 0
    visible: width > 0
    Behavior on width { NumberAnimation { duration: b.ui && b.ui.tema.reduzir ? 0 : 380; easing.type: Easing.OutBack } }
    Rectangle {
        visible: !!b.ui
        x: 0; y: -height / 2; width: parent.width; height: parent.height * 1.5
        radius: b.ui ? b.ui.raioDe(width) : 0; color: b.ui ? b.ui.tema.fundo : "transparent"
    }
    Item { anchors.fill: parent; visible: !!b.ui; 
    Rectangle { visible: b.tipo === "mic"; anchors.centerIn: parent; width: 8; height: 8; radius: b.ui ? b.ui.raioDe(8) : 0; color: b.ui ? b.ui.tema.alerta : "transparent" }
    Glifo { visible: b.tipo === "download" || b.tipo === "atividade"; anchors.centerIn: parent; cor: b.ui.tema.ok; nome: b.tipo === "download" ? "DownloadSimple" : b.tipo === "atividade" ? A.glifoDaOrigem(b.v.atividade.source) : "Circle" }
    Text { visible: b.tipo === "timer"; anchors.centerIn: parent; text: b.tipo === "timer" ? A.contagem(b.v.timer, b.ui.agora) : ""; color: b.ui.tema.alerta; font.family: b.ui.tema.fonte; font.pixelSize: 11; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
    Ondas { visible: b.tipo === "midia"; anchors.centerIn: parent; tema: b.ui.tema; niveis: b.ui.niveis; parado: !b.v || !b.v.tocando; alturaMax: Math.min(14, b.ui.alturaPilula - 18) }
    }
}
