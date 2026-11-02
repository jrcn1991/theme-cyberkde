import QtQuick
import "../../qml"

// Transição entre pastas nas PILHAS (referência 17: cartões lado a lado em perspectiva que perdem o
// conteúdo, ficam só a moldura e se recolhem em pilha). Camada por cima da visão, independente da
// navegação (nada espera por ela):
//   entrar(caixa, n, cor): os painéis saem empilhados no lugar da pilha clicada, abrem em leque pela
//                          largura da visão, perdem o preenchimento e somem (a pasta nova se monta embaixo);
//   voltar(caixa, n, cor): o inverso, os painéis chegam abertos e se recolhem na pilha da pasta de onde
//                          se voltou.
// Só no movimento completo. No máximo 8 painéis, e só durante a passada.
Item {
    id: t
    enabled: false
    z: 30
    property color cor: Tema.destaque
    property int n: 0
    property rect caixa: Qt.rect(0, 0, 0, 0)     // caixa da pilha (coordenadas desta camada)
    property real escala: 1
    property bool abrindo: true
    property real p: 0                            // 0 = empilhado … 1 = aberto em leque
    readonly property real fim: abrindo ? p : 1 - p   // andamento da passada (para o esmaecer)
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    visible: anda.running

    function entrar(caixa, n, cor, escala) { comecar(true, caixa, n, cor, escala) }
    function voltar(caixa, n, cor, escala) { comecar(false, caixa, n, cor, escala) }
    function comecar(abre, caixa, n, cor, escala) {
        if (!completo || !caixa || caixa.width <= 0 || width <= 0) return
        t.abrindo = abre; t.caixa = caixa; t.n = Math.max(3, Math.min(8, n || 5)); t.cor = cor || Tema.destaque
        t.escala = escala || 1
        anda.stop()
        anda.from = abre ? 0 : 1; anda.to = abre ? 1 : 0
        anda.easing.type = abre ? Easing.OutQuad : Easing.InOutCubic
        anda.duration = abre ? 420 : 340
        anda.start()
    }
    NumberAnimation { id: anda; target: t; property: "p" }

    // geometria da pilha (a mesma da Pilha.qml) e do leque
    readonly property real lw: 26 * escala
    readonly property real lh: 58 * escala
    readonly property real dx: 15 * escala
    readonly property real dy: 5 * escala
    readonly property real k: 0.42
    readonly property real cw: Math.max(lw, Math.min(150, (width * 0.86) / n - 14))      // cartão aberto
    readonly property real ch: Math.min(height * 0.62, cw * 2.1)
    readonly property real x0: (width - (n * cw + (n - 1) * 14 + k * 0)) / 2
    readonly property real y0: (height - ch - cw * k) / 2

    Repeater {
        model: t.visible ? t.n : 0
        Item {
            id: c
            required property int index
            readonly property int i: t.n - 1 - index            // 0 = frente (desenhada por último)
            // empilhado (como na Pilha) → aberto (lado a lado, a frente à esquerda)
            readonly property real ex: t.caixa.x + (t.caixa.width - (t.lw + (t.n - 1) * t.dx)) / 2 + i * t.dx
            readonly property real ey: t.caixa.y + (t.caixa.height - (t.lh + t.lw * t.k + (t.n - 1) * t.dy)) / 2 + (t.n - 1 - i) * t.dy
            readonly property real ax: t.x0 + i * (t.cw + 14)
            readonly property real ay: t.y0
            // cada painel sai um pouco depois do anterior (o leque "corre")
            readonly property real q: Math.max(0, Math.min(1, (t.p * (1 + 0.25) - i * 0.25 / t.n)))
            x: ex + (ax - ex) * q
            y: ey + (ay - ey) * q
            width: t.lw + (t.cw - t.lw) * q
            height: t.lh + (t.ch - t.lh) * q
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, 0, 0, 0,  t.k, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) }
            // abre perdendo o conteúdo: preenchimento some na primeira metade, a moldura fica e esmaece no fim
            opacity: 1 - Math.max(0, (t.fim - 0.75) / 0.25)
            Rectangle {
                anchors.fill: parent
                color: Tema.alfa(t.cor, Math.max(0, 0.30 * (1 - c.q * 1.8)))
                border.width: c.i === 0 ? 2 : 1
                border.color: Tema.alfa(t.cor, 0.95 - 0.35 * (c.i / t.n))
                antialiasing: true
            }
            // "texto" que some enquanto abre (o cartão perde o conteúdo)
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 4 + c.width * 0.08; y: c.height * (0.18 + index * 0.1)
                    width: (c.width - 8) * (index === 3 ? 0.5 : 0.8); height: 1
                    color: Tema.alfa(t.cor, Math.max(0, 0.5 * (1 - c.q * 2)))
                }
            }
        }
    }
}
