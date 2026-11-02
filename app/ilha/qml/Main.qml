import QtQuick

// A ilha: uma janela por tela escolhida (ilha.telas). O resto está em JanelaIlha e Gota.
Instantiator {
    id: raiz
    model: ilha ? ilha.telas : []
    // as janelas saem antes do contexto: depois dele, todo binding em "ilha" daria TypeError
    property var _saida: Connections { target: Qt.application; function onAboutToQuit() { raiz.active = false } }
    delegate: JanelaIlha {
        required property var modelData
        tela: modelData
    }
}
