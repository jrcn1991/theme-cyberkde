import QtQuick

// Uma fase do tema: nome, código, descrição, interruptor; selo SUDO quando precisa de senha.
Item {
    id: c
    // montagem (ver Cascata): moldura traçada, superfície, conteúdo acendendo, flash da borda
    property real traco: 1
    property real superficie: 1
    property real acender: 1
    property real realce: 0
    property var fase: ({})
    property int numero: 0
    property bool esperando: false      // clicado, aguardando o CLI confirmar
    property bool pedidoLigar: false
    readonly property bool naFila: painel.alvo === fase.id || painel.alvosNaFila.indexOf(fase.id) >= 0
    readonly property bool rodando: painel.alvo === fase.id
    readonly property var ligadaVisual: esperando ? pedidoLigar : fase.ligada
    readonly property bool _on: ligadaVisual === true

    implicitHeight: Math.max(100, col.implicitHeight + 30)

    Connections {
        target: painel
        function onFasesMudou() { if (!c.naFila) c.esperando = false }
        function onOperacaoTerminou(nome, codigo) { if (codigo !== 0 && codigo !== 4 && !c.naFila) c.esperando = false }
    }

    Chanfro {
        anchors.fill: parent
        traco: c.traco; superficie: c.superficie; realce: c.realce
        corte: Tema.chanfro + 2
        preenchimento: hover.hovered ? Tema.alfa(Tema.elevado, 0.95) : Tema.alfa(Tema.painel, 0.92)
        borda: c._on ? Tema.alfa(Tema.destaque, 0.55) : Tema.linha
        Behavior on preenchimento { ColorAnimation { duration: Tema.micro } }
        Behavior on borda { ColorAnimation { duration: Tema.rapido } }
    }
    Rectangle {
        x: 0; y: 14; width: Tema.marcador
        height: c._on ? 30 : 0
        color: Tema.destaque
        Behavior on height { NumberAnimation { duration: Tema.rapido; easing.type: Easing.OutCubic } }
    }
    HoverHandler { id: hover }

    Column {
        id: col
        x: 18; y: 14
        width: parent.width - 36 - chave.width - 12
        spacing: 6
        Row {
            spacing: 8
            Codigo { text: "PH-" + ("0" + c.numero).slice(-2) + " // " + c.fase.id; color: c._on ? Tema.destaque : Tema.texto3 }
            Rectangle {
                visible: c.fase.opcional === true
                width: opTx.implicitWidth + 10; height: 14
                color: "transparent"; border.color: Tema.secundaria; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Codigo { id: opTx; anchors.centerIn: parent; text: Txt.t("fase.selo.opcional"); tamanho: 8; color: Tema.secundaria }
            }
            Rectangle {
                visible: c.fase.precisaSudo === true
                width: sudoTx.implicitWidth + 10; height: 14
                color: "transparent"; border.color: Tema.alerta; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Codigo { id: sudoTx; anchors.centerIn: parent; text: Txt.t("fase.selo.sudo"); tamanho: 8; color: Tema.alerta }
            }
        }
        Rotulo { text: c.fase.nome || c.fase.id; tamanho: 19; color: Tema.texto; width: parent.width; elide: Text.ElideRight }
        Leitura { text: c.fase.descricao || ""; width: parent.width; tamanho: 12 }
    }

    Interruptor {
        id: chave
        anchors.right: parent.right; anchors.rightMargin: 16
        y: 16
        ligado: c.ligadaVisual
        ocupado: c.naFila
        habilitado: !c.naFila && c.fase.disponivel !== false
        onAlternado: (novo) => {
            if (!novo && (!painel.suporteFases || !painel.registroPorFase)) {
                avisoSemSuporte.restart()
                return
            }
            c.esperando = true
            c.pedidoLigar = novo
            painel.alternarFase(c.fase.id, novo)
        }
    }
    Codigo {
        id: estado
        anchors.right: chave.right
        anchors.top: chave.bottom; anchors.topMargin: 6
        tamanho: 9
        text: c.verificando ? (c._pisca ? Txt.t("fase.estado.verificando") : "") : c.rodando ? Txt.t("fase.estado.processando") : c.naFila ? Txt.t("fase.estado.fila") : c.fase.disponivel === false ? Txt.t("fase.estado.indisponivel") : (c.fase.ligada === true ? Txt.t("fase.estado.ativa") : c.fase.ligada === false ? Txt.t("fase.estado.inativa") : Txt.t("fase.estado.desconhecido"))
        color: c.verificando ? Tema.secundaria : c.naFila ? Tema.secundaria : (c.fase.ligada === true ? Tema.destaque : Tema.texto3)
    }

    // status real em sequência (A17): ao entrar na seção, cada cartão mostra "VERIFICANDO" piscando e
    // depois o estado verdadeiro, 60 ms depois do anterior
    property bool entrando: false
    property int ordemStatus: 0
    property bool verificando: false
    property bool _pisca: true
    onEntrandoChanged: if (entrando && !Tema.reduzir) { verificando = true; _pisca = true; fimVerif.restart(); piscaVerif.restart() }
    Timer { id: fimVerif; interval: 380 + c.ordemStatus * 60; onTriggered: { c.verificando = false; piscaVerif.stop() } }
    Timer { id: piscaVerif; interval: 120; repeat: true; onTriggered: c._pisca = !c._pisca }
    Leitura {
        id: semSuporte
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.top: estado.bottom; anchors.topMargin: 4
        width: 150
        horizontalAlignment: Text.AlignRight
        tamanho: 10
        color: Tema.alerta
        text: painel.suporteFases ? Txt.t("fase.registroAntigo") : Txt.t("fase.semSuporteOff")
        opacity: 0
        SequentialAnimation {
            id: avisoSemSuporte
            NumberAnimation { target: semSuporte; property: "opacity"; to: 1; duration: Tema.rapido }
            PauseAnimation { duration: 2600 }
            NumberAnimation { target: semSuporte; property: "opacity"; to: 0; duration: Tema.padrao }
        }
    }

    // progresso desta fase (quando é ela que está rodando)
    BarraSegmentada {
        visible: c.rodando
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        height: 4
        larguraSeg: 4; vao: 2
        readonly property var p: painel.progresso
        valor: p.total > 0 ? p.feitas / p.total : 0
        indeterminado: !(p.total > 0)
    }

    // máscara do conteúdo durante a montagem (o conteúdo "acende" com flicker)
    Chanfro {
        visible: c.acender < 1
        z: 50
        anchors.fill: parent
        anchors.margins: 1
        corte: Tema.chanfro + 2
        preenchimento: Tema.base
        espessura: 0
        opacity: 1 - c.acender
    }
    QuadradosMontagem { z: 51; progresso: c.traco; n: 4 }
}
