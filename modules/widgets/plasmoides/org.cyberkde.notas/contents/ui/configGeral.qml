import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração das Notas: nome do quadro e largura dos cartões (as notas se editam no próprio widget).
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property string cfg_quadro
    property string cfg_notas
    property int cfg_larguraCartao
    property string cfg_quadroDefault
    property string cfg_notasDefault
    property int cfg_larguraCartaoDefault

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
            Kirigami.FormData.label: t("Nome do quadro:", "Board name:")
            text: pag.cfg_quadro
            placeholderText: t("Notas", "Notes")
            onTextEdited: pag.cfg_quadro = text
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Largura dos cartões (px):", "Card width (px):")
            from: 140; to: 400; stepSize: 10
            value: pag.cfg_larguraCartao
            onValueModified: pag.cfg_larguraCartao = value
        }
    }
}
