import QtQuick
import "comum"

// Cabeçalho de seção: código técnico e um fio até a borda; à direita, um resumo opcional.
Item {
    id: s
    property string texto: ""
    property string resumo: ""
    property color corResumo: Cores.texto2
    width: parent ? parent.width : 200
    height: 14
    Codigo { id: c; text: s.texto; tamanho: 9; color: Cores.destaque; anchors.verticalCenter: parent.verticalCenter }
    Rectangle {
        x: c.width + 6; width: s.width - x - (rs.text ? rs.width + 6 : 0)
        height: 1; color: Cores.linha
        anchors.verticalCenter: parent.verticalCenter
    }
    Codigo { id: rs; anchors.right: parent.right; text: s.resumo; tamanho: 9; color: s.corResumo; anchors.verticalCenter: parent.verticalCenter }
}
