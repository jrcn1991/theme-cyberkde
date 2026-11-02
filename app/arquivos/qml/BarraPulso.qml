import QtQuick
import "../../qml"

// Barra segmentada que ENCHE (anima até o valor) e dá um PULSO de brilho quando pulsar() é chamado
// (referência 11). Sem laço: o pulso é uma passada só. Movimento reduzido: enche direto, sem pulso.
Item {
    id: b
    property real valor: 0                 // 0..1
    property color cor: Tema.destaque
    property real larguraSeg: 5
    property real vao: 2
    property real limiarAlerta: 2          // acima disto, a cor de alerta (2 = nunca)
    implicitHeight: 6
    readonly property int n: Math.max(4, Math.floor((width + vao) / (larguraSeg + vao)))
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    property real mostrado: valor
    Behavior on mostrado { enabled: b.completo; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    readonly property int acesos: Math.round(Math.max(0, Math.min(1, mostrado)) * n)
    property real brilho: 0
    function pulsar() { if (completo) pulso.restart() }
    SequentialAnimation {
        id: pulso
        NumberAnimation { target: b; property: "brilho"; from: 0; to: 1; duration: 90 }
        NumberAnimation { target: b; property: "brilho"; to: 0; duration: 380; easing.type: Easing.OutQuad }
    }
    Row {
        spacing: b.vao
        Repeater {
            model: b.n
            Rectangle {
                required property int index
                width: b.larguraSeg; height: b.height
                readonly property bool aceso: index < b.acesos
                readonly property color c: b.mostrado >= b.limiarAlerta ? Tema.alerta : b.cor
                color: aceso ? Qt.tint(c, Tema.alfa(Tema.texto, 0.55 * b.brilho)) : Tema.alfa(b.cor, 0.14 + 0.1 * b.brilho)
            }
        }
    }
}
