import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Docker: tamanho, opacidade, intervalo e contêineres parados.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property int cfg_intervalo
    property int cfg_intervaloDefault
    property bool cfg_mostrarParados
    property bool cfg_mostrarParadosDefault

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
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Atualizar a cada (s):", "Refresh every (s):")
            from: 3; to: 300
            value: pag.cfg_intervalo
            onValueModified: pag.cfg_intervalo = value
        }
        QQC2.CheckBox {
            text: t("Mostrar os contêineres parados", "Show stopped containers")
            checked: pag.cfg_mostrarParados
            onToggled: pag.cfg_mostrarParados = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: t("O widget usa o comando docker da sua conta. Sem permissão, adicione-se ao grupo docker (sudo usermod -aG docker $USER) e entre de novo na sessão.",
                    "The widget uses your account's docker command. Without permission, add yourself to the docker group (sudo usermod -aG docker $USER) and log in again.")
        }
    }
}
