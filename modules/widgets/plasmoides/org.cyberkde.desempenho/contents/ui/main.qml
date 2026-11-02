import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "comum"

// CyberKDE · Desempenho: CPU (total e por núcleo), memória, swap, GPU, temperaturas, rede e disco,
// pelos sensores do sistema (ksystemstats). Acima dos limiares, tudo passa à cor de alerta.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }
    readonly property int intervalo: Math.max(500, cfg.intervalo)

    // ---- formatação
    function gib(b) { return (b / 1073741824).toFixed(b >= 10737418240 ? 0 : 1) }
    function taxa(b) {
        if (!(b > 0)) return "0 B/s"
        const u = ["B/s", "KB/s", "MB/s", "GB/s"]
        let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i === 0 ? Math.round(b) : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i]
    }
    function pct(v) { return isFinite(v) ? Math.round(v) + "%" : "--" }
    function graus(v) { return v > 0 ? Math.round(v) + "°C" : "--" }

    component S: Sensors.Sensor { updateRateLimit: raiz.intervalo }

    // ---- sensores
    S { id: cpu; sensorId: "cpu/all/usage" }
    S { id: nucleos; sensorId: "cpu/all/coreCount"; updateRateLimit: 60000 }
    S { id: tempCpu; sensorId: "cpu/all/maximumTemperature" }
    S { id: mem; sensorId: "memory/physical/used" }
    S { id: memTotal; sensorId: "memory/physical/total"; updateRateLimit: 60000 }
    S { id: swap; sensorId: "memory/swap/used" }
    S { id: swapTotal; sensorId: "memory/swap/total"; updateRateLimit: 60000 }
    S { id: desce; sensorId: "network/all/download" }
    S { id: sobe; sensorId: "network/all/upload" }
    S { id: leitura; sensorId: "disk/all/read" }
    S { id: escrita; sensorId: "disk/all/write" }
    S { id: discoUso; sensorId: "disk/all/usedPercent"; updateRateLimit: 30000 }
    S { id: discoLivre; sensorId: "disk/all/free"; updateRateLimit: 30000 }

    // GPU: "auto" procura a primeira gpuN com nome de placa dedicada (a RTX 3060 aparece como gpu1)
    property string gpuId: cfg.gpu !== "auto" ? cfg.gpu : ""
    property string gpuNome: ""
    Instantiator {
        model: raiz.cfg.gpu === "auto" ? 4 : 0
        S {
            required property int index
            sensorId: "gpu/gpu" + index + "/name"
            updateRateLimit: 60000
            onValueChanged: raiz.escolherGpu()
        }
        onObjectAdded: (i, o) => raiz._nomesGpu[i] = o
    }
    property var _nomesGpu: ({})
    function escolherGpu() {
        if (cfg.gpu !== "auto") return
        let melhor = "", nome = ""
        for (let i = 0; i < 4; i++) {
            const o = _nomesGpu[i]
            const v = o && o.value ? String(o.value) : ""
            if (!v) continue
            if (/nvidia|geforce|radeon|amd|arc/i.test(v)) { melhor = "gpu" + i; nome = v; break }
            if (!melhor) { melhor = "gpu" + i; nome = v }
        }
        gpuId = melhor; gpuNome = nome
    }
    S { id: gpuNomeFixo; sensorId: raiz.cfg.gpu !== "auto" ? "gpu/" + raiz.cfg.gpu + "/name" : ""; updateRateLimit: 60000 }
    readonly property string nomeGpu: (cfg.gpu !== "auto" ? String(gpuNomeFixo.value || "") : gpuNome)
        .replace(/^NVIDIA\s+/i, "").replace(/^GeForce\s+/i, "").replace(/^AMD\s+/i, "")
    S { id: gpuUso; sensorId: raiz.gpuId ? "gpu/" + raiz.gpuId + "/usage" : "" }
    S { id: gpuVram; sensorId: raiz.gpuId ? "gpu/" + raiz.gpuId + "/usedVram" : "" }
    S { id: gpuVramTotal; sensorId: raiz.gpuId ? "gpu/" + raiz.gpuId + "/totalVram" : ""; updateRateLimit: 60000 }
    S { id: gpuTemp; sensorId: raiz.gpuId ? "gpu/" + raiz.gpuId + "/temperature" : "" }
    S { id: gpuEnergia; sensorId: raiz.gpuId ? "gpu/" + raiz.gpuId + "/power" : "" }
    readonly property bool temGpu: gpuId !== "" && gpuVramTotal.value > 0

    // ---- valores derivados
    readonly property real fCpu: (cpu.value || 0) / 100
    readonly property real fMem: memTotal.value > 0 ? mem.value / memTotal.value : 0
    readonly property real fSwap: swapTotal.value > 0 ? swap.value / swapTotal.value : 0
    readonly property real fGpu: (gpuUso.value || 0) / 100
    readonly property real fVram: gpuVramTotal.value > 0 ? gpuVram.value / gpuVramTotal.value : 0
    readonly property bool quente: tempCpu.value >= cfg.limiarTemp || gpuTemp.value >= cfg.limiarTemp
    readonly property bool emAlerta: fCpu >= cfg.limiarCpu / 100 || fMem >= cfg.limiarMemoria / 100
        || (temGpu && fGpu >= cfg.limiarGpu / 100) || quente

    // ---- histórico (60 amostras)
    readonly property int amostras: 60
    property var hCpu: []
    property var hGpu: []
    property var hDesce: []
    property var hSobe: []
    function empurrar(a, v) { const b = a.length >= amostras ? a.slice(1) : a.slice(); b.push(v || 0); return b }
    Timer {
        interval: raiz.intervalo; running: true; repeat: true
        onTriggered: {
            raiz.hCpu = raiz.empurrar(raiz.hCpu, cpu.value)
            if (raiz.temGpu) raiz.hGpu = raiz.empurrar(raiz.hGpu, gpuUso.value)
            raiz.hDesce = raiz.empurrar(raiz.hDesce, desce.value)
            raiz.hSobe = raiz.empurrar(raiz.hSobe, sobe.value)
        }
    }

    toolTipMainText: t("Desempenho", "Performance")
    toolTipSubText: "CPU " + pct(cpu.value) + " · RAM " + pct(fMem * 100) + (temGpu ? " · GPU " + pct(gpuUso.value) : "")

    // ---- tamanho na área de trabalho: livre (a geometria do applet, redimensionável no modo de edição);
    //      P/M/G são presets, e "modo" guarda o último escolhido. Na barra, a forma compacta de sempre.
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    // valores antigos: compacto → pequeno, completo → grande
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0                  // muda a cada escolha de preset (até a mesma de novo)
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.fill: parent
                spacing: 3
                Codigo { text: raiz.emAlerta ? (raiz.quente ? raiz.t("PERF.MON // ▲ TEMPERATURA", "PERF.MON // ▲ HEAT") : raiz.t("PERF.MON // ▲ SOBRECARGA", "PERF.MON // ▲ OVERLOAD")) : "PERF.MON"
                         color: raiz.emAlerta ? Cores.alerta : Cores.destaque; tamanho: 8; font.bold: true; width: parent.width }
                LinhaMini { rotulo: "CPU"; fracao: raiz.fCpu; limiar: raiz.cfg.limiarCpu / 100; valor: raiz.pct(cpu.value) }
                LinhaMini { rotulo: "RAM"; fracao: raiz.fMem; limiar: raiz.cfg.limiarMemoria / 100; valor: raiz.pct(raiz.fMem * 100); cor: Cores.secundaria }
                LinhaMini { visible: raiz.temGpu; rotulo: "GPU"; fracao: raiz.fGpu; limiar: raiz.cfg.limiarGpu / 100; valor: raiz.pct(gpuUso.value) }
            }
        }
    }

    Component {
        id: compactoBarra
    MouseArea {
        Layout.minimumWidth: linhaC.implicitWidth + 8
        onClicked: raiz.expanded = !raiz.expanded
        Row {
            id: linhaC
            anchors.centerIn: parent
            height: parent.height * 0.7
            spacing: 3
            BarraSegmentada { vertical: true; width: 5; height: parent.height; valor: raiz.fCpu; limiar: raiz.cfg.limiarCpu / 100; tamSeg: 2; vao: 1 }
            BarraSegmentada { vertical: true; width: 5; height: parent.height; valor: raiz.fMem; limiar: raiz.cfg.limiarMemoria / 100; cor: Cores.secundaria; tamSeg: 2; vao: 1 }
            Text {
                text: raiz.pct(cpu.value)
                anchors.verticalCenter: parent.verticalCenter
                font.family: Cores.fMono; font.pixelSize: 12; font.bold: true
                color: raiz.fCpu >= raiz.cfg.limiarCpu / 100 ? Cores.alerta : Cores.texto
            }
        }
    }
    }

    // ---- médio e grande (a mesma moldura; o médio mostra menos partes)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            // pelo tamanho real (altura útil): cada parte entra assim que cabe. Base: barras de CPU, memória,
            // GPU e o resumo da rede (~192 px); + disco (236); gráfico da CPU no lugar da barra (262);
            // + núcleos (320); + gráfico da rede (365)
            readonly property real h: area.height
            readonly property bool medio: h < 262
            readonly property bool cabeGrafRede: h >= 365
            readonly property bool cabeNucleos: h >= 320
            readonly property bool cabeDisco: h >= 236
            readonly property bool cabeGpu: h >= 150
            titulo: raiz.t("Desempenho", "Performance")
            codigo: "PERF.MON // " + (nucleos.value || "--") + raiz.t(" NÚCLEOS", " CORES")
            extra: [
                Item {
                    // aviso de sobrecarga: pisca 3 vezes ao entrar em alerta e fica aceso
                    visible: raiz.emAlerta
                    width: av.implicitWidth + 12; height: 16
                    Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.alerta, 0.15); border.color: Cores.alerta }
                    Codigo { id: av; anchors.centerIn: parent; text: raiz.quente ? raiz.t("▲ TEMPERATURA", "▲ HEAT") : raiz.t("▲ SOBRECARGA", "▲ OVERLOAD"); color: Cores.alerta; tamanho: 9; font.bold: true }
                    SequentialAnimation on opacity {
                        running: raiz.emAlerta && !Cores.reduzir
                        loops: 3
                        NumberAnimation { to: 0.2; duration: 120 }
                        NumberAnimation { to: 1; duration: 120 }
                    }
                }
            ]

            Column {
                anchors.fill: parent
                spacing: 7

                // ---- CPU
                Secao {
                    texto: "CPU"
                    resumo: "TEMP " + raiz.graus(tempCpu.value)
                    corResumo: tempCpu.value >= raiz.cfg.limiarTemp ? Cores.alerta : Cores.texto2
                }
                Medidor {
                    visible: mold.medio
                    rotulo: raiz.t("USO", "LOAD")
                    fracao: raiz.fCpu; limiar: raiz.cfg.limiarCpu / 100
                    valor: raiz.pct(cpu.value)
                }
                Item {
                    visible: !mold.medio
                    width: parent.width; height: visible ? 40 : 0
                    NumeroCintilante {
                        id: grandeCpu
                        valor: raiz.pct(cpu.value)
                        intervaloMin: 2500
                        width: 92
                        font.family: Cores.fIdentidade; font.pixelSize: 30; font.weight: Font.Bold
                        color: raiz.fCpu >= raiz.cfg.limiarCpu / 100 ? Cores.alerta : Cores.texto
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    GraficoHud {
                        x: grandeCpu.width + 8
                        width: parent.width - x; height: parent.height
                        maximo: 100
                        limiar: raiz.cfg.limiarCpu
                        series: [{ valores: raiz.hCpu, cor: Cores.destaque }].concat(raiz.temGpu && raiz.cfg.mostrarGpu ? [{ valores: raiz.hGpu, cor: Cores.secundaria }] : [])
                    }
                }
                // núcleos
                Item {
                    visible: raiz.cfg.mostrarNucleos && nucleos.value > 0 && mold.cabeNucleos
                    width: parent.width; height: visible ? 52 : 0
                    Row {
                        id: colunas
                        anchors.fill: parent
                        readonly property int n: Math.max(1, nucleos.value || 1)
                        spacing: 3
                        Repeater {
                            model: raiz.cfg.mostrarNucleos && mold.cabeNucleos ? colunas.n : 0
                            Item {
                                id: nuc
                                required property int index
                                width: (colunas.width - (colunas.n - 1) * colunas.spacing) / colunas.n
                                height: colunas.height
                                S { id: sn; sensorId: "cpu/cpu" + nuc.index + "/usage" }
                                BarraSegmentada {
                                    vertical: true
                                    width: parent.width; height: parent.height - 12
                                    valor: (sn.value || 0) / 100
                                    limiar: raiz.cfg.limiarCpu / 100
                                    tamSeg: 2; vao: 2
                                }
                                Codigo {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: String(nuc.index + 1).padStart(2, "0")
                                    tamanho: 7
                                    color: (sn.value || 0) >= raiz.cfg.limiarCpu ? Cores.alerta : Cores.texto3
                                }
                            }
                        }
                    }
                }

                // ---- memória
                Secao { texto: raiz.t("MEMÓRIA", "MEMORY"); resumo: raiz.gib(memTotal.value || 0) + " GiB" }
                Medidor {
                    rotulo: "RAM"
                    fracao: raiz.fMem; limiar: raiz.cfg.limiarMemoria / 100
                    valor: raiz.gib(mem.value || 0) + " GiB · " + raiz.pct(raiz.fMem * 100)
                }
                Medidor {
                    visible: swapTotal.value > 0
                    rotulo: "SWAP"
                    fracao: raiz.fSwap; limiar: raiz.cfg.limiarMemoria / 100
                    cor: Cores.secundaria
                    valor: raiz.gib(swap.value || 0) + " / " + raiz.gib(swapTotal.value || 0) + " GiB"
                }

                // ---- GPU
                Secao {
                    visible: raiz.cfg.mostrarGpu && raiz.temGpu && mold.cabeGpu
                    texto: "GPU · " + raiz.nomeGpu.toUpperCase()
                    resumo: raiz.graus(gpuTemp.value) + (gpuEnergia.value > 0 ? " · " + Math.round(gpuEnergia.value) + " W" : "")
                    corResumo: gpuTemp.value >= raiz.cfg.limiarTemp ? Cores.alerta : Cores.texto2
                }
                Medidor {
                    visible: raiz.cfg.mostrarGpu && raiz.temGpu && mold.cabeGpu
                    rotulo: raiz.t("USO", "LOAD")
                    fracao: raiz.fGpu; limiar: raiz.cfg.limiarGpu / 100
                    valor: raiz.pct(gpuUso.value)
                }
                Medidor {
                    visible: raiz.cfg.mostrarGpu && raiz.temGpu && mold.cabeGpu
                    rotulo: "VRAM"
                    fracao: raiz.fVram; limiar: raiz.cfg.limiarMemoria / 100
                    cor: Cores.secundaria
                    valor: raiz.gib(gpuVram.value || 0) + " / " + raiz.gib(gpuVramTotal.value || 0) + " GiB"
                }

                // ---- rede
                Secao {
                    visible: raiz.cfg.mostrarRede
                    texto: raiz.t("REDE", "NETWORK")
                    resumo: "↓ " + raiz.taxa(desce.value) + "   ↑ " + raiz.taxa(sobe.value)
                    corResumo: Cores.texto
                }
                Item {
                    visible: raiz.cfg.mostrarRede && mold.cabeGrafRede
                    width: parent.width; height: visible ? 38 : 0
                    GraficoHud {
                        anchors.fill: parent
                        series: [{ valores: raiz.hDesce, cor: Cores.destaque }, { valores: raiz.hSobe, cor: Cores.secundaria }]
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top
                        width: legenda.width + 8; height: legenda.height + 4
                        color: Cores.alfa(Cores.painel, 0.85)
                    }
                    Row {
                        id: legenda
                        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 2; anchors.leftMargin: 4
                        spacing: 8
                        Codigo { text: "■ " + raiz.t("DESCIDA", "DOWN"); color: Cores.destaque; tamanho: 7 }
                        Codigo { text: "■ " + raiz.t("SUBIDA", "UP"); color: Cores.secundaria; tamanho: 7 }
                    }
                }

                // ---- disco
                Secao {
                    visible: raiz.cfg.mostrarDisco && mold.cabeDisco
                    texto: raiz.t("DISCO", "DISK")
                    resumo: "L " + raiz.taxa(leitura.value) + "   E " + raiz.taxa(escrita.value)
                    corResumo: Cores.texto
                }
                Medidor {
                    visible: raiz.cfg.mostrarDisco && mold.cabeDisco
                    rotulo: raiz.t("ESPAÇO", "SPACE")
                    fracao: (discoUso.value || 0) / 100; limiar: raiz.cfg.limiarDisco / 100
                    valor: raiz.gib(discoLivre.value || 0) + raiz.t(" GiB livres", " GiB free")
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        limiteCartao: Qt.size(250, 150)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        tamanhoPequeno: Qt.size(236, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 18, Kirigami.Units.gridUnit * 14)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 21, Kirigami.Units.gridUnit * 24)
    }

}
