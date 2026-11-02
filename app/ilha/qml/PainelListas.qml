import QtQuick

// Gaveta, janelas, avisos, cópias e nota: uma por vez ("qual").
Rolagem {
    id: p
    property string qual: "gaveta"
    readonly property var avisos: ui.snap ? ui.snap.notices || [] : []
    readonly property var clips: ui.snap ? ui.snap.clips || [] : []
    readonly property var janelas: ilha.janelasGuardadas || []
    function corApp(app) {
        let h = 0; for (let i = 0; i < app.length; i++) h = (h * 31 + app.charCodeAt(i)) >>> 0
        return ["#30D158", "#0A84FF", "#FF9F0A", "#FF6982", "#BF5AF2", "#64D2FF", "#FFD60A", "#ACE696"][h % 8]
    }
    function hora(at) { return Qt.formatTime(new Date(at), "hh:mm") }

    // ---- gaveta
    Vazio { visible: p.qual === "gaveta" && (ilha.gaveta || []).length === 0; ui: p.ui; glifo: "Tray"; texto: p.ui.txt("Arraste arquivos, texto ou endereços para a pílula e eles ficam aqui") }
    Repeater {
        model: p.qual === "gaveta" ? ilha.gaveta || [] : []
        Surge {
            id: it
            required property var modelData
            required property int index
            ui: p.ui; ordem: index; width: parent.width; height: 44
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: p.ui.tema.hover }
            Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; tamanho: 22; cor: it.modelData.exists ? p.ui.tema.texto2 : p.ui.tema.texto4; nome: it.modelData.kind === "url" ? "Link" : it.modelData.kind === "texto" ? "NotePencil" : "File" }
            Text { x: 44; width: parent.width - 44 - acoesGaveta.width - 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle; text: it.modelData.name; color: it.modelData.exists ? p.ui.tema.texto : p.ui.tema.texto4; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
            Row {
                id: acoesGaveta
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                Acao { ui: p.ui; glifo: "ArrowSquareOut"; tamanho: 12; onClicado: p.ui.agir("gaveta-abrir", it.modelData.path) }
                Acao { visible: it.modelData.exists && /\.(png|jpe?g|webp|bmp|tiff?)$/i.test(it.modelData.path); ui: p.ui; glifo: "TextAa"; tamanho: 12; onClicado: p.ui.agir("texto-da-imagem", it.modelData.path) }
                Acao { ui: p.ui; glifo: "X"; tamanho: 12; onClicado: p.ui.agir("gaveta-remover", it.modelData.path) }
            }
        }
    }

    // ---- janelas: as guardadas e as abertas
    Text { visible: p.qual === "janelas" && p.janelas.length > 0; text: p.ui.txt("Guardadas: clique para devolver"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
    Repeater {
        model: p.qual === "janelas" ? p.janelas : []
        Item {
            id: ja
            required property var modelData
            width: parent.width; height: 40
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: mja.containsMouse ? p.ui.tema.ativo : p.ui.tema.hover }
            MouseArea { id: mja; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.agir("janela-restaurar", ja.modelData.id) }
            Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "Tray"; cor: p.ui.tema.texto2 }
            Text { x: 34; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: ja.modelData.title || ja.modelData.appClass || ""; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
        }
    }
    Text { visible: p.qual === "janelas"; text: p.ui.txt(p.ui.janelasAbertas === null ? "Listando janelas…" : "Abertas"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
    readonly property var abertas: (ui.janelasAbertas || []).filter(a => !p.janelas.some(j => j.id === a.id))
    Vazio { visible: p.qual === "janelas" && p.ui.janelasAbertas !== null && p.abertas.length === 0; ui: p.ui; glifo: "AppWindow"; texto: p.ui.txt("Nenhuma janela aberta") }
    Repeater {
        model: p.qual === "janelas" ? p.abertas : []
        Item {
            id: ab
            required property var modelData
            width: parent.width; height: 40
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: ab.modelData.active ? p.ui.tema.acaoFraca : p.ui.tema.hover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.agir("janela-focar", ab.modelData.id) }
            Glifo { x: 12; anchors.verticalCenter: parent.verticalCenter; nome: "AppWindow"; cor: p.ui.tema.texto2 }
            Text { x: 34; width: parent.width - 34 - aj.width - 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: ab.modelData.title; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13 }
            Row {
                id: aj
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                Acao { ui: p.ui; glifo: "SquareHalf"; onClicado: p.ui.agir("janela-encaixar", ab.modelData.id + " esquerda") }
                Acao { ui: p.ui; glifo: "SquareHalf"; transform: Scale { origin.x: 14; xScale: -1 } onClicado: p.ui.agir("janela-encaixar", ab.modelData.id + " direita") }
                Acao { ui: p.ui; glifo: "ArrowsOutSimple"; onClicado: p.ui.agir("janela-encaixar", ab.modelData.id + " maximizar") }
                Acao { ui: p.ui; glifo: "Tray"; onClicado: p.ui.agir("janela-guardar", ab.modelData.id) }
            }
        }
    }

    // ---- avisos
    Vazio { visible: p.qual === "avisos" && p.avisos.length === 0; ui: p.ui; glifo: "BellRinging"; texto: p.ui.txt("As notificações que os aplicativos mandarem ficam aqui") }
    Item {
        visible: p.qual === "avisos" && p.avisos.length > 0
        width: parent.width; height: 28
        Text { anchors.verticalCenter: parent.verticalCenter; text: p.ui.txt("Recentes"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
        AcaoLarga { anchors.right: parent.right; ui: p.ui; glifo: "Broom"; texto: p.ui.txt("Limpar"); onClicado: p.ui.agir("avisos-limpar") }
    }
    Repeater {
        model: p.qual === "avisos" ? p.avisos : []
        Surge {
            id: av
            required property var modelData
            required property int index
            ui: p.ui; ordem: index; width: parent.width; height: cv.implicitHeight + 16
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: av.modelData.urgent ? Qt.rgba(p.ui.tema.erro.r, p.ui.tema.erro.g, p.ui.tema.erro.b, 0.14) : p.ui.tema.hover }
            Column {
                id: cv
                x: 12; y: 8; width: parent.width - 60; spacing: 2
                Row {
                    spacing: 6
                    Rectangle { width: 7; height: 7; radius: p.ui.raioDe(7); anchors.verticalCenter: parent.verticalCenter; color: p.corApp(av.modelData.app || "") }
                    Text { text: (av.modelData.app || p.ui.txt("sistema")) + " · " + p.hora(av.modelData.at); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
                }
                Text { width: parent.width; elide: Text.ElideRight; text: av.modelData.title; color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13; font.weight: Font.Medium }
                Text { visible: !!av.modelData.body; width: parent.width; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; text: av.modelData.body; color: p.ui.tema.texto2; font.family: p.ui.tema.fonte; font.pixelSize: 12 }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 6; y: 6
                Acao { visible: !!av.modelData.desktopEntry; ui: p.ui; glifo: "ArrowSquareOut"; tamanho: 12; onClicado: p.ui.agir("avisos-abrir-app", av.modelData.desktopEntry) }
                Acao { ui: p.ui; glifo: "X"; tamanho: 12; onClicado: p.ui.agir("avisos-remover", String(av.modelData.id)) }
            }
        }
    }

    // ---- cópias
    Vazio { visible: p.qual === "clips" && p.clips.length === 0; ui: p.ui; glifo: "Clipboard"; texto: p.ui.txt("O que você copiar aparece aqui, para pegar de volta depois") }
    Item {
        visible: p.qual === "clips" && p.clips.length > 0
        width: parent.width; height: 32
        Rectangle { anchors.fill: parent; radius: p.ui.tema.raioControle; color: p.ui.tema.hover }
        TextInput {
            id: busca
            x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
            color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13; selectByMouse: true
            Keys.onEscapePressed: { text = ""; p.ui.soltarTeclado() }
            TapHandler { onPressedChanged: if (pressed) p.ui.pedirTeclado(busca) }
            Text { visible: !busca.text; text: p.ui.txt("Buscar nas cópias…"); color: p.ui.tema.texto3; font: busca.font }
        }
    }
    Repeater {
        model: p.qual === "clips" ? p.clips.filter(c => !busca.text || c.preview.toLowerCase().indexOf(busca.text.toLowerCase()) >= 0) : []
        Surge {
            id: cl
            required property var modelData
            required property int index
            ui: p.ui; ordem: Math.min(index, 8); width: parent.width; height: 40
            Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: mcl.containsMouse ? p.ui.tema.ativo : p.ui.tema.hover }
            MouseArea { id: mcl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.ui.agir("clip-copiar", String(cl.modelData.id)) }
            Rectangle { visible: cl.modelData.kind === "cor"; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 5; color: visible ? cl.modelData.preview : "transparent" }
            Text { x: cl.modelData.kind === "cor" ? 36 : 12; width: parent.width - x - 70; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: cl.modelData.preview; color: p.ui.tema.texto; font.family: cl.modelData.kind === "url" ? p.ui.tema.fonteMono : p.ui.tema.fonte; font.pixelSize: 13 }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                Acao { ui: p.ui; glifo: "PushPin"; tamanho: 12; cheio: cl.modelData.pinned; ativa: cl.modelData.pinned; onClicado: p.ui.agir("clip-fixar", String(cl.modelData.id)) }
                Acao { ui: p.ui; glifo: "X"; tamanho: 12; onClicado: p.ui.agir("clip-remover", String(cl.modelData.id)) }
            }
        }
    }
    AcaoLarga { visible: p.qual === "clips" && p.clips.length > 0; ui: p.ui; glifo: "Broom"; texto: p.ui.txt("Limpar · fixados ficam"); onClicado: p.ui.agir("clip-limpar") }

    // ---- nota
    Item {
        visible: p.qual === "nota"
        width: parent.width; height: 190
        Rectangle { anchors.fill: parent; radius: p.ui.raioItem; color: p.ui.tema.hover }
        TextEdit {
            id: nota
            x: 12; y: 10; width: parent.width - 24; height: parent.height - 34
            wrapMode: TextEdit.Wrap; selectByMouse: true; clip: true
            color: p.ui.tema.texto; font.family: p.ui.tema.fonte; font.pixelSize: 13
            Component.onCompleted: {
                text = p.ui.snap ? p.ui.snap.note || "" : ""
                if (p.ui.querNota) { p.ui.querNota = false; cursorPosition = length; p.ui.pedirTeclado(nota) }
            }
            onTextChanged: if (activeFocus) { salvar.restart(); estado.salvo = false }
            Keys.onEscapePressed: p.ui.soltarTeclado()
            TapHandler { onPressedChanged: if (pressed) p.ui.pedirTeclado(nota) }
            Text { visible: !nota.text; text: p.ui.txt("Anote algo — fica guardado na ilha."); color: p.ui.tema.texto3; font: nota.font }
            Timer { id: salvar; interval: 500; onTriggered: { p.ui.agir("nota-salvar", nota.text); estado.salvo = true } }
        }
        Text { id: estado; property bool salvo: true; x: 12; y: parent.height - 20; text: p.ui.txt(salvo ? "guardada" : "guardando…"); color: p.ui.tema.texto3; font.family: p.ui.tema.fonte; font.pixelSize: 11 }
    }
}
