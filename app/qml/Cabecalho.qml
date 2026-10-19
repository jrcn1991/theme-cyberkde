import QtQuick

// Cabeçalho: número e título da seção (glitch), linha de dados e o "crachá" da corporação em uso.
Item {
    id: c
    property int numero: 1
    property string titulo: ""
    property string caminho: ""
    property alias logo: crachaLogo
    property string nomeForcado: ""

    height: 84

    Text {
        id: num
        x: 28; y: 16
        text: ("0" + c.numero).slice(-2)
        font.family: Tema.fIdentidade; font.pixelSize: 30; font.weight: Font.Black
        color: Tema.destaque
    }
    Rectangle { x: num.x + num.width + 12; y: 22; width: 1; height: 34; color: Tema.linhaMarca }
    TextoGlitch {
        id: tit
        x: num.x + num.width + 26; y: 14
        text: c.titulo
        font.family: Tema.fRotulo; font.pixelSize: 30; font.weight: Font.Bold
        font.capitalization: Font.AllUppercase; font.letterSpacing: 2
        color: Tema.texto
    }
    Codigo {
        x: tit.x; y: 52
        width: Math.max(0, cracha.x - x - 20)
        elide: Text.ElideRight
        text: "SYS://CYBERKDE/" + c.caminho + "  ·  NODE 0x" + (0x3A0 + c.numero * 17).toString(16).toUpperCase() + "  ·  " + painel.binario.split("/").slice(-2).join("/")
        tamanho: 10
    }

    // linha de dados com marcas de escala
    Item {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28; anchors.rightMargin: 28
        height: 6
        Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Tema.linha }
        Rectangle { width: 120; height: 1; anchors.bottom: parent.bottom; color: Tema.destaque }
        Repeater {
            model: Math.max(0, Math.floor(parent.width / 24))
            Rectangle {
                required property int index
                x: index * 24; width: 1; height: index % 5 === 0 ? 6 : 3
                anchors.bottom: parent.bottom
                color: index % 5 === 0 ? Tema.linhaMarca : Tema.linha
            }
        }
    }

    // crachá da corporação
    Item {
        id: cracha
        anchors.right: parent.right; anchors.rightMargin: 28
        y: 14
        width: crachaRow.implicitWidth + 28; height: 50
        Chanfro {
            anchors.fill: parent
            preenchimento: Tema.alfa(Tema.destaque, 0.06)
            borda: Tema.linhaMarca
        }
        Row {
            id: crachaRow
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 12
            LogoMontagem {
                id: crachaLogo
                modo: "compacto"
                height: 34; width: Math.min(height * 2.6, height * Math.max(1, proporcao))
                source: painel.logoAtual || painel.logoReserva
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Rotulo {
                    text: {
                        if (c.nomeForcado) return c.nomeForcado
                        const id = painel.corpAtual
                        const corp = painel.corps.find(x => x.id === id)
                        return corp ? corp.nome : (id === "personalizada" ? Txt.t("nome.personalizada") : Txt.t("cab.semCorp"))
                    }
                    tamanho: 16
                }
                Row {
                    spacing: 6
                    Rectangle { width: 10; height: 10; color: Tema.alvo; anchors.verticalCenter: parent.verticalCenter }
                    Codigo { text: Tema.alvo.toString().toUpperCase(); color: Tema.texto2 }
                    Codigo { text: Tema.emPrevia ? (painel.ocupado ? Txt.t("cab.aplicando") : Txt.t("cab.previa")) : ""; color: Tema.secundaria }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Codigo { text: Txt.t("comum.tema"); tamanho: 9 }
                Text {
                    text: painel.temaLigado ? Txt.t("estado.online") : Txt.t("estado.offline")
                    font.family: Tema.fIdentidade; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1
                    color: painel.temaLigado ? Tema.destaque : Tema.texto3
                }
            }
        }
    }
}
