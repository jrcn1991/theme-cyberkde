import QtQuick
import "../../qml"

// Confirmação de DESMONTAR / EJETAR (spec 20): o back-end não desmonta sem ficha; ele emite
// confirmacaoNecessaria(acao, mapa) e aqui se mostra o que será afetado (abas abertas no disco, que vão
// para a HOME, e operações em andamento). Só "Desmontar"/"Ejetar" chama arquivos.confirmar(ficha).
Modal {
    id: md
    property var info: ({})
    property string acao: "desmontar"
    readonly property bool ejetar: acao === "ejetar" || !!info.ejetar
    cor: (info.operacoes || []).length ? Tema.alerta : Tema.destaque
    largura: 620
    focoInicial: "cancelar"
    titulo: Ds.t(ejetar ? "disco.ejetarTitulo" : "disco.desmontarTitulo", { n: info.nome || "" })
    codigo: "UDISKS // " + (info.dispositivo || "").toUpperCase()
    onCancelado: fechar()
    function pedir(a, mapa) { acao = a || "desmontar"; info = mapa || {}; abrir() }

    Column {
        width: parent.width; spacing: 10
        Leitura { width: parent.width; tamanho: 14; color: Tema.texto; text: Ds.t(md.ejetar ? "disco.ejetarTexto" : "disco.desmontarTexto", { m: md.info.montagem || "—" }) }
        Rotulo { visible: (md.info.abasAfetadas || []).length > 0; text: Ds.t("disco.abas"); tamanho: 12; color: Tema.secundaria }
        Repeater {
            model: (md.info.abasAfetadas || []).slice(0, 6)
            Text { required property string modelData; width: parent.width; text: "> " + modelData; elide: Text.ElideMiddle; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto2 }
        }
        Rotulo { visible: (md.info.operacoes || []).length > 0; text: Ds.t("disco.ops"); tamanho: 12; color: Tema.alerta }
        Repeater {
            model: (md.info.operacoes || []).slice(0, 6)
            Text { required property string modelData; width: parent.width; text: "! " + modelData; elide: Text.ElideRight; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.alerta }
        }
        Codigo { visible: !(md.info.abasAfetadas || []).length && !(md.info.operacoes || []).length; text: Ds.t("disco.nada"); tamanho: 10 }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: md.fechar() },
        Botao {
            text: Ds.t(md.ejetar ? "disco.ejetar" : "disco.desmontar"); icone: "⏏"; tipo: "primario"; cor: md.cor
            onClicado: { if (!arquivos.confirmar(md.info.ficha || "")) {} md.fechar() }
        }
    ]
}
