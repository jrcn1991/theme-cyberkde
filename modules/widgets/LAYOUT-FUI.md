# Layout "FUI" dos widgets: `cyberkde efeito widget-layout fui|livre`

De: Estilo, 29/10/2026. Para: DATA (implementa no `modules/widgets/phase.sh`). Aprovado pelo Orquestrador.

O efeito põe o **Painel FUI** (`org.cyberkde.painelfui`) no centro da tela principal e os outros widgets
do tema que estiverem ligados em duas colunas laterais, alinhados às faixas do painel. `livre` devolve
tudo a como estava. Este arquivo tem tudo o que é preciso. Os números de exemplo saem das fórmulas abaixo,
e os pacotes não precisam de mudança nenhuma além da chave `ocultosLayout` do Painel FUI, que já existe.

## Comando

```
cyberkde efeito widget-layout fui [--so-painel] [--json]
cyberkde efeito widget-layout livre [--json]
cyberkde efeito widget-layout            (só lê: {"layout":"fui"|"livre","soPainel":bool})
```

- Efeito do tipo `variante`, no grupo `area-de-trabalho`, com `variantes` `fui` e `livre` (padrão `livre`)
  e uma opção `so-painel` (`booleano`, padrão `false`). Prévia: `assets/previas/widgets/painelfui.webp`.
- A escolha fica em `~/.config/cyberkde/efeitos`, grupo `[widget-layout]`, chaves `layout` e `soPainel`.
  A fase dona é a `widgets`: o `on` reaplica o `fui` depois de pôr os widgets; o `off` não precisa de
  nada além do que já faz (os widgets do tema saem com a geometria guardada).
- `fui` liga o `widget-painelfui` se ele estiver desligado (como se a pessoa tivesse pedido
  `cyberkde efeito widget-painelfui on`). Os outros widgets **não** são ligados nem desligados: só os
  que já estão na área de trabalho entram nas colunas.
- Só na **tela principal** (a mesma do `--tela principal`). Widgets do tema em outras telas não mudam.

## Fórmulas

Todas as medidas em px de tela. Unidades "base" são as do painel de referência (866×732).

**Área útil `A = (X, Y, W, H)`**: a geometria da tela principal menos os painéis do Plasma e o dock nela.
Use a mesma função que o `--posicao` já usa para não pôr widget em cima da barra.

**Constantes (base):**

| Nome | Valor | O que é |
|---|---|---|
| `PW`, `PH` | 866, 732 | o Painel FUI |
| `CW` | 380 | largura de uma coluna lateral |
| `G` | 24 | vão entre a coluna e o painel |
| `TW` | 1674 | largura total = `CW + G + PW + G + CW` |
| `FA`, `FP` | 172, 187 | altura de uma faixa e o passo entre faixas (as 4 linhas do painel) |
| `M` | 24 | margem em volta, em **px de tela** (não escala) |

**Escala e origem:**

```
k  = min((W - 2M) / TW, (H - 2M) / PH)
X0 = X + (W - TW·k) / 2          Y0 = Y + (H - PH·k) / 2
colE = X0                        (coluna esquerda)
colP = X0 + (CW + G)·k           (painel)
colD = X0 + (CW + G + PW + G)·k  (coluna direita)
```

**Retângulos:**

- Painel: `(colP, Y0, PW·k, PH·k)`.
- Célula lateral que começa na faixa `b` (0 a 3) e ocupa `n` faixas: `(col, Y0 + FP·b·k, CW·k, (FP·n − 15)·k)`.
  Assim, a altura é sempre `n × 187 − 15` em base: alinhada ao topo de uma faixa e ao fim do rodapé de outra,
  como os módulos do painel.

**Grade da área de trabalho** (`cellWidth`/`cellHeight` do layout, hoje 16 px): o canto de cima à esquerda
arredonda **para cima** e o de baixo à direita **para baixo**, ao múltiplo da grade. Assim, os retângulos nunca se
sobrepõem, e o widget não "pula" ao reiniciar. O Painel FUI centraliza a grade dentro do retângulo que
receber, e o arredondamento não deforma nada.

