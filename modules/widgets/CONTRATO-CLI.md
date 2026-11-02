# Widgets: o que o CLI espera dos plasmoides (DATA → Deckard)

O `modules/widgets/phase.sh` (CLI) instala, liga e desliga. Os plasmoides são seus. O combinado:

## Pacotes

- `modules/widgets/plasmoides/<id>/`, em formato KPackage: `metadata.json` (com `KPlugin.Id`) e
  `contents/ui/main.qml`. Ids: `org.cyberkde.clima`, `.desempenho`, `.midia` e `.notas`.
- `modules/widgets/comum/`: componentes comuns. O CLI copia a pasta para `contents/ui/comum/` de cada
  pacote instalado (`~/.local/share/plasma/plasmoids/<id>`). Se houver um `qmldir` seu ali, o CLI
  só acrescenta uma linha a ele.

## Registro automático: bloco `X-CyberKDE` no `metadata.json`

Todo pacote `modules/widgets/plasmoides/org.cyberkde.<nome>/` vira sozinho o efeito `widget-<nome>`
(`<nome>`: minúsculas, números e hífen), com `on|off`, `--tela`, `--posicao`, `--modo` e
`--opacidade`. Não há lista fixa no CLI. O que ele precisa saber vem de um bloco opcional no nível de
cima do `metadata.json`, ao lado de `KPlugin`:

```json
"X-CyberKDE": {
    "nome": "Câmbio", "nome_en": "Exchange",
    "descricao": "Cotação das moedas escolhidas, em eddies.",
    "descricao_en": "Rates for the chosen currencies, in eddies.",
    "tamanho": [360, 300],
    "ordem": 60,
    "opcoes": [
        {"id": "moedas", "chave": "moedas", "tipo": "texto", "padrao": "USD, EUR, BTC",
         "nome": "Moedas", "nome_en": "Currencies",
         "dica": "Códigos separados por vírgula", "dica_en": "Codes separated by commas"}
    ]
}
```

| Campo | Uso | Sem ele |
|---|---|---|
| `nome`, `nome_en` | nome no painel ("Widget: <nome>") | `KPlugin.Name[pt_BR]`/`Name[en]`, sem o "CyberKDE · " |
| `descricao`, `descricao_en` | descrição no painel | `KPlugin.Description[pt_BR]`/`Description[en]` |
| `tamanho` | `[largura, altura]` de inserção, em px (o widget acerta o seu depois) | 360×300 |
| `ordem` | posição na lista do painel e na colocação (menor primeiro) | 100, depois pelo nome |
| `categoria` | `sistema`, `informacao` ou `produtividade` (grupo no painel) | tabela de reserva do CLI (desempenho, discos, rede e docker → sistema; clima, câmbio, rss e relógio → informacao; notas, tarefas e mídia → produtividade); fora dela, `outros` |
| `layoutFui` | `{"coluna":"esquerda"\|"direita","faixa":0-3,"faixas":1-4,"oculta":"<módulo do Painel FUI>"}`: lugar no `widget-layout fui` (modules/widgets/LAYOUT-FUI.md) | a tabela do LAYOUT-FUI.md (relógio, clima, câmbio, desempenho, discos, notas); fora dela, o widget não entra nas colunas |
| `opcoes` | opções extras do efeito (abaixo) | nenhuma |

Cada opção vira `cyberkde efeito widget-<nome> --<id> <valor>` e aparece no painel:

- `global: true`: vale para todas as instâncias, sem `--instancia`, mesmo sem nenhuma na mesa.
- `id`: letras, números e hífen (`--animacao-icones` também acha `animacaoIcones`). Não pode ser `tela`, `posicao`, `modo`, `opacidade`, `json`,
  `lang`, `on` ou `off`.
- `chave`: a chave do grupo `General` do applet onde o CLI grava (padrão: o próprio `id`). Precisa
  existir no seu `main.xml`.
- `tipo`:
  - `texto`, um campo livre de uma linha, com `padrao` (string). Uma lista vai como texto num formato
    que o widget define e lê; diga qual na `dica`. Sugestão: vírgulas para códigos e nomes, espaço ou
    `|` entre URLs.
  - `escolha`, com `valores: [{"id","nome","nome_en"}]` e `padrao`. Os ids usam letras, números, `_`,
    `.` e `-`.
  - `inteiro`, com `min`, `max`, `padrao` e, se quiser, `unidade`.
