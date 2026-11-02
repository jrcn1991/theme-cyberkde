import QtQuick

// Seção ILHA: liga e desliga o efeito "ilha" e mostra tudo o que ilha.json oferece. As opções vêm do
// esquema do app (cyberkde-ilha.py --esquema): chave que ele não conhece não aparece.
Secao {
    id: s
    readonly property var d: painel.ilhaDados
    readonly property var cfg: d.config || ({})
    readonly property var efeito: painel.efeitoIlha.id ? painel.efeitoIlha : null
    readonly property bool ligada: efeito ? efeito.ligado === true : false
    readonly property bool ocupado: painel.alvosNaFila.indexOf("ilha") >= 0 || painel.alvo === "ilha" || painel.alvosNaFila.indexOf("fx:ilha") >= 0 || painel.alvo === "fx:ilha"
    onAtivaChanged: if (ativa) Qt.callLater(painel.ilhaLer)
    function ops(k) { return (d.esquema || []).find(o => o.chave === k) || null }
    function nome(k) { const o = ops(k); return o ? (painel.idioma === "en" ? o.nome_en : o.nome) : k }
    function val(k) { const o = ops(k); return cfg[k] !== undefined ? cfg[k] : (o ? o.padrao : undefined) }
    function definir(k, v) { painel.ilhaDefinir(k, JSON.stringify(v)) }
    readonly property var temaAtual: (d.temas || []).find(t => t.id === val("tema")) || null
    readonly property bool lado: corpo.width >= 940
    readonly property real col: lado ? (corpo.width - 20) / 2 : corpo.width

    component Liga: Row {
        id: li
        property string k: ""
        property string texto: ""
        visible: !!s.ops(k)
        spacing: 10
        width: parent ? parent.width : 300
        Interruptor {
            anchors.verticalCenter: parent.verticalCenter
            ligado: s.val(li.k) === true
            onAlternado: (n) => s.definir(li.k, n)
        }
        Leitura { width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; tamanho: 13; text: li.texto || s.nome(li.k) }
    }
    component Escolha: Column {
        id: es
        property string k: ""
        property var opcoes: []                 // [{ id, t }]
        property string ajuda: ""
        visible: !!s.ops(k)
        width: parent ? parent.width : 300
        spacing: 6
        Codigo { text: s.nome(es.k).toUpperCase(); tamanho: 9 }
        Flow {
            width: parent.width; spacing: 6
            Repeater {
                model: es.opcoes
                Botao {
                    required property var modelData
                    text: modelData.nome || Txt.t(modelData.t); tamanho: 12; implicitHeight: 28
                    tipo: String(s.val(es.k)) === modelData.id ? "primario" : "secundario"
                    onClicado: s.definir(es.k, modelData.id)
                }
            }
        }
        Leitura { visible: es.ajuda !== ""; width: parent.width; tamanho: 11; color: Tema.texto3; text: es.ajuda }
    }
    component Numero: Deslizador {
        id: nu
        property string k: ""
        property var aoFim: null
        visible: !!s.ops(k)
        rotulo: s.nome(k).toUpperCase()
        readonly property var o: s.ops(k)
        de: o && o.min !== undefined ? o.min : 0
        ate: o && o.max !== undefined ? o.max : 100
        passo: 1
        padrao: o ? o.padrao : -1
        valor: { const v = s.val(k); return v === undefined ? 0 : Number(v) }
        onMovido: (v) => { pend.v = Math.round(v); pend.restart() }
        Timer { id: pend; property int v: 0; interval: 350; onTriggered: s.definir(nu.k, v) }
    }

    // ---- topo
    Bloco {
        id: topo
        width: s.corpo.width
        titulo: Txt.t("il.titulo")
        codigo: "DESK.ISLAND // " + (s.ligada ? "ONLINE" : "STANDBY")
        destaque: s.ligada
        Cascata { ativo: s.entrando; ordem: 0; alvo: topo }
        Row {
            spacing: 12
            Interruptor {
                anchors.verticalCenter: parent.verticalCenter
                ligado: s.ligada
                ocupado: s.ocupado
                habilitado: !!s.efeito
                onAlternado: (n) => painel.aplicarOpcoes("ilha", { ligado: n })
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Rotulo { text: Txt.t("il.mostrar"); tamanho: 14 }
                Leitura { tamanho: 12; color: Tema.texto3; text: s.efeito ? Txt.t("il.ajuda") : Txt.t("il.semEfeito") }
            }
        }
        Item {
            visible: s.d.haloAtivo === true && s.val("conviverComHalo") !== true
            width: parent.width; height: avisoHalo.implicitHeight + 16
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.alerta, 0.1); borda: Tema.alerta }
            Leitura { id: avisoHalo; x: 12; y: 8; width: parent.width - 24; tamanho: 13; color: Tema.texto; text: Txt.t("il.haloAtivo") }
        }
        Row {
            spacing: 8
            Codigo { anchors.verticalCenter: parent.verticalCenter; text: Txt.t("il.testar"); tamanho: 10 }
            Repeater {
                model: [{ id: "abrir", t: "il.tAbrir" }, { id: "comum", t: "il.tAnuncio" }, { id: "hud", t: "il.tHud" }, { id: "aviso", t: "il.tAviso" }, { id: "voo", t: "il.tVoo" }]
                Botao { required property var modelData; text: Txt.t(modelData.t); tamanho: 11; tipo: "secundario"; habilitado: s.ligada; onClicado: painel.ilhaDemonstrar(modelData.id) }
            }
        }
    }

    // ---- tema
    Bloco {
        id: blTema
        width: s.corpo.width
        titulo: Txt.t("il.tema")
        codigo: (s.val("tema") || "halo").toUpperCase()
        Cascata { ativo: s.entrando; ordem: 1; alvo: blTema }
        Flow {
            id: galeria
            width: parent.width; spacing: 10
            readonly property int colunas: Math.max(2, Math.floor((width + 10) / 240))
            Repeater {
                model: s.d.temas || []
                TilePrevia {
                    required property var modelData
                    width: (galeria.width - (galeria.colunas - 1) * 10) / galeria.colunas
                    nome: modelData.nome
                    descricao: modelData.descricao
                    previa: modelData.previa
                    proporcao: 9 / 16
                    selecionado: s.val("tema") === modelData.id
                    onEscolhido: s.definir("tema", modelData.id)
                }
            }
        }
        Escolha {
            k: "estilo"
            opcoes: [{ id: "preto", t: "il.preto" }, { id: "degrade", t: "il.degrade" }, { id: "vidro", t: "il.vidro" }]
            ajuda: Txt.t("il.vidroAjuda")
        }
    }

    Flow {
        width: s.corpo.width
        spacing: 20
        // ---- aparência
        Bloco {
            id: blAp
            width: s.col
            titulo: Txt.t("il.aparencia")
            codigo: "LOOK"
            Cascata { ativo: s.entrando; ordem: 2; alvo: blAp }
            Numero { k: "alturaPilula"; width: parent.width; unidade: " px" }
            Numero { k: "opacidadeOciosa"; width: parent.width; unidade: "%" }
            Numero { k: "cantos"; width: parent.width; unidade: " px" }
            Escolha { k: "alinhamento"; opcoes: [{ id: "esquerda", t: "il.esquerda" }, { id: "centro", t: "il.centro" }, { id: "direita", t: "il.direita" }] }
            Escolha { k: "cor"; opcoes: [{ id: "tema", t: "il.corTema" }, { id: "destaque", t: "il.corDestaque" }, { id: "secundaria", t: "il.corSecundaria" }, { id: "alerta", t: "il.corAlerta" }] }
            Escolha { k: "assento"; opcoes: [{ id: "sobre", t: "il.sobre" }, { id: "abaixo", t: "il.abaixo" }] }
            Escolha {
                k: "tela"
                opcoes: [{ id: "principal", t: "il.principal" }, { id: "todas", t: "il.todas" }].concat((s.d.telas || []).map(n => ({ id: n, nome: n })))
            }
        }
        // ---- animações
        Bloco {
            id: blAn
            width: s.col
            titulo: Txt.t("il.animacoes")
            codigo: "MOTION"
            Cascata { ativo: s.entrando; ordem: 3; alvo: blAn }
            Escolha { k: "pilula"; opcoes: [{ id: "simples", t: "il.pSimples" }, { id: "satelites", t: "il.pSatelites" }]; ajuda: Txt.t("il.pAjuda") }
            Escolha { k: "layout"; opcoes: [{ id: "folha", t: "il.lFolha" }, { id: "trilho", t: "il.lTrilho" }]; ajuda: Txt.t("il.lAjuda") }
            Escolha { k: "abertura"; opcoes: [{ id: "hover", t: "il.pairar" }, { id: "clique", t: "il.clique" }] }
            Escolha {
                k: "movimento"
                ajuda: painel.reduzirAnimacoes ? Txt.t("il.reduzir") : ""
                opcoes: [{ id: "gota", t: "il.mGota" }, { id: "elastico", t: "il.mElastico" }, { id: "desliza", t: "il.mDesliza" }, { id: "expandir", t: "il.mExpandir" }, { id: "nenhuma", t: "il.mNenhuma" }]
                    .concat((s.temaAtual ? s.temaAtual.movimentos : []))
            }
            Escolha { k: "voo"; opcoes: [{ id: "sugado", t: "il.vSugado" }, { id: "foguete", t: "il.vFoguete" }, { id: "nenhuma", t: "il.mNenhuma" }] }
        }
        // ---- módulos
        Bloco {
            id: blMod
            width: s.col
            titulo: Txt.t("il.modulos")
            codigo: ((s.cfg.modulos || []).length || (s.ops("modulos") ? s.ops("modulos").valores.length : 0)) + " ON"
            Cascata { ativo: s.entrando; ordem: 4; alvo: blMod }
            Leitura { width: parent.width; tamanho: 12; color: Tema.texto3; text: Txt.t("il.modulosAjuda") }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: s.ops("modulos") ? s.ops("modulos").valores : []
                    Row {
                        id: rm
                        required property string modelData
                        readonly property var lista: s.cfg.modulos || []
                        width: (blMod.width - 48) / 2
                        spacing: 8
                        Interruptor {
                            anchors.verticalCenter: parent.verticalCenter
                            ligado: rm.lista.length === 0 || rm.lista.indexOf(rm.modelData) >= 0
                            onAlternado: (n) => {
                                const todos = s.ops("modulos").valores
                                const base = rm.lista.length ? rm.lista.slice() : todos.slice()
                                const r = n ? base.concat([rm.modelData]) : base.filter(x => x !== rm.modelData)
                                s.definir("modulos", r.length === todos.length ? [] : r)
                            }
                        }
                        Leitura { anchors.verticalCenter: parent.verticalCenter; tamanho: 13; text: Txt.t("il.mod." + rm.modelData) }
                    }
                }
            }
        }
        // ---- recursos e atalhos
        Bloco {
            id: blRec
            width: s.col
            titulo: Txt.t("il.recursos")
            codigo: "FEATURES"
            Cascata { ativo: s.entrando; ordem: 5; alvo: blRec }
            Repeater {
                model: ["hud", "avisos", "clipboard", "espectro", "api", "esconderTelaCheia", "letras", "conviverComHalo"]
                Liga { required property string modelData; k: modelData; width: blRec.width - 40 }
            }
            Codigo { text: Txt.t("il.atalhos"); tamanho: 9 }
            // o que vier do esquema: chave "atalho…" booleana liga e desliga; de texto, troca a tecla
            Repeater {
                model: (s.d.esquema || []).filter(o => o.chave.indexOf("atalho") === 0)
                Column {
                    id: ca
                    required property var modelData
                    width: blRec.width - 40
                    spacing: 4
                    Liga { visible: ca.modelData.tipo === "bool"; k: ca.modelData.chave; width: parent.width }
                    Column {
                        visible: ca.modelData.tipo !== "bool"
                        width: parent.width; spacing: 4
                        Codigo { text: s.nome(ca.modelData.chave).toUpperCase(); tamanho: 9 }
                        CampoTexto { width: parent.width; valor: String(s.val(ca.modelData.chave) || ""); onConfirmado: (t) => s.definir(ca.modelData.chave, t) }
                    }
                }
            }
            Codigo { text: s.nome("relogios").toUpperCase(); tamanho: 9 }
            CampoTexto {
                width: parent.width
                valor: (s.val("relogios") || []).join(", ")
                onConfirmado: (t) => s.definir("relogios", t.split(",").map(x => x.trim()).filter(x => x))
            }
            Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Txt.t("il.relogiosAjuda") }
        }
    }
    Leitura { visible: s.d.erro !== "" && s.d.erro !== undefined; width: s.corpo.width; tamanho: 13; color: Tema.alerta; text: s.d.erro || "" }
}
