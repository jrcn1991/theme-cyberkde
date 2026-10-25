import QtQuick

// Seletor de cor no estilo do tema: quadrado saturação × brilho, faixa de matiz, campo hexadecimal e
// a paleta do UI kit. Edita o destaque ou a secundária (esta só quando o CLI aceita "--secundaria").
// As cores escolhidas recolorem o painel ao vivo (prévia).
Column {
    id: sc
    property real h: 0
    property real sat: 1
    property real val: 1
    property bool editandoSecundaria: false
    property color cor: "#9D2BF5"            // destaque
    property color secundaria: "#5EF6FF"
    property bool mexeuSecundaria: false
    readonly property color _atual: Qt.hsva(h, sat, val, 1)
    spacing: 14

    // posiciona o quadro e a faixa na cor c, sem disparar edição
    property bool _carregando: false
    function _carregar(c) {
        _carregando = true
        const q = Qt.color(c)
        h = Math.max(0, q.hsvHue)
        sat = q.hsvSaturation
        val = q.hsvValue
        campo.text = q.toString().toUpperCase()
        _carregando = false
    }
    function definir(destaque, sec) {
        cor = destaque
        if (sec) secundaria = sec
        mexeuSecundaria = false
        editandoSecundaria = false
        _carregar(destaque)
    }
    // cor clicada na paleta ou digitada: vai para o alvo em edição
    function escolher(c) {
        if (editandoSecundaria) { secundaria = c; mexeuSecundaria = true } else cor = c
        _carregar(c)
    }
    on_AtualChanged: {
        if (_carregando) return
        if (editandoSecundaria) { secundaria = _atual; mexeuSecundaria = true } else cor = _atual
        if (!campo.activeFocus) campo.text = _atual.toString().toUpperCase()
    }
    onEditandoSecundariaChanged: _carregar(editandoSecundaria ? secundaria : cor)

    // alvo: destaque | secundária
    Row {
        spacing: 10
        Repeater {
            model: [
                { sec: false, rotulo: Txt.t("seletor.destaque") },
                { sec: true, rotulo: Txt.t("seletor.secundaria") }
            ]
            Item {
                id: aba
                required property var modelData
                readonly property bool sel: sc.editandoSecundaria === modelData.sec
                readonly property bool ok: !modelData.sec || painel.suporteSecundaria
                width: 190; height: 40
                opacity: ok ? 1 : 0.45
                Chanfro {
                    anchors.fill: parent
                    preenchimento: aba.sel ? Tema.selecao : Tema.entrada
                    borda: aba.sel ? Tema.destaque : Tema.linha
                }
                Rectangle {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    color: aba.modelData.sec ? sc.secundaria : sc.cor
                }
                Column {
                    x: 38; anchors.verticalCenter: parent.verticalCenter
                    Rotulo { text: aba.modelData.rotulo; tamanho: 14 }
                    Codigo { text: (aba.modelData.sec ? sc.secundaria : sc.cor).toString().toUpperCase(); tamanho: 9 }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: aba.ok
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sc.editandoSecundaria = aba.modelData.sec
                }
            }
        }
    }
    Leitura {
        visible: !painel.suporteSecundaria
        width: parent.width
        tamanho: 12
        color: Tema.alerta
        text: Txt.t("seletor.semSec")
    }

    Row {
        spacing: 14
        // saturação × brilho
        Item {
            id: quadro
            width: 260; height: 180
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#FFFFFF" }
                    GradientStop { position: 1; color: Qt.hsva(sc.h, 1, 1, 1) }
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "#000000" }
                }
            }
            Rectangle { anchors.fill: parent; color: "transparent"; border.color: Tema.linha }
            Item {
                x: sc.sat * quadro.width - 8; y: (1 - sc.val) * quadro.height - 8
                width: 16; height: 16
                Rectangle { anchors.centerIn: parent; width: 16; height: 1; color: Tema.texto }
                Rectangle { anchors.centerIn: parent; width: 1; height: 16; color: Tema.texto }
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; color: sc._atual; border.color: Tema.escuro }
            }
            MouseArea {
                anchors.fill: parent
                function pegar(m) {
                    sc.sat = Math.max(0, Math.min(1, m.x / width))
                    sc.val = Math.max(0, Math.min(1, 1 - m.y / height))
                }
                onPressed: (m) => pegar(m)
                onPositionChanged: (m) => pegar(m)
            }
        }
        // matiz
        Item {
            id: faixa
            width: 22; height: 180
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.000; color: "#FF0000" }
                    GradientStop { position: 0.167; color: "#FFFF00" }
                    GradientStop { position: 0.333; color: "#00FF00" }
                    GradientStop { position: 0.500; color: "#00FFFF" }
                    GradientStop { position: 0.667; color: "#0000FF" }
                    GradientStop { position: 0.833; color: "#FF00FF" }
                    GradientStop { position: 1.000; color: "#FF0000" }
                }
            }
            Rectangle { y: sc.h * faixa.height - 2; x: -4; width: faixa.width + 8; height: 4; color: "transparent"; border.color: Tema.texto; border.width: 1 }
            MouseArea {
                anchors.fill: parent
                function pegar(m) { sc.h = Math.max(0, Math.min(0.999, m.y / height)) }
                onPressed: (m) => pegar(m)
                onPositionChanged: (m) => pegar(m)
            }
        }
        // amostra e campo
        Column {
            spacing: 10
            Item {
                width: 150; height: 70
                Chanfro { anchors.fill: parent; preenchimento: sc._atual; borda: Tema.linha; corte: 10 }
            }
            Codigo { text: "HEX"; tamanho: 9 }
            Item {
                width: 150; height: 34
                Chanfro { anchors.fill: parent; preenchimento: Tema.entrada; borda: campo.activeFocus ? Tema.secundaria : Tema.linha }
                TextInput {
                    id: campo
                    anchors.fill: parent; anchors.leftMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tema.fMono; font.pixelSize: 14
                    color: Tema.texto
                    selectByMouse: true
                    maximumLength: 7
                    validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{0,6}/ }
                    onTextEdited: {
                        const t = text.startsWith("#") ? text : "#" + text
                        if (/^#[0-9A-Fa-f]{6}$/.test(t)) sc.escolher(t)
                    }
                }
            }
            Leitura {
                width: 150; tamanho: 11; color: Tema.texto3
                text: Txt.t("seletor.nota")
            }
        }
    }

    // paleta do UI kit
    Row {
        spacing: 8
        Codigo { text: Txt.t("corp.paleta"); tamanho: 9; anchors.verticalCenter: parent.verticalCenter; width: 52 }
        Repeater {
            model: painel.paletaKit
            Rectangle {
                required property string modelData
                width: 30; height: 22
                color: modelData
                border.color: sc._atual.toString().toUpperCase() === modelData ? Tema.texto : "transparent"
                border.width: 2
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sc.escolher(parent.modelData) }
            }
        }
    }
}
