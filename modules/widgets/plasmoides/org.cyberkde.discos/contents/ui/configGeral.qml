import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração dos Discos: unidades, limiar de alerta e intervalo do espaço.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_montagens
    property string cfg_montagensDefault
    property int cfg_limiar
    property int cfg_limiarDefault
    property int cfg_intervalo
    property int cfg_intervaloDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }

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
        QQC2.TextField {
            Kirigami.FormData.label: t("Unidades:", "Drives:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            text: pag.cfg_montagens
            placeholderText: t("automático", "automatic")
            onTextEdited: pag.cfg_montagens = text
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            wrapMode: Text.Wrap
            opacity: 0.75
            text: t("Pontos de montagem separados por vírgula, na ordem da lista (ex.: /, /home, /mnt/hd). Vazio: as unidades reais (/, /home, /mnt e mídias).",
                    "Mount points separated by commas, in list order (e.g. /, /home, /mnt/hd). Empty: the real drives (/, /home, /mnt and media).")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Alerta acima de:", "Alert above:")
            from: 50; to: 99
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_limiar
            onValueModified: pag.cfg_limiar = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Ler o espaço a cada:", "Read space every:")
            from: 5; to: 600; stepSize: 5
            textFromValue: (v) => v + " s"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_intervalo
            onValueModified: pag.cfg_intervalo = value
        }
    }
}
