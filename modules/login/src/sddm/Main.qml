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

    // Opções do efeito "login" (cyberkde efeito login): vêm do Opcoes.qml que a fase grava no tema;
    // são propriedades para as prévias poderem trocar.
    property string entrada: Opcoes.entrada     // completa | curta | fatias | nenhuma
    property string painel: Opcoes.painel       // centro | esquerda
    property bool sucesso: Opcoes.sucesso       // "ACESSO CONCEDIDO" antes de sair
    readonly property bool esquerda: painel === "esquerda"
    readonly property bool fatias: entrada === "fatias" && montagem.ativa  // sem GPU: entrada completa

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
        if (previewT < 0) {
            if (entrada === "nenhuma" || factor <= 0)
                t = CK.introTotal
            else
                intro.start()
        }
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
        duration: CK.introTotal * root.factor * (root.entrada === "curta" ? 0.5 : 1)
        onFinished: panel.focusInput()
    }

    // Sucesso: a confirmação aparece (≤200 ms) e só então a tela começa a sair.
    Timer {
        id: leaveTimer
        interval: 200
        onTriggered: root.leaving = true
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
            anchors.right: root.esquerda ? undefined : divider.left
            anchors.left: root.esquerda ? divider.right : undefined
            anchors.rightMargin: 56
            anchors.leftMargin: 56
            anchors.verticalCenter: painelBox.verticalCenter
            transformOrigin: root.esquerda ? Item.Left : Item.Right
            scale: root.esquerda
                   ? Math.min(1, Math.max(0, stage.width - (divider.x + divider.width) - 56 - 40) / Math.max(1, implicitWidth))
                   : Math.min(1, Math.max(0, divider.x - 56 - 40) / Math.max(1, implicitWidth))
            t: root.t
            fixedDate: root.previewDate
            visible: String(config.showClock) !== "false"
        }

            Item {
                id: divider
                anchors.right: root.esquerda ? undefined : painelBox.left
                anchors.left: root.esquerda ? painelBox.right : undefined
                anchors.rightMargin: 56 - painelBox.folga
                anchors.leftMargin: 56 - painelBox.folga
                width: 9
                height: panel.height + 120
                anchors.verticalCenter: painelBox.verticalCenter
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

            // Caixa com folga em volta do painel (a aba e o halo saem dele): é o que a Montagem fatia.
            Item {
                id: painelBox
                readonly property int folga: 30
                width: panel.width + 2 * folga
                height: panel.height + 2 * folga
                // centro exato, ou à esquerda (lista e detalhe: painel à esquerda, relógio à direita)
                anchors.horizontalCenter: root.esquerda ? undefined : parent.horizontalCenter
                anchors.left: root.esquerda ? parent.left : undefined
                anchors.leftMargin: Math.round(parent.width * 0.11) - folga
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -8
                focus: true

            LoginPanel {
                id: panel
                x: painelBox.folga
                y: painelBox.folga
                focus: true
                mode: "login"
                // na entrada "fatias" o painel já está pronto e quem o apresenta é a Montagem
                t: root.fatias ? 100000 : root.t
                userModel: root.users
                userIndex: root.users && root.users.lastIndex >= 0 ? root.users.lastIndex : 0
                sessionModel: root.sessions
                sessionIndex: root.sessions && root.sessions.lastIndex >= 0 ? root.sessions.lastIndex : 0
                capsLock: root.kbd ? !!root.kbd.capsLock : false
                onSubmit: (user, password, session) => sddm.login(user, password, session)
            }
            }

        Montagem {
            id: montagem
            alvo: painelBox
            t: root.fatias ? root.t / CK.introTotal : 1
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
            if (root.sucesso) {
                panel.concedido()
                leaveTimer.start()
            } else {
                root.leaving = true
            }
        }
        function onInformationMessage(message) {
            panel.info(message)
        }
    }
}
