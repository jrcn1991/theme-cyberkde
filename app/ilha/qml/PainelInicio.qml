import QtQuick
import "Atividades.js" as A

// A home: player (ou panorama), conectividade, ferramentas e temporizador.
Rolagem {
    id: p
    readonly property var midia: ui.mod("midia")
    // buscando, o corpo é a lista: o painel guarda a altura e nada pula
    readonly property bool buscando: busca.text !== ""
    property real alturaAntes: 0
    onBuscandoChanged: if (buscando) alturaAntes = implicitHeight
    readonly property var volume: ui.ler("audio", "volume")
    readonly property var tocando: ui.ler("midia", "midia-tocando")
    readonly property bool parado: !nada && !ui.tocando
    readonly property bool nada: !tocando || tocando.value === "nada" || tocando.value === "nothing"

    readonly property var pendrive: { const v = p.ui.volumes().find(x => x.mountpoint !== undefined); return v || null }
    component Bloco: Rectangle { radius: p.ui.tema.raioCartao; color: p.ui.tema.hover }
    component Linha: Item {
        id: li
        property string glifo: ""
        property string nome: ""
        property string estado: ""
        property bool ativa: false
        property string acao: ""
        property string modulo: ""
        signal clicado()
        width: parent.width; height: 44
        Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: ma.containsMouse ? p.ui.tema.hover : "transparent" }
        Rectangle {
            x: 6; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: p.ui.raioDe(28)
            color: li.ativa ? p.ui.tema.ligado : p.ui.tema.ativo
            Glifo { anchors.centerIn: parent; nome: li.glifo; cheio: li.ativa; cor: li.ativa ? p.ui.tema.ligadoTexto : p.ui.tema.texto }
        }
        Column {
            x: 42; width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; elide: Text.ElideRight; text: li.nome; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13; font.weight: Font.Medium }
            Text { width: parent.width; elide: Text.ElideRight; text: li.estado; color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
            onClicked: (m) => { if (m.button === Qt.RightButton) p.ui.abrirModulo(li.modulo); else if (li.acao) p.ui.agir(li.acao); else li.clicado() }
        }
    }

    // ---- player ou panorama
    Surge {
        ui: p.ui; ordem: 0
        visible: !p.buscando
        width: parent.width; height: p.nada ? 120 : p.parado ? 64 : 148
        Item {
            visible: !p.nada
            anchors.fill: parent
            Image { id: capa; width: 60; height: 60; fillMode: Image.PreserveAspectCrop; source: !p.nada && p.tocando.art ? p.tocando.art : ""; asynchronous: true; cache: false
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.abrirModulo("midia") } }
            Rectangle { visible: capa.status !== Image.Ready; width: 60; height: 60; radius: p.ui.tema.raioControle; color: p.ui.tema.ativo; Glifo { anchors.centerIn: parent; nome: "MusicNotes"; tamanho: 22; cor: p.ui.tema.texto3 } }
            Column {
                x: 72; width: parent.width - 72 - 40; height: 60
                spacing: 2
                Text { width: parent.width; elide: Text.ElideRight; text: p.nada ? "" : p.tocando.value; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text { width: parent.width; elide: Text.ElideRight; text: p.nada ? "" : p.tocando.detail; color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
                Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: p.ui.linhaLetra; color: p.ui.tinta; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
            }
            Acao { visible: p.parado; anchors.right: parent.right; y: 14; width: 44; height: 36; ui: p.ui; dica: p.ui.txt("Tocar"); glifo: "Play"; tamanho: 22; cheio: true; onClicado: p.ui.agir("midia-alternar") }
            Ondas { visible: !p.parado; anchors.right: parent.right; y: 22; tema: p.ui.tema; cor: p.ui.tinta; niveis: p.ui.niveis; parado: !p.ui.tocando }
            Column {
                y: 68; width: parent.width; spacing: 4
                readonly property var prog: p.ui.ler("midia", "midia-progresso")
                visible: !!prog && !p.parado
                Barra { ui: p.ui; width: parent.width; razao: parent.prog ? parent.prog.ratio || 0 : 0; tinta: true }
                Item {
                    width: parent.width; height: 14
                    Text { text: p.ui.tempos(0); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                    Text { anchors.right: parent.right; text: p.ui.tempos(1); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                }
            }
            Row {
                y: 104; anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
                visible: !p.parado
                readonly property bool toca: p.ui.tocando
                Acao { ui: p.ui; glifo: "SkipBack"; tamanho: 18; cheio: true; width: 40; height: 36; onClicado: p.ui.agir("midia-anterior") }
                Acao { ui: p.ui; glifo: parent.toca ? "Pause" : "Play"; tamanho: 22; cheio: true; width: 44; height: 36; onClicado: p.ui.agir("midia-alternar") }
                Acao { ui: p.ui; glifo: "SkipForward"; tamanho: 18; cheio: true; width: 40; height: 36; onClicado: p.ui.agir("midia-proxima") }
                Item {
                    width: 110; height: 36
                    Glifo { anchors.verticalCenter: parent.verticalCenter; nome: "SpeakerHigh"; cor: p.ui.tema.texto2 }
                    Barra { x: 20; width: 90; anchors.verticalCenter: parent.verticalCenter; ui: p.ui; razao: p.volume ? p.volume.ratio || 0 : 0; aoBuscar: (r) => p.ui.agir("volume-definir", String(Math.round(r * 100))) }
                }
            }
        }
        // o panorama: hora e medidores
        Item {
            visible: p.nada
            anchors.fill: parent
            MouseArea {
                width: 170; height: parent.height; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.abrirModulo("tempo")
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: p.ui.valor("tempo", "relogio-hora") || "—"; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 40; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                    Text { width: 160; elide: Text.ElideRight; text: { const d = new Date().toLocaleDateString(Qt.locale(ilha.idioma), "ddd, dd MMM").replace(/\./g, ""); return d.charAt(0).toUpperCase() + d.slice(1) } color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
                    Repeater {
                        model: { const m = p.ui.mod("tempo"); return m ? (m.readings || []).filter(l => l.id === "relogio-mundo").slice(0, 3) : [] }
                        Text { required property var modelData; width: 160; elide: Text.ElideRight; text: modelData.label + "  " + modelData.value; color: modelData.level === "ok" ? p.ui.tema.texto2 : p.ui.tema.alerta; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
                    }
                    Row {
                        readonly property var clima: p.ui.ler("tempo", "clima-temp")
                        visible: !!clima && clima.level === "ok" && clima.value !== "—"
                        spacing: 4
                        Glifo { nome: "CloudSun"; cor: p.ui.tema.texto2 }
                        Text { text: parent.clima ? parent.clima.value : ""; color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
                    }
                }
            }
            Grid {
                x: 178; width: parent.width - 178; columns: 2; spacing: 8
                Repeater {
                    model: [{ r: "cpu", m: "sistema", g: "Cpu" }, { r: "memoria", m: "sistema", g: "Memory" }, { r: "temp-cpu", m: "sistema", g: "Thermometer" }, { r: "gpu-uso", m: "gpu", g: "GraphicsCard" }, { r: "rede-baixando", m: "rede", g: "DownloadSimple" }]
                        .map(x => Object.assign({ l: p.ui.ler(x.m, x.r) }, x)).filter(x => !!x.l).slice(0, 4)
                    Item {
                        id: me
                        required property var modelData
                        width: (parent.width - 8) / 2; height: 56
                        Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: mm.containsMouse ? p.ui.tema.ativo : p.ui.tema.hover }
                        Column {
                            x: 10; y: 7; width: parent.width - 20; spacing: 3
                            Row { spacing: 4; Glifo { nome: me.modelData.g; tamanho: 12; cor: p.ui.tema.texto3 } Text { text: /^temp/i.test(me.modelData.r) ? p.ui.txt("Temp.") : me.modelData.l.label; width: 60; elide: Text.ElideRight; color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 } }
                            Text { text: me.modelData.l.value; color: me.modelData.l.level === "ok" ? p.ui.tema.texto : p.ui.tema[me.modelData.l.level]; font.family: p.ui.tema.fonte; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Barra { visible: me.modelData.l.ratio != null; ui: p.ui; width: parent.width; height: 3; razao: me.modelData.l.ratio || 0; nivel: me.modelData.l.level }
                        }
                        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.abrirModulo(me.modelData.m) }
                    }
                }
            }
        }
    }

    // ---- grade
    Row {
        visible: !p.buscando
        width: parent.width; spacing: 8
        readonly property real col: (width - 16) / 3
        Surge {
            ui: p.ui; ordem: 1; width: parent.col; height: 176
            Bloco {
                anchors.fill: parent
                Column {
                    x: 2; y: 4; width: parent.width - 4
                    readonly property bool wifi: !!p.ui.ler("rede", "wifi-sinal")
                    readonly property var bt: p.ui.ler("bluetooth", "bluetooth")
                    readonly property bool sil: p.ui.ligado("kde", "silencio")
                    Linha { visible: !!p.ui.mod("rede"); height: visible ? 44 : 0; glifo: parent.wifi ? "WifiHigh" : "WifiSlash"; nome: "Wi-Fi"; estado: parent.wifi ? (p.ui.valor("rede", "rede-conexao") || p.ui.txt("ligado")) : p.ui.txt("desligado"); ativa: parent.wifi; acao: "wifi-alternar"; modulo: "rede" }
                    Linha { visible: !!p.ui.mod("bluetooth"); height: visible ? 44 : 0; glifo: "Bluetooth"; nome: "Bluetooth"; estado: p.ui.ligado("bluetooth", "bluetooth") ? ((p.ui.ler("bluetooth", "bluetooth") || {}).detail || p.ui.txt("ligado")) : p.ui.txt("desligado"); ativa: p.ui.ligado("bluetooth", "bluetooth"); acao: "bluetooth-alternar"; modulo: "bluetooth" }
                    Linha { visible: !!p.ui.mod("kde"); height: visible ? 44 : 0; glifo: parent.sil ? "BellSlash" : "Bell"; nome: p.ui.txt("Silêncio"); estado: parent.sil ? p.ui.txt("não perturbe") : p.ui.txt("notificações"); ativa: parent.sil; acao: "silencio-alternar"; modulo: "kde" }
                    Linha {
                        visible: !!p.pendrive
                        height: visible ? 44 : 0
                        glifo: "Usb"; nome: p.pendrive ? p.pendrive.label || p.pendrive.device : ""; ativa: !!p.pendrive && !!p.pendrive.mountpoint
                        estado: p.ui.txt("ejetar"); acao: ""; modulo: "discos"
                        onClicado: p.ui.agir("disco-ejetar", p.pendrive.disco)
                    }
                    Linha {
                        readonly property var cel: p.ui.ler("celular", "celular-dispositivo")
                        visible: !!cel && cel.level === "ok" && cel.value !== "nenhum" && cel.value !== "—"
                        height: visible ? 44 : 0
                        glifo: "DeviceMobile"; nome: cel ? cel.value : ""; estado: "KDE Connect"; ativa: true; acao: "celular-ping"; modulo: "celular"
                    }
                }
            }
        }
        Surge {
            ui: p.ui; ordem: 2; width: parent.col; height: 176
            Bloco {
                anchors.fill: parent
                Grid {
                    anchors.centerIn: parent; columns: 2; spacing: 8
                    Repeater {
                        model: [
                            { id: "volume-mudo", d: "Mudo", g: p.ui.valor("audio", "volume") === "mudo" ? "SpeakerSlash" : "SpeakerHigh", a: p.ui.valor("audio", "volume") === "mudo", m: "audio" },
                            { id: "mic-mudo-alternar", d: "Microfone: mudo", g: p.ui.valor("audio", "mic-mudo") === "mudo" ? "MicrophoneSlash" : "Microphone", a: p.ui.valor("audio", "mic-mudo") === "mudo", m: "audio" },
                            { id: "cafeina-alternar", d: "Cafeína", g: "Coffee", a: p.ui.ligado("kde", "cafeina"), m: "desktop" },
                            { id: "kde-mostrar-desktop", d: "Mostrar a área de trabalho", g: "Desktop", a: false, m: "desktop" },
                            { id: "kde-captura", d: "Capturar", g: "Camera", a: false, m: "desktop" },
                            { id: "kde-bloquear", d: "Bloquear", g: "Lock", a: false, m: "desktop" }
                        ].filter(x => !!p.ui.mod(x.m))
                        Rectangle {
                            id: tl
                            required property var modelData
                            width: 44; height: 44; radius: p.ui.tema.raioControle
                            color: modelData.a ? p.ui.tema.ligado : (mt.containsMouse ? p.ui.tema.ativo : p.ui.tema.hover)
                            opacity: p.ui.pendente(modelData.id) ? 0.5 : 1
                            HoverHandler { onHoveredChanged: p.ui.pedirDica(hovered ? p.ui.txt(tl.modelData.d) + (tl.modelData.id === "cafeina-alternar" || tl.modelData.id === "volume-mudo" ? ": " + p.ui.txt(tl.modelData.a ? "ligado" : "desligado") : "") : "", tl) }
                            Glifo { anchors.centerIn: parent; nome: tl.modelData.g; tamanho: 16; cheio: tl.modelData.a; cor: tl.modelData.a ? p.ui.tema.ligadoTexto : p.ui.tema.texto }
                            MouseArea {
                                id: mt; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                onClicked: (m) => { if (m.button === Qt.RightButton) p.ui.abrirModulo(tl.modelData.m); else p.ui.agir(tl.modelData.id) }
                            }
                        }
                    }
                }
            }
        }
        Surge {
            ui: p.ui; ordem: 3; width: parent.col; height: 176
            Bloco {
                anchors.fill: parent
                readonly property var timer: p.ui.snap ? p.ui.snap.timer : null
                Column {
                    x: 12; y: 10; width: parent.width - 24; spacing: 6
                    Row {
                        spacing: 4
                        Glifo { nome: parent.parent.parent.timer && parent.parent.parent.timer.end === null ? "Hourglass" : "Timer"; tamanho: 12; cor: p.ui.tema.texto3 }
                        Text { text: p.ui.txt(parent.parent.parent.timer && parent.parent.parent.timer.end === null ? "Cronômetro" : "Temporizador"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                    }
                    Text { visible: !!parent.parent.timer; text: A.contagem(parent.parent.timer, p.ui.agora); color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 24; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                    AcaoLarga { visible: !!parent.parent.timer; ui: p.ui; glifo: "Stop"; texto: p.ui.txt("Parar"); onClicado: p.ui.agir("timer-parar") }
                    // parado: o foco de 25 min à mão; o resto no "+"
                    Flow {
                        visible: !parent.parent.timer
                        width: parent.width; spacing: 4
                        AcaoLarga { ui: p.ui; texto: p.ui.txt("25 · foco"); onClicado: p.ui.agir("timer-iniciar", "25 foco") }
                        AcaoLarga { ui: p.ui; texto: maisTimer.aberto ? "−" : "+"; dica: p.ui.txt("Mais"); onClicado: maisTimer.aberto = !maisTimer.aberto }
                        Item { id: maisTimer; property bool aberto: false; width: 0; height: 0 }
                        Repeater {
                            model: maisTimer.aberto ? [5, 15, 50] : []
                            AcaoLarga { required property int modelData; ui: p.ui; texto: p.ui.txt("{n} min", { n: modelData }); onClicado: p.ui.agir("timer-iniciar", String(modelData)) }
                        }
                        AcaoLarga { visible: maisTimer.aberto; ui: p.ui; glifo: "Hourglass"; texto: p.ui.txt("Cronômetro"); onClicado: p.ui.agir("timer-cronometro") }
                        FocoSemana { visible: !maisTimer.aberto && dias.length === 7 && total > 0; ui: p.ui; compacto: true; width: parent.width }
                    }
                }
            }
        }
    }
    // ---- lançador
    Surge {
        ui: p.ui; ordem: 4
        width: parent.width; height: Math.max(36 + (lista.count ? lista.count * 34 + 12 : 0), p.buscando ? p.alturaAntes - 24 : 0)
        Rectangle { width: parent.width; height: 36; radius: p.ui.tema.raioControle; color: p.ui.tema.hover
            Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "MagnifyingGlass"; cor: p.ui.tema.texto3 }
            TextInput {
                id: busca
                x: 34; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; clip: true
                color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13; selectByMouse: true
                onTextChanged: ilha.buscarApps(text)
                onAccepted: if (lista.count) p.executar(lista.itemAt(0).modelData)
                Keys.onEscapePressed: { text = ""; p.ui.soltarTeclado() }
                TapHandler { onPressedChanged: if (pressed) p.ui.pedirTeclado(busca) }
                Text { visible: !busca.text; text: p.ui.txt("App ou comando"); color: p.ui.tema.texto3; font: busca.font }
            }
        }
        Column {
            y: 42; width: parent.width
            Repeater {
                id: lista
                model: busca.text ? p.comandos(busca.text).concat(p.ui.apps).slice(0, 6) : []
                Item {
                    id: la
                    required property var modelData
                    width: parent.width; height: 34
                    Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: mla.containsMouse ? p.ui.tema.ativo : "transparent" }
                    Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: la.modelData.glifo || "AppWindow"; cor: p.ui.tema.texto2 }
                    Text { x: 34; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: la.modelData.nome; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
                    MouseArea { id: mla; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.executar(la.modelData) }
                }
            }
        }
    }
    function comandos(q) {
        const n = (s) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
        return [{ acao: "kde-captura", nome: "Capturar a tela (Spectacle)", glifo: "Camera" }, { acao: "kde-bloquear", nome: "Bloquear a tela agora", glifo: "Lock" },
                { acao: "kde-mostrar-desktop", nome: "Mostrar a área de trabalho", glifo: "Desktop" }, { acao: "cafeina-alternar", nome: "Cafeína: manter a tela acordada", glifo: "Coffee" },
                { acao: "cor-capturar", nome: "Conta-gotas", glifo: "Eyedropper" }, { acao: "texto-da-tela", nome: "Ler o texto da tela (OCR)", glifo: "TextAa" }]
            .map(c => Object.assign(c, { nome: p.ui.txt(c.nome) })).filter(c => n(c.nome).indexOf(n(q)) >= 0)
    }
    function executar(c) {
        if (c.acao) p.ui.agir(c.acao); else p.ui.agir("apps-abrir", c.id)
        busca.text = ""
        p.ui.soltarTeclado()
    }
}
