import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · Clima: tempo atual, previsão por hora e de 5 dias (Open-Meteo, sem chave).
// Cidade na configuração (busca por nome). Cores da corporação; movimento do tema.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    // cidade vazia (padrão do CLI): fica a última resolvida (São Paulo de início)
    readonly property string nomeCidade: (cfg.cidade || "").trim() || cfg.cidadeResolvida
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- dados
    property var atual: null      // { temp, sensacao, umidade, vento, direcao, codigo, dia, chuva }
    property var horas: []        // [{ hora, temp, codigo, chuva, dia }]
    property var dias: []         // [{ data, max, min, codigo, chuva }]
    property string erro: ""
    property bool carregando: false
    property date atualizado: new Date(0)

    function nomeCondicao(c) {
        const T = en ? {
            0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
            61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain",
            71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains", 80: "Showers", 81: "Showers",
            82: "Violent showers", 85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Storm with hail", 99: "Storm with hail"
        } : {
            0: "Céu limpo", 1: "Quase limpo", 2: "Parcialmente nublado", 3: "Encoberto", 45: "Neblina", 48: "Nevoeiro gelado",
            51: "Garoa fraca", 53: "Garoa", 55: "Garoa forte", 56: "Garoa congelante", 57: "Garoa congelante",
            61: "Chuva fraca", 63: "Chuva", 65: "Chuva forte", 66: "Chuva congelante", 67: "Chuva congelante",
            71: "Neve fraca", 73: "Neve", 75: "Neve forte", 77: "Grãos de neve", 80: "Pancadas", 81: "Pancadas",
            82: "Pancadas fortes", 85: "Pancadas de neve", 86: "Pancadas de neve", 95: "Trovoada", 96: "Trovoada com granizo", 99: "Trovoada com granizo"
        }
        return T[c] !== undefined ? T[c] : "—"
    }
    function rosa(graus) {
        const p = en ? ["N", "NE", "E", "SE", "S", "SW", "W", "NW"] : ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
        return p[Math.round(((graus % 360) / 45)) % 8]
    }
    function diaSemana(iso) {
        const d = new Date(iso + "T12:00:00")
        return d.toLocaleDateString(Qt.locale(), "ddd").replace(".", "").toUpperCase()
    }

    function buscar() {
        if (carregando) return
        carregando = true
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + cfg.latitude + "&longitude=" + cfg.longitude
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,is_day,precipitation"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=6&forecast_hours=13&wind_speed_unit=kmh"
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            carregando = false
            if (xhr.status !== 200) { erro = t("Sem sinal da estação (", "No signal from station (") + xhr.status + ")"; return }
            try {
                const j = JSON.parse(xhr.responseText)
                const c = j.current
                atual = { temp: c.temperature_2m, sensacao: c.apparent_temperature, umidade: c.relative_humidity_2m,
                          vento: c.wind_speed_10m, direcao: c.wind_direction_10m, codigo: c.weather_code, dia: c.is_day === 1,
                          chuva: c.precipitation }
                let h = []
                for (let i = 1; i < j.hourly.time.length && h.length < 12; i++)
                    h.push({ hora: j.hourly.time[i].slice(11, 16), temp: j.hourly.temperature_2m[i], codigo: j.hourly.weather_code[i],
                             chuva: j.hourly.precipitation_probability[i] || 0, dia: j.hourly.is_day[i] === 1 })
                horas = h
                let d = []
                for (let i = 0; i < j.daily.time.length && d.length < 5; i++)
                    d.push({ data: j.daily.time[i], max: j.daily.temperature_2m_max[i], min: j.daily.temperature_2m_min[i],
                             codigo: j.daily.weather_code[i], chuva: j.daily.precipitation_probability_max[i] || 0 })
                dias = d
                erro = ""
                atualizado = new Date()
            } catch (e) {
                erro = t("Resposta ilegível da estação", "Unreadable station reply")
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }
    // cidade gravada só pelo nome (CLI): resolve no geocoding e grava as coordenadas
    readonly property bool precisaResolver: (cfg.cidade || "").trim() !== "" && cfg.cidade !== cfg.cidadeResolvida
    function resolver() {
        const partes = cfg.cidade.split(",").map(x => x.trim())
        const nome = partes[0], filtro = partes.slice(1).join(" ").toLowerCase()
        const pedida = cfg.cidade
        carregando = true
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            carregando = false
            if (pedida !== cfg.cidade) return            // mudou no meio do caminho
            let r = []
            try { r = JSON.parse(xhr.responseText).results || [] } catch (e) {}
            if (xhr.status !== 200) { erro = t("Sem sinal do serviço de busca (", "No signal from search service (") + xhr.status + ")"; return }
            const ok = filtro ? r.find(x => [x.admin1, x.country, x.country_code].some(v => v && filtro.includes(String(v).toLowerCase()))) || r[0] : r[0]
            if (!ok) { erro = t("Cidade não encontrada: ", "City not found: ") + cfg.cidade; return }
            cfg.latitude = ok.latitude
            cfg.longitude = ok.longitude
            cfg.regiao = [ok.admin1, ok.country].filter(x => !!x).join(", ")
            cfg.cidadeResolvida = cfg.cidade
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=10&format=json&language=" + (en ? "en" : "pt")
                 + "&name=" + encodeURIComponent(nome))
        xhr.send()
    }
    Timer {
        interval: Math.max(10, raiz.cfg.intervaloMin) * 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: raiz.precisaResolver ? raiz.resolver() : raiz.buscar()
    }
    Connections {
        target: raiz.cfg
        function onLatitudeChanged() { atrasoBusca.restart() }
        function onLongitudeChanged() { atrasoBusca.restart() }
        function onCidadeChanged() { if (raiz.precisaResolver) atrasoResolver.restart() }
    }
    Timer { id: atrasoResolver; interval: 400; onTriggered: raiz.resolver() }
    Timer { id: atrasoBusca; interval: 300; onTriggered: raiz.buscar() }

    readonly property real minSemana: dias.length ? Math.min(...dias.map(x => x.min)) : 0
    readonly property real maxSemana: dias.length ? Math.max(...dias.map(x => x.max)) : 1
    function graus(v) { return v === undefined || v === null ? "--" : Math.round(v) + "°" }

    toolTipMainText: nomeCidade
    toolTipSubText: atual ? graus(atual.temp) + " · " + nomeCondicao(atual.codigo) : ""

    // ---- tamanho na área de trabalho: livre (a geometria do applet, redimensionável no modo de edição);
    //      P/M/G são presets, e "modo" guarda o último escolhido. Na barra, a forma compacta de sempre.
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    // valores antigos: compacto → pequeno, completo → grande
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0                  // muda a cada escolha de preset (até a mesma de novo)
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                IconeClima {
                    width: 48; height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    codigo: raiz.atual ? raiz.atual.codigo : 3
                    dia: raiz.atual ? raiz.atual.dia : true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    NumeroCintilante {
                        valor: raiz.atual ? raiz.graus(raiz.atual.temp) : "--°"
                        font.family: Cores.fIdentidade; font.pixelSize: 26; font.weight: Font.Bold
                        color: Cores.texto
                    }
                    Codigo { text: raiz.nomeCidade.toUpperCase(); tamanho: 9; color: Cores.destaque; width: Math.min(implicitWidth, 130) }
                }
            }
        }
    }

    Component {
        id: compactoBarra
    MouseArea {
        Layout.minimumWidth: linhaC.implicitWidth + 8
        onClicked: raiz.expanded = !raiz.expanded
        Row {
            id: linhaC
            anchors.centerIn: parent
            spacing: 4
            IconeClima {
                width: Math.min(parent.parent.height, 28); height: width
                codigo: raiz.atual ? raiz.atual.codigo : 3
                dia: raiz.atual ? raiz.atual.dia : true
                animar: false
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: raiz.atual ? raiz.graus(raiz.atual.temp) : "--°"
                font.family: Cores.fIdentidade; font.pixelSize: 13; font.bold: true
                color: Cores.texto
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- área de trabalho (completo)
    }

    // ---- médio e grande (a mesma moldura; o médio mostra menos partes)
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            // pelo tamanho real: o tempo agora sempre; com altura, as próximas horas; com mais, a previsão,
            // com quantos dias couberem (2 a 5)
            readonly property real h: area.height
            readonly property int nDias: Math.max(0, Math.min(5, Math.floor((h - (cabeHoras ? 192 : 112) - 30) / 25)))
            readonly property bool cabeDias: nDias >= 2
            readonly property bool cabeHoras: h >= 180
            readonly property bool estreito: area.width < 330
            titulo: raiz.t("Clima", "Weather")
            codigo: "WX.SYS // " + raiz.nomeCidade.toUpperCase()
            extra: [
                BotaoIcone { glifo: "↻"; tamanho: 20; dica: raiz.t("Atualizar", "Refresh"); onClicado: raiz.buscar() }
            ]

            Column {
                anchors.fill: parent
                spacing: 10

                // erro / carregando
                Leitura {
                    visible: raiz.erro !== "" || (!raiz.atual && raiz.carregando)
                    width: parent.width
                    color: raiz.erro !== "" ? Cores.alerta : Cores.texto2
                    text: raiz.erro !== "" ? raiz.erro : raiz.t("Sintonizando a estação…", "Tuning in to the station…")
                }

                // atual
                Item {
                    visible: !!raiz.atual
                    width: parent.width; height: 84
                    IconeClima {
                        id: grande
                        width: mold.estreito ? 52 : 72; height: width
                        anchors.verticalCenter: parent.verticalCenter
                        codigo: raiz.atual ? raiz.atual.codigo : 0
                        dia: raiz.atual ? raiz.atual.dia : true
                    }
                    Column {
                        x: grande.width + 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        NumeroCintilante {
                            valor: raiz.atual ? raiz.graus(raiz.atual.temp) : "--°"
                            font.family: Cores.fIdentidade; font.pixelSize: mold.estreito ? 30 : 38; font.weight: Font.Bold
                            color: Cores.texto
                        }
                        Leitura { text: raiz.atual ? raiz.nomeCondicao(raiz.atual.codigo) : ""; tamanho: 13; color: Cores.texto; wrapMode: Text.NoWrap }
                        Row {
                            spacing: 8
                            Codigo { text: "MAX " + (raiz.dias.length ? raiz.graus(raiz.dias[0].max) : "--"); color: Cores.destaque; tamanho: 10 }
                            Codigo { text: "MIN " + (raiz.dias.length ? raiz.graus(raiz.dias[0].min) : "--"); color: Cores.secundaria; tamanho: 10 }
                        }
                    }
                    // telemetria à direita
                    Grid {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        columns: 2; columnSpacing: 10; rowSpacing: 4
                        Codigo { text: raiz.t("UMID", "HUM") }
                        NumeroCintilante { valor: raiz.atual ? raiz.atual.umidade + "%" : "--"; font.pixelSize: 11; color: Cores.texto }
                        Codigo { text: raiz.t("VENTO", "WIND") }
                        NumeroCintilante { valor: raiz.atual ? Math.round(raiz.atual.vento) + " km/h " + raiz.rosa(raiz.atual.direcao) : "--"; font.pixelSize: 11; color: Cores.texto }
                        Codigo { text: raiz.t("SENS", "FEELS") }
                        NumeroCintilante { valor: raiz.atual ? raiz.graus(raiz.atual.sensacao) : "--"; font.pixelSize: 11; color: Cores.texto }
                        Codigo { text: raiz.t("CHUVA", "RAIN") }
                        NumeroCintilante { valor: raiz.dias.length ? raiz.dias[0].chuva + "%" : "--"; font.pixelSize: 11; color: raiz.dias.length && raiz.dias[0].chuva >= 70 ? Cores.alerta : Cores.texto }
                    }
                }

                Rectangle { visible: !!raiz.atual; width: parent.width; height: 1; color: Cores.linha }

                // próximas horas
                Column {
                    visible: raiz.cfg.mostrarHoras && raiz.horas.length > 0 && mold.cabeHoras
                    width: parent.width
                    spacing: 4
                    Codigo { text: raiz.t("PRÓXIMAS HORAS", "NEXT HOURS") }
                    Row {
                        id: linhaHoras
                        width: parent.width
                        // uma coluna a cada ~44 px, no máximo 12
                        readonly property int n: Math.max(1, Math.min(raiz.horas.length, Math.floor(width / 44)))
                        Repeater {
                            model: raiz.horas.slice(0, linhaHoras.n)
                            Column {
                                required property var modelData
                                width: linhaHoras.width / linhaHoras.n
                                spacing: 2
                                Codigo { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hora; tamanho: 8 }
                                IconeClima { anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; codigo: modelData.codigo; dia: modelData.dia; animar: false }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: raiz.graus(modelData.temp); font.family: Cores.fMono; font.pixelSize: 10; color: Cores.texto }
                                Rectangle {   // probabilidade de chuva
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width * 0.6; height: 3
                                    color: Cores.alfa(Cores.secundaria, 0.15)
                                    Rectangle { width: parent.width * modelData.chuva / 100; height: parent.height; color: modelData.chuva >= 70 ? Cores.alerta : Cores.secundaria }
                                }
                            }
                        }
                    }
                }

                // 5 dias
                Column {
                    visible: raiz.dias.length > 0 && mold.cabeDias
                    width: parent.width
                    spacing: 3
                    Codigo { text: raiz.t("PREVISÃO · ", "FORECAST · ") + Math.min(mold.nDias, raiz.dias.length) + raiz.t(" DIAS", " DAYS") }
                    Repeater {
                        model: raiz.dias.slice(0, mold.nDias)
                        Item {
                            id: linhaDia
                            required property var modelData
                            required property int index
                            width: parent.width; height: 22
                            Codigo { width: 34; text: index === 0 ? raiz.t("HOJE", "TODAY") : raiz.diaSemana(modelData.data); color: index === 0 ? Cores.destaque : Cores.texto2; tamanho: 10; anchors.verticalCenter: parent.verticalCenter }
                            IconeClima { x: 38; width: 20; height: 20; codigo: modelData.codigo; animar: false; anchors.verticalCenter: parent.verticalCenter }
                            Codigo { x: 64; width: 34; text: modelData.chuva + "%"; tamanho: 9; color: modelData.chuva >= 70 ? Cores.alerta : Cores.texto3; anchors.verticalCenter: parent.verticalCenter }
                            Text { x: 100; width: 30; horizontalAlignment: Text.AlignRight; text: raiz.graus(modelData.min); font.family: Cores.fMono; font.pixelSize: 10; color: Cores.secundaria; anchors.verticalCenter: parent.verticalCenter }
                            // faixa mín–máx na escala da semana
                            Item {
                                x: 136; width: parent.width - 136 - 36; height: 6
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property real esc: Math.max(1, raiz.maxSemana - raiz.minSemana)
                                Rectangle { anchors.fill: parent; color: Cores.alfa(Cores.linha, 0.6) }
                                Rectangle {
                                    x: parent.width * (modelData.min - raiz.minSemana) / parent.esc
                                    width: Math.max(4, parent.width * (modelData.max - modelData.min) / parent.esc)
                                    height: parent.height
                                    gradient: Gradient { orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Cores.secundaria }
                                        GradientStop { position: 1; color: Cores.destaque } }
                                }
                            }
                            Text { anchors.right: parent.right; width: 30; horizontalAlignment: Text.AlignRight; text: raiz.graus(modelData.max); font.family: Cores.fMono; font.pixelSize: 10; color: Cores.destaque; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Codigo {
                    visible: !!raiz.atual && mold.h >= 120
                    text: raiz.t("ATUALIZADO ", "UPDATED ") + raiz.atualizado.toLocaleTimeString(Qt.locale(), "HH:mm") + " · OPEN-METEO · " + raiz.cfg.regiao.toUpperCase()
                    tamanho: 8
                    width: parent.width
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
        limiteCartao: Qt.size(260, 150)
        naMesa: raiz.naMesa
        opacidade: raiz.opac
        pequeno: cartaoPequeno
        completo: painelCompleto
        tamanhoPequeno: Qt.size(224, 80)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 20, Kirigami.Units.gridUnit * 14)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 20, Kirigami.Units.gridUnit * 23)
    }

}
