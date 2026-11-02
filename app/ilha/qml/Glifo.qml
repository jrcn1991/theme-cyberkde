import QtQuick
import QtQuick.Shapes
import "glifos.js" as G

// Um ícone Phosphor, pelo nome (os mesmos do Halo). Vetor, sem imagem.
Item {
    id: g
    property string nome: "Circle"
    property int tamanho: 14
    property bool cheio: false
    property color cor: "white"
    width: tamanho; height: tamanho
    Shape {
        scale: g.tamanho / 256
        transformOrigin: Item.TopLeft
        width: 256; height: 256
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"; fillColor: g.cor
            fillRule: ShapePath.WindingFill
            PathSvg { path: G.d(g.nome, g.cheio) }
        }
    }
}
