import QtQuick

// Rodapé: operação em andamento com a barra segmentada ligada ao PROGRESSO do CLI; parado, mostra
// a última linha do registro.
Item {
    id: r
    height: 44

    readonly property var p: painel.progresso
    readonly property bool temTotal: p.total > 0

    Rectangle { anchors.fill: parent; color: Tema.fundo; opacity: 0.85 }
    Rectangle { width: parent.width; height: 1; color: Tema.linha }
    Rectangle { width: 80; height: 1; color: painel.ocupado ? Tema.secundaria : Tema.destaque }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 20
        spacing: 14
        width: parent.width - 40

        Rectangle {
            width: 8; height: 8; rotation: 45
            anchors.verticalCenter: parent.verticalCenter
            color: painel.ocupado ? Tema.secundaria : Tema.sucesso
            SequentialAnimation on opacity {
                running: painel.ocupado && !Tema.reduzir
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.2; duration: 300 }
                NumberAnimation { to: 1; duration: 300 }
            }
        }
        Rotulo {
            id: estado
            text: painel.ocupado ? Txt.t("rodape.processando") : Txt.t("rodape.pronto")
            tamanho: 14
            color: painel.ocupado ? Tema.secundaria : Tema.texto2
            anchors.verticalCenter: parent.verticalCenter
            width: 96
        }
        Leitura {
            id: msg
            anchors.verticalCenter: parent.verticalCenter
            width: painel.ocupado ? Math.min(360, parent.width * 0.32) : parent.width - estado.width - dicas.width - 60
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            tamanho: 12
            text: {
                if (painel.ocupado) {
                    let s = painel.operacao
                    if (r.p.etapa) s += "  ·  " + r.p.etapa + (r.p.fase ? " " + r.p.fase : "")
                    return s
                }
                const reg = painel.registro
                return reg.length ? reg[reg.length - 1].hora + "  " + reg[reg.length - 1].texto : ""
            }
        }
        BarraSegmentada {
            visible: painel.ocupado
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - estado.width - msg.width - cont.width - 70
            height: 10
            valor: r.temTotal ? r.p.feitas / r.p.total : 0
            indeterminado: !r.temTotal
        }
        Row {
            id: dicas
            visible: !painel.ocupado
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Atalho { tecla: "F5"; anchors.verticalCenter: parent.verticalCenter }
            Codigo { text: Txt.t("rodape.atualizar"); tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
            Item { width: 8; height: 1 }
            Atalho { tecla: "F1"; anchors.verticalCenter: parent.verticalCenter }
            Codigo { text: Txt.t("rodape.atalhos"); tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
        }
        Codigo {
            id: cont
            visible: painel.ocupado
            anchors.verticalCenter: parent.verticalCenter
            text: r.temTotal ? ("0" + r.p.feitas).slice(-2) + "/" + ("0" + r.p.total).slice(-2) : "--/--"
            tamanho: 11
            color: Tema.secundaria
        }
    }
}
