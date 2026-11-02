import QtQuick
import "../../qml"

// Barra de comando: voltar / avançar / subir; BREADCRUMB DE CÓDIGO (/SHARD:HOME/0x1A_Documentos/…;
// clique num segmento navega; clique no vazio ou Ctrl+L troca para o campo com o caminho real); busca
// (digitar filtra a pasta; Enter faz a busca recursiva; Esc sai); seletor PILHAS | LISTA | GRADE;
// atalhos do LOG e dos Locais.
Item {
    id: b
    height: 40
    property var aba: arquivos.aba
    property bool editando: false
    function editarCaminho() { editando = true; campo.text = aba.caminho; campo.forceActiveFocus(); campo.selectAll(); sug.lista = [] }
    function focarBusca() { modoFiltro = false; busca.forceActiveFocus(); busca.selectAll() }
    // Ctrl+I (como no Dolphin): o mesmo campo, filtrando a pasta (Enter não vira busca recursiva)
    property bool modoFiltro: false
    readonly property bool filtrosAbertos: filtros.aberto
    readonly property bool buscaFocada: busca.activeFocus
    function fecharFiltros() { filtros.aberto = false }
    // trocar de aba (ou de lado na divisão) fecha os filtros e o campo mostra o que vale na aba nova
    onAbaChanged: { filtros.aberto = false; busca.text = aba ? (aba.modoBusca ? aba.textoBusca : aba.filtro) : "" }
    function focarFiltro() { modoFiltro = true; busca.forceActiveFocus(); busca.selectAll() }

    component BotaoNav: Item {
        id: bn
        property string glifo: ""
        property bool habilitado: true
        property bool ativo: false
        property string dica: ""
        signal clicado()
        signal direito(point p)
        width: 28; height: 26
        opacity: habilitado ? 1 : 0.35
        Chanfro { anchors.fill: parent; corte: 5; preenchimento: bn.ativo ? Tema.alfa(Tema.destaque, 0.2) : (mb.containsMouse && bn.habilitado ? Tema.hover : Tema.alfa(Tema.painel, 0.7)); borda: bn.ativo || mb.containsMouse ? Tema.destaque : Tema.alfa(Tema.destaque, 0.35) }
        Text { anchors.centerIn: parent; text: bn.glifo; font.pixelSize: 13; color: bn.ativo ? Tema.destaque : Tema.texto }
        Accessible.role: Accessible.Button
        Accessible.name: bn.dica
        HoverHandler { id: hvB }          // (vale também com o botão desabilitado)
        DicaTexto { texto: bn.dica; sobre: hvB.hovered }
        MouseArea {
            id: mb; anchors.fill: parent; hoverEnabled: true; enabled: bn.habilitado; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (e) => { if (e.button === Qt.RightButton) bn.direito(mapToItem(null, e.x, e.y + 8)); else bn.clicado() }
            onPressAndHold: (e) => bn.direito(mapToItem(null, e.x, e.y + 8))
        }
    }

    Row {
        id: nav
        x: 12; anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        // botão direito (ou segurar) no voltar/avançar: a lista do histórico, como no Dolphin
        BotaoNav { glifo: "◂"; dica: Ds.t("dica.voltar", { a: ((arquivos.atalhos || {}).voltar || "") }); habilitado: !!b.aba && b.aba.podeVoltar; onClicado: b.aba.voltar(); onDireito: (p) => Ds.janela.menuHistorico(-1, p) }
        BotaoNav { glifo: "▸"; dica: Ds.t("dica.avancar", { a: ((arquivos.atalhos || {}).avancar || "") }); habilitado: !!b.aba && b.aba.podeAvancar; onClicado: b.aba.avancar(); onDireito: (p) => Ds.janela.menuHistorico(1, p) }
        BotaoNav { glifo: "▴"; dica: Ds.t("dica.subir", { a: ((arquivos.atalhos || {}).subir || "") }); habilitado: !!b.aba; onClicado: b.aba.subir() }
    }

    // ---- breadcrumb / caminho
    Item {
        id: migalha
        anchors.left: nav.right; anchors.leftMargin: 10
        anchors.right: buscaCaixa.left; anchors.rightMargin: 10
        height: 26; anchors.verticalCenter: parent.verticalCenter
        Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.alfa(Tema.entrada, 0.9); borda: b.editando ? Tema.secundaria : Tema.alfa(Tema.destaque, 0.3) }
        MouseArea { anchors.fill: parent; visible: !b.editando; cursorShape: Qt.IBeamCursor; onClicked: b.editarCaminho() }
        Flickable {
            id: fm
            visible: !b.editando
            x: 8; width: parent.width - 16; height: parent.height
            contentWidth: linha.implicitWidth; contentHeight: height
            clip: true; interactive: false
            onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
            Row {
                id: linha
                height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; text: "/SHARD:"; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto3 }
                Repeater {
                    model: b.aba ? b.aba.migalhas : []
                    Row {
                        id: seg
                        required property int index
                        required property var modelData
                        readonly property bool ultimo: index === (b.aba ? b.aba.migalhas.length - 1 : 0)
                        height: linha.height
                        Text { visible: seg.index > 0; anchors.verticalCenter: parent.verticalCenter; text: "/"; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto3 }
                        Item {
                            width: rs.implicitWidth + 6; height: parent.height
                            Rectangle { anchors.fill: parent; anchors.topMargin: 4; anchors.bottomMargin: 4; color: ms.containsMouse ? Tema.hover : "transparent" }
                            Row {
                                id: rs
                                x: 3; anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                // o caminho se lê sem ruído: o código só no segmento atual, depois do nome
                                Text { id: nm; text: seg.modelData.nome; font.family: Tema.fTexto; font.pixelSize: 13; color: seg.ultimo ? Tema.destaque : Tema.texto }
                                Text { visible: seg.ultimo; text: " 0x" + seg.modelData.codigo; font.family: Tema.fMono; font.pixelSize: 9; color: Tema.texto3; anchors.baseline: nm.baseline }
                            }
                            MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!seg.ultimo) b.aba.irPara(seg.modelData.caminho) }
                            AlvoSoltar { anchors.fill: parent; destino: seg.ultimo ? "" : seg.modelData.caminho }
                        }
                    }
                }
            }
        }
        TextInput {
            id: campo
            visible: b.editando
            x: 8; width: parent.width - 16; height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tema.fTexto; font.pixelSize: 13
            color: Tema.texto
            selectionColor: Tema.alfa(Tema.destaque, 0.5)
            clip: true
            onAccepted: {
                if (sug.sel >= 0 && sug.lista[sug.sel]) text = sug.lista[sug.sel].texto
                const e = b.aba.irPara(text)
                if (e) Ds.janela.avisar("erro", e)
                else { b.editando = false; Ds.janela.focarArea() }
            }
            // sugestões (completarCaminho) a cada letra; Tab completa pelo prefixo comum; ↑/↓ escolhem
            onTextEdited: sug.atualizar()
            Keys.onTabPressed: (e) => {
                e.accepted = true
                const p = arquivos.prefixoComum ? arquivos.prefixoComum(text) : ""
                if (p && p.length > text.length) text = p
                else if (sug.lista.length === 1) text = sug.lista[0].texto
                else if (sug.sel >= 0) text = sug.lista[sug.sel].texto
                cursorPosition = text.length
                sug.atualizar()
            }
            Keys.onDownPressed: (e) => { if (sug.lista.length) { sug.sel = (sug.sel + 1) % sug.lista.length; e.accepted = true } }
            Keys.onUpPressed: (e) => { if (sug.lista.length) { sug.sel = sug.sel <= 0 ? sug.lista.length - 1 : sug.sel - 1; e.accepted = true } }
            Keys.onEscapePressed: { if (sug.lista.length) sug.lista = []; else { b.editando = false; Ds.janela.focarArea() } }
            onActiveFocusChanged: if (!activeFocus) { b.editando = false; sug.lista = [] }
        }
        Item {
            id: sug
            property var lista: []
            property int sel: -1
            function atualizar() { lista = arquivos.completarCaminho ? (arquivos.completarCaminho(campo.text) || []) : []; sel = -1 }
            visible: b.editando && lista.length > 0
            y: parent.height + 3; width: Math.min(parent.width, 520); height: colS.implicitHeight + 8
            z: 80
            Chanfro { anchors.fill: parent; corte: 6; preenchimento: Tema.elevado; borda: Tema.secundaria }
            Column {
                id: colS
                x: 4; y: 4; width: parent.width - 8
                Repeater {
                    model: sug.lista
                    Item {
                        required property var modelData
                        required property int index
                        width: colS.width; height: 26
                        Rectangle { anchors.fill: parent; color: sug.sel === index ? Tema.selecao : maS.containsMouse ? Tema.hover : "transparent" }
                        Icone { x: 6; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter; fonte: "image://icone/folder"; cor: Tema.destaque; colorir: 0.9 }
                        Text { x: 28; width: parent.width - 34; anchors.verticalCenter: parent.verticalCenter; text: modelData.texto; elide: Text.ElideLeft; font.family: Tema.fTexto; font.pixelSize: 13; color: Tema.texto }
                        MouseArea {
                            id: maS; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: (e) => e.accepted = true          // sem tirar o foco do campo antes do clique
                            onClicked: { const c = modelData.caminho; b.editando = false; sug.lista = []; b.aba.irPara(c); Ds.janela.focarArea() }
                        }
                    }
                }
            }
        }
    }

    // ---- busca
    Item {
        id: buscaCaixa
        anchors.right: visoes.left; anchors.rightMargin: 10
        width: 260; height: 26; anchors.verticalCenter: parent.verticalCenter
        Chanfro { anchors.fill: parent; corte: 5; preenchimento: Tema.alfa(Tema.entrada, 0.9); borda: busca.activeFocus ? Tema.secundaria : (b.aba && b.aba.modoBusca ? Tema.destaque : Tema.alfa(Tema.destaque, 0.3)) }
        Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; font.pixelSize: 14; color: Tema.texto3 }
        TextInput {
            id: busca
            x: 26; width: parent.width - 58; height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tema.fTexto; font.pixelSize: 13
            color: Tema.texto
            clip: true
            onTextEdited: if (b.aba && !b.aba.modoBusca) b.aba.filtro = text
            onAccepted: {
                if (b.modoFiltro) { Ds.janela.focarArea(); return }
                if (text.trim() !== "" || filtros.temFiltro) { filtros.buscar(); Ds.janela.focarArea() }
            }
            Keys.onEscapePressed: { text = ""; filtros.aberto = false; if (b.aba.modoBusca) b.aba.sairBusca(); else b.aba.filtro = ""; Ds.janela.focarArea() }
            Text { visible: busca.text === "" && (!busca.activeFocus || b.modoFiltro); text: b.modoFiltro ? Ds.t("busca.filtrar") : Ds.t("busca.dica") + "  Ctrl+F"; font: busca.font; color: Tema.texto3; anchors.verticalCenter: parent.verticalCenter }
        }
        Connections { target: b.aba; function onCaminhoMudou() { busca.text = ""; filtros.aberto = false } }
        // botão dos filtros da busca (acende quando há filtro ativo)
        Item {
            anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 20
            Chanfro { anchors.fill: parent; corte: 4; preenchimento: filtros.temFiltro ? Tema.secundaria : (mf.containsMouse || filtros.aberto ? Tema.hover : "transparent"); borda: Tema.alfa(Tema.secundaria, filtros.aberto || filtros.temFiltro ? 1 : 0.4) }
            Text { anchors.centerIn: parent; text: "⚙"; font.pixelSize: 12; color: filtros.temFiltro ? Tema.escuro : Tema.texto2 }
            MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: filtros.aberto = !filtros.aberto }
            DicaTexto { texto: Ds.t("filtro.dica"); sobre: mf.containsMouse && !filtros.aberto }
        }
    }
    PainelFiltros {
        id: filtros
        x: buscaCaixa.x + buscaCaixa.width - width; y: buscaCaixa.y + buscaCaixa.height + 4
        aba: b.aba
        texto: busca.text
        onBuscou: Ds.janela.focarArea()
    }

    // ---- visões e painéis
    Row {
        id: visoes
        anchors.right: agrupT.visible ? agrupT.left : paineis.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Repeater {
            model: ["pilhas", "lista", "grade"]
            Item {
                id: vb
                required property string modelData
                required property int index
                readonly property bool ativa: b.aba && b.aba.visao === modelData
                width: tv.implicitWidth + 20; height: 26
                Chanfro {
                    anchors.fill: parent; corte: vb.index === 0 ? 5 : 0
                    preenchimento: vb.ativa ? Tema.destaque : (mv.containsMouse ? Tema.hover : Tema.alfa(Tema.painel, 0.7))
                    borda: Tema.alfa(Tema.destaque, vb.ativa ? 1 : 0.4)
                }
                Text { id: tv; anchors.centerIn: parent; text: Ds.t("visao." + vb.modelData); font.family: Tema.fRotulo; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1; color: vb.ativa ? Tema.escuro : Tema.texto }
                MouseArea { id: mv; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.aba.visao = vb.modelData }
            }
        }
    }
    // PILHAS: agrupar os arquivos soltos por tipo (Ctrl+G)
    Item {
        id: agrupT
        readonly property bool ligado: Ds.janela.agruparTiposDe(b.aba)
        visible: !!b.aba && b.aba.visao === "pilhas"
        anchors.right: paineis.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: ta.implicitWidth + 30; height: 26
        Chanfro { anchors.fill: parent; corte: 5; preenchimento: agrupT.ligado ? Tema.secundaria : (mt.containsMouse ? Tema.hover : Tema.alfa(Tema.painel, 0.7)); borda: Tema.alfa(Tema.secundaria, agrupT.ligado || mt.containsMouse ? 1 : 0.45) }
        Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; rotation: 45; color: agrupT.ligado ? Tema.escuro : "transparent"; border.color: agrupT.ligado ? Tema.escuro : Tema.secundaria }
        Text { id: ta; x: 22; anchors.verticalCenter: parent.verticalCenter; text: Ds.t("pilhas.agruparTipos"); font.family: Tema.fRotulo; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1; color: agrupT.ligado ? Tema.escuro : Tema.texto }
        MouseArea { id: mt; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ds.janela.alternarAgruparTipos() }
    }
    Row {
        id: paineis
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        BotaoNav { glifo: "◫"; ativo: !!arquivos.dividido; dica: Ds.t("at.dividir") + " · " + ((arquivos.atalhos || {}).dividir || ""); onClicado: arquivos.alternarDivisao() }
        BotaoNav { glifo: "§"; ativo: !!b.aba && b.aba.agrupar; dica: Ds.t("menu.agrupar"); onClicado: b.aba.agrupar = !b.aba.agrupar }
        BotaoNav { glifo: "▤"; ativo: Ds.janela.locaisVisiveis; dica: Ds.t("at.locais") + " · " + ((arquivos.atalhos || {}).locais || ""); onClicado: Ds.janela.locaisVisiveis = !Ds.janela.locaisVisiveis }
        BotaoNav { glifo: "≡"; ativo: Ds.janela.logVisivel; dica: Ds.t("at.painelLog") + " · " + ((arquivos.atalhos || {}).painelLog || ""); onClicado: Ds.janela.logVisivel = !Ds.janela.logVisivel }
    }
}
