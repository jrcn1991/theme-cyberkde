import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração das Notícias: tamanho, opacidade, feeds (um por linha aqui; gravados separados por
// espaço) e intervalo.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_feeds
    property string cfg_feedsDefault
    property int cfg_intervaloMin
    property int cfg_intervaloMinDefault
    property string cfg_lidas
    property string cfg_lidasDefault

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
        QQC2.TextArea {
            Kirigami.FormData.label: t("Feeds (um por linha):", "Feeds (one per line):")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
            text: pag.cfg_feeds.split(/[\s|]+/).filter(u => u).join("\n")
            onTextChanged: pag.cfg_feeds = text.split(/[\s|]+/).filter(u => u).join(" ")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Atualizar a cada (min):", "Refresh every (min):")
            from: 5; to: 240; stepSize: 5
            value: pag.cfg_intervaloMin
            onValueModified: pag.cfg_intervaloMin = value
        }
        QQC2.Button {
            text: t("Marcar todas como não lidas", "Mark all as unread")
            icon.name: "edit-clear-history"
            onClicked: pag.cfg_lidas = "[]"
        }
    }
}
