// CyberKDE — painel de autenticação compartilhado pelo login (SDDM, mode "login") e pelo bloqueio
// (kscreenlocker, mode "lock").
//
// Silhueta: painel chanfrado (16 px em cima à direita, 8 px embaixo), faixa vermelha lateral de 4 px,
// aba curta com a categoria, contorno de 1 px e marcador de atividade junto ao chanfro.
// Apresentação (relógio "t" em ms, vindo da raiz; seção 12.2/13.3 do documento):
//   0–200   moldura desenhada da esquerda para a direita, faixa vermelha cresce, aba aparece
//   60–260  superfície ganha opacidade e sobe 8 px
//   160–560 varredura ciano atravessa o painel
//   220–540 grupos (título, usuário, senha, mensagens, ações) entram com defasagem de 30 ms
//   430–490 acento de glitch (moldura fantasma ciano/vermelha, 60 ms) e depois tudo estabiliza
// Erro: tremida curta (~290 ms), campo e faixa em vermelho e mensagem clara até a próxima digitação.
import QtQuick
import "."

FocusScope {
    id: root

    // ---------------------------------------------------------------- API
    property string mode: "login"
    property real t: 100000
    property var userModel: null
    property int userIndex: 0
    property var sessionModel: null
    property int sessionIndex: 0
    property string lockUserName: ""
    property string lockRealName: ""
    property string lockAvatar: ""
    property bool capsLock: false
    property bool inputEnabled: true
    property bool busy: false
    property string message: ""
    property string messageKind: ""        // "error" | "info"
    property alias password: pass.text
    property alias passwordField: pass
    signal submit(string user, string password, int session)

    // ---------------------------------------------------------------- estado
    readonly property bool isLock: mode === "lock"
    property bool manualUser: false
    readonly property bool typingUser: !isLock && (manualUser || userRep.count === 0)
    readonly property bool glitch: CK.factor > 0 && t >= 430 && t < 490

    readonly property Item curUser: userRep.count > 0
        ? userRep.itemAt(Math.max(0, Math.min(userIndex, userRep.count - 1))) : null
    readonly property string userName: isLock ? lockUserName : (curUser ? curUser.uName : "")
    readonly property string realName: isLock ? (lockRealName || lockUserName)
                                              : (curUser ? (curUser.uReal || curUser.uName) : "")
    readonly property string avatar: isLock ? lockAvatar : (curUser ? curUser.uIcon : "")
    readonly property string sessionName: {
        const it = sessRep.count > 0 ? sessRep.itemAt(Math.max(0, Math.min(sessionIndex, sessRep.count - 1))) : null
        return it ? it.sName : ""
    }

    readonly property string msgKind: message !== "" ? messageKind : (capsLock ? "caps" : "")
    readonly property string msgText: message !== "" ? message : (capsLock ? "Caps Lock está ativado." : "")
    readonly property color msgColor: msgKind === "error" ? CK.danger : (msgKind === "caps" ? CK.gold : CK.cyan)

    readonly property bool failed: messageKind === "error" && message !== ""
    readonly property string statusText: busy ? "VERIFICANDO" : (failed ? "FALHA" : "PRONTO")
    readonly property color statusColor: failed ? CK.danger : CK.cyan

    property real shakeX: 0
    property real errorGlow: 0

    width: 468
    implicitHeight: shell.height
    height: implicitHeight

    // ---------------------------------------------------------------- ações
    function fail(msg) {
        busy = false
        message = msg
        messageKind = "error"
        pass.input.selectAll()
        pass.forceActiveFocus()
        shake.restart()
        errorPulse.restart()
    }

    function info(msg) {
        if (msg) {
            message = msg
            messageKind = "info"
        }
    }

    function focusInput() {
        if (typingUser && userField.text.length === 0)
            userField.forceActiveFocus()
        else
            pass.forceActiveFocus()
    }

    function startLogin() {
        if (busy || !inputEnabled)
            return
        const u = typingUser ? userField.text.trim() : userName
        if (!isLock && u.length === 0) {
            fail("Digite o nome de usuário.")
            userField.forceActiveFocus()
            return
        }
        busy = true
        message = ""
        messageKind = ""
        submit(u, pass.text, sessionIndex)
    }

    function userEntries() {
        const a = []
        for (let i = 0; i < userRep.count; i++) {
            const it = userRep.itemAt(i)
            a.push(it ? (it.uReal || it.uName) : "")
        }
        a.push("Outro usuário…")
        return a
    }

    function sessionEntries() {
        const a = []
        for (let i = 0; i < sessRep.count; i++) {
            const it = sessRep.itemAt(i)
            a.push(it ? it.sName : "")
        }
        return a
    }

    function openChooser(list, anchor, above) {
        const wasOpen = list.open
        userChooser.open = false
        sessionChooser.open = false
        if (wasOpen) {
            focusInput()
            return
        }
        const p = anchor.mapToItem(shell, 0, 0)
        list.x = above ? p.x : Math.max(0, p.x + anchor.width - list.width)
        list.y = above ? p.y - list.height - 6 : p.y + anchor.height + 6
        list.open = true
    }

    function chooseUser(i) {
        userChooser.open = false
        if (i >= userRep.count) {
            manualUser = true
        } else {
            manualUser = false
            userIndex = i
        }
        pass.text = ""
        message = ""
        Qt.callLater(focusInput)
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: -9; duration: CK.dur(40); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: 8; duration: CK.dur(60); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: -5; duration: CK.dur(55); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: 3; duration: CK.dur(50); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: CK.dur(45); easing.type: Easing.OutQuad }
    }
    NumberAnimation {
        id: errorPulse
        target: root; property: "errorGlow"; from: 1; to: 0
        duration: CK.dur(700); easing.type: Easing.OutCubic
    }

    // modelos (invisíveis): dão acesso a nome, nome real, foto e sessões pelo índice
    Item {
        visible: false
        Repeater {
            id: userRep
            model: root.isLock ? 0 : root.userModel
            delegate: Item {
                property string uName: model.name !== undefined ? String(model.name) : ""
                property string uReal: model.realName !== undefined ? String(model.realName) : ""
                property string uIcon: model.icon !== undefined && model.icon !== null ? String(model.icon) : ""
            }
        }
        Repeater {
            id: sessRep
            model: root.isLock ? 0 : root.sessionModel
            delegate: Item {
                property string sName: model.name !== undefined ? String(model.name) : ""
            }
        }
    }

    // ---------------------------------------------------------------- painel
    Item {
        id: shell
        width: root.width
        height: content.y + content.height + 28
        transform: Translate { x: root.shakeX; y: 8 * (1 - CK.ramp(root.t, 60, 220)) }

        // aba de categoria
        Chamfer {
            y: -22
            width: tabLabel.implicitWidth + 30
            height: 22
            tr: 8
            fillColor: CK.red
            opacity: CK.ramp(root.t, 0, 140)
            Text {
                id: tabLabel
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.isLock ? "BLOQUEIO" : "ACESSO"
                color: CK.textOnRed
                font.family: CK.fontUi
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.6
            }
        }

        // superfície
        Chamfer {
            anchors.fill: parent
            tr: CK.chamferPanel
            br: CK.chamferButton
            fillColor: CK.alpha(CK.panel, 0.94)
            opacity: CK.ramp(root.t, 60, 200)
        }

        // moldura, desenhada da esquerda para a direita
        Item {
            width: parent.width * CK.ramp(root.t, 0, 180)
            height: parent.height
            clip: true
            Chamfer {
                width: shell.width
                height: shell.height
                tr: CK.chamferPanel
                br: CK.chamferButton
                borderColor: CK.line
            }
            Rectangle { x: shell.width - CK.chamferPanel - 72; y: 0; width: 56; height: 2; color: CK.red }
        }

        // acento de glitch: moldura fantasma com separação de cor (60 ms, só na apresentação)
        Chamfer {
            anchors.fill: parent; anchors.leftMargin: 3; anchors.rightMargin: -3
            tr: CK.chamferPanel; br: CK.chamferButton
            borderColor: CK.alpha(CK.cyan, 0.7)
            visible: root.glitch
        }
        Chamfer {
            anchors.fill: parent; anchors.leftMargin: -3; anchors.rightMargin: 3
            tr: CK.chamferPanel; br: CK.chamferButton
            borderColor: CK.alpha(CK.red, 0.7)
            visible: root.glitch
        }

        // faixa vermelha lateral + halo curto no erro
        Rectangle {
            x: -7
            width: 3
            height: parent.height
            color: CK.red
            opacity: 0.55 * root.errorGlow
            visible: root.errorGlow > 0
        }
        Rectangle {
            x: root.glitch ? -2 : 0
            width: CK.band
            height: parent.height * CK.ramp(root.t, 0, 200)
            color: CK.red
        }

        Column {
            id: content
            x: CK.band + 24
            y: 24
            width: parent.width - x - 28

            // título
            Reveal {
                t: root.t; start: 220
                width: content.width
                Column {
                    width: content.width
                    spacing: 6
                    Item {
                        width: parent.width
                        height: 30
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isLock ? "Sessão bloqueada" : "Identificação"
                            color: CK.txt1
                            font.family: CK.fontUi
                            font.pixelSize: 22
                            font.weight: Font.Medium
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Rectangle {
                                width: 6; height: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.statusColor
                            }
                            Text {
                                text: root.statusText
                                color: root.statusColor
                                font.family: CK.fontUi
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 1.6
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.isLock ? "Digite a senha para voltar à sua sessão."
                                          : "Escolha o usuário e digite a senha."
                        color: CK.txt2
                        font.family: CK.fontUi
                        font.pixelSize: 14
                    }
                }
            }

            Item { width: 1; height: 14 }

            // divisor com marcador vermelho
            Reveal {
                t: root.t; start: 240
                width: content.width
                Item {
                    width: content.width
                    height: 3
                    Rectangle { y: 1; width: parent.width; height: 1; color: CK.line }
                    Rectangle { width: 40; height: 3; color: CK.red }
                }
            }

            Item { width: 1; height: 18 }

            // usuário
            Reveal {
                t: root.t; start: 250
                width: content.width
                Column {
                    width: content.width
                    spacing: 12
                    Item {
                        id: userRow
                        width: parent.width
                        height: 56
                        Avatar {
                            id: avatarItem
                            width: 56; height: 56
                            source: root.avatar
                            name: root.realName
                            generic: root.typingUser
                        }
                        Column {
                            anchors.left: avatarItem.right
                            anchors.leftMargin: 14
                            anchors.right: switchBtn.visible ? switchBtn.left : parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.typingUser ? "Outro usuário" : root.realName
                                color: CK.txt1
                                font.family: CK.fontUi
                                font.pixelSize: 18
                                font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.typingUser ? "Digite o nome de usuário e a senha"
                                    : root.realName !== root.userName ? "@" + root.userName
                                    : (root.isLock ? "Sessão local" : "Conta local")
                                color: CK.txt2
                                font.family: CK.fontUi
                                font.pixelSize: 14
                            }
                        }
                        CyberButton {
                            id: switchBtn
                            objectName: "userButton"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            compact: true
                            visible: !root.isLock && userRep.count > 0
                            text: "Trocar"
                            trailing: "down"
                            onClicked: root.openChooser(userChooser, switchBtn, false)
                        }
                    }
                    CyberField {
                        id: userField
                        width: parent.width
                        visible: root.typingUser
                        placeholder: "Nome de usuário"
                        enabled: root.inputEnabled && !root.busy
                        onAccepted: pass.forceActiveFocus()
                    }
                }
            }

            Item { width: 1; height: 18 }

            // senha
            Reveal {
                t: root.t; start: 280
                width: content.width
                Column {
                    width: content.width
                    spacing: 8
                    Text {
                        text: "SENHA"
                        color: CK.txt2
                        font.family: CK.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.6
                    }
                    CyberField {
                        id: pass
                        width: parent.width
                        password: true
                        focus: true
                        placeholder: "Senha"
                        error: root.failed
                        enabled: root.inputEnabled && !root.busy
                        onAccepted: root.startLogin()
                        onTextChanged: {
                            if (root.messageKind === "error" && text.length > 0)
                                root.message = ""
                        }
                    }
                }
            }

            // mensagens (espaço reservado: nada pula quando aparece um erro)
            Reveal {
                t: root.t; start: 310
                width: content.width
                Item {
                    width: content.width
                    height: 50
                    Item {
                        anchors.fill: parent
                        anchors.topMargin: 10
                        anchors.bottomMargin: 4
                        opacity: root.msgText !== "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: CK.dur(CK.fast) } }
                        Rectangle { anchors.fill: parent; color: CK.alpha(root.msgColor, 0.12) }
                        Rectangle { width: CK.markerWidth; height: parent.height; color: root.msgColor }
                        CyberIcon {
                            x: 13
                            anchors.verticalCenter: parent.verticalCenter
                            name: "warn"
                            color: root.msgColor
                            width: 16; height: 16
                        }
                        Text {
                            x: 40
                            width: parent.width - 48
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.msgText
                            elide: Text.ElideRight
                            color: CK.txt1
                            font.family: CK.fontUi
                            font.pixelSize: 14
                        }
                    }
                }
            }

            Item { width: 1; height: 10 }

            // ações
            Reveal {
                t: root.t; start: 340
                width: content.width
                Item {
                    width: content.width
                    height: 44
                    CyberButton {
                        id: sessionBtn
                        objectName: "sessionButton"
                        visible: !root.isLock && sessRep.count > 0
                        anchors.left: parent.left
                        width: parent.width - loginBtn.width - 12
                        height: 44
                        alignLeft: true
                        icon: "session"
                        trailing: "down"
                        text: root.sessionName
                        onClicked: root.openChooser(sessionChooser, sessionBtn, true)
                    }
                    CyberButton {
                        id: loginBtn
                        anchors.right: parent.right
                        width: root.isLock ? parent.width : 156
                        height: 44
                        primary: true
                        busy: root.busy
                        trailing: root.busy ? "" : "arrow"
                        text: root.busy ? "Verificando…" : (root.isLock ? "Desbloquear" : "Entrar")
                        enabled: root.inputEnabled
                        onClicked: root.startLogin()
                    }
                }
            }
        }

        ScanLine {
            x: CK.band
            width: parent.width - CK.band - 2
            height: parent.height
            progress: (root.t - 160) / 400
        }

        ChoiceList {
            id: userChooser
            title: "USUÁRIO"
            width: 300
            entries: root.userEntries()
            currentIndex: root.manualUser ? userRep.count : root.userIndex
            onChosen: index => root.chooseUser(index)
            onDismissed: { open = false; root.focusInput() }
        }

        ChoiceList {
            id: sessionChooser
            title: "SESSÃO"
            width: Math.max(240, sessionBtn.width)
            entries: root.sessionEntries()
            currentIndex: root.sessionIndex
            onChosen: index => {
                root.sessionIndex = index
                open = false
                root.focusInput()
            }
            onDismissed: { open = false; root.focusInput() }
        }
    }
}
