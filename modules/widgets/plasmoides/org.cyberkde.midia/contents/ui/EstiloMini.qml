import QtQuick
import org.kde.kirigami as Kirigami
import "comum"

// Estilo JUKEBOX MINI (as "small screens" do jukebox): o título pequeno em cima, o "PRICE 2.00 E$" (a piada
// do jogo; o tempo da faixa embaixo) e botões grandes e chanfrados de tocar/pausar, parar, avançar e
// voltar. "compacto" (P): a tecla de play grande, o preço e o título numa linha.
Item {
    id: m
    property var r
    property bool compacto: false
    readonly property bool tem: r.tem
    readonly property var p: r.player
    readonly property color cor: r.corBarra

    component Tecla: Item {
        id: tc
        property string icone: ""
        property string rotulo: ""
        property bool grande: false
        property bool habilitado: true
        signal clicado()
        opacity: habilitado ? 1 : 0.4
        Chanfro {
            anchors.fill: parent; corte: tc.grande ? 8 : 6
            preenchimento: Cores.alfa(m.cor, maT.pressed ? 0.4 : maT.containsMouse ? 0.26 : 0.16)
            borda: Cores.alfa(m.cor, maT.containsMouse ? 1 : 0.55)
        }
        // trama fina de linhas, como nas telas da referência
        Column {
            anchors.fill: parent; anchors.margins: 4; clip: true; spacing: 3
            Repeater { model: Math.floor(tc.height / 4); Rectangle { width: parent.width; height: 1; color: Cores.alfa(m.cor, 0.07) } }
        }
        Codigo { visible: tc.rotulo !== "" && tc.height > 44; x: 7; y: 5; text: tc.rotulo; tamanho: 8; color: Cores.alfa(m.cor, 0.9) }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * (tc.grande ? 0.5 : 0.42); height: width
            source: tc.icone; isMask: true; color: m.cor
        }
        MouseArea { id: maT; anchors.fill: parent; hoverEnabled: true; enabled: tc.habilitado; cursorShape: Qt.PointingHandCursor; onClicked: tc.clicado() }
    }
    component Preco: Item {
        property real tam: 28
        width: tp.implicitWidth + 20; height: tam * 1.5
        Chanfro { anchors.fill: parent; corte: 6; preenchimento: Cores.alfa(m.cor, 0.16); borda: Cores.alfa(m.cor, 0.45) }
        Text { id: tp; anchors.centerIn: parent; text: "2.00 E$"; font.family: Cores.fTitulo; font.pixelSize: parent.tam; font.weight: Font.Bold; color: m.cor }
    }

    // ---- P: linha
    CartaoCompacto {
        visible: m.compacto
        anchors.fill: parent
        opacidade: m.r.opac
        Item {
            anchors.fill: parent
            Tecla {
                id: tP
                width: parent.height; height: parent.height; grande: true
                icone: m.r.tocando ? "media-playback-pause" : "media-playback-start"
                habilitado: m.tem && (m.r.tocando ? m.p.canPause : m.p.canPlay)
                onClicado: m.p.PlayPause()
            }
            Column {
                x: tP.width + 10; width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { width: parent.width; text: "▪ " + (m.tem ? "1. " + m.p.track.toUpperCase() : m.r.t("SEM SINAL", "NO SIGNAL")); elide: Text.ElideRight; font.family: Cores.fTitulo; font.pixelSize: 12; font.weight: Font.Bold; color: Cores.texto }
                Text { text: "PRICE 2.00 E$"; font.family: Cores.fTitulo; font.pixelSize: 17; font.weight: Font.Bold; color: m.cor }
            }
        }
    }

    // ---- M/G: a tela pequena
    Item {
        visible: !m.compacto
        anchors.fill: parent
        Chanfro { anchors.fill: parent; corte: 12; preenchimento: Cores.alfa(Cores.cartao, m.r.opac); borda: Cores.alfa(m.cor, 0.5) }
        Row { x: parent.width - 52; y: 6; spacing: 3; Repeater { model: 3; Rectangle { width: 8; height: 3; color: m.r.corPico } } }
        Item {
            id: corpo
            anchors.fill: parent; anchors.margins: 12
            readonly property real wDir: Math.max(70, width * 0.34)
            Text {
                id: tit
                width: parent.width - 60
                text: "▪ " + (m.tem ? "1. " + m.p.track.toUpperCase() : m.r.t("NENHUM PLAYER ATIVO", "NO ACTIVE PLAYER"))
                elide: Text.ElideRight; font.family: Cores.fTitulo; font.pixelSize: 12; font.weight: Font.Bold; color: Cores.texto
            }
            Codigo { anchors.right: parent.right; text: m.r.tempo(m.r.posicao) + "/" + m.r.tempo(m.r.duracao); tamanho: 10; color: Cores.texto2 }
            // esquerda: preço e o play grande
            Column {
                y: tit.height + 8; width: parent.width - corpo.wDir - 10; height: parent.height - y
                spacing: 8
                Item {
                    width: parent.width; height: Math.min(54, parent.height * 0.38)
                    Chanfro { anchors.fill: parent; corte: 6; preenchimento: Cores.alfa(m.cor, 0.16); borda: Cores.alfa(m.cor, 0.45) }
                    Codigo { x: 8; y: 4; text: "PRICE"; tamanho: 8; color: Cores.alfa(m.cor, 0.9) }
                    Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 3; text: "2.00 E$"; font.family: Cores.fTitulo; font.pixelSize: Math.min(30, parent.height * 0.58); font.weight: Font.Bold; color: m.cor }
                }
                Tecla {
                    width: parent.width; height: parent.height - y; grande: true; rotulo: m.r.tocando ? "PAUSE" : "PLAY"
                    icone: m.r.tocando ? "media-playback-pause" : "media-playback-start"
                    habilitado: m.tem && (m.r.tocando ? m.p.canPause : m.p.canPlay)
                    onClicado: m.p.PlayPause()
                }
            }
            // direita: parar, avançar, voltar
            Column {
                x: parent.width - corpo.wDir; y: tit.height + 8; width: corpo.wDir; height: parent.height - y
                spacing: 6
                readonly property real h: (height - 12) / 3
                Tecla { width: parent.width; height: parent.h; rotulo: "STOP"; icone: "media-playback-stop"; habilitado: m.tem && m.p.canStop !== false; onClicado: m.p.Stop() }
                Tecla { width: parent.width; height: parent.h; rotulo: "NEXT"; icone: "media-skip-forward"; habilitado: m.tem && m.p.canGoNext; onClicado: m.p.Next() }
                Tecla { width: parent.width; height: parent.h; rotulo: "PREVIOUS"; icone: "media-skip-backward"; habilitado: m.tem && m.p.canGoPrevious; onClicado: m.p.Previous() }
            }
        }
    }
}
