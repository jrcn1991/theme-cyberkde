import QtQuick
import "Atividades.js" as A

// Os cartões dos módulos; um módulo aberto mostra as leituras e as ações.
Rolagem {
    id: p
    property var foco: null                 // módulo aberto
    signal voltar()
    Grid {
        visible: !p.foco
        width: parent.width; columns: 2; spacing: 8
        Repeater {
            model: p.foco ? [] : p.ui.modulos
            Surge {
                id: card
                required property var modelData
                required property int index
                ui: p.ui; ordem: index
                width: (parent.width - 8) / 2; height: 104
                readonly property var pr: (modelData.readings || [])[0]
                readonly property var se: (modelData.readings || [])[1]
                Rectangle {
                    anchors.fill: parent; radius: p.ui.tema.raioCartao; color: mc.containsMouse ? p.ui.tema.ativo : p.ui.tema.hover
                    MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.abrirModulo(card.modelData.id) }
                    Column {
                        x: 14; y: 12; width: parent.width - 28; spacing: 4
                        Row { spacing: 6; Glifo { nome: card.modelData.icon; cor: p.ui.tema.texto2 } Text { text: card.modelData.name; color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 11 } }
                        Text { width: parent.width; elide: Text.ElideRight; text: !card.modelData.ok || !card.pr ? "" : card.pr.value === "nada" ? p.ui.txt("Nada tocando") : card.pr.value; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 15; font.weight: Font.DemiBold; visible: text !== "" }
                        Text { width: parent.width; elide: Text.ElideRight; color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11
                            text: !card.modelData.ok || !card.pr ? (card.modelData.error || p.ui.txt("sem dado")) : (card.pr.detail && card.pr.detail !== card.pr.label ? card.pr.detail : (card.se ? card.se.value : card.pr.label)) }
                        Barra { visible: !!card.pr && card.pr.ratio != null && card.modelData.ok; ui: p.ui; width: parent.width; razao: card.pr ? card.pr.ratio || 0 : 0; nivel: card.pr ? card.pr.level : "ok" }
                    }
                }
            }
        }
    }
    // ---- o módulo aberto
    readonly property bool ehMidia: !!p.foco && p.foco.id === "midia"
    Row {
        visible: !!p.foco
        spacing: 8
        Acao { ui: p.ui; glifo: "CaretLeft"; onClicado: p.voltar() }
        Text { anchors.verticalCenter: parent.verticalCenter; text: p.foco ? p.foco.name : ""; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 15; font.weight: Font.DemiBold }
    }
    // mídia: tela própria, com controles, saídas e letra
    Item {
        visible: p.ehMidia
        width: parent.width; height: 72
        readonly property var toc: p.ui.ler("midia", "midia-tocando")
        readonly property bool nada: !toc || A.nada(toc.value)
        Image { id: capaM; width: 64; height: 64; fillMode: Image.PreserveAspectCrop; source: !parent.nada && parent.toc.art ? parent.toc.art : ""; asynchronous: true; cache: false }
        Rectangle { visible: capaM.status !== Image.Ready; width: 64; height: 64; radius: 12; color: p.ui.tema.ativo; Glifo { anchors.centerIn: parent; nome: "MusicNotes"; tamanho: 24; cor: p.ui.tema.texto3 } }
        Column {
            x: 76; width: parent.width - 76; spacing: 2
            Text { width: parent.width; elide: Text.ElideRight; text: parent.parent.nada ? p.ui.txt("Nada tocando") : parent.parent.toc.value; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: parent.parent.nada ? p.ui.txt("abra um player e ele aparece aqui") : parent.parent.toc.detail; color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
            Text { width: parent.width; elide: Text.ElideRight; text: p.ui.valor("midia", "midia-player"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
        }
    }
    Column {
        readonly property var prog: p.ui.ler("midia", "midia-progresso")
        visible: p.ehMidia && !!prog
        width: parent.width; spacing: 4
        Barra { ui: p.ui; width: parent.width; razao: parent.prog ? parent.prog.ratio || 0 : 0; tinta: true }
        Item {
            width: parent.width; height: 14
            Text { text: p.ui.tempos(0); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
            Text { anchors.right: parent.right; text: p.ui.tempos(1); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
        }
    }
    Flow {
        visible: p.ehMidia
        width: parent.width; spacing: 6
        readonly property bool toca: p.ui.tocando
        AcaoLarga { ui: p.ui; glifo: "SkipBack"; onClicado: p.ui.agir("midia-anterior") }
        AcaoLarga { ui: p.ui; glifo: parent.toca ? "Pause" : "Play"; onClicado: p.ui.agir("midia-alternar") }
        AcaoLarga { ui: p.ui; glifo: "SkipForward"; onClicado: p.ui.agir("midia-proxima") }
        AcaoLarga { ui: p.ui; glifo: "ArrowSquareOut"; onClicado: p.ui.agir("midia-abrir") }
        AcaoLarga { ui: p.ui; glifo: "Shuffle"; onClicado: p.ui.agir("midia-embaralhar") }
        AcaoLarga { ui: p.ui; glifo: "Repeat"; onClicado: p.ui.agir("midia-repetir") }
        AcaoLarga { ui: p.ui; glifo: "Link"; onClicado: p.ui.agir("midia-copiar-link") }
    }
    Flow {
        readonly property var saidas: p.ui.json("audio", "saidas-audio")
        visible: p.ehMidia && saidas.length > 1
        width: parent.width; spacing: 6
        Repeater {
            model: parent.visible ? parent.saidas : []
            AcaoLarga {
                required property var modelData
                ui: p.ui; ativa: modelData.descricao === p.ui.valor("audio", "saida-audio")
                texto: { const s = String(modelData.descricao || modelData.nome || ""); return /hdmi/i.test(s) ? "HDMI" : /usb/i.test(s) ? "USB" : /blue/i.test(s) ? "Bluetooth" : s.length > 28 ? s.slice(0, 27) + "…" : s }
                onClicado: p.ui.agir("audio-definir-saida", modelData.nome)
            }
        }
    }
    Column {
        readonly property var letra: p.ui.snap ? p.ui.snap.lyrics : null
        visible: p.ehMidia && !!letra && letra.length > 0
        width: parent.width; spacing: 3
        Repeater {
            model: parent.visible ? parent.letra : []
            Text {
                required property var modelData
                width: parent.width; wrapMode: Text.Wrap; text: modelData.text
                readonly property bool atual: modelData.text === p.ui.linhaLetra
                color: atual ? p.ui.tinta : p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: atual ? 15 : 13; font.weight: atual ? Font.DemiBold : Font.Normal
            }
        }
    }
    // foco: os sete dias
    FocoSemana { visible: !!p.foco && p.foco.id === "foco"; ui: p.ui; width: parent.width }
    // discos: volumes removíveis
    Repeater {
        model: p.foco && p.foco.id === "discos" ? p.ui.volumes() : []
        Item {
            id: dv
            required property var modelData
            width: parent.width; height: 40
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: p.ui.tema.hover }
            Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "Usb"; cor: p.ui.tema.texto2 }
            Text { x: 34; width: parent.width - 34 - acoesD.width - 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13
                text: (dv.modelData.label || dv.modelData.nomeDisco || dv.modelData.device) + "  ·  " + (dv.modelData.mountpoint || p.ui.txt("não montado")) }
            Row {
                id: acoesD
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                Acao { visible: !dv.modelData.mountpoint; ui: p.ui; glifo: "Plug"; onClicado: p.ui.agir("disco-montar", dv.modelData.device) }
                Acao { visible: !!dv.modelData.mountpoint; ui: p.ui; glifo: "FolderOpen"; onClicado: p.ui.agir("disco-abrir", dv.modelData.mountpoint) }
                Acao { ui: p.ui; glifo: "Eject"; pendente: p.ui.pendente("disco-ejetar"); onClicado: p.ui.agir("disco-ejetar", dv.modelData.disco) }
            }
        }
    }
    Repeater {
        model: p.foco && !p.ehMidia ? (p.foco.readings || []).filter(l => l.id !== "discos-lista" && l.id !== "saidas-audio") : []
        Surge {
            id: li
            required property var modelData
            required property int index
            ui: p.ui; ordem: index
            width: parent.width; height: cl.implicitHeight + 16
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: p.ui.tema.hover }
            Column {
                id: cl
                x: 12; y: 8; width: parent.width - 24; spacing: 2
                Text { text: li.modelData.label; color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                Text { width: parent.width; wrapMode: Text.Wrap; text: li.modelData.value; color: li.modelData.level === "ok" ? p.ui.tema.texto : p.ui.tema[li.modelData.level]; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
                Text { visible: !!li.modelData.detail; width: parent.width; wrapMode: Text.Wrap; text: String(li.modelData.detail).replace(/;/g, " · "); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                Barra { visible: li.modelData.ratio != null; ui: p.ui; width: parent.width; razao: li.modelData.ratio || 0; nivel: li.modelData.level }
            }
        }
    }
    Text { visible: !!p.foco && (p.foco.readings || []).length === 0; text: p.foco ? (p.foco.error || p.ui.txt("sem dado")) : ""; color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
    Flow {
        visible: !!p.foco && !p.ehMidia
        width: parent.width; spacing: 6
        Repeater {
            model: p.foco && !p.ehMidia ? p.foco.actions || [] : []
            AcaoLarga { required property var modelData; ui: p.ui; glifo: modelData.icon; texto: modelData.label; ativa: modelData.active === true; onClicado: p.ui.agir(modelData.id) }
        }
    }
    Flow {
        visible: !!p.foco && p.foco.id === "desktop"
        width: parent.width; spacing: 6
        Text { text: p.ui.txt("Cafeína por"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 12; height: 28; verticalAlignment: Text.AlignVCenter }
        Repeater {
            model: [30, 60, 120, 240]
            AcaoLarga { required property int modelData; ui: p.ui; texto: modelData < 60 ? p.ui.txt("{n} min", { n: modelData }) : p.ui.txt("{n} h", { n: modelData / 60 }); onClicado: p.ui.agir("cafeina-alternar", String(modelData)) }
        }
    }
}
