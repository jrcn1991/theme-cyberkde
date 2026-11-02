import QtQuick
import "../../qml"

// Código técnico que muda devagar (dado "vivo" do cabeçalho): a cada "intervalo" ms troca o valor, com um
// degrau de flicker de 2 quadros no movimento completo. Reduzido: troca seco; mínimo: parado.
// Só decorativo: nunca usar em texto de leitura.
Text {
    id: c
    property string prefixo: "SYNC"
    property int intervalo: 7000
    property int semente: 0
    property int _k: 0
    readonly property string valor: {
        let h = (semente * 2654435761 + _k * 40503 + 0x9E37) >>> 0
        return (h & 0xFFFF).toString(16).toUpperCase().padStart(4, "0") + "·" + String((h >>> 16) % 100).padStart(2, "0")
    }
    text: prefixo + " " + valor
    font.family: Tema.fMono; font.pixelSize: 10
    color: Tema.texto3
    Timer {
        interval: c.intervalo; repeat: true
        running: arquivos.movimento !== "minimo" && c.visible && Qt.application.state === Qt.ApplicationActive
        onTriggered: { c._k++; if (!Tema.reduzir && arquivos.movimento === "completo") pisca.restart() }
    }
    SequentialAnimation {
        id: pisca
        PropertyAction { target: c; property: "opacity"; value: 0.25 }
        PauseAnimation { duration: 33 }
        PropertyAction { target: c; property: "opacity"; value: 1 }
    }
}
