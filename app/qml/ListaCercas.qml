import QtQuick

// As cercas: título, pasta, selo MANUAL e o interruptor de cada uma. Clicar seleciona.
Column {
    id: lc
    property var instancias: []
    property string selecionada: ""
    property bool ocupado: false
    signal escolher(string id)
    spacing: 6
    function nome(i) {
        if (i.titulo) return i.titulo
        if (i.pasta) return i.pasta.replace(/\/+$/, "").split("/").pop()
        return Txt.t("wg.cercaN", { n: i.id })
    }
    Repeater {
        model: lc.instancias
        Item {
            id: li
            required property var modelData
            readonly property bool sel: modelData.id === lc.selecionada
            width: lc.width; height: 46
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: li.sel ? Tema.selecao : (maI.containsMouse ? Tema.hover : Tema.entrada); borda: li.sel ? Tema.destaque : Tema.linha }
            MouseArea { id: maI; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lc.escolher(li.modelData.id) }
            Column {
                x: 10; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Row {
                    spacing: 6
                    width: parent.width
                    Text { width: Math.min(implicitWidth, parent.width - (selo.visible ? selo.width + 6 : 0)); text: lc.nome(li.modelData); elide: Text.ElideRight; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
                    Rectangle {
                        id: selo
                        visible: li.modelData.manual === true
                        anchors.verticalCenter: parent.verticalCenter
                        width: tSelo.implicitWidth + 8; height: 15
                        color: "transparent"; border.color: Tema.secundaria
                        Codigo { id: tSelo; anchors.centerIn: parent; text: Txt.t("wg.manual"); tamanho: 9; color: Tema.secundaria }
                    }
                }
                Text { width: parent.width; text: li.modelData.pasta || Txt.t("cfg.padrao"); elide: Text.ElideMiddle; font.family: Tema.fTexto; font.pixelSize: 11; color: Tema.texto3 }
            }
            Interruptor {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 72; height: 30
                ligado: li.modelData.ligado === true
                ocupado: lc.ocupado
                onAlternado: (novo) => painel.aplicarOpcoesInstancia("widget-cerca", li.modelData.id, { ligado: novo }, {})
            }
        }
    }
    Leitura {
        visible: lc.instancias.some(i => i.id === lc.selecionada && i.manual === true)
        width: lc.width; tamanho: 11; color: Tema.texto3; text: Txt.t("wg.manualDica")
    }
}