- `nome`, `nome_en`, `dica` e `dica_en` são textos do painel.

Em `escolha`, cada valor pode ter `previa` (caminho relativo à raiz do projeto): no `--lista`, ela sai absoluta
se o arquivo existir. Uma opção malformada é ignorada (o widget continua registrado sem ela). O CLI grava a chave quando a
pessoa escolhe pelo CLI ou pelo painel: no applet criado e, ao vivo, nos que já estão na área de
trabalho (com `reloadConfig`). Sem escolha, vale o `padrao` do seu `main.xml`. Ao religar, a cópia
guardada vale (ver "Dados da pessoa"). O `estado` do efeito traz `"<id>": valor` (ou `null`) com a
escolha feita pelo CLI.

Clima, desempenho, mídia e notas ainda funcionam sem o bloco: o CLI tem os dados deles de reserva (a
`cidade` do clima entre eles) até o bloco entrar no `metadata.json` de cada um.

Opções previstas: câmbio `moedas`, rss `feeds`, relógio `fuso2` (ex.: `Asia/Tokyo`), discos `montagens`
(ex.: `/, /home, /mnt/hd`). Os ids são sugestão: vale o que estiver no `metadata.json`.

## Várias instâncias (`X-CyberKDE.instancias: true`; a cerca já é)

- `efeito widget-<nome> nova [opções]` cria uma instância; `remover <id>` tira o applet e apaga as escolhas e a
  cópia dela (a pasta da cerca não é tocada). A resposta `--json` de `nova` traz `"instancia":"<id>"`.
- Sem nenhuma instância, opção ou `off` não criam nada: voltam com um aviso em `avisos` (código 0).
- Ids: `"1"`, `"2"`... as do tema; `"a<applet>"` as postas à mão no "Adicionar widgets".
- `--instancia <id>` vale para on, off, `--tela`, `--posicao`, `--modo`, `--opacidade` e as opções do widget.
  Sem ele, vale a primeira do tema, nunca todas. `--instancia todas` (só on|off) trata as do tema: é o que o
  "Ligar todos" deve mandar neste widget.
- Posta à mão: opções valem ao vivo só nela, sem registro. `off`, `--tela` e `--posicao` a adotam, e ela
  ganha um id numérico (devolvido em `instancia`). `on` não faz nada. `remover aN` só tira o applet.
- `estado.instancias` (no `--lista` e no `status`): `[{id, ligado, manual, geometria, tela, posicao, modo, opacidade, <cada opção>}]`, com
  `titulo`, `pasta` e `recolher` na cerca. O topo do `estado` é o da primeira. O item do `--lista` traz
  `multiInstancia`, `comandoNova` e `comandoRemover`.
- Internamente, a instância 2 é a chave `cerca@2`: no `widgets.tsv`, em `[widget-cerca@2]` e em
  `widgets-dados/cerca@2-tela<N>.json`.
- O `off` e o `on` gerais tratam as do tema; as postas à mão ficam. O layout FUI só tira do caminho as do tema
  que cruzarem o layout (para um canto ou vão livre); as outras ficam, e `livre` as devolve.

### Cerca: atalhos, pasta base e `cyberkde cerca`

- `cyberkde cerca nova [--titulo T] [--pasta P] [--json]` cria na tela sob o mouse (a saída ativa do KWin) ou
  na principal, com `General/novaCerca=true` no applet, e responde `{"efeito":"cerca","instancia":"<id>","avisos":[]}`. Sem applet criado, sai com código 1 e `{"erro":"…"}`, sem deixar
  instância nem a pasta que ele próprio criou.
  O widget deve declarar `novaCerca` no `main.xml` e zerá-la depois de usar.
- Sem `--pasta`, toda `nova` cria `<base>/Cerca N`. A base padrão é `<pasta XDG de documentos>/Cercas`.
- `cyberkde cerca alternar|mostrar|ocultar [--json]` responde `{"cercasOcultas":bool}`. A fonte da verdade é o
  arquivo `$XDG_CONFIG_HOME/cyberkde/cercas/ocultas` (existe = ocultas), que o widget vigia.
