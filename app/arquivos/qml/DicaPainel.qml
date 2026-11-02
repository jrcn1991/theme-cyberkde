import QtQuick
import "../../qml"

// Dica do painel-subpasta destacado numa Pilha (hover ou teclado): moldura chanfrada sobre o painel,
// com o nome se decodificando letra a letra (ruído → texto, ~18 ms por letra), a contagem de itens e o
// código hex. Entra em ~150 ms (sobe 6 px e aparece); movimento mínimo/reduzido: aparece pronta.
// A decodificação SEMPRE termina (U6): o nome que chega ou muda depois reinicia a decodificação, um timer
// de segurança mostra o nome inteiro em até 300 ms, e no modo calmo o nome aparece direto.
Item {
    id: d
    property var pilha: null
    property Item area: null                 // onde a dica é desenhada (coordenadas)
    property real topo: 0                    // topo visível da área (contentY): sem espaço acima, vai para baixo
    readonly property var dado: pilha ? pilha.painel(pilha.destacado) : null
    readonly property bool calmo: Tema.reduzir || arquivos.movimento === "minimo"
    readonly property string nome: !dado ? "" : dado.mais ? Ds.t("dica.mais", { n: dado.mais }) : dado.nome
    readonly property string linha2: !dado ? "" : dado.mais ? Ds.t("dica.abreMae")
        : (dado.raiz ? Ds.t("dica.raiz") + " · " : "") + Ds.t("dica.itens", { n: dado.itens < 0 ? "…" : dado.itens }) + " · " + (dado.codigo || Ds.hexDe(dado.caminho))
    readonly property var ponto: pilha && area && dado ? pilha.mapToItem(area, pilha.topoDe(pilha.destacado)) : Qt.point(0, 0)

    width: Math.min(260, Math.max(130, Math.max(tNome.implicitWidth, tL2.implicitWidth) + 26))
    height: 46
    x: area ? Math.max(4, Math.min(area.width - width - 4, ponto.x - width / 2)) : 0
    readonly property bool embaixo: ponto.y - height - 10 < topo + 2
    y: (embaixo ? ponto.y + (pilha ? pilha.lh : 60) + 12 : ponto.y - height - 10) + _desce
    z: 50
    visible: opacity > 0
    opacity: 0
    property real _desce: 0

    // ---- decodificação
    property int _rev: 0
    readonly property string _ruido: "▚▞#/\\<>[]_=+*01ΞΔ"
    readonly property string mostrado: {
        if (calmo || _rev >= nome.length) return nome
        let o = nome.slice(0, _rev)
        for (let i = _rev; i < nome.length; i++) o += nome[i] === " " ? " " : _ruido[(i * 7 + _rev * 3) % _ruido.length]
        return o
    }
    Timer { id: decod; interval: 18; repeat: true; onTriggered: { d._rev++; if (d._rev >= d.nome.length) stop() } }
    // segurança: o nome inteiro aparece em até 300 ms, aconteça o que acontecer com a decodificação
    Timer { id: garantia; interval: 300; onTriggered: { decod.stop(); d._rev = d.nome.length } }
    function decodificar() {
        decod.stop()
        if (calmo || !nome) { _rev = nome.length; garantia.stop(); return }
        _rev = 0; decod.start(); garantia.restart()
    }

    onDadoChanged: {
        if (!dado) { entra.stop(); decod.stop(); garantia.stop(); opacity = 0; return }
        decodificar()
        if (calmo) { opacity = 1; _desce = 0; return }
        if (opacity < 1) { _desce = 6; entra.restart() }
    }
    // o nome que chega/muda depois (as subpastas vêm aos poucos) decodifica de novo, até o fim
    onNomeChanged: if (dado) decodificar()
    ParallelAnimation {
        id: entra
        NumberAnimation { target: d; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: d; property: "_desce"; to: 0; duration: 150; easing.type: Easing.OutCubic }
    }

    Chanfro {
        anchors.fill: parent
        corte: 8
        preenchimento: Tema.alfa(Tema.fundo, 0.94)
        borda: Tema.alfa(d.pilha ? d.pilha.cor : Tema.destaque, 0.9)
    }
    // marca à esquerda, como nos cabeçalhos do tema
    Rectangle { x: 0; y: 8; width: 3; height: parent.height - 16; color: d.pilha ? d.pilha.cor : Tema.destaque }
    Text {
        id: tNome
        x: 12; y: 6; width: parent.width - 22
        text: d.mostrado
        elide: Text.ElideRight
        font.family: Tema.fTexto; font.pixelSize: 13
        color: Tema.texto
    }
    Codigo {
        id: tL2
        x: 12; y: 27
        text: d.linha2
        tamanho: 9
        color: d.pilha ? d.pilha.cor : Tema.destaque
    }
    // fio até o painel
    Rectangle {
        x: Math.max(10, Math.min(parent.width - 10, d.ponto.x - d.x)); y: d.embaixo ? -8 : parent.height
        width: 1; height: 8
        color: Tema.alfa(d.pilha ? d.pilha.cor : Tema.destaque, 0.8)
    }
}
