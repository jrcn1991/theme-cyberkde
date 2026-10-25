# Animações do painel: de onde vêm os tempos

Referências: os GIFs em `app_portfolio_cyberpunk/Portfolio Refeencias/` (quadros extraídos com
`magick X.gif -coalesce`, tempos lidos dos atrasos de cada quadro) e as coreografias já usadas no site
irmão (`app_portfolio_cyberpunk/site/src/motion/coreografias.ts`, `PortfolioDesign.md` §13–14).

## O que a referência faz, quadro a quadro

**"Aniamção de janelas" (391 quadros, ~33 ms cada, 13 s)**

| Tempo | Evento |
|---|---|
| 0–270 ms | tela preta |
| 300 ms | primeiro traço (barra do topo) começa a se desenhar da esquerda |
| 330–500 ms | quadrados soltos acendem em posições espalhadas, em 1–2 quadros cada |
| 430–900 ms | molduras dos painéis traçadas linha a linha; cada painel começa 100–150 ms depois do anterior |
| 670–900 ms | gráficos se traçam; grades tracejadas aparecem |
| 1300–1600 ms | células da grade acendem uma a uma (em degraus) |
| 1500 ms em diante | texto de terminal linha a linha (~100 ms por linha); depois, laço "vivo" |

**"Efeito de logo" (107 quadros, ~33 ms, 3,5 s)**

| Tempo | Evento |
|---|---|
| 0–270 ms | escuro avermelhado com blocos de microtexto de dados |
| 300–400 ms | tracinhos ciano esparsos e brilhos diagonais |
| 430–630 ms | feixes horizontais densos (ciano) com pontos de brilho; um traço amarelo entra pela esquerda; tracejado corre no topo |
| 670–930 ms | o logo surge em fatias horizontais deslocadas, cruzado por fios ciano |
| 970–1030 ms | fatias quase no lugar, com franja ciano (aberração cromática) |
| 1070–1200 ms | assenta com flicker e brilho |
| 1200–1330 ms | "2077" escrito sobre uma linha de dados |

**"Efeito de logo2" / "efeito de logo3" (135 quadros, 20 ms)**: as camadas separadas: o circuito do logo
(linhas diagonais paralelas e nós quadrados, tremulando) e as partículas (rajadas de traços
horizontais a cada ~1,1 s, pontos e brilhos diagonais entre elas).

## Como o painel traduz

O painel é usado o tempo todo; as aberturas de seção são aceleradas (~0,45×), a abertura do app fica
perto do tempo da referência.

| Onde | Componente | Coreografia |
|---|---|---|
| Entrada de seção | `Cascata` + `Chanfro.traco` | seção nova começa vazia; cada painel, com atraso de 45 ms × ordem: moldura traçada a partir do canto (280 ms, linear, ponta brilhante), quadrados piscando (`QuadradosMontagem`), superfície a partir de 180 ms, conteúdo acende com flicker de liga e desliga (quadros de 33 ms: 75 → 10 → 90 → 35 → 100%), borda pisca na secundária ao fechar |
| Modais | `Modal` | fundo escurece (120 ms); moldura traçada (60–340 ms); superfície (200–340); conteúdo com flicker (300–440); título decodifica quando a moldura fecha |
| Inspetor de corporação | `InspetorCorp` | troca de seleção: o painel limpa e reacende com flicker; borda pisca; logo se monta (`LogoMontagem` "medio", 780 ms); nome decodifica |
| Abertura | `Abertura` + `LogoMontagem` "completo" | microtexto nos cantos com piscadas; logo largo oficial: feixes → circuito → fatias com aberração → flicker e brilho (1,25 s); nome da corporação escrito letra a letra sobre uma linha (o "2077"); cortina abre em 1,45 s |
| Troca de corporação | `GlitchTela` + `LogoMontagem` "compacto" | faixas de glitch e linhas de dados atravessando a tela, varredura que revela a paleta nova; o logo do cabeçalho e do menu se monta (520 ms) |

Curvas: entrada `Easing.OutExpo` (o `expo.out` do site irmão); traços lineares; flicker em degraus de
um quadro (o `steps(4)` do site).

## Desempenho

- Nada fica em laço: a faixa de varredura passa uma vez por troca de seção; a varredura ociosa do logo
  é disparada por `Timer` (12 s) e dura 0,7 s. Em repouso a janela fica parada (medido: ~4 quadros/s
  em média, só das rajadas curtas de acento; 0 com "reduzir animações").
- Efeitos com shader (`MultiEffect`, `ShaderEffect`) só existem enquanto a montagem roda; o
  `LogoMontagem` deriva tudo de um único `t` animado.
- Medido no modo offscreen com OpenGL (RTX 3060): ~57 quadros/s na abertura, a mais pesada.
- "Reduzir animações" desliga tudo isso: as telas aparecem prontas.
