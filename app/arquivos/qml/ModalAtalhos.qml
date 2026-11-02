import QtQuick
import "../../qml"

// TELA DE ATALHOS (F1, spec 20): as ações de arquivos.atalhos com a tecla atual. "Mudar" grava a próxima
// combinação pressionada (Esc cancela) com definirAtalho(acao, seq); "Restaurar padrões" volta tudo.
// Embaixo, as teclas fixas da navegação (setas, Enter, Tab nos painéis da pilha…).
Modal {
    id: mt
    property string gravando: ""
    readonly property var lista: Object.keys(arquivos.atalhos || {}).sort((a, b) => Ds.t("at." + a).localeCompare(Ds.t("at." + b)))
    largura: 900
    focoInicial: "principal"
    titulo: Ds.t("at.titulo")
    codigo: "KEYMAP // " + lista.length
    onCancelado: { if (gravando) gravando = ""; else fechar() }
    function mostrar() { gravando = ""; abrir() }
    // grava a combinação (foco num item próprio para receber as teclas)
    Item {
        id: captura
        focus: mt.gravando !== ""
        onFocusChanged: if (focus) forceActiveFocus()
        Keys.onPressed: (e) => {
            if (!mt.gravando) return
            e.accepted = true
            if (e.key === Qt.Key_Escape) { mt.gravando = ""; return }
            const s = Ds.seqDe(e)
            if (!s) return                                  // só modificador: espera a tecla
            arquivos.definirAtalho(mt.gravando, s)
            mt.gravando = ""
        }
    }
    onGravandoChanged: if (gravando) captura.forceActiveFocus()
    Column {
        width: parent.width; spacing: 10
        Item {
            width: parent.width; height: 380
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.fundo, 0.5); borda: Tema.alfa(Tema.destaque, 0.35) }
            GridView {
                id: gv
                anchors.fill: parent; anchors.margins: 6
                clip: true; boundsBehavior: Flickable.StopAtBounds
                cellWidth: width / 2; cellHeight: 28
                model: mt.lista
                delegate: Item {
                    required property string modelData
                    width: gv.cellWidth; height: gv.cellHeight
                    readonly property bool grav: mt.gravando === modelData
                    Rectangle { anchors.fill: parent; anchors.margins: 1; color: parent.grav ? Tema.alfa(Tema.secundaria, 0.18) : hv.hovered ? Tema.hover : "transparent" }
                    Text { x: 8; width: parent.width - 190; anchors.verticalCenter: parent.verticalCenter; text: Ds.t("at." + modelData); elide: Text.ElideRight; font.family: Tema.fTexto; font.pixelSize: 12; color: Tema.texto }
                    Chip {
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        texto: parent.grav ? Ds.t("at.gravando") : ((arquivos.atalhos || {})[modelData] || "—")
                        ativo: parent.grav; cor: parent.grav ? Tema.secundaria : Tema.destaque
                        onClicado: mt.gravando = parent.grav ? "" : modelData
                    }
                    HoverHandler { id: hv }
                }
            }
        }
        Leitura { width: parent.width; tamanho: 11; color: Tema.texto3; text: Ds.t("at.fixas") }
    }
    acoes: [
        Botao { text: Ds.t("at.restaurar"); tipo: "sutil"; onClicado: arquivos.restaurarAtalhos() },
        Botao { text: Ds.t("modal.fechar"); tipo: "primario"; tamanho: 12; onClicado: mt.fechar() }
    ]
}
