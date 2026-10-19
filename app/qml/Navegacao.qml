import QtQuick

// Trilho lateral: identidade, seções numeradas e preferências do painel.
Item {
    id: n
    property int atual: 0
    property var secoes: []
    signal escolher(int i)

    Rectangle { anchors.fill: parent; color: Tema.fundo; opacity: 0.85 }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.linha }
    Rectangle { anchors.right: parent.right; y: 96; width: 1; height: 64; color: Tema.destaque }

    // identidade
    Row {
        x: 20; y: 22
        spacing: 12
        LogoMontagem {
            id: logoNav
            modo: "compacto"
            // logos largos ficam mais baixos, para o título continuar cabendo
            width: Math.min(64, 40 * Math.max(1, proporcao)); height: Math.min(40, width / Math.max(0.01, proporcao))
            anchors.verticalCenter: parent.verticalCenter
            source: painel.logoAtual || painel.logoReserva
            recorte: painel.logoAtual ? painel.recorteAtual : null
            varreduraOciosa: true
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: n.width - 20 - logoNav.width - 12 - 12
            spacing: 2
            Text {
                text: "CYBERKDE"
                width: parent.width
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 12
                font.family: Tema.fIdentidade; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 2
                color: Tema.texto
            }
            Codigo { text: Txt.t("nav.subtitulo"); tamanho: 9; color: Tema.destaque; width: parent.width; elide: Text.ElideRight }
        }
    }

    Column {
        id: lista
        y: 100
        width: parent.width - 1
        spacing: 2
        Repeater {
            model: n.secoes
            Item {
                id: item
                required property var modelData
                required property int index
                readonly property bool sel: n.atual === index
                width: lista.width; height: 46
                activeFocusOnTab: true
                Keys.onReturnPressed: n.escolher(index)
                Keys.onSpacePressed: n.escolher(index)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    color: item.sel ? Tema.selecao : (ma.containsMouse ? Tema.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Tema.micro } }
                    border.width: item.activeFocus ? 2 : 0
                    border.color: Tema.secundaria
                }
                Rectangle {
                    x: 10; width: Tema.marcador
                    height: item.sel ? parent.height : 0
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.destaque
                    Behavior on height { NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
                }
                Text {
                    x: 26; anchors.verticalCenter: parent.verticalCenter
                    text: ("0" + (item.index + 1)).slice(-2)
                    font.family: Tema.fIdentidade; font.pixelSize: 11; font.weight: Font.Bold
                    color: item.sel ? Tema.destaque : Tema.texto3
                }
                Rotulo {
                    id: rot
                    x: 56; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, item.width - x - 18)
                    elide: Text.ElideRight
                    text: item.modelData.titulo
                    tamanho: 17
                    color: item.sel ? Tema.texto : (ma.containsMouse ? Tema.texto : Tema.texto2)
                    Behavior on color { ColorAnimation { duration: Tema.micro } }
                }
                Atalho {
                    id: capsula
                    // sem espaço ao lado do rótulo (menu estreito ou título longo), a cápsula sai;
                    // o atalho continua valendo e aparece no F1
                    visible: rot.x + rot.implicitWidth + 10 <= x
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    tecla: "^" + (item.index + 1)
                    cor: item.sel ? Tema.destaque : Tema.texto3
                    opacity: item.sel || ma.containsMouse ? 1 : 0.55
                }
                // indicador de atenção (ex.: diagnóstico com problemas)
                Rectangle {
                    visible: item.modelData.alerta === true
                    width: 6; height: 6; rotation: 45
                    anchors.right: parent.right; anchors.rightMargin: 52
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.alerta
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: n.escolher(item.index)
                }
            }
        }
    }

    // preferências
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        x: 20
        width: parent.width - 40
        spacing: 10
        Rectangle { width: parent.width; height: 1; color: Tema.linha }
        Codigo { text: Txt.t("nav.prefs"); tamanho: 9 }
        Row {
            spacing: 10
            width: parent.width
            Interruptor {
                id: reduz
                ligado: painel.reduzirAnimacoes
                onAlternado: (novo) => painel.reduzirAnimacoes = novo
                anchors.verticalCenter: parent.verticalCenter
            }
            Leitura {
                text: Txt.t("nav.reduzir")
                width: parent.width - reduz.width - 10
                tamanho: 12
                color: Tema.texto2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        // idioma: troca ao vivo, gravado em painel.json
        Row {
            spacing: 10
            width: parent.width
            Item {
                id: seletorIdioma
                width: 64; height: 28
                Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.entrada; borda: Tema.linha }
                Row {
                    anchors.fill: parent; anchors.margins: 3
                    spacing: 2
                    Repeater {
                        model: [{ id: "pt_BR", rotulo: "PT" }, { id: "en", rotulo: "EN" }]
                        Item {
                            id: opcao
                            required property var modelData
                            readonly property bool sel: painel.idioma === modelData.id
                            width: 28; height: 22
                            activeFocusOnTab: true
                            Keys.onSpacePressed: painel.idioma = modelData.id
                            Keys.onReturnPressed: painel.idioma = modelData.id
                            Chanfro {
                                anchors.fill: parent; corte: 3
                                preenchimento: opcao.sel ? Tema.destaque : (maIdioma.containsMouse ? Tema.hover : "transparent")
                                borda: opcao.activeFocus ? Tema.secundaria : "transparent"
                                espessura: opcao.activeFocus ? 2 : 0
                                Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: opcao.modelData.rotulo
                                font.family: Tema.fIdentidade; font.pixelSize: 9; font.weight: Font.Bold
                                color: opcao.sel ? Tema.escuro : Tema.texto2
                            }
                            MouseArea {
                                id: maIdioma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: painel.idioma = opcao.modelData.id
                            }
                        }
                    }
                }
            }
            Leitura {
                text: Txt.t("idioma.rotulo")
                width: parent.width - seletorIdioma.width - 10
                tamanho: 12
                color: Tema.texto2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            spacing: 6
            Rectangle {
                width: 6; height: 6; rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                color: painel.statusOk ? Tema.sucesso : Tema.erro
            }
            Codigo {
                text: painel.statusOk ? Txt.t("nav.cliOk") : Txt.t("nav.cliErro")
                tamanho: 9
                color: painel.statusOk ? Tema.texto2 : Tema.erro
            }
        }
    }
}
