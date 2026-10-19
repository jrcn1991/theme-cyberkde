# Pedidos do painel ao CLI (`scripts/cyberkde`)

O painel (`app/cyberkde-painel.py`) só conversa com o CLI. Esta lista registra o que ele já usa e o
que ainda falta. Conferido em 19/10/2026 contra o `scripts/cyberkde` e o `tokens/corporacoes.json`
da árvore de trabalho.

## Já em uso (funciona hoje)

| Comando | Uso no painel |
|---|---|
| `status --json` | cabeçalho e seção Status; usa `corp`, `corpLogo` (se o arquivo existir) e o objeto `paleta` |
| `fases --json` | seção Módulos; `registroPorFase:false` mostra o aviso "Registro antigo" com botão Ligar, deixa o estado das fases como desconhecido (?) e não chama `off <fase>` |
| `corp --lista --json` | grade de corporações: a lista de ids vem daqui (sem `nenhuma`, que é o cartão "Padrão"); `nome`, `cor`, `lema`, `secundaria`, `alerta`, `fundo`, `logo` |
| `on [fase] --json --progresso --sem-sudo` | ligar o tema e cada fase |
| `off <fase> --json --progresso --sem-sudo` | desligar uma fase (só com `fases --json` e `registroPorFase` verdadeiro) |
| `off --json --progresso` | desligar tudo; CLIs que ignoram as opções desligam do mesmo jeito |
| `corp <id> --json --progresso --sem-sudo` | aplicar corporação (`corp nenhuma` no cartão "Padrão") |
| `cor '#hex' [--secundaria '#hex'] --json --progresso --sem-sudo` | Personalizada; `--secundaria` só se o texto de `cor --help` a mencionar |
| `cor --help` | só para descobrir se `--secundaria` existe (sai com 2 antes da trava) |
| `papel …`, `checar` | papel de parede e diagnóstico, como antes |

### Paleta e logos: de onde o painel tira cada coisa
- **Paleta e lema**, campo a campo: `corp --lista --json` → `tokens/corporacoes.json` (lista em
  `corporacoes`) → reserva no próprio painel (os valores da rodada 2, mais lemas próprios para Kang Tao,
  Segotari e Zetatech). Os nomes "Padrão" e "Personalizada" são do painel.
- **Logo largo** (cartões/inspetor): `~/.config/cyberkde/corporacoes/<id>.svg|png` (da usuária) →
  `assets/corporacoes/<id>-logo-escuro.png` → `<id>-logo.png` → o `logo` do CLI/tokens quando o nome
  tem `-logo` → o ícone.
- **Ícone quadrado** (cabeçalho, miniaturas, prévia do botão do menu): o da usuária →
  `<id>.svg` → `<id>-icone.svg|png` → `<id>.png` → o `logo` do CLI/tokens sem `-logo` no nome →
  `assets/corporacoes/genericos/<id>.svg` (emblemas genéricos, só se faltar o oficial).

## Pedidos

1. **`--secundaria` na Personalizada.** O seletor tem uma aba "Secundária", desabilitada com
   explicação enquanto `cor --help` não citar `--secundaria`. Formato que o painel vai usar:
   `cyberkde cor '#DESTAQUE' --secundaria '#SECUNDARIA' --json --progresso --sem-sudo`; e
   `status --json` com `paleta.secundaria` refletindo a escolha.
2. **Ícone do menu.** O `logo` do `corp --lista` e do tokens hoje aponta o logo LARGO
   (`<id>-logo.png`), que não serve de ícone do botão do menu (22–32 px). Sugestão: um campo
   `icone` (o `<id>.svg` quadrado) separado de `logo`, no tokens e na lista; o painel já aceita os dois.
   O `status --json` já traz `corpLogo` e `corpLogoLargo`: confirmar que `corpLogo` é o quadrado.
3. **Logo trocado da corporação em uso.** "Escolher logo…" copia a imagem para
   `~/.config/cyberkde/corporacoes/<id>.svg` ou `.png` (um arquivo só por corporação). Se for a
   corporação atual, o painel pede para aplicar de novo; confirmar que `corp <id>` regenera o ícone
   do menu a partir desse arquivo.
