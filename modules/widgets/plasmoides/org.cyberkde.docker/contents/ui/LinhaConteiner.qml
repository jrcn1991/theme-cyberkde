import QtQuick
import "comum"

// Uma linha da lista de contêineres: estado, nome, imagem e uptime; com "detalhes", CPU, memória e as
// ações (iniciar, parar com confirmação, reiniciar). Os textos do Docker entram só como texto.
Item {
    id: l
    property var c: ({})
    property var st: null
    property bool detalhes: false
    property string pendente: ""      // ação em andamento
    property bool armado: false       // "parar" esperando a confirmação
    property bool en: false
    signal acao(string a)
    function t(pt, ing) { return en ? ing : pt }

    readonly property bool roda: c.estado === "running"
    readonly property color corEstado: c.saude === "unhealthy" ? Cores.alerta
        : roda ? Cores.destaque : (c.estado === "paused" || c.estado === "restarting" ? Cores.secundaria : Cores.texto3)
    height: detalhes ? 44 : 30

    Chanfro {
        anchors.fill: parent
        corte: 5
        preenchimento: l.armado ? Cores.alfa(Cores.alerta, 0.14) : Cores.alfa(Cores.elevado, l.roda ? 0.7 : 0.4)
        borda: l.armado ? Cores.alerta : Cores.linha
    }
    Rectangle {  // faixa de estado à esquerda
        x: 0; y: 4; width: 3; height: parent.height - 8
        color: l.corEstado
    }
    Column {
        anchors.left: parent.left; anchors.leftMargin: 10
        anchors.right: direita.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Leitura {
            width: parent.width
            text: l.c.nome || l.c.id
            textFormat: Text.PlainText
            elide: Text.ElideRight
            tamanho: 12; font.weight: Font.DemiBold
            color: l.roda ? Cores.texto : Cores.texto2
        }
        Codigo {
            width: parent.width
            text: l.armado ? l.t("PARAR? CLIQUE DE NOVO EM ■", "STOP? CLICK ■ AGAIN")
                  : (l.c.imagem || "") + (l.detalhes ? "" : "  ·  " + l.c.uptime)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            tamanho: 8
            color: l.armado ? Cores.alerta : Cores.texto3
        }
    }
    Row {
        id: direita
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Column {  // uptime e, rodando, CPU/memória
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            visible: l.detalhes
            Codigo {
                anchors.right: parent.right
                text: (l.roda ? "▲ " : "■ ") + l.c.uptime
                tamanho: 8; color: l.corEstado
            }
            Codigo {
                anchors.right: parent.right
                visible: l.roda
                text: l.st ? "CPU " + l.st.cpu + " · " + l.st.mem : "CPU -- · --"
                tamanho: 8; color: l.st && l.st.cpuNum >= 80 ? Cores.alerta : Cores.texto2
            }
        }
        Codigo {
            visible: l.pendente !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: "…"; tamanho: 12; color: Cores.secundaria
        }
        Row {
            visible: l.detalhes && l.pendente === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            BotaoIcone {
                visible: !l.roda
                glifo: "▶"; tamanho: 22
                dica: l.t("Iniciar", "Start")
                onClicado: l.acao("start")
            }
            BotaoIcone {
                visible: l.roda
                glifo: "■"; tamanho: 22
                ativo: l.armado
                dica: l.armado ? l.t("Clique de novo para parar", "Click again to stop") : l.t("Parar", "Stop")
                onClicado: l.acao("stop")
            }
            BotaoIcone {
                visible: l.roda
                glifo: "↻"; tamanho: 22
                dica: l.t("Reiniciar", "Restart")
                onClicado: l.acao("restart")
            }
        }
    }
}
