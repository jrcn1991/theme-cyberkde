import QtQuick
import "../../qml"

// Conflito numa operação (estado "conflito"): origem e destino lado a lado (tamanho e data);
// Substituir (pasta sobre pasta = Mesclar), Pular, Renomear, com "aplicar a todos".
Modal {
    id: mc
    property var op: ({})
    readonly property var c: op && op.conflito ? op.conflito : ({})
    property bool todos: false
    cor: Tema.alerta
    largura: 760
    tituloNatural: true
    titulo: Ds.t("confl.titulo", { n: c.nome || "" })
    codigo: "OP." + (op.id || 0) + " // " + (op.tipo || "").toUpperCase()
    onCancelado: { arquivos.cancelar(op.id); fechar() }
    function pedir(o) { op = o; todos = false; abrir() }
    function resolver(a) { arquivos.resolverConflito(op.id, a, todos); fechar() }

    Leitura { width: parent.width; tamanho: 13; color: Tema.texto2; text: Ds.t("confl.texto") }
    Row {
        width: parent.width; spacing: 14
        Repeater {
            model: [["confl.origem", mc.c.origem, mc.c.tamanhoOrigem, mc.c.dataOrigem], ["confl.destino", mc.c.destino, mc.c.tamanhoDestino, mc.c.dataDestino]]
            Item {
                required property var modelData
                required property int index
                width: (parent.width - 14) / 2; height: 96
                Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.alfa(Tema.fundo, 0.5); borda: Tema.alfa(index ? Tema.alerta : Tema.destaque, 0.5) }
                Column {
                    x: 12; y: 10; width: parent.width - 24; spacing: 4
                    Rotulo { text: Ds.t(modelData[0]); tamanho: 13; color: index ? Tema.alerta : Tema.destaque }
                    Text { width: parent.width; text: modelData[1] || ""; elide: Text.ElideMiddle; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
                    Text { text: (modelData[2] || "") + " · " + (modelData[3] || ""); font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2 }
                }
            }
        }
    }
    Row {
        spacing: 10
        Item {
            width: 18; height: 18
            Chanfro { anchors.fill: parent; corte: 4; preenchimento: mc.todos ? Tema.destaque : Tema.entrada; borda: mc.todos ? Tema.destaque : Tema.linha }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mc.todos = !mc.todos }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: Ds.t("confl.todos"); font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: { arquivos.cancelar(mc.op.id); mc.fechar() } },
        Botao { text: Ds.t("confl.pular"); tipo: "secundario"; onClicado: mc.resolver("pular") },
        Botao { text: Ds.t("confl.renomear"); tipo: "secundario"; onClicado: mc.resolver("renomear") },
        Botao { text: mc.c.ehPasta ? Ds.t("confl.mesclar") : Ds.t("confl.substituir"); tipo: "primario"; cor: Tema.alerta; onClicado: mc.resolver("substituir") }
    ]
}
