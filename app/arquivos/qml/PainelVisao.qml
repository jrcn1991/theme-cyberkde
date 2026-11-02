import QtQuick
import "../../qml"

// Um painel de visão (PILHAS, LISTA ou GRADE) de uma Aba: moldura, linha de título ("MODEL LINE"),
// palco com a visão, estado vazio/erro e a transição entre pastas (seção 12). Na TELA DIVIDIDA (F3,
// spec 20) há dois, um por lado; clicar em qualquer ponto de um painel o torna o ATIVO
// (arquivos.ladoAtivo), e arquivos.aba passa a ser a aba dele (operações, LOG e busca seguem o foco).
FocusScope {
    id: pv
    property var aba: null
    property string lado: "esquerdo"
    property bool ativo: true
    property bool dividido: false
    readonly property var visao: carregador.item
    readonly property bool focado: areaFoco.activeFocus
    function focar() { areaFoco.forceActiveFocus() }
    // rowCount() não avisa quando muda: a contagem é relida a cada leitura da pasta
    property int _rev: 0
    readonly property int nItens: (_rev, aba ? aba.modelo.rowCount() : 0)
    Connections { target: pv.aba; function onCarregou() { pv._rev++ } }

    Item {
        id: areaFoco
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => { if (pv.ativo && pv.visao && Ds.janela.tecla(e)) e.accepted = true }
    }
    // moldura da área (traço da montagem); o painel ativo fica mais aceso
    Chanfro {
        anchors.fill: parent
        corte: Tema.chanfroG
        preenchimento: Tema.alfa(Tema.painel, 0.35)
        borda: Tema.alfa(pv.dividido && pv.ativo ? Tema.secundaria : Tema.destaque, areaFoco.activeFocus || (pv.dividido && pv.ativo) ? 0.65 : 0.3)
        espessura: pv.dividido && pv.ativo ? 2 : 1
    }
    // linha de título da área, como "MODEL LINE 12.10A" da referência
    Row {
        x: 16; y: 8
        spacing: 12
        Codigo { visible: pv.dividido; text: (pv.lado === "esquerdo" ? "◧ " : "◨ ") + Ds.t("div." + pv.lado); tamanho: 9; color: pv.ativo ? Tema.secundaria : Tema.texto3 }
        Codigo { text: "MODEL LINE"; tamanho: 9; color: Tema.destaque }
        Codigo { text: pv.aba ? pv.aba.codigo.slice(2) + "A" : ""; tamanho: 9; color: Tema.destaque }
        Codigo { visible: pv.dividido && !!pv.aba; text: pv.aba ? pv.aba.titulo : ""; tamanho: 9; color: Tema.texto2 }
        Codigo { visible: !!pv.aba && pv.aba.filtro !== ""; text: "FILTER // " + (pv.aba ? pv.aba.filtro : ""); tamanho: 9; color: Tema.secundaria }
        Codigo { visible: !!pv.aba && pv.aba.modoBusca; text: Ds.t("busca.resultados", { q: pv.aba ? pv.aba.textoBusca : "", n: pv.aba ? pv.aba.modelo.rowCount() : 0 }) + " · " + Ds.t("busca.sair"); tamanho: 9; color: Tema.secundaria }
        Codigo { visible: arquivos.zoom !== 100; text: "ZOOM " + arquivos.zoom + "%"; tamanho: 9; color: Tema.texto3 }
    }
    // atalhos da visão (barra de atalhos): por visão, e com seleção os que agem nela (U19)
    Codigo {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 7
        visible: !!pv.aba && !pv.aba.modoBusca && pv.width > 760 && pv.ativo
        text: !pv.aba ? "" : pv.aba.qtdSelecionados > 0 && pv.aba.visao !== "pilhas" ? Ds.t("dicas.sel")
              : pv.aba.visao === "pilhas" ? Ds.t("atalhos.pilhas") : Ds.t("dicas.lista")
        tamanho: 10; color: Tema.texto2
        elide: Text.ElideLeft; width: Math.min(implicitWidth, pv.width * 0.55)
    }
    Rectangle { x: 16; y: 24; width: parent.width - 32; height: 1; color: Tema.alfa(Tema.destaque, 0.6) }

    // lixeira: faixa de ação acima da lista (U15)
    Item {
        id: faixaLixo
        visible: !!pv.aba && pv.aba.ehLixeira
        x: 12; y: 30; width: parent.width - 24; height: visible ? 34 : 0
        Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.alfa(Tema.alerta, 0.10); borda: Tema.alfa(Tema.alerta, 0.6) }
        Rotulo { x: 12; anchors.verticalCenter: parent.verticalCenter; text: Ds.t("lix.faixa", { n: pv.nItens }); tamanho: 13; color: Tema.alerta }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Botao { text: Ds.t("lix.restaurar"); tipo: "sutil"; tamanho: 11; habilitado: !!pv.aba && pv.aba.qtdSelecionados > 0; onClicado: arquivos.restaurar(pv.aba.selecionados) }
            Botao { text: Ds.t("lix.esvaziar"); tipo: "primario"; cor: Tema.alerta; tamanho: 11; habilitado: pv.nItens > 0; onClicado: Ds.janela.esvaziar() }
        }
    }

    Item {
        id: palco
        x: 4; y: 28 + (faixaLixo.visible ? faixaLixo.height + 6 : 0)
        width: parent.width - 8; height: parent.height - y - 4
        clip: true
        property real desloc: 0
        transform: Translate { x: palco.desloc }
        Loader {
            id: carregador
            anchors.fill: parent
            sourceComponent: !pv.aba ? null : pv.aba.visao === "lista" ? cLista : pv.aba.visao === "grade" ? cGrade : cPilhas
            onLoaded: item.aba = Qt.binding(() => pv.aba)
        }
        Component { id: cPilhas; VisaoPilhas {} }
        Component { id: cLista; VisaoLista {} }
        Component { id: cGrade; VisaoGrade {} }

        // vazio / erro
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: !!pv.aba && !pv.aba.carregando && pv.aba.modelo.rowCount() === 0 && !(pv.visao && pv.visao.leque) && pv.aba.grupos.length === 0
            CelulaLosango { width: 90; height: 90; anchors.horizontalCenter: parent.horizontalCenter; cor: pv.aba && pv.aba.erro ? Tema.alerta : Tema.destaque }
            Rotulo {
                anchors.horizontalCenter: parent.horizontalCenter; tamanho: 18
                color: pv.aba && pv.aba.erro ? Tema.alerta : Tema.texto2
                text: pv.aba && pv.aba.erro ? Ds.t("erro.leitura") : pv.aba && pv.aba.filtro ? Ds.t("vazio.filtro", { f: pv.aba.filtro }) : Ds.t("vazio.pasta")
            }
            Text { visible: !!pv.aba && !!pv.aba.erro; anchors.horizontalCenter: parent.horizontalCenter; text: pv.aba ? pv.aba.erro : ""; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto2 }
            // pasta vazia: o que dá para fazer (U24)
            Text { visible: !!pv.aba && !pv.aba.erro && !pv.aba.filtro && !pv.aba.ehLixeira && !pv.aba.ehRecentes; anchors.horizontalCenter: parent.horizontalCenter; text: Ds.t("vazio.acoes"); font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto2 }
        }
    }
    QuadradosMontagem { id: quadrados; progresso: 1; n: 7 }

    // qualquer clique (ou toque) no painel o ativa, sem roubar o clique dos itens (pega só passiva)
    Item {
        anchors.fill: parent
        z: 100
        PointHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onActiveChanged: if (active && pv.dividido && !pv.ativo) arquivos.ladoAtivo = pv.lado
        }
    }

    // ---- transição entre pastas: a visão antiga sai (fade + 8 px), varre, a nova monta
    property int _sentido: 1
    // trocar de aba no meio de uma transição deixava o palco apagado (a "entrada" era da aba anterior)
    onAbaChanged: { sai.stop(); if (Tema.reduzir) { palco.opacity = 1; palco.desloc = 0 } else entra.restart() }
    Connections {
        target: pv.aba
        function onNavegou(direcao) {
            pv._sentido = (direcao === "voltar" || direcao === "subir") ? -1 : 1
            Ds.janela.renomeando = ""
            if (Tema.reduzir) return
            sai.restart()
            Ds.janela.passarVarredura()
        }
        function onCarregou() {
            if (Tema.reduzir) { palco.opacity = 1; palco.desloc = 0; return }
            entra.restart()
            quadrados.progresso = 0; montaQ.restart()
        }
    }
    ParallelAnimation {
        id: sai
        NumberAnimation { target: palco; property: "opacity"; to: 0; duration: 120 }
        NumberAnimation { target: palco; property: "desloc"; to: -8 * pv._sentido; duration: 120 }
    }
    ParallelAnimation {
        id: entra
        NumberAnimation { target: palco; property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { target: palco; property: "desloc"; from: 8 * pv._sentido; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }
    NumberAnimation { id: montaQ; target: quadrados; property: "progresso"; from: 0; to: 1; duration: 420 }
}
