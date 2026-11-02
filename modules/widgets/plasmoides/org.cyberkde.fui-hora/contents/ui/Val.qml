import QtQuick
import "comum"

// Valor em linha de um módulo FUI (mono, legível: nunca abaixo de 11 px).
Text {
    property real k: 1
    property real tam: 11.5
    font.family: Cores.fMono; font.pixelSize: Math.max(11, Math.round(tam * k)); font.weight: Font.Bold
    color: Cores.texto
    elide: Text.ElideRight
}
