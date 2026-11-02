import QtQuick

Column {
    id: v
    property var ui
    property string glifo: "Tray"
    property string texto: ""
    width: parent ? parent.width : 300
    spacing: 8
    topPadding: 24; bottomPadding: 24
    Glifo { anchors.horizontalCenter: parent.horizontalCenter; nome: v.glifo; tamanho: 22; cor: v.ui.tema.texto3 }
    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: v.texto; color: v.ui.tema.texto3; font.family: v.ui.tema.fonte; font.pixelSize: 13 }
}
