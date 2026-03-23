// CyberKDE — relógio grande em Noto Sans Light (não condensada) + data por extenso em português.
import QtQuick
import "."

Item {
    id: root

    property real t: 100000
    property real start: 180
    property var fixedDate: null        // prévias: horário fixo
    property bool alignRight: true
    property int timeSize: 120

    property var now: new Date()
    readonly property var shown: fixedDate ? fixedDate : now
    readonly property bool glitch: CK.factor > 0 && t >= start + 250 && t < start + 310

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Timer {
        interval: 1000
        repeat: true
        running: !root.fixedDate
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function dateText(d) {
        const s = d.toLocaleDateString(Qt.locale("pt_BR"), "dddd, d 'de' MMMM")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    Column {
        id: col
        width: implicitWidth
        anchors.right: root.alignRight ? parent.right : undefined
        spacing: 2

        Reveal {
            t: root.t; start: root.start; dx: root.alignRight ? 8 : -8
            anchors.right: root.alignRight ? parent.right : undefined
            Row {
                spacing: 8
                Rectangle { width: 16; height: 3; color: CK.red; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "HORA LOCAL"
                    color: CK.txt2
                    font.family: CK.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }
            }
        }

        Reveal {
            t: root.t; start: root.start + 40; dur: 240; dx: root.alignRight ? 8 : -8
            anchors.right: root.alignRight ? parent.right : undefined
            Item {
                width: time.implicitWidth
                height: time.implicitHeight - root.timeSize * 0.12
                Text {
                    x: 3; y: -root.timeSize * 0.06
                    visible: root.glitch
                    text: time.text; font: time.font
                    color: CK.alpha(CK.cyan, 0.55)
                }
                Text {
                    x: -3; y: -root.timeSize * 0.06
                    visible: root.glitch
                    text: time.text; font: time.font
                    color: CK.alpha(CK.red, 0.55)
                }
                Text {
                    id: time
                    y: -root.timeSize * 0.06
                    text: Qt.formatTime(root.shown, "HH:mm")
                    color: CK.txt1
                    font.family: CK.fontUi
                    font.pixelSize: root.timeSize
                    // Noto Sans Regular: a Light não vem instalada no sistema (e o SDDM só vê fontes do sistema)
                    font.weight: Font.Normal
                    font.features: { "tnum": 1 }
                }
            }
        }

        Reveal {
            t: root.t; start: root.start + 90; dx: root.alignRight ? 8 : -8
            anchors.right: root.alignRight ? parent.right : undefined
            Text {
                text: root.dateText(root.shown)
                color: CK.txt2
                font.family: CK.fontUi
                font.pixelSize: 22
            }
        }
    }
}
