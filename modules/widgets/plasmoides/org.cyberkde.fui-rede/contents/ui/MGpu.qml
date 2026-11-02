import QtQuick
import "comum"

// GPU: temperatura no anel (0 a 100 °C), uso embaixo; VRAM e potência no rodapé. Sem GPU: a RAM.
Modulo {
    id: m
    titulo: d.anelGpu ? "GPU" : "RAM"; codigo: d.anelGpu ? "temp" : d.t("uso", "use")
    rodape: d.anelExtra
    dica: d.anelGpu ? d.t("Temperatura da placa de vídeo (", "Graphics card temperature (") + d.gpuNome + d.t("), pelo sensor gpu/…/temperature do ksystemstats. O anel vai de 0 a 100 °C.", "), from the ksystemstats gpu/…/temperature sensor. The ring goes from 0 to 100 °C.")
                    : d.t("Sem sensor de GPU: o anel mostra a memória RAM usada.", "No GPU sensor: the ring shows the RAM in use.")
    readonly property int diam: Math.min(width, u(90))
    Arco {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: m.diam; height: width
        inicio: 270; abertura: 360; espessura: m.lw(8)
        trilho: Cores.alfa(Cores.texto, 0.2); cor: m.d.anelValor >= m.d.limiar ? Cores.alerta : Cores.texto
        valor: m.conta(m.d.anelValor)
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(m.diam * 0.31)
        text: m.d.dec(m.conta(m.d.anelNumero), 1)
        font.family: Cores.fIdentidade; font.pixelSize: m.fi(17); font.weight: Font.Medium
        color: Cores.texto
    }
    Rot { k: m.k; anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(m.diam * 0.56); text: m.d.anelUnidade + (m.d.anelGpu ? " GPU" : " RAM") }
    Val { k: m.k; anchors.horizontalCenter: parent.horizontalCenter; y: m.u(98); color: Cores.texto2
          text: m.d.anelGpu ? m.d.t("uso ", "load ") + Math.round(m.d.gpuUso) + " %" : "" }
}
