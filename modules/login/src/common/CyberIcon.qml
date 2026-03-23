// CyberKDE — ícones vetoriais de traço (desenhados numa grade de 18 px e escalados).
// Não dependem do tema de ícones: o SDDM roda como outro usuário e não enxerga o tema do usuário.
import QtQuick
import QtQuick.Shapes
import "."

Item {
    id: root

    property string name: ""
    property color color: CK.txt1
    property real lineWidth: 1.75

    implicitWidth: 18
    implicitHeight: 18

    readonly property real s: width / 18

    function p(v) { return v * s }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.name) {
            case "power": return powerC
            case "reboot": return rebootC
            case "suspend": return suspendC
            case "hibernate": return hibernateC
            case "arrow": return arrowC
            case "down": return downC
            case "left": return leftC
            case "right": return rightC
            case "warn": return warnC
            case "lock": return lockC
            case "user": return userC
            case "session": return sessionC
            default: return null
            }
        }
    }

    Component {
        id: powerC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: root.p(9); centerY: root.p(10); radiusX: root.p(6.5); radiusY: root.p(6.5); startAngle: -55; sweepAngle: 290 }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                startX: root.p(9); startY: root.p(1.5)
                PathLine { x: root.p(9); y: root.p(9) }
            }
        }
    }

    Component {
        id: rebootC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: root.p(9); centerY: root.p(9.5); radiusX: root.p(6.5); radiusY: root.p(6.5); startAngle: -40; sweepAngle: 300 }
            }
            ShapePath {
                strokeColor: "transparent"; fillColor: root.color
                startX: root.p(7.4); startY: root.p(0.6)
                PathLine { x: root.p(11.2); y: root.p(2.6) }
                PathLine { x: root.p(8.3); y: root.p(5.7) }
                PathLine { x: root.p(7.4); y: root.p(0.6) }
            }
        }
    }

    Component {
        id: suspendC   // lua crescente
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                startX: root.p(8.7); startY: root.p(2.0)
                PathArc { x: root.p(15.9); y: root.p(10.4); radiusX: root.p(7); radiusY: root.p(7); useLargeArc: true; direction: PathArc.Counterclockwise }
                PathArc { x: root.p(8.7); y: root.p(2.0); radiusX: root.p(5.5); radiusY: root.p(5.5); useLargeArc: false; direction: PathArc.Clockwise }
            }
        }
    }

    Component {
        id: hibernateC  // seta para dentro de uma base
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                startX: root.p(9); startY: root.p(2)
                PathLine { x: root.p(9); y: root.p(11) }
                PathMove { x: root.p(5); y: root.p(7.5) }
                PathLine { x: root.p(9); y: root.p(11.5) }
                PathLine { x: root.p(13); y: root.p(7.5) }
                PathMove { x: root.p(3); y: root.p(15.5) }
                PathLine { x: root.p(15); y: root.p(15.5) }
            }
        }
    }

    Component {
        id: arrowC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
                startX: root.p(2.5); startY: root.p(9)
                PathLine { x: root.p(15); y: root.p(9) }
                PathMove { x: root.p(10); y: root.p(4) }
                PathLine { x: root.p(15); y: root.p(9) }
                PathLine { x: root.p(10); y: root.p(14) }
            }
        }
    }

    Component {
        id: downC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
                startX: root.p(4); startY: root.p(6.5)
                PathLine { x: root.p(9); y: root.p(11.5) }
                PathLine { x: root.p(14); y: root.p(6.5) }
            }
        }
    }

    Component {
        id: leftC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
                startX: root.p(11.5); startY: root.p(4)
                PathLine { x: root.p(6.5); y: root.p(9) }
                PathLine { x: root.p(11.5); y: root.p(14) }
            }
        }
    }

    Component {
        id: rightC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
                startX: root.p(6.5); startY: root.p(4)
                PathLine { x: root.p(11.5); y: root.p(9) }
                PathLine { x: root.p(6.5); y: root.p(14) }
            }
        }
    }

    Component {
        id: warnC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: root.p(9); startY: root.p(2)
                PathLine { x: root.p(16.5); y: root.p(15.5) }
                PathLine { x: root.p(1.5); y: root.p(15.5) }
                PathLine { x: root.p(9); y: root.p(2) }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                startX: root.p(9); startY: root.p(6.5)
                PathLine { x: root.p(9); y: root.p(11) }
                PathMove { x: root.p(9); y: root.p(12.4) }
                PathLine { x: root.p(9); y: root.p(14) }
            }
        }
    }

    Component {
        id: lockC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                startX: root.p(5); startY: root.p(9)
                PathLine { x: root.p(5); y: root.p(6.5) }
                PathArc { x: root.p(13); y: root.p(6.5); radiusX: root.p(4); radiusY: root.p(4) }
                PathLine { x: root.p(13); y: root.p(9) }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: root.p(3); startY: root.p(9)
                PathLine { x: root.p(15); y: root.p(9) }
                PathLine { x: root.p(15); y: root.p(14) }
                PathLine { x: root.p(13); y: root.p(16) }
                PathLine { x: root.p(3); y: root.p(16) }
                PathLine { x: root.p(3); y: root.p(9) }
            }
        }
    }

    Component {
        id: userC
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                PathAngleArc { centerX: root.p(9); centerY: root.p(6); radiusX: root.p(3.5); radiusY: root.p(3.5); startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: root.p(9); centerY: root.p(17); radiusX: root.p(6.5); radiusY: root.p(6); startAngle: 180; sweepAngle: 180 }
            }
        }
    }

    Component {
        id: sessionC   // monitor
        Shape {
            antialiasing: true
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: root.p(2); startY: root.p(3)
                PathLine { x: root.p(16); y: root.p(3) }
                PathLine { x: root.p(16); y: root.p(11) }
                PathLine { x: root.p(14); y: root.p(13) }
                PathLine { x: root.p(2); y: root.p(13) }
                PathLine { x: root.p(2); y: root.p(3) }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: root.lineWidth; fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                startX: root.p(6); startY: root.p(16)
                PathLine { x: root.p(12); y: root.p(16) }
            }
        }
    }
}
