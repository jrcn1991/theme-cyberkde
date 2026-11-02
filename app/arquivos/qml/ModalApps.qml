import QtQuick
import "../../qml"

// "OUTRO APLICATIVO…" / "DEFINIR COMO PADRÃO" (spec 20): todos os apps instalados (todosApps), com filtro
// por nome. Clique escolhe; "Abrir" abre com ele (e, marcado, vira o padrão do tipo: definirAppPadrao).
// No modo "padrao" o botão só define o padrão.
Modal {
    id: ma
    property var arquivosAlvo: []
    property string mime: ""
    property bool soPadrao: false
    property var apps: []
    property string escolhido: ""
    largura: 640
    titulo: soPadrao ? Ds.t("apps.padraoTitulo") : Ds.t("apps.titulo")
    codigo: "XDG.MIME // " + (mime || "?").toUpperCase()
    onCancelado: fechar()
    function pedir(lista, tipoMime, padrao) {
        arquivosAlvo = lista || []; mime = tipoMime || ""; soPadrao = !!padrao
        escolhido = ""; filtro.texto = ""; marcaPadrao.marcado = soPadrao
        apps = arquivos.todosApps() || []
        abrir(); Qt.callLater(filtro.focar)
    }
    readonly property var visiveis: apps.filter(a => !filtro.texto || a.nome.toLowerCase().indexOf(filtro.texto.toLowerCase()) >= 0)
    function ok() {
        if (!escolhido) return
        if (marcaPadrao.marcado && mime) { const e = arquivos.definirAppPadrao(mime, escolhido); if (e) Ds.janela.avisar("erro", e) }
        if (!soPadrao) for (const c of arquivosAlvo) arquivos.abrirCom(c, escolhido)
        fechar()
    }
    Column {
        width: parent.width; spacing: 8
        Campo { id: filtro; width: parent.width; dica: Ds.t("apps.filtrar"); onAceito: { if (ma.visiveis.length === 1) ma.escolhido = ma.visiveis[0].id; ma.ok() } }
        Item {
            width: parent.width; height: 300
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.fundo, 0.5); borda: Tema.alfa(Tema.destaque, 0.35) }
            ListView {
                id: lv
                anchors.fill: parent; anchors.margins: 4
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: ma.visiveis
                delegate: Item {
                    required property var modelData
                    width: lv.width; height: 30
                    readonly property bool sel: ma.escolhido === modelData.id
                    Rectangle { anchors.fill: parent; color: parent.sel ? Tema.alfa(Tema.destaque, 0.25) : hv.hovered ? Tema.hover : "transparent" }
                    Icone { x: 8; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter; fonte: modelData.icone ? "image://icone/" + modelData.icone : ""; cor: Tema.destaque }
                    Text { x: 36; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
                    HoverHandler { id: hv }
                    TapHandler { onTapped: ma.escolhido = modelData.id; onDoubleTapped: { ma.escolhido = modelData.id; ma.ok() } }
                }
            }
        }
        Marcador { id: marcaPadrao; visible: !!ma.mime && ma.mime !== "inode/directory"; texto: Ds.t("apps.lembrar") }
    }
    acoes: [
        Botao { text: Ds.t("conf.cancelar"); tipo: "sutil"; onClicado: ma.fechar() },
        Botao { text: ma.soPadrao ? Ds.t("apps.definir") : Ds.t("modal.abrir"); tipo: "primario"; habilitado: ma.escolhido !== ""; onClicado: ma.ok() }
    ]
}
