import QtQuick

// Base de uma seção: abre uma "janela de entrada" de ~1 s em que os itens com Cascata se montam
// em sequência (molduras traçadas, conteúdo em blocos com flicker). Conteúdo rolável.
Item {
    id: s
    property bool ativa: false
    property bool entrando: false
    property var app
    property real margem: 28
    default property alias conteudo: corpo.data
    property alias flick: flick
    property alias corpo: corpo

    visible: opacity > 0
    opacity: ativa ? 1 : 0
    // a seção nova entra "no escuro": os painéis se montam por conta própria (Cascata); a antiga
    // sai em 60 ms
    Behavior on opacity { NumberAnimation { duration: Tema.press } }

    onAtivaChanged: if (ativa) { entrando = false; entrando = true; janela.restart(); flick.contentY = 0 }
    Component.onCompleted: if (ativa) { entrando = true; janela.restart() }
    Timer { id: janela; interval: 1000; onTriggered: s.entrando = false }
    // remonta o conteúdo (troca de grupo na SYS.CONFIG, nova busca)
    function reentrar() { entrando = false; entrando = true; janela.restart(); flick.contentY = 0 }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: corpo.implicitHeight + s.margem * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: corpo
            x: s.margem; y: s.margem - 6
            width: flick.width - s.margem * 2
            spacing: 20
        }
    }
    // barra de rolagem fina
    Rectangle {
        visible: flick.contentHeight > flick.height
        anchors.right: parent.right; anchors.rightMargin: 6
        width: 3
        y: flick.visibleArea.yPosition * flick.height
        height: Math.max(30, flick.visibleArea.heightRatio * flick.height)
        color: Tema.alfa(Tema.destaque, 0.5)
    }
}
