# Plasmoides do CyberKDE

Onze widgets do Plasma 6 no visual do tema. A instalação, a inserção e a remoção na área de trabalho
ficam com o `modules/widgets/phase.sh` (ver `../CONTRATO-CLI.md`): cada pacote vira sozinho o efeito
`widget-<nome>` pelo bloco `X-CyberKDE` do seu `metadata.json`.

| Pacote | O que mostra | Quem fez | Opções no painel (além de tela, posição, modo e opacidade) |
|---|---|---|---|
| `org.cyberkde.relogio` | hora HUD com segundos e data, 2º fuso, calendário do mês e próximos eventos | Deckard | `fuso2`, `formato`, `segundos` |
| `org.cyberkde.clima` | tempo agora, próximas horas e até 5 dias (Open-Meteo, sem conta) | Deckard | `cidade`, `intervalo` |
| `org.cyberkde.desempenho` | CPU por núcleo, memória, GPU, temperaturas, rede e disco (ksystemstats) | Deckard | `intervalo`, `limiar-cpu`, `limiar-temp` |
| `org.cyberkde.midia` | player MPRIS (Spotify primeiro), capa, progresso, controles e volume | Deckard | `preferir`, `ignorarNavegadores`, `ignorados` |
| `org.cyberkde.notas` | quadro de notas "datashard": cores, fixar, reordenar e checklist | Deckard | `quadro` |
| `org.cyberkde.tarefas` | "gigs": contratos com prioridade, prazo, contratante e status | Deckard | `quadro`, `filtro` |
| `org.cyberkde.cambio` | cotações em "eddies", variação do dia e gráfico | Estilo | `moedas`, `intervalo`, `periodo` |
| `org.cyberkde.discos` | espaço de cada unidade montada, alerta ao encher, E/S ao vivo | Estilo | `montagens`, `limiar` |
| `org.cyberkde.docker` | contêineres com estado, uptime, CPU e memória; iniciar, parar, reiniciar | Rachael | `intervalo`, `parados` |
| `org.cyberkde.rede` | interface, IP, gateway, velocidade, ping, perda e VPN (IP público desligado) | Rachael | `host`, `intervalo-ping`, `ip-publico` |
| `org.cyberkde.rss` | manchetes dos feeds RSS/Atom, com fonte e hora | Rachael | `feeds`, `intervalo` |
| `org.cyberkde.cerca` | **Cyber Fence**: uma pasta numa moldura com título (grade do Folder View da KDE), que recolhe até só o título | Deckard | `pasta`, `titulo`, `gatilho`, `recolher` |

Todos têm tamanho livre com presets P/M/G, modo de edição, a forma compacta da barra, PT/EN e as cores
da corporação.

## Tamanho livre, presets e modo de edição

