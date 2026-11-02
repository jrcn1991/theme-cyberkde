import QtQuick
import "../../qml"

// PROPRIEDADES DE VÁRIOS ITENS (spec 20): propriedadesVarias(lista) → propriedadesVariasProntas(mapa) com
// totais (recursivos) e o que é comum ("" = misto). Permissões em lote: octal ("644") ou simbólico como o
// chmod ("u+x,go-w", "a+X"), com "recursivo" → alterarPermissoesLote. Grupo: só os da usuária
// (gruposDisponiveis) → alterarGrupo. Etiquetas, avaliação e comentário para todos de uma vez.
Modal {
    id: mv
    property var lista: []
    property var p: null
    largura: 820
    focoInicial: "principal"
    titulo: Ds.t("pv.titulo", { n: lista.length })
    codigo: "MULTI.PROPS // " + lista.length
    onCancelado: fechar()
    function mostrar(l) { lista = l || []; p = null; mudanca.texto = ""; abrir(); arquivos.propriedadesVarias(lista) }
    Connections { target: arquivos; function onPropriedadesVariasProntas(mapa) { if (mv.aberto) mv.p = mapa } }
    function val(k) { return !p ? "…" : (p[k] === "" || p[k] === undefined) ? Ds.t("pv.misto") : String(p[k]) }

    component Par: Item {
        property string r: ""
        property string v: ""
        width: parent.width; height: Math.max(18, tv.implicitHeight)
        Text { width: 120; text: parent.r; font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3 }
        Text { id: tv; x: 124; width: parent.width - 124; text: parent.v; wrapMode: Text.WrapAnywhere; font.family: Tema.fTexto; font.pixelSize: 12; color: parent.v === Ds.t("pv.misto") ? Tema.texto3 : Tema.texto }
    }
    Row {
        width: parent.width; spacing: 16
        Column {
            width: (parent.width - 16) / 2; spacing: 6
            Rotulo { text: Ds.t("prop.geral"); tamanho: 13; color: Tema.destaque }
            Par { r: Ds.t("pv.itens"); v: mv.p ? Ds.t("pv.contagem", { a: mv.p.arquivos, p: mv.p.pastas }) : "…" }
            Par { r: Ds.t("prop.tamanho"); v: mv.p ? mv.p.tamanhoTexto : Ds.t("prop.lendo") }
            Par { r: Ds.t("prop.tipo"); v: mv.val("mime") }
            Par { r: "MODO"; v: mv.val("modo") }
            Par { r: Ds.t("prop.dono"); v: mv.val("dono") }
            Par { r: Ds.t("prop.grupo"); v: mv.val("grupoDono") }
            Item { width: 1; height: 6 }
            Rotulo { text: Ds.t("meta.titulo"); tamanho: 13; color: Tema.destaque }
            Metadados { width: parent.width; caminhos: mv.lista }
        }
        Column {
            width: (parent.width - 16) / 2; spacing: 8
            Rotulo { text: Ds.t("prop.perm"); tamanho: 13; color: Tema.destaque }
            Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Ds.t("pv.permDica") }
            Row {
                spacing: 6
                Repeater {
                    model: ["644", "755", "600", "u+x", "go-w", "a+X"]
                    Chip { required property string modelData; texto: modelData; ativo: mudanca.texto === modelData; onClicado: mudanca.texto = modelData }
                }
            }
            Campo { id: mudanca; width: parent.width; mono: true; dica: "644 · u+x,go-w · a+X" }
            Marcador { id: recursivo; texto: Ds.t("pv.recursivo") }
            Botao {
                text: Ds.t("prop.aplicar"); tamanho: 11; tipo: "primario"; habilitado: mudanca.texto.trim() !== ""
                onClicado: { const id = arquivos.alterarPermissoesLote(mv.lista, mudanca.texto.trim(), recursivo.marcado); if (id < 0) Ds.janela.avisar("erro", Ds.t("pv.permInvalida")) }
            }
            Item { width: 1; height: 6 }
            Rotulo { text: Ds.t("pv.grupoTitulo"); tamanho: 13; color: Tema.destaque }
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: arquivos.gruposDisponiveis || []
                    Chip {
                        required property string modelData
                        texto: modelData; ativo: !!mv.p && mv.p.grupoDono === modelData
                        onClicado: { const e = arquivos.alterarGrupo(mv.lista, modelData); if (e) Ds.janela.avisar("erro", e); else arquivos.propriedadesVarias(mv.lista) }
                    }
                }
            }
        }
    }
    acoes: [ Botao { text: Ds.t("modal.fechar"); tipo: "primario"; tamanho: 12; onClicado: mv.fechar() } ]
}
