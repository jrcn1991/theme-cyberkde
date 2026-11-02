import QtQuick
import "../../qml"

// RENOMEAÇÃO EM LOTE (F2 com vários itens, spec 20): quatro modos — padrão com contador ("Foto ###"),
// buscar e trocar (texto ou regex), caixa e prefixo/sufixo. A prévia é viva: a cada mudança,
// arquivos.previaRenomearLote(lista, regra) → [{de, nome, novo, conflito}], com os conflitos destacados
// (existe, repetido, inválido). "Renomear" só fica disponível sem conflito; chama renomearLote().
Modal {
    id: ml
    property var lista: []
    property string modo: "padrao"
    property var previa: []
    readonly property int problemas: previa.filter(p => p.conflito && p.conflito !== "igual").length
    readonly property int mudam: previa.filter(p => !p.conflito).length
    largura: 860
    titulo: Ds.t("lote.titulo", { n: lista.length })
    codigo: "BATCH.RENAME // " + lista.length
    onCancelado: fechar()

    function pedir(l) {
        lista = l || []
        modo = "padrao"
        padrao.texto = Ds.t("lote.padraoInicial"); inicio.texto = "1"; passo.texto = "1"
        buscar.texto = ""; trocar.texto = ""; prefixo.texto = ""; sufixo.texto = ""
        caixaModo = "minusculas"
        abrir(); atualizar(); Qt.callLater(padrao.focar)
    }
    property string caixaModo: "minusculas"
    function regra() {
        if (modo === "padrao") return { modo: "padrao", padrao: padrao.texto, inicio: parseInt(inicio.texto) || 1, passo: parseInt(passo.texto) || 1 }
        if (modo === "substituir") return { modo: "substituir", buscar: buscar.texto, trocar: trocar.texto, regex: mRegex.marcado, caixaSensivel: mCaixa.marcado, extensao: mExt.marcado }
        if (modo === "caixa") return { modo: "caixa", caixa: caixaModo, extensao: mExt2.marcado }
        return { modo: "acrescentar", prefixo: prefixo.texto, sufixo: sufixo.texto }
    }
    function atualizar() { espera.restart() }
    Timer { id: espera; interval: 90; onTriggered: ml.previa = ml.aberto ? (arquivos.previaRenomearLote(ml.lista, ml.regra()) || []) : [] }
    onModoChanged: atualizar()
    onCaixaModoChanged: atualizar()
    function aplicar() {
        if (problemas || !mudam) return
        const id = arquivos.renomearLote(lista, regra())
        if (id < 0) Ds.janela.avisar("erro", Ds.t("lote.erro"))
        fechar()
    }

    Column {
        width: parent.width; spacing: 12
        Row {
            spacing: 6
            Repeater {
                model: ["padrao", "substituir", "caixa", "acrescentar"]
                Chip { required property string modelData; texto: Ds.t("lote." + modelData); ativo: ml.modo === modelData; onClicado: ml.modo = modelData }
            }
        }
        // ---- campos do modo
        Item {
            width: parent.width; height: 64
            Row {
                visible: ml.modo === "padrao"; spacing: 10
                Column { spacing: 4; Codigo { text: Ds.t("lote.padraoRot"); tamanho: 11; color: Tema.texto2 } Campo { id: padrao; width: 360; mono: true; onEditado: ml.atualizar(); onAceito: ml.aplicar() } }
                Column { spacing: 4; Codigo { text: Ds.t("lote.inicio"); tamanho: 11; color: Tema.texto2 } Campo { id: inicio; width: 70; mono: true; onEditado: ml.atualizar() } }
                Column { spacing: 4; Codigo { text: Ds.t("lote.passo"); tamanho: 11; color: Tema.texto2 } Campo { id: passo; width: 70; mono: true; onEditado: ml.atualizar() } }
                Leitura { width: 260; tamanho: 11; color: Tema.texto3; text: Ds.t("lote.padraoDica") }
            }
            Column {
                visible: ml.modo === "substituir"; spacing: 6
                Row {
                    spacing: 10
                    Column { spacing: 4; Codigo { text: Ds.t("lote.buscar"); tamanho: 11; color: Tema.texto2 } Campo { id: buscar; width: 300; mono: mRegex.marcado; onEditado: ml.atualizar(); onAceito: ml.aplicar() } }
                    Column { spacing: 4; Codigo { text: Ds.t("lote.trocar"); tamanho: 11; color: Tema.texto2 } Campo { id: trocar; width: 300; onEditado: ml.atualizar(); onAceito: ml.aplicar() } }
                }
                Row {
                    spacing: 18
                    Marcador { id: mRegex; texto: Ds.t("lote.regex"); onAlternado: ml.atualizar() }
                    Marcador { id: mCaixa; texto: Ds.t("lote.caixaSens"); onAlternado: ml.atualizar() }
                    Marcador { id: mExt; texto: Ds.t("lote.ext"); onAlternado: ml.atualizar() }
                }
            }
            Row {
                visible: ml.modo === "caixa"; spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: ["minusculas", "maiusculas", "titulo"]
                    Chip { required property string modelData; texto: Ds.t("lote.c." + modelData); ativo: ml.caixaModo === modelData; onClicado: ml.caixaModo = modelData }
                }
                Item { width: 18; height: 1 }
                Marcador { id: mExt2; anchors.verticalCenter: parent.verticalCenter; texto: Ds.t("lote.ext"); onAlternado: ml.atualizar() }
            }
            Row {
                visible: ml.modo === "acrescentar"; spacing: 10
                Column { spacing: 4; Codigo { text: Ds.t("lote.prefixo"); tamanho: 11; color: Tema.texto2 } Campo { id: prefixo; width: 300; onEditado: ml.atualizar(); onAceito: ml.aplicar() } }
                Column { spacing: 4; Codigo { text: Ds.t("lote.sufixo"); tamanho: 11; color: Tema.texto2 } Campo { id: sufixo; width: 300; onEditado: ml.atualizar(); onAceito: ml.aplicar() } }
            }
        }
        // ---- prévia viva
        Row {
            spacing: 12
            Rotulo { text: Ds.t("lote.previa"); tamanho: 12; color: Tema.secundaria }
            Codigo { anchors.verticalCenter: parent.verticalCenter; tamanho: 12; color: ml.problemas ? Tema.alerta : Tema.texto2; text: Ds.t("lote.resumo", { m: ml.mudam, p: ml.problemas }) }
        }
        Item {
            width: parent.width; height: Math.min(300, Math.max(60, ml.previa.length * 24 + 8))
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.fundo, 0.5); borda: Tema.alfa(ml.problemas ? Tema.alerta : Tema.destaque, 0.4) }
            ListView {
                id: lv
                anchors.fill: parent; anchors.margins: 4
                clip: true
                model: ml.previa
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool ruim: !!modelData.conflito && modelData.conflito !== "igual"
                    width: lv.width; height: 24
                    Rectangle { anchors.fill: parent; color: parent.ruim ? Tema.alfa(Tema.alerta, 0.14) : index % 2 ? Tema.alfa(Tema.texto, 0.025) : "transparent" }
                    Text { x: 8; width: (parent.width - 150) / 2 - 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; elide: Text.ElideMiddle; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto2 }
                    Text { x: (parent.width - 150) / 2; anchors.verticalCenter: parent.verticalCenter; text: "→"; font.pixelSize: 12; color: parent.ruim ? Tema.alerta : Tema.destaque }
                    Text {
                        x: (parent.width - 150) / 2 + 22; width: (parent.width - 150) / 2 - 22; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.novo; elide: Text.ElideMiddle
                        font.family: Tema.fTexto; font.pixelSize: 12; font.bold: !modelData.conflito
                        color: parent.ruim ? Tema.alerta : modelData.conflito === "igual" ? Tema.texto3 : Tema.texto
                    }
                    Codigo {
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        visible: !!modelData.conflito
                        text: Ds.t("lote.cf." + modelData.conflito); tamanho: 11
                        color: parent.ruim ? Tema.alerta : Tema.texto3
                    }
                }
            }
        }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: ml.fechar() },
        Botao { text: Ds.t("lote.aplicar", { n: ml.mudam }); tipo: "primario"; habilitado: !ml.problemas && ml.mudam > 0; onClicado: ml.aplicar() }
    ]
}
