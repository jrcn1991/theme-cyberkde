// CyberKDE — tela de bloqueio (kscreenlocker_greet, Plasma 6.6).
// Substitui só o ponto de entrada contents/lockscreen/LockScreen.qml do pacote de shell do Plasma;
// os componentes ficam em contents/lockscreen/cyberkde/. O PasswordSync (sincroniza a senha entre
// monitores) vem do qmldir original da mesma pasta.
// Contexto dado pelo kscreenlocker: authenticator, kscreenlocker_userName, kscreenlocker_userImage,
// config (lockscreen/config.xml original) e wallpaper.
import QtQuick
import org.kde.kirigami as Kirigami
import "cyberkde"

Item {
    id: root

    // Propriedades e sinais "mágicos" que o kscreenlocker procura na raiz.
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false
    signal suspendToDisk()
    signal suspendToRam()

    implicitWidth: 800
    implicitHeight: 600

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // Prévias fora da tela (preview/render_previews.py).
    property real previewT: -1
    property var previewDate: null

    // Respeita o AnimationDurationFactor do KDE (longDuration = 200 ms × fator; 0 = sem animação).
    readonly property real factor: Kirigami.Units.longDuration > 0 ? Kirigami.Units.longDuration / 200 : 0
    readonly property bool showClock: typeof config === "undefined" || !config || config.alwaysShowClock !== false
    readonly property var lockedAt: new Date()
    property bool noPassword: false
    property real t: 0

    Component.onCompleted: {
        CK.factor = factor
        panel.password = Qt.binding(() => PasswordSync.password)
        if (previewT < 0)
            intro.start()
        panel.focusInput()
        Qt.callLater(() => authenticator.startAuthenticating())
    }
    onPreviewTChanged: {
        if (previewT >= 0) {
            intro.stop()
            t = previewT
        }
    }
    onClearPassword: {
        panel.password = ""
        panel.password = Qt.binding(() => PasswordSync.password)
        panel.focusInput()
    }

    // Uso frequente: o ritual de apresentação é 25% mais curto que o do login (~615 ms).
    NumberAnimation {
        id: intro
        target: root
        property: "t"
        from: 0
        to: CK.introTotal
        duration: CK.introTotal * 0.75 * root.factor
        onFinished: panel.focusInput()
    }

    Binding {
        target: PasswordSync
        property: "password"
        value: panel.password
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0)  // falhas de leitor de digital/cartão não passam pela senha
                return
            panel.fail("Senha incorreta. Aguarde um instante e tente de novo.")
            graceTimer.restart()
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit()
            } else {
                root.noPassword = true
                panel.busy = false
                panel.info("Nenhuma senha é necessária: use Desbloquear.")
            }
        }
        function onInfoMessageChanged() {
            panel.info(authenticator.infoMessage)
        }
        function onErrorMessageChanged() {
            panel.info(authenticator.errorMessage)
        }
        function onPromptForSecretChanged() {
            panel.busy = false
            panel.focusInput()
        }
    }

    // Depois de uma falha, o PAM pede um intervalo; o campo fica travado e a autenticação recomeça.
    Timer {
        id: graceTimer
        interval: 3000
        onTriggered: {
            root.clearPassword()
            authenticator.startAuthenticating()
        }
    }

    Backdrop {
        anchors.fill: parent
        source: Qt.resolvedUrl("cyberkde/background.png")
        t: root.t
    }

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
                text: "//  SESSÃO BLOQUEADA"
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
                text: "BLOQUEADA ÀS"
                color: CK.txt2
                font.family: CK.fontUi
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.6
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(root.previewDate ? root.previewDate : root.lockedAt, "HH:mm")
                color: CK.txt1
                font.family: CK.fontUi
                font.pixelSize: 15
            }
            Rectangle { width: CK.band; height: 18; color: CK.cyan; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Painel no centro exato; divisor e relógio ancorados à esquerda dele (mesma composição do login).
    ClockBlock {
        anchors.right: divider.left
        anchors.rightMargin: 56
        anchors.verticalCenter: panel.verticalCenter
        // telas estreitas: encolhe até caber à esquerda do painel (40 px de folga na borda)
        transformOrigin: Item.Right
        scale: Math.min(1, Math.max(0, divider.x - 56 - 40) / Math.max(1, implicitWidth))
        t: root.t
        fixedDate: root.previewDate
        visible: root.showClock
    }

        Item {
            id: divider
            anchors.right: panel.left
            anchors.rightMargin: 56
            width: 9
            height: panel.height + 120
            anchors.verticalCenter: panel.verticalCenter
            visible: root.showClock
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
            mode: "lock"
            t: root.t
            lockUserName: kscreenlocker_userName
            lockAvatar: kscreenlocker_userImage
                        ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
            inputEnabled: !graceTimer.running && !authenticator.graceLocked
            onSubmit: (user, password, session) => {
                if (root.noPassword)
                    Qt.quit()
                else
                    authenticator.respond(password)
            }
        }

    Reveal {
        t: root.t; start: 500
        x: 64
        anchors.bottom: parent.bottom; anchors.bottomMargin: 60
        Text {
            text: "Enter desbloqueia  ·  Esc apaga a tela"
            color: CK.txt2
            font.family: CK.fontUi
            font.pixelSize: 13
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 64
        anchors.bottomMargin: 56
        spacing: 10

        Reveal {
            t: root.t; start: 460; dx: 8
            visible: root.suspendToRamSupported
            CyberButton { text: "Suspender"; icon: "suspend"; activeFocusOnTab: false; onClicked: root.suspendToRam() }
        }
        Reveal {
            t: root.t; start: 490; dx: 8
            visible: root.suspendToDiskSupported
            CyberButton { text: "Hibernar"; icon: "hibernate"; activeFocusOnTab: false; onClicked: root.suspendToDisk() }
        }
    }
}
