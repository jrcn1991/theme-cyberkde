import QtQuick
import QtQuick.Window

// Janela de teste: uma janela de verdade, pequena e no visual do tema, para a usuária ver a animação
// REAL do KWin ao abrir e ao fechar. Criada e destruída pelo Loader da seção Efeitos (destruir a
// janela é o que dispara a animação de fechar).
Window {
    id: w
    width: 380; height: 220
    minimumWidth: 380; minimumHeight: 220
    color: Tema.base
    title: Txt.t("fx.teste.titulo")
    flags: Qt.Window
    visible: true

    Rectangle { anchors.fill: parent; color: Tema.base }
    Chanfro {
        anchors.fill: parent; anchors.margins: 10
        corte: Tema.chanfroG
        preenchimento: Tema.painel
        borda: Tema.alfa(Tema.destaque, 0.7)
    }
    Cantoneiras { anchors.margins: 16; cor: Tema.alfa(Tema.destaque, 0.5); tamanho: 10 }
    Column {
        anchors.centerIn: parent
        spacing: 8
        Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: "FX // TEST.WINDOW"; color: Tema.destaque }
        Rotulo { anchors.horizontalCenter: parent.horizontalCenter; text: Txt.t("fx.teste.titulo"); tamanho: 22 }
        Leitura {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            horizontalAlignment: Text.AlignHCenter
            tamanho: 12
            text: Txt.t("fx.teste.texto")
        }
        BarraSegmentada { width: 300; height: 6; valor: 1 }
    }
}
