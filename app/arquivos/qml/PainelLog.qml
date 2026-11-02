import QtQuick
import "../../qml"

// Painel LOG // DETALHES (coluna direita da referência "Lista de Projetos Pessoais"): ao mudar o item,
// limpa e escreve as linhas de arquivos.detalhes() uma a uma (~35 ms por linha), cada uma com um
// cursor ▌ que decodifica 2–3 quadros antes do texto assentar. Rótulos em mono (decorativo), valores
// na fonte do sistema (informação). Embaixo, a prévia pequena e, em pasta, o tamanho recursivo.
// Leitura viva (referência 11): a barra SCAN enche conforme as linhas se escrevem e dá um pulso ao
// terminar; um filete de varredura acompanha a linha que está sendo escrita; cada valor cintila uma vez
// (2 quadros, sem se mover) ao assentar. Nada em laço: tudo acontece só enquanto o LOG se escreve.
// Movimento "reduzido": escreve, sem filete nem cintilação; "mínimo": aparece pronto.
Item {
    id: g
    property var dados: null            // {linhas:[{rotulo, valor}], miniatura, iconeUrl, ehPasta, caminho, codigo}
    property string extra: ""           // tamanho recursivo (propriedadesProntas)
    property bool carregando: false
    property var _escritas: []
    property int _n: 0                  // linhas já escritas
    property int _quadro: 0             // decodificação da linha atual (0..3)
    readonly property var linhas: Ds.linhasDe(dados)
    readonly property bool completo: !Tema.reduzir && arquivos.movimento === "completo"
    property real _yEscrita: 0          // y (em "col") da linha sendo escrita: o filete de leitura

    onDadosChanged: reescrever()
    function reescrever() {
        escrita.stop()
        _quadro = 0
        // (lê de "dados" direto: a propriedade "linhas" pode ainda não ter se atualizado aqui)
        const total = dados && dados.linhas ? dados.linhas.length : 0
        if (Tema.reduzir || arquivos.movimento === "minimo") { _n = total; return }
        _n = 0
        if (total) escrita.start()
    }
    readonly property alias escritaT: escrita
    Timer {
        id: escrita
        interval: 12; repeat: true
        onTriggered: {
            g._quadro++
            if (g._quadro >= 3) { g._quadro = 0; g._n++ }
            if (g._n >= g.linhas.length) { stop(); scan.pulsar() }
        }
    }
    readonly property string _ruido: "▚▞#/\\<>[]_=+*01ΞΔ"
    function embaralhar(s) {
        let o = ""
        for (let i = 0; i < Math.min(s.length, 22); i++) o += _ruido[Math.floor(Math.random() * _ruido.length)]
        return o
    }

    // cabeçalho
    Row {
        id: cab
        spacing: 12
        Rotulo { text: Ds.t("log.titulo"); tamanho: 14; color: Tema.destaque }
        Codigo { anchors.verticalCenter: parent.verticalCenter; text: g.dados && g.dados.codigo ? "MODEL LINE " + g.dados.codigo.slice(2) : "MODEL LINE --"; tamanho: 9 }
    }
    Rectangle { y: cab.height + 6; width: parent.width; height: 2; color: Tema.destaque }
    // barra de leitura: enche com as linhas escritas, pulsa ao terminar
    Row {
        id: linhaScan
        anchors.right: parent.right
        y: cab.height + 11
        spacing: 6
        visible: g.linhas.length > 0
        Codigo {
            anchors.verticalCenter: parent.verticalCenter
            text: "SCAN " + String(Math.min(g._n, g.linhas.length)).padStart(2, "0") + "/" + String(g.linhas.length).padStart(2, "0")
            tamanho: 8; color: g._n >= g.linhas.length ? Tema.texto3 : Tema.secundaria
        }
        BarraPulso {
            id: scan
            anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 5
            larguraSeg: 3; vao: 1
            valor: g.linhas.length ? Math.min(1, g._n / g.linhas.length) : 0
            cor: Tema.destaque
        }
    }

    Column {
        id: col
        y: cab.height + 32          // (a linha do SCAN fica sempre reservada: o texto não pula)
        width: parent.width
        spacing: 3
        // linhas de "boot" decorativas (baixo contraste, micro)
        Codigo { width: parent.width; tamanho: 8; text: "[ 0.000" + (g.dados && g.dados.codigo ? g.dados.codigo.slice(-3) : "000") + "] SHARD.LINK: MOUNT " + (g.dados && g.dados.codigo ? g.dados.codigo : "--"); elide: Text.ElideRight }
        Codigo { width: parent.width; tamanho: 8; text: "[ 0.01" + (g._n % 10) + "88] DMA: ASSIGNED REGION " + (g.linhas.length * 1024) + " B"; elide: Text.ElideRight }
        Item { width: 1; height: 6 }
        Text {
            visible: !g.dados && !g.carregando
            text: Ds.t("log.vazio"); font.family: Tema.fMono; font.pixelSize: 12; color: Tema.texto3
        }
        Text {
            visible: g.carregando
            text: Ds.t("log.carregando"); font.family: Tema.fMono; font.pixelSize: 12; color: Tema.secundaria
        }
        Repeater {
            model: g.linhas
            Item {
                id: ln
                required property int index
                required property var modelData
                readonly property bool escrita: index < g._n
                readonly property bool escrevendo: index === g._n
                onEscrevendoChanged: if (escrevendo) g._yEscrita = Qt.binding(() => ln.y + ln.height)
                // o valor cintila uma vez ao assentar (dois quadros de opacidade; nada se move)
                onEscritaChanged: if (escrita && g.completo && g.escritaT.running) cintila.restart()
                SequentialAnimation {
                    id: cintila
                    PropertyAction { target: val; property: "opacity"; value: 0.35 }
                    PauseAnimation { duration: 33 }
                    PropertyAction { target: val; property: "opacity"; value: 0.8 }
                    PauseAnimation { duration: 33 }
                    PropertyAction { target: val; property: "opacity"; value: 1 }
                }
                width: col.width
                height: Math.max(rot.implicitHeight, val.implicitHeight) + 2
                visible: escrita || escrevendo
                Text {
                    id: rot
                    width: Math.min(150, col.width * 0.42)
                    text: "> " + ln.modelData.rotulo + " " + ".".repeat(Math.max(2, 16 - ln.modelData.rotulo.length))
                    font.family: Tema.fMono; font.pixelSize: 11
                    color: Tema.texto3
                    elide: Text.ElideRight
                }
                Text {
                    id: val
                    x: rot.width + 4
                    width: col.width - x
                    text: ln.escrita ? ln.modelData.valor : (g.embaralhar(ln.modelData.valor) + "▌")
                    font.family: ln.escrita ? Tema.fTexto : Tema.fMono; font.pixelSize: 12
                    color: ln.escrita ? Tema.texto : Tema.secundaria
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
        Text {
            visible: g.extra !== "" && g._n >= g.linhas.length
            text: "> " + g.extra; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.secundaria
        }
        Text {
            visible: !!g.dados && g._n >= g.linhas.length && g.linhas.length > 0
            text: "DONE_"; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.destaque
        }
        // etiquetas, estrelas e comentário (um item ou a seleção inteira; não na lixeira)
        Item { width: 1; height: 4; visible: meta.visible }
        Metadados {
            id: meta
            visible: !!g.dados && !!g.dados.meta && g._n >= g.linhas.length
            width: col.width
            compacto: true
            caminhos: g.dados && g.dados.meta ? g.dados.meta.caminhos : []
            tags: g.dados && g.dados.meta ? g.dados.meta.tags : []
            avaliacao: g.dados && g.dados.meta ? g.dados.meta.avaliacao : 0
            comentario: g.dados && g.dados.meta ? g.dados.meta.comentario : ""
        }
    }

    // filete de varredura de leitura: acompanha a linha sendo escrita (só enquanto escreve)
    Rectangle {
        visible: g.completo && escrita.running
        x: 0; width: parent.width; height: 1
        y: col.y + g._yEscrita + 1
        Behavior on y { NumberAnimation { duration: 30 } }
        color: Tema.alfa(Tema.secundaria, 0.8)
        Rectangle {
            anchors.bottom: parent.top; width: parent.width; height: 14
            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Tema.alfa(Tema.secundaria, 0.12) } }
        }
    }

    // prévia pequena
    Item {
        id: prev
        visible: !!g.dados && g._n >= g.linhas.length && (!!g.dados.miniatura || !!g.dados.iconeUrl)
        y: col.y + col.implicitHeight + 16
        width: parent.width; height: Math.min(170, Math.max(0, g.height - y - 40))
        Chanfro { anchors.fill: parent; corte: 8; preenchimento: Tema.alfa(Tema.fundo, 0.6); borda: Tema.alfa(Tema.destaque, 0.4) }
        Image {
            id: mini
            anchors.fill: parent; anchors.margins: 6
            fillMode: Image.PreserveAspectFit
            source: g.dados && g.dados.miniatura ? g.dados.miniatura : ""
            sourceSize.width: 400
            asynchronous: true
            // miniatura que falha (ou vem vazia) cai no ícone do tipo (U16)
            readonly property bool ok: status === Image.Ready && implicitWidth > 1
            visible: ok
        }
        Icone {
            anchors.centerIn: parent
            width: 56; height: 56
            visible: !mini.ok && !!g.dados
            fonte: g.dados ? (g.dados.iconeUrl || "") : ""
            cor: Tema.destaque
        }
    }

    // rodapé do LOG
    Rectangle { anchors.bottom: rodLog.top; anchors.bottomMargin: 6; width: parent.width; height: 2; color: Tema.destaque }
    Codigo { id: rodLog; anchors.bottom: parent.bottom; text: "TRK.TLCAS " + (g.dados && g.dados.codigo ? g.dados.codigo.slice(2) : "000000"); tamanho: 9; color: Tema.destaque }
}
