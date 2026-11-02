import QtQuick
import "Atividades.js" as A

// O conteúdo da pílula fechada, para uma atividade.
Row {
    id: r
    property var tema
    property var ui
    property var a: null
    property var niveis: []
    property real alturaPilula: 36
    property real agora: 0
    spacing: 8
    height: alturaPilula
    readonly property string tipo: a ? a.tipo : ""
    component Texto: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: r.tema.texto; font.family: r.tema.fonte; font.pixelSize: 13; font.weight: Font.Medium
        elide: Text.ElideRight
    }
    Image {
        visible: r.tipo === "midia" && !!r.a.art
        anchors.verticalCenter: parent.verticalCenter
        readonly property real t: Math.min(24, r.alturaPilula - 10)
        width: t; height: t; fillMode: Image.PreserveAspectCrop
        source: visible ? r.a.art : ""
        asynchronous: true; cache: false
    }
    Glifo {
        visible: r.tipo === "timer" || r.tipo === "download" || r.tipo === "atividade"
        anchors.verticalCenter: parent.verticalCenter
        cor: r.tipo === "timer" ? r.tema.alerta : r.tema.ok
        nome: r.tipo === "timer" ? (r.a.timer.end === null ? "Hourglass" : "Timer") : r.tipo === "download" ? "DownloadSimple" : r.tipo === "atividade" ? A.glifoDaOrigem(r.a.atividade.source) : "Circle"
    }
    Rectangle { visible: r.tipo === "mic"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: r.tema.alerta }
    Texto {
        visible: r.tipo !== ""
        width: Math.min(implicitWidth, r.tipo === "midia" ? 150 : 240)
        font.features: { "tnum": 1 }
        text: r.tipo === "relogio" ? r.a.hora
            : r.tipo === "midia" ? r.a.nome
            : r.tipo === "timer" ? A.contagem(r.a.timer, r.agora)
            : r.tipo === "download" ? (r.a.n === 1 ? r.a.nome : r.ui.txt("{n} downloads", { n: r.a.n }))
            : r.tipo === "mic" ? r.ui.txt("Microfone") + " · " + r.a.quem
            : r.tipo === "atividade" ? r.a.atividade.title + (r.a.n > 1 ? " +" + (r.a.n - 1) : "") + (r.a.atividade.progress !== null ? " · " + Math.round(r.a.atividade.progress * 100) + "%" : "")
            : ""
    }
    Ondas {
        visible: r.tipo === "midia"
        anchors.verticalCenter: parent.verticalCenter
        tema: r.tema; niveis: r.niveis
        parado: !r.a || !r.a.tocando
        alturaMax: Math.min(14, r.alturaPilula - 18)
    }
}
