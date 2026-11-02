import QtQuick
import "comum"

// Coluna de ruído: pontos quadrados acesos ao acaso, na densidade de "nivel" (0..1), em pixel inteiro.
// Só sorteia de novo com amostra nova ("semente") e nível > 0: parado em repouso.
Canvas {
    id: r
    property real k: 1
    property real nivel: 0
    property int semente: 0
    readonly property int passo: Math.max(3, Math.round(4 * k))
    readonly property int ponto: Math.max(2, passo - 1)
    onNivelChanged: requestPaint()
    onSementeChanged: if (nivel > 0) requestPaint()
    onWidthChanged: requestPaint()
    function aleat(i) { const x = Math.sin((i + 1) * 12.9898 + semente * 78.233) * 43758.5453; return x - Math.floor(x) }
    onPaint: {
        const g = getContext("2d"); g.reset()
        const cols = Math.floor(width / passo), rows = Math.floor(height / passo)
        let i = 0
        const luz = String(Cores.texto), apagado = String(Cores.alfa(Cores.texto, 0.14))
        for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++, i++) {
            const aceso = aleat(i) < nivel
            g.fillStyle = aceso ? luz : apagado
            g.fillRect(x * passo, y * passo, aceso ? ponto : 1, aceso ? ponto : 1)
        }
    }
}
