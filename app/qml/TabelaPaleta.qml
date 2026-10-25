import QtQuick

// Tabela da paleta de uma corporação: amostra, papel e hex de destaque, secundária, alerta e fundo.
Column {
    id: t
    property var paleta: ({})
    property bool compacta: false      // duas colunas (cartões estreitos)
    spacing: 4

    readonly property var linhas: [
        { chave: "destaque", rotulo: Txt.t("paleta.destaque") },
        { chave: "secundaria", rotulo: Txt.t("paleta.secundaria") },
        { chave: "alerta", rotulo: Txt.t("paleta.alerta") },
        { chave: "fundo", rotulo: Txt.t("paleta.fundo") }
    ]

    Grid {
        columns: t.compacta ? 2 : 1
        columnSpacing: 12
        rowSpacing: 4
        width: t.width
        Repeater {
            model: t.linhas
            Row {
                id: ln
                required property var modelData
                readonly property string hex: (t.paleta[modelData.chave] || "").toString().toUpperCase()
                width: t.compacta ? (t.width - 12) / 2 : t.width
                spacing: 8
                Rectangle {
                    width: 16; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: ln.hex || "transparent"
                    border.width: 1
                    border.color: Tema.alfa(Tema.texto, ln.modelData.chave === "fundo" ? 0.35 : 0.0)
                    Behavior on color { ColorAnimation { duration: Tema.rapido } }
                }
                Codigo {
                    text: ln.modelData.rotulo
                    tamanho: 9
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                }
                Codigo {
                    text: ln.hex
                    tamanho: 10
                    color: Tema.texto2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
