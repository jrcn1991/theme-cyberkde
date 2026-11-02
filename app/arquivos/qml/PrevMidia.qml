import QtQuick
import QtMultimedia
import "../../qml"

// Vídeo e áudio da prévia. À parte do ModalPrevia para o QtMultimedia (FFmpeg e seus codecs, dezenas de MB) só
// carregar quando alguém abrir uma mídia: o Loader de lá só cria este item nessa hora.
Item {
    id: m
    property var modal
    property alias source: player.source
    function parar() { player.stop() }
    function alternar() { if (player.playbackState === MediaPlayer.PlayingState) player.pause(); else player.play() }

    MediaPlayer {
        id: player
        videoOutput: saida
        audioOutput: AudioOutput { id: som; volume: 0.7 }
    }
    VideoOutput { id: saida; visible: m.modal.pv.tipo === "video"; anchors.fill: parent; anchors.margins: 8; anchors.bottomMargin: 56 }
    // pôster: a miniatura até dar play (em vez da área preta)
    Image {
        id: poster
        anchors.fill: saida
        visible: m.modal.pv.tipo === "video" && player.playbackState !== MediaPlayer.PlayingState && player.position === 0 && status === Image.Ready && implicitWidth > 1
        source: m.modal.pv.tipo === "video" ? (m.modal.det.miniatura || m.modal.pv.miniatura || "") : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: 54; color: Tema.alfa(Tema.texto, 0.85); style: Text.Outline; styleColor: Tema.escuro }
    }
    Row {
        visible: m.modal.pv.tipo === "audio"
        anchors.centerIn: parent; anchors.verticalCenterOffset: -30
        spacing: 4
        Repeater {
            model: 32
            Rectangle {
                required property int index
                property real h: 0.15
                width: 8; height: 160 * h
                anchors.bottom: parent.bottom
                color: Tema.alfa(index % 5 === 0 ? Tema.secundaria : Tema.destaque, 0.8)
                Timer {
                    interval: 110; repeat: true
                    running: player.playbackState === MediaPlayer.PlayingState && !Tema.reduzir && m.modal.aberto
                    onTriggered: parent.h = 0.1 + Math.random() * 0.9 * (0.5 + 0.5 * Math.sin(Math.PI * (parent.index + 2) / 36))
                }
            }
        }
    }
    Item {
        visible: m.modal.pv.tipo === "video" || m.modal.pv.tipo === "audio"
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        x: 14; width: parent.width - 28; height: 32
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Botao {
                text: player.playbackState === MediaPlayer.PlayingState ? "❚❚" : "▶"; tamanho: 12; tipo: "primario"
                onClicado: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                function tm(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
                text: tm(player.position) + " / " + tm(player.duration)
                font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2
            }
        }
        BarraSegmentada {
            x: 190; width: parent.width - 190 - 200; height: 8
            anchors.verticalCenter: parent.verticalCenter
            valor: player.duration > 0 ? player.position / player.duration : 0
            larguraSeg: 5; vao: 2
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: (e) => { if (player.seekable) player.position = player.duration * Math.max(0, Math.min(1, e.x / width)) } }
        }
        // volume: ícone e valor
        Text {
            anchors.right: barraVol.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            text: "🔈 " + Math.round(som.volume * 100) + "%"
            font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2
        }
        BarraSegmentada {
            id: barraVol
            anchors.right: parent.right; width: 110; height: 8
            anchors.verticalCenter: parent.verticalCenter
            valor: som.volume; cor: Tema.secundaria; larguraSeg: 4; vao: 2
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: (e) => som.volume = Math.max(0, Math.min(1, e.x / width)) }
        }
    }
    Text {
        visible: (m.modal.pv.tipo === "video" || m.modal.pv.tipo === "audio") && player.error !== MediaPlayer.NoError
        anchors.centerIn: parent
        text: player.errorString; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.alerta
    }
}
