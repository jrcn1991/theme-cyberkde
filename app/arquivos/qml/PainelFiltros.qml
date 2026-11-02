import QtQuick
import "../../qml"

// FILTROS DA BUSCA (spec 20), sob o campo de busca: conteúdo (procura dentro dos arquivos), tipo, data,
// tamanho, etiqueta e avaliação mínima. "Buscar" chama aba.buscar(texto, {…}); o texto pode ficar vazio
// quando há filtro (ex.: "imagens desta semana").
Item {
    id: pf
    property var aba: arquivos.aba
    property string texto: ""
    property bool aberto: false
    property bool conteudo: false
    property string grupo: ""
    property int desdeDias: 0
    property int faixa: 0                   // índice de "faixas"
    property string tag: ""
    property int avaliacaoMin: 0
    readonly property var faixas: [[0, 0], [0, 1048576], [1048576, 104857600], [104857600, 0]]
    readonly property bool temFiltro: conteudo || grupo !== "" || desdeDias > 0 || faixa > 0 || tag !== "" || avaliacaoMin > 0
    signal buscou()
    visible: aberto
    width: 470; height: col.implicitHeight + 28
    z: 80
    function opcoes() {
        let o = { conteudo: conteudo, ocultos: !!aba && aba.mostrarOcultos }
        if (grupo) o.grupo = grupo
        if (desdeDias) o.desdeDias = desdeDias
        if (faixa) { if (faixas[faixa][0]) o.tamanhoMin = faixas[faixa][0]; if (faixas[faixa][1]) o.tamanhoMax = faixas[faixa][1] }
        if (tag) o.tag = tag
        if (avaliacaoMin) o.avaliacaoMin = avaliacaoMin
        return o
    }
    function buscar() {
        if (!aba || (texto.trim() === "" && !temFiltro)) return
        aba.filtro = ""                      // o que se digitou filtrava a pasta; a busca recomeça do zero
        aba.buscar(texto.trim(), opcoes()); aberto = false; buscou()
    }
    function limpar() { conteudo = false; grupo = ""; desdeDias = 0; faixa = 0; tag = ""; avaliacaoMin = 0 }

    Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.elevado; borda: Tema.secundaria }
    MouseArea { anchors.fill: parent }          // não deixa o clique vazar para a visão
    component Linha: Row {
        property string rotulo: ""
        default property alias itens: fl.data
        spacing: 8; width: col.width
        Codigo { width: 84; y: 5; text: parent.rotulo; tamanho: 11; color: Tema.texto2 }
        Flow { id: fl; width: parent.width - 92; spacing: 4 }
    }
    Column {
        id: col
        x: 14; y: 14; width: parent.width - 28
        spacing: 8
        Row {
            spacing: 10
            Rotulo { text: Ds.t("filtro.titulo"); tamanho: 13; color: Tema.secundaria }
            Codigo { anchors.verticalCenter: parent.verticalCenter; tamanho: 11; color: Tema.texto2; text: pf.texto ? "“" + pf.texto + "”" : Ds.t("filtro.semTexto") }
        }
        Marcador { texto: Ds.t("filtro.conteudo"); marcado: pf.conteudo; onAlternado: (v) => pf.conteudo = v }
        Linha {
            rotulo: Ds.t("filtro.tipo")
            Repeater {
                model: ["", "imagem", "video", "audio", "documento", "codigo", "compactado"]
                Chip { required property string modelData; texto: modelData ? Ds.t("tipo." + modelData) : Ds.t("filtro.todos"); ativo: pf.grupo === modelData; onClicado: pf.grupo = modelData }
            }
        }
        Linha {
            rotulo: Ds.t("filtro.data")
            Repeater {
                model: [0, 1, 7, 30, 365]
                Chip { required property int modelData; texto: Ds.t("filtro.d" + modelData); ativo: pf.desdeDias === modelData; onClicado: pf.desdeDias = modelData }
            }
        }
        Linha {
            rotulo: Ds.t("filtro.tamanho")
            Repeater {
                model: 4
                Chip { required property int index; texto: Ds.t("filtro.t" + index); ativo: pf.faixa === index; onClicado: pf.faixa = index }
            }
        }
        Linha {
            rotulo: Ds.t("filtro.tag")
            visible: (arquivos.tagsConhecidas || []).length > 0
            Repeater {
                model: [""].concat(arquivos.tagsConhecidas || [])
                Chip { required property string modelData; texto: modelData || Ds.t("filtro.todas"); cor: Tema.secundaria; ativo: pf.tag === modelData; onClicado: pf.tag = modelData }
            }
        }
        Linha {
            rotulo: Ds.t("filtro.avaliacao")
            Repeater {
                model: [0, 2, 4, 6, 8, 10]
                Chip { required property int modelData; texto: modelData ? "★".repeat(modelData / 2) + "+" : Ds.t("filtro.todas"); ativo: pf.avaliacaoMin === modelData; onClicado: pf.avaliacaoMin = modelData }
            }
        }
        Row {
            spacing: 8
            anchors.right: parent.right
            Botao { text: Ds.t("filtro.limpar"); tipo: "sutil"; tamanho: 11; onClicado: pf.limpar() }
            Botao { text: Ds.t("filtro.buscar"); tipo: "primario"; tamanho: 11; habilitado: pf.texto.trim() !== "" || pf.temFiltro; onClicado: pf.buscar() }
        }
    }
}
