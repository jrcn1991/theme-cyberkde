import QtQuick

Secao {
    id: s
    flick.interactive: false

    Item {
        width: parent.width
        height: s.height - s.margem * 2

        Row {
            id: barra
            width: parent.width
            spacing: 10
            Codigo { text: Txt.t(painel.registro.length === 1 ? "reg.linha" : "reg.linhas", { n: painel.registro.length }); anchors.verticalCenter: parent.verticalCenter; width: parent.width - 220 }
            Botao { text: Txt.t("comum.copiar"); tamanho: 12; implicitWidth: 96; onClicado: { painel.copiar(painel.registroComoTexto()); painel.notificar("ok", Txt.t("notif.registroCopiado")) } }
            Botao { text: Txt.t("comum.limpar"); tamanho: 12; implicitWidth: 96; tipo: "sutil"; onClicado: painel.limparRegistro() }
        }

        Item {
            anchors.top: barra.bottom; anchors.topMargin: 14
            anchors.bottom: parent.bottom
            width: parent.width
            Chanfro { anchors.fill: parent; corte: Tema.chanfroG; preenchimento: Tema.alfa(Tema.fundo, 0.9); borda: Tema.linha }
            ListView {
                id: lista
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                model: painel.registro
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: positionViewAtEnd()
                Component.onCompleted: positionViewAtEnd()
                delegate: Row {
                    id: ln
                    required property var modelData
                    width: lista.width
                    spacing: 12
                    readonly property color cor: modelData.nivel === "erro" ? Tema.erro : modelData.nivel === "aviso" ? Tema.alerta : modelData.nivel === "ok" ? Tema.sucesso : Tema.texto2
                    Text {
                        text: ln.modelData.hora
                        font.family: Tema.fMono; font.pixelSize: 12
                        color: Tema.texto3
                    }
                    Rectangle { width: 2; height: 14; y: 2; color: ln.cor }
                    Text {
                        width: ln.width - 100
                        text: ln.modelData.texto
                        font.family: Tema.fMono; font.pixelSize: 12
                        color: ln.modelData.nivel === "info" ? Tema.texto2 : Tema.texto
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
            Rectangle {
                visible: lista.contentHeight > lista.height
                anchors.right: parent.right; anchors.rightMargin: 4
                width: 3
                y: 14 + lista.visibleArea.yPosition * (lista.height)
                height: Math.max(24, lista.visibleArea.heightRatio * lista.height)
                color: Tema.alfa(Tema.destaque, 0.5)
            }
        }
    }
}
