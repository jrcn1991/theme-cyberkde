import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Painel FUI: módulos visíveis, alerta, log, rede, clima, glitch e logo.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_ocultos
    property string cfg_ocultosDefault
    property string cfg_slot2
    property string cfg_slot2Default
    property string cfg_ocultosLayout
    property string cfg_slot2
    property string cfg_slot2Default
    property string cfg_ocultosLayoutDefault
    property int cfg_limiar
    property int cfg_limiarDefault
    property int cfg_intervalo
    property int cfg_intervaloDefault
    property string cfg_logNivel
    property string cfg_logNivelDefault
    property string cfg_alvos
    property string cfg_alvosDefault
    property int cfg_pingSeg
    property int cfg_pingSegDefault
    property int cfg_glitchMin
    property int cfg_glitchMinDefault
    property string cfg_cidade
    property string cfg_cidadeDefault
    property string cfg_cidadeResolvida
    property string cfg_cidadeResolvidaDefault
    property real cfg_latitude
    property real cfg_latitudeDefault
    property real cfg_longitude
    property real cfg_longitudeDefault
    property string cfg_logo
    property string cfg_logoDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }
    readonly property var modulos: [
        ["bandas", t("CPU por grupos (F1–F6)", "CPU groups (F1–F6)")], ["log", t("Log do sistema", "System log")],
        ["canais", t("Sensores (knobs)", "Sensors (knobs)")], ["cpu", t("Carga da CPU", "CPU load")],
        ["estados", t("Estados (HDR)", "States (HDR)")], ["processos", t("Processos", "Processes")],
        ["anel", t("Temperatura da GPU", "GPU temperature")], ["discos", t("Discos", "Drives")],
        ["relogio", t("Relógio", "Clock")], ["clima", t("Clima", "Weather")], ["memoria", t("Memória", "Memory")],
        ["sinal", t("Sinal da rede", "Network signal")], ["ruido", t("Ruído de rede e disco", "Network and disk noise")],
        ["rede", t("Nós da rede", "Network nodes")], ["es", t("E/S por disco", "Disk I/O")]]
    function escondido(id) { return String(cfg_ocultos).split(/[\s,;]+/).indexOf(id) >= 0 }
    function alternar(id, mostrar) {
        let l = String(cfg_ocultos).split(/[\s,;]+/).filter(x => x && x !== id)
        if (!mostrar) l.push(id)
        cfg_ocultos = l.join(", ")
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Preset de tamanho:", "Size preset:")
            model: [t("Pequeno (cartão)", "Small (card)"), t("Médio", "Medium"), t("Grande (referência)", "Large (reference)")]
            readonly property var ids: ["pequeno", "medio", "grande"]
            currentIndex: Math.max(0, ids.indexOf(({ compacto: "pequeno", completo: "grande" })[pag.cfg_modo] || pag.cfg_modo))
            onActivated: (i) => pag.cfg_modo = ids[i]
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Opacidade do fundo:", "Background opacity:")
            from: 0; to: 100; stepSize: 5
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_opacidade
            onValueModified: pag.cfg_opacidade = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Alerta acima de:", "Alert above:")
            from: 50; to: 99
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_limiar
            onValueModified: pag.cfg_limiar = value
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Ao lado dos núcleos:", "Next to the cores:")
            model: [t("Log do sistema", "System log"), t("Sistema (uptime, carga, atualizações, Docker)", "System (uptime, load, updates, Docker)")]
            currentIndex: pag.cfg_slot2 === "sistema" ? 1 : 0
            onActivated: (i) => pag.cfg_slot2 = i === 1 ? "sistema" : "log"
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: t("Módulos", "Modules") }
        Repeater {
            model: pag.modulos
            QQC2.CheckBox {
                required property var modelData
                text: modelData[1]
                checked: !pag.escondido(modelData[0])
                onToggled: pag.alternar(modelData[0], checked)
            }
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.TextField {
            Kirigami.FormData.label: t("Cidade do clima:", "Weather city:")
            text: pag.cfg_cidade
            placeholderText: pag.cfg_cidadeResolvida
            onTextEdited: pag.cfg_cidade = text
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Log do sistema:", "System log:")
            model: [t("Só erros", "Errors only"), t("Avisos e erros", "Warnings and errors"), t("Notas e acima", "Notices and up"), t("Tudo", "Everything")]
            readonly property var ids: ["err", "warning", "notice", "info"]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_logNivel))
            onActivated: (i) => pag.cfg_logNivel = ids[i]
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Alvos do ping:", "Ping targets:")
            text: pag.cfg_alvos
            onTextEdited: pag.cfg_alvos = text
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            wrapMode: Text.Wrap; opacity: 0.75
            text: t("Só endereços públicos (o gateway entra sozinho). Endereço privado é recusado: o painel nunca sonda outras máquinas da rede local.",
                    "Public addresses only (the gateway is added on its own). Private addresses are refused: the dashboard never probes other machines on the local network.")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Sondar a rede a cada:", "Probe network every:")
            from: 15; to: 600; stepSize: 15
            textFromValue: (v) => v + " s"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_pingSeg
            onValueModified: pag.cfg_pingSeg = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Glitch a cada:", "Glitch every:")
            from: 0; to: 120; stepSize: 5
            textFromValue: (v) => v === 0 ? t("só na hora cheia", "on the hour only") : v + " min"
            valueFromText: (s) => parseInt(s) || 0
            value: pag.cfg_glitchMin
            onValueModified: pag.cfg_glitchMin = value
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Logo (imagem):", "Logo (image):")
            text: pag.cfg_logo
            placeholderText: t("o emblema da referência", "the reference emblem")
            onTextEdited: pag.cfg_logo = text
        }
    }
}
