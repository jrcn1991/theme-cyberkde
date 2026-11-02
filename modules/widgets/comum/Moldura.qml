import QtQuick

// Moldura de um widget CyberKDE: superfície chanfrada perto do fundo da corporação (na opacidade do
// widget), marcador lateral no destaque, cantoneiras, um código técnico e o título. Ao aparecer, monta
// como as janelas do painel: a moldura se traça (280 ms), a superfície entra e o conteúdo acende com
// flicker de liga e desliga (também a cada troca de tamanho). Com o movimento em "mínimo", aparece pronta.
// Só dados: os controles de edição (alça, presets) ficam na faixa do Tamanhos, fora do conteúdo.
Item {
    id: m
    property string titulo: ""
    property string codigo: ""
    property bool cabecalho: true
    property real opacidade: 0.95         // da superfície (0..1)
    default property alias conteudo: area.data
    property alias area: area
    property alias extra: extra.data
    property real margem: 12
    property bool tituloSistema: false    // o título é um nome (pasta): fonte do sistema, com a caixa real
    property color cor: Cores.destaque    // papel da Paleta (a cerca escolhe; o padrão é o destaque)

    // montagem
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    function montar() {
        anim.stop()
        if (Cores.reduzir) { traco = 1; superficie = 1; acender = 1; return }
        traco = 0; superficie = 0; acender = 0
        anim.start()
    }
    Component.onCompleted: montar()

    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation { target: m; property: "traco"; from: 0; to: 1; duration: Cores.d(280) }
            SequentialAnimation {
                PauseAnimation { duration: Cores.d(160) }
                NumberAnimation { target: m; property: "superficie"; to: 1; duration: Cores.d(140) }
            }
            SequentialAnimation {
                PauseAnimation { duration: Cores.d(220) }
                PropertyAction { target: m; property: "acender"; value: 0.75 }
                PauseAnimation { duration: Cores.d(33) }
                PropertyAction { target: m; property: "acender"; value: 0.1 }
                PauseAnimation { duration: Cores.d(33) }
                PropertyAction { target: m; property: "acender"; value: 0.9 }
                PauseAnimation { duration: Cores.d(33) }
                PropertyAction { target: m; property: "acender"; value: 0.35 }
                PauseAnimation { duration: Cores.d(33) }
                PropertyAction { target: m; property: "acender"; value: 1 }
            }
        }
    }

    Item {
        id: palco
        anchors.fill: parent

        Item {
            width: m.width; height: m.height

            Chanfro {
                anchors.fill: parent
                corte: 12
                preenchimento: Cores.alfa(Cores.cartao, Cores.alfaSuperficie(m.opacidade) * m.superficie)
                borda: Cores.alfa(m.cor, 0.45)
                traco: m.traco
            }
            Rectangle { x: 0; y: 18; width: 3; height: 22 * Math.max(0, Math.min(1, (m.traco - 0.5) * 2)); color: m.cor }
            Cantoneiras { anchors.margins: -4; cor: Cores.alfa(m.cor, 0.35); tamanho: 7; opacity: m.superficie }

            Item {
                id: topo
                visible: m.cabecalho
                x: m.margem; y: m.margem - 2
                width: parent.width - 2 * m.margem; height: visible ? 20 : 0
                opacity: m.acender
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Rotulo {
                        id: tit
                        text: m.titulo; tamanho: 14; anchors.verticalCenter: parent.verticalCenter
                        // nome longo corta aqui, sem invadir a vizinha
                        width: Math.min(implicitWidth, topo.width - (extra.width > 0 ? extra.width + 16 : 0))
                        elide: Text.ElideRight
                        font.family: m.tituloSistema ? Cores.fTexto : Cores.fTitulo
                        font.weight: m.tituloSistema ? Font.Medium : Font.DemiBold
                        font.capitalization: m.tituloSistema ? Font.MixedCase : Font.AllUppercase
                        font.letterSpacing: m.tituloSistema ? 0 : 1
                    }
                    // o código cede espaço aos botões/etiquetas da direita (corta com reticências)
                    Codigo {
                        text: m.codigo; color: m.cor
                        width: Math.max(0, Math.min(implicitWidth, topo.width - tit.width - 8 - (extra.width > 0 ? extra.width + 8 : 0)))
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    id: extra
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                }
            }
            Item {
                id: area
                opacity: m.acender
                x: m.margem
                y: topo.y + topo.height + (m.cabecalho ? 8 : 0)
                width: parent.width - 2 * m.margem
                height: parent.height - y - m.margem
            }
        }
    }
}
