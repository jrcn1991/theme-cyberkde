import QtQuick
import "../../qml"

// ETIQUETAS, AVALIAÇÃO e COMENTÁRIO de um ou vários itens (xattr do Baloo, compatíveis com o Dolphin;
// spec 20). Usado no LOG e nas propriedades. Estrelas: 5, cada uma vale 2 (0–10); clicar na mesma nota
// zera. Etiquetas: fichas com ×, campo com sugestões de arquivos.tagsConhecidas. Comentário: Enter grava.
// Mostra o estado local logo após a mudança (o modelo atualiza o papel depois).
Column {
    id: mt
    property var caminhos: []
    property var tags: []
    property int avaliacao: 0
    property string comentario: ""
    property bool compacto: false          // no LOG: rótulos em mono, menos espaço
    spacing: compacto ? 6 : 8

    function _ok(e) { if (e) Ds.janela.avisar("aviso", e) }
    function nota(n) { const v = n === avaliacao ? 0 : n; avaliacao = v; _ok(arquivos.definirAvaliacao(caminhos, v)) }
    function addTag(t) {
        t = (t || "").trim(); if (!t || tags.indexOf(t) >= 0) return
        tags = tags.concat([t]); _ok(arquivos.adicionarTag(caminhos, t)); novaTag.texto = ""
    }
    function remTag(t) { tags = tags.filter(x => x !== t); _ok(arquivos.removerTag(caminhos, t)) }

    // ---- estrelas
    Row {
        spacing: 8
        Codigo { anchors.verticalCenter: parent.verticalCenter; width: mt.compacto ? 96 : 110; text: Ds.t("meta.avaliacao"); tamanho: mt.compacto ? 9 : 10; color: Tema.texto3 }
        Row {
            spacing: 2
            Repeater {
                model: 5
                Text {
                    required property int index
                    readonly property int valor: (index + 1) * 2
                    text: mt.avaliacao >= valor - 1 ? "★" : "☆"
                    opacity: mt.avaliacao === valor - 1 ? 0.5 : 1          // meia estrela (nota ímpar)
                    font.pixelSize: 17
                    color: mt.avaliacao >= valor - 1 ? Tema.destaque : Tema.alfa(Tema.texto3, hvE.hovered ? 1 : 0.6)
                    HoverHandler { id: hvE; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: mt.nota(parent.valor) }
                }
            }
        }
    }
    // ---- etiquetas
    Row {
        spacing: 8
        width: parent.width
        Codigo { width: mt.compacto ? 96 : 110; y: 5; text: Ds.t("meta.tags"); tamanho: mt.compacto ? 9 : 10; color: Tema.texto3 }
        Flow {
            width: parent.width - (mt.compacto ? 104 : 118)
            spacing: 4
            Repeater {
                model: mt.tags
                Chip { required property string modelData; texto: modelData; fechar: true; cor: Tema.secundaria; onRemovido: mt.remTag(modelData) }
            }
            Campo {
                id: novaTag
                width: 110; height: 24
                dica: Ds.t("meta.novaTag")
                onAceito: mt.addTag(texto)
            }
        }
    }
    // sugestões (etiquetas já usadas que este item não tem)
    Flow {
        visible: novaTag.entrada.activeFocus && sugestoes.length > 0
        x: mt.compacto ? 104 : 118; width: parent.width - x
        spacing: 4
        readonly property var sugestoes: (arquivos.tagsConhecidas || []).filter(t => mt.tags.indexOf(t) < 0 && t.toLowerCase().indexOf(novaTag.texto.toLowerCase()) >= 0).slice(0, 8)
        Repeater { model: parent.sugestoes; Chip { required property string modelData; texto: "+ " + modelData; onClicado: mt.addTag(modelData) } }
    }
    // ---- comentário
    Row {
        spacing: 8
        width: parent.width
        Codigo { width: mt.compacto ? 96 : 110; y: 7; text: Ds.t("meta.comentario"); tamanho: mt.compacto ? 9 : 10; color: Tema.texto3 }
        Campo {
            id: com
            width: parent.width - (mt.compacto ? 104 : 118)
            dica: Ds.t("meta.comentarioDica")
            Component.onCompleted: texto = mt.comentario
            Connections { target: mt; function onComentarioChanged() { if (!com.entrada.activeFocus) com.texto = mt.comentario } }
            onAceito: { mt.comentario = texto; mt._ok(arquivos.definirComentario(mt.caminhos, texto)); Ds.janela.focarArea() }
        }
    }
}
