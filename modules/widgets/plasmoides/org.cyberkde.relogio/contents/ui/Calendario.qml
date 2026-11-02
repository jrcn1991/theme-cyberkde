import QtQuick
import "comum"

// Mini-calendário do mês: cabeçalho com navegação (◀ mês ano ▶; clique no nome volta a hoje), iniciais
// dos dias e a grade de 6 semanas. Hoje em destaque, o dia escolhido realçado, ponto nos dias com evento.
Item {
    id: c
    property date mes: new Date()                 // qualquer dia do mês exibido
    property date hoje: new Date()
    property date selecionado: new Date()
    property var temEvento: (d) => false          // função data -> bool
    property int versao: 0                        // muda quando a agenda muda (recalcula os pontos)
    signal escolher(date dia)
    signal mudarMes(int delta)
    signal voltarHoje()

    readonly property int primeiroDia: Qt.locale().firstDayOfWeek % 7      // 0 = domingo
    readonly property var dias: {
        const ini = new Date(mes.getFullYear(), mes.getMonth(), 1)
        const desl = (ini.getDay() - primeiroDia + 7) % 7
        let l = []
        for (let i = 0; i < 42; i++) l.push(new Date(mes.getFullYear(), mes.getMonth(), 1 - desl + i))
        return l
    }
    function mesmoDia(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }

    readonly property real altCab: 22
    readonly property real altSemana: 16
    readonly property real cw: width / 7
    readonly property real ch: (height - altCab - altSemana) / 6

    // ---- cabeçalho
    Item {
        width: parent.width; height: c.altCab
        BotaoIcone { glifo: "◀"; tamanho: 20; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; onClicado: c.mudarMes(-1) }
        Rotulo {
            anchors.centerIn: parent
            tamanho: 14
            text: c.mes.toLocaleDateString(Qt.locale(), "MMMM yyyy").toUpperCase()
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: c.voltarHoje() }
        }
        BotaoIcone { glifo: "▶"; tamanho: 20; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; onClicado: c.mudarMes(1) }
    }
    // ---- iniciais dos dias da semana
    Row {
        y: c.altCab
        Repeater {
            model: 7
            Codigo {
                required property int index
                width: c.cw; horizontalAlignment: Text.AlignHCenter
                tamanho: 8
                text: Qt.locale().standaloneDayName((c.primeiroDia + index) % 7, Locale.ShortFormat).replace(".", "").slice(0, 3).toUpperCase()
                color: (c.primeiroDia + index) % 7 === 0 ? Cores.alerta : Cores.texto3
            }
        }
    }
    // ---- grade
    Grid {
        y: c.altCab + c.altSemana
        columns: 7
        Repeater {
            model: c.dias
            Item {
                id: cel
                required property var modelData
                readonly property bool doMes: modelData.getMonth() === c.mes.getMonth()
                readonly property bool ehHoje: c.mesmoDia(modelData, c.hoje)
                readonly property bool escolhido: c.mesmoDia(modelData, c.selecionado)
                readonly property bool evento: c.versao >= 0 && c.temEvento(modelData)
                width: c.cw; height: c.ch
                Rectangle {
                    anchors.fill: parent; anchors.margins: 1
                    color: cel.escolhido ? Cores.alfa(Cores.destaque, 0.2) : (ma.containsMouse ? Cores.alfa(Cores.destaque, 0.08) : "transparent")
                    border.color: cel.ehHoje ? Cores.destaque : "transparent"
                    border.width: 1
                }
                Text {
                    anchors.centerIn: parent
                    text: cel.modelData.getDate()
                    font.family: Cores.fMono; font.pixelSize: Math.max(9, Math.min(13, c.ch * 0.5))
                    font.bold: cel.ehHoje
                    color: cel.ehHoje ? Cores.destaque : cel.doMes ? Cores.texto : Cores.texto3
                }
                Rectangle {
                    visible: cel.evento
                    width: 4; height: 4; rotation: 45
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                    color: Cores.secundaria
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.escolher(cel.modelData) }
            }
        }
    }
}
