import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração da Rede: tamanho, opacidade, host e intervalo do ping, IP público.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_host
    property string cfg_hostDefault
    property int cfg_intervaloPing
    property int cfg_intervaloPingDefault
    property bool cfg_ipPublico
    property bool cfg_ipPublicoDefault
    property bool cfg_demonstracao
    property bool cfg_demonstracaoDefault

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
            Kirigami.FormData.label: t("Medir a latência em:", "Measure latency to:")
            text: pag.cfg_host
            placeholderText: "1.1.1.1"
            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9.:-]{1,253}/ }
            onTextEdited: pag.cfg_host = text
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Ping a cada (s):", "Ping every (s):")
            from: 2; to: 60
            value: pag.cfg_intervaloPing
            onValueModified: pag.cfg_intervaloPing = value
        }
        QQC2.CheckBox {
            text: t("Mostrar o IP público", "Show the public IP")
            checked: pag.cfg_ipPublico
            onToggled: pag.cfg_ipPublico = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: t("Desligado por padrão: o IP público aparece em capturas de tela. Ligado, o widget consulta api.ipify.org a cada 10 minutos.",
                    "Off by default: the public IP shows up in screenshots. When on, the widget asks api.ipify.org every 10 minutes.")
        }
    }
}
