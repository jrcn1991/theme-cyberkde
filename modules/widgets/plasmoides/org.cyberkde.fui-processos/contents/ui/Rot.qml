import QtQuick
import "comum"

// Rótulo / legenda de um módulo FUI (texto2, fonte de título), em pixel real.
Text {
    property real k: 1
    property real tam: 10.5
    font.family: Cores.fTitulo; font.weight: Font.Bold; font.pixelSize: Math.max(10, Math.round(tam * k)); font.letterSpacing: 0.4
    color: Cores.texto2
}
