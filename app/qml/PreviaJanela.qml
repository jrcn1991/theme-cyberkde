import QtQuick

// Prévia de uma animação de janela. Com o .webp da Rachael (assets/previas/janelas), toca a imagem
// animada; sem ele, desenha uma aproximação em QML pelo "estilo" da variante. Só toca com "tocar"
// (hover ou seleção) e nunca com "reduzir animações": parada, mostra a janela aberta.
// modo: "abrir" (p 0→1) ou "fechar" (p 1→0). "nenhuma": a janela some sem animação.
Item {
    id: v
    property string estilo: "varredura"
    property string modo: "abrir"
    property url fonte: ""             // webp/gif animado (opcional)
    property bool tocar: false
    property int duracao: 280
    property color cor: Tema.destaque
    property real p: 1                 // 0 = fechada, 1 = aberta

    clip: true
    readonly property bool _anima: tocar && !Tema.reduzir && visible
    function _lim(x) { return Math.max(0, Math.min(1, x)) }
    function _expo(x) { return x >= 1 ? 1 : 1 - Math.pow(2, -10 * x) }
    function _r(i, k) { const s = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453; return s - Math.floor(s) }

    Rectangle { anchors.fill: parent; color: Tema.mistura(Tema.fundo, "#000000", 0.3) }
    // "área de trabalho" de fundo: grade discreta
    Repeater {
        model: 5
        Rectangle { required property int index; x: (index + 1) * v.width / 6; width: 1; height: v.height; color: Tema.alfa(Tema.linha, 0.4) }
    }

    // ---- prévia em imagem animada
    AnimatedImage {
        id: anim
        visible: v.fonte != ""
        anchors.fill: parent
        source: v.fonte
        fillMode: Image.PreserveAspectCrop
        playing: v._anima
        paused: !v._anima
        asynchronous: true
        cache: false
    }

    // ---- prévia desenhada
    Item {
        id: palco
        visible: v.fonte == ""
        anchors.fill: parent
        readonly property real w: v.width * 0.68
        readonly property real h: v.height * 0.64
        readonly property real x0: (v.width - w) / 2
        readonly property real y0: (v.height - h) / 2
        readonly property real p: v.p
        readonly property real e: v._expo(p)

        // a janela (estilos que mexem nela inteira)
        MiniJanela {
            id: jan
            cor: v.cor
            x: palco.x0 + (v.estilo === "holograma" && palco.p < 1 ? (v._r(Math.floor(palco.p * 30), 1) - 0.5) * 6 : 0)
            y: palco.y0
            width: palco.w; height: palco.h
            visible: ["glitch", "cortina", "linhas", "varredura"].indexOf(v.estilo) < 0 && palco.p > 0.001
            transformOrigin: Item.Center
            scale: v.estilo === "zoom" ? 0.3 + 0.7 * palco.e : 1
            opacity: {
                const p = palco.p
                switch (v.estilo) {
                case "zoom": case "aberracao": return Math.min(1, p * 1.4)
                case "holograma": return p >= 1 ? 1 : (Math.floor(p * 20) % 3 === 0 ? 0.25 : 0.4 + p * 0.6)
                case "montagem": return 1
                case "dados": case "desintegrar": return p * p
                case "interferencia": return Math.min(1, p * 1.2)
                case "braindance": return v._lim((p - 0.45) / 0.4)
                case "nenhuma": return p >= 0.999 ? 1 : 0
                default: return Math.min(1, p * 1.5)
                }
            }
            // CRT: abre de uma linha no centro
            transform: Scale {
                origin.x: palco.w / 2; origin.y: palco.h / 2
                xScale: v.estilo === "crt" ? Math.max(0.02, Math.min(1, palco.p * 2.2)) : 1
                yScale: v.estilo === "crt" ? (palco.p < 0.45 ? 0.012 : Math.max(0.012, (palco.p - 0.45) / 0.55)) : 1
            }
            // digitalizar: textura em baixa resolução, sem suavizar
            layer.enabled: v.estilo === "pixel" && palco.p < 1
            layer.smooth: false
            layer.textureSize: Qt.size(Math.max(2, palco.w * (0.04 + Math.pow(palco.p, 2) * 0.96)),
                                       Math.max(2, palco.h * (0.04 + Math.pow(palco.p, 2) * 0.96)))
        }

        // montagem: moldura traçada por cima
        Chanfro {
            visible: v.estilo === "montagem" && palco.p < 1
            x: palco.x0; y: palco.y0; width: palco.w; height: palco.h
            corte: Math.max(4, Math.min(width, height) * 0.08)
            preenchimento: Tema.mistura(Tema.fundo, "#000000", 0.3)
            borda: "transparent"
            traco: v._lim(palco.p / 0.55)
            superficie: 1
            opacity: palco.p < 0.6 ? 1 : (Math.floor(palco.p * 40) % 2 ? 0.2 : 0.8) * (1 - (palco.p - 0.6) / 0.4)
        }

        // varredura: revela de cima para baixo atrás de uma linha
        Item {
            visible: v.estilo === "varredura"
            x: palco.x0; y: palco.y0; width: palco.w; height: palco.h * palco.p
            clip: true
            MiniJanela { width: palco.w; height: palco.h; cor: v.cor }
        }
        Rectangle {
            visible: v.estilo === "varredura" && palco.p > 0 && palco.p < 1
            x: palco.x0 - 6; width: palco.w + 12; height: 2
            y: palco.y0 + palco.h * palco.p - 1
            color: Tema.secundaria
        }

        // linhas de terminal: desce em degraus
        Item {
            visible: v.estilo === "linhas"
            x: palco.x0; y: palco.y0; width: palco.w
            height: palco.h * Math.floor(palco.p * 9) / 9
            clip: true
            MiniJanela { width: palco.w; height: palco.h; cor: v.cor }
        }

        // comporta: duas metades
        Repeater {
            model: v.estilo === "cortina" ? 2 : 0
            Item {
                required property int index
                x: palco.x0; width: palco.w; height: palco.h / 2
                y: palco.y0 + index * palco.h / 2 + (index === 0 ? -1 : 1) * (1 - palco.e) * palco.h * 0.5
                clip: true
                opacity: Math.min(1, palco.p * 2)
                MiniJanela { y: -parent.index * palco.h / 2; width: palco.w; height: palco.h; cor: v.cor }
            }
        }

        // glitch: fatias deslocadas
        Repeater {
            model: v.estilo === "glitch" ? 7 : 0
            Item {
                required property int index
                readonly property real fh: palco.h / 7
                x: palco.x0 + (v._r(index, 2) - 0.5) * palco.w * 0.6 * (1 - v._expo(v._lim((palco.p - v._r(index, 3) * 0.3) / 0.7)))
                y: palco.y0 + index * fh
                width: palco.w; height: fh + 1
                clip: true
                visible: palco.p > v._r(index, 3) * 0.3
                MiniJanela { y: -parent.index * parent.fh; width: palco.w; height: palco.h; cor: v.cor }
            }
        }

        // aberração: cópias tingidas convergindo
        Repeater {
            model: v.estilo === "aberracao" && palco.p < 1 ? 2 : 0
            Rectangle {
                required property int index
                x: palco.x0 + (index ? 1 : -1) * (1 - palco.e) * palco.w * 0.12
                y: palco.y0; width: palco.w; height: palco.h
                color: "transparent"
                border.width: 2
                border.color: index ? Tema.secundaria : v.cor
                opacity: 0.8 * (1 - palco.p)
            }
        }

        // holograma: linhas de varredura por cima
        Repeater {
            model: v.estilo === "holograma" && palco.p < 1 ? Math.floor(palco.h / 4) : 0
            Rectangle {
                required property int index
                x: palco.x0; y: palco.y0 + index * 4; width: palco.w; height: 1
                color: Tema.alfa(Tema.secundaria, 0.35)
            }
        }

        // chuva de dados / interferência / desintegrar: partículas
        Repeater {
            model: (v.estilo === "dados" || v.estilo === "interferencia" || v.estilo === "desintegrar") && palco.p < 1 ? 40 : 0
            Rectangle {
                required property int index
                readonly property real fx: v._r(index, 1)
                readonly property real fy: v._r(index, 2)
                width: v.estilo === "dados" ? 2 : 3 + v._r(index, 4) * 4
                height: v.estilo === "dados" ? 4 + v._r(index, 5) * 10 : (v.estilo === "interferencia" ? 1 + v._r(index, 6) * 2 : width)
                x: v.estilo === "desintegrar"
                    ? palco.x0 + fx * palco.w + (v._r(index, 7) - 0.5) * v.width * (1 - palco.e)
                    : palco.x0 + fx * palco.w
                y: v.estilo === "dados"
                    ? palco.y0 - 20 + ((fy + palco.p * 1.4) % 1) * (palco.h + 20)
                    : v.estilo === "desintegrar"
                    ? palco.y0 + fy * palco.h + (v._r(index, 8) - 0.5) * v.height * (1 - palco.e)
                    : palco.y0 + v._r(index + Math.floor(palco.p * 25), 2) * palco.h
                color: index % 5 === 0 ? v.cor : Tema.secundaria
                opacity: v.estilo === "interferencia" ? 0.8 * (1 - palco.p) : (1 - palco.p * 0.8)
            }
        }

        // braindance: camadas de moldura vermelha com marcas de tempo
        Repeater {
            model: v.estilo === "braindance" && palco.p < 1 ? 3 : 0
            Rectangle {
                required property int index
                readonly property real q: v._lim((palco.p - index * 0.12) / 0.5)
                x: palco.x0 + palco.w * (1 - q) / 2; y: palco.y0 + palco.h * (1 - q) / 2
                width: palco.w * q; height: palco.h * q
                color: "transparent"
                border.width: 1
                border.color: Tema.erro
                opacity: q > 0 ? 0.9 - index * 0.25 : 0
                Codigo { x: 3; y: 2; text: "00:0" + parent.index + ":" + Math.floor(palco.p * 60); tamanho: 7; color: Tema.erro }
            }
        }
    }

    // ---- tocar em laço: abrir (ou fechar), pausa, recomeça
    SequentialAnimation {
        id: laco
        running: v._anima && v.fonte == ""
        loops: Animation.Infinite
        PropertyAction { target: v; property: "p"; value: v.modo === "fechar" ? 1 : 0 }
        PauseAnimation { duration: 260 }
        NumberAnimation {
            target: v; property: "p"
            from: v.modo === "fechar" ? 1 : 0; to: v.modo === "fechar" ? 0 : 1
            duration: Math.max(150, v.duracao * 1.6)   // um pouco mais lenta, para dar para ver
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 700 }
        onRunningChanged: if (!running) v.p = 1
    }
}
