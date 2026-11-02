import QtQuick
import QtQuick.Effects
import "comum"

// A grade FUI da referência ("Cyberpunk 2077 UI Art"): quatro faixas de 172 com passo de 187 e as colunas
// medidas no desenho, em unidades de 866×732. NÃO há escala por transformação: o fator da tela "k" entra
// nos tamanhos de cada módulo, e tudo é desenhado em pixel inteiro, na resolução nativa. A grade fica
// centrada no espaço. Os módulos são os mesmos dos widgets avulsos (org.cyberkde.fui-*): M*.qml.
// Movimento: montagem de entrada por faixas; glitch (fatias com eco na secundária e depois barras
// verticais faixa a faixa) só na hora cheia ou a cada N minutos. Com o movimento "mínimo", nada disso.
Item {
    id: p
    property var d
    property string slot2: "log"          // o módulo da faixa 1 ao lado dos núcleos: "log" ou "sistema"
    readonly property real k: Math.max(0.3, Math.min(width / 866, height / 732))
    readonly property int ox: Math.round((width - 866 * k) / 2)
    readonly property int oy: Math.round((height - 732 * k) / 2)
    function u(v) { return Math.round(v * k) }

    // ---------------------------------------------------------------- montagem
    property real montagem: 1
    function montar() {
        anim.stop()
        if (Cores.reduzir) { montagem = 1; return }
        montagem = 0
        anim.start()
    }
    NumberAnimation { id: anim; target: p; property: "montagem"; from: 0; to: 1; duration: Cores.d(1300) }
    function m(linha, coluna) { return Math.max(0, Math.min(1, (p.montagem - linha * 0.11 - coluna * 0.045) / 0.5)) }

    // ---------------------------------------------------------------- glitch
    property bool fatiando: false
    property real sem: 0
    function glitch() {
        if (Cores.reduzir || !visible) return
        sem = Math.random()
        fatiando = true
        fimFatias.restart()
    }
    Timer { id: fimFatias; interval: Cores.d(320); onTriggered: { p.fatiando = false; varre.linha = 0; varre.start() } }
    Timer {
        id: varre
        property int linha: 0
        interval: Cores.d(150); repeat: true
        onTriggered: {
            for (const x of p.linhas[linha]) if (x && x.visible) x.glitch(Cores.d(200))
            if (++linha >= 4) stop()
        }
    }
    readonly property var linhas: [[mNuc, mLog, mSis, mSens], [mCpu, mSt1, mProc, mGpu, mSt2, mDiscos],
                                   [mHora, mClima, mMem], [mTraf, mRx, mRede, mIo, mES]]

    Item {
        id: palco
        anchors.fill: parent
        // FAIXA 1
        MNucleos  { id: mNuc;  d: p.d; k: p.k; montado: p.m(0, 0); visible: !p.d.oculto("bandas");   x: p.ox + p.u(6);   y: p.oy;            width: p.u(349) }
        MLog      { id: mLog;  d: p.d; k: p.k; montado: p.m(0, 1); visible: p.slot2 !== "sistema" && !p.d.oculto("log"); x: p.ox + p.u(385); y: p.oy; width: p.u(181) }
        MSistema  { id: mSis;  d: p.d; k: p.k; montado: p.m(0, 1); visible: p.slot2 === "sistema" && !p.d.oculto("log"); x: p.ox + p.u(385); y: p.oy; width: p.u(181) }
        MSensores { id: mSens; d: p.d; k: p.k; montado: p.m(0, 2); visible: !p.d.oculto("canais");   x: p.ox + p.u(589); y: p.oy;            width: p.u(270) }
        // FAIXA 2
        MCpu      { id: mCpu;  d: p.d; k: p.k; montado: p.m(1, 0); visible: !p.d.oculto("cpu");      x: p.ox + p.u(6);   y: p.oy + p.u(187); width: p.u(116) }
        MEstados  { id: mSt1;  d: p.d; k: p.k; montado: p.m(1, 1); visible: !p.d.oculto("estados");  x: p.ox + p.u(141); y: p.oy + p.u(187); width: p.u(36); grupo: 1 }
        MProcessos{ id: mProc; d: p.d; k: p.k; montado: p.m(1, 2); visible: !p.d.oculto("processos");x: p.ox + p.u(195); y: p.oy + p.u(187); width: p.u(239) }
        MGpu      { id: mGpu;  d: p.d; k: p.k; montado: p.m(1, 3); visible: !p.d.oculto("anel");     x: p.ox + p.u(453); y: p.oy + p.u(187); width: p.u(99) }
        MEstados  { id: mSt2;  d: p.d; k: p.k; montado: p.m(1, 4); visible: !p.d.oculto("estados");  x: p.ox + p.u(567); y: p.oy + p.u(187); width: p.u(36); grupo: 2 }
        MDiscos   { id: mDiscos; d: p.d; k: p.k; montado: p.m(1, 5); visible: !p.d.oculto("discos"); x: p.ox + p.u(620); y: p.oy + p.u(187); width: p.u(239) }
        // FAIXA 3
        MHora     { id: mHora; d: p.d; k: p.k; montado: p.m(2, 0); visible: !p.d.oculto("relogio");  x: p.ox + p.u(6);   y: p.oy + p.u(374); width: p.u(349) }
        MClima    { id: mClima; d: p.d; k: p.k; montado: p.m(2, 1); visible: !p.d.oculto("clima");   x: p.ox + p.u(385); y: p.oy + p.u(374); width: p.u(181) }
        MMemoria  { id: mMem;  d: p.d; k: p.k; montado: p.m(2, 2); visible: !p.d.oculto("memoria");  x: p.ox + p.u(587); y: p.oy + p.u(374); width: p.u(273) }
        // FAIXA 4
        MTrafego  { id: mTraf; d: p.d; k: p.k; montado: p.m(3, 0); visible: !p.d.oculto("sinal");    x: p.ox + p.u(6);   y: p.oy + p.u(561); width: p.u(116) }
        MRuido    { id: mRx;   d: p.d; k: p.k; montado: p.m(3, 1); visible: !p.d.oculto("ruido");    x: p.ox + p.u(141); y: p.oy + p.u(561); width: p.u(36); tipo: "rx" }
        MRede     { id: mRede; d: p.d; k: p.k; montado: p.m(3, 2); visible: !p.d.oculto("rede");     x: p.ox + p.u(194); y: p.oy + p.u(561); width: p.u(358) }
        MRuido    { id: mIo;   d: p.d; k: p.k; montado: p.m(3, 3); visible: !p.d.oculto("ruido");    x: p.ox + p.u(567); y: p.oy + p.u(561); width: p.u(36); tipo: "io" }
        MES       { id: mES;   d: p.d; k: p.k; montado: p.m(3, 4); visible: !p.d.oculto("es");       x: p.ox + p.u(619); y: p.oy + p.u(561); width: p.u(240) }
    }

    // ---------------------------------------------------------------- fatias do glitch (cópias do palco)
    Repeater {
        model: p.fatiando ? 9 : 0
        Item {
            required property int index
            readonly property real r: Math.abs(Math.sin((index + 3) * 91.3 + p.sem * 47.1) * 4375.85) % 1
            readonly property int h0: Math.ceil(p.height / 9)
            y: index * h0; width: p.width; height: h0
            clip: true
            ShaderEffectSource {
                id: eco
                sourceItem: palco; hideSource: true; live: false
                sourceRect: Qt.rect(0, parent.y, p.width, parent.height)
                width: p.width; height: parent.height
                x: Math.round((parent.r - 0.5) * (parent.r > 0.55 ? 46 : 8) * p.k)
                visible: false
            }
            MultiEffect {
                source: eco; width: eco.width; height: eco.height
                x: eco.x + Math.round((4 + parent.r * 6) * p.k)
                colorization: 1; colorizationColor: Cores.secundaria
                opacity: 0.55
            }
            MultiEffect { source: eco; width: eco.width; height: eco.height; x: eco.x }
        }
    }
}
