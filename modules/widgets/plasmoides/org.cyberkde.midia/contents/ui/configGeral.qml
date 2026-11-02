import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

// Configuração da Mídia: player preferido, visualizador e volume.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property string cfg_preferir
    property bool cfg_mostrarVisualizador
    property bool cfg_mostrarVolume
    property string cfg_estilo
    property string cfg_estiloDefault
    property bool cfg_espectroReal
    property bool cfg_espectroRealDefault
    property bool cfg_paletaJukebox
    property bool cfg_paletaJukeboxDefault
    property bool cfg_ignorarNavegadores
    property bool cfg_ignorarNavegadoresDefault
    property string cfg_ignorados
    property string cfg_ignoradosDefault
    property string cfg_preferirDefault
    property bool cfg_mostrarVisualizadorDefault
    property bool cfg_mostrarVolumeDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }

    // o espectro real precisa do pw-record (ou parec) e do numpy: sem eles, a opção fica desligada
    property bool podeReal: false
    property string motivoReal: ""
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["command -v pw-record >/dev/null 2>&1 || command -v parec >/dev/null 2>&1 || { echo captura; exit; }; python3 -c 'import numpy' 2>/dev/null && echo ok || echo numpy"]
        onNewData: (f, d) => { const v = (d.stdout || "").trim(); pag.podeReal = v === "ok"; pag.motivoReal = v; disconnectSource(f) }
    }
    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Estilo:", "Style:")
            readonly property var ids: ["hud", "jukebox", "mini", "eq", "neon"]
            model: ["HUD", "JUKEBOX", "JUKEBOX MINI", t("SÓ EQUALIZADOR", "EQUALIZER ONLY"), t("RÁDIO NEON", "NEON RADIO")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_estilo))
            onActivated: (i) => pag.cfg_estilo = ids[i]
        }
        QQC2.CheckBox {
            text: t("Espectro real (lê o som que está tocando; gasta CPU)", "Real spectrum (reads what is playing; uses CPU)")
            enabled: pag.podeReal
            checked: pag.cfg_espectroReal && pag.podeReal
            onToggled: pag.cfg_espectroReal = checked
        }
        QQC2.Label {
            text: pag.podeReal ? t("Desligado, o equalizador é sintético: anima só tocando, sem ler o áudio.", "Off, the equalizer is synthetic: it animates only while playing, without reading audio.")
                 : pag.motivoReal === "numpy" ? t("Indisponível: falta o numpy (sudo apt install python3-numpy).", "Unavailable: numpy is missing (sudo apt install python3-numpy).")
                 : t("Indisponível: falta o pw-record (PipeWire) ou o parec (sudo apt install pipewire-bin).", "Unavailable: pw-record (PipeWire) or parec is missing (sudo apt install pipewire-bin).")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            opacity: 0.7
        }
        QQC2.CheckBox {
            text: t("Cores do jukebox do jogo (laranja e verde-água)", "The game's jukebox colors (orange and teal)")
            checked: pag.cfg_paletaJukebox
            onToggled: pag.cfg_paletaJukebox = checked
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Preset de tamanho:", "Size preset:")
            model: [t("Pequeno", "Small"), t("Médio", "Medium"), t("Grande", "Large")]
            readonly property var ids: ["pequeno", "medio", "grande"]
            currentIndex: Math.max(0, ids.indexOf(({ compacto: "pequeno", completo: "grande" })[pag.cfg_modo] || pag.cfg_modo))
            onActivated: (i) => pag.cfg_modo = ids[i]
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Opacidade do fundo:", "Background opacity:")
            from: 30; to: 100; stepSize: 5
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_opacidade
            onValueModified: pag.cfg_opacidade = value
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.TextField {
            Kirigami.FormData.label: t("Player preferido:", "Preferred player:")
            text: pag.cfg_preferir
            placeholderText: "spotify"
            onTextEdited: pag.cfg_preferir = text.trim().toLowerCase()
        }
        QQC2.Label {
            text: t("Nome do player no MPRIS (spotify, vlc, elisa, firefox…). Vazio ou ausente: o player ativo.",
                    "Player name in MPRIS (spotify, vlc, elisa, firefox…). Empty or missing: the active player.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            opacity: 0.7
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: t("Navegadores:", "Browsers:")
            text: t("Ignorar a mídia dos navegadores", "Ignore media from browsers")
            checked: pag.cfg_ignorarNavegadores
            onToggled: pag.cfg_ignorarNavegadores = checked
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Players ignorados:", "Ignored players:")
            text: pag.cfg_ignorados
            placeholderText: "kdeconnect, mpv"
            onTextEdited: pag.cfg_ignorados = text
        }
        QQC2.Label {
            text: t("Nomes separados por vírgula (como aparecem no MPRIS). Com tudo ignorado, o widget mostra \"sem mídia\".",
                    "Names separated by commas (as they appear in MPRIS). With everything ignored, the widget shows \"no media\".")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            opacity: 0.7
        }
        QQC2.CheckBox { text: t("Visualizador de áudio (decorativo)", "Audio visualizer (decorative)"); checked: pag.cfg_mostrarVisualizador; onToggled: pag.cfg_mostrarVisualizador = checked }
        QQC2.CheckBox { text: t("Controle de volume", "Volume control"); checked: pag.cfg_mostrarVolume; onToggled: pag.cfg_mostrarVolume = checked }
    }
}
