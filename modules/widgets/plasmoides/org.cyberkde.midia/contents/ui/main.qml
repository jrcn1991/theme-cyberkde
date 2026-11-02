import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Mídia: controle MPRIS. Prefere o Spotify (configurável); sem ele, segue o player ativo
// do sistema. Capa com glitch na troca de faixa, barra de progresso segmentada arrastável, controles,
// volume, embaralhar/repetir e um visualizador decorativo que só anima tocando.
// ESTILO (opção "estilo"): HUD (este), JUKEBOX (EQ de 12 bandas + now playing + knob de volume), JUKEBOX
// MINI (telas pequenas com botões grandes e o "PRICE 2.00 E$"), SÓ EQUALIZADOR e RÁDIO NEON (visor de néon
// com brilho, letreiro e EQ de pontos). O EQ é sintético por padrão; "Espectro real" usa o helper.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- players: linha do multiplexador (player ativo) e uma por player
    Mpris.Mpris2Model { id: mpris }
    property var _linhas: []
    Instantiator {
        model: mpris
        delegate: QtObject {
            required property int index
            required property var container
            required property string desktopEntry
            required property bool isMultiplexer
        }
        onObjectAdded: raiz._recontar()
        onObjectRemoved: raiz._recontar()
        // as linhas que já existem chegam antes disto, com _inst ainda nulo: sem recontar aqui, o player que
        // já tocava quando o widget nasceu ficaria de fora até o próximo player aparecer
        Component.onCompleted: { raiz._inst = this; raiz._recontar() }
    }
    property var _inst: null
    function _recontar() {
        let l = []
        if (_inst) for (let i = 0; i < _inst.count; i++) { const o = _inst.objectAt(i); if (o) l.push(o) }
        _linhas = l
    }
    // ---- players ignorados: navegadores (opção "Ignorar navegadores", ligada por padrão) e a lista da
    // usuária ("Players ignorados"). Compara com DesktopEntry, Identity e o nome do serviço MPRIS.
    readonly property var _navegadores: /chrom(e|ium)|firefox|plasma-browser-integration|brave|opera|vivaldi|msedge|microsoft[- ]edge|epiphany|gnome web|falkon|librewolf|waterfox|zen-browser|floorp|konqueror|qutebrowser/
    readonly property var _extras: (cfg.ignorados || "").toLowerCase().split(/[,;\s]+/).filter(x => x)
    function ignorado(c) {
        if (!c) return true
        const s = [c.desktopEntry, c.identity, c.objectName].map(x => String(x || "")).join(" ").toLowerCase()
        if (cfg.ignorarNavegadores && _navegadores.test(s)) return true
        return _extras.some(x => s.indexOf(x) >= 0)
    }
    readonly property bool _filtrando: !!cfg.ignorarNavegadores || _extras.length > 0
    // o preferido (se não ignorado); senão o ativo do sistema, se não ignorado; senão o primeiro player de
    // verdade tocando, ou o primeiro que houver. Sem nenhum: "sem mídia" (mesmo com aba tocando).
    readonly property var player: {
        const pref = (cfg.preferir || "").toLowerCase()
        let multi = null, reais = []
        for (const o of _linhas) {
            if (!o.container) continue
            if (o.isMultiplexer) { multi = o.container; continue }
            if (ignorado(o.container)) continue
            if (pref && o.desktopEntry.toLowerCase() === pref) return o.container
            reais.push(o.container)
        }
        if (!_filtrando) return multi || mpris.currentPlayer
        const atual = mpris.currentPlayer
        if (atual && !ignorado(atual) && reais.indexOf(atual) >= 0) return atual
        return reais.find(c => c.playbackStatus === Mpris.PlaybackStatus.Playing) || reais[0] || null
    }
    readonly property bool tem: !!player && player.track !== undefined && (player.track !== "" || player.identity !== "")
    readonly property bool tocando: tem && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real duracao: tem ? player.length : 0             // µs
    readonly property real posicao: tem ? player.position : 0
    readonly property string nomePlayer: tem ? (player.identity || player.desktopEntry || "") : ""

    // posição: o MPRIS não manda a posição contínua, então lemos a cada segundo enquanto toca
    Timer { interval: 1000; repeat: true; running: raiz.tocando && raiz.duracao > 0; onTriggered: raiz.player.updatePosition() }

    function tempo(us) {
        if (!(us > 0)) return "0:00"
        const s = Math.floor(us / 1e6)
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = String(s % 60).padStart(2, "0")
        return h ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss
    }
    function alternarRepetir() {
        const L = Mpris.LoopStatus
        player.loopStatus = player.loopStatus === L.None ? L.Playlist : player.loopStatus === L.Playlist ? L.Track : L.None
    }
    // ShuffleStatus: 1 = desligado, 2 = ligado
    readonly property bool embaralhado: tem && Number(player.shuffle) === 2
    function alternarEmbaralhar() { player.shuffle = embaralhado ? 1 : 2 }

    toolTipMainText: tem ? player.track : t("Mídia", "Media")
    toolTipSubText: tem ? player.artist + (nomePlayer ? " · " + nomePlayer : "") : t("Nenhum player ativo", "No active player")

    // ---- tamanho na área de trabalho: livre (a geometria do applet, redimensionável no modo de edição);
    //      P/M/G são presets, e "modo" guarda o último escolhido. Na barra, a forma compacta de sempre.
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    // valores antigos: compacto → pequeno, completo → grande
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0                  // muda a cada escolha de preset (até a mesma de novo)
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))

    // ---- estilo e cores (a paleta "jukebox" do jogo é opcional; o padrão são as cores da corporação)
    readonly property string estilo: ["hud", "jukebox", "mini", "eq", "neon"].indexOf(cfg.estilo) >= 0 ? cfg.estilo : "hud"
    onEstiloChanged: pedidoPreset++                     // cada estilo tem os seus P/M/G
    readonly property bool paletaJukebox: !!cfg.paletaJukebox && estilo !== "hud"
    readonly property color corBarra: paletaJukebox ? "#E2552C" : Cores.destaque
    readonly property color corPico: paletaJukebox ? "#27B3A6" : Cores.secundaria
    readonly property var tamanhos: ({
        hud:     { p: Qt.size(300, 78), m: Qt.size(Kirigami.Units.gridUnit * 19, Kirigami.Units.gridUnit * 9.5), g: Qt.size(Kirigami.Units.gridUnit * 22, Kirigami.Units.gridUnit * 11), lim: Qt.size(280, 140) },
        jukebox: { p: Qt.size(320, 80), m: Qt.size(460, 256), g: Qt.size(640, 336), lim: Qt.size(300, 150) },
        mini:    { p: Qt.size(288, 80), m: Qt.size(304, 208), g: Qt.size(384, 256), lim: Qt.size(260, 150) },
        eq:      { p: Qt.size(272, 96), m: Qt.size(368, 176), g: Qt.size(528, 256), lim: Qt.size(150, 60) },
        neon:    { p: Qt.size(320, 96), m: Qt.size(432, 208), g: Qt.size(576, 272), lim: Qt.size(300, 130) }
    })
    readonly property var tam: tamanhos[estilo]
    // os níveis do equalizador (só existem fora do HUD; o HUD tem o visualizador próprio)
    Espectro {
        id: espectroObj
        tocando: raiz.tocando && raiz.estilo !== "hud"
        real: !!raiz.cfg.espectroReal
        chave: String(Plasmoid.id)
    }
    readonly property alias espectro: espectroObj
    Component { id: cJukeboxP; EstiloJukebox { r: raiz; compacto: true } }
    Component { id: cJukebox; EstiloJukebox { r: raiz } }
    Component { id: cMiniP; EstiloMini { r: raiz; compacto: true } }
    Component { id: cMini; EstiloMini { r: raiz } }
    Component { id: cEq; EstiloEq { r: raiz } }
    Component { id: cEqP; EstiloEq { r: raiz; compacto: true } }
    Component { id: cNeon; EstiloNeon { r: raiz } }
    Component { id: cNeonP; EstiloNeon { r: raiz; compacto: true } }
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Item {
                anchors.fill: parent
                Capa {
                    id: capaMini
                    width: parent.height; height: width
                    fonte: raiz.tem ? raiz.player.artUrl : ""
                    chave: raiz.tem ? raiz.player.track + "|" + raiz.player.artist : ""
                }
                Column {
                    x: capaMini.width + 10
                    width: parent.width - x - 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: raiz.tem ? raiz.player.track : raiz.t("Nenhum player ativo", "No active player")
                        elide: Text.ElideRight
                        font.family: Cores.fTexto; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: raiz.tem ? Cores.texto : Cores.texto2
                    }
                    Text {
                        visible: raiz.tem
                        width: parent.width
                        text: raiz.tem ? raiz.player.artist : ""
                        elide: Text.ElideRight
                        font.family: Cores.fTexto; font.pixelSize: 11
                        color: Cores.secundaria
                    }
                    Codigo {
                        text: !raiz.tem ? "MPRIS // " + raiz.t("SEM SINAL", "NO SIGNAL") : raiz.tocando ? raiz.t("▶ TOCANDO", "▶ PLAYING") : raiz.t("❚❚ PAUSA", "❚❚ PAUSED")
                        color: raiz.tocando ? Cores.destaque : Cores.texto3; tamanho: 8
                    }
                }
                BotaoIcone {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    tamanho: 30; ativo: raiz.tem
                    icone: raiz.tocando ? "media-playback-pause" : "media-playback-start"
                    habilitado: raiz.tem && (raiz.tocando ? raiz.player.canPause : raiz.player.canPlay)
                    onClicado: raiz.player.PlayPause()
                }
            }
        }
    }

    Component {
        id: compactoBarra
    MouseArea {
        Layout.minimumWidth: linhaC.implicitWidth + 8
        Layout.maximumWidth: Kirigami.Units.gridUnit * 14
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (m) => { if (m.button === Qt.MiddleButton && raiz.tem) raiz.player.PlayPause(); else raiz.expanded = !raiz.expanded }
        onWheel: (w) => { if (raiz.tem) raiz.player.changeVolume(w.angleDelta.y > 0 ? 0.05 : -0.05, true) }
        Row {
            id: linhaC
            anchors.centerIn: parent
            spacing: 6
            Kirigami.Icon {
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: raiz.tocando ? "media-playback-pause" : "media-playback-start"
                isMask: true; color: raiz.tocando ? Cores.destaque : Cores.texto2
            }
            Text {
                visible: raiz.tem
                width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 11)
                anchors.verticalCenter: parent.verticalCenter
                text: raiz.tem ? raiz.player.track : ""
                elide: Text.ElideRight
                font.family: Cores.fTexto; font.pixelSize: 12
                color: Cores.texto
            }
        }
    }
    }

    // ---- médio e grande (a mesma moldura; o médio mostra menos partes)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("Mídia", "Media")
            codigo: "MPRIS // " + (raiz.tem ? raiz.nomePlayer.toUpperCase() : raiz.t("SEM SINAL", "NO SIGNAL"))
            extra: [
                Item {
                    visible: raiz.tem
                    width: st.implicitWidth + 12; height: 16
                    readonly property color cor: raiz.tocando ? Cores.destaque : Cores.texto3
                    Rectangle { anchors.fill: parent; color: Cores.alfa(parent.cor, 0.12); border.color: parent.cor }
                    Codigo {
                        id: st
                        anchors.centerIn: parent; tamanho: 9; font.bold: true; color: parent.cor
                        text: raiz.tocando ? raiz.t("▶ TOCANDO", "▶ PLAYING") : raiz.t("❚❚ PAUSA", "❚❚ PAUSED")
                    }
                }
            ]

            // ---- sem player
            Column {
                visible: !raiz.tem
                anchors.centerIn: parent
                spacing: 6
                Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 40; source: "audio-x-generic"; isMask: true; color: Cores.texto3 }
                Leitura { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.t("Nenhum player ativo", "No active player"); color: Cores.texto2; wrapMode: Text.NoWrap }
                Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.t("ABRA O SPOTIFY OU OUTRO PLAYER", "OPEN SPOTIFY OR ANOTHER PLAYER") }
            }

            // ---- com player
            Item {
                visible: raiz.tem
                anchors.fill: parent

                Capa {
                    id: capa
                    width: Math.min(parent.height, parent.width * 0.36); height: width
                    fonte: raiz.tem ? raiz.player.artUrl : ""
                    chave: raiz.tem ? raiz.player.track + "|" + raiz.player.artist : ""
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (raiz.player.canRaise) raiz.player.Raise() }
                }

                Column {
                    id: info
                    x: capa.width + 12
                    width: parent.width - x
                    height: parent.height
                    spacing: 4

                    Text {
                        width: parent.width
                        text: raiz.tem ? raiz.player.track : ""
                        elide: Text.ElideRight
                        font.family: Cores.fTexto; font.pixelSize: 15; font.weight: Font.DemiBold
                        color: Cores.texto
                    }
                    Text {
                        width: parent.width
                        text: raiz.tem ? raiz.player.artist : ""
                        elide: Text.ElideRight
                        font.family: Cores.fTexto; font.pixelSize: 12
                        color: Cores.secundaria
                    }
                    Codigo {
                        visible: info.height >= 104
                        width: parent.width
                        text: raiz.tem && raiz.player.album ? "ALB // " + raiz.player.album.toUpperCase() : " "
                    }

                    Visualizador {
                        visible: raiz.cfg.mostrarVisualizador && info.height >= 132
                        width: parent.width; height: visible ? Math.max(10, Math.min(30, info.height - 120)) : 0
                        tocando: raiz.tocando
                    }

                    // progresso: segmentado e arrastável
                    Item {
                        id: prog
                        width: parent.width; height: 22
                        property real arrasto: -1
                        readonly property real fracao: arrasto >= 0 ? arrasto : (raiz.duracao > 0 ? raiz.posicao / raiz.duracao : 0)
                        BarraSegmentada {
                            y: 2; width: parent.width; height: 6
                            valor: prog.fracao
                            tamSeg: 3; vao: 1
                        }
                        Codigo { y: 11; text: raiz.tempo(prog.arrasto >= 0 ? prog.arrasto * raiz.duracao : raiz.posicao); tamanho: 9; color: Cores.texto2 }
                        Codigo { y: 11; anchors.right: parent.right; text: raiz.tempo(raiz.duracao); tamanho: 9 }
                        MouseArea {
                            anchors.fill: parent; anchors.topMargin: -4
                            enabled: raiz.tem && raiz.player.canSeek && raiz.duracao > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            function f(x) { return Math.max(0, Math.min(1, x / width)) }
                            onPressed: (m) => prog.arrasto = f(m.x)
                            onPositionChanged: (m) => { if (pressed) prog.arrasto = f(m.x) }
                            onReleased: { raiz.player.position = Math.round(prog.arrasto * raiz.duracao); prog.arrasto = -1 }
                            onCanceled: prog.arrasto = -1
                        }
                    }

                    // controles
                    Item {
                        width: parent.width; height: 30
                        Row {
                            spacing: 5
                            anchors.verticalCenter: parent.verticalCenter
                            BotaoIcone {
                                tamanho: 24; icone: "media-playlist-shuffle"; ativo: raiz.embaralhado
                                dica: raiz.t("Embaralhar", "Shuffle")
                                habilitado: raiz.tem && raiz.player.canControl
                                onClicado: raiz.alternarEmbaralhar()
                            }
                            BotaoIcone {
                                tamanho: 26; icone: "media-skip-backward"
                                habilitado: raiz.tem && raiz.player.canGoPrevious
                                onClicado: raiz.player.Previous()
                            }
                            BotaoIcone {
                                tamanho: 30; ativo: true
                                icone: raiz.tocando ? "media-playback-pause" : "media-playback-start"
                                habilitado: raiz.tem && (raiz.tocando ? raiz.player.canPause : raiz.player.canPlay)
                                onClicado: raiz.player.PlayPause()
                            }
                            BotaoIcone {
                                tamanho: 26; icone: "media-skip-forward"
                                habilitado: raiz.tem && raiz.player.canGoNext
                                onClicado: raiz.player.Next()
                            }
                            BotaoIcone {
                                tamanho: 24
                                icone: raiz.tem && raiz.player.loopStatus === Mpris.LoopStatus.Track ? "media-repeat-single" : "media-repeat-all"
                                ativo: raiz.tem && raiz.player.loopStatus !== Mpris.LoopStatus.None && raiz.player.loopStatus !== Mpris.LoopStatus.Unknown
                                dica: raiz.t("Repetir", "Repeat")
                                habilitado: raiz.tem && raiz.player.canControl
                                onClicado: raiz.alternarRepetir()
                            }
                        }
                        // volume
                        Item {
                            visible: raiz.cfg.mostrarVolume && raiz.tem && raiz.player.volume >= 0 && info.width >= 210
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(84, info.width - 160); height: 16
                            Kirigami.Icon {
                                id: icVol
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: !raiz.tem || raiz.player.volume <= 0 ? "audio-volume-muted" : raiz.player.volume < 0.4 ? "audio-volume-low" : raiz.player.volume < 0.75 ? "audio-volume-medium" : "audio-volume-high"
                                isMask: true; color: Cores.texto2
                            }
                            BarraSegmentada {
                                x: icVol.width + 4; width: parent.width - x; height: 6
                                anchors.verticalCenter: parent.verticalCenter
                                valor: raiz.tem ? raiz.player.volume : 0
                                cor: Cores.secundaria
                                tamSeg: 3; vao: 2
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    function f(x) { return Math.max(0, Math.min(1, (x - 6) / (width - 12))) }
                                    onPressed: (m) => raiz.player.volume = f(m.x)
                                    onPositionChanged: (m) => { if (pressed) raiz.player.volume = f(m.x) }
                                    onWheel: (w) => raiz.player.changeVolume(w.angleDelta.y > 0 ? 0.05 : -0.05, false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        limiteCartao: raiz.tam.lim
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: ({ hud: cartaoPequeno, jukebox: cJukeboxP, mini: cMiniP, eq: cEqP, neon: cNeonP })[raiz.estilo]
        completo: ({ hud: painelCompleto, jukebox: cJukebox, mini: cMini, eq: cEq, neon: cNeon })[raiz.estilo]
        tamanhoPequeno: raiz.tam.p
        tamanhoMedio: raiz.tam.m
        tamanhoGrande: raiz.tam.g
    }

}
