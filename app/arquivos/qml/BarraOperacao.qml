import QtQuick
import "../../qml"

// Barra segmentada da operação (referência 11): enche segmento a segmento; quando o progresso anda, um
// trecho curto logo à frente acende na secundária por ~120 ms (o "glitch" da referência, nunca em
// laço); "indeterminado" corre um bloco; ao CONCLUIR, todos os segmentos dão um flash e aparece DONE.
// Movimento reduzido: enche direto, sem glitch nem flash; mínimo: igual, sem o bloco correndo.
Item {
    id: b
    property real valor: 0
    property bool indeterminado: false
    property string estado: ""          // "estado:id" da operação ("ok:…" = concluiu; o id distingue duas seguidas)
    property color cor: Tema.destaque
    property real larguraSeg: 7
    property real vao: 2
    implicitHeight: 10
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    readonly property int n: Math.max(4, Math.floor((width + vao) / (larguraSeg + vao)))
    readonly property int acesos: Math.round(Math.max(0, Math.min(1, valor)) * n)

    // glitch: ao avançar, acende 2–4 segmentos à frente por um instante
    property int glitchIni: -1
    property int glitchLen: 0
    onAcesosChanged: {
        if (!completo || indeterminado || acesos >= n) return
        glitchIni = acesos; glitchLen = 2 + (acesos * 7) % 3
        apagaGlitch.restart()
    }
    Timer { id: apagaGlitch; interval: 120; onTriggered: b.glitchIni = -1 }

    // flash e DONE ao concluir
    property real flash: 0
    property bool feito: false
    onEstadoChanged: {
        if (!estado.startsWith("ok:")) { feito = false; return }
        feito = true
        glitchIni = -1; apagaGlitch.stop()
        if (completo) fim.restart()
        some.restart()
    }
    SequentialAnimation {
        id: fim
        NumberAnimation { target: b; property: "flash"; from: 0; to: 1; duration: 60 }
        NumberAnimation { target: b; property: "flash"; to: 0.2; duration: 60 }
        NumberAnimation { target: b; property: "flash"; to: 1; duration: 60 }
        NumberAnimation { target: b; property: "flash"; to: 0; duration: 420; easing.type: Easing.OutQuad }
    }
    Timer { id: some; interval: 1800; onTriggered: b.feito = false }

    // indeterminado: bloco de 4 segmentos correndo (só enquanto indeterminado e visível)
    property int cabeca: 0
    Timer {
        interval: 70; repeat: true
        running: b.indeterminado && b.visible && arquivos.movimento !== "minimo"
        onTriggered: b.cabeca = (b.cabeca + 1) % (b.n + 4)
    }

    Row {
        spacing: b.vao
        opacity: b.feito ? 0.35 + 0.65 * b.flash : 1
        Repeater {
            model: b.n
            Rectangle {
                required property int index
                width: b.larguraSeg; height: b.height
                readonly property bool bloco: b.indeterminado && index <= b.cabeca && index > b.cabeca - 4
                readonly property bool glitch: b.glitchIni >= 0 && index >= b.glitchIni && index < b.glitchIni + b.glitchLen
                color: glitch ? Tema.alfa(Tema.secundaria, 0.9)
                     : (index < b.acesos || bloco || b.feito) ? Qt.tint(b.cor, Tema.alfa(Tema.texto, 0.6 * b.flash))
                     : Tema.alfa(b.cor, 0.16)
            }
        }
    }
    Text {
        visible: b.feito
        anchors.centerIn: parent
        text: "DONE"
        font.family: Tema.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 2
        color: Tema.escuro
        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -2; anchors.leftMargin: -5; anchors.rightMargin: -5; color: b.cor }
    }
}
