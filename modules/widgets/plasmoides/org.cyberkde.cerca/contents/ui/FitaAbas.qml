import QtQuick
import "comum"

// As abas da cerca: uma por pasta, com "+" no fim. Usada na moldura e no peek.
Row {
    id: fita
    property var cerca: null                 // o root da cerca
    visible: !!cerca && cerca.pastas.length > 1
    height: visible ? 26 : 0
    spacing: 3
    clip: true
    Repeater {
        model: fita.cerca ? fita.cerca.pastas.length : 0
        Item {
            required property int index
            readonly property bool sel: index === fita.cerca.aba
            width: Math.min(130, tAba.implicitWidth + 18); height: 24
            Chanfro {
                anchors.fill: parent; corte: 5
                preenchimento: parent.sel ? Cores.alfa(fita.cerca.corCerca, 0.22) : (ma.containsMouse ? Cores.alfa(fita.cerca.corCerca, 0.1) : "transparent")
                borda: Cores.alfa(fita.cerca.corCerca, parent.sel ? 0.9 : 0.3)
            }
            Rectangle { visible: parent.sel; x: 5; y: parent.height - 2; width: parent.width - 10; height: 2; color: fita.cerca.corCerca }
            Text {
                id: tAba
                anchors.centerIn: parent; width: Math.min(implicitWidth, 112)
                text: fita.cerca.nomeAba(parent.index); elide: Text.ElideRight
                font.family: Cores.fTexto; font.pixelSize: 12
                color: parent.sel ? Cores.texto : Cores.texto2
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fita.cerca.cfg.abaAtual = parent.index }
        }
    }
    Item {
        width: 24; height: 24
        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 15; color: maMais.containsMouse ? fita.cerca.corCerca : Cores.texto2 }
        MouseArea { id: maMais; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fita.cerca.pedirAba() }
    }
}
