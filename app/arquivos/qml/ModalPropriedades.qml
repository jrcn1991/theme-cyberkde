import QtQuick
import "../../qml"

// Modal de PROPRIEDADES (Alt+Enter): arquivos.propriedades(caminho) é assíncrono e chega por
// propriedadesProntas. Blocos GERAL (nome editável → renomear), DATAS, PERMISSÕES (caixas rwx para
// dono/grupo/outros → alterarPermissoes em octal) e DISCO (montagem, livre/total, barra segmentada).
Modal {
    id: mpr
    property string caminho: ""
    property var p: null
    property var bits: [false, false, false, false, false, false, false, false, false]
    largura: 860
    focoInicial: "principal"; tituloNatural: true
    titulo: p ? p.nome : Ds.t("prop.lendo")
    codigo: Ds.t("modal.prop", { c: p ? p.codigo : "…" })
    onCancelado: fechar()

    // etiquetas/avaliação/comentário: do mapa, se o back-end mandar; senão, dos papéis do item na aba
    readonly property var meta: {
        if (p && (p.tags !== undefined || p.avaliacao !== undefined)) return { tags: p.tags || [], avaliacao: p.avaliacao || 0, comentario: p.comentario || "" }
        const a = arquivos.aba, i = a ? a.indiceDe(caminho) : -1
        const it = i >= 0 ? a.item(i) : null
        return it ? { tags: it.tags || [], avaliacao: it.avaliacao || 0, comentario: it.comentario || "" } : {}
    }
    function mostrar(c) {
        caminho = c; p = null
        if (!aberto) abrir()
        arquivos.propriedades(c)
    }
    Connections {
        target: arquivos
        function onPropriedadesProntas(c, mapa) {
            if (c !== mpr.caminho) return
            mpr.p = mapa
            const m = parseInt(mapa.modo || "0", 8)
            let b = []
            for (let i = 8; i >= 0; i--) b.push(((m >> i) & 1) === 1)
            mpr.bits = b
            nome.text = mapa.nome
        }
    }
    readonly property string octal: {
        let v = 0
        for (let i = 0; i < 9; i++) if (bits[i]) v |= 1 << (8 - i)
        return v.toString(8).padStart(3, "0")
    }

    component Bloco2: Item {
        id: bl
        property string titulo: ""
        default property alias conteudo: cc.data
        width: parent.width; height: cc.implicitHeight + 40
        Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.alfa(Tema.fundo, 0.45); borda: Tema.alfa(Tema.destaque, 0.35) }
        Rotulo { x: 12; y: 8; text: bl.titulo; tamanho: 13; color: Tema.destaque }
        Rectangle { x: 12; y: 28; width: 40; height: 1; color: Tema.destaque }
        Column { id: cc; x: 12; y: 34; width: parent.width - 24; spacing: 4 }
    }
    component Par: Item {
        property string r: ""
        property string v: ""
        width: parent.width; height: Math.max(16, tv.implicitHeight)
        Text { width: 110; text: parent.r; font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3 }
        Text { id: tv; x: 114; width: parent.width - 114; text: parent.v; wrapMode: Text.WrapAnywhere; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
    }

    Text { visible: !mpr.p; text: Ds.t("prop.lendo"); font.family: Tema.fMono; font.pixelSize: 12; color: Tema.secundaria }

    Row {
        visible: !!mpr.p
        width: parent.width
        spacing: 14
        Column {
            width: (parent.width - 14) / 2
            spacing: 12
            Bloco2 {
                titulo: Ds.t("prop.geral")
                Item {
                    width: parent.width; height: 26
                    Text { width: 110; anchors.verticalCenter: parent.verticalCenter; text: Ds.t("prop.nome"); font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3 }
                    Rectangle { x: 114; width: parent.width - 114; height: 24; color: Tema.entrada; border.color: nome.activeFocus ? Tema.secundaria : Tema.linha }
                    TextInput {
                        id: nome
                        x: 120; width: parent.width - 126; height: 24
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto
                        clip: true; selectByMouse: true
                        onAccepted: if (mpr.p && text !== mpr.p.nome) {
                            const e = arquivos.renomear(mpr.caminho, text)
                            if (e) Ds.janela.avisar("erro", e)
                            else { mpr.caminho = mpr.caminho.substring(0, mpr.caminho.lastIndexOf("/") + 1) + text; arquivos.propriedades(mpr.caminho) }
                        }
                    }
                }
                Par { r: Ds.t("prop.tipo"); v: mpr.p ? mpr.p.mime + " · " + mpr.p.tipo : "" }
                Par { r: Ds.t("prop.local"); v: mpr.p ? (mpr.p.local || mpr.p.pastaPai) : "" }
                Par { r: Ds.t("prop.tamanho"); v: mpr.p ? (mpr.p.tamanhoRecursivoTexto || mpr.p.tamanhoTexto) : "" }
                Par { visible: !!mpr.p && !!mpr.p.conteudo; r: Ds.t("prop.conteudo"); v: mpr.p ? (mpr.p.conteudo || "") : "" }
                Par { r: "SHARD_ID"; v: mpr.p ? mpr.p.codigo : "" }
            }
            Bloco2 {
                titulo: Ds.t("meta.titulo")
                Metadados {
                    width: parent.width
                    caminhos: [mpr.caminho]
                    tags: mpr.meta.tags || []
                    avaliacao: mpr.meta.avaliacao || 0
                    comentario: mpr.meta.comentario || ""
                }
            }
            Bloco2 {
                titulo: Ds.t("prop.datas")
                Par { r: Ds.t("prop.modificado"); v: mpr.p ? mpr.p.modificadoTexto : "" }
                Par { r: Ds.t("prop.criado"); v: mpr.p ? (mpr.p.criadoTexto || "") : "" }
                Par { r: Ds.t("prop.acessado"); v: mpr.p ? (mpr.p.acessadoTexto || "") : "" }
            }
        }
        Column {
            width: (parent.width - 14) / 2
            spacing: 12
            Bloco2 {
                titulo: Ds.t("prop.perm")
                Grid {
                    columns: 4; columnSpacing: 14; rowSpacing: 6
                    Item { width: 80; height: 16 }
                    Repeater { model: ["prop.ler", "prop.escrever", "prop.executar"]; Codigo { required property string modelData; text: Ds.t(modelData); tamanho: 11; color: Tema.texto2; width: 70 } }
                    Repeater {
                        model: 12
                        Item {
                            required property int index
                            readonly property int lin: Math.floor(index / 4)
                            readonly property int col: index % 4
                            width: col === 0 ? 80 : 70; height: 22
                            Text {
                                visible: parent.col === 0; anchors.verticalCenter: parent.verticalCenter
                                text: Ds.t(["prop.dono", "prop.grupo", "prop.outros"][parent.lin]) + (parent.lin === 0 && mpr.p ? " · " + (mpr.p.dono || "") : parent.lin === 1 && mpr.p ? " · " + (mpr.p.grupoDono || "") : "")
                                font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto2
                            }
                            // caixa rwx
                            Item {
                                visible: parent.col > 0
                                readonly property int k: parent.lin * 3 + parent.col - 1
                                width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                                Chanfro { anchors.fill: parent; corte: 4; preenchimento: mpr.bits[parent.k] === true ? Tema.destaque : Tema.entrada; borda: mpr.bits[parent.k] === true ? Tema.destaque : Tema.linha }
                                Text { anchors.centerIn: parent; visible: mpr.bits[parent.k] === true; text: "rwx"[Math.max(0, parent.k) % 3]; font.family: Tema.fMono; font.pixelSize: 10; font.bold: true; color: Tema.escuro }
                                MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: { let b = mpr.bits.slice(); b[parent.k] = !b[parent.k]; mpr.bits = b } }
                            }
                        }
                    }
                }
                // grupo (só os da usuária; trocar o dono exige root e não é feito)
                Flow {
                    width: parent.width; spacing: 4
                    Codigo { width: 80; y: 4; text: Ds.t("pv.grupoTitulo"); tamanho: 11; color: Tema.texto2 }
                    Repeater {
                        model: arquivos.gruposDisponiveis || []
                        Chip {
                            required property string modelData
                            texto: modelData; ativo: !!mpr.p && mpr.p.grupoDono === modelData
                            onClicado: { const e = arquivos.alterarGrupo([mpr.caminho], modelData); if (e) Ds.janela.avisar("erro", e); else arquivos.propriedades(mpr.caminho) }
                        }
                    }
                }
                Row {
                    spacing: 10
                    Text { anchors.verticalCenter: parent.verticalCenter; text: mpr.octal; font.family: Tema.fMono; font.pixelSize: 13; color: Tema.secundaria }
                    Botao {
                        text: Ds.t("prop.aplicar"); tamanho: 11
                        tipo: mpr.p && mpr.octal !== mpr.p.modo ? "primario" : "secundario"
                        habilitado: !!mpr.p && mpr.octal !== mpr.p.modo
                        onClicado: {
                            const e = arquivos.alterarPermissoes(mpr.caminho, mpr.octal)
                            if (e) Ds.janela.avisar("erro", e); else arquivos.propriedades(mpr.caminho)
                        }
                    }
                }
            }
            Bloco2 {
                titulo: Ds.t("prop.disco")
                Par { r: Ds.t("prop.montagem"); v: mpr.p ? (mpr.p.montagem || "") : "" }
                Par { r: ""; v: mpr.p ? Ds.t("prop.livre", { l: mpr.p.livreTexto || "?", t: mpr.p.totalTexto || "?" }) : "" }
                BarraSegmentada { width: parent.width; height: 10; valor: mpr.p ? (mpr.p.uso || 0) : 0; cor: mpr.p && mpr.p.uso > 0.9 ? Tema.alerta : Tema.destaque; larguraSeg: 6; vao: 2 }
            }
        }
    }
    acoes: [
        Botao {
            visible: !!mpr.p && !!mpr.p.mime && mpr.p.mime !== "inode/directory"
            text: Ds.t("apps.padraoBotao"); tipo: "sutil"; tamanho: 12
            onClicado: Ds.janela.escolherApp([mpr.caminho], mpr.p.mime, true)
        },
        Botao { text: Ds.t("modal.fechar"); tipo: "primario"; tamanho: 12; onClicado: mpr.fechar() }
    ]
}
