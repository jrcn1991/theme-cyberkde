import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Desempenho: intervalo, limiares de alerta, GPU e seções visíveis.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property int cfg_intervalo
    property int cfg_limiarCpu
    property int cfg_limiarMemoria
    property int cfg_limiarGpu
    property int cfg_limiarTemp
    property int cfg_limiarDisco
    property string cfg_gpu
    property bool cfg_mostrarNucleos
    property bool cfg_mostrarGpu
    property bool cfg_mostrarRede
    property bool cfg_mostrarDisco
    property int cfg_intervaloDefault
    property int cfg_limiarCpuDefault
    property int cfg_limiarMemoriaDefault
    property int cfg_limiarGpuDefault
    property int cfg_limiarTempDefault
    property int cfg_limiarDiscoDefault
    property string cfg_gpuDefault
    property bool cfg_mostrarNucleosDefault
    property bool cfg_mostrarGpuDefault
    property bool cfg_mostrarRedeDefault
    property bool cfg_mostrarDiscoDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }

    component Limiar: QQC2.SpinBox {
        from: 10; to: 100; stepSize: 5
        textFromValue: (v) => v + "%"
        valueFromText: (s) => parseInt(s)
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Preset de tamanho:", "Size preset:")
            model: [t("Pequeno", "Small"), t("Médio", "Medium"), t("Grande", "Large")]
            readonly property var ids: ["pequeno", "medio", "grande"]
            currentIndex: Math.max(0, ids.indexOf(({ compacto: "pequeno", completo: "grande" })[pag.cfg_modo] || pag.cfg_modo))
            onActivated: (i) => pag.cfg_modo = ids[i]
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Opacidade do fundo:", "Background opacity:")
            from: 30; to: 100; stepSize: 5
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_opacidade
            onValueModified: pag.cfg_opacidade = value
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Ler os sensores a cada (ms):", "Read sensors every (ms):")
            from: 500; to: 10000; stepSize: 250
            value: pag.cfg_intervalo
            onValueModified: pag.cfg_intervalo = value
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: t("Alerta acima de", "Alert above") }
        Limiar { Kirigami.FormData.label: "CPU:"; value: pag.cfg_limiarCpu; onValueModified: pag.cfg_limiarCpu = value }
        Limiar { Kirigami.FormData.label: t("Memória:", "Memory:"); value: pag.cfg_limiarMemoria; onValueModified: pag.cfg_limiarMemoria = value }
        Limiar { Kirigami.FormData.label: "GPU:"; value: pag.cfg_limiarGpu; onValueModified: pag.cfg_limiarGpu = value }
        Limiar { Kirigami.FormData.label: t("Disco cheio:", "Disk full:"); value: pag.cfg_limiarDisco; onValueModified: pag.cfg_limiarDisco = value }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Temperatura:", "Temperature:")
            from: 40; to: 110; stepSize: 5
            textFromValue: (v) => v + " °C"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_limiarTemp
            onValueModified: pag.cfg_limiarTemp = value
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: t("Mostrar", "Show") }
        QQC2.CheckBox { text: t("Núcleos da CPU", "CPU cores"); checked: pag.cfg_mostrarNucleos; onToggled: pag.cfg_mostrarNucleos = checked }
        QQC2.CheckBox { text: "GPU"; checked: pag.cfg_mostrarGpu; onToggled: pag.cfg_mostrarGpu = checked }
        QQC2.CheckBox { text: t("Rede", "Network"); checked: pag.cfg_mostrarRede; onToggled: pag.cfg_mostrarRede = checked }
        QQC2.CheckBox { text: t("Disco", "Disk"); checked: pag.cfg_mostrarDisco; onToggled: pag.cfg_mostrarDisco = checked }
        QQC2.ComboBox {
            Kirigami.FormData.label: "GPU:"
            model: [t("Automática", "Automatic"), "gpu0", "gpu1", "gpu2", "gpu3"]
            currentIndex: pag.cfg_gpu === "auto" ? 0 : Math.max(0, model.indexOf(pag.cfg_gpu))
            onActivated: (i) => pag.cfg_gpu = i === 0 ? "auto" : model[i]
        }
    }
}