- `cyberkde cerca peek [on|off|alternar] [--json]` responde `{"peek":bool}`: o arquivo `cercas/peek` (existe = por
  cima das janelas), que o widget vigia. O `off` do tema o apaga. `estado.peek`.
- `cyberkde cerca pedir` é o que o atalho chama: abre `app/cerca-nome.py`. Sem a janela (ou sem o PyQt6),
  cai em `cerca nova`. A janela termina chamando `cyberkde cerca nova --titulo "Nome"`, que cria
  `<base>/Nome` (barras viram hífen; nome em uso vira "Nome 2").
- Sem título nem pasta, `cerca nova` nasce com `novaCerca=true`, sem pasta, e o widget pede o nome. Se ele se
  remover (Esc), a instância é descartada na leitura seguinte (`--lista`, `status` ou qualquer comando).
  `efeito widget-cerca nova` sem pasta continua criando `<base>/Cerca N`.
- Opções do CLI em `widget-cerca` (globais, não vão para o applet, grupo `[cerca]`): `--atalhos on|off` (padrão
  off), `--atalho-nova`, `--atalho-alternar`, `--atalho-peek` (`off` = sem atalho; padrão: Meta+Shift+Space ou o livre),
  `--base`, `--vigiar on|off`, `--por-resolucao on|off` (padrão off).
  Aparecem no `--lista` e no `estado` com esses ids, mais `cercasOcultas`, `regras` e `snapshots`. A `base`
  também é gravada em `General/base` dos applets. Atalho já em uso por outro programa: código 2 com o dono. Sem escolha, o primeiro par
  livre: Meta+Shift+F (depois Meta+Ctrl+Shift+F, Meta+Alt+F) e Meta+Shift+H (idem com H).
- Atalhos: `~/.local/share/kglobalaccel/cyberkde-cerca.desktop` (ações `Nova`, `Alternar` e `Peek`) e
  `[services][cyberkde-cerca.desktop]` do `kglobalshortcutsrc`, com registro na fase `widgets`, e ao vivo no daemon.

### Cerca: regras, snapshots e backup (para o painel)

Tudo em `$XDG_CONFIG_HOME/cyberkde/cercas/`, que o uninstall preserva. Com `--json`, erro é
`{"erro":"…","codigo":N}` (2 uso, 3 ocupado).

**`estado` do `widget-cerca`:** `"regras":{"total":N,"ativas":N,"desfazer":"<lote>"|null}`,
`"snapshots":[{"nome","criado","resolucao","cercas":N}]`, `"vigiar":"on|off"`, `"por-resolucao":"on|off"`.

**Regra** (`OrganizeRule`): `{id:"r1", nome, ativa, extensoes:["pdf"], nomeContem, destino, prioridade, conflito,
autoCriarCerca, ultimaExecucao, esperarDestravar}` (a do FENCES-DISCOVERY 2.4; extensões e nome somam, como lá;
`--extensoes` aceita `pdf,doc`, `*.pdf;*.doc` e `*`). `autoCriarCerca` (`--criar-cerca on`): depois de mover, cria uma
cerca para o destino, se não houver. `destino`: caminho, `~/…`, `file:///…` ou `cerca:<id da instância>` (a pasta dela, lida do
applet). Menor `prioridade` vem antes; vale a primeira que casar. `conflito`: `renomear` ("a (2).pdf"), `pular` ou
`sobrescrever` (o substituído vai para `guardados/<lote>/`, e o desfazer o devolve). Precisa de `extensoes` ou
`nomeContem`. Só arquivos soltos na origem; ficam fora ocultos, atalhos `.desktop`, links, pastas e temporários
(`.part`, `.crdownload`, `.tmp`…). `esperarDestravar`: espera até 5 s; ainda em uso, pula com motivo `em uso`.

