// CyberKDE — tela de login (tema SDDM "cyberkde", Theme-API 2.0, Qt 6).
// O SDDM expõe ao QML: sddm, userModel, sessionModel, screenModel, config (theme.conf), keyboard
// e primaryScreen. Cada monitor recebe uma cópia desta tela (uma QQuickView por tela).
import QtQuick
import "components"

Item {
    id: root

    width: 1920
    height: 1080

    // Prévias fora da tela: congelam a apresentação e o horário (ver preview/render_previews.py).
    property real previewT: -1
    property var previewDate: null

    // Velocidade das animações: o SDDM roda como outro usuário e não lê o AnimationDurationFactor
    // do usuário; por isso vem do theme.conf (animationFactor=0 desliga as animações).
    readonly property real factor: {
        const f = parseFloat(config.animationFactor)
        return isNaN(f) ? 1 : Math.max(0, f)
    }
    readonly property var users: userModel
    readonly property var sessions: sessionModel
    readonly property var kbd: typeof keyboard !== "undefined" ? keyboard : null

    property real t: 0
    property bool leaving: false

    readonly property url background: {
        const b = config.background ? String(config.background) : ""
        if (b === "")
            return Qt.resolvedUrl("background.png")
        if (b.startsWith("/"))
            return "file://" + b
        if (b.indexOf(":/") > 0)
            return b
        return Qt.resolvedUrl(b)
    }

    Component.onCompleted: {
        CK.factor = factor
        if (previewT < 0)
            intro.start()
        panel.focusInput()
    }
    onPreviewTChanged: {
        if (previewT >= 0) {
            intro.stop()
            t = previewT
        }
    }

    NumberAnimation {
        id: intro
        target: root
        property: "t"
        from: 0
        to: CK.introTotal
        duration: CK.introTotal * root.factor
        onFinished: panel.focusInput()
    }

    // O SDDM às vezes só ativa a janela depois de mostrada; reforça o foco (mesmo truque do Breeze).
    Timer {
        interval: 250
        running: true
        onTriggered: panel.focusInput()
    }

    Backdrop {
        anchors.fill: parent
        source: root.background
        t: root.t
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.leaving ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: CK.dur(CK.close) } }

        // identificação
        Reveal {
            t: root.t; start: 90
            x: 64; y: 44
            Row {
                spacing: 12
                Rectangle { width: CK.band; height: 18; color: CK.red; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CYBERKDE"
                    color: CK.txt1
                    font.family: CK.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: 3
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "//  TERMINAL DE ACESSO"
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 13
                    font.letterSpacing: 1.5
                }
            }
        }
        Reveal {
            t: root.t; start: 120; dx: 8
            anchors.right: parent.right; anchors.rightMargin: 64; y: 44
            Row {
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NÓ"
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.6
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sddm.hostName || ""
                    color: CK.txt1
                    font.family: CK.fontUi
                    font.pixelSize: 15
                }
                Rectangle { width: CK.band; height: 18; color: CK.cyan; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Painel no centro exato (cai dentro do enquadramento central do papel de parede);
        // divisor e relógio ancorados à esquerda dele.
        // Em telas estreitas (ex.: 1280 px) o relógio não cabe à esquerda do painel: encolhe a partir
        // da borda direita até caber, com 40 px de folga na borda da tela.
        ClockBlock {
            id: clock
            anchors.right: divider.left
            anchors.rightMargin: 56
            anchors.verticalCenter: panel.verticalCenter
            transformOrigin: Item.Right
            scale: Math.min(1, Math.max(0, divider.x - 56 - 40) / Math.max(1, implicitWidth))
            t: root.t
            fixedDate: root.previewDate
            visible: String(config.showClock) !== "false"
        }

            Item {
                id: divider
                anchors.right: panel.left
                anchors.rightMargin: 56
                width: 9
                height: panel.height + 120
                anchors.verticalCenter: panel.verticalCenter
                opacity: CK.ramp(root.t, 40, 200)
                Rectangle { x: 4; width: 1; height: parent.height * CK.ramp(root.t, 40, 280); color: CK.line }
                Rectangle { width: 9; height: 1; color: CK.red }
                Rectangle { y: parent.height - 1; width: 9; height: 1; color: CK.red; opacity: CK.ramp(root.t, 280, 80) }
                Repeater {
                    model: 6
                    Rectangle {
                        x: 2
                        y: (index + 1) * parent.height / 7
                        width: 5
                        height: 1
                        color: CK.alpha(CK.txt1, 0.25)
                    }
                }
            }

            LoginPanel {
                id: panel
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -8
                focus: true
                mode: "login"
                t: root.t
                userModel: root.users
                userIndex: root.users && root.users.lastIndex >= 0 ? root.users.lastIndex : 0
                sessionModel: root.sessions
                sessionIndex: root.sessions && root.sessions.lastIndex >= 0 ? root.sessions.lastIndex : 0
                capsLock: root.kbd ? !!root.kbd.capsLock : false
                onSubmit: (user, password, session) => sddm.login(user, password, session)
            }

        // ajuda e teclado
        Reveal {
            t: root.t; start: 500
            x: 64
            anchors.bottom: parent.bottom; anchors.bottomMargin: 60
            Column {
                spacing: 4
                Text {
                    text: "Enter entra  ·  Tab alterna os campos  ·  Esc fecha as listas"
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 13
                }
                Text {
                    readonly property var layouts: root.kbd && root.kbd.layouts ? root.kbd.layouts : []
                    visible: layouts.length > 1
                    text: visible ? "Teclado: " + layouts[root.kbd.currentLayout].longName : ""
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 13
                }
            }
        }

        // energia
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 64
            anchors.bottomMargin: 56
            spacing: 10

            Reveal {
                t: root.t; start: 460; dx: 8
                visible: !!sddm.canSuspend
                CyberButton { text: "Suspender"; icon: "suspend"; onClicked: sddm.suspend() }
            }
            Reveal {
                t: root.t; start: 490; dx: 8
                visible: !!sddm.canHibernate
                CyberButton { text: "Hibernar"; icon: "hibernate"; onClicked: sddm.hibernate() }
            }
            Reveal {
                t: root.t; start: 520; dx: 8
                visible: !!sddm.canReboot
                CyberButton { text: "Reiniciar"; icon: "reboot"; onClicked: sddm.reboot() }
            }
            Reveal {
                t: root.t; start: 550; dx: 8
                visible: !!sddm.canPowerOff
                CyberButton { text: "Desligar"; icon: "power"; onClicked: sddm.powerOff() }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            panel.fail("Senha incorreta. Confira e tente de novo.")
        }
        function onLoginSucceeded() {
            // O SDDM encerra a tela a qualquer momento depois disso; a saída é só um fade curto.
            root.leaving = true
        }
        function onInformationMessage(message) {
            panel.info(message)
        }
    }
}
