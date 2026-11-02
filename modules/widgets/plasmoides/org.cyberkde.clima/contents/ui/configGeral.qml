import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Configuração do Clima: cidade (busca no geocoding do Open-Meteo), intervalo e previsão por hora.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property string cfg_cidade
    property string cfg_regiao
    property string cfg_cidadeResolvida
    property string cfg_cidadeResolvidaDefault
    property real cfg_latitude
    property real cfg_longitude
    property int cfg_intervaloMin
    property bool cfg_mostrarHoras
    property string cfg_cidadeDefault
    property string cfg_regiaoDefault
    property real cfg_latitudeDefault
    property real cfg_longitudeDefault
    property int cfg_intervaloMinDefault
    property bool cfg_mostrarHorasDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }

    property var resultados: []
    property string estado: ""

    function buscar(nome) {
        nome = nome.trim()
        if (nome.length < 2) { resultados = []; estado = ""; return }
        estado = t("Buscando…", "Searching…")
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { estado = t("Sem resposta do serviço de busca", "No reply from search service"); return }
            try {
                const j = JSON.parse(xhr.responseText)
                resultados = j.results || []
                estado = resultados.length ? "" : t("Nenhuma cidade encontrada", "No city found")
            } catch (e) { estado = t("Resposta ilegível", "Unreadable reply") }
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=8&format=json&language=" + (en ? "en" : "pt")
                 + "&name=" + encodeURIComponent(nome))
        xhr.send()
    }
    Timer { id: atraso; interval: 450; onTriggered: pag.buscar(campo.text) }

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
        QQC2.Label {
            Kirigami.FormData.label: t("Cidade atual:", "Current city:")
            text: pag.cfg_cidade + (pag.cfg_regiao ? " — " + pag.cfg_regiao : "")
            font.bold: true
        }
        QQC2.TextField {
            id: campo
            Kirigami.FormData.label: t("Buscar cidade:", "Search city:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: t("Digite o nome da cidade", "Type the city name")
            onTextEdited: atraso.restart()
            onAccepted: pag.buscar(text)
        }
        QQC2.Label { visible: pag.estado !== ""; text: pag.estado; opacity: 0.7 }
        ColumnLayout {
            visible: pag.resultados.length > 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            Repeater {
                model: pag.resultados
                QQC2.ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name + " — " + [modelData.admin1, modelData.country].filter(x => !!x).join(", ")
                    onClicked: {
                        pag.cfg_cidade = modelData.name
                        pag.cfg_cidadeResolvida = modelData.name
                        pag.cfg_regiao = [modelData.admin1, modelData.country].filter(x => !!x).join(", ")
                        pag.cfg_latitude = modelData.latitude
                        pag.cfg_longitude = modelData.longitude
                        pag.resultados = []
                        campo.text = ""
                    }
                }
            }
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Atualizar a cada (min):", "Refresh every (min):")
            from: 10; to: 180; stepSize: 5
            value: pag.cfg_intervaloMin
            onValueModified: pag.cfg_intervaloMin = value
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: t("Previsão por hora:", "Hourly forecast:")
            checked: pag.cfg_mostrarHoras
            onToggled: pag.cfg_mostrarHoras = checked
        }
        QQC2.Label {
            text: t("Dados: Open-Meteo (sem chave, sem conta).", "Data: Open-Meteo (no key, no account).")
            opacity: 0.6
        }
    }
}
