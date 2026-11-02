import QtQuick
import "../../qml"

// Rótulo sob a pilha: o nome (até 2 linhas) (fonte do sistema; título de grupo em Rajdhani) e, em micro, código e
// quantidade. Aceso = nome no destaque.
Column {
    id: r
    property string nome: ""
    property string codigo: ""
    property bool aceso: false
    property bool titulo: false
    spacing: 2
    // nome em até 2 linhas (corte no meio só se não couber; mouse em cima mostra o nome inteiro), numa
    // caixa de altura fixa: os códigos de todas as células ficam na mesma linha
    NomeLongo {
        width: r.width
        texto: (r.titulo ? "◇ " : "") + r.nome; linhas: 2      // ◇: grupo de TIPO, não uma pasta
        familia: r.titulo ? Tema.fRotulo : Tema.fTexto
        tamanho: r.titulo ? 14 : 13
        peso: r.titulo ? Font.DemiBold : Font.Normal
        espaco: r.titulo ? 1 : 0
        cor: r.aceso ? Tema.destaque : Tema.texto
    }
    // "0x06C381 · 11": o código é decorativo (texto3, 9 px); a contagem é informação (texto2, 11 px)
    Text {
        width: r.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
        readonly property int corte: r.codigo.indexOf(" · ")
        textFormat: Text.StyledText
        text: corte < 0 ? r.codigo
            : "<font color='" + Tema.texto3 + "' size='1'>" + r.codigo.slice(0, corte) + "</font> · " + r.codigo.slice(corte + 3)
        font.family: Tema.fMono; font.pixelSize: 11; font.letterSpacing: 0.5
        color: Tema.texto2
    }
}
