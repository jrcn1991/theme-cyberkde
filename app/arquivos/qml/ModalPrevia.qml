import QtQuick
import "../../qml"

// Modal de PRÉVIA (Espaço / duplo clique em arquivo visualizável), no desenho do "Modal do projeto alt3":
// à esquerda a lista de dados (rótulo · valor, como a lista nome · hex), à direita a prévia pelo tipo
// de arquivos.previa(): imagem (zoom com a roda, 1:1 com a tecla 1), texto/código (mono, linhas
// numeradas), vídeo/áudio (MediaPlayer, barra segmentada, volume; áudio com espectro decorativo),
// pdf (miniatura + abrir), hex (grade de células, losango nos bytes nulos), pasta (grade 3×4 de
// losangos com as 12 primeiras entradas). ←/→ passam para o vizinho (o Main chama vizinho()).
Modal {
    id: mp
    property string caminho: ""
    property var det: ({})
    property var pv: ({})
    property real zoom: 0            // 0 = ajustar
    largura: 1180
    focoInicial: "principal"; tituloNatural: true
    titulo: det.nome || ""
    codigo: "BD_" + (det.codigo || "0x000000").slice(2) + "_0000000" + (det.codigo || "121").slice(-3)
    cor: Tema.destaque
    onCancelado: fechar()
    signal vizinho(int d)

    function mostrar(c) {
        caminho = c
        det = arquivos.detalhes(c)
        pv = arquivos.previa(c)
        zoom = 0
        if (!aberto) abrir()
        const ehMidia = pv.tipo === "video" || pv.tipo === "audio"
        if (ehMidia) midia.active = true
        if (midia.item) {
            if (midia.item.source != "") midia.item.parar()
            midia.item.source = ehMidia ? pv.url : ""
        }
    }
    onAbertoChanged: if (!aberto && midia.item) { midia.item.parar(); midia.item.source = "" }
    // Espaço: no vídeo/áudio alterna tocar/pausar; nos outros tipos fecha a prévia
    function espaco() {
        if ((pv.tipo === "video" || pv.tipo === "audio") && midia.item) midia.item.alternar()
        else fechar()
    }

    readonly property real alturaCorpo: Math.min(560, (parent ? parent.height : 800) - 260)

    Row {
        width: parent.width; height: mp.alturaCorpo
        spacing: 20

        // ---- dados (rótulo · valor)
        Item {
            id: dados
            width: 330; height: parent.height
            Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.alfa(Tema.fundo, 0.5); borda: Tema.alfa(Tema.destaque, 0.4) }
            Codigo { x: 12; y: 10; text: "BD_" + (mp.det.codigo || "").slice(2) + "A_000000000121"; tamanho: 9; color: Tema.destaque }
            Column {
                x: 12; y: 32; width: parent.width - 24
                spacing: 5
                Repeater {
                    model: Ds.linhasDe(mp.det)
                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width; height: Math.max(vt.implicitHeight, 16)
                        Text { width: 112; text: modelData.rotulo; font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3; elide: Text.ElideRight }
                        Text { id: vt; x: 116; width: parent.width - 116; text: modelData.valor; wrapMode: Text.WrapAnywhere; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 26; x: 12; width: parent.width - 24; height: 2; color: Tema.destaque }
            Codigo { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; x: 12; text: "SYS.CLASS OFFICERS ARE ALLOWED TO MANIPULATE // " + (mp.pv.tipo || "").toUpperCase(); tamanho: 8 }
        }

        // ---- prévia
        Item {
            id: area
            width: parent.width - dados.width - 20; height: parent.height
            clip: true
            Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.alfa(Tema.fundo, 0.7); borda: Tema.alfa(Tema.destaque, 0.4) }

            // imagem
            Flickable {
                id: fi
                visible: mp.pv.tipo === "imagem"
                anchors.fill: parent; anchors.margins: 8
                contentWidth: Math.max(width, img.width); contentHeight: Math.max(height, img.height)
                clip: true
                Image {
                    id: img
                    source: mp.pv.tipo === "imagem" ? mp.pv.url : ""
                    asynchronous: true
                    readonly property real fit: Math.min(fi.width / Math.max(1, sourceSize.width), fi.height / Math.max(1, sourceSize.height), 1)
                    readonly property real esc: mp.zoom > 0 ? mp.zoom : fit
                    width: sourceSize.width * esc; height: sourceSize.height * esc
                    x: Math.max(0, (fi.width - width) / 2); y: Math.max(0, (fi.height - height) / 2)
                    smooth: true
                }
                MouseArea {
                    anchors.fill: parent
                    onWheel: (w) => { mp.zoom = Math.max(0.05, Math.min(8, (mp.zoom > 0 ? mp.zoom : img.fit) * (w.angleDelta.y > 0 ? 1.2 : 1 / 1.2))) }
                }
            }
            Codigo {
                visible: mp.pv.tipo === "imagem"
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                text: Ds.t("prev.dim", { l: mp.pv.largura || 0, a: mp.pv.altura || 0 }) + " · " + Math.round((mp.zoom > 0 ? mp.zoom : img.fit) * 100) + "%  [1] 1:1"
                tamanho: 9; color: Tema.texto2
            }

            // texto / código
            ListView {
                visible: mp.pv.tipo === "texto" || mp.pv.tipo === "codigo"
                anchors.fill: parent; anchors.margins: 10
                clip: true
                model: visible ? (mp.pv.texto || "").split("\n") : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Row {
                    required property int index
                    required property string modelData
                    spacing: 10
                    Text { width: 40; horizontalAlignment: Text.AlignRight; text: index + 1; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto3 }
                    Text {
                        text: modelData.length ? modelData : " "
                        font.family: Tema.fMono; font.pixelSize: 12
                        // comentário em texto2 (só se a linguagem for conhecida)
                        color: mp.pv.linguagem && /^\s*(#|\/\/)/.test(modelData) ? Tema.texto3 : Tema.texto
                    }
                }
                footer: Text { visible: !!mp.pv.truncado; text: Ds.t("prev.truncado"); font.family: Tema.fMono; font.pixelSize: 11; color: Tema.alerta }
            }

            // vídeo / áudio: no próprio arquivo, carregado na primeira mídia aberta (ver PrevMidia.qml)
            Loader {
                id: midia
                anchors.fill: parent
                active: false
                source: "PrevMidia.qml"
                onLoaded: item.modal = mp
            }

            // pdf
            Column {
                visible: mp.pv.tipo === "pdf"
                anchors.centerIn: parent
                spacing: 14
                Image { id: miniPdf; source: mp.pv.miniatura || ""; sourceSize.height: 360; visible: status === Image.Ready && implicitWidth > 1; anchors.horizontalCenter: parent.horizontalCenter }
                // sem miniatura, ou miniatura que falhou (PDF inválido): o losango do tipo
                CelulaLosango { visible: !miniPdf.visible; width: 140; height: 160; rotulo: "PDF"; anchors.horizontalCenter: parent.horizontalCenter }
                Botao { text: Ds.t("modal.abrir"); icone: "↗"; tipo: "primario"; anchors.horizontalCenter: parent.horizontalCenter; onClicado: arquivos.abrir(mp.caminho) }
            }

            // hex: 16 colunas de células, losango nos bytes nulos
            Flickable {
                visible: mp.pv.tipo === "hex"
                anchors.fill: parent; anchors.margins: 12
                contentHeight: hexCol.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: hexCol
                    spacing: 3
                    Repeater {
                        model: mp.pv.tipo === "hex" ? mp.pv.hex : []
                        Row {
                            required property var modelData
                            spacing: 3
                            Text { width: 70; text: modelData.offset; font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto3; anchors.verticalCenter: parent.verticalCenter }
                            Repeater {
                                model: modelData.bytes
                                Item {
                                    required property int modelData
                                    width: 26; height: 20
                                    Chanfro { anchors.fill: parent; corte: 4; preenchimento: Tema.alfa(Tema.destaque, modelData === 0 ? 0.04 : 0.1); borda: Tema.alfa(Tema.destaque, 0.35) }
                                    Rectangle { visible: modelData === 0; anchors.centerIn: parent; width: 6; height: 6; rotation: 45; color: "transparent"; border.color: Tema.destaque }
                                    Text { visible: modelData !== 0; anchors.centerIn: parent; text: modelData.toString(16).toUpperCase().padStart(2, "0"); font.family: Tema.fMono; font.pixelSize: 10; color: Tema.texto }
                                }
                            }
                            Text { text: modelData.ascii; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // pasta: grade 3×4 de losangos
            Column {
                visible: mp.pv.tipo === "pasta"
                x: 18; y: 14
                width: parent.width - 36
                spacing: 10
                Row {
                    spacing: 12
                    Rotulo { text: "BD_" + (mp.det.codigo || "").slice(2) + "_" + String((mp.pv.amostra || []).length).padStart(9, "0"); tamanho: 15; color: Tema.destaque }
                    Codigo { anchors.verticalCenter: parent.verticalCenter; text: Ds.t("prev.amostra", { n: (mp.pv.amostra || []).length }); tamanho: 9 }
                }
                Grid {
                    columns: 4; spacing: 8
                    Repeater {
                        model: mp.pv.tipo === "pasta" ? mp.pv.amostra : []
                        CelulaLosango {
                            required property var modelData
                            width: (area.width - 36 - 24) / 4; height: Math.min(110, (mp.alturaCorpo - 70) / 3 - 8)
                            rotulo: modelData.nome
                            aceso: modelData.ehPasta
                            icone: "image://icone/" + modelData.icone
                        }
                    }
                }
            }

            Text {
                visible: ["imagem", "texto", "codigo", "video", "audio", "pdf", "hex", "pasta"].indexOf(mp.pv.tipo) < 0
                anchors.centerIn: parent
                text: Ds.t("prev.semPrevia"); font.family: Tema.fTexto; font.pixelSize: 14; color: Tema.texto3
            }
        }
    }
    acoes: [
        Botao { text: "◂"; tipo: "sutil"; tamanho: 12; onClicado: mp.vizinho(-1) },
        Botao { text: "▸"; tipo: "sutil"; tamanho: 12; onClicado: mp.vizinho(1) },
        Botao { text: Ds.t("modal.abrir"); icone: "↗"; tipo: "secundario"; tamanho: 12; onClicado: arquivos.abrir(mp.caminho) },
        Botao { text: Ds.t("modal.fechar"); tipo: "primario"; tamanho: 12; onClicado: mp.fechar() }
    ]
}
