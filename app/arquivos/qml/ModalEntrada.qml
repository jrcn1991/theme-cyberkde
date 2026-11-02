import QtQuick
import "../../qml"

// Pergunta curta de uma linha (selecionar por padrão, alvo do link…): título, explicação, campo e,
// opcional, uma caixa de marcar. pedir({titulo, texto, valor, dica, marcador, mono}, funcao(valor, marcado)).
Modal {
    id: me
    property var cfg: ({})
    property var _aoConfirmar: null
    largura: 560
    titulo: cfg.titulo || ""
    codigo: cfg.codigo || "INPUT // TTY"
    onCancelado: fechar()
    function pedir(c, f) {
        cfg = c || {}; _aoConfirmar = f
        campo.texto = cfg.valor || ""; marca.marcado = !!cfg.marcado
        abrir(); Qt.callLater(campo.focar)
    }
    function ok() { const f = _aoConfirmar; const v = campo.texto, m = marca.marcado; fechar(); if (f) f(v, m) }
    Column {
        width: parent.width; spacing: 10
        Leitura { visible: !!me.cfg.texto; width: parent.width; tamanho: 13; color: Tema.texto2; text: me.cfg.texto || "" }
        Campo { id: campo; width: parent.width; dica: me.cfg.dica || ""; mono: !!me.cfg.mono; onAceito: me.ok(); onCancelado: me.fechar() }
        Marcador { id: marca; visible: !!me.cfg.marcador; texto: me.cfg.marcador || "" }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: me.fechar() },
        Botao { text: me.cfg.botao || "OK"; tipo: "primario"; habilitado: campo.texto.trim() !== "" || !!me.cfg.vazioOk; onClicado: me.ok() }
    ]
}
