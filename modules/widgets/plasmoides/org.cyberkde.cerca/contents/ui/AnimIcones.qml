import QtQuick
import org.kde.private.desktopcontainment.folder as Folder
import "comum"
import "anim/catalogoIcones.js" as CatIcones

// Animação dos ícones de uma cerca (catálogo em contents/animacoes-icones.json). Um relógio só ("p", 0–1);
// cada delegate VISÍVEL lê daqui o seu estado com estado(), e aplica por transform no ícone. Fora da
// animação não há nada: "ligado" é falso, os delegates ficam como sempre e nada aqui pede quadro.
//   preparar()         esconde os ícones (a pasta ainda carrega, a cerca ainda entra);
//   tocar(atraso)      entrada: até 60 ícones visíveis, com stagger limitado e total sempre < 1,2 s;
//   sair(ms, atraso)   a saída de cada variante, no tempo pedido (o relógio volta de 1 a 0);
//   parar()            termina na hora (clique na grade, rolagem).
// Quem dispara é só o main.qml e a troca de pasta: rolar nunca dispara, e rolar durante a animação a termina.
// Os cliques da grade são por célula, então valem a qualquer momento. Tudo fica dentro do clip da grade.
// Movimento: reduzido = dissolução; mínimo = nada.
// A coreografia da explosão vem de ~/Área de trabalho/Cyberpunk/e6720e…gif, comprimida para caber no teto: fenda que
// abre e rasga, estouro radial sem girar (curva medida), alerta em degraus por cartão e saída que esmaga no lugar.
// Partes: estado() por ícone, anim/icone.frag no ícone, anim/deco.frag atrás dele e anim/camada.frag sobre a cerca.
Item {
    id: a
    property Item view: null              // o GridView
    property Item pasta: null             // o FolderView
    property string variante: "explosao"
    property color cor: Cores.destaque
    readonly property color _cor2: Qt.colorEqual(cor, Cores.secundaria) ? Cores.destaque : Cores.secundaria
    // a tóxica pede um tom saturado: a secundária, ou o alerta quando ela é quase branca (Arasaka, MooreTech…)
    readonly property color corToxica: _cor2.hslSaturation >= 0.45 && _cor2.hslLightness < 0.8 ? _cor2 : Cores.alerta
    readonly property color cor2: v.id === "explosao-toxica" ? corToxica : _cor2
    readonly property color corAlerta: Cores.alerta
    // o cartão atrás de cada ícone e o fio: alerta na explosão, a cor da cerca na limpa, a secundária na tóxica
    readonly property color corCartao: v.id === "explosao-limpa" ? cor : v.id === "explosao-toxica" ? corToxica : corAlerta
    readonly property int modoDeco: v.id === "explosao-toxica" ? 2 : 0
    property real velocidade: 1           // só para testes e prévias (> 1 = mais lento)
    enabled: false
    clip: true

    readonly property int maxIcones: 60
    readonly property int maxTotal: 1150
    readonly property bool _minimo: Cores.reduzir
    readonly property bool _reduzido: !_minimo && Cores.fator < 0.75
    readonly property var v: CatIcones.de(variante)
    readonly property string id_: _reduzido ? "dissolucao" : v.id
    readonly property bool desligada: _minimo || (v.id === "nenhuma")
    readonly property int modoShader: _reduzido ? -1 : v.modoShader
    readonly property int modoCamada: _reduzido || v.modoCamada === undefined ? -1 : v.modoCamada

    property bool ligado: false           // os delegates estão sob controle daqui
    property bool preparando: false       // escondidos, à espera do tocar()
    property bool saindo: false
    property real p: 0
    property int primeira: 0
    property int n: 0
    property int colunas: 1
    property real y0: 0
    // tempos da passada (ms)
    property real _pre: 0
    property real _d: 260
    property real _pos: 0
    property real _st: 0
    property real _T: 1

    readonly property var _oculto: ({ o: 0, ol: 0 })
    // ms: antes do 1º ícone, de cada ícone, depois do último, e a defasagem máxima entre vezes
    readonly property var _tempos: ({
        explosao: { pre: 200, d: 470, pos: 340, st: 8 }, "explosao-limpa": { pre: 170, d: 470, pos: 290, st: 8 },
        "explosao-toxica": { pre: 200, d: 470, pos: 340, st: 8 }, cascata: { d: 300, st: 40 },
        decodificar: { d: 300, st: 12 }, varredura: { d: 620, st: 0 }, montagem: { d: 320, st: 12 },
        glitch: { d: 320, st: 12 }, pixel: { d: 300, st: 12 }, quickhack: { d: 440, st: 12 },
        sandevistan: { d: 500, st: 10 }, braindance: { d: 900, st: 0 }, dissolucao: { d: 160, st: 0 }
    })

    function preparar() {
        if (desligada) return
        anda.stop(); adia.stop()
        preparando = true; ligado = true
        seguro.restart()
    }
    function _ajustar() {
        const g = view, cw = Math.max(1, g.cellWidth), ch = Math.max(1, g.cellHeight)
        let i0 = g.indexAt(g.contentX + 2, g.contentY + 2)
        if (i0 < 0) i0 = 0
        primeira = i0
        colunas = Math.max(1, Math.floor(g.width / cw))
        n = Math.min(g.count - i0, colunas * Math.ceil(g.height / ch + 1), maxIcones)
        y0 = g.contentY
        const c = _tempos[id_] || _tempos.cascata
        _pre = c.pre || 0; _d = c.d; _pos = c.pos || 0
        const passos = _chaves()
        _st = passos > 1 ? Math.min(c.st, Math.max(0, (maxTotal - _pre - _d - _pos) / (passos - 1))) : 0
        _T = _pre + _st * Math.max(0, passos - 1) + _d + _pos
    }
    function _chaves() {
        if (id_ === "cascata") return Math.ceil(n / colunas) + (colunas - 1) * 0.22
        return id_ === "varredura" || id_ === "braindance" ? 1 : n
    }
    function tocar(atraso) {
        if (desligada) { parar(); return }
        seguro.stop()
        adia.fn = _entrar; adia.interval = Math.max(1, atraso || 0); adia.restart()
    }
    function _entrar() {
        if (!view || view.count === 0) { parar(); return }
        anda.stop(); _ajustar()
        preparando = false; saindo = false; ligado = true; p = 0
        anda.rodar(1, _T * velocidade)
    }
    function sair(ms, atraso) {
        if (desligada || !view || view.count === 0) return
        adia.fn = () => {
            anda.stop(); seguro.stop(); _ajustar()
            preparando = false; saindo = true; ligado = true; p = 1
            anda.rodar(0, (ms || 300) * velocidade)
        }
        adia.interval = Math.max(1, atraso || 0); adia.restart()
    }
    function parar() {
        anda.stop(); adia.stop(); seguro.stop()
        preparando = false; saindo = false; ligado = false; p = 0
    }
    Timer { id: adia; property var fn: null; onTriggered: if (fn) fn() }
    Timer { id: seguro; interval: 3000; onTriggered: a.tocar(0) }   // nada veio tocar: nunca fica escondido
    // relógio por quadro: depois do repouso o relógio das animações do Qt pula centenas de ms, e o começo se perderia
    FrameAnimation {
        id: anda
        property real alvo: 1
        property real dur: 1
        function rodar(para, ms) { alvo = para; dur = Math.max(1, ms); restart() }
        onTriggered: {
            const d = Math.min(frameTime, 0.05) * 1000 / dur
            a.p = alvo > 0.5 ? Math.min(1, a.p + d) : Math.max(0, a.p - d)
            if (a.p !== alvo) return
            stop()
            if (alvo === 0) { a.saindo = false; a.preparando = true; seguro.restart() }   // saiu: segue escondido até a cerca sumir
            else a.ligado = false
        }
    }

    // estado do ícone "rank" (ordem entre os visíveis); (dx, dy) = do ícone até o centro da cerca
    function _hash(i) { let x = Math.sin(i * 127.1 + 3.3) * 43758.5453; return x - Math.floor(x) }
    function _lim(x) { return Math.max(0, Math.min(1, x)) }
    function estado(rank, dx, dy) {
        if (preparando) return _oculto
        if (rank < 0 || rank >= n) return null
        const t = p * _T
        const id = id_
        if (id === "dissolucao") return { o: Math.min(1, t / 160), ol: Math.min(1, t / 160) }
        if (id === "varredura") return _varredura(t, dy)
        if (id === "braindance") return _braindance(t, dy)
        const linha = Math.floor(rank / colunas), col = rank - linha * colunas
        const k = id === "cascata" ? linha + col * 0.22 : id === "montagem" || id === "glitch" || id === "pixel" ? rank : Math.floor(_hash(rank) * n)
        const ini = _pre + _st * k, q = _lim((t - ini) / _d)
        if (id === "explosao") return saindo ? _explosaoSai(rank) : _explosao(rank, dx, dy, t, ini, q)
        if (id === "explosao-limpa") return saindo ? _limpaSai(rank) : _limpa(rank, dx, dy, t, ini, q)
        if (id === "explosao-toxica") return saindo ? _toxicaSai(rank) : _toxica(rank, dx, dy, t, ini, q)
        if (id === "quickhack") return _quickhack(q)
        if (id === "sandevistan") return saindo ? _sandevistanSai(rank, linha) : _sandevistan(q, linha)
        const ol = _lim((q - 0.55) / 0.45), acesa = q > 0 ? 1 : 0
        if (id === "cascata") {
            // liga em degraus de ~30 ms, como um painel, em vez de um fade
            const o = q <= 0 ? 0 : q < 0.1 ? 0.7 : q < 0.2 ? 0.25 : 1, s = 1 - Math.pow(1 - q, 4)
            return { o: o, ol: ol, y: (1 - s) * -16, q: 1, flash: acesa * Math.pow(1 - q, 2) * 0.9 }
        }
        if (id === "glitch") {
            const dg = Math.floor(q * 5), j = (_hash(rank * 3 + dg) - 0.5) * [10, 6, 4, 2, 0, 0][dg]
            return { o: acesa, ol: ol, x: j, q: q, ab: q > 0 ? (5 - dg) * 0.7 : 0 }
        }
        if (id === "montagem") return { o: acesa, ol: ol, q: q, flash: q > 0.86 ? (1 - q) / 0.14 * 0.45 : 0 }
        if (id === "decodificar") return { o: acesa, ol: ol, q: q, flash: q > 0.7 ? (1 - q) / 0.3 * 0.35 : 0 }
        return { o: acesa, ol: ol, q: q }                  // pixel
    }

    function _explosao(rank, dx, dy, t, ini, q) {
        const s = 1 - Math.pow(1 - q, 2.2)                 // a curva medida do anel na referência
        const quadro = Math.floor(t / 33)
        const pisca = q >= 1 ? 1 : _hash(rank + quadro * 13) > 0.3 ? 1 : 0.45
        const a = t - ini - _d - _hash(rank + 7) * 80      // tempo no alerta, cada cartão com o seu atraso
        const degrau = a < 0 ? -1 : Math.floor(a / 33)
        const fl = a < 0 ? 0 : degrau < 6 ? [0.4, 0.1, 0.7, 0.3, 1, 0.9][degrau] : Math.max(0, 0.9 - (a - 198) / 60)
        const c = a < 198 ? 1 : Math.max(0, 1 - (a - 198) / 60)
        const dec = _lim((t - ini - _d - 40) / 220)
        const fio = q <= 0 ? 0 : Math.min(1, q * 5) * (a < 0 ? 1 : Math.max(0, 1 - Math.ceil(a / 33) / 4))
        return { o: q > 0 ? pisca : 0, x: dx * (1 - s), y: dy * (1 - s), c: q > 0 ? c * pisca : 0, fl: fl, fio: fio,
                 rasgo: q > 0 ? 1 - s : 0, q: q > 0 ? Math.min(1, q * 1.3) : 0, ab: q > 0 && q < 0.77 ? 3 * (1 - q) : 0,
                 ol: dec > 0 ? 1 : 0, dec: dec, quadro: quadro }
    }
    // a saída da referência: cada cartão acende no alerta e esmaga em fenda, no lugar
    function _explosaoSai(rank) {
        const v = _lim(((1 - p) - _hash(rank) * 0.35) / 0.65)
        return { o: v < 1 ? 1 : 0, sy: Math.max(0.04, 1 - v * v), c: v < 1 ? 1 : 0, fl: 1, fio: 0, rasgo: 0, q: 1,
                 ol: Math.max(0, 1 - v * 3), quadro: 0 }
    }

    // limpa: o mesmo voo, sem pisca, rasgo, alerta nem franjas; o cartão na cor da cerca só apaga
    function _limpa(rank, dx, dy, t, ini, q) {
        const s = 1 - Math.pow(1 - q, 2.2), a = t - ini - _d - _hash(rank + 7) * 60
        const dec = _lim((t - ini - _d - 40) / 220)
        return { o: q > 0 ? 1 : 0, x: dx * (1 - s), y: dy * (1 - s), c: q > 0 ? 0.75 * (a < 0 ? 1 : Math.max(0, 1 - a / 170)) : 0,
                 fl: 0, rasgo: 0, quadro: 0, fio: q <= 0 ? 0 : Math.min(1, q * 5) * 0.7 * (a < 0 ? 1 - s * 0.5 : Math.max(0, 0.5 - a / 200)),
                 ol: dec > 0 ? 1 : 0, dec: dec }
    }
    function _limpaSai(rank) {
        const v = _lim(((1 - p) - _hash(rank) * 0.35) / 0.65)
        return { o: v < 1 ? 1 : 0, sy: Math.max(0.04, 1 - v * v), c: v < 1 ? 0.75 : 0, fl: 0, fio: 0, rasgo: 0, quadro: 0,
                 ol: Math.max(0, 1 - v * 3) }
    }
    // tóxica: voam já contaminados; ao assentar, a corrosão come o cartão, as gotas escorrem e o ícone se limpa de cima
    function _toxica(rank, dx, dy, t, ini, q) {
        const s = 1 - Math.pow(1 - q, 2.2), a = t - ini - _d - _hash(rank + 7) * 80, limpo = a < 0 ? 0 : _lim(a / 240)
        const dec = _lim((t - ini - _d - 40) / 220)
        return { o: q > 0 ? 1 : 0, x: dx * (1 - s), y: dy * (1 - s), q: q > 0 ? limpo : 0,
                 c: q > 0 ? 1 - _lim((limpo - 0.6) / 0.4) : 0, fl: _lim(q * 1.6 - 0.2), rasgo: limpo, quadro: Math.floor(t / 47) + rank,
                 fio: q <= 0 ? 0 : Math.min(1, q * 5) * (a < 0 ? 1 : Math.max(0, 1 - a / 120)), ol: dec > 0 ? 1 : 0, dec: dec }
    }
    // a saída: o ícone recontamina e a corrosão o come no lugar, junto com o cartão
    function _toxicaSai(rank) {
        const v = _lim(((1 - p) - _hash(rank) * 0.35) / 0.65)
        return { o: v < 1 ? 1 : 0, q: 1 - _lim(v * 2.2), q2: 1 - _lim(v * 1.6 - 0.5), c: v < 1 ? 1 : 0, fl: 1, rasgo: _lim(v * 1.4 - 0.3),
                 quadro: Math.floor((1 - p) * 20) + rank, fio: 0, ol: Math.max(0, 1 - v * 3) }
    }

    // a posição da linha é global: o ícone se revela onde ela está, e não por conta própria
    function _topo(dy) { return view.height / 2 - dy - view.iconSize / 2 }
    function _varredura(t, dy) {
        const y = t / _T * (view.height + 8) - 4, topo = _topo(dy)
        const q = (y - topo) / view.iconSize
        return { o: q > 0 ? 1 : 0, ol: _lim((y - topo - view.iconSize) / 40), q: _lim(q) }
    }
    // duas bandas em sentidos opostos; o ícone se funde depois que as duas passaram, então a fusão abre do meio
    function _braindance(t, dy) {
        const Ts = _T - 260, L = view.height + 8, topo = _topo(dy), h = view.iconSize, f = t / Ts
        const qa = _lim((f * L - 4 - topo) / h), qb = _lim((topo + h - (view.height + 4 - f * L)) / h)
        const tc = Math.max((topo + h + 4) / L, (view.height + 4 - topo) / L) * Ts
        const m = Math.floor(_lim((t - tc) / 240) * 4) / 4
        return { o: qa > 0 || qb > 0 ? 1 : 0, ol: m, q: m, q2: qa, flash: qb }
    }
    // retícula trava em 3 degraus, a barra sobe em ritmo constante (ela mede algo), e o ícone acende
    function _quickhack(q) {
        const trava = q > 0 ? Math.ceil(_lim(q / 0.22) * 3) / 3 : 0, up = _lim((q - 0.24) / 0.46), h = _lim((q - 0.72) / 0.28)
        return { o: q > 0 ? 1 : 0, ol: h > 0 ? 1 : 0, dec: h, q: up, c: q > 0 ? 1 - _lim((h - 0.4) / 0.6) : 0, trava: trava, barra: up,
                 fl: 0, rasgo: 0, quadro: 0, flash: h > 0 ? Math.pow(1 - h, 1.5) : 0, ab: h > 0 ? (1 - h) * 3 : 0 }
    }
    // disparo, e o resto em câmera lenta com o rastro parado no ar; no fim o tempo volta e o rastro some
    function _sandX(u, dir) {
        const a = _lim(u / 0.24), b = _lim((u - 0.24) / 0.56), L = Math.min(90, view.width * 0.3)
        return -dir * (L * Math.pow(1 - a, 3) + 6 * (1 - b))
    }
    function _sandevistan(q, linha) {
        const dir = linha % 2 ? -1 : 1, volta = _lim((q - 0.8) / 0.2)
        const fat = Math.ceil(Math.max(0, 1 - _lim((q - 0.62) / 0.22)) * 4) / 4   // o rastro apaga em fatias
        const go = k => q > 0.06 * k ? fat * (0.75 - 0.15 * k) : 0
        const x = _sandX(q, dir)
        return { o: q > 0 ? 1 : 0, ol: volta, q: 1, x: x, flash: volta > 0 ? (1 - volta) * 0.6 : 0, ab: volta > 0 ? (1 - volta) * 3 : 0,
                 g: Qt.vector3d(_sandX(0.06, dir) - x, _sandX(0.12, dir) - x, _sandX(0.18, dir) - x), go: Qt.vector3d(go(1), go(2), go(3)) }
    }
    function _sandevistanSai(rank, linha) {
        const dir = linha % 2 ? -1 : 1, v = _lim(((1 - p) - _hash(rank) * 0.3) / 0.7), L = Math.min(110, view.width * 0.35)
        const x = u => dir * L * Math.pow(u, 2.4), o = 0.6 * (1 - v), aqui = x(v)
        return { o: v < 0.92 ? 1 : 0, ol: Math.max(0, 1 - v * 3), q: 1, x: aqui,
                 g: Qt.vector3d(x(v * 0.78) - aqui, x(v * 0.56) - aqui, x(v * 0.34) - aqui), go: Qt.vector3d(o, o * 0.75, o * 0.5) }
    }

    // o que é da cerca inteira, num quad só (anim/camada.frag)
    ShaderEffect {
        anchors.fill: parent
        visible: a.ligado && !a.preparando && a.modoCamada >= 0 && (!a.saindo || a.modoCamada === 0 || a.modoCamada >= 4)
        readonly property size tam: Qt.size(width, height)
        readonly property real t: a.p * a._T
        readonly property real total: a._T
        readonly property real pre: a._pre
        readonly property real d: a._d
        readonly property real sai: a.saindo ? Math.max(0.001, 1 - a.p) : 0
        readonly property real modo: a.modoCamada
        readonly property color cor: a.cor
        readonly property color cor2: a.cor2
        readonly property color texto: Cores.texto
        fragmentShader: Qt.resolvedUrl("anim/camada.frag.qsb")
    }

    // pasta nova (entrar numa pasta, trocar de aba): esconde agora, toca quando a listagem termina
    property bool _aguarda: false
    readonly property bool _ehCerca: !!pasta && typeof root !== "undefined" && !!root.camada && root.camada.view === pasta
    Connections {
        target: a.pasta
        function onUrlChanged() { if (a._ehCerca && a._listou) { a.preparar(); a._aguarda = true } }
        function onStatusChanged() {
            if (a.pasta.status !== Folder.FolderModel.Ready) return
            a._listou = true
            if (a._aguarda) { a._aguarda = false; a.tocar(40) }
        }
    }
    property bool _listou: false
}
