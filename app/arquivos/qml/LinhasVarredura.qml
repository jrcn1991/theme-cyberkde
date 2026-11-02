import QtQuick
import "../../qml"

// Linhas de varredura finas sobre a superfície (a cada "passo" px) e um filete que desce UMA vez quando
// "ligado" acende. Para o painel-subpasta sob o mouse. Movimento reduzido/mínimo: nada.
Item {
    id: l
    property bool ligado: false
    property color cor: Tema.secundaria
    property real passo: 4
    anchors.fill: parent
    enabled: false
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    visible: ligado && completo
    Repeater {
        model: l.visible ? Math.floor(l.height / l.passo) : 0
        Rectangle { required property int index; y: index * l.passo + 1; width: l.width; height: 1; color: Tema.alfa(l.cor, 0.10) }
    }
    Rectangle {
        id: filete
        width: l.width; height: 2
        color: Tema.alfa(l.cor, 0.85)
        visible: desce.running
        Rectangle { anchors.bottom: parent.top; width: parent.width; height: 10
            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Tema.alfa(l.cor, 0.25) } } }
    }
    NumberAnimation { id: desce; target: filete; property: "y"; from: 0; to: l.height; duration: 220; easing.type: Easing.OutQuad }
    onLigadoChanged: if (ligado && completo) desce.restart()
    Component.onCompleted: if (ligado && completo) desce.restart()
}
