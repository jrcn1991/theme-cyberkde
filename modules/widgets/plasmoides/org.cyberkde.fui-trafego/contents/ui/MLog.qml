import QtQuick
import "comum"

// LOG: os últimos eventos do journal do usuário (hora e origem em cima, mensagem embaixo).
Modulo {
    id: m
    titulo: "Log"; codigo: d.t("sistema", "system")
    rodape: "journalctl --user · " + d.logNivel + d.t(" e acima", " and up")
    dica: d.t("Últimos eventos do journal do seu usuário (journalctl --user), a partir do nível escolhido na configuração. Só leitura.",
              "Latest events from your user journal (journalctl --user), from the level chosen in the settings. Read only.")
    // quantas entradas cabem (cada uma = 2 linhas, na altura real da fonte)
    readonly property int quantos: Math.max(1, Math.floor((u(124) + u(3)) / (Math.ceil(fr(10) * 1.32) + Math.ceil(fi(11) * 1.32) + u(3))))
    Column {
        width: m.width; spacing: m.u(3)
        clip: true; height: m.u(124)
        Repeater {
            model: m.d.logLinhas.slice(-m.quantos)
            Column {
                required property var modelData
                required property int index
                readonly property bool nova: index === Math.min(m.quantos, m.d.logLinhas.length) - 1
                width: m.width
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: modelData.hora + "  " + modelData.origem
                    font.family: Cores.fMono; font.pixelSize: m.fr(10); font.weight: Font.Bold
                    color: parent.nova ? Cores.destaque : Cores.texto2
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: parent.nova ? m.digita(modelData.msg, Math.min(m.montado, m.d.logNova)) : m.digita(modelData.msg)
                    font.family: Cores.fMono; font.pixelSize: m.fi(11)
                    color: Cores.texto
                }
            }
        }
    }
    Val { k: m.k; visible: m.d.logLinhas.length === 0; text: m.d.t("Nenhum evento", "No events"); color: Cores.texto2 }
}
