import QtQuick
import "../comum"

// Linhas: a cada anúncio, um brilho corre pelo fio, dos dois lados; na troca de módulo, um traço curto cruza a base.
Item {
    id: e
    property var tema
    property var ctx
    readonly property var caminho: [Qt.point(width / 2, 0.5), Qt.point(width - 0.5, 0.5), Qt.point(width - 0.5, height - 0.5), Qt.point(0.5, height - 0.5), Qt.point(0.5, 0.5), Qt.point(width / 2, 0.5)]
    Relogio { id: rel; ms: 520 }
    Relogio { id: troca; ms: 240 }
    readonly property color cor: e.ctx.nivel === "alerta" || e.ctx.nivel === "erro" ? e.tema.alerta : e.tema.acao
    Contorno {
        anchors.fill: parent; visible: rel.running
        pontos: e.caminho; duasPontas: true; fracao: rel.p; cor: e.cor; espessura: 1.5; opacity: 1 - Math.pow(rel.p, 4)
    }
    Rectangle {
        visible: troca.running
        y: e.height - 2; height: 1; width: e.width * 0.3
        x: -width + (e.width + width) * (1 - Math.pow(1 - troca.p, 3))
        color: e.tema.texto
    }
    Connections {
        target: e.ctx
        function onPicoChanged() { if (!e.ctx.reduzir) rel.tocar() }
    }
    readonly property var _mod: e.ctx.modulo
    on_ModChanged: if (!e.ctx.reduzir) troca.tocar()
}