Fora do modo de edição do Plasma, os widgets mostram só os dados: nenhum controle de edição, e o
conteúdo usa o espaço todo. No modo de edição (botão direito na área de trabalho → "Entrar no modo de
edição"; por comando, `qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.editMode true|false`),
o Plasma mostra as alças nativas de mover e redimensionar, e cada widget mostra no canto de baixo uma
faixa com a alça de seis pontos e os presets P·M·G (S·M·L em inglês), com uma montagem rápida ao
entrar e sair. A faixa fica presa ao contêiner do applet, acima da camada de edição do Plasma (que fica
com os cliques do conteúdo).

- O tamanho REAL é a geometria do applet: redimensionado à mão no modo de edição, fica gravado e o
  widget não o desfaz (na área de trabalho ele não expõe tamanho "preferido", que o Plasma adotaria).
- P/M/G são presets: aplicam um tamanho quando escolhidos (na faixa, na configuração ou com `modo`
  mudado por fora) e na primeira vez que o widget aparece. Ao aplicar, o canto que fica parado é o mais
  perto da borda, sem sair da tela, com posição e tamanho na grade da área de trabalho; a troca anima
  com uma moldura que se redimensiona e o conteúdo que acende (movimento "mínimo": direto). O preset
  que corresponde ao tamanho atual fica aceso; depois de um ajuste manual, nenhum.
- O conteúdo escolhe o que mostrar pelo tamanho real: abaixo de um limite (largura ou altura), o cartão
  enxuto; acima, a moldura, que acrescenta partes por faixas de altura (os do Deckard; os da Rachael e
  do Estilo seguem a mesma regra, com as faixas descritas nos `main.qml` deles):

| Widget | Cartão (abaixo de) | Moldura, por altura útil |
|---|---|---|
| clima | 260×150 | tempo agora; + próximas horas (≥ 180); + previsão com 2 a 5 dias |
| desempenho | 250×150 | barras de CPU, memória, GPU e rede; + disco (≥ 236); gráfico da CPU (≥ 262); + núcleos (≥ 320); + gráfico da rede (≥ 365) |
| mídia | 280×140 | capa, progresso e controles; + álbum, volume e visualizador conforme o espaço |
| notas | 240×170 | o quadro, em quantas colunas couberem (rola) |
| relógio | 230×150 | hora e data; + 2º fuso (≥ 120); + calendário do mês (≥ 300 e largura ≥ 210); + próximos eventos (o que sobrar) |
| gigs | 240×160 | filtros (≥ 120) e a lista de contratos (rola) |

Na barra, nada muda: forma compacta, e o popup mostra o tamanho grande.

`opacidade` (95, de 30 a 100, em %) é a da superfície dos cartões, perto do fundo da corporação.

## Como montar um widget novo

O `comum/` é do Deckard: use os componentes, não os edite. Se faltar algo, peça (pelo Orquestrador).

### Arquivos

```
modules/widgets/plasmoides/org.cyberkde.<nome>/
  metadata.json
  contents/config/main.xml        chaves (as 3 comuns + as suas)
  contents/config/config.qml      categoria da configuração
  contents/ui/main.qml            o widget (esqueleto abaixo)
  contents/ui/configGeral.qml     tela de configuração
  contents/ui/<Partes>.qml        componentes só seus (import "comum" neles também)
```

Os comuns entram em `contents/ui/comum/` na instalação (`install_widgets` do CLI, ou `montar.sh` para
teste); a `Paleta.qml` é gerada ali com as cores da corporação. Não copie o `comum/` para o pacote.

`metadata.json` (troque nome, ícone, categoria e descrições; PT e EN):

```json
{
    "KPlugin": {
        "Id": "org.cyberkde.<nome>",
        "Name": "CyberKDE · <Nome>", "Name[pt_BR]": "CyberKDE · <Nome>", "Name[en]": "CyberKDE · <Name>",
        "Description": "…", "Description[pt_BR]": "…", "Description[en]": "…",
        "Icon": "<ícone do tema>", "Category": "<categoria do Plasma>",
        "Authors": [{ "Name": "CyberKDE" }], "License": "GPL-3.0-or-later", "Version": "1.0",
        "Website": "https://github.com/jrcn1991/theme-cyberkde",
        "FormFactors": ["desktop", "panel"]
    },
    "KPackageStructure": "Plasma/Applet",
    "X-Plasma-API-Minimum-Version": "6.0",
    "X-CyberKDE": {
        "nome": "<Nome>", "nome_en": "<Name>",
        "descricao": "<uma frase>", "descricao_en": "<one sentence>",
        "tamanho": [240, 96],
        "ordem": 100,
        "opcoes": [
            {"id": "<id>", "chave": "<chave do main.xml>", "tipo": "texto", "padrao": "",
             "nome": "<Opção>", "nome_en": "<Option>", "dica": "<formato>", "dica_en": "<format>"}
        ]
    }
}
```

O bloco `X-CyberKDE` registra o widget no CLI e no painel (efeito `widget-<nome>`), sem lista fixa. O
contrato completo está em `../CONTRATO-CLI.md`; em resumo:

- `tamanho`: o de inserção, em px. Use o do seu preset pequeno: o widget aplica o preset de `modo` ao
  aparecer pela primeira vez (`ajustado` = false), e assim ele não pula de tamanho.
- `ordem`: posição na lista do painel (os do tema usam 10 a 80).
- `opcoes`: cada uma vira `cyberkde efeito widget-<nome> --<id> <valor>` e um campo no painel.
  `id` em minúsculas, números e hífen (nunca `tela`, `posicao`, `modo`, `opacidade`, `json`, `lang`,
  `on`, `off`); `chave` precisa existir no `main.xml`; `tipo` é `texto` (com `padrao`), `escolha`
  (`valores: [{id, nome, nome_en}]`; para chave Bool, ids `"true"`/`"false"`) ou `inteiro` (`min`,
  `max`, `padrao`, `unidade`). O `padrao` deve ser o mesmo do `main.xml`.
- Uma lista que a pessoa também edita no widget usa a mesma chave da opção (como `feeds` e `moedas`).
- Confira o registro com `cyberkde efeito --lista --json` (com `XDG_CONFIG_HOME` de teste).

`contents/config/main.xml`: as três chaves comuns sempre, e depois as suas:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.kde.org/standards/kcfg/1.0 http://www.kde.org/standards/kcfg/1.0/kcfg.xsd">
  <kcfgfile name=""/>
  <group name="General">
    <entry name="modo" type="String"><default>pequeno</default></entry>       <!-- último preset -->
    <entry name="opacidade" type="Int"><default>95</default><min>30</min><max>100</max></entry>
    <entry name="ajustado" type="Bool"><default>false</default></entry>       <!-- interno -->
    <!-- as suas chaves aqui; listas em JSON numa String (ver notas) -->
  </group>
</kcfg>
```

`contents/config/config.qml`:

```qml
import QtQuick
import org.kde.plasma.configuration
ConfigModel {
    ConfigCategory {
        name: Qt.locale().name.toLowerCase().startsWith("pt") ? "Geral" : "General"
        icon: "<ícone>"
        source: "configGeral.qml"
    }
}
```

`contents/ui/configGeral.qml`: um `KCM.SimpleKCM` com um `Kirigami.FormLayout`. Para cada chave X do
main.xml declare `property <tipo> cfg_X` e `property <tipo> cfg_XDefault` (inclusive `modo`, `opacidade`
e `ajustado`, mesmo sem campo, ou o Plasma reclama). Copie o de `org.cyberkde.desempenho` como modelo:
ele já tem o "Preset de tamanho" e a "Opacidade do fundo".

### Esqueleto do `main.qml`

```qml
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "comum"

// CyberKDE · <Nome>: o que mostra, de onde vêm os dados.
PlasmoidItem {
    id: raiz
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var cfg: Plasmoid.configuration
    readonly property bool en: Cores.en
    function t(pt, ing) { return en ? ing : pt }

    // ---- dados (sensores, D-Bus, XHR, config…) aqui, na raiz: valem para todas as formas

    toolTipMainText: t("<Nome>", "<Name>")
    toolTipSubText: "<resumo de uma linha>"

    // ---- tamanho na área de trabalho (não mexa): livre, P/M/G são presets
    readonly property bool naMesa: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property string modo: ({ compacto: "pequeno", completo: "grande", pequeno: "pequeno", medio: "medio", grande: "grande" })[cfg.modo] || "pequeno"
    property int pedidoPreset: 0
    function mudarModo(m) { cfg.modo = m; pedidoPreset++ }
    Component.onCompleted: if (cfg.modo !== modo) cfg.modo = modo
    readonly property real opac: Math.max(0.3, Math.min(1, cfg.opacidade / 100))
    preferredRepresentation: naMesa ? fullRepresentation : null
    compactRepresentation: compactoBarra

    // cartão enxuto (tamanhos pequenos): só o essencial, sem controles de edição
    Component {
        id: cartaoPequeno
        CartaoCompacto {
            opacidade: raiz.opac
            // conteúdo (ocupa o cartão todo)
        }
    }

    // forma da BARRA (painel): ícone/valor curto; o clique abre o popup (moldura no tamanho grande)
    Component {
        id: compactoBarra
        MouseArea {
            Layout.minimumWidth: linha.implicitWidth + 8
            onClicked: raiz.expanded = !raiz.expanded
            Row { id: linha; anchors.centerIn: parent; spacing: 4 /* … */ }
        }
    }

    // versão completa: decide o que mostrar pelo TAMANHO REAL (mold.area.width/height), nunca por "modo"
    Component {
        id: painelCompleto
        Moldura {
            id: mold
            opacidade: raiz.opac
            anchors.fill: parent
            titulo: raiz.t("<Nome>", "<Name>")
            codigo: "<COD.TECNICO> // <dado>"
            extra: [ /* BotaoIcone de ações do conteúdo (não de edição) */ ]
            readonly property real h: area.height
            readonly property bool cabeX: h >= 200          // faixas: cada parte entra quando cabe
            Column { anchors.fill: parent; spacing: 7 /* … */ }
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
        limiteCartao: Qt.size(250, 150)            // abaixo disto (largura OU altura): o cartão
        tamanhoPequeno: Qt.size(240, 96)            // presets (px no pequeno; gridUnit nos outros)
        tamanhoMedio: Qt.size(Kirigami.Units.gridUnit * 18, Kirigami.Units.gridUnit * 14)
        tamanhoGrande: Qt.size(Kirigami.Units.gridUnit * 21, Kirigami.Units.gridUnit * 24)
    }
}
```

O `Tamanhos` cuida de tudo da edição: a faixa ⠿ P·M·G no modo de edição, a aplicação dos presets (sem
sair da tela, na grade, com animação), o respeito ao tamanho manual e a troca cartão ↔ moldura.
Não ponha alça, seletor nem outro controle de edição no conteúdo.

### Componentes do `comum/`

| Componente | Para quê | Propriedades principais |
|---|---|---|
| `Cores` (singleton) | cores, ritmo e fontes | `destaque` `secundaria` `alerta` `sucesso` `fundo` `cartao` `painel` `elevado` `linha` `texto` `texto2` `texto3`; `alfa(cor,a)` `mistura(a,b,f)` `papel(nome)`; `d(ms)` (duração no ritmo do tema) `reduzir` (movimento mínimo); `fTitulo` `fIdentidade` `fMono` `fTexto`; `en` |
| `Moldura` | a superfície da versão completa | `titulo` `codigo` `cabecalho` `extra` `area` `margem` `opacidade`; `montar()` |
| `CartaoCompacto` | a superfície do cartão enxuto | `opacidade` `margem`; `montar()` |
| `Tamanhos` | tamanho livre, presets, edição | ver esqueleto |
| `Chanfro` | forma chanfrada | `corte` `preenchimento` `borda` `espessura` `traco` |
| `Cantoneiras` | marcas de canto | `cor` `tamanho` `espessura` |
| `Rotulo` | título curto (fonte do tema) | `tamanho` |
| `Codigo` | código técnico pequeno (mono) | `tamanho` |
| `Leitura` | texto de leitura (fonte do sistema) | `tamanho` |
| `NumeroCintilante` | número que cintila ao mudar | `valor` (texto) `intervaloMin` |
| `BarraSegmentada` | barra em segmentos, alerta acima do limiar | `valor` (0..1) `limiar` `cor` `vertical` `tamSeg` `vao` |
| `GraficoHud` | gráfico de linha HUD | `series: [{valores, cor}]` `maximo` `limiar` |
| `BotaoIcone` | botão chanfrado | `icone` ou `glifo` `ativo` `habilitado` `dica` `tamanho`; `clicado()` |
| `Revelador` | mostrar/esconder com montagem rápida | `alvo` `mostrar` |
| `Alca`, `SeletorTamanho` | usados pelo `Tamanhos` | não use direto |

### Regras

- Cores só de `Cores.*` (que vêm da `Paleta`). Nenhuma cor fixa; texto nunca branco puro (`Cores.texto`).
- Leitura (frases, nomes, listas) na fonte do sistema (`Cores.fTexto`, `Leitura`). Rajdhani/Orbitron só
  em títulos curtos e números grandes (`Rotulo`, `fIdentidade`); códigos em `Codigo`.
- Durações sempre `Cores.d(ms)`; com `Cores.reduzir`, sem animação. Nada animando em repouso (pulsos por
  Timer, não laços infinitos); animações só quando visível.
- Fora do modo de edição, só dados: nenhum controle de edição no conteúdo (o `Tamanhos` cuida disso).
- O conteúdo escolhe o que mostrar pelo tamanho real (faixas de `area.width/height`), do cartão ao
  grande, sem deixar áreas vazias grandes.
- Textos PT e EN pelo `t(pt, en)`.
- Dados persistentes na config do applet (JSON numa String, como `notas`), nunca em arquivo à parte: o
  CLI guarda e devolve a config inteira ao desligar e religar o widget.
- Prévias: `assets/previas/widgets/<nome>.webp` (Arasaka) e `<nome>-militech.webp`, com P, M e G lado a
  lado, fora do modo de edição.

### Testar

Nada na sessão real. Monte com `plasmoides/montar.sh /tmp/<dir> org.cyberkde.<nome>` e rode um
plasmashell (ou `plasmawindowed`) isolado num Xvfb, com `dbus-run-session`, XDG_* em /tmp e SEM
`XDG_SESSION_ID`/`XDG_SEAT`/`XDG_VTNR` (senão o processo de teste fala com a sessão real no logind).
Não use KWin aninhado. Bloqueie no D-Bus isolado (arquivos `.service` com `Exec=/bin/false` em
`$XDG_DATA_HOME/dbus-1/services`) o kded6, o kdeconnect (abre porta), o obex e o evolution. Ao terminar,
confira `loginctl show-session <sessão> -p LockedHint` = no e que nenhum processo de teste sobrou.

## Configuração (grupo `General` do applet)

- **clima**: `cidade` (pode vir só com o nome, até como "Nome, Estado"; o widget a resolve no
  geocoding do Open-Meteo e grava `latitude`, `longitude`, `regiao` e `cidadeResolvida`; vazia, fica
  a última resolvida), `intervaloMin` (30) e `mostrarHoras` (true).
- **desempenho**: `intervalo` (1500 ms); os limiares de alerta `limiarCpu` (85), `limiarMemoria` (85),
  `limiarGpu` (90), `limiarTemp` (85 °C) e `limiarDisco` (90); `gpu` ("auto" ou `gpuN`); e
  `mostrarNucleos`, `mostrarGpu`, `mostrarRede`, `mostrarDisco`.
- **todos**: `modo` (último preset: `pequeno`, `medio` ou `grande`; padrão `pequeno`; aceita os antigos
  `compacto` e `completo`), `opacidade` (95) e `ajustado` (interno: o preset inicial já foi aplicado).
- **cerca** (Cyber Fence): `url` (a pasta: caminho, `~/…` ou `file:///…`; vazio = Downloads; `desktop:/` vira a pasta real da
  área de trabalho, porque `desktop:/` não lança nem percebe arquivo novo), `titulo` (vazio = o nome da pasta),
  `gatilho` (`ctrl`, padrão; `clique` no título; `sair`, ao sair o mouse), `IsRolled` (a opção `recolher`, ao vivo), e as chaves do Folder View (`iconSize`,
  `previews`, `sortMode`, `showHiddenFiles`…). Internas: `UnrolledHeight` e `RolledY`. Os arquivos
  `Folder*.qml`, `RenameEditor`, `ActionButton`, `BackButtonItem` e `code/FolderTools.js` derivam do
  `org.kde.desktopcontainment` (GPL-2.0-or-later, com os cabeçalhos originais) e usam o módulo privado
  `org.kde.private.desktopcontainment.folder`: reconferir a cada Plasma novo.
- **mídia**: `preferir` ("spotify", o DesktopEntry do MPRIS), `ignorarNavegadores` (padrão ligado: esconde a mídia de Chrome/Chromium, Firefox, Edge, Brave, Opera, Vivaldi, Epiphany, Falkon e da integração do Plasma com o navegador, pela DesktopEntry, Identity ou serviço MPRIS), `ignorados` (outros nomes, separados por vírgula), `mostrarVisualizador` e `mostrarVolume`. Com tudo ignorado, o widget mostra "sem mídia".
- **relógio**: `formato` (`auto`, `24` ou `12`), `mostrarSegundos` (true), `fuso2` (nome IANA, ex.:
  `America/New_York`; vazio = desligado), `rotulo2` (vazio = a cidade do fuso) e `pluginsEventos`
  (StringList com os plugins de eventos do calendário do Plasma: `pimevents`, a agenda do KDE, que
  precisa do pacote PIM; `holidaysevents`; `astronomicalevents`; padrão `pimevents`). Sem plugin que
  responda, só o calendário.
- **gigs** (`org.cyberkde.tarefas`): `quadro` (nome da lista), `filtro` (`ativos`, `andamento`,
  `concluidos` ou `todos`) e `tarefas`, um JSON com `[{id, titulo, prioridade: baixa|media|alta|critica,
  prazo: "AAAA-MM-DD" ou "", contratante, status: aberto|andamento|concluido, criada, concluida}]`.
  Prioridade nas cores da Paleta (baixa: texto; média: secundária; alta: destaque; crítica: alerta).
  JSON ilegível: a lista fica só leitura.
- **câmbio** (Estilo): `moedas` ("USD-BRL, EUR-BRL, BTC-BRL"; pares separados por vírgula, "USD"
  sozinho = USD-BRL, o primeiro é o principal), `intervaloMin` (10, de 5 a 60), `periodo` ("7" ou "30"
  dias do gráfico), `grafico` (par do gráfico; vazio = o principal) e `cache` (interno).
- **discos** (Estilo): `montagens` (pontos de montagem separados por vírgula; vazio = os reais),
  `limiar` (90 %, de 50 a 99) e `intervalo` (30 s, de 5 a 600; leitura do espaço).
- **docker** (Rachael): `intervalo` (10 s, de 3 a 300) e `mostrarParados` (true).
- **rede** (Rachael): `host` do ping ("1.1.1.1"), `intervaloPing` (5 s, de 2 a 60), `ipPublico` (false;
  consulta a api.ipify.org) e `demonstracao` (interno, dados fictícios para prévias).
- **rss** (Rachael): `feeds` (endereços separados por espaço, quebra de linha ou `|`), `intervaloMin`
  (30, de 5 a 240) e `lidas` (interno: as notícias já lidas).
- **notas**: `quadro` (o nome do quadro), `larguraCartao` (170) e `notas`, um JSON com
  `[{id, texto, cor: destaque|secundaria|alerta, fixada, checklist, criada}]`. No checklist, cada
  linha é um item, e `[x] ` marca o item feito. Se o JSON não puder ser lido, o quadro fica só leitura
  e não grava nada por cima.

## Comum

`../comum/` tem os componentes de todos os widgets (moldura chanfrada, barras segmentadas, gráfico HUD,
números que cintilam…) e o singleton `Cores`, que lê as cores da `Paleta`. A `Paleta.qml` daqui é só a
padrão (Arasaka): o `install_widgets` grava por cima a paleta aplicada. Os tempos seguem o
AnimationDurationFactor do KDE; com o movimento em "mínimo", nada anima.

`montar.sh DESTINO [id…]` monta os pacotes com o `comum/` dentro, para testar fora do CLI.
