import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "corps.js" as Corps

// Configuração do papel FUI (Configurar a área de trabalho → Papel de parede).
Kirigami.FormLayout {
    id: raiz
    property string cfg_Corporacao
    property int cfg_Intensidade
    property int cfg_Velocidade
    property bool cfg_MostrarLogo
    property bool cfg_MostrarTextos
    property string cfg_CorLogo
    property int cfg_FpsMax
    property bool cfg_PausarCoberto
    property string cfg_Movimento
    readonly property bool en: Qt.locale().name.indexOf("pt") !== 0
    function tr(pt, en) { return raiz.en ? en : pt }

    QQC2.ComboBox {
        Kirigami.FormData.label: raiz.tr("Corporação:", "Corporation:")
        model: Corps.lista().map(c => ({ id: c.id, nome: c.nomeExibido }))
        textRole: "nome"; valueRole: "id"
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(raiz.cfg_Corporacao))
        onActivated: raiz.cfg_Corporacao = currentValue
    }
    RowLayout {
        Kirigami.FormData.label: raiz.tr("Intensidade dos feixes:", "Beam intensity:")
        QQC2.Slider { from: 30; to: 200; stepSize: 5; value: raiz.cfg_Intensidade; onMoved: raiz.cfg_Intensidade = value; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
        QQC2.Label { text: raiz.cfg_Intensidade + "%" }
    }
    RowLayout {
        Kirigami.FormData.label: raiz.tr("Velocidade dos feixes:", "Beam speed:")
        QQC2.Slider { from: 25; to: 300; stepSize: 5; value: raiz.cfg_Velocidade; onMoved: raiz.cfg_Velocidade = value; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
        QQC2.Label { text: raiz.cfg_Velocidade + "%" }
    }
    QQC2.CheckBox { Kirigami.FormData.label: raiz.tr("Mostrar:", "Show:"); text: raiz.tr("Logo e emblema da corporação", "Corporation logo and emblem"); checked: raiz.cfg_MostrarLogo; onToggled: raiz.cfg_MostrarLogo = checked }
    QQC2.CheckBox { text: raiz.tr("Logo na cor original", "Logo in its original color"); checked: raiz.cfg_CorLogo === "original"; onToggled: raiz.cfg_CorLogo = checked ? "original" : "tingido" }
    QQC2.CheckBox { text: raiz.tr("Textos técnicos da lateral", "Side technical text"); checked: raiz.cfg_MostrarTextos; onToggled: raiz.cfg_MostrarTextos = checked }
    QQC2.ComboBox {
        Kirigami.FormData.label: raiz.tr("Quadros por segundo (máx.):", "Frames per second (max):")
        model: [30, 60]
        currentIndex: raiz.cfg_FpsMax >= 60 ? 1 : 0
        onActivated: raiz.cfg_FpsMax = currentIndex === 1 ? 60 : 30
    }
    QQC2.CheckBox {
        Kirigami.FormData.label: raiz.tr("Economia:", "Power saving:")
        text: raiz.tr("Pausar com janela maximizada ou em tela cheia", "Pause under maximized or fullscreen windows")
        checked: raiz.cfg_PausarCoberto; onToggled: raiz.cfg_PausarCoberto = checked
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: raiz.tr("Movimento:", "Motion:")
        readonly property var valores: ["auto", "completo", "reduzido", "minimo"]
        model: [raiz.tr("Seguir o sistema", "Follow the system"), raiz.tr("Completo", "Full"), raiz.tr("Reduzido", "Reduced"), raiz.tr("Mínimo (parado)", "Minimal (still)")]
        currentIndex: Math.max(0, valores.indexOf(raiz.cfg_Movimento))
        onActivated: raiz.cfg_Movimento = valores[currentIndex]
    }
}
