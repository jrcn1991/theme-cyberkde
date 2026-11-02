import QtQuick
import "../../qml"

// Dica de um botão de ícone: aparece depois de 600 ms com o mouse em cima (nome · atalho), numa
// moldura chanfrada logo abaixo do botão (acima, se "acima"). Desenhada por cima do resto (z alto).
Item {
    id: d
    property string texto: ""
    property bool sobre: false           // o mouse está no botão
    property bool acima: false
    readonly property bool mostrando: sobre && texto !== "" && espera.pronto
    z: 90
    anchors.horizontalCenter: parent.horizontalCenter
    y: acima ? -height - 6 : parent.height + 6
    width: tx.implicitWidth + 18; height: 24
    visible: mostrando
    onSobreChanged: { espera.pronto = false; if (sobre) espera.restart(); else espera.stop() }
    Timer { id: espera; property bool pronto: false; interval: 600; onTriggered: pronto = true }
    Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.elevado; borda: Tema.alfa(Tema.secundaria, 0.9) }
    Text { id: tx; anchors.centerIn: parent; text: d.texto; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
}
