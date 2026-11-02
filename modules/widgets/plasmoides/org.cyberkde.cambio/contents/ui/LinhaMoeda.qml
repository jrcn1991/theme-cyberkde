import QtQuick
import "comum"

// Uma moeda na lista: emblema, par e nome, mini-gráfico (se couber), valor e variação do dia.
// "escolhida" = a que está no gráfico grande; o clique a escolhe.
Item {
    id: l
    property var cota: null              // { par, de, para, nome, valor, pct, varia }
    property string par: ""              // mostrado mesmo sem cotação (par inexistente ou sem sinal)
    property bool carregado: false       // já chegou alguma cotação (sem ela, "não encontrado" não vale)
    property var serie: []               // histórico (mais antigo → mais novo)
    property bool escolhida: false
    property bool semSinal: false
    property bool mini: true
    property bool clicavel: true
    property var fmt: (v) => String(v)
    property var fmtPct: (v) => String(v)
    property string simbolo: "€$"
    signal escolher()
    height: 36
    readonly property bool sobe: cota && cota.pct >= 0
    readonly property color corVar: !cota ? Cores.texto3 : sobe ? Cores.secundaria : Cores.alerta

    Rectangle {
        anchors.fill: parent
        color: l.escolhida ? Cores.alfa(Cores.destaque, 0.10) : ma.containsMouse && l.clicavel ? Cores.alfa(Cores.destaque, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: Cores.d(80) } }
    }
    Rectangle { visible: l.escolhida; width: 2; height: parent.height; color: Cores.destaque }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Cores.alfa(Cores.linha, 0.7) }

    Eddie {
        id: em
        x: 6; anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26
        simbolo: l.simbolo
        apagado: l.semSinal
    }
    Column {
        id: nome
        x: em.x + em.width + 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 120)
        Text {
            text: l.cota ? l.cota.de + "/" + l.cota.para : l.par.replace("-", "/")
            font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
            color: Cores.texto
        }
        Text {
            width: Math.min(implicitWidth, 120)
            text: l.cota ? l.cota.nome : l.semSinal || !l.carregado ? "" : (Cores.en ? "pair not found" : "par não encontrado")
            font.family: Cores.fTexto; font.pixelSize: 10
            color: Cores.texto3
            elide: Text.ElideRight
        }
    }
    GraficoHud {
        visible: l.mini && l.serie.length > 1 && width > 40
        x: nome.x + nome.width + 10
        width: valores.x - x - 10
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 12
        // a escala começa perto do mínimo do período: sem isso a variação some
        readonly property real lo: l.serie.length ? Math.min(...l.serie) : 0
        readonly property real hi: l.serie.length ? Math.max(...l.serie) : 1
        series: [{ valores: l.serie.map(v => v - lo + (hi - lo) * 0.08 + 1e-9), cor: l.corVar }]
    }
    Column {
        id: valores
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        NumeroCintilante {
            anchors.right: parent.right
            valor: l.cota ? l.fmt(l.cota.valor, l.cota.para) : "--"
            intervaloMin: 4000
            font.pixelSize: 13; font.bold: true
            color: l.semSinal ? Cores.texto2 : Cores.texto
        }
        Text {
            anchors.right: parent.right
            text: l.cota ? (l.sobe ? "▲ " : "▼ ") + l.fmtPct(l.cota.pct) : ""
            font.family: Cores.fMono; font.pixelSize: 10; font.bold: true
            color: l.corVar
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: l.clicavel
        hoverEnabled: true
        cursorShape: l.clicavel ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: l.escolher()
    }
}
