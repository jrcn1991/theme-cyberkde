import QtQuick

// Uma opção da SYS.CONFIG, montada pelo que o "cyberkde efeito --lista --json" descreve:
//   tipo "liga"                  → interruptor
//   variantes no efeito (estilo) → miniaturas com prévia + "Padrão"
//   opção "liga" (on/off)        → interruptor
//   opção com prévias            → miniaturas
//   opção de escolha             → botões em grupo
//   opção inteira                → deslizador
// Mais a linha de ajuda (descrição), a prévia do efeito, os selos SUDO e PERSONALIZADO e o aviso de
// senha pendente (o comando "retomar" aparece no aviso do painel). Clique aplica na hora; os
// deslizadores esperam 450 ms parados.
Bloco {
    id: b
    property var dados: ({})
    property int numero: 1
    titulo: dados.nome || dados.id || ""
    codigo: "CFG-" + ("0" + numero).slice(-2) + " // " + (dados.id || "")
    destaque: b.mudado

    readonly property bool rodando: painel.alvo === "fx:" + (dados.id || "")
    readonly property bool naFila: rodando || painel.alvosNaFila.indexOf("fx:" + (dados.id || "")) >= 0
    readonly property bool mudado: dados.mudado === true || (dados.tipo === "liga" && b.ligado)

    // estado local (otimista), ressincronizado quando o CLI responde
    property bool ligado: dados.ligado === true
    property string variante: dados.variante || ""
    property var valores: ({})
    property var _pendente: ({})
    function _sincronizar() {
        if (Object.keys(_pendente).length || naFila) return
        ligado = dados.ligado === true
        variante = dados.variante || ""
        let v = {}
        for (const o of dados.opcoes || []) v[o.id] = o.valor
        valores = v
    }
    onDadosChanged: _sincronizar()
    onNaFilaChanged: if (!naFila) _sincronizar()

    function mudar(chave, valor, imediato) {
        if (chave === "ligado") ligado = valor
        else if (chave === "variante" && (dados.variantes || []).length) variante = valor === "__padrao__" ? (dados.padraoVariante || "") : valor
        else { let v = Object.assign({}, valores); v[chave] = valor; valores = v }
        let p = Object.assign({}, _pendente); p[chave] = valor; _pendente = p
        espera.interval = imediato ? 1 : 450
        espera.restart()
    }
    Timer {
        id: espera
        // manda também os valores que a tela mostra (opções que vão no comando sem ter mudado)
        onTriggered: { const p = b._pendente; b._pendente = ({}); painel.aplicarOpcoes(b.dados.id, p, b.valores) }
    }

    // selos no canto do título
    extra: [
        Rectangle {
            visible: b.dados.sudo === true
            width: sudoTx.implicitWidth + 10; height: 16
            color: "transparent"; border.color: Tema.alerta; border.width: 1
            Codigo { id: sudoTx; anchors.centerIn: parent; text: "SUDO"; tamanho: 8; color: Tema.alerta }
        },
        Rectangle {
            visible: b.mudado
            width: perTx.implicitWidth + 10; height: 16
            color: Tema.alfa(Tema.destaque, 0.15); border.color: Tema.destaque; border.width: 1
            Codigo { id: perTx; anchors.centerIn: parent; text: Txt.t("cfg.selo.personalizado"); tamanho: 8; color: Tema.destaque }
        },
        Codigo {
            visible: b.naFila
            text: b.rodando ? Txt.t("fase.estado.processando") : Txt.t("fase.estado.fila")
            tamanho: 9; color: Tema.secundaria
        }
    ]

    // linha de ajuda + interruptor (efeito do tipo liga)
    Row {
        width: parent.width
        spacing: 14
        Interruptor {
            id: chave
            visible: b.dados.tipo === "liga"
            ligado: b.ligado
            ocupado: b.rodando
            habilitado: !b.naFila
            anchors.verticalCenter: parent.verticalCenter
            onAlternado: (novo) => b.mudar("ligado", novo, true)
        }
        Leitura {
            width: parent.width - (chave.visible ? chave.width + 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: b.dados.descricao || ""
            tamanho: 12
        }
    }

    // prévia geral do efeito (ex.: comparação dos ícones)
    Item {
        visible: !!b.dados.previa
        width: parent.width
        height: visible ? Math.min(200, width * 0.32) : 0
        AnimatedImage {
            anchors.fill: parent
            source: b.dados.previa || ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: hoverPrevia.hovered && !Tema.reduzir
            paused: !playing
        }
        HoverHandler { id: hoverPrevia }
    }

    // variantes do próprio efeito (opções de estilo)
    Flow {
        visible: (b.dados.variantes || []).length > 0
        width: parent.width
        spacing: 10
        Repeater {
            model: b.dados.variantes || []
            TilePrevia {
                required property var modelData
                width: Math.min(176, (b.area.width - 40) / 5)
                nome: modelData.nome
                descricao: modelData.descricao || ""
                previa: modelData.previa || ""
                selecionado: b.variante === modelData.id
                padrao: modelData.id === b.dados.padraoVariante
                ocupado: b.rodando && b.variante === modelData.id
                onEscolhido: if (!b.naFila && b.variante !== modelData.id) b.mudar("variante", modelData.id, true)
            }
        }
    }

    // opções
    Repeater {
        model: b.dados.opcoes || []
        Column {
            id: op
            required property var modelData
            required property int index
            width: b.area.width
            spacing: 6
            readonly property string valor: b.valores[modelData.id] !== undefined ? b.valores[modelData.id] : modelData.valor
            readonly property bool temSom: modelData.forma !== "previas" && modelData.valores.some(x => !!x.som)

            Row {
                visible: op.modelData.forma !== "liga" && op.modelData.forma !== "inteiro"
                spacing: 8
                Codigo { text: op.modelData.nome.toUpperCase(); tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
                Codigo {
                    visible: op.modelData.padrao !== "" && op.valor !== op.modelData.padrao
                    text: "· " + Txt.t("cfg.padraoEh", { v: (op.modelData.valores.find(x => x.id === op.modelData.padrao) || { nome: op.modelData.padrao }).nome })
                    tamanho: 9; color: Tema.texto3
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            // liga
            Row {
                visible: op.modelData.forma === "liga"
                spacing: 12
                Interruptor {
                    ligado: op.valor === "on" || op.valor === "true"
                    habilitado: !b.naFila
                    anchors.verticalCenter: parent.verticalCenter
                    onAlternado: (novo) => b.mudar(op.modelData.id, op.modelData.valores.some(x => x.id === "true") ? (novo ? "true" : "false") : (novo ? "on" : "off"), true)
                }
                Rotulo { text: op.modelData.nome; tamanho: 14; anchors.verticalCenter: parent.verticalCenter }
            }
            // miniaturas
            Flow {
                visible: op.modelData.forma === "previas"
                width: parent.width
                spacing: 10
                Repeater {
                    model: op.modelData.forma === "previas" ? op.modelData.valores : []
                    TilePrevia {
                        required property var modelData
                        width: Math.min(176, (b.area.width - 40) / 5)
                        nome: modelData.nome
                        descricao: modelData.descricao || ""
                        previa: modelData.previa || ""
                        selecionado: op.valor === modelData.id
                        padrao: modelData.id === op.modelData.padrao
                        som: modelData.som || ""
                        onEscolhido: if (!b.naFila && op.valor !== modelData.id) b.mudar(op.modelData.id, modelData.id, true)
                    }
                }
            }
            // opção cujas escolhas têm som (ex.: "som"): sem prévia de imagem, botões com ▶ ao lado
            Flow {
                visible: op.temSom
                width: parent.width
                spacing: 8
                Repeater {
                    model: op.temSom ? op.modelData.valores : []
                    Row {
                        required property var modelData
                        spacing: 4
                        Botao {
                            text: modelData.nome; tamanho: 12; implicitHeight: 30
                            tipo: op.valor === modelData.id ? "primario" : "secundario"
                            habilitado: !b.naFila
                            onClicado: if (op.valor !== modelData.id) b.mudar(op.modelData.id, modelData.id, true)
                        }
                        BotaoSom { arquivo: modelData.som || ""; visible: !!modelData.som; anchors.verticalCenter: parent.verticalCenter; implicitHeight: 30; implicitWidth: 30 }
                    }
                }
            }
            // os sons da escolha atual, um ▶ por evento
            Column {
                readonly property var atual: op.modelData.valores.find(x => x.id === op.valor) || null
                visible: !!atual && (atual.sons || []).length > 0
                width: parent.width
                spacing: 6
                Codigo { text: Txt.t("som.lista", { n: parent.atual ? parent.atual.sons.length : 0 }); tamanho: 9 }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: parent.parent.atual ? parent.parent.atual.sons : []
                        BotaoSom { required property var modelData; arquivo: modelData.arquivo; rotulo: modelData.nome }
                    }
                }
                Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Txt.t("som.volumeNota") }
            }
            // escolha
            Flow {
                visible: op.modelData.forma === "escolha" && !op.temSom
                width: parent.width
                spacing: 6
                Repeater {
                    model: op.modelData.forma === "escolha" ? op.modelData.valores : []
                    Botao {
                        required property var modelData
                        text: modelData.nome
                        tamanho: 12
                        implicitHeight: 30
                        tipo: op.valor === modelData.id ? "primario" : "secundario"
                        habilitado: !b.naFila
                        onClicado: if (op.valor !== modelData.id) b.mudar(op.modelData.id, modelData.id, true)
                    }
                }
            }
            Leitura {
                // descrição da escolha atual (ex.: arranjos da barra)
                visible: op.modelData.forma === "escolha" && text !== ""
                width: parent.width
                tamanho: 11
                color: Tema.texto3
                text: (op.modelData.valores.find(x => x.id === op.valor) || {}).descricao || ""
            }
            // inteiro
            Deslizador {
                visible: op.modelData.forma === "inteiro"
                width: Math.min(420, parent.width)
                rotulo: op.modelData.nome.toUpperCase()
                de: Number(op.modelData.min); ate: Number(op.modelData.max); passo: Number(op.modelData.passo) || 1
                unidade: op.modelData.unidade ? " " + op.modelData.unidade : ""
                valor: op.valor === "" ? Number(op.modelData.min) : Number(op.valor)
                textoValor: op.valor === "" ? Txt.t("cfg.padrao") : Math.round(valor) + unidade
                habilitado: !b.naFila
                onMovido: (v) => b.mudar(op.modelData.id, String(v), false)
            }
        }
    }

    // ações de rodapé
    Row {
        spacing: 10
        visible: (b.dados.variantes || []).length > 0 && b.dados.definido === true
        Botao {
            text: Txt.t("cfg.voltarPadrao"); tipo: "sutil"; tamanho: 12
            habilitado: !b.naFila
            onClicado: b.mudar("variante", "__padrao__", true)
        }
    }
    Leitura {
        visible: b.dados.disponivel === false || b.dados.aviso !== ""
        width: parent.width
        tamanho: 12
        color: Tema.alerta
        text: (b.dados.aviso || "") + (b.dados.disponivel === false ? (b.dados.aviso ? " " : "") + Txt.t("fx.indisponivel") : "")
    }
    Leitura {
        visible: b.dados.sudo === true
        width: parent.width
        tamanho: 11
        color: Tema.texto3
        text: Txt.t("cfg.sudoNota")
    }
}
