import QtQuick
import "Catalogo.js" as Catalogo
import "comum"

// Um módulo do Painel FUI sozinho (widget org.cyberkde.fui-<id>): o mesmo componente M*.qml do painel,
// com o fator "k" que cabe no espaço (proporção da referência: largura-base × 172), centrado e em pixel
// inteiro. Os dados vêm de "d" (Dados.qml, só com as partes que o módulo usa).
Item {
    id: s
    property var d
    property string qual: "cpu"
    readonly property var info: Catalogo.modulos[qual] || Catalogo.modulos["cpu"]
    readonly property real k: Math.max(0.5, Math.min((width - 8) / info.largura, (height - 8) / 172))
    function montar() { if (carregador.item) { carregador.item.montado = 0; entra.restart() } }
    NumberAnimation { id: entra; target: carregador.item; property: "montado"; from: 0; to: 1; duration: Cores.d(700) }
    // d e k entram já na criação (sem eles o módulo nasceria sem dados)
    Component.onCompleted: carregador.setSource(s.info.arquivo, { d: s.d, k: s.k })
    Loader {
        id: carregador
        x: Math.round((s.width - width) / 2); y: Math.round((s.height - height) / 2)
        width: Math.round(s.info.largura * s.k)
        onLoaded: {
            item.d = Qt.binding(() => s.d)
            item.k = Qt.binding(() => s.k)
            if (s.qual === "estados") item.grupo = 0
            if (s.qual === "es") item.logo = false
            item.width = Qt.binding(() => carregador.width)
            if (!Cores.reduzir) { item.montado = 0; entra.start() }
        }
    }
    function glitch() { if (carregador.item) carregador.item.glitch(Cores.d(260)) }
}
