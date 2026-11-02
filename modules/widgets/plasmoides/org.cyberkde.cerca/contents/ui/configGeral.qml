import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "anim/catalogo.js" as Catalogo
import "anim/catalogoIcones.js" as CatIcones

// Configuração do Cyber Fence: pasta, título, como recolher, tamanho dos ícones e aparência.
KCM.SimpleKCM {
    id: pag
    property string cfg_modo
    property string cfg_modoDefault
    property int cfg_opacidade
    property int cfg_opacidadeDefault
    property string cfg_url
    property string cfg_urlDefault
    property string cfg_titulo
    property string cfg_tituloDefault
    property string cfg_tipoCerca
    property string cfg_tipoCercaDefault
    property string cfg_cor
    property string cfg_corDefault
    property string cfg_animacao
    property string cfg_animacaoDefault
    property string cfg_animacaoIcones
    property string cfg_animacaoIconesDefault
    property string cfg_filtroTipo
    property string cfg_filtroTipoDefault
    property bool cfg_blur
    property bool cfg_blurDefault
    property bool cfg_quickhideExcluir
    property bool cfg_quickhideExcluirDefault
    property bool cfg_popups
    property bool cfg_popupsDefault
    property string cfg_abas
    property string cfg_abasDefault
    property string cfg_layout
    property string cfg_layoutDefault
    property string cfg_densidade
    property string cfg_densidadeDefault
    property string cfg_cliques
    property string cfg_cliquesDefault
    property bool cfg_gestoOcultar
    property bool cfg_gestoOcultarDefault
    property string cfg_soltar
    property string cfg_soltarDefault
    property string cfg_base
    property string cfg_baseDefault
    property string cfg_gatilho
    property string cfg_gatilhoDefault
    property int cfg_iconSize
    property int cfg_iconSizeDefault
    property bool cfg_previews
    property bool cfg_previewsDefault
    property bool cfg_showHiddenFiles
    property bool cfg_showHiddenFilesDefault

    readonly property bool en: !Qt.locale().name.toLowerCase().startsWith("pt")
    function t(pt, ing) { return en ? ing : pt }

    FolderDialog {
        id: dlg
        onAccepted: pag.cfg_url = decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""))
    }
    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: t("Pasta:", "Folder:")
            QQC2.TextField {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                text: pag.cfg_url
                placeholderText: t("Downloads", "Downloads")
                onTextEdited: pag.cfg_url = text.trim()
            }
            QQC2.Button { icon.name: "folder-open"; text: t("Escolher…", "Choose…"); onClicked: dlg.open() }
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Título:", "Title:")
            text: pag.cfg_titulo
            placeholderText: t("o nome da pasta", "the folder name")
            onTextEdited: pag.cfg_titulo = text
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Tipo:", "Type:")
            readonly property var ids: ["pasta", "lista"]
            model: [t("Pasta", "Folder"), t("Lista de atalhos e arquivos", "List of shortcuts and files")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_tipoCerca))
            onActivated: (i) => pag.cfg_tipoCerca = ids[i]
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Mais abas:", "More tabs:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            text: pag.cfg_abas
            placeholderText: t("pastas separadas por ;", "folders separated by ;")
            onTextEdited: pag.cfg_abas = text
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Mostrar só:", "Show only:")
            readonly property var ids: ["todos", "imagens", "documentos", "audio", "video", "pastas"]
            model: [t("Tudo", "Everything"), t("Imagens", "Images"), t("Documentos", "Documents"), t("Áudio", "Audio"), t("Vídeo", "Video"), t("Pastas", "Folders")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_filtroTipo))
            onActivated: (i) => pag.cfg_filtroTipo = ids[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Cor:", "Color:")
            readonly property var ids: ["destaque", "secundaria", "alerta"]
            model: [t("Destaque", "Accent"), t("Secundária", "Secondary"), t("Alerta", "Alert")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_cor))
            onActivated: (i) => pag.cfg_cor = ids[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Animação (todas as cercas):", "Animation (all fences):")
            readonly property var lista: Catalogo.lista()
            model: lista.map(v => pag.en ? v.nome_en : v.nome)
            currentIndex: Math.max(0, lista.findIndex(v => v.id === pag.cfg_animacao))
            onActivated: (i) => pag.cfg_animacao = lista[i].id
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Animação dos ícones (todas):", "Icon animation (all):")
            readonly property var lista: CatIcones.lista()
            model: lista.map(v => pag.en ? v.nome_en : v.nome)
            currentIndex: Math.max(0, lista.findIndex(v => v.id === pag.cfg_animacaoIcones))
            onActivated: (i) => pag.cfg_animacaoIcones = lista[i].id
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Layout:", "Layout:")
            readonly property var ids: ["grade", "dados", "inventario"]
            model: [t("Grade", "Grid"), t("Dados (lista)", "Data (list)"), t("Inventário", "Inventory")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_layout))
            onActivated: (i) => pag.cfg_layout = ids[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Densidade:", "Density:")
            readonly property var ids: ["grade", "compacta"]
            model: [t("Grade", "Grid"), t("Compacta", "Compact")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_densidade))
            onActivated: (i) => pag.cfg_densidade = ids[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Abrir com:", "Open with:")
            readonly property var ids: ["sistema", "um", "dois"]
            model: [t("Padrão do KDE", "KDE default"), t("1 clique", "1 click"), t("2 cliques (1 clique seleciona, Enter abre)", "2 clicks (1 click selects, Enter opens)")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_cliques))
            onActivated: (i) => pag.cfg_cliques = ids[i]
        }
        QQC2.CheckBox { text: t("Duplo clique na mesa oculta as cercas", "Double-click on the desktop hides fences"); checked: pag.cfg_gestoOcultar; onToggled: pag.cfg_gestoOcultar = checked }
        QQC2.CheckBox { text: t("Desfocar o fundo", "Blur the background"); checked: pag.cfg_blur; onToggled: pag.cfg_blur = checked }
        QQC2.CheckBox { text: t("Não ocultar com as outras", "Do not hide with the others"); checked: pag.cfg_quickhideExcluir; onToggled: pag.cfg_quickhideExcluir = checked }
        QQC2.CheckBox { text: t("Abrir subpastas em popup", "Open subfolders in a popup"); checked: pag.cfg_popups; onToggled: pag.cfg_popups = checked }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Ao soltar arquivos:", "When dropping files:")
            readonly property var ids: ["mover", "perguntar"]
            model: [t("Mover direto (Ctrl copia)", "Move right away (Ctrl copies)"), t("Perguntar", "Ask")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_soltar))
            onActivated: (i) => pag.cfg_soltar = ids[i]
        }
        QQC2.TextField {
            Kirigami.FormData.label: t("Pasta das cercas novas:", "Folder for new fences:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            text: pag.cfg_base
            placeholderText: t("Documentos/Cercas", "Documents/Cercas")
            onTextEdited: pag.cfg_base = text.trim()
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Recolher com:", "Roll up with:")
            readonly property var ids: ["ctrl", "clique", "sair"]
            model: [t("Ctrl+clique no título", "Ctrl+click on the title"), t("Clique no título", "Click on the title"), t("Ao sair o mouse", "When the mouse leaves")]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_gatilho))
            onActivated: (i) => pag.cfg_gatilho = ids[i]
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Preset de tamanho:", "Size preset:")
            model: [t("Pequeno", "Small"), t("Médio", "Medium"), t("Grande", "Large")]
            readonly property var ids: ["pequeno", "medio", "grande"]
            currentIndex: Math.max(0, ids.indexOf(pag.cfg_modo))
            onActivated: (i) => pag.cfg_modo = ids[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: t("Ícones:", "Icons:")
            model: ["22", "32", "48", "64", "96"]
            currentIndex: Math.min(4, pag.cfg_iconSize)
            onActivated: (i) => pag.cfg_iconSize = i
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: t("Opacidade do fundo:", "Background opacity:")
            from: 60; to: 100; stepSize: 5
            textFromValue: (v) => v + "%"
            valueFromText: (s) => parseInt(s)
            value: pag.cfg_opacidade
            onValueModified: pag.cfg_opacidade = value
        }
        QQC2.CheckBox { text: t("Miniaturas dos arquivos", "File thumbnails"); checked: pag.cfg_previews; onToggled: pag.cfg_previews = checked }
        QQC2.CheckBox { text: t("Mostrar arquivos ocultos", "Show hidden files"); checked: pag.cfg_showHiddenFiles; onToggled: pag.cfg_showHiddenFiles = checked }
    }
}
