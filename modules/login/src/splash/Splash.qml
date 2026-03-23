// CyberKDE — splash de inicialização (KSplashQML, pacote look-and-feel org.cyberkde.desktop).
// O ksplashqml avança "stage" de 1 a 6 (initial, startPlasma, kcminit, ksmserver, wm, desktop)
// e fecha no 6. A barra segmentada mostra esse progresso real; a varredura é só um acento.
// Orbitron só no título curto "CYBERKDE"; todo o resto em Noto Sans.
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
    readonly property int introTotal: 900

    property real t: 0
    property real progress: 0.04
    property real rescanP: -1

    Component.onCompleted: {
        CK.factor = factor
        if (previewT < 0)
            intro.start()
    }
    onPreviewTChanged: {
        if (previewT >= 0) {
            intro.stop()
            t = previewT
        }
    }
    onStageChanged: {
        progress = Math.max(progress, Math.min(1, stage / 6))
        if (t >= introTotal)
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
        t: root.t
        imageOpacity: 0.45
    }

    Column {
        anchors.centerIn: parent
        width: 640

        Reveal {
            t: root.t; start: 60; dx: 0; dy: 6
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

        Item {
            id: titleBox
            width: parent.width
            height: title.implicitHeight + 8

            readonly property bool glitch: CK.factor > 0 && root.t >= 400 && root.t < 460
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
                opacity: CK.ramp(root.t, 140, 260)
            }
            ScanLine {
                anchors.fill: parent
                anchors.margins: -6
                progress: root.rescanP >= 0 ? root.rescanP : (root.t - 180) / 380
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 140 * CK.ramp(root.t, 300, 220)
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
                    opacity: CK.ramp(root.t, 320 + index * 14, 160)
                    Behavior on color { ColorAnimation { duration: CK.dur(CK.micro) } }
                }
            }
        }

        Item { width: 1; height: 12 }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: bar.width
            height: 20
            opacity: CK.ramp(root.t, 520, 200)
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

    Reveal {
        t: root.t; start: 600; dx: 8
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
