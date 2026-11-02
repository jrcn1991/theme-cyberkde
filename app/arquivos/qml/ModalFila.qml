import QtQuick
import "../../qml"

// Fila de operações (clique na barra do rodapé): cada operação com a barra segmentada (degraus),
// bytes, velocidade, arquivo atual e cancelar; "limpar concluídas".
Modal {
    id: mf
    largura: 820
    focoInicial: "principal"
    titulo: Ds.t("fila.titulo")
    codigo: "OPS.QUEUE // " + (arquivos.operacoes || []).length
    onCancelado: fechar()
    Leitura { visible: (arquivos.operacoes || []).length === 0; text: Ds.t("fila.vazia"); tamanho: 13; color: Tema.texto3 }
    Repeater {
        model: (arquivos.operacoes || []).slice().reverse()
        Item {
            required property var modelData
            width: parent.width; height: 62
            readonly property bool vivo: ["fila", "contando", "rodando", "conflito"].indexOf(modelData.estado) >= 0
            readonly property color cor: modelData.estado === "erro" || modelData.estado === "conflito" ? Tema.alerta : modelData.estado === "ok" ? Tema.texto2 : Tema.destaque
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.fundo, 0.45); borda: Tema.alfa(parent.cor, 0.5) }
            Column {
                x: 12; y: 8; width: parent.width - 130; spacing: 5
                Row {
                    spacing: 10
                    Rotulo { text: modelData.rotulo; tamanho: 13; color: parent.parent.parent.cor }
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: "OP." + modelData.id + " · " + Ds.t("op." + modelData.estado); tamanho: 9 }
                }
                BarraSegmentada {
                    width: parent.width; height: 8
                    valor: Math.max(0, modelData.progresso)
                    indeterminado: modelData.estado === "contando" || (modelData.progresso < 0 && parent.parent.vivo)
                    cor: parent.parent.cor; larguraSeg: 6; vao: 2
                }
                Text {
                    width: parent.width; elide: Text.ElideMiddle
                    text: modelData.erro ? modelData.erro : [modelData.atual, modelData.bytesTexto, modelData.velocidade].filter(x => !!x).join(" · ")
                    font.family: Tema.fTexto; font.pixelSize: 11; color: modelData.erro ? Tema.alerta : Tema.texto2
                }
            }
            Botao {
                visible: parent.vivo
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: Ds.t("fila.cancelar"); tipo: "sutil"; tamanho: 11
                onClicado: arquivos.cancelar(modelData.id)
            }
        }
    }
    acoes: [
        Botao { text: Ds.t("fila.limpar"); tipo: "sutil"; onClicado: arquivos.limparConcluidas() },
        Botao { text: Ds.t("modal.fechar"); tipo: "primario"; onClicado: mf.fechar() }
    ]
}
