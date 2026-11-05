import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Configuração do papel em vídeo (Configurar a área de trabalho → Papel de parede). O normal é escolher
// pelo painel do CyberKDE (seção da pasta de papéis); aqui dá para trocar à mão.
Kirigami.FormLayout {
    id: raiz
    property string cfg_Video
    property string cfg_Reserva
    property string cfg_Preenchimento
    property bool cfg_PausarCoberto
    property bool cfg_PausarBloqueio
    property string cfg_Movimento
    readonly property bool en: Qt.locale().name.indexOf("pt") !== 0
    function tr(pt, en) { return raiz.en ? en : pt }

    RowLayout {
        Kirigami.FormData.label: raiz.tr("Vídeo:", "Video:")
        QQC2.Label {
            text: raiz.cfg_Video ? decodeURIComponent(raiz.cfg_Video.toString().replace(/^.*\//, "")) : raiz.tr("(nenhum)", "(none)")
            elide: Text.ElideMiddle
            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
        }
        QQC2.Button { text: raiz.tr("Escolher…", "Choose…"); onClicked: dialogo.open() }
    }
    Dialogs.FileDialog {
        id: dialogo
        nameFilters: [raiz.tr("Vídeos", "Videos") + " (*.mp4 *.webm *.mkv *.mov)"]
        onAccepted: raiz.cfg_Video = selectedFile.toString()
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: raiz.tr("Preenchimento:", "Fill:")
        model: [
            { id: "cortar", nome: raiz.tr("Preencher e recortar", "Fill and crop") },
            { id: "ajustar", nome: raiz.tr("Inteiro, com faixas", "Fit, with bars") },
            { id: "esticar", nome: raiz.tr("Esticar", "Stretch") }
        ]
        textRole: "nome"; valueRole: "id"
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(raiz.cfg_Preenchimento))
        onActivated: raiz.cfg_Preenchimento = currentValue
    }
    QQC2.CheckBox { Kirigami.FormData.label: raiz.tr("Pausar:", "Pause:"); text: raiz.tr("Com janela maximizada ou em tela cheia", "With a maximized or full-screen window"); checked: raiz.cfg_PausarCoberto; onToggled: raiz.cfg_PausarCoberto = checked }
    QQC2.CheckBox { text: raiz.tr("Com a tela bloqueada", "While the screen is locked"); checked: raiz.cfg_PausarBloqueio; onToggled: raiz.cfg_PausarBloqueio = checked }
}