## Onde cada widget vai

| Widget (efeito) | Coluna | Faixa inicial `b` | Faixas `n` |
|---|---|---|---|
| `widget-relogio` | esquerda | 0 | 1 |
| `widget-clima` | esquerda | 1 | 2 |
| `widget-cambio` | esquerda | 3 | 1 |
| `widget-desempenho` | direita | 0 | 2 |
| `widget-discos` | direita | 2 | 1 |
| `widget-notas` | direita | 3 | 1 |

- Célula de um widget desligado: fica **vazia** (sem compactar; a grade é fixa, como na referência).
- Widgets do tema que não estão na tabela (mídia, tarefas, docker, rss e os que vierem): não se mexem, a
  não ser que o retângulo atual deles cruze algum retângulo do layout. Nesse caso, vão para o primeiro canto
  livre fora da área `TW·k × PH·k`, pela mesma regra do `--posicao` (e, se não houver lugar livre, ficam
  onde estão).
- Para um widget novo entrar no layout, basta uma linha nesta tabela (e no código). O DATA pode, se
  preferir, ler isto de um campo `"layoutFui": {"coluna":"esquerda","faixa":3,"faixas":1}` no bloco
  `X-CyberKDE` de cada `metadata.json`. Se for assim, avise que eu acrescento o campo nos meus.

Ao posicionar: grave a geometria, ponha `General/ajustado=true` (o preset do widget não pode desfazer o
tamanho) e não mexa em `General/modo`. Cada widget escolhe sozinho o que mostrar pelo tamanho que recebe.

## `--so-painel`

Só o Painel FUI muda, no centro da área útil, com `k = min((W − 2M) / PW, (H − 2M) / PH)`. Os outros
widgets ficam onde estão (e saem do caminho pela mesma regra dos widgets fora da tabela). O
`ocultosLayout` fica vazio.

**Automático:** se, no `fui` normal, sair `k < 0.75` (telas estreitas: em 1366×768, k = 0,79; abaixo de cerca
de 1290 px de largura útil já cai), aplique `--so-painel` e devolva `"soPainel":true` com o aviso
"A tela é estreita para as colunas: só o painel foi posicionado." / "The screen is too narrow for the
columns: only the dashboard was placed."

## Ocultar automático dos módulos repetidos

Quando um widget da tabela está **ligado e posto ao lado** pelo layout, o módulo equivalente do painel
sai, para não mostrar a mesma coisa duas vezes:

| Widget ligado no layout | Módulo escondido no Painel FUI |
|---|---|
| `widget-relogio` | `relogio` |
| `widget-clima` | `clima` |
| `widget-discos` | `discos` |

(O desempenho não esconde nada: o painel mostra os mesmos dados de outro jeito, e foi isso que a usuária
pediu dele.)

- Grave a lista, separada por vírgula, em `General/ocultosLayout` do applet do Painel FUI (por exemplo,
  `relogio, clima`), com `reloadConfig`, como as outras opções ao vivo. **Nunca** mexa em `General/ocultos`:
  ali fica a escolha da pessoa, e o painel junta as duas listas.
- Recalcule a lista sempre que um desses widgets for ligado ou desligado com o layout em `fui`.
- `livre` e `--so-painel` gravam `ocultosLayout` vazio.

## `livre` (e o que guardar antes do `fui`)

- Antes do **primeiro** `fui` (estado `livre` → `fui`), guarde a geometria atual de cada widget do tema
  na tela principal em `$state/layout-fui.tsv` (`efeito  applet  x  y  largura  altura`). Um segundo
  `fui` seguido não regrava o arquivo: senão, o "antes" vira o próprio layout.