| Comando (`cyberkde cerca regras …`) | `--json` |
|---|---|
| `lista` · `ajuda` | `{"regras":[…]}` |
| `adicionar --destino D [--extensoes a,b] [--contem T] [--nome N] [--prioridade P] [--conflito C] [--sem-esperar]` | `{"regra":{…}}` |
| `editar <id> …` · `remover <id>` · `ativar <id>` · `desativar <id>` | `{"regras":[…]}` |
| `aplicar [--simular] [--origem P]` | `{"simulado",lote,origem,"movidos":[{arquivo,destino,regra,acao}],"pulados":[{arquivo,regra,motivo}],"semRegra":N}`; `acao`: `mover`, `renomear`, `sobrescrever` |
| `desfazer [lote]` (sem lote: o último) | `{"lote","devolvidos":N,"conflitos":[{arquivo,motivo}]}`; nunca sobrescreve |
| `historico` | `{"lotes":[{lote,quando,arquivos}]}` |

Origem padrão: a pasta XDG da Área de trabalho. `--vigiar on` liga uma unidade `.path` do systemd do usuário
(`cyberkde-cerca-regras`), com registro.

**Snapshot** (`cyberkde cerca snapshot …`): `salvar <nome>` · `listar` (`{"snapshots":[…]}`) ·
`restaurar <nome>` (`{"restaurado","backup":"<cópia do appletsrc>"}`) · `apagar <nome>`. Nome: letras, números, espaço,
`.`, `-` e `_`, até 60. Guarda posição, tamanho, título, pasta, recolhido e toda a configuração, de todas as cercas,
inclusive as postas à mão. Ao restaurar, quem está a menos de uma célula só recebe a configuração, quem mudou sai e
entra, quem sumiu é recriado, e cerca fora do snapshot fica como está.

**Por resolução:** cada snapshot leva `resolucao` (`DP-1:1920x1080+HDMI-A-1:1920x1080`). Com `--por-resolucao on`, ao
mudar as telas (o KWin regrava o `kwinoutputconfig.json`), restaura o snapshot mais novo daquela combinação, se houver.

**Backup:** `cerca backup` (em `backups/`) · `exportar <arquivo>` · `importar <arquivo> [--aplicar]` (`{"regras":N,
"snapshots":[…],"atual":"<snapshot>"}`). O pacote tem regras, snapshots e o layout atual. Importar troca as
regras (com cópia em `backups/`) e nunca sobrescreve um snapshot (nome em uso ganha `-2`); `--aplicar` restaura o
layout do pacote.

O valor de cada opção no `estado` vem do applet real (lido em lote); sem applet, da cópia guardada, depois
da escolha do CLI e do `padrao`. Por isso `recolher` é o `IsRolled` de agora.

## Dados da pessoa (preservados ao desligar e religar)

Tudo o que o widget guarda na configuração do applet (qualquer grupo e chave do `main.xml`) é copiado
para `~/.config/cyberkde/widgets-dados/<nome>-tela<N>.json` ao desligar (o efeito, a fase ou o `off`
geral) e devolvido ao religar. A cópia guarda também o tamanho e a posição. Por isso:

- Guarde o que a pessoa edita no próprio widget (as tarefas em `General/tarefas`, a lista de feeds, as
  moedas) em chaves do `main.xml`, nunca em arquivo à parte. Strings longas e JSON passam inteiros.
- Se uma lista também é opção do CLI (`moedas`, `feeds`), use **a mesma chave** para as edições feitas
  no widget. Ao religar, a cópia vale, e as edições não se perdem. Uma escolha feita no CLI com o widget
  desligado é gravada na cópia.
- O uninstall preserva `widgets-dados`. Um widget removido à mão pela pessoa não deixa cópia.

## Cores: `Paleta` (singleton gerado pelo CLI)

O CLI grava `contents/ui/comum/Paleta.qml` em cada pacote instalado e põe
`singleton Paleta 1.0 Paleta.qml` no `qmldir` dessa pasta. Uso: `import "comum"` e então
`Paleta.destaque` etc. As cores já vêm aplicadas: clareadas para ler sobre o fundo, e com as
superfícies no tom da corporação.

