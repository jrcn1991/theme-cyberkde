import QtQuick
import "../../qml"

// Confirmação de apagar permanentemente / esvaziar a lixeira (cor de alerta). Só chama o back-end
// com a ficha que prepararApagar/prepararEsvaziar devolveram (seção 10 da especificação).
Modal {
    id: mc
    property var ficha: ({})
    property bool esvaziar: false
    cor: Tema.alerta
    largura: 620
    focoInicial: "cancelar"
    titulo: esvaziar ? Ds.t("conf.esvaziarTitulo") : Ds.t("conf.apagarTitulo")
    codigo: "RM.PERMANENT // " + (ficha.ficha || "").toUpperCase()
    onCancelado: fechar()
    function pedir(f, ev) { ficha = f || {}; esvaziar = !!ev; abrir() }
    Leitura {
        width: parent.width; tamanho: 14; color: Tema.texto
        text: mc.esvaziar ? Ds.t(mc.ficha.quantidade === 1 ? "conf.esvaziarTexto1" : "conf.esvaziarTexto", { n: mc.ficha.quantidade || 0 }) : Ds.t(mc.ficha.quantidade === 1 ? "conf.apagarTexto1" : "conf.apagarTexto", { n: mc.ficha.quantidade || 0, t: mc.ficha.tamanhoTexto || "" })
    }
    Column {
        visible: !mc.esvaziar
        width: parent.width; spacing: 2
        Repeater {
            model: (mc.ficha.nomes || []).slice(0, 8)
            Text { required property string modelData; text: "> " + modelData; width: parent.width; elide: Text.ElideMiddle; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto2 }
        }
        Codigo { visible: (mc.ficha.nomes || []).length > 8; text: "+" + ((mc.ficha.nomes || []).length - 8); tamanho: 10 }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: mc.fechar() },
        Botao {
            text: Ds.t("conf.apagar"); icone: "✕"; tipo: "primario"; cor: Tema.alerta
            onClicado: {
                const id = mc.esvaziar ? arquivos.esvaziarLixeira(mc.ficha.ficha) : arquivos.apagarPermanentemente(mc.ficha.ficha)
                if (id < 0) Ds.janela.avisar("erro", Ds.en ? "Confirmation expired. Try again." : "A confirmação expirou. Tente de novo.")
                mc.fechar()
            }
        }
    ]
}
