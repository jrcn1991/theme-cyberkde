import QtQuick
import org.kde.kirigami as Kirigami
import "comum"

// Estilo JUKEBOX (a "big screen" do jukebox do jogo): SOUND MASTER com o equalizador de 12 bandas em
// cima; embaixo NOW PLAYING (abas com o player, o artista e o álbum; a faixa atual e, se o player expuser
// a fila, a fila), o knob de VOLUME (arrasta ou rola: muda o volume do player) e, com largura, os knobs de
// PRESETS (leitura viva das bandas). "compacto" (P): um cartão com o EQ pequeno, o título e o play.
Item {
    id: j
    property var r                              // a raiz do widget (player, espectro, cores, textos)
    property bool compacto: false
    readonly property bool tem: r.tem
    readonly property var p: r.player
    readonly property bool largo: width >= 560
    readonly property bool alto: height >= 260

    // ---- P: cartão
    CartaoCompacto {
        visible: j.compacto
        anchors.fill: parent
        opacidade: j.r.opac
        Item {
            anchors.fill: parent
            Equalizador {
                id: eqP
                width: Math.min(parent.width * 0.42, 130); height: parent.height
                niveis: j.r.espectro.niveis; rotulos: false; alturaSeg: 3; vaoSeg: 2
                cor: j.r.corBarra; corPico: j.r.corPico
            }
            Column {
                x: eqP.width + 10; width: parent.width - x - 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Codigo { text: "SOUND MASTER"; tamanho: 8; color: j.r.corBarra }
                Text { width: parent.width; text: j.tem ? j.p.track : j.r.t("Nenhum player ativo", "No active player"); elide: Text.ElideRight; font.family: Cores.fTexto; font.pixelSize: 13; font.weight: Font.DemiBold; color: j.tem ? Cores.texto : Cores.texto2 }
                Text { visible: j.tem && j.height >= 84; width: parent.width; text: j.tem ? j.p.artist : ""; elide: Text.ElideRight; font.family: Cores.fTexto; font.pixelSize: 11; color: Cores.texto2 }
            }
            BotaoIcone {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                tamanho: 30; ativo: j.tem
                icone: j.r.tocando ? "media-playback-pause" : "media-playback-start"
                habilitado: j.tem && (j.r.tocando ? j.p.canPause : j.p.canPlay)
                onClicado: j.p.PlayPause()
            }
        }
    }

    // ---- M/G: a tela grande
    Moldura {
        visible: !j.compacto
        anchors.fill: parent
        opacidade: j.r.opac
        titulo: "SOUND MASTER"
        codigo: Qt.formatTime(relogio.agora, "hh.mm.ss") + " // " + (j.tem ? j.r.nomePlayer.toUpperCase() : j.r.t("SEM SINAL", "NO SIGNAL"))
        Item {
            id: relogio
            property date agora: new Date()
            Timer { interval: 1000; running: j.visible; repeat: true; onTriggered: relogio.agora = new Date() }
        }
        Item {
            anchors.fill: parent
            Equalizador {
                id: eq
                width: parent.width
                height: Math.round(parent.height * (j.alto ? 0.52 : 0.46))
                niveis: j.r.espectro.niveis
                rotulos: true; rotulosBaixo: j.alto
                alturaSeg: j.alto ? 6 : 4; vaoSeg: 3
                cor: j.r.corBarra; corPico: j.r.corPico
            }
            Rectangle { y: eq.height + 6; width: parent.width; height: 1; color: Cores.alfa(j.r.corBarra, 0.4) }

            Item {
                id: baixo
                y: eq.height + 12; width: parent.width; height: parent.height - y
                readonly property real wVol: Math.min(height, 96)
                readonly property real wPre: j.largo ? Math.min(baixo.width * 0.3, 190) : 0

                // NOW PLAYING
                Item {
                    width: parent.width - baixo.wVol - baixo.wPre - 20; height: parent.height
                    Row {
                        spacing: 6
                        Rectangle { width: 6; height: 6; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter }
                        Codigo { text: "NOW PLAYING"; tamanho: 10; color: j.r.corBarra; font.bold: true }
                    }
                    // abas: o player, o artista, o álbum (o "gênero" da referência)
                    Column {
                        id: abas
                        y: 18; width: Math.min(110, parent.width * 0.34)
                        spacing: 3
                        Repeater {
                            model: j.tem ? [j.r.nomePlayer, j.p.artist, j.p.album].filter(x => x).slice(0, j.alto ? 3 : 2) : []
                            Item {
                                required property string modelData
                                required property int index
                                width: abas.width; height: 18
                                Chanfro { anchors.fill: parent; corte: 4; preenchimento: index === 0 ? j.r.corBarra : Cores.alfa(j.r.corBarra, 0.14); borda: Cores.alfa(j.r.corBarra, index === 0 ? 1 : 0.4) }
                                Text { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; text: parent.modelData.toUpperCase(); elide: Text.ElideRight; font.family: Cores.fMono; font.pixelSize: 9; font.bold: index === 0; color: index === 0 ? Cores.escuro : Cores.texto2 }
                            }
                        }
                    }
                    // a faixa atual (a fila só se o player expuser TrackList; o Spotify não expõe)
                    Column {
                        x: abas.width + 10; y: 18; width: parent.width - x
                        spacing: 4
                        Item {
                            width: parent.width; height: 18
                            Text { text: "▶"; font.pixelSize: 10; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                x: 14; width: parent.width - 14 - tDur.width - 6; anchors.verticalCenter: parent.verticalCenter
                                text: j.tem ? "1. " + j.p.track.toUpperCase() : j.r.t("NENHUM PLAYER ATIVO", "NO ACTIVE PLAYER")
                                elide: Text.ElideRight; font.family: Cores.fTitulo; font.pixelSize: 13; font.weight: Font.Bold; color: Cores.texto
                            }
                            Text { id: tDur; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: j.r.tempo(j.r.duracao); font.family: Cores.fMono; font.pixelSize: 10; color: Cores.texto2 }
                        }
                        Text { visible: j.tem; width: parent.width; text: j.tem ? "   " + j.p.artist : ""; elide: Text.ElideRight; font.family: Cores.fTexto; font.pixelSize: 11; color: Cores.texto2 }
                        BarraSegmentada { visible: j.tem; width: parent.width; height: 4; valor: j.r.duracao > 0 ? j.r.posicao / j.r.duracao : 0; cor: j.r.corBarra; tamSeg: 3; vao: 1 }
                        Row {
                            spacing: 4
                            BotaoIcone { tamanho: 22; icone: "media-skip-backward"; habilitado: j.tem && j.p.canGoPrevious; onClicado: j.p.Previous() }
                            BotaoIcone { tamanho: 22; ativo: true; icone: j.r.tocando ? "media-playback-pause" : "media-playback-start"; habilitado: j.tem && (j.r.tocando ? j.p.canPause : j.p.canPlay); onClicado: j.p.PlayPause() }
                            BotaoIcone { tamanho: 22; icone: "media-skip-forward"; habilitado: j.tem && j.p.canGoNext; onClicado: j.p.Next() }
                        }
                    }
                }
                // VOLUME
                Item {
                    x: parent.width - baixo.wVol - baixo.wPre - (j.largo ? 14 : 0); width: baixo.wVol; height: parent.height
                    Row { spacing: 6; Rectangle { width: 6; height: 6; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter } Codigo { text: "VOLUME"; tamanho: 10; color: j.r.corBarra; font.bold: true } }
                    Knob {
                        y: 18; width: Math.max(30, Math.min(parent.width, parent.height - 22)); height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        valor: j.tem && j.p.volume >= 0 ? j.p.volume : 0
                        interativo: j.tem && j.p.volume >= 0
                        cor: Cores.texto; corNumero: j.r.corBarra
                        opacity: j.tem && j.p.volume >= 0 ? 1 : 0.4
                        onMudou: (v) => j.p.volume = v
                    }
                }
                // PRESETS: oito knobs que leem as bandas (aos pares)
                Item {
                    visible: j.largo
                    x: parent.width - baixo.wPre; width: baixo.wPre; height: parent.height
                    Row { spacing: 6; Rectangle { width: 6; height: 6; color: Cores.texto; anchors.verticalCenter: parent.verticalCenter } Codigo { text: "PRESETS"; tamanho: 10; color: j.r.corBarra; font.bold: true } }
                    Grid {
                        y: 20; columns: 4; columnSpacing: 6; rowSpacing: 4
                        Repeater {
                            model: 8
                            Column {
                                required property int index
                                readonly property real v: ((j.r.espectro.niveis[index] || 0) + (j.r.espectro.niveis[index + 4] || 0)) / 2
                                spacing: 0
                                Knob { width: Math.max(16, Math.min(34, (baixo.wPre - 18) / 4, (baixo.height - 24) / 2 - 15)); height: width; numero: false; valor: parent.v; cor: Cores.texto; espessura: 2 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(parent.v * 99); font.family: Cores.fTitulo; font.pixelSize: 11; font.weight: Font.Bold; color: index % 3 === 2 ? j.r.corPico : j.r.corBarra }
                            }
                        }
                    }
                }
            }
        }
    }
}
