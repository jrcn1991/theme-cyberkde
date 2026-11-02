import QtQuick
import "../../qml"

// Rodapé: contagem · seleção · tamanho (ou o estado da busca); a barra segmentada da operação mais
// recente (clique abre a fila); área de transferência; código de barras, código da pasta e livre no
// disco. Embaixo, a barra grossa da referência com microtexto.
// Vivo, sem laço: a barra da operação enche com glitch e termina num flash com DONE (BarraOperacao,
// referência 11); a barra de uso do disco (do dispositivo da pasta) dá um pulso leve ao trocar de pasta.
Item {
    id: r
    height: 40
    property var aba: arquivos.aba
    readonly property var ops: arquivos.operacoes || []
    readonly property var op: ops.length ? (ops.slice().reverse().find(o => ["contando", "rodando", "conflito", "fila"].indexOf(o.estado) >= 0) || ops[ops.length - 1]) : null
    signal abrirFila()
    // uso (0–1) do dispositivo montado que contém a pasta (o ponto de montagem mais longo); -1 = não achado
    readonly property real uso: {
        const cam = aba ? String(aba.caminho || "") : ""
        let melhor = -1, u = -1
        for (const sec of (arquivos.locais || [])) {
            if (sec.secao !== "dispositivos") continue
            for (const d of (sec.itens || [])) {
                const m = String(d.caminho || "")
                if (!d.montado || !m) continue
                const dentro = cam === m || cam.startsWith(m.endsWith("/") ? m : m + "/")
                if (dentro && m.length > melhor) { melhor = m.length; u = d.uso || 0 }
            }
        }
        return u
    }
    onUsoChanged: barraUso.pulsar()
    // tamanho da seleção; pasta (sem tamanho calculado) dá "—", não "0 B" (U10)
    readonly property string tamSel: {
        if (!aba || aba.qtdSelecionados <= 0) return ""
        const t = aba.tamanhoSelecao || ""
        const umaPasta = aba.qtdSelecionados === 1 && aba.atual >= 0 && !!aba.item(aba.atual).ehPasta
        return umaPasta || !t || /^0([.,]0+)?\s/.test(t) ? "—" : t
    }
    Connections { target: r.aba; function onCarregou() { barraUso.pulsar() } }

    Rectangle { width: parent.width; height: 1; color: Tema.alfa(Tema.destaque, 0.5) }
    Row {
        x: 14; y: 6
        spacing: 14
        Text {
            text: r.aba ? (r.aba.modoBusca ? (r.aba.buscando ? Ds.t("busca.varrendo", { n: r.aba.modelo.rowCount() }) : Ds.t("busca.resultados", { q: r.aba.textoBusca, n: r.aba.modelo.rowCount() })) : r.aba.contagem.toUpperCase()) : ""
            font.family: Tema.fMono; font.pixelSize: 11; color: r.aba && r.aba.buscando ? Tema.secundaria : Tema.texto2
        }
        Text {
            visible: !!r.aba && r.aba.qtdSelecionados > 0
            text: Ds.t("rod.sel", { n: r.aba ? r.aba.qtdSelecionados : 0 }) + " · " + r.tamSel
            font.family: Tema.fMono; font.pixelSize: 11; color: Tema.destaque
        }
        Text {
            visible: arquivos.area && arquivos.area.quantidade > 0
            text: arquivos.area ? Ds.t("rod.area", { n: arquivos.area.quantidade, m: arquivos.area.modo === "recortar" ? Ds.t("rod.recortar") : Ds.t("rod.copiar") }) : ""
            font.family: Tema.fMono; font.pixelSize: 11; color: Tema.secundaria
        }
    }
    // operação
    Item {
        id: opx
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4; width: Math.min(520, parent.width * 0.4); height: 24
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            BarraOperacao {
                width: 170; height: 10
                anchors.verticalCenter: parent.verticalCenter
                valor: r.op ? (r.op.estado === "ok" ? 1 : Math.max(0, r.op.progresso)) : 0
                indeterminado: !!r.op && (r.op.estado === "contando" || r.op.progresso < 0) && r.op.estado !== "ok"
                estado: r.op ? r.op.estado + ":" + r.op.id : ""
                cor: r.op && (r.op.estado === "erro" || r.op.estado === "conflito") ? Tema.alerta : Tema.destaque
                larguraSeg: 7; vao: 2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: opx.width - 180
                elide: Text.ElideRight
                text: !r.op ? Ds.t("rod.semOp")
                    : r.op.estado === "rodando" ? r.op.rotulo + " " + (r.op.feitos + 1) + "/" + r.op.total + " · " + Math.round(r.op.progresso * 100) + "% · " + r.op.velocidade
                    : r.op.rotulo + " · " + Ds.t("op." + r.op.estado)
                font.family: Tema.fMono; font.pixelSize: 11
                color: !r.op ? Tema.texto3 : r.op.estado === "conflito" || r.op.estado === "erro" ? Tema.alerta : r.op.estado === "ok" ? Tema.texto2 : Tema.secundaria
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.abrirFila() }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 14; y: 6
        spacing: 10
        Text {
            id: f1
            anchors.verticalCenter: parent.verticalCenter
            text: Ds.t("rod.atalhos")
            font.family: Tema.fMono; font.pixelSize: 11
            color: maF1.containsMouse ? Tema.secundaria : Tema.texto2
            MouseArea { id: maF1; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ds.janela.abrirAtalhos() }
        }
        CodigoBarras { width: 60; height: 12; texto: r.aba ? r.aba.codigo : ""; anchors.verticalCenter: parent.verticalCenter }
        Text { text: r.aba ? r.aba.codigo : ""; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto3 }
        Text { text: r.aba ? Ds.t("rod.livre", { v: r.aba.livre }) : ""; font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2 }
        BarraPulso {
            id: barraUso
            visible: r.uso >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 6
            larguraSeg: 4; vao: 1
            valor: Math.max(0, r.uso)
            limiarAlerta: 0.9
        }
    }
    // barra grossa da referência
    Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        x: 14; width: parent.width - 120; height: 8
        color: Tema.alfa(Tema.destaque, 0.85)
        Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "DATASHARD // " + (r.aba ? r.aba.codigo : "") + " // NFS.MOUNT OK"; font.family: Tema.fMono; font.pixelSize: 6; color: Tema.escuro }
    }
    CodigoBarras { anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 1; width: 90; height: 10; texto: "DATASHARD" + (r.aba ? r.aba.codigo : "") }
}
