import QtQuick
import "comum"

// Knob de um canal: anel aberto embaixo (o arco aceso vai até o valor, com um ponto na ponta), o valor
// com a unidade embaixo e o nome do canal (CPU°, GPU%…). Tudo em pixel inteiro (k = fator da tela).
Item {
    id: kb
    property real k: 1
    property real valor: 0              // 0..1
    property string numero: "--"        // texto do valor, já com a unidade ("62°C", "38%")
    property string nome: "CH"
    property bool alerta: false
    property real montado: 1
    function u(v) { return Math.round(v * k) }
    width: u(62); height: u(58)
    // de 0,5 em 0,5%: oscilação menor que um pixel do arco não dispara 320 ms de animação nem redesenho do Canvas
    property real _mostrado: Math.round(valor * 200) / 200 * montado
    Behavior on _mostrado { enabled: !Cores.reduzir; NumberAnimation { duration: Cores.d(320); easing.type: Easing.OutCubic } }
    readonly property color cor: alerta ? Cores.alerta : Cores.texto
    Arco {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: kb.u(28); height: width
        inicio: 210; abertura: 300; espessura: Math.max(2, kb.u(2.2))
        valor: kb._mostrado
        cor: kb.alerta ? Cores.alerta : Cores.destaque
        trilho: Cores.alfa(Cores.texto, 0.18)
        ponto: true
    }
    NumeroCintilante {
        anchors.horizontalCenter: parent.horizontalCenter
        y: kb.u(30)
        valor: kb.numero
        intervaloMin: 1500
        font.family: Cores.fMono; font.pixelSize: Math.max(11, kb.u(12)); font.weight: Font.Bold
        color: kb.cor
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: kb.u(45)
        text: kb.nome
        font.family: Cores.fTitulo; font.weight: Font.DemiBold; font.pixelSize: Math.max(10, kb.u(10.5))
        color: Cores.texto2
    }
}
