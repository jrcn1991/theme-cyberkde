// Paleta PADRÃO (Arasaka), só para o widget abrir fora do tema. O install_widgets
// (modules/widgets/phase.sh) grava por cima a paleta aplicada; o "cor"/"corp" a regrava.
pragma Singleton
import QtQuick

QtObject {
    readonly property color destaque: "#F75049"
    readonly property color secundaria: "#DCDCE4"
    readonly property color alerta: "#FB932E"
    readonly property color fundo: "#0E0E17"
    readonly property color superficie: "#12121C"
    readonly property color painel: "#181824"
    readonly property color elevado: "#1F1F2E"
    readonly property color texto: "#DCDCE4"
    readonly property color textoSecundario: "#A9A9BA"
    readonly property color textoDesativado: "#76768A"
    readonly property color linha: "#343442"
    readonly property color textoSobreDestaque: "#0E0E17"
    readonly property string corp: "nenhuma"
}
