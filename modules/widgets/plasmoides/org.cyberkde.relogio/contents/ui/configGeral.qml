import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Relógio: formato, segundos, segundo fuso e de onde vêm os eventos.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_formato
    property string cfg_formatoDefault
    property bool cfg_mostrarSegundos
    property bool cfg_mostrarSegundosDefault
    property string cfg_fuso2
    property string cfg_fuso2Default
    property string cfg_rotulo2
    property string cfg_rotulo2Default
    property var cfg_pluginsEventos
    property var cfg_pluginsEventosDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }
    function temPlugin(p) { return (pag.cfg_pluginsEventos || []).indexOf(p) >= 0 }
    function alternarPlugin(p, ligado) {
        let l = (pag.cfg_pluginsEventos || []).filter(x => x !== p)
        if (ligado) l.push(p)
        pag.cfg_pluginsEventos = l
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Preset de tamanho:", "Size preset:")
            model: [t("Pequeno", "Small"), t("Médio", "Medium"), t("Grande", "Large")]
            readonly property var ids: ["pequeno", "medio", "grande"]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_modo))
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
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Formato da hora:", "Time format:")
            model: [t("Do idioma", "From the language"), "24 h", "12 h"]
            readonly property var ids: ["auto", "24", "12"]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_formato))
            onActivated: (i) => pag.cfg_formato = ids[i]
        }
        QQC2.CheckBox { text: t("Mostrar os segundos", "Show seconds"); checked: pag.cfg_mostrarSegundos; onToggled: pag.cfg_mostrarSegundos = checked }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: t("Segundo fuso", "Second time zone") }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Fuso:", "Time zone:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            editable: true
            model: ["", "UTC", "America/New_York", "America/Los_Angeles", "America/Chicago", "America/Sao_Paulo", "America/Manaus",
                    "America/Mexico_City", "America/Argentina/Buenos_Aires", "Europe/London", "Europe/Lisbon", "Europe/Paris",
                    "Europe/Berlin", "Europe/Moscow", "Africa/Johannesburg", "Asia/Dubai", "Asia/Kolkata", "Asia/Shanghai",
                    "Asia/Tokyo", "Asia/Seoul", "Australia/Sydney", "Pacific/Auckland"]
            Component.onCompleted: editText = pag.cfg_fuso2
            onEditTextChanged: pag.cfg_fuso2 = editText.trim()
            displayText: currentIndex === 0 && editText === "" ? t("(desligado)", "(off)") : editText
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Rótulo:", "Label:")
            text: pag.cfg_rotulo2
            placeholderText: t("a cidade do fuso", "the zone's city")
            onTextEdited: pag.cfg_rotulo2 = text
        }
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: t("Eventos", "Events") }
        QQC2.CheckBox { text: t("Agenda do KDE (precisa do plugin PIM)", "KDE calendar (needs the PIM plugin)"); checked: pag.temPlugin("pimevents"); onToggled: pag.alternarPlugin("pimevents", checked) }
        QQC2.CheckBox { text: t("Feriados", "Holidays"); checked: pag.temPlugin("holidaysevents"); onToggled: pag.alternarPlugin("holidaysevents", checked) }
        QQC2.CheckBox { text: t("Eventos astronômicos (fases da lua, estações)", "Astronomical events (moon phases, seasons)"); checked: pag.temPlugin("astronomicalevents"); onToggled: pag.alternarPlugin("astronomicalevents", checked) }
    }
}
