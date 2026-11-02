import QtQuick
import org.kde.kirigami as Kirigami
import "comum"

// CLIMA: ícone, temperatura agora, a faixa HOJE da referência e a descrição; umidade e vento no rodapé.
Modulo {
    id: m
    titulo: d.t("Clima", "Weather"); codigo: d.cidade
    rodape: d.clima.ok ? d.t("umidade ", "humidity ") + Math.round(d.clima.umidade) + " % · " + d.t("vento ", "wind ") + Math.round(d.clima.vento) + " km/h · " + d.climaAtualizado
                       : "Open-Meteo · " + d.climaAtualizado
    dica: d.t("Tempo agora na cidade escolhida, pelo Open-Meteo (atualiza a cada 30 min).", "Current weather in the chosen city, from Open-Meteo (updates every 30 min).")
    Rot { k: m.k; x: 0; y: 0; text: m.d.diaSemana }
    Rot { k: m.k; x: m.u(52); y: 0; text: m.d.t("AGORA", "NOW") }
    Kirigami.Icon {
        x: 0; y: m.u(18); width: m.u(34); height: width
        source: m.d.climaIcone; isMask: true; color: Cores.texto
    }
    Text {
        x: m.u(50); y: m.u(14)
        text: m.d.clima.ok ? m.digita(m.d.dec(m.d.clima.temp, 1) + " °C") : "-- °C"
        font.family: Cores.fIdentidade; font.pixelSize: m.fi(24); font.weight: Font.Medium
        color: Cores.texto
    }
    Rectangle {
        x: 0; y: m.u(60); width: Math.round(m.width * Math.min(1, m.montado * 1.4)); height: m.u(16); color: Cores.texto
        Text { x: m.u(5); anchors.verticalCenter: parent.verticalCenter; text: m.d.t("HOJE", "TODAY")
               font.family: Cores.fIdentidade; font.pixelSize: m.fi(10.5); font.weight: Font.Bold; color: Cores.fundo }
    }
    Text {
        x: 0; y: m.u(82); width: m.width
        text: m.digita(m.d.climaDesc)
        font.family: Cores.fTexto; font.pixelSize: m.fi(12); font.weight: Font.DemiBold
        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        color: Cores.texto
    }
}
