import QtQuick
import QtQuick.Window

// QML mínimo para testar o back-end (o Deckard faz o Main.qml de verdade).
// Lista a aba atual com ícone/miniatura, caminho e locais; Enter entra, Backspace sobe, Del lixeira.
Window {
    id: janela
    width: opcoes.largura || 1000
    height: opcoes.altura || 640
    visible: true
    color: arquivos.paleta.fundo
    title: "DATASHARD // " + arquivos.aba.titulo

    readonly property color destaque: arquivos.paleta.destaque
    readonly property var aba: arquivos.aba

    Column {
        id: topo
        x: 12; y: 8; spacing: 4
        Text {
            text: "DATASHARD v1.0 NFS   RESOURCES MANAGER   LOG ANALYTICS " + aba.codigo + "   " + arquivos.paleta.nome.toUpperCase() + " SHARD"
            color: destaque; font.family: "Orbitron"; font.pixelSize: 11
        }
        Row {
            spacing: 6
            Repeater {
                model: aba.migalhas
                Text { text: "/" + modelData.codigo + "_" + modelData.nome; color: "#A9A9BA"; font.pixelSize: 13 }
            }
        }
        Text { text: aba.contagem + (aba.carregando ? "  · lendo…" : "") + "   " + aba.erro + "   livre " + aba.livre; color: "#76768A"; font.pixelSize: 12 }
    }

    Column {
        id: lateral
        anchors { left: parent.left; top: topo.bottom; bottom: parent.bottom; margins: 12 }
        width: 200; spacing: 2
        Repeater {
            model: arquivos.locais
            Column {
                Text { text: modelData.titulo + (modelData.secao === "lixeira" ? " [" + modelData.quantidade + "]" : ""); color: destaque; font.pixelSize: 11; font.bold: true
                       MouseArea { anchors.fill: parent; enabled: !!modelData.caminho; onClicked: aba.irPara(modelData.caminho) } }
                Repeater {
                    model: modelData.itens
                    Text { text: "  " + modelData.nome; color: "#DCDCE4"; font.pixelSize: 12; elide: Text.ElideRight; width: 190
                           MouseArea { anchors.fill: parent; onClicked: if (modelData.caminho) aba.irPara(modelData.caminho) } }
                }
            }
        }
    }

    ListView {
        id: lista
        anchors { left: lateral.right; right: parent.right; top: topo.bottom; bottom: parent.bottom; margins: 12 }
        clip: true; focus: true
        model: aba.modelo
        currentIndex: aba.atual
        delegate: Rectangle {
            width: ListView.view.width; height: 26
            color: selecionado ? Qt.rgba(janela.destaque.r, janela.destaque.g, janela.destaque.b, 0.25) : "transparent"
            border.color: index === aba.atual ? "#5EF6FF" : "transparent"
            Row {
                x: 4; spacing: 8; anchors.verticalCenter: parent.verticalCenter
                Image { width: 20; height: 20; sourceSize: Qt.size(40, 40); asynchronous: true
                        source: miniatura !== "" ? miniatura : iconeUrl; fillMode: Image.PreserveAspectFit }
                Text { text: codigo; color: "#76768A"; font.family: "JetBrains Mono"; font.pixelSize: 11; width: 70 }
                Text { text: nome + (ehPasta && filhos >= 0 ? "  [" + filhos + "]" : ""); color: "#DCDCE4"; width: 340; elide: Text.ElideMiddle }
                Text { text: tamanhoTexto; color: "#A9A9BA"; width: 80; horizontalAlignment: Text.AlignRight }
                Text { text: modificadoTexto + "  " + grupo; color: "#76768A" }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: (m) => aba.selecionar(index, m.modifiers & Qt.ControlModifier ? "alternar" : m.modifiers & Qt.ShiftModifier ? "intervalo" : "unico")
                onDoubleClicked: aba.ativar(index)
            }
        }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Down) aba.selecionar(Math.min(aba.atual + 1, count - 1), "unico")
            else if (e.key === Qt.Key_Up) aba.selecionar(Math.max(aba.atual - 1, 0), "unico")
            else if (e.key === Qt.Key_Return) aba.ativar(aba.atual)
            else if (e.key === Qt.Key_Backspace) aba.subir()
            else if (e.key === Qt.Key_Delete) arquivos.lixeira(aba.selecionados)
            else if (e.key === Qt.Key_F5) aba.recarregar()
            else return
            e.accepted = true
        }
    }
}
