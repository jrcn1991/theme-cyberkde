import QtQuick
import "../../qml"

// Rolagem das visões (U4 da análise de UX): por cima de uma Flickable/ListView/GridView ("alvo"), com a
// mesma geometria. A roda anda "passo" px por clique (3 linhas, como no Dolphin; touchpad usa o delta
// em px), com um deslize curto (nenhum com movimento reduzido); Ctrl+roda é o zoom. À direita, a barra:
// 6 px em repouso e 10 px com o mouse em cima, alça no destaque (60%, 100% ao arrastar), arrastável;
// clique no trilho pagina. O item em si não pega cliques: só a roda e a barra.
Item {
    id: r
    property Flickable alvo: null
    property real passo: 66
    readonly property real fim: alvo ? Math.max(alvo.originY, alvo.originY + alvo.contentHeight - alvo.height) : 0
    readonly property bool cabe: !alvo || alvo.contentHeight <= alvo.height + 1

    function limitar(y) { return Math.max(alvo.originY, Math.min(fim, y)) }
    function irPara(y, suave) {
        if (!alvo) return
        y = limitar(y)
        if (!suave || Tema.reduzir) { desliza.stop(); alvo.contentY = y; return }
        desliza.stop(); desliza.from = alvo.contentY; desliza.to = y; desliza.start()
    }
    function mover(d) { irPara((desliza.running ? desliza.to : alvo.contentY) + d, true) }
    NumberAnimation { id: desliza; target: r.alvo; property: "contentY"; duration: 110; easing.type: Easing.OutCubic }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => {
            if (!r.alvo) return
            if (ev.modifiers & Qt.ControlModifier) { if (ev.angleDelta.y !== 0) Ds.janela.zoom(ev.angleDelta.y > 0 ? 1 : -1); return }
            if (r.cabe) return
            if (ev.pixelDelta.y !== 0) r.irPara(r.alvo.contentY - ev.pixelDelta.y, false)
            else r.mover(-ev.angleDelta.y / 120 * r.passo)
        }
    }

    // ---- barra
    Item {
        id: trilho
        visible: !r.cabe
        anchors.right: parent.right
        width: maTrilho.containsMouse || maTrilho.pressed ? 10 : 6
        height: parent.height
        Behavior on width { enabled: !Tema.reduzir; NumberAnimation { duration: 90 } }
        Rectangle { anchors.fill: parent; color: Tema.alfa(Tema.linha, maTrilho.containsMouse ? 0.55 : 0.25) }
        Rectangle {
            id: alca
            width: parent.width
            y: r.alvo ? Math.max(0, Math.min(trilho.height - height, r.alvo.visibleArea.yPosition * trilho.height)) : 0
            height: r.alvo ? Math.max(30, r.alvo.visibleArea.heightRatio * trilho.height) : 30
            color: Tema.alfa(Tema.destaque, maTrilho.pressed && maTrilho.arrastando ? 1 : 0.6)
        }
        MouseArea {
            id: maTrilho
            anchors.fill: parent; anchors.leftMargin: -4
            hoverEnabled: true
            preventStealing: true
            property bool arrastando: false
            property real dy: 0
            onPressed: (e) => {
                if (e.y >= alca.y && e.y <= alca.y + alca.height) { arrastando = true; dy = e.y - alca.y }
                else { arrastando = false; r.irPara(r.alvo.contentY + (e.y < alca.y ? -1 : 1) * r.alvo.height * 0.9, true) }
            }
            onPositionChanged: (e) => {
                if (!arrastando) return
                const livre = Math.max(1, trilho.height - alca.height)
                const frac = Math.max(0, Math.min(1, (e.y - dy) / livre))
                r.irPara(r.alvo.originY + frac * (r.fim - r.alvo.originY), false)
            }
            onReleased: arrastando = false
        }
    }
}
