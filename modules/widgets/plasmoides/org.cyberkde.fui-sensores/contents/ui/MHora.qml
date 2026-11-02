import QtQuick
import "comum"

// HORA: HH:MM grande sobre as caixas-fantasma da referência, os dois-pontos piscando no destaque; legendas
// HORAS/MINUTOS, o dia e há quanto tempo o computador está ligado.
Modulo {
    id: m
    titulo: d.t("Hora", "Time"); codigo: "local · UTC" + d.fuso
    rodape: d.agora.toLocaleDateString(Qt.locale(), d.en ? "dddd, MMMM d yyyy" : "dddd, d 'de' MMMM 'de' yyyy")
    dica: d.t("Hora local deste computador. \"Ligado há\": tempo desde o último boot.", "This computer's local time. \"Up\": time since the last boot.")
    readonly property real ex: width / u(349)            // largura própria (módulo avulso mais largo ou mais estreito)
    readonly property var cx: [0, u(80) * ex, u(186) * ex, u(266) * ex].map(Math.round)
    readonly property int cw: Math.round(u(76) * ex)
    readonly property int fonte: Math.round(Math.min(u(80), u(80) * ex))
    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: m.cx[index]; y: m.u(4); width: m.cw; height: m.u(80); radius: m.u(8)
            color: "transparent"; border.color: Cores.alfa(Cores.texto, 0.08); border.width: Math.max(2, m.u(5))
        }
    }
    Repeater {
        model: 4
        NumeroCintilante {
            required property int index
            readonly property string hm: m.d.agora.toLocaleTimeString(Qt.locale("C"), "HHmm")
            x: m.cx[index]; y: m.u(44) - Math.round(height / 2)
            width: m.cw; horizontalAlignment: Text.AlignHCenter
            visible: m.montado >= (index + 1) * 0.22
            valor: hm[index]
            font.family: Cores.fIdentidade; font.pixelSize: m.fonte; font.weight: Font.DemiBold
            color: Cores.texto
        }
    }
    Text {
        x: Math.round((m.cx[1] + m.cw + m.cx[2]) / 2 - width / 2); y: m.u(44) - Math.round(height / 2)
        text: ":"
        font.family: Cores.fIdentidade; font.pixelSize: m.fonte; font.weight: Font.DemiBold
        color: Cores.destaque
        visible: m.montado >= 0.5
        opacity: m.d.segundo % 2 === 0 || Cores.reduzir ? 1 : 0.2
    }
    Rot { k: m.k; x: m.cx[0]; y: m.u(92); text: m.d.t("HORAS", "HOURS") }
    Rot { k: m.k; x: m.cx[2]; y: m.u(92); text: m.d.t("MINUTOS", "MINUTES") }
    Val { k: m.k; x: 0; y: m.u(108); text: m.d.agora.toLocaleDateString(Qt.locale(), "ddd dd/MM").toUpperCase(); color: Cores.texto }
    Val { k: m.k; anchors.right: parent.right; y: m.u(108); visible: m.d.uptime > 0
          text: m.d.t("ligado há ", "up ") + m.d.duracao(m.d.uptime); color: Cores.texto2 }
}
