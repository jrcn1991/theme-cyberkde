import QtQuick

Secao {
    id: s
    readonly property string atual: painel.papel || (painel.papeisDoTema.length ? painel.papeisDoTema[0].url : "")

    Row {
        width: parent.width
        spacing: 20

        Bloco {
            id: bl
            width: parent.width * 0.62
            titulo: Txt.t("papel.desktop")
            codigo: painel.papel ? Txt.t("papel.personalizado") : Txt.t("papel.doTema")
            Cascata { ativo: s.entrando; ordem: 0; vertical: true; alvo: bl }
            Item {
                id: quadro
                width: parent.width
                height: width * 9 / 16
                Rectangle { anchors.fill: parent; color: Tema.entrada }
                Image {
                    id: img
                    anchors.fill: parent
                    anchors.margins: 1
                    source: s.atual
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 1280
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tema.padrao } }
                }
                Cantoneiras { cor: Tema.destaque; tamanho: 16; espessura: 2; recuo: 4 }
                // varredura ao trocar a imagem
                Rectangle {
                    id: linha
                    width: parent.width; height: 2
                    color: Tema.secundaria
                    visible: false
                }
                Connections {
                    target: img
                    function onStatusChanged() {
                        if (img.status === Image.Ready && !Tema.reduzir) varre.restart()
                    }
                }
                SequentialAnimation {
                    id: varre
                    PropertyAction { target: linha; property: "visible"; value: true }
                    NumberAnimation { target: linha; property: "y"; from: 0; to: quadro.height; duration: 520; easing.type: Easing.InOutQuad }
                    PropertyAction { target: linha; property: "visible"; value: false }
                }
                Codigo {
                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                    text: img.status === Image.Ready ? decodeURIComponent(String(img.source).split("/").pop()).toUpperCase() : Txt.t("comum.carregando")
                    color: Tema.texto
                    style: Text.Outline; styleColor: Tema.escuro
                }
            }
            Leitura {
                width: parent.width
                color: Tema.texto2
                text: painel.papelCaminho ? painel.papelCaminho : Txt.t("papel.usandoTema")
                elide: Text.ElideMiddle
                wrapMode: painel.papelCaminho ? Text.NoWrap : Text.Wrap
            }
            Row {
                spacing: 10
                Botao {
                    text: Txt.t("papel.escolher"); icone: "▣"; tipo: "primario"
                    habilitado: !painel.ocupado
                    onClicado: s.app.escolherPapel()
                }
                Botao {
                    text: Txt.t("papel.voltar")
                    habilitado: !painel.ocupado && painel.papel !== ""
                    onClicado: painel.papelPadrao()
                }
            }
            Leitura {
                width: parent.width
                tamanho: 12
                color: Tema.texto3
                text: painel.temaLigado
                    ? Txt.t("papel.ligado")
                    : Txt.t("papel.desligado")
            }
        }

        Column {
            width: parent.width * 0.38 - 20
            spacing: 14
            Rotulo { id: rt; text: Txt.t("papel.imagensTema"); tamanho: 17; color: Tema.texto2; Cascata { ativo: s.entrando; ordem: 1; alvo: rt } }
            Repeater {
                model: painel.papeisDoTema
                Item {
                    id: mini
                    required property var modelData
                    required property int index
                    width: parent.width; height: width * 9 / 16 + 26
                    Cascata { ativo: s.entrando; ordem: 2 + mini.index; alvo: mini }
                    Chanfro { width: parent.width; height: parent.height - 26; preenchimento: Tema.entrada; borda: Tema.linha }
                    Image {
                        x: 1; y: 1
                        width: parent.width - 2; height: parent.height - 28
                        source: mini.modelData.url
                        sourceSize.width: 480
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Row {
                        anchors.bottom: parent.bottom
                        spacing: 8
                        Codigo { text: "IMG-0" + (mini.index + 1); color: Tema.destaque; anchors.verticalCenter: parent.verticalCenter }
                        Leitura { text: mini.modelData.nome; tamanho: 12; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
