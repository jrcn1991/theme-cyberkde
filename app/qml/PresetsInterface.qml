import QtQuick

// Presets de interface (estilo-preset), em destaque: miniatura grande de cada um, a descrição e a
// corporação que ele sugere (o preset não troca a cor; a sugestão leva à seção Corporação).
Bloco {
    id: b
    property var dados: ({})
    property var app
    titulo: Txt.t("cfg.presets")
    codigo: "STYLE.PRESET"
    destaque: true
    readonly property bool naFila: painel.alvo === "fx:estilo-preset" || painel.alvosNaFila.indexOf("fx:estilo-preset") >= 0
    property string _escolhido: ""
    readonly property string atual: _escolhido || dados.variante || ""
    onDadosChanged: if (!naFila) _escolhido = ""
    readonly property var escolhido: (dados.variantes || []).find(v => v.id === atual) || null

    Leitura { width: parent.width; tamanho: 12; text: b.dados.descricao || "" }
    Flow {
        width: parent.width
        spacing: 12
        Repeater {
            model: b.dados.variantes || []
            TilePrevia {
                required property var modelData
                width: Math.min(250, (b.area.width - 36) / 4)
                proporcao: 0.56
                nome: modelData.nome
                descricao: modelData.descricao || ""
                previa: modelData.previa || ""
                selecionado: b.atual === modelData.id
                padrao: modelData.id === b.dados.padraoVariante
                ocupado: b.naFila && b.atual === modelData.id
                onEscolhido: if (!b.naFila && b.atual !== modelData.id) { b._escolhido = modelData.id; painel.aplicarOpcoes("estilo-preset", { variante: modelData.id }) }
            }
        }
    }
    Row {
        visible: !!b.escolhido && !!b.escolhido.corp
        spacing: 10
        Leitura {
            anchors.verticalCenter: parent.verticalCenter
            tamanho: 12; color: Tema.texto
            text: Txt.t("cfg.presetSugere", { corp: b.escolhido ? ((painel.corps.find(c => c.id === b.escolhido.corp) || { nome: b.escolhido.corp }).nome) : "" })
        }
        Botao {
            text: Txt.t("cfg.verCorp"); tamanho: 12; tipo: "sutil"
            onClicado: if (b.app) b.app.irPara("corporacao")
        }
    }
}
