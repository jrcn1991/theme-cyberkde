import QtQuick
import "comum"

// Emblema dos eddies: "€$" sobreposto, cortado por dois traços horizontais, numa placa chanfrada.
// "simbolo" troca o glifo (o da moeda da linha); o padrão é o €$ do jogo.
Item {
    id: e
    property string simbolo: "€$"
    property color cor: Cores.destaque
    property bool apagado: false
    implicitWidth: 34; implicitHeight: 34
    Chanfro {
        anchors.fill: parent
        corte: Math.max(4, Math.round(e.height * 0.18))
        preenchimento: Cores.alfa(e.cor, e.apagado ? 0.06 : 0.14)
        borda: Cores.alfa(e.cor, e.apagado ? 0.35 : 0.8)
    }
    Text {
        id: g
        anchors.centerIn: parent
        text: e.simbolo
        font.family: Cores.fIdentidade
        font.weight: Font.Black
        font.pixelSize: Math.round(e.height * (e.simbolo.length > 2 ? 0.30 : e.simbolo.length > 1 ? 0.42 : 0.55))
        font.letterSpacing: -1
        color: e.apagado ? Cores.texto3 : e.cor
    }
    // os dois traços do símbolo do eddie, passando por cima do glifo
    Repeater {
        model: e.simbolo === "€$" ? 2 : 0
        Rectangle {
            required property int index
            x: g.x - 2; width: g.width + 4
            y: g.y + g.height * (index ? 0.58 : 0.40); height: Math.max(1, Math.round(e.height / 22))
            color: e.apagado ? Cores.texto3 : e.cor
        }
    }
}
