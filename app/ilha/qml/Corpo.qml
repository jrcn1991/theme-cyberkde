import QtQuick

// A ilha aberta: cabeçalho e o painel da aba. Arrastando algo por cima, o alvo de soltar.
Column {
    id: co
    property var ui
    width: parent ? parent.width : 488
    Cabeca { width: parent.width; ui: co.ui; aba: co.ui.aba; visible: !co.ui.arrastando && !co.ui.trilho; onEscolher: (id) => co.ui.escolherAba(id) }
    Row {
        visible: !co.ui.arrastando
        width: parent.width
    Trilho { visible: co.ui.trilho; ui: co.ui; height: pagina.height }
    Loader {
        id: pagina
        width: co.width - (co.ui.trilho ? 112 : 0)
        height: item ? item.implicitHeight : 0
        sourceComponent: co.ui.aba === "inicio" ? cInicio : co.ui.aba === "modulos" ? cModulos : cListas
    }
    }
    Component { id: cInicio; PainelInicio { ui: co.ui } }
    Component { id: cModulos; PainelModulos { ui: co.ui; foco: co.ui.modFoco; onVoltar: co.ui.focoId = "" } }
    Component { id: cListas; PainelListas { ui: co.ui; qual: co.ui.aba } }
    // ---- soltar
    Item {
        visible: co.ui.arrastando
        width: parent.width; height: 150
        Rectangle { x: 16; y: 16; width: parent.width - 32; height: parent.height - 32; radius: co.ui.tema.raioCartao; color: co.ui.tema.acaoFraca; border.color: co.ui.tema.acao }
        Column {
            anchors.centerIn: parent; spacing: 4
            Glifo { anchors.horizontalCenter: parent.horizontalCenter; nome: "Tray"; tamanho: 22; cor: co.ui.tema.texto }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: co.ui.txt("Guardar na gaveta"); color: co.ui.tema.texto; font.family: co.ui.tema.fonte; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: co.ui.txt("fica na ilha, para arrastar de volta depois"); color: co.ui.tema.texto2; font.family: co.ui.tema.fonte; font.pixelSize: 12 }
        }
    }
}
