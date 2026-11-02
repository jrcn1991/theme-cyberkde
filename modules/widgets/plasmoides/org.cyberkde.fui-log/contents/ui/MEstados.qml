import QtQuick
import "comum"

// ESTADOS (as colunas "HDR" da referência): ladrilhos com rótulo curto e dica. grupo 1 = rede, som e
// microfone; grupo 2 = energia, GPU e latência; 0 = os seis (módulo avulso, em 2 colunas).
Modulo {
    id: m
    property int grupo: 0
    titulo: "Sts"; codigo: grupo === 0 ? d.t("estado", "status") : ""
    dica: ""      // cada ladrilho tem a sua
    readonly property string _resumo: grupo === 1 ? d.t("Estado: rede, som e microfone.", "Status: network, sound and microphone.")
        : grupo === 2 ? d.t("Estado: energia, GPU e latência da internet.", "Status: power, GPU and internet latency.")
        : d.t("Estado: rede, som, microfone, energia, GPU e latência da internet.", "Status: network, sound, microphone, power, GPU and internet latency.")
    readonly property var itens: grupo === 1 ? [0, 1, 2] : grupo === 2 ? [3, 4, 5] : [0, 1, 2, 3, 4, 5]
    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: m.grupo === 0 ? 3 : 1
        columnSpacing: m.u(10); rowSpacing: m.u(4)
        Repeater {
            model: m.itens
            Ladrilho {
                required property int modelData
                k: m.k
                readonly property var h: m.d.hdr
                tipo: ["diagonal", "barra", "barra", "circulos", "diagonal", "barra"][modelData]
                rotulo: ["NET", m.d.t("SOM", "SND"), "MIC", "PWR", "GPU", "PING"][modelData]
                cheio: modelData === 0 ? h.rede : modelData === 3 ? h.energia === "AC" : false
                nivel: modelData === 1 ? (h.somMudo ? 0 : h.som) : modelData === 2 ? (h.micMudo ? 0 : h.mic)
                     : modelData === 4 ? m.d.gpuUso / 100 : modelData === 5 ? (h.lat >= 0 ? Math.max(0.05, 1 - h.lat / 200) : 0) : 0
                alerta: modelData === 4 ? m.d.gpuUso >= m.d.limiar * 100 : modelData === 5 ? h.lat < 0 : false
                dica: [m.d.t("Rede: ", "Network: ") + (h.rede ? m.d.t("conectada", "connected") : m.d.t("sem conexão", "disconnected")),
                       m.d.t("Volume da saída padrão: ", "Default output volume: ") + (h.somMudo ? m.d.t("mudo", "muted") : Math.round(h.som * 100) + " %"),
                       m.d.t("Volume do microfone padrão: ", "Default microphone volume: ") + (h.micMudo ? m.d.t("mudo", "muted") : Math.round(h.mic * 100) + " %"),
                       m.d.t("Energia: ", "Power: ") + (h.energia === "AC" ? m.d.t("na tomada", "plugged in") : h.energia + " %"),
                       "GPU: " + Math.round(m.d.gpuUso) + m.d.t(" % de uso", " % load"),
                       m.d.t("Latência até a internet: ", "Internet latency: ") + (h.lat >= 0 ? Math.round(h.lat) + " ms" : m.d.t("sem resposta", "no reply"))][modelData]
            }
        }
    }
}
