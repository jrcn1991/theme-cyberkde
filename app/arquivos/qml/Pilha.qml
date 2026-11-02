import QtQuick
import QtQuick.Shapes
import "../../qml"

// Pilha isométrica de painéis translúcidos (referência "Lista de Projetos Pessoais"): painéis em pé,
// cisalhados (borda de cima descendo para a direita), um ATRÁS do outro com deslocamento diagonal
// pequeno e constante (para trás = para a direita e para cima). A caixa é FIXA (a de 8 painéis):
// toda pilha tem o mesmo tamanho e fica centrada nela, então a grade não se desalinha.
// O número de painéis só sugere o volume (faixas: 0 itens = 1 painel tracejado; 1–3 = 3; 4–10 = 5;
// 11–30 = 7; mais = 8); a contagem exata fica no rótulo. O da frente é o mais definido, o fundo some.
// Seleção ACENDE: o da frente num degrau de flicker (75→10→100%) e os de trás em cascata (35 ms cada), e um
// feixe de luz diagonal varre o painel da frente uma vez (referência 15).
// Hover: bordas a 100%; o painel-subpasta sob o mouse sobe com linhas de varredura e um filete que desce.
// Montagem (referência 18): os painéis chegam ESPALHADOS e em wireframe, se juntam na pilha (o do fundo
// primeiro), o preenchimento entra e uma grade passa por cima; ~420 ms. Movimento reduzido: só uma
// dissolução de 120 ms; mínimo: aparece pronta. "animarMontagem" falso (pilhas longe do topo): pronta.
// O PAINEL DA FRENTE É A PRÓPRIA PASTA (a raiz): moldura mais definida e aba de pasta; clicar nele é
// clicar na pasta. PAINÉIS DE TRÁS = SUBPASTAS: com "subpastas" (do modelo), até 7 subpastas reais
// atrás da raiz; com mais, o último mostra +N. Pasta só com arquivos: a regra das faixas pela
// contagem de arquivos, em painéis mais apagados com linhas de "texto" (arquivo ≠ subpasta).
// O painel sob o mouse (ou o focado pelo teclado) sobe e acende; quem desenha a dica é a visão.
Item {
    id: p
    property int itens: 3                // filhos da pasta / arquivos do grupo (-1 = ainda contando)
    property bool itensLimite: false     // a contagem parou no limite do back-end: mostra "999+"
    property bool acesa: false
    property bool foco: false            // item atual do teclado (borda secundária no da frente)
    property bool hover: false
    property bool alvoSoltar: false      // algo sendo arrastado por cima (pasta)
    property color cor: Tema.destaque
    property real atraso: 0
    property real escala: 1
    property var subpastas: []           // [{nome, caminho, itens, codigo?}] (chega depois: até lá, "itens")
    property int subpastasTotal: -1      // -1 = ainda não chegou
    property int arquivosTotal: -1
    property string raizNome: ""         // a pasta desta pilha (painel da frente)
    property string raizCaminho: ""
    property string raizCodigo: ""
    property int painelHover: -1         // painel sob o mouse (0 = frente)
    property int painelFoco: -1          // painel focado pelo teclado
    readonly property int destacado: painelHover >= 0 ? painelHover : painelFoco
    readonly property bool modoSub: !!subpastas && subpastas.length > 0
    readonly property bool soArquivos: !modoSub && subpastasTotal === 0
    readonly property int mais: modoSub && subpastasTotal > maximo - 1 ? subpastasTotal - (maximo - 2) : 0
    readonly property int contagem: soArquivos && arquivosTotal >= 0 ? arquivosTotal : itens

    readonly property real lw: 26 * escala       // largura de um painel (antes do cisalhamento)
    readonly property real lh: 58 * escala       // altura
    readonly property real dx: 15 * escala       // deslocamento por painel (~0,6 da largura, como no GIF): para a direita…
    readonly property real dy: 5 * escala        // …e para cima
    readonly property real k: 0.42               // inclinação (a borda de cima desce 0,42 por px)
    readonly property int maximo: 8
    readonly property bool vazia: !modoSub && contagem === 0
    readonly property int n: modoSub ? Math.min(maximo, 1 + Math.max(subpastas.length, subpastasTotal))
        : contagem < 0 ? 3 : contagem === 0 ? 1 : contagem <= 3 ? 3 : contagem <= 10 ? 5 : contagem <= 30 ? 7 : maximo
    // dados do painel i: 0 = a raiz {raiz, nome, caminho, itens, codigo}; atrás, {nome, caminho, itens,
    // codigo} da subpasta i-1 ou {mais: N}; null se não há painel (ou atrás, fora do modo subpastas)
    function painel(i) {
        if (i === 0 && raizCaminho) return { raiz: true, nome: raizNome, caminho: raizCaminho, itens: itensLimite ? "999+" : itens, codigo: raizCodigo }
        if (!modoSub || i < 1 || i >= n) return null
        if (mais > 0 && i === n - 1) return { mais: mais }
        return subpastas[i - 1] || null
    }
    // painel sob o ponto (coordenadas da pilha); -1 se nenhum. A FRENTE ganha na área sobreposta e tem
    // margem de folga; os de trás só valem na parte que aparece.
    readonly property real folga: 4 * escala
    function painelEm(px, py) {
        for (let i = 0; i < n; i++) {
            if (i > 0 && !modoSub) break
            const m = i === 0 ? folga : 0
            const x0 = ox + i * dx + 1, y0 = oy + (n - 1 - i) * dy + 1 - (i === destacado ? subida : 0)
            if (px >= x0 - m && px <= x0 + lw + m) { const yy = py - k * (px - x0); if (yy >= y0 - m && yy <= y0 + lh + m) return i }
        }
        return -1
    }
    // centro do topo do painel i (para posicionar a dica)
    function topoDe(i) { return Qt.point(ox + i * dx + 1 + lw / 2, oy + (n - 1 - i) * dy + 1 + k * lw / 2 - subida) }
    readonly property real subida: 9 * escala     // quanto o painel destacado sobe
    // caixa fixa (a de "maximo" painéis); a pilha real fica centrada nela
    implicitWidth: lw + (maximo - 1) * dx + 2
    implicitHeight: lh + lw * k + (maximo - 1) * dy + 2
    readonly property real ox: (implicitWidth - (lw + (n - 1) * dx)) / 2
    readonly property real oy: (implicitHeight - (lh + lw * k + (n - 1) * dy)) / 2

    // ---- montagem (0 = espalhada em wireframe … 1 = pilha pronta)
    property real monta: 1
    property bool animarMontagem: true
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    SequentialAnimation {
        id: montaSeq
        PauseAnimation { duration: p.atraso }
        NumberAnimation { target: p; property: "monta"; from: 0; to: 1; duration: 420; easing.type: Easing.Linear }
    }
    NumberAnimation { id: dissolve; target: p; property: "opacity"; from: 0; to: 1; duration: 120 }
    function iniciarMontagem() {
        montaSeq.stop(); dissolve.stop(); opacity = 1
        if (arquivos.movimento === "minimo" || !animarMontagem) { monta = 1; return }
        if (!completo) { monta = 1; dissolve.restart(); return }
        monta = 0; montaSeq.restart()
    }
    // preenchimento: entra na segunda metade da montagem (antes disso, só as molduras)
    readonly property real preenche: Math.max(0, Math.min(1, (monta - 0.45) / 0.4))

    // ---- acender: flicker no da frente e cascata para o fundo
    property real pisca: acesa ? 1 : 0       // painel da frente
    property real onda: acesa ? n : 0        // painéis de trás: i acende quando onda passa de i
    // célula reaproveitada pela visão (rolagem): troca de dados sem animar nada
    property bool quieta: false
    function assentar() {
        montaSeq.stop(); dissolve.stop(); acende.stop(); opacity = 1; monta = 1
        pisca = acesa ? 1 : 0; onda = acesa ? n : 0
        feixeCaixa.active = false
    }
    onAcesaChanged: {
        acende.stop()
        if (!acesa || Tema.reduzir || quieta) { pisca = acesa ? 1 : 0; onda = acesa ? n : 0; return }
        onda = 0
        acende.restart()
        if (completo && !vazia) { if (feixeCaixa.item) feixeCaixa.item.passar(); else feixeCaixa.active = true }
    }
    SequentialAnimation {
        id: acende
        PropertyAction { target: p; property: "pisca"; value: 0.75 }
        PauseAnimation { duration: 40 }
        PropertyAction { target: p; property: "pisca"; value: 0.1 }
        PauseAnimation { duration: 40 }
        PropertyAction { target: p; property: "pisca"; value: 1 }
        NumberAnimation { target: p; property: "onda"; from: 1; to: p.n; duration: Math.max(1, p.n - 1) * 35 }
    }

    // painéis do fundo para a frente (o da frente desenhado por último)
    Repeater {
        model: p.n
        Item {
            id: cam
            required property int index
            readonly property int i: p.n - 1 - index          // 0 = frente
            readonly property real prof: p.n > 1 ? i / (p.n - 1) : 0      // 0 frente … 1 fundo
            // montagem: o do fundo chega primeiro; espalhado ao longo da diagonal da pilha até juntar
            readonly property real jt: Math.max(0, Math.min(1, (p.monta - index * 0.05) / 0.5))
            readonly property real junta: 1 - Math.pow(1 - jt, 3)
            readonly property real espalha: (1 - junta) * (i - (p.n - 1) / 2) * 2.2
            readonly property bool dest: p.destacado === i
            readonly property bool raiz: i === 0 && p.modoSub
            readonly property real luz: dest ? 1 : i === 0 ? p.pisca : Math.max(0, Math.min(1, p.onda - i))
            readonly property real apaga: p.soArquivos ? 0.5 : 1          // arquivos: mais apagado
            property real sobe: dest ? p.subida : 0
            Behavior on sobe { enabled: !Tema.reduzir && arquivos.movimento !== "minimo"; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            readonly property real fill: p.alvoSoltar ? 0.35
                : p.vazia ? 0.03
                : p.preenche * apaga * ((0.14 - 0.10 * prof) + ((0.85 - 0.45 * prof) - (0.14 - 0.10 * prof)) * luz)
            readonly property real traco: dest || p.alvoSoltar ? 1 : (p.hover ? 1 : apaga * ((0.95 - 0.6 * prof) + 0.05 * luz + 0.6 * prof * luz))
            visible: jt > 0
            x: p.ox + i * p.dx + 1 + espalha * p.dx
            y: p.oy + (p.n - 1 - i) * p.dy + 1 - espalha * p.dy * 2.4 - sobe
            opacity: Math.min(1, jt * 2.5)
            width: p.lw; height: p.lh
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, 0, 0, 0,  p.k, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) }
            Rectangle {
                anchors.fill: parent
                visible: !p.vazia
                color: Tema.alfa(p.cor, cam.fill)
                border.width: cam.raiz ? 2 : 1
                // na montagem, o wireframe é da cor secundária ("grade verde" da referência) até o preenchimento entrar
                border.color: Tema.alfa(cam.dest && p.painelFoco === cam.i || p.foco && cam.i === 0 && p.destacado < 0 ? Tema.secundaria
                                        : p.preenche < 1 ? Tema.mistura(Tema.secundaria, p.cor, p.preenche) : p.cor,
                                        cam.raiz ? Math.max(cam.traco, 0.95) : cam.traco)
                antialiasing: true
            }
            // a raiz: aba de pasta (lingueta à esquerda) por cima do topo, mais cheia que a dos outros
            Rectangle {
                visible: cam.raiz && !p.vazia
                x: 0; y: -4; width: parent.width * 0.45; height: 5
                color: Tema.alfa(p.cor, 0.55 + 0.45 * cam.luz)
                antialiasing: true
            }
            // aba no topo do painel (o "cabeçalho" de cada cartão da referência); em arquivos, linhas de texto
            Rectangle {
                visible: !p.vazia && !p.soArquivos
                x: 3; y: 3; width: parent.width - 6; height: Math.max(5, parent.height * 0.12)
                color: cam.i === 0 && cam.luz > 0.5 && !cam.dest ? Tema.alfa(Tema.escuro, 0.45) : Tema.alfa(p.cor, (cam.raiz ? 0.35 : 0.10) + 0.45 * cam.luz)
                border.width: 1
                border.color: Tema.alfa(p.cor, 0.35 + 0.5 * cam.luz - 0.2 * cam.prof)
                antialiasing: true
            }
            Repeater {
                model: p.soArquivos && !p.vazia ? 4 : 0
                Rectangle {
                    required property int index
                    x: 4; y: 6 + index * 6; height: 1
                    width: (p.lw - 8) * (index === 3 ? 0.55 : 1)
                    color: Tema.alfa(p.cor, 0.30 + 0.4 * cam.luz - 0.2 * cam.prof)
                }
            }
            // +N: o último painel representa as subpastas que não couberam
            Text {
                visible: p.mais > 0 && cam.i === p.n - 1
                x: p.lw - width - 2; y: p.lh * 0.45
                text: "+" + p.mais
                font.family: Tema.fMono; font.pixelSize: 9; font.bold: true
                color: cam.luz > 0.5 ? Tema.escuro : Tema.alfa(p.cor, 0.95)
            }
            // pasta vazia: um painel só, tracejado
            Shape {
                visible: p.vazia
                anchors.fill: parent
                ShapePath {
                    strokeColor: Tema.alfa(p.foco ? Tema.secundaria : p.cor, p.hover || p.acesa || p.alvoSoltar ? 1 : 0.55)
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: Tema.alfa(p.cor, p.alvoSoltar ? 0.35 : 0.03 + 0.25 * cam.luz)
                    startX: 0; startY: 0
                    PathLine { x: p.lw; y: 0 }
                    PathLine { x: p.lw; y: p.lh }
                    PathLine { x: 0; y: p.lh }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }

    // ---- grade que passa durante a montagem (só enquanto monta)
    // (Loader: com milhares de pilhas, nada disto existe fora da montagem)
    Loader {
        active: p.completo && p.monta > 0.12 && p.monta < 0.98
        anchors.fill: parent
        sourceComponent: Item {
        readonly property real a: Math.sin(Math.PI * Math.max(0, Math.min(1, (p.monta - 0.12) / 0.86))) * 0.55
        Repeater {
            model: 4
            Rectangle { required property int index; x: 0; y: (index + 1) * p.implicitHeight / 5; width: p.width; height: 1; color: Tema.alfa(Tema.secundaria, parent.a * 0.6) }
        }
        Repeater {
            model: 3
            Rectangle { required property int index; x: (index + 1) * p.implicitWidth / 4; y: 0; width: 1; height: p.height; color: Tema.alfa(Tema.secundaria, parent.a * 0.5) }
        }
        Rectangle {  // a linha de leitura que atravessa a pilha
            width: p.width; height: 2
            y: p.height * p.monta
            color: Tema.alfa(Tema.secundaria, parent.a * 1.6)
        }
        }
    }

    // ---- superfícies de efeito sobre UM painel (cisalhadas como ele), só quando usadas:
    //      o feixe de luz da seleção (painel da frente) e a varredura do painel sob o mouse
    function geometriaPainel(i) {
        return Qt.rect(ox + i * dx + 1, oy + (n - 1 - i) * dy + 1 - (i === destacado ? subida : 0), lw, lh)
    }
    Loader {
        id: feixeCaixa
        active: false                      // criado na seleção, destruído quando a passada acaba
        readonly property rect g: p.geometriaPainel(0)
        x: g.x; y: g.y; width: g.width; height: g.height
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, 0, 0, 0,  p.k, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) }
        sourceComponent: Item {
            clip: true
            function passar() { feixe.passar() }
            FeixeLuz { id: feixe; cor: Tema.secundaria; onAcabou: feixeCaixa.active = false }
        }
        onLoaded: item.passar()
    }
    Loader {
        id: varreduraHover
        active: p.painelHover >= 0 && p.completo && !p.vazia
        readonly property rect g: p.geometriaPainel(Math.max(0, p.painelHover))
        x: g.x; y: g.y; width: g.width; height: g.height
        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, 0, 0, 0,  p.k, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1) }
        sourceComponent: Item {
            clip: true
            LinhasVarredura { ligado: true; cor: Tema.secundaria }
        }
        // ao trocar de painel, recria (o filete desce de novo no painel novo)
        Connections { target: p; function onPainelHoverChanged() { if (varreduraHover.active) { varreduraHover.active = false; varreduraHover.active = Qt.binding(() => p.painelHover >= 0 && p.completo && !p.vazia) } } }
    }
}
