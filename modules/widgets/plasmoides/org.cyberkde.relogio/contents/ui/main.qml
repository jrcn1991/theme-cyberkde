import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Relógio: hora HUD com segundos e data, um segundo fuso opcional, o calendário do mês e os
// próximos eventos (pelos plugins de eventos do calendário do Plasma: agenda do KDE, feriados, eventos
// astronômicos). Sem plugin de eventos, só o calendário.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- hora (alinhada ao segundo)
    property date agora: new Date()
    Timer {
        id: tique
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { raiz.agora = new Date(); interval = 1000 - (Date.now() % 1000) + 5 }
    }
    readonly property bool doze: cfg.formato === "12" || (cfg.formato !== "24" && /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat)))
    function dois(n) { return (n < 10 ? "0" : "") + n }
    function hhmm(d) { const h = d.getHours(); return dois(doze ? (h % 12 || 12) : h) + ":" + dois(d.getMinutes()) }
    function ampm(d) { return doze ? (d.getHours() < 12 ? "AM" : "PM") : "" }
    function deslocamento(min) { const s = min < 0 ? "−" : "+"; min = Math.abs(min); return "UTC" + s + dois(Math.floor(min / 60)) + ":" + dois(min % 60) }
    readonly property string dataLonga: agora.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    readonly property string dataCurta: agora.toLocaleDateString(Qt.locale(), "ddd d MMM").replace(/\./g, "").toUpperCase()

    // ---- segundo fuso (motor "time" do Plasma: deslocamento e cidade do fuso)
    readonly property string fuso2: (cfg.fuso2 || "").trim()
    P5Support.DataSource {
        id: fonteHora
        engine: "time"
        connectedSources: raiz.fuso2 !== "" ? [raiz.fuso2] : []
        interval: 60000
    }
    readonly property var dadosFuso2: fuso2 !== "" ? fonteHora.data[fuso2] : undefined
    readonly property bool temFuso2: !!dadosFuso2 && dadosFuso2["Offset"] !== undefined
    readonly property date agora2: temFuso2 ? new Date(agora.getTime() + (agora.getTimezoneOffset() * 60 + dadosFuso2["Offset"]) * 1000) : agora
    readonly property string rotuloFuso2: ((cfg.rotulo2 || "").trim() || (temFuso2 ? (dadosFuso2["Timezone City"] || fuso2.split("/").pop()).replace(/_/g, " ") : fuso2)).toUpperCase()
    readonly property int difFuso2: temFuso2 ? Math.round((dadosFuso2["Offset"] / 60 + agora.getTimezoneOffset()) / 60) : 0

    // ---- calendário e eventos
    property date mesExibido: new Date()
    property date diaEscolhido: new Date()
    property date hojeData: new Date()
    onAgoraChanged: if (agora.getDate() !== hojeData.getDate()) { hojeData = new Date(agora); diaEscolhido = new Date(agora) }
    PlasmaCalendar.EventPluginsManager { id: gerente }
    PlasmaCalendar.Calendar {
        id: cal
        days: 7; weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek % 7
        today: raiz.hojeData
        displayedDate: raiz.mesExibido
    }
    property int versaoAgenda: 0
    Connections { target: cal.daysModel; function onAgendaUpdated(d) { raiz.versaoAgenda++ } }
    // o calendário pede os eventos quando a data exibida muda: depois de ligar os plugins, recarrega
    function ligarPlugins() { gerente.enabledPlugins = cfg.pluginsEventos || []; Qt.callLater(recarregar) }
    function recarregar() {
        const d = mesExibido
        cal.displayedDate = new Date(d.getFullYear(), d.getMonth() + 1, 1)
        cal.displayedDate = Qt.binding(() => raiz.mesExibido)
    }
    Connections { target: raiz.cfg; function onPluginsEventosChanged() { raiz.ligarPlugins() } }
    readonly property bool temPlugins: (cfg.pluginsEventos || []).length > 0
    function eventos(d) { return versaoAgenda >= 0 && cal.daysModel ? cal.daysModel.eventsForDate(d) || [] : [] }
    // do dia escolhido em diante (no que o calendário carregou: o mês exibido e as bordas)
    readonly property var proximos: {
        versaoAgenda
        let l = []
        const ini = new Date(diaEscolhido.getFullYear(), diaEscolhido.getMonth(), diaEscolhido.getDate())
        for (let i = 0; i < 21 && l.length < 12; i++) {
            const d = new Date(ini.getFullYear(), ini.getMonth(), ini.getDate() + i)
            for (const e of eventos(d))
                l.push({ dia: d, titulo: e.title, todoDia: e.isAllDay, inicio: e.startDateTime, cor: e.eventColor || "" })
        }
        return l
    }
    function mudarMes(delta) { mesExibido = new Date(mesExibido.getFullYear(), mesExibido.getMonth() + delta, 1) }
    function voltarHoje() { mesExibido = new Date(agora); diaEscolhido = new Date(agora) }

    toolTipMainText: hhmm(agora) + (doze ? " " + ampm(agora) : "")
    toolTipSubText: dataLonga + (temFuso2 ? " · " + rotuloFuso2 + " " + hhmm(agora2) : "")

    // ---- tamanho na área de trabalho: livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: {
        if (cfg.modo !== modo) cfg.modo = modo
        cal.daysModel.setPluginsManager(gerente)
        ligarPlugins()
    }
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // ---- hora grande (cartão e moldura)
    component Hora: Item {
        id: hora
        property real tamanho: 40
        implicitWidth: linha.implicitWidth
        implicitHeight: linha.implicitHeight
        Row {
            id: linha
            spacing: 4
            NumeroCintilante {
                id: hm
                valor: raiz.hhmm(raiz.agora)
                font.family: Cores.fIdentidade; font.pixelSize: hora.tamanho; font.weight: Font.Bold
                color: Cores.texto
            }
            Column {
                anchors.bottom: hm.bottom; anchors.bottomMargin: hora.tamanho * 0.12
                spacing: 0
                Text {
                    visible: raiz.doze
                    text: raiz.ampm(raiz.agora)
                    font.family: Cores.fMono; font.pixelSize: Math.max(9, hora.tamanho * 0.26); font.bold: true
                    color: Cores.destaque
                }
                Text {
                    visible: raiz.cfg.mostrarSegundos
                    text: raiz.dois(raiz.agora.getSeconds())
                    font.family: Cores.fMono; font.pixelSize: Math.max(10, hora.tamanho * 0.42)
                    color: Cores.destaque
                }
            }
        }
    }

    // cartão enxuto: hora e data
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Hora { tamanho: Math.max(22, Math.min(parent.parent.height * 0.5, parent.parent.width / 5.2)) }
                Codigo { text: raiz.dataCurta; tamanho: 10; color: Cores.destaque }
            }
        }
    }

    // barra: hora
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linhaB.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Text {
                id: linhaB
                anchors.centerIn: parent
                text: raiz.hhmm(raiz.agora) + (raiz.doze ? " " + raiz.ampm(raiz.agora) : "")
                font.family: Cores.fMono; font.pixelSize: 13; font.bold: true
                color: Cores.texto
            }
        }
    }

    // versão completa: partes pelo tamanho real
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("Relógio", "Clock")
            codigo: "CHRONO // " + raiz.deslocamento(-raiz.agora.getTimezoneOffset())
            // faixas: hora e data sempre; + 2º fuso; + calendário (≥ 300 de altura útil); + eventos (o resto)
            readonly property real h: area.height
            readonly property bool cabeFuso: raiz.temFuso2 && h >= 120
            readonly property bool cabeCal: h >= 300 && area.width >= 210
            readonly property real altCal: Math.min(240, Math.max(190, h - 110 - (cabeFuso ? 30 : 0) - 120))
            readonly property bool cabeEventos: cabeCal && h - 110 - (cabeFuso ? 30 : 0) - altCal - 20 >= 70

            Column {
                anchors.fill: parent
                spacing: 8

                // hora e data
                Column {
                    width: parent.width
                    spacing: 2
                    Hora { tamanho: Math.max(30, Math.min(64, mold.area.width / 5.5, mold.h * 0.3)) }
                    Leitura { width: parent.width; text: raiz.dataLonga; tamanho: 13; color: Cores.texto2; wrapMode: Text.NoWrap; elide: Text.ElideRight }
                }

                // segundo fuso
                Item {
                    visible: mold.cabeFuso
                    width: parent.width; height: visible ? 22 : 0
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Cores.linha }
                    Codigo { y: 6; text: raiz.rotuloFuso2; tamanho: 10; color: Cores.secundaria; width: parent.width - 150 }
                    Row {
                        y: 4; anchors.right: parent.right
                        spacing: 8
                        Text { text: raiz.hhmm(raiz.agora2) + (raiz.doze ? " " + raiz.ampm(raiz.agora2) : ""); font.family: Cores.fMono; font.pixelSize: 13; font.bold: true; color: Cores.texto }
                        Codigo {
                            anchors.verticalCenter: parent.verticalCenter
                            tamanho: 9
                            text: (raiz.difFuso2 >= 0 ? "+" : "−") + Math.abs(raiz.difFuso2) + "H"
                                  + (raiz.agora2.getDate() !== raiz.agora.getDate() ? (raiz.agora2 > raiz.agora ? raiz.t(" · AMANHÃ", " · TOMORROW") : raiz.t(" · ONTEM", " · YESTERDAY")) : "")
                        }
                    }
                }

                // calendário
                Calendario {
                    visible: mold.cabeCal
                    width: parent.width; height: visible ? mold.altCal : 0
                    mes: raiz.mesExibido
                    hoje: raiz.hojeData
                    selecionado: raiz.diaEscolhido
                    versao: raiz.versaoAgenda
                    temEvento: (d) => raiz.eventos(d).length > 0
                    onEscolher: (d) => raiz.diaEscolhido = d
                    onMudarMes: (dl) => raiz.mudarMes(dl)
                    onVoltarHoje: raiz.voltarHoje()
                }

                // próximos eventos
                Column {
                    visible: mold.cabeEventos
                    width: parent.width
                    spacing: 4
                    Item {
                        width: parent.width; height: 14
                        Codigo { text: raiz.t("PRÓXIMOS EVENTOS", "UPCOMING EVENTS"); tamanho: 9; color: Cores.destaque }
                        Rectangle { x: 130; width: parent.width - 130; height: 1; anchors.verticalCenter: parent.verticalCenter; color: Cores.linha }
                    }
                    Leitura {
                        visible: raiz.proximos.length === 0
                        width: parent.width; tamanho: 12; color: Cores.texto3
                        text: !raiz.temPlugins ? raiz.t("Ligue uma fonte de eventos na configuração.", "Turn on an event source in the settings.")
                                               : raiz.t("Nenhum evento nos próximos dias.", "No events in the coming days.")
                    }
                    Repeater {
                        model: raiz.proximos.slice(0, Math.max(0, Math.floor((mold.h - 110 - (mold.cabeFuso ? 30 : 0) - mold.altCal - 46) / 22)))
                        Item {
                            required property var modelData
                            width: parent.width; height: 18
                            Rectangle { width: 3; height: 12; anchors.verticalCenter: parent.verticalCenter; color: modelData.cor !== "" ? modelData.cor : Cores.secundaria }
                            Codigo {
                                x: 9; width: 78; anchors.verticalCenter: parent.verticalCenter; tamanho: 9
                                text: modelData.dia.toLocaleDateString(Qt.locale(), "ddd d").replace(/\./g, "").toUpperCase()
                                      + " " + (modelData.todoDia ? "" : raiz.hhmm(modelData.inicio))
                                color: Cores.texto2
                            }
                            Text {
                                x: 90; width: parent.width - 90; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.titulo; elide: Text.ElideRight
                                font.family: Cores.fTexto; font.pixelSize: 12; color: Cores.texto
                            }
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: Tamanhos {
        modo: raiz.modo
        pedido: raiz.pedidoPreset
        aplicarAoIniciar: !raiz.cfg.ajustado
        onPresetAplicado: if (!raiz.cfg.ajustado) raiz.cfg.ajustado = true
        onEscolherPreset: (m) => raiz.mudarModo(m)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        limiteCartao: Qt.size(230, 150)
        tamanhoPequeno: Qt.size(240, 96)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 19, Kirigami.Units.gridUnit * 22)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 19, Kirigami.Units.gridUnit * 31)
    }
}
