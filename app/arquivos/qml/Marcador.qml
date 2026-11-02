import QtQuick
import "../../qml"

// Caixa de marcar com rótulo (modais). Clique alterna; emite alternado(novo).
Row {
    id: mk
    property bool marcado: false
    property string texto: ""
    property bool habilitado: true
    signal alternado(bool novo)
    spacing: 8
    opacity: habilitado ? 1 : 0.45
    Item {
        width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
        Chanfro { anchors.fill: parent; corte: 4; preenchimento: mk.marcado ? Tema.destaque : Tema.entrada; borda: mk.marcado ? Tema.destaque : Tema.linha }
        Text { anchors.centerIn: parent; visible: mk.marcado; text: "✓"; font.pixelSize: 12; font.bold: true; color: Tema.escuro }
    }
    Text { anchors.verticalCenter: parent.verticalCenter; text: mk.texto; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
    TapHandler { enabled: mk.habilitado; onTapped: { mk.marcado = !mk.marcado; mk.alternado(mk.marcado) } }
}
