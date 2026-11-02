import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "Catalogo.js" as Catalogo
import "comum"

// CyberKDE · Painel FUI e os módulos avulsos (o mesmo main.qml; os pacotes org.cyberkde.fui-<id> usam
// estes arquivos por link). Pelo nome do plugin:
//   org.cyberkde.painelfui  -> o painel inteiro da referência "Cyberpunk 2077 UI Art" (grade 4×3)
//   org.cyberkde.fui-<id>   -> só o módulo <id> (cpu, nucleos, sensores, memoria, gpu, discos, es, rede,
//                              trafego, processos, log, sistema, hora, clima, estados)
// Tudo é desenhado em pixel inteiro, na resolução da tela (sem escala por transformação). Dados reais,
// só leitura (Dados.qml).
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    readonly property string plugin: Plasmoid.pluginName || "org.cyberkde.painelfui"
    readonly property string qual: plugin.indexOf("org.cyberkde.fui-") === 0 ? plugin.slice(17) : ""
    readonly property bool inteiro: qual === "" || !Catalogo.modulos[qual]
    readonly property var info: inteiro ? null : Catalogo.modulos[qual]

    Dados {
        id: dados
        cfg: raiz.cfg
        partes: raiz.inteiro ? [] : raiz.info.partes
        onHoraCheia: raiz.glitch()
    }
    signal glitch()
    Timer {
        interval: Math.max(1, raiz.cfg.glitchMin) * 60000
        running: raiz.cfg.glitchMin > 0; repeat: true
        onTriggered: raiz.glitch()
    }

    toolTipMainText: inteiro ? "PAINEL FUI" : "FUI · " + qual.toUpperCase()
    toolTipSubText: "CPU " + Math.round(dados.cpu) + " % · RAM " + Math.round(dados.fRam * 100) + " %"

    // ---------------------------------------------------------------- tamanho na área de trabalho (padrão dos widgets)
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "grande"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra
    // módulo avulso: P/M/G = a proporção do módulo em 1×, 1,35× e 1,75× (largura-base × 172)
    function tamModulo(f) { return Qt.size(Math.round(info.largura * f) + 8, Math.round(172 * f) + 8) }

    // cartão enxuto do painel inteiro (abaixo de 700×592, onde as fontes de 11 px já não cabem): relógio, CPU, RAM e clima
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: Math.max(0.3, raiz.opac)
            Text {
                width: parent.width - info.width - 10; height: parent.height
                text: dados.agora.toLocaleTimeString(Qt.locale("C"), "HH:mm")
                font.family: Cores.fIdentidade; font.weight: Font.DemiBold; font.pixelSize: 64
                fontSizeMode: Text.Fit; minimumPixelSize: 12
                verticalAlignment: Text.AlignVCenter
                color: Cores.texto
            }
            Column {
                id: info
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { anchors.right: parent.right; text: "CPU " + Math.round(dados.cpu) + " %"; font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                       color: dados.cpu >= dados.limiar * 100 ? Cores.alerta : Cores.texto }
                Text { anchors.right: parent.right; text: "RAM " + Math.round(dados.fRam * 100) + " %"; font.family: Cores.fMono; font.pixelSize: 12; color: Cores.texto2 }
                Text { anchors.right: parent.right; text: dados.clima.ok ? dados.dec(dados.clima.temp, 1) + " °C" : ""; font.family: Cores.fMono; font.pixelSize: 12; color: Cores.texto2 }
            }
        }
    }

    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: lc.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Text {
                id: lc; anchors.centerIn: parent
                text: raiz.inteiro ? "FUI " + Math.round(dados.cpu) + " %" : raiz.qual.toUpperCase()
                font.family: Cores.fMono; font.pixelSize: 12; font.bold: true; color: Cores.texto
            }
        }
    }

    // o painel inteiro ou o módulo, desenhado no tamanho real (sem escala por transformação)
    Component {
        id: cCompleto
        Item {
            id: caixa
            anchors.fill: parent
            Rectangle {      // fundo opcional (opacidade) atrás das linhas
                visible: raiz.opac > 0
                anchors.fill: parent
                color: Cores.alfa(Cores.fundo, raiz.opac)
            }
            Loader {
                id: conteudo
                anchors.fill: parent
                anchors.margins: raiz.inteiro ? 12 : 4
                sourceComponent: raiz.inteiro ? cPainel : cModulo
            }
            Component { id: cPainel; Painel { d: dados; slot2: raiz.cfg.slot2 === "sistema" ? "sistema" : "log" } }
            Component { id: cModulo; ModuloSolo { d: dados; qual: raiz.qual } }
            Connections {
                target: conteudo
                function onLoaded() { conteudo.item.montar() }
            }
            Connections { target: raiz; function onGlitch() { if (conteudo.item) conteudo.item.glitch() } }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        naMesa: raiz.naMesa
        opacidade: Math.max(0.3, raiz.opac)
        pequeno: raiz.inteiro ? cartaoPequeno : cCompleto
        completo: cCompleto
        limiteCartao: raiz.inteiro ? Qt.size(700, 592) : Qt.size(1, 1)
        tamanhoPequeno: raiz.inteiro ? Qt.size(240, 96) : raiz.tamModulo(1)
        tamanhoMedio: raiz.inteiro ? Qt.size(776, 656) : raiz.tamModulo(1.35)
        tamanhoGrande: raiz.inteiro ? Qt.size(960, 816) : raiz.tamModulo(1.75)
    }
}