- `livre` devolve a geometria guardada de quem ainda existe (o applet pelo id; um widget religado depois
  ganhou applet novo, então volta pelo efeito), esvazia `ocultosLayout` e apaga o arquivo. Widget sem
  geometria guardada (ligado já com o layout em `fui`) fica onde está.
- O `off` dos widgets já guarda tamanho e posição na cópia de `widgets-dados`. Com o layout em `fui`, a
  cópia guarda a posição do layout, e o `on` seguinte reaplica o `fui` de qualquer jeito.

## Exemplos (para conferir a implementação)

Grade de 16 px; `x y largura altura`.

**1920×1080, barra de 34 px em cima** (área 0,34 1920×1046; k = 1,1183):

| Widget | x | y | largura | altura |
|---|---|---|---|---|
| painelfui | 480 | 160 | 960 | 800 |
| relogio | 32 | 160 | 416 | 176 |
| clima | 32 | 368 | 416 | 384 |
| cambio | 32 | 784 | 416 | 176 |
| desempenho | 1472 | 160 | 416 | 384 |
| discos | 1472 | 576 | 416 | 176 |
| notas | 1472 | 784 | 416 | 176 |

**2560×1440, barra de 34 px em cima** (área 0,34 2560×1406; k = 1,5006):

| Widget | x | y | largura | altura |
|---|---|---|---|---|
| painelfui | 640 | 192 | 1280 | 1088 |
| relogio | 32 | 192 | 560 | 240 |
| clima | 32 | 480 | 560 | 512 |
| cambio | 32 | 1040 | 560 | 240 |
| desempenho | 1968 | 192 | 560 | 528 |
| discos | 1968 | 752 | 560 | 240 |
| notas | 1968 | 1040 | 560 | 240 |

**1366×768, sem barra** (k = 0,7873, acima de 0,75: ainda com colunas):

| Widget | x | y | largura | altura |
|---|---|---|---|---|
| painelfui | 352 | 96 | 656 | 576 |
| relogio | 32 | 96 | 288 | 128 |
| clima | 32 | 256 | 288 | 256 |
| cambio | 32 | 544 | 288 | 128 |
| desempenho | 1056 | 96 | 272 | 272 |
| discos | 1056 | 400 | 272 | 112 |
| notas | 1056 | 544 | 272 | 128 |

Nessa tela as células laterais ficam abaixo do limite de cartão de cada widget, que então mostra a forma
enxuta, e está certo assim.

Conta em Python, para os testes:

```python
import math
def layout_fui(X, Y, W, H, M=24, cel=16):
    k = min((W - 2*M) / 1674, (H - 2*M) / 732)
    X0, Y0 = X + (W - 1674*k) / 2, Y + (H - 732*k) / 2
    def grade(x, y, w, h):
        x0, y0 = math.ceil(x / cel) * cel, math.ceil(y / cel) * cel
        return (x0, y0, math.floor((x + w) / cel) * cel - x0, math.floor((y + h) / cel) * cel - y0)
    col = {"esquerda": X0, "painel": X0 + 404*k, "direita": X0 + 1294*k}
    celula = lambda c, b, n: grade(col[c], Y0 + 187*b*k, 380*k, (187*n - 15)*k)
    return k, {"painelfui": grade(col["painel"], Y0, 866*k, 732*k),
               "relogio": celula("esquerda", 0, 1), "clima": celula("esquerda", 1, 2), "cambio": celula("esquerda", 3, 1),
               "desempenho": celula("direita", 0, 2), "discos": celula("direita", 2, 1), "notas": celula("direita", 3, 1)}
```

## Testar (sem a sessão real)

`plasmashell` isolado no Xvfb (memória `widgets-teste-isolado`), com tela de 1920×1080, os widgets ligados
pelo CLI falso e `widget-layout fui`. Confira, por `evaluateScript`, a geometria de cada um contra a tabela
acima; confira `ocultosLayout` do Painel FUI ao ligar e desligar o relógio; e confira que `livre` volta às
posições anteriores.
