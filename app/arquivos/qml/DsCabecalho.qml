import QtQuick
import "../../qml"

// Cabeçalho de sistema (28 px): DATASHARD v1.0 NFS · RESOURCES MANAGER · LOG ANALYTICS <código> ·
// <CORP> SHARD, relógio e o ícone da corporação. Códigos de sistema ficam em inglês nos dois idiomas.
// Dados vivos discretos: um código SYNC que troca a cada 7 s (CodigoVivo) e três quadradinhos que acendem
// em sequência só enquanto a aba está lendo. Em repouso, só o relógio muda (1 vez por segundo).
Item {
    id: c
    height: 28
    property string codigo: arquivos.aba ? arquivos.aba.codigo : ""
    property date agora: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: c.agora = new Date() }
    readonly property string corp: (arquivos.paleta && arquivos.paleta.nome) ? arquivos.paleta.nome : "CYBERKDE"
    readonly property string icone: arquivos.paleta && arquivos.paleta.corp && arquivos.paleta.corp !== "nenhuma"
        ? Qt.resolvedUrl("../../../assets/corporacoes/" + arquivos.paleta.corp + "-icone.png") : ""

    Row {
        x: 14; anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Text { text: "DATASHARD v1.0 NFS"; font.family: Tema.fIdentidade; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1; color: Tema.destaque; anchors.verticalCenter: parent.verticalCenter }
        Codigo { text: "◆"; color: Tema.destaque; tamanho: 9; anchors.verticalCenter: parent.verticalCenter }
        // atividade: acende em sequência enquanto lê a pasta (parado e apagado em repouso)
        Row {
            id: atividade
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            readonly property bool lendo: !!arquivos.aba && arquivos.aba.carregando
            property int passo: 0
            Timer { interval: 110; repeat: true; running: atividade.lendo && arquivos.movimento !== "minimo"; onTriggered: atividade.passo = (atividade.passo + 1) % 3 }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 4; height: 4
                    color: atividade.lendo && (atividade.passo === index || arquivos.movimento === "minimo") ? Tema.secundaria : Tema.alfa(Tema.destaque, 0.25)
                }
            }
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 28
        Text { text: "RESOURCES MANAGER"; font.family: Tema.fRotulo; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.5; color: Tema.destaque }
        Text { text: "LOG ANALYTICS " + c.codigo.replace("0x", "").slice(0, 4); font.family: Tema.fRotulo; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.5; color: Tema.destaque }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        CodigoVivo { prefixo: "SYNC"; semente: parseInt((c.codigo || "0x0").replace("0x", ""), 16) || 0; anchors.verticalCenter: parent.verticalCenter }
        Text { text: Qt.formatTime(c.agora, "HH:mm:ss"); font.family: Tema.fMono; font.pixelSize: 11; color: Tema.texto2; anchors.verticalCenter: parent.verticalCenter }
        Text { text: c.corp + " SHARD"; font.family: Tema.fRotulo; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.5; color: Tema.destaque; anchors.verticalCenter: parent.verticalCenter }
        Image { visible: c.icone !== "" && status === Image.Ready; source: c.icone; width: 18; height: 18; sourceSize: Qt.size(36, 36); fillMode: Image.PreserveAspectFit; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.alfa(Tema.destaque, 0.35) }
}