4. **Lemas.** Os do tokens (do DATA) têm prioridade. Sugestões do painel para as novas, se quiserem:
   Kang Tao "Inteligência em cada disparo.", Segotari "O amanhã já tem dono.", Zetatech "Pense à
   frente." (o "Think ahead" oficial).
5. **`papel --json`** e **`checar --json`** (opcionais). Hoje o painel lê a saída em texto.
6. **Instalação.** O instalador precisa levar `app/` e `assets/corporacoes/` (com `genericos/`) para a
   cópia instalada e gerar `~/.local/share/applications/cyberkde-painel.desktop` a partir de
   `app/cyberkde-painel.desktop`, trocando `@APP@`. O nome do arquivo tem de ser
   `cyberkde-painel.desktop`. O `uninstall` remove esse arquivo.

## Rodada 3 (idioma, 13 corporações)

Já em uso:
- `fases --json`: `nome_en`, `descricao_en`, `grupoNome`, `grupoNome_en` (no inglês; faltando, o painel
  traduz pelo id com o catálogo `app/i18n/en.json`).
- `corp --lista --json` e `tokens/corporacoes.json`: `lema_en`, `descricao`, `descricao_en` (a
  descrição é o "dossiê" no inspetor), `icone` e `logoLargo`. A lista de corporações vem do CLI (13 hoje).

Fica em PT-BR no modo inglês, por vir pronto do CLI:
7. **`checar`**: os itens do Diagnóstico são o texto do CLI. Um `checar --json` com `texto`/`texto_en`
   (ou só o código de cada item, que o painel traduziria) resolveria.
8. **Mensagens de erro e avisos** do `--json` (`erro`, `avisos`): saem em PT-BR; um campo `*_en`, ou um
   `--idioma en`, deixaria as notificações no idioma escolhido no painel.

## Rodada 4 (cascata de dados do Konsole, idioma do CLI)

O painel já usa, quando existirem (sem eles, mostra "CLI sem suporte" e desabilita os controles):
- `status --json` (ou `fases --json`) com `"efeitos": {"konsoleCascata": {"ligado","linhas","cores","disponivel"}}`.
- `cyberkde efeito konsole-cascata on|off --linhas N --cores video|tema --json`. O painel manda sempre
  as três coisas juntas: mudar só a altura ou as cores com o efeito desligado vira `off --linhas … --cores …`.
  Resposta lida: `ligado`, `linhas`, `cores`, `disponivel` (com `disponivel:false` o painel avisa para
  atualizar o Konsole animado).
- Idioma: o painel exporta `CYBERKDE_LANG=en|pt_BR` para todo processo do CLI (não passa `--lang`, que
  um CLI antigo recusaria). `checar --json` é chamado sempre; o painel aceita
  `{"itens":[{"nivel":"impede|corrigir|aviso|ok","texto","texto_en","correcao":[...]}]}` e, se a resposta
  não for JSON, lê o texto como antes.

## Rodada 5 (seção Efeitos)

Já em uso (conferido contra o CLI real em 19/10):
- `efeito janelas --lista --json`: `{"variantes":[...catálogo...],"estado":{"abrir","fechar","duracaoAbrir","duracaoFechar","intensidade","disponivel","catalogo"}}`
  (aceita também `atual` no lugar de `estado`). `disponivel:false` mostra um aviso com o botão
  "Religar Janelas" (`on janelas`). Sem o comando, o painel lê `effects/cyberkde_scan/variantes.json`
  direto; sem nenhum dos dois, um catálogo de exemplo, e Aplicar fica desligado.
- Aplicar: `efeito janelas --abrir ID --fechar ID|nenhuma --duracao-abrir MS|padrao --duracao-fechar MS|padrao --intensidade N --json`
  (o painel manda sempre tudo; duração 0 no painel = `padrao`; `--duracao-fechar` só se fechar ≠ nenhuma).
- Prévias: `previaAbrir`/`previaFechar` do catálogo, ou `assets/previas/janelas/<id>-abrir.webp|-fechar.webp`.
  Sem elas, o painel desenha uma aproximação em QML (mapa id → estilo em `ESTILO_PREVIA`).
