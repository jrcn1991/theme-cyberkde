import QtQuick
import "comum"

// CPU: carga total no arco (com o ponto no valor), o número com "% CPU" e a temperatura embaixo.
Modulo {
    id: m
    titulo: "CPU"; codigo: d.t("carga", "load")
    rodape: d.t("temp. ", "temp. ") + d.cpuTempTxt
    dica: d.t("Uso total da CPU (todos os núcleos), pelo sensor cpu/all/usage do ksystemstats. Fica na cor de alerta acima do limiar.",
              "Total CPU load (all cores), from the ksystemstats cpu/all/usage sensor. Turns to the alert color above the threshold.")
    readonly property bool quente: d.cpu >= d.limiar * 100
    readonly property int diam: Math.min(width, u(104))
    Arco {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: m.diam; height: width
        inicio: 210; abertura: 300; espessura: m.lw(3)
        trilho: Cores.alfa(Cores.texto, 0.2); cor: m.quente ? Cores.alerta : Cores.destaque
        valor: m.conta(m.d.cpu / 100)
        ponto: true
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(m.diam * 0.27)
        text: Math.round(m.conta(m.d.cpu))
        font.family: Cores.fIdentidade; font.pixelSize: m.fi(32); font.weight: Font.Medium
        color: m.quente ? Cores.alerta : Cores.texto
    }
    Rot { k: m.k; anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(m.diam * 0.67); text: "% CPU" }
    Val { k: m.k; anchors.horizontalCenter: parent.horizontalCenter; y: m.u(104); text: m.d.cpuTempTxt; color: Cores.texto2 }
}
