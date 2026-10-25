// CyberKDE — splash de inicialização (KSplashQML, pacote look-and-feel org.cyberkde.desktop).
// O ksplashqml avança "stage" de 1 a 6 (initial, startPlasma, kcminit, ksmserver, wm, desktop)
// e fecha no 6. A barra segmentada mostra esse progresso real; a varredura é só um acento.
// Orbitron só no título curto "CYBERKDE"; todo o resto em Noto Sans.
// Duração (cyberkde efeito splash): "completo" (2 s; o título e o logo se montam como no LogoMontagem
// "completo" do painel, 1,25 s), "curto" (padrão, 900 ms; montagem "média", 780 ms) ou "nenhum" (a
// tela aparece pronta). O splash roda a cada login: por isso o padrão é o curto.
import QtQuick
import org.kde.kirigami as Kirigami
import "components"

Rectangle {
    id: root

    color: CK.base

    property int stage: 0

    // Prévias fora da tela (preview/render_previews.py).
    property real previewT: -1

    readonly property real factor: Kirigami.Units.longDuration > 0 ? Kirigami.Units.longDuration / 200 : 0
    readonly property var steps: ["Preparando", "Preparando", "Iniciando o Plasma", "Carregando configurações",
                                  "Restaurando a sessão", "Gerenciador de janelas", "Área de trabalho"]
    readonly property int segments: 24
    property string modo: Opcoes.splash        // completo | curto | nenhum
    // Fundo = papel da corporação, que já traz a placa com o logo: o logo daqui não aparece (F7).
    property bool logoNoFundo: Opcoes.logoNoFundo
    readonly property int introTotal: modo === "completo" ? 2000 : (modo === "nenhum" ? 0 : 900)
    readonly property bool completo: modo === "completo"
    // A coreografia abaixo está marcada para 900 ms; no "completo" ela é esticada (tt = tempo nessa régua).
    readonly property real tt: introTotal > 0 ? t * 900 / introTotal : 100000
    // Montagem do título e do logo: 1,25 s no completo, 0,78 s no curto (os tempos do LogoMontagem).
    readonly property real tMontagem: introTotal > 0 ? Math.min(1, t / (completo ? 1250 : 780)) : 1

    property real t: 0
    property real progress: 0.04
    property real rescanP: -1

    Component.onCompleted: {
        CK.factor = factor
        if (previewT < 0) {
            if (introTotal <= 0 || factor <= 0)
                t = Math.max(introTotal, 1)
            else
                intro.start()
        }
    }
    onPreviewTChanged: {
        if (previewT >= 0) {
            intro.stop()
            t = previewT
        }
    }
    onStageChanged: {
        progress = Math.max(progress, Math.min(1, stage / 6))
        if (t >= introTotal && introTotal > 0)
            rescan.restart()
    }

    NumberAnimation {
        id: intro
        target: root
        property: "t"
        from: 0
        to: root.introTotal
        duration: root.introTotal * root.factor
    }
    Behavior on progress {
        NumberAnimation { duration: CK.dur(CK.context); easing.type: Easing.OutCubic }
    }
    NumberAnimation {
        id: rescan
        target: root
        property: "rescanP"
        from: 0
        to: 1
        duration: CK.dur(CK.context)
    }

    FontLoader {
        id: orbitron
        source: "fonts/Orbitron-VariableFont_wght.ttf"
    }

    Backdrop {
        anchors.fill: parent
        source: Qt.resolvedUrl("images/background.png")
        t: root.tt
        imageOpacity: 0.45
    }

    Column {
        id: coluna
        anchors.centerIn: parent
        width: 640

        Reveal {
            t: root.tt; start: 60; dx: 0; dy: 6
            anchors.horizontalCenter: parent.horizontalCenter
            Row {
                spacing: 12
                Rectangle { width: 18; height: 3; color: CK.red; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "INICIALIZAÇÃO DO SISTEMA"
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 3
                }
                Rectangle { width: 18; height: 3; color: CK.red; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Item { width: 1; height: 16 }

        Item {  // título + a montagem dele (a Montagem precisa ser irmã do alvo, fora do Column)
            width: parent.width
            height: titleBox.height

        Item {
            id: titleBox
            width: parent.width
            height: title.implicitHeight + 8

            readonly property bool glitch: CK.factor > 0 && root.tt >= 400 && root.tt < 460
            readonly property string family: orbitron.status === FontLoader.Ready ? orbitron.font.family : CK.fontUi

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: title.font.letterSpacing / 2 + 3
                visible: titleBox.glitch
                text: title.text; font: title.font
                color: CK.alpha(CK.cyan, 0.6)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: title.font.letterSpacing / 2 - 3
                visible: titleBox.glitch
                text: title.text; font: title.font
                color: CK.alpha(CK.red, 0.6)
            }
            Text {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                // o espaçamento entre letras também entra depois da última letra: compensa
                anchors.horizontalCenterOffset: font.letterSpacing / 2
                text: "CYBERKDE"
                color: CK.txt1
                font.family: titleBox.family
                font.pixelSize: 76
                font.weight: Font.Bold
                font.letterSpacing: 12
                opacity: montagemTitulo.ativa ? 1 : CK.ramp(root.tt, 140, 260)  // sem GPU: só aparece
            }
            ScanLine {
                anchors.fill: parent
                anchors.margins: -6
                progress: root.rescanP >= 0 ? root.rescanP : (root.tt - 180) / 380
            }
        }
        Montagem {
            id: montagemTitulo
            alvo: titleBox
            t: root.tMontagem
            fatias: root.completo ? 11 : 8
            feixes: root.completo ? 52 : 24
            campo: root.completo ? 2.4 : 1.6
            dadosIni: root.completo ? 0.18 : 0.02
            dadosFim: root.completo ? 0.62 : 0.55
            fatIni: root.completo ? 0.48 : 0.30
            fatFim: root.completo ? 0.80 : 0.74
            flIni: root.completo ? 0.80 : 0.76
            flFim: root.completo ? 0.90 : 0.88
        }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 140 * CK.ramp(root.tt, 300, 220)
            height: 2
            color: CK.red
        }

        Item { width: 1; height: 40 }

        // progresso segmentado: vermelho = concluído, ciano = etapa atual
        Row {
            id: bar
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            readonly property int lit: Math.round(root.progress * root.segments)
            Repeater {
                model: root.segments
                Rectangle {
                    width: 22
                    height: 10
                    color: index < bar.lit ? (index === bar.lit - 1 ? CK.cyan : CK.red) : CK.alpha(CK.txt1, 0.10)
                    opacity: CK.ramp(root.tt, 320 + index * 14, 160)
                    Behavior on color { ColorAnimation { duration: CK.dur(CK.micro) } }
                }
            }
        }

        Item { width: 1; height: 12 }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: bar.width
            height: 20
            opacity: CK.ramp(root.tt, 520, 200)
            Text {
                text: root.steps[Math.max(0, Math.min(6, root.stage))]
                color: CK.txt2
                font.family: CK.fontUi
                font.pixelSize: 14
            }
            Text {
                anchors.right: parent.right
                text: Math.round(root.progress * 100) + "%"
                color: CK.txt1
                font.family: CK.fontUi
                font.pixelSize: 14
                font.features: { "tnum": 1 }
            }
        }
    }

    // Logo da corporação ("cyberkde corp"): o install_login copia para images/logo.svg ou .png. Sem
    // logo, a imagem não carrega e a tela fica como sempre: o logo fica fora da coluna e não empurra
    // nada. Entra junto com o cabeçalho, com uma varredura curta por cima.
    Image {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: coluna.top
        anchors.bottomMargin: 40
        // Caixa larga: os logos oficiais são horizontais (até 5,5:1); um ícone quadrado fica com 110 px.
        width: 440
        height: 110
        sourceSize.width: 880
        sourceSize.height: 220
        fillMode: Image.PreserveAspectFit
        mipmap: true  // a caixa é a metade do sourceSize (telas com escala 2): reduz sem serrilhar
        asynchronous: false
        source: "images/logo.svg"
        // Sem o .svg, tenta o .png; sem nenhum dos dois, fica invisível.
        onStatusChanged: if (status === Image.Error && String(source).endsWith(".svg")) source = "images/logo.png"
        visible: status === Image.Ready && !root.logoNoFundo
        opacity: montagemTitulo.ativa ? 1 : CK.ramp(root.tt, 0, 240)

        ScanLine {  // só sobre o desenho (paintedWidth), não sobre a caixa larga inteira
            anchors.centerIn: parent
            width: logo.paintedWidth + 20
            height: logo.paintedHeight + 20
            progress: (root.tt - 80) / 320
        }
    }
    Montagem {
        alvo: logo.visible ? logo : null
        visible: logo.visible
        t: root.tMontagem
        fatias: root.completo ? 11 : 8
        feixes: root.completo ? 52 : 24
        campo: root.completo ? 2.4 : 1.6
        dadosIni: root.completo ? 0.18 : 0.02
        dadosFim: root.completo ? 0.62 : 0.55
        fatIni: root.completo ? 0.48 : 0.30
        fatFim: root.completo ? 0.80 : 0.74
        flIni: root.completo ? 0.80 : 0.76
        flFim: root.completo ? 0.90 : 0.88
    }

    Reveal {
        t: root.tt; start: 600; dx: 8
        anchors.right: parent.right; anchors.rightMargin: 64
        anchors.bottom: parent.bottom; anchors.bottomMargin: 56
        Row {
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Plasma  ·  KDE"
                color: CK.txt2
                font.family: CK.fontUi
                font.pixelSize: 13
            }
            Rectangle { width: CK.band; height: 16; color: CK.red; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
