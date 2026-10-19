import QtQuick

// Inspetor da corporação selecionada: logo largo oficial (qualquer proporção, entra em varredura ao
// trocar), nome, lema, tabela da paleta, o ícone como fica no menu iniciar e as ações.
Item {
    id: n
    // montagem (ver Cascata): moldura traçada, superfície, conteúdo acendendo, flash da borda
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0
    property var dados: ({})
    property int numero: 1
    property var app
    signal aplicar()

    readonly property var paleta: dados.paleta || ({ destaque: "#F75049", secundaria: "#5EF6FF", alerta: "#FB932E", fundo: "#0E0E17" })
    readonly property color corC: Tema.legivel(paleta.destaque)
    readonly property color fundoC: Tema.mistura(Qt.color(paleta.fundo), Tema.texto, 0.05)
    readonly property bool especial: dados.id === "personalizada" || dados.id === "nenhuma"
    readonly property bool emUso: painel.corpAtual === dados.id
    readonly property bool aplicando: painel.alvo === dados.id || painel.alvosNaFila.indexOf(dados.id) >= 0

    implicitHeight: col.implicitHeight + 40

    Chanfro {
        anchors.fill: parent
        traco: n.traco; superficie: n.superficie; realce: n.realce
        corte: Tema.chanfroG + 6
        preenchimento: Tema.alfa(n.fundoC, 0.97)
        borda: Tema.alfa(n.corC, 0.7)
        Behavior on preenchimento { ColorAnimation { duration: Tema.padrao } }
        Behavior on borda { ColorAnimation { duration: Tema.padrao } }
    }
    Rectangle { x: 0; y: Tema.chanfroG + 14; width: Tema.marcador; height: 40; color: n.corC }
    Cantoneiras { cor: Tema.alfa(n.corC, 0.45); tamanho: 10; recuo: 5 }

    // troca de seleção: o painel limpa e o conteúdo novo acende com flicker de liga e desliga (a
    // moldura fica); a borda pisca; o logo se monta (LogoMontagem) e o nome se decodifica
    property string _ultimo: ""
    onDadosChanged: {
        if (dados.id === _ultimo) return
        _ultimo = dados.id || ""
        if (!Tema.reduzir) troca.restart()
    }
    SequentialAnimation {
        id: troca
        PropertyAction { target: col; property: "opacity"; value: 0 }
        PropertyAction { target: n; property: "realce"; value: 0.9 }
        PauseAnimation { duration: 66 }
        PropertyAction { target: col; property: "opacity"; value: 0.6 }
        PauseAnimation { duration: 33 }
        PropertyAction { target: col; property: "opacity"; value: 0.15 }
        PauseAnimation { duration: 33 }
        PropertyAction { target: col; property: "opacity"; value: 1 }
        PauseAnimation { duration: 33 }
        PropertyAction { target: col; property: "opacity"; value: 0.5 }
        PauseAnimation { duration: 33 }
        PropertyAction { target: col; property: "opacity"; value: 1 }
        NumberAnimation { target: n; property: "realce"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }

    Column {
        id: col
        x: 24; y: 20
        width: parent.width - 48
        spacing: 14

        Item {
            width: parent.width; height: 18
            Codigo {
                text: "CORP-" + ("0" + n.numero).slice(-2) + " // " + (n.dados.id || "").toUpperCase()
                color: n.corC
            }
            Rectangle {
                visible: n.emUso || n.aplicando
                anchors.right: parent.right
                width: seloTx.implicitWidth + 14; height: 18
                color: n.aplicando ? "transparent" : n.corC
                border.color: n.corC; border.width: 1
                Codigo {
                    id: seloTx
                    anchors.centerIn: parent
                    text: n.aplicando ? Txt.t("corp.aplicando") : Txt.t("corp.emUso")
                    tamanho: 9; font.bold: true
                    color: n.aplicando ? n.corC : Tema.escuro
                }
            }
        }

        // palco do logo largo
        Item {
            width: parent.width; height: 150
            Cantoneiras { cor: Tema.alfa(n.corC, 0.25); tamanho: 12 }
            LogoMontagem {
                id: logo
                modo: "medio"
                recorte: null
                visible: !n.especial
                anchors.centerIn: parent
                width: parent.width - 48; height: 116
                source: n.dados.logo || ""
                cor: n.corC
                brilho: true
            }
            // Personalizada: losango com o espectro; Padrão: os quatro blocos do tema
            Item {
                visible: n.dados.id === "personalizada"
                anchors.centerIn: parent
                width: 110; height: 110
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: 76 - index * 12; height: width; rotation: 45
                        color: index === 5 ? n.corC : "transparent"
                        border.width: 2
                        border.color: Qt.hsva(index / 6, 0.75, 1, 1)
                    }
                }
            }
            IconeMenu {
                visible: n.dados.id === "nenhuma"
                anchors.centerIn: parent
                tamanho: 84
                cor: n.corC
            }
        }

        TextoGlitch {
            text: n.dados.nome || ""
            ocioso: false
            font.family: Tema.fIdentidade; font.pixelSize: 26; font.weight: Font.Bold; font.letterSpacing: 1.5
            color: Tema.texto
        }
        Leitura {
            text: n.dados.lema || ""
            width: parent.width
            font.italic: true
            tamanho: 14
            color: Tema.texto2
        }
        // dossiê (lore): texto de leitura, na fonte do sistema
        Column {
            visible: !!n.dados.descricao
            width: parent.width
            spacing: 6
            Row {
                spacing: 8
                Codigo { text: Txt.t("corp.dossie"); tamanho: 9; color: Tema.legivel(n.paleta.secundaria) }
                Rectangle { width: 40; height: 1; color: Tema.alfa(n.corC, 0.4); anchors.verticalCenter: parent.verticalCenter }
            }
            Leitura {
                text: n.dados.descricao || ""
                width: parent.width
                tamanho: 13
                color: Tema.texto
            }
        }

        Rectangle { width: parent.width; height: 1; color: Tema.alfa(n.corC, 0.3) }

        Row {
            width: parent.width
            spacing: 20
            Column {
                width: parent.width - menu.width - 20
                spacing: 8
                Codigo { text: Txt.t("corp.paleta"); tamanho: 9 }
                TabelaPaleta { width: parent.width; paleta: n.paleta }
            }
            // como o ícone fica no botão do menu iniciar, em três tamanhos
            Column {
                id: menu
                width: 150
                spacing: 8
                Codigo { text: Txt.t("corp.botaoMenu"); tamanho: 9 }
                Item {
                    width: parent.width; height: 64
                    Rectangle {
                        anchors.fill: parent
                        color: Tema.mistura(Qt.color(n.paleta.fundo), "#000000", 0.2)
                        border.color: Tema.linha
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 14
                        Repeater {
                            model: [22, 32, 48]
                            IconeMenu {
                                required property int modelData
                                anchors.verticalCenter: parent.verticalCenter
                                tamanho: modelData
                                source: n.dados.id === "personalizada" || n.dados.id === "nenhuma" ? "" : (n.dados.icone || "")
                                cor: n.corC
                            }
                        }
                    }
                }
                Codigo { text: "22 · 32 · 48 PX"; tamanho: 8 }
            }
        }

        Leitura {
            visible: n.dados.logoDaUsuaria === true
            width: parent.width
            tamanho: 11
            color: Tema.legivel(n.paleta.secundaria)
            text: Txt.t("corp.logoProprio")
        }
        Leitura {
            visible: !n.especial && !n.dados.logoDaUsuaria && (n.dados.logo || "").indexOf("/genericos/") >= 0
            width: parent.width
            tamanho: 11
            color: Tema.texto3
            text: Txt.t("corp.logoGenerico")
        }

        Row {
            spacing: 10
            Botao {
                text: n.dados.id === "personalizada" ? Txt.t("corp.escolherCor") : (n.emUso ? Txt.t("corp.emUsoBotao") : (n.dados.id === "nenhuma" ? Txt.t("corp.voltarPadrao") : Txt.t("comum.aplicar")))
                icone: n.emUso && n.dados.id !== "personalizada" ? "" : "▶"
                tipo: n.emUso && n.dados.id !== "personalizada" ? "secundario" : "primario"
                cor: n.corC
                habilitado: !n.aplicando && !painel.ocupado && !(n.emUso && n.dados.id !== "personalizada")
                onClicado: n.aplicar()
            }
            Botao {
                visible: !n.especial
                text: Txt.t("corp.escolherLogo")
                tipo: "sutil"; tamanho: 12
                cor: n.corC
                onClicado: n.app.escolherLogo(n.dados.id)
            }
            Botao {
                visible: !n.especial && n.dados.logoDaUsuaria === true
                text: Txt.t("comum.remover")
                tipo: "sutil"; tamanho: 12
                cor: n.corC
                implicitWidth: 84
                onClicado: painel.removerLogo(n.dados.id)
            }
        }
    }

    // máscara do conteúdo durante a montagem (o conteúdo "acende" com flicker)
    Chanfro {
        visible: n.acender < 1
        z: 50
        anchors.fill: parent
        anchors.margins: 1
        corte: Tema.chanfroG + 6
        preenchimento: Tema.base
        espessura: 0
        opacity: 1 - n.acender
    }
    QuadradosMontagem { z: 51; progresso: n.traco; n: 4 }
}