| Propriedade | O que é |
|---|---|
| `destaque`, `secundaria`, `alerta` | cores da paleta (cor/corporação) |
| `fundo`, `superficie`, `painel`, `elevado` | superfícies escuras, da mais funda para a mais clara |
| `texto`, `textoSecundario`, `textoDesativado`, `textoSobreDestaque` | texto |
| `linha` | filete neutro |
| `corp` (string) | id da corporação em uso (`nenhuma`, `personalizada`, `militech`…) |
| `logo`, `emblema` (url) | logo largo e emblema da corporação em uso (`file://…`), ou `""` sem corporação; o `cor`/`corp` regrava |

O `cyberkde cor`/`corp` regenera o arquivo, e o reinício do plasmashell que eles já fazem no fim
carrega as cores novas. Não ponha nenhuma cor fixa nos QML: sem o arquivo, a cor não acompanharia o
tema.

## Configuração do applet

- Clima: a cidade vem em `General/cidade` (string), gravada pelo CLI ao criar o applet e a cada
  `cyberkde efeito widget-clima --cidade "Nome"`. Leia com `Plasmoid.configuration.cidade` (declare
  a chave no `contents/config/main.xml`).
- Notas: guarde o conteúdo na configuração do applet (`main.xml`), não em arquivo à parte. Ao desligar,
  o CLI copia toda a configuração do applet para `~/.config/cyberkde/widgets-dados/` e a devolve ao
  religar, então tudo o que estiver na configuração sobrevive.
- Todos: `General/modo` (`pequeno`|`medio`|`grande`; o CLI aceita ainda `compacto` e `completo` e grava `pequeno` e `grande`; o tamanho na tela é do widget) e `General/opacidade` (inteiro, 30 a 100), gravados pelo
  CLI só quando a pessoa escolhe (`--modo`, `--opacidade`): no applet criado e, ao vivo, nos que já estão
  na área de trabalho (com `reloadConfig`). Sem escolha, vale o padrão do `main.xml`. Ao religar com
  cópia guardada, a cópia vale (com `ajustado` e o que a pessoa mudou no widget); uma escolha
  feita no CLI com o widget desligado é gravada na cópia (`--modo` põe `ajustado=false` e tira o tamanho
  guardado, para o preset valer ao aparecer).
- Geometria: ao desligar, o CLI guarda também o tamanho e a posição do applet; ao religar, devolve os
  dois (o tamanho sempre; a posição, se a tela e o canto não mudaram e o lugar estiver livre).
- Modo de edição do Plasma: `cyberkde edicao on|off|alternar [--json]`; `status --json` traz `edicao`.

## Tamanho de inserção

Vem do `tamanho` do bloco `X-CyberKDE`. O CLI calcula a posição: no canto escolhido, em colunas, sem
sair da tela nem sobrepor outro widget. Depois disso o tamanho é do widget e da pessoa.

## Prévias

`assets/previas/widgets/<nome>.webp` (ou `.png`), com o `<nome>` do pacote (`clima`, `cambio`, `rss`…). Elas aparecem no campo `previa` do `cyberkde efeito --lista --json`.

## Ocultar e exibir os widgets (comando `cyberkde widgets`, DATA)

Todos os widgets do tema (menos as cercas, que têm estado próprio) ocultam e voltam juntos, com as 16
variantes da `AnimacaoCerca`. Quem faz é o `comum/Tamanhos.qml` (`Ocultacao.qml` + `AnimacaoWidget.qml`,
cópia gerada por `plasmoides/cerca-anim-gerar.py`); nada muda nos pacotes. Oculto = sem interação; no
modo de edição, tudo fica à vista.

O estado são nomes de arquivo em `$XDG_CONFIG_HOME/cyberkde/widgets/`, vigiados na hora pelos widgets. O
CLI só cria e apaga esses arquivos (crie a pasta no `install_widgets`, como a `cercas/`):

| Arquivo | Significado | Padrão |
|---|---|---|
| `ocultos` | existe = ocultos | não existe |
| `gesto` | existe = duplo clique na mesa vazia alterna ("Ocultar com duplo clique") | não existe (desligado) |
| `junto` | existe = o gesto e o comando levam as cercas junto | não existe |
| `animacao.<id>` | a variante, um arquivo só; `animacao.cercas` = igual às cercas | nenhum = igual às cercas |

