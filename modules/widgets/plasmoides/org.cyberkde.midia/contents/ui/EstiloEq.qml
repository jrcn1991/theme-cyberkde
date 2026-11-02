import QtQuick
import "comum"

// Estilo SÓ EQUALIZADOR: as 12 bandas grandes ocupando o widget, com os rótulos de frequência quando há
// altura, e o título da faixa numa linha fina embaixo. Clique: tocar/pausar; roda: volume do player.
Item {
    id: q
    property var r
    property bool compacto: false
    readonly property bool tem: r.tem
    Chanfro { anchors.fill: parent; corte: 10; preenchimento: Cores.alfa(Cores.cartao, r.opac); borda: Cores.alfa(r.corBarra, 0.4) }
    Item {
        anchors.fill: parent; anchors.margins: q.compacto ? 8 : 12
        Row {
            id: topo
            visible: !q.compacto
            spacing: 8
            Rectangle { width: 6; height: 6; color: q.r.corBarra; anchors.verticalCenter: parent.verticalCenter }
            Codigo { text: "SOUND MASTER"; tamanho: 10; font.bold: true; color: q.r.corBarra }
            Codigo { text: q.r.tocando ? q.r.t("▶ TOCANDO", "▶ PLAYING") : q.tem ? q.r.t("❚❚ PAUSA", "❚❚ PAUSED") : q.r.t("SEM SINAL", "NO SIGNAL"); tamanho: 9; color: q.r.tocando ? q.r.corPico : Cores.texto2 }
        }
        Equalizador {
            y: topo.visible ? topo.height + 6 : 0
            width: parent.width; height: parent.height - y - (linha.visible ? linha.height + 4 : 0)
            niveis: q.r.espectro.niveis
            rotulos: !q.compacto; rotulosBaixo: !q.compacto && height > 160
            alturaSeg: height > 160 ? 7 : height > 90 ? 5 : 3; vaoSeg: height > 90 ? 3 : 2
            cor: q.r.corBarra; corPico: q.r.corPico
        }
        Text {
            id: linha
            visible: q.tem
            anchors.bottom: parent.bottom
            width: parent.width
            text: q.tem ? q.r.player.track + (q.r.player.artist ? "  ·  " + q.r.player.artist : "") : ""
            elide: Text.ElideRight; font.family: Cores.fTexto; font.pixelSize: q.compacto ? 10 : 12; color: Cores.texto2
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: q.tem
        cursorShape: Qt.PointingHandCursor
        onClicked: q.r.player.PlayPause()
        onWheel: (w) => q.r.player.changeVolume(w.angleDelta.y > 0 ? 0.05 : -0.05, false)
    }
}