- `efeito --lista --json`: `janelas` e `konsole-cascata` têm cartões próprios; os demais viram cartões
  genéricos. O painel entende `tipo` "liga"|"variante", `ligado`, `variante`, `variantes:[{id,nome,nome_en}]`,
  `opcoes:[{id,nome,nome_en,tipo:"inteiro"|"escolha"|"booleano",min,max,passo,unidade,valor,escolhas}]`,
  `disponivel` e `aviso`/`aviso_en`, e aplica com
  `efeito <id> on|off [--variante V] [--<opção> valor …] --json`.

Pedido:
9. **Estado dos genéricos no `efeito --lista`.** Hoje `janelas` e `konsole-cascata` trazem o estado em
   `estado`; para um efeito genérico, o painel lê `ligado`, `variante` e `opcoes[].valor` no nível do
   efeito. Se o padrão for `estado`, me avisem que eu leio de lá também.
10. **`--abrir nenhuma`.** O efeito aceita `nenhuma` em `AbrirVariante` (effects/cyberkde_scan/PEDIDO.md),
    mas o `janelas_variante` do CLI recusa `--abrir nenhuma` (código 2). O painel só oferece "Nenhuma"
    na galeria de abrir quando `efeito --lista` trouxer `"nenhuma"` em `opcoes[abrir].valores` (hoje só
    está em `fechar`). Pedido: aceitar `nenhuma` no `--abrir` e listá-la nos valores de `abrir`.
11. **`main.xml` no install (pedido da Rachael, obrigatório).** Sem `contents/config/main.xml` o KWin
    não entrega as chaves ao efeito e a escolha do painel não tem efeito nenhum; o `disponivel` deveria
    testar esse arquivo também.

## Rodada 6 (SYS.CONFIG)

O painel monta a seção Configurações inteira a partir de `efeito --lista --json` (grupos, opções,
`estado`, prévias). Aplicar usa esta regra, deduzida dos `uso:` de cada módulo:
liga → `on|off`; uma opção só → valor posicional (layout, menu, movimento, splash, papel, cursor);
`areas` → número posicional + `--nomes`; `icones` → `grupo=valor`; estilo-* → `--variante V`
(`off` = voltar ao padrão) e `--<opção> V`; demais → `--<opção> V`. Todo processo do painel roda com
`CYBERKDE_SEM_SUDO=1`; resposta com `pendentesSudo`/`retomar` abre o aviso de senha.

12. **Campo `comando` por efeito (ou `forma` por opção).** A regra acima é frágil: um efeito novo com
    sintaxe diferente sai errado. Pedido: em cada efeito do `--lista`, algo como
    `"forma": {"<opção>": "posicional"|"flag"|"par"}` ou um modelo `"comando": "efeito areas {numero} --nomes {nomes}"`.
13. **`retomar` no `efeito login`.** Hoje ele devolve `pendentesSudo` e um aviso; o painel usa
    `cyberkde on login` como comando. Um campo `retomar` exato evita adivinhar.
14. **Grupo `estilo` em `grupos`.** Os efeitos estilo-* vêm com `grupo: "estilo"`, mas `grupos` não lista
    "estilo" na primeira versão vista (o painel tem nome de reserva). Conferido de novo: já vem como
    "Estilo visual" — ok, só registrar.
- **Atualização (rodada 6, fim):** o pedido 12 foi entregue (`comando` + `forma: {liga, opcoes: {id: posicional|flag|igual}}`).
  O painel usa `forma.opcoes` para montar o comando; um posicional que no `comando` aparece fora de `[ ]`
  (ex.: `efeito areas {numero} [--nomes …]`) vai sempre, com o valor atual. A dedução antiga só vale
  quando o CLI não manda `forma`. O `retomar` por efeito (pedido 13) ainda não aparece no `--lista`;
  quando vier (no efeito ou no `estado`), o painel já o usa no aviso de senha.
- **Sons:** o painel lê `previaSom` e `sons[]` (`evento`, `previaSom`) de cada valor e toca só arquivos
  dentro do projeto, em 30% (`pw-play --volume 0.3`, ou `paplay`), só por clique.
