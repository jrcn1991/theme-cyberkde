import QtQuick
import QtQuick.Effects
import "comum"

// Ícone de condição (código WMO do Open-Meteo), montado com as camadas SVG de icones/ e tingido com
// a paleta: sol no destaque, nuvem e chuva na secundária, raio no alerta. Animação leve e econômica:
// a cada ~7 s um movimento curto (raios giram um pouco, nuvem flutua, chuva cai, raio pisca);
// fora disso, nada redesenha. Sem animação com o movimento em "mínimo".
Item {
    id: ic
    property int codigo: 0
    property bool dia: true
    property bool animar: true
    implicitWidth: 48; implicitHeight: 48

    readonly property string tipo: {
        const c = codigo
        if (c === 0) return dia ? "sol" : "lua"
        if (c <= 2) return dia ? "sol-nuvem" : "lua-nuvem"
        if (c === 3) return "nuvem"
        if (c === 45 || c === 48) return "neblina"
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "chuva"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "neve"
        if (c >= 95) return "trovoada"
        return "nuvem"
    }
    readonly property bool temSol: tipo === "sol" || tipo === "sol-nuvem"
    readonly property bool temLua: tipo === "lua" || tipo === "lua-nuvem"
    readonly property bool temNuvem: tipo !== "sol" && tipo !== "lua" && tipo !== "neblina"
    readonly property bool soloSol: tipo === "sol" || tipo === "lua"

    // fase do movimento curto (0..1); só anda durante o pulso
    property real fase: 0
    Timer {
        running: ic.animar && !Cores.reduzir && ic.visible
        interval: 7000; repeat: true; triggeredOnStart: true
        onTriggered: pulso.restart()
    }
    NumberAnimation { id: pulso; target: ic; property: "fase"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }

    component Camada: Item {
        id: cam
        property url fonte
        property color cor
        Image { id: img; anchors.fill: parent; source: cam.fonte; sourceSize: Qt.size(width * 2, height * 2); visible: false }
        MultiEffect { anchors.fill: parent; source: img; colorization: 1; colorizationColor: cam.cor; brightness: 0.2 }
    }

    // sol (ou lua) atrás, menor quando há nuvem
    Item {
        id: astro
        width: ic.soloSol ? ic.width : ic.width * 0.68
        height: width
        x: ic.soloSol ? 0 : ic.width * 0.02
        y: ic.soloSol ? 0 : ic.height * 0.0
        Camada { visible: ic.temSol; anchors.fill: parent; fonte: "icones/sol-raios.svg"; cor: Cores.destaque; rotation: ic.fase * 45 }
        Camada { visible: ic.temSol; anchors.fill: parent; fonte: "icones/sol-disco.svg"; cor: Cores.destaque }
        Camada { visible: ic.temLua; anchors.fill: parent; fonte: "icones/lua.svg"; cor: Cores.texto2 }
    }
    // nuvem na frente, flutua 2 px
    Camada {
        visible: ic.temNuvem
        width: ic.width * (ic.tipo === "nuvem" ? 0.95 : 0.8); height: width
        x: ic.width - width
        y: (ic.tipo === "chuva" || ic.tipo === "neve" || ic.tipo === "trovoada" ? -ic.height * 0.12 : ic.height * 0.12) + Math.sin(ic.fase * Math.PI) * -2
        fonte: "icones/nuvem.svg"
        cor: Cores.secundaria
    }
    // precipitação embaixo, desce durante o pulso
    Item {
        visible: ic.tipo === "chuva" || ic.tipo === "neve"
        x: ic.width * 0.12; y: ic.height * 0.55
        width: ic.width * 0.8; height: ic.height * 0.45
        clip: true
        Camada {
            width: parent.width; height: parent.width
            y: -parent.width * 0.02 + ic.fase * 6
            fonte: ic.tipo === "neve" ? "icones/neve.svg" : "icones/chuva.svg"
            cor: ic.tipo === "neve" ? Cores.texto : Cores.secundaria
        }
    }
    Camada {
        visible: ic.tipo === "trovoada"
        width: ic.width * 0.55; height: width
        x: ic.width * 0.22; y: ic.height * 0.44
        fonte: "icones/raio.svg"
        cor: Cores.alerta
        opacity: ic.fase > 0.3 && ic.fase < 0.45 ? 0.25 : 1
    }
    Camada {
        visible: ic.tipo === "neblina"
        width: ic.width; height: ic.height
        x: Math.sin(ic.fase * Math.PI) * 3
        fonte: "icones/neblina.svg"
        cor: Cores.texto2
    }
}
