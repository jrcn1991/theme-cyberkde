import QtQuick
import "../../qml"

// Abas chanfradas: ◆ título ×; a ativa com marcador no destaque. Clique ativa, botão do meio fecha,
// "+" abre a pasta atual numa aba nova. Soltar arquivos numa aba = soltar na pasta dela. Arrastar a
// própria aba para os lados reordena (moverAba), com um traço onde ela vai cair.

Item {
    id: b
    height: 30
    property int arrastandoDe: -1
    property real desloc: 0
    property int alvo: -1
    function alvoEm(xRow) {
        let k = 0
        for (let i = 0; i < rep.count; i++) { const t = rep.itemAt(i); if (t && xRow > t.x + t.width / 2) k = i + 1 }
        return k
    }
    Row {
        id: fila
        x: 12; height: parent.height
        spacing: 4
        Repeater {
            id: rep
            model: arquivos.abas
            Item {
                id: a
                required property int index
                required property var modelData
                readonly property bool ativa: arquivos.abaAtual === index
                width: Math.min(220, tit.implicitWidth + 58); height: 26
                anchors.bottom: parent.bottom
                z: b.arrastandoDe === index ? 5 : 0
                opacity: b.arrastandoDe === index ? 0.85 : 1
                transform: Translate { x: b.arrastandoDe === a.index ? b.desloc : 0 }
                Chanfro {
                    anchors.fill: parent
                    corte: 6
                    preenchimento: alvo.sobre ? Tema.alfa(Tema.destaque, 0.3) : a.ativa ? Tema.alfa(Tema.destaque, 0.14) : (ma.containsMouse ? Tema.hover : Tema.alfa(Tema.painel, 0.8))
                    borda: a.ativa ? Tema.destaque : Tema.alfa(Tema.destaque, 0.35)
                }
                Rectangle { visible: a.ativa; x: 0; y: 6; width: 3; height: parent.height - 12; color: Tema.destaque }
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "◆"; font.pixelSize: 8; color: a.ativa ? Tema.destaque : Tema.texto3 }
                Text {
                    id: tit
                    x: 24; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 160)
                    // na tela dividida, a aba ativa mostra a pasta do LADO ATIVO (como no Dolphin)
                    readonly property var fonte: a.ativa && arquivos.dividido && arquivos.aba ? arquivos.aba : a.modelData
                    text: fonte.titulo + (fonte.carregando ? " …" : "")
                    elide: Text.ElideMiddle
                    font.family: Tema.fTexto; font.pixelSize: 12
                    color: a.ativa ? Tema.texto : Tema.texto2
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    preventStealing: true
                    property real x0: 0
                    property bool arrastou: false
                    onPressed: (e) => { x0 = e.x; arrastou = false }
                    onPositionChanged: (e) => {
                        if (!(e.buttons & Qt.LeftButton) || arquivos.abas.length < 2) return
                        if (b.arrastandoDe < 0 && Math.abs(e.x - x0) > 8) { b.arrastandoDe = a.index; arrastou = true }
                        if (b.arrastandoDe === a.index) { b.desloc = e.x - x0; b.alvo = b.alvoEm(mapToItem(fila, e.x, 0).x) }
                    }
                    onReleased: {
                        if (b.arrastandoDe !== a.index) return
                        const de = a.index, para = b.alvo > de ? b.alvo - 1 : b.alvo
                        b.arrastandoDe = -1; b.desloc = 0; b.alvo = -1
                        if (para >= 0 && para !== de) arquivos.moverAba(de, para)
                    }
                    onClicked: (e) => { if (arrastou) return; if (e.button === Qt.MiddleButton) arquivos.fecharAba(a.index); else arquivos.abaAtual = a.index }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                    text: "×"; font.pixelSize: 14
                    color: fx.containsMouse ? Tema.alerta : Tema.texto3
                    visible: arquivos.abas.length > 1
                    MouseArea { id: fx; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: arquivos.fecharAba(a.index) }
                    DicaTexto { texto: Ds.t("aba.fechar"); sobre: fx.containsMouse }
                }
                AlvoSoltar { id: alvo; anchors.fill: parent; destino: a.modelData.ehLixeira || a.modelData.ehRecentes ? "" : a.modelData.caminho }
            }
        }
        Item {
            width: 26; height: 26
            anchors.bottom: parent.bottom
            z: -1
            Chanfro { anchors.fill: parent; corte: 5; preenchimento: mn.containsMouse ? Tema.hover : "transparent"; borda: Tema.alfa(Tema.destaque, 0.4) }
            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 15; color: Tema.destaque }
            MouseArea { id: mn; anchors.fill: parent; hoverEnabled: true; onClicked: arquivos.novaAba("") }
            DicaTexto { texto: Ds.t("aba.nova") + " · " + ((arquivos.atalhos || {}).novaAba || ""); sobre: mn.containsMouse }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Tema.alfa(Tema.destaque, 0.5) }
    // onde a aba arrastada vai cair
    Rectangle {
        visible: b.arrastandoDe >= 0 && b.alvo >= 0
        readonly property var ref: rep.itemAt(Math.min(b.alvo, rep.count - 1))
        x: fila.x + (ref ? (b.alvo >= rep.count ? ref.x + ref.width + 2 : ref.x - 3) : 0)
        y: 2; width: 2; height: parent.height - 4
        color: Tema.secundaria
    }
}
