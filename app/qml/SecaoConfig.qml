import QtQuick

// SYS.CONFIG (o painel de configurações do NetWatch OS): MOVIMENTO no topo, um trilho com a busca e
// os grupos (Visão geral, Janelas, Terminal, Interface, Estilo, Área de trabalho, Login, Sistema…,
// e Partes do tema) e, à direita, a página escolhida. Tudo vem do "cyberkde efeito --lista --json".
Item {
    id: c
    property bool ativa: false
    property var app
    property string pagina: "geral"
    property string consulta: ""

    visible: opacity > 0
    opacity: ativa ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tema.press } }

    onAtivaChanged: if (!ativa) painel.pararSom()      // prévia de som não continua fora da seção
    function irGrupo(id) { consulta = ""; busca.text = ""; pagina = id }

    BarraMovimento {
        id: mov
        x: 28; y: 18
        width: parent.width - 56
    }

    // ---- trilho
    Item {
        id: trilho
        x: 28; y: mov.y + mov.height + 16
        width: 220
        height: parent.height - y - 18

        Item {
            id: caixaBusca
            width: parent.width; height: 36
            Chanfro { anchors.fill: parent; preenchimento: Tema.entrada; borda: busca.activeFocus ? Tema.secundaria : Tema.linha; espessura: busca.activeFocus ? 2 : 1 }
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; font.pixelSize: 15; color: Tema.texto3 }
            TextInput {
                id: busca
                x: 30; width: parent.width - 60
                anchors.verticalCenter: parent.verticalCenter
                font.family: Tema.fTexto; font.pixelSize: 13
                color: Tema.texto
                selectByMouse: true
                clip: true
                onTextChanged: c.consulta = text
                Keys.onEscapePressed: text = ""
                Text {
                    visible: busca.text === ""
                    text: Txt.t("cfg.buscar")
                    font: busca.font
                    color: Tema.texto3
                }
            }
            Text {
                visible: busca.text !== ""
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: "✕"; font.pixelSize: 12; color: Tema.texto3
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: busca.text = "" }
            }
        }

        Flickable {
            anchors.top: caixaBusca.bottom; anchors.topMargin: 12
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: lista.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: lista
                width: parent.width
                spacing: 2
                Repeater {
                    model: [{ id: "geral", nome: Txt.t("cfg.geral"), total: -1 }].concat(painel.fxGrupos || [])
                        .concat([{ id: "partes", nome: Txt.t("cfg.partes"), total: painel.fases.length, separar: true }])
                    Item {
                        id: it
                        required property var modelData
                        required property int index
                        readonly property bool sel: c.consulta === "" && c.pagina === modelData.id
                        width: lista.width
                        height: (modelData.separar ? 14 : 0) + 34
                        activeFocusOnTab: true
                        Keys.onReturnPressed: c.irGrupo(modelData.id)
                        Keys.onSpacePressed: c.irGrupo(modelData.id)
                        Rectangle { visible: !!it.modelData.separar; y: 6; width: parent.width; height: 1; color: Tema.linha }
                        Item {
                            y: it.modelData.separar ? 14 : 0
                            width: parent.width; height: 34
                            Rectangle {
                                anchors.fill: parent
                                color: it.sel ? Tema.selecao : (ma.containsMouse ? Tema.hover : "transparent")
                                border.width: it.activeFocus ? 2 : 0; border.color: Tema.secundaria
                                Behavior on color { ColorAnimation { duration: Tema.micro } }
                            }
                            Rectangle { width: Tema.marcador; height: it.sel ? parent.height : 0; color: Tema.destaque
                                Behavior on height { NumberAnimation { duration: Tema.rapido } } }
                            Codigo {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: it.modelData.id === "geral" ? "00" : it.modelData.id === "partes" ? "PT" : ("0" + it.index).slice(-2)
                                tamanho: 9; color: it.sel ? Tema.destaque : Tema.texto3
                            }
                            Text {
                                x: 36; width: parent.width - 36 - contagem.width - 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: it.modelData.nome
                                elide: Text.ElideRight
                                font.family: Tema.fTexto; font.pixelSize: 13
                                font.weight: it.sel ? Font.DemiBold : Font.Normal
                                color: it.sel ? Tema.texto : Tema.texto2
                            }
                            Row {
                                id: contagem
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Rectangle {
                                    visible: (it.modelData.personalizados || 0) > 0
                                    width: 5; height: 5; rotation: 45; color: Tema.destaque
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                NumeroCintilante {
                                    visible: it.modelData.total >= 0
                                    valor: ("0" + it.modelData.total).slice(-2)
                                    font.pixelSize: 10
                                    color: it.sel ? Tema.destaque : Tema.texto3
                                }
                            }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.irGrupo(it.modelData.id) }
                        }
                    }
                }
            }
        }
    }

    // ---- conteúdo
    Item {
        id: area
        anchors.left: trilho.right; anchors.leftMargin: 6
        anchors.right: parent.right
        y: mov.y + mov.height + 6        // respiro: o conteúdo rolado não encosta na barra de movimento
        height: parent.height - y
        PaginaConfig {
            anchors.fill: parent
            app: c.app
            ativa: c.ativa && (c.pagina !== "partes" || c.consulta !== "")
            grupo: c.pagina === "partes" ? "geral" : c.pagina
            consulta: c.consulta
            onEscolherGrupo: (id) => c.irGrupo(id)
        }
        SecaoModulos {
            anchors.fill: parent
            app: c.app
            ativa: c.ativa && c.pagina === "partes" && c.consulta === ""
        }
    }
}