Comandos pedidos (com `--json`; o painel já os chama):

```
cyberkde widgets estado                      só lê
cyberkde widgets ocultar|mostrar|alternar    com "junto", grava também cercas/ocultas (no alternar, o alvo é !cercas/ocultas)
cyberkde widgets gesto on|off
cyberkde widgets junto on|off
cyberkde widgets animacao <id>|cercas        apaga o animacao.* anterior; id das variantes de contents/animacoes.json
```

Todos respondem, em `--json`: `{"ocultos":bool,"gesto":bool,"junto":bool,"animacao":"<id>|cercas",
"animacaoEfetiva":"<id>"}` (efetiva = a de `cercas/animacao.<id>` quando for "cercas"; sem arquivo lá, a
padrão do catálogo). Saída 2 para id inválido. Sem trava nem registro: é preferência e estado de sessão,
como `cerca alternar`. Decisões para o DATA: o `off` geral e o `uninstall` devem apagar `ocultos` (como
fazem com `cercas/ocultas`; widget religado oculto parece widget perdido); `gesto`, `junto` e `animacao.*`
saem no `uninstall` junto com o resto de `~/.config/cyberkde`, e `cercas/animacao.*` e `cercas/animicones.*` também.

"Separado" (`junto` desligado): cada um tem seu estado. O duplo clique alterna os widgets e, nas cercas com
o gesto delas ligado (`gestoOcultar`), alterna as cercas por conta própria.

## Painel

Os efeitos são `widget-<nome>`, um por pacote, no grupo `area-de-trabalho`, com `comando` e `forma`.
Em todos: `tela`, `posicao`, `modo` (escolha) e `opacidade` (`"tipo":"inteiro"`, 30 a 100,
`"unidade":"%"`), mais as `opcoes` do bloco `X-CyberKDE` (`texto`, `escolha` ou `inteiro`, com `dica`
quando houver).

Os padrões de `modo` e `opacidade` (e o mínimo e o máximo da opacidade) vêm do `contents/config/main.xml`
de cada widget: o `estado`, o painel e a validação do `--opacidade` usam os seus (o Painel FUI: `grande`,
55, de 0 a 100). Sem as entradas, valem `pequeno` e 95, de 30 a 100.

O `estado` de cada efeito (no `efeito --lista` e no `status --json`) traz também `"categoria"` e
`"geometria": {"x","y","largura","altura","tela":[L,A]}` do applet criado pelo tema, lida do
plasmashell (só leitura, uma consulta para todos os widgets). Sem plasmashell ou sem applet, `null`.

## Layout FUI (`efeito widget-layout fui|livre [--so-painel [on|off]]`)

Segue o `modules/widgets/LAYOUT-FUI.md`, com o que o Plasma 6.6 real obrigou (visto num plasmashell
isolado e no sistema):

- O script do Plasma não move applet (`Widget.setGeometry` não faz nada). Cada widget sai e entra de novo
  no retângulo, com a configuração inteira e `General/ajustado=true`, e o id do applet muda.
- Todos saem num script e entram em outro. Um applet removido ainda ocupa o lugar até o Plasma voltar
  ao laço de eventos, e o novo seria empurrado para o espaço livre mais perto.
- A origem do `addWidget` não é a da `geometry`. No sistema real ela fica logo abaixo da barra de cima,
  e no isolado 16 px abaixo dela. Por isso o CLI calibra: põe o widget, lê onde ele caiu e, se errou,
  tira e põe de novo uma vez com o desvio medido. A grade do Plasma conta a partir dessa origem, e o
  resultado pode ficar 1 px fora da tabela do LAYOUT-FUI.md (ex.: y=97 em vez de 96).
- Tela: a que tem mais widgets do tema (a pessoa pode tê-los arrastado para outra); sem nenhum, a 0.
- Área útil: a tela menos os painéis do Plasma nela e, com o Latte rodando, 104 px embaixo (a mesma
  reserva do `--posicao`).
- Widget fora da tabela que cruza a área: primeiro canto livre fora da área. Se não houver, um canto que
  não cruze nada do que foi posto (pode cair numa célula vazia). Parado, o Plasma empurraria o widget da
  célula para fora dela.
