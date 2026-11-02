import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Câmbio: moedas, intervalo e período do gráfico.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property bool cfg_ajustado
    property bool cfg_ajustadoDefault
    property string cfg_moedas
    property string cfg_moedasDefault
    property int cfg_intervaloMin
    property int cfg_intervaloMinDefault
    property string cfg_periodo
    property string cfg_periodoDefault
    property string cfg_grafico
    property string cfg_graficoDefault
    property string cfg_cache
    property string cfg_cacheDefault

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
            Kirigami.FormData.label: t("Moedas:", "Currencies:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            text: pag.cfg_moedas
            placeholderText: "USD-BRL, EUR-BRL, BTC-BRL"
            onTextEdited: pag.cfg_moedas = text
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            wrapMode: Text.Wrap
            opacity: 0.75
            text: t("Pares separados por vírgula (moeda-cotada). Só o código vale contra o real: USD = USD-BRL. A primeira é a principal.",
                    "Pairs separated by commas (currency-quote). A bare code is against the real: USD = USD-BRL. The first one is the main one.")
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Atualizar a cada:", "Refresh every:")
            from: 5; to: 60
            textFromValue: (v) => v + " min"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_intervaloMin
            onValueModified: pag.cfg_intervaloMin = value
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Gráfico:", "Chart:")
            model: [t("7 dias", "7 days"), t("30 dias", "30 days")]
            currentIndex: pag.cfg_periodo === "7" ? 0 : 1
            onActivated: (i) => pag.cfg_periodo = i === 0 ? "7" : "30"
        }
        QQC2.Label {
            Kirigami.FormData.label: t("Fonte:", "Source:")
            text: "AwesomeAPI (economia.awesomeapi.com.br)"
            opacity: 0.75
        }
    }
}
