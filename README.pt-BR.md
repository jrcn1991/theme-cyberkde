<p align="center">
  <img src="assets/readme/desktop-corps.gif" width="100%" alt="Área de trabalho do CyberKDE trocando de corporação: Arasaka, Militech, Biotechnica, NetWatch, Kang Tao e Trauma Team, com a transição de glitch">
</p>

<h1 align="center">CyberKDE</h1>

<p align="center">
  <b>Um tema cyberpunk para o KDE Plasma 6, inspirado nos menus de Cyberpunk 2077.</b><br>
  <code>SYS://CYBERKDE</code> · Plasma 6 · Wayland · 14 corporações · painel gráfico · Cyber Fence · DATASHARD · widgets · ilha dinâmica · tudo reversível
</p>

<p align="center">
  <a href="README.md">Read in English</a> ·
  <a href="#instalar">Instalar</a> ·
  <a href="#o-painel">Painel</a> ·
  <a href="#cyber-fence">Cyber Fence</a> ·
  <a href="#datashard">DATASHARD</a> ·
  <a href="#widgets">Widgets</a> ·
  <a href="#ilha-dinâmica">Ilha</a> ·
  <a href="#comandos">Comandos</a> ·
  <a href="#créditos-e-marcas">Créditos</a>
</p>

Fiz este tema para usar no meu computador e resolvi compartilhar. Ele muda as cores, as janelas, os ícones, o terminal, o cursor, os sons e a tela de login, e traz cercas para a área de trabalho, um gerenciador de arquivos, widgets e animações por todo lado. Liga com `cyberkde on`; o `cyberkde off` deixa tudo como estava antes.

> [!IMPORTANT]
> **This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED.**
> Obra de fã não oficial, sem aprovação nem endosso da CD PROJEKT RED.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Corporações

`SYS.01 // CORP.SELECT`

Uma corporação troca o tema inteiro de uma vez: a cor de destaque, a secundária, a cor de alerta, o tom das superfícies, o ícone do botão do menu, o logo da tela de abertura e o papel de parede. No painel, passar o mouse num cartão mostra a paleta antes de aplicar; ao confirmar, a interface faz o glitch e assenta na paleta nova.

<p align="center">
  <img src="assets/readme/painel-previa-pt.gif" width="100%" alt="Seção Corporação do painel: o mouse passa pelos cartões da Militech, NetWatch, Biotechnica, Kang Tao e Trauma Team, e o painel inteiro se recolore na paleta de cada uma">
</p>

<p align="center">
  <img src="assets/readme/corporacoes.png" width="100%" alt="As 14 corporações: Arasaka, Biotechnica, Delamain, Dynalar, Kang Tao, Kiroshi, Militech, Moore Tech, NetWatch, Night Corp, Petrochem, Segotari, Trauma Team e Zetatech, cada uma com logo, id e paleta">
</p>

```bash
cyberkde corp militech     # aplica a corporação (o login, que precisa de sudo, pede a senha no fim)
cyberkde corp --lista      # todas, com as cores de cada uma
cyberkde corp nenhuma      # volta à paleta do próprio tema
```

As paletas ficam em `tokens/corporacoes.json` (fonte única do CLI e do painel): edite e rode `cyberkde corp <id>` de novo. Uma cor escolhida à mão com `cyberkde cor '#hex'` troca só o destaque. Para usar outro logo, ponha `<id>.svg` ou `.png` (ícone do menu) e `<id>-logo.svg` ou `.png` (abertura; `<id>-logo-escuro` para fundo escuro) em `~/.config/cyberkde/corporacoes/`, ou use o botão "Escolher logo…" do painel. Essas imagens ficam só na sua máquina, e o `cyberkde uninstall` não as apaga.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## O painel

`SYS.02 // CONTROL.PANEL`

Tudo o que o CLI faz também está num painel gráfico, que abre com `cyberkde painel` ou pelo menu de aplicativos (mesmo com o tema desligado). Ele liga e desliga o tema e cada parte, escolhe a corporação ou uma cor, monta a página de configurações sozinho a partir da lista de efeitos do CLI, roda o diagnóstico e guarda o registro de tudo o que foi aplicado. Fala português e inglês.

São dez seções: STATUS, CORPORAÇÃO, CONFIGURAÇÕES, WIDGETS (galeria, inspetor, mapa da tela, modo de edição e layout FUI), ARQUIVOS (abrir o DATASHARD e escolher se ele é o padrão), CYBER FENCE (cercas, animações, regras, layouts e backup), ILHA (tema, módulos, animações e atalhos), PAPEL DE PAREDE (animado ou estático, com aviso sobre a sua placa de vídeo), DIAGNÓSTICO e REGISTRO.

A interface segue a mesma linguagem do tema: a abertura monta o logo da corporação em fatias, cada seção entra com as molduras se traçando e os cartões acendendo, e trocar de corporação passa por um glitch que revela a paleta nova. "Reduzir animações" (ou o movimento "mínimo" do tema) desliga tudo isso.

<p align="center">
  <img src="assets/readme/painel-abertura-pt.gif" width="100%" alt="Abertura do painel: feixes de dados, o logo da Arasaka se montando em fatias com aberração de cor, o nome escrito letra a letra e a cortina abrindo para a seção Status">
</p>

**Seções.** Cada troca de seção traça as molduras a partir do canto, acende os cartões em sequência e decodifica o título.

<p align="center">
  <img src="assets/readme/painel-secoes-pt.gif" width="100%" alt="O painel passando por Corporação, Configurações e Papel de parede: o título decodifica, as molduras se traçam e os cartões acendem um a um">
</p>

**Aplicar uma corporação.** O cartão escolhido mostra a paleta, o modal pede confirmação e, ao confirmar, a tela passa pelo glitch, a barra de progresso acompanha o CLI e o logo do inspetor se remonta.

<p align="center">
  <img src="assets/readme/painel-aplicar-pt.gif" width="100%" alt="Aplicando a Militech: clique no cartão, botão Aplicar, modal Militech Protocol, glitch amarelo, progresso das fases e o logo se montando no inspetor">
</p>

**Configurações.** O seletor de movimento, os presets de interface e, em cada grupo, as opções com prévia animada: na galeria de janelas, cada uma das 21 animações toca quando o mouse passa por cima.

<p align="center">
  <img src="assets/readme/painel-config-pt.gif" width="100%" alt="Seção Configurações: seletor de movimento, presets de interface e a galeria de animações de janela, com as prévias tocando sob o mouse">
</p>

**Terminal.** O cartão da cascata do Konsole mostra a prévia ao vivo; a altura da faixa e as cores mudam com um clique, e cada mudança é confirmada no canto da tela.

<p align="center">
  <img src="assets/readme/painel-cascata-pt.gif" width="100%" alt="Cartão da cascata de dados do Konsole: a prévia da pluma colorida tocando, a altura da faixa mudando de 19 para 6 linhas e as cores entre vídeo e tema">
</p>

| | |
|---|---|
| ![Status: núcleo de energia, telemetria e avisos](assets/readme/painel-status-pt.jpg) | ![Corporação: grade das 14 corporações e o inspetor da Militech, com dossiê, paleta e o botão do menu](assets/readme/painel-corporacao-pt.jpg) |
| ![Configurações, visão geral: movimento, grupos e presets de interface](assets/readme/painel-config-pt.jpg) | ![Configurações, grupo Janelas: abrir, fechar e 1ª abertura, intensidade e durações](assets/readme/painel-config-janelas-pt.jpg) |
| ![Widgets: modo de edição, layout FUI, galeria e inspetor](assets/readme/painel-widgets-pt.jpg) | ![Arquivos: o DATASHARD e a escolha do gerenciador padrão](assets/readme/painel-arquivos-pt.jpg) |
| ![Cyber Fence, aba Regras: regras ativas, simular, aplicar e histórico](assets/readme/painel-regras-pt.jpg) | ![Papel de parede: seleção atual, o FUI animado e as opções estáticas](assets/readme/painel-papel-pt.jpg) |
| ![Diagnóstico: requisitos conferidos, com o comando de correção de cada aviso](assets/readme/painel-diagnostico-pt.jpg) |

O painel nunca grava a configuração do tema por conta própria: ele só chama o `cyberkde`, um comando de cada vez, e nunca pede senha (o que precisa de sudo vira um comando para o terminal).

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Cyber Fence

`SYS.03 // DESK.FENCES`

Cercas para a área de trabalho: cada cerca é uma pasta real numa moldura do tema, que recolhe até só o título. Ela sai do mesmo código da Visão de pasta do Plasma, então arrastar, abrir, renomear e o menu de contexto funcionam como você espera. Crie quantas quiser, em qualquer tela.

<p align="center">
  <img src="assets/readme/cerca-animacoes.gif" width="100%" alt="Cercas reais exibindo os ícones com a Explosão de dados e as variantes sem estouro e tóxica, Quickhack, Braindance e Sandevistan">
</p>

**Na cerca.** Pasta real ou lista de atalhos (o que você solta vira atalho e nada sai do lugar), abas com outras pastas, filtro por tipo, densidade compacta, subpasta em popup, cor da paleta, fundo desfocado e o gatilho de recolher (Ctrl+clique, clique ou ao sair o mouse). Soltar arquivos move direto; Ctrl copia, e dá para desfazer.

**Ocultar e peek.** Duplo clique na área de trabalho oculta as cercas e outro traz de volta; uma cerca marcada com "Não ocultar" fica à vista. O peek traz as cercas por cima das janelas.

**Regras.** Arquivos soltos na área de trabalho vão para a cerca certa por extensão ou parte do nome. Simule antes, aplique uma vez ou deixe vigiando; cada lote pode ser desfeito, e o que for sobrescrito fica guardado até lá.

<p align="center">
  <img src="assets/readme/cerca-organizar.gif" width="100%" alt="Cercas recolhendo até o título e voltando; depois uma regra leva os PDFs da área de trabalho para a cerca Contratos, e o desfazer os devolve">
</p>

**Layouts.** Salve a posição, o tamanho e a configuração de todas as cercas com um nome e restaure quando quiser, inclusive sozinho ao trocar de monitor (`--por-resolucao on`). O backup exporta e importa regras, layouts e o layout atual num arquivo só.

**Animações.** 16 para ocultar e exibir as cercas e 13 para os ícones: Explosão de dados (também sem estouro e tóxica), Quickhack, Braindance, Sandevistan, Cascata, Decodificação, Varredura, Montagem, Glitch cromático, Mosaico e Nenhuma. Todas têm prévia na seção CYBER FENCE do painel.

| | |
|---|---|
| ![As 16 animações de ocultar e exibir](assets/readme/cerca-16-animacoes.gif) | ![As 13 animações dos ícones, em cercas reais](assets/readme/cerca-icones.gif) |

**Atalhos globais** (desligados até você ligar; se a combinação já tiver dono, o tema avisa ou escolhe a próxima livre):

| Atalho | Ação |
|---|---|
| `Meta+Shift+F` | nova cerca (pergunta o nome) |
| `Meta+Shift+H` | mostrar ou ocultar todas |
| `Meta+Shift+Space` | peek: cercas por cima das janelas |

```bash
cyberkde cerca nova --titulo Contratos        # nova cerca na tela do mouse, com pasta própria
cyberkde cerca alternar                       # também: mostrar | ocultar | peek [on|off|alternar]
cyberkde efeito widget-cerca --atalhos on     # liga os atalhos (--atalho-nova, --atalho-alternar, --atalho-peek)
cyberkde efeito widget-cerca --instancia 2 --animacao glitch --animacaoIcones cascata

cyberkde cerca regras adicionar --destino cerca:1 --extensoes pdf,doc --nome Documentos
cyberkde cerca regras aplicar --simular       # mostra o que moveria; sem --simular, move
cyberkde cerca regras desfazer                # desfaz o último lote
cyberkde efeito widget-cerca --vigiar on      # arquivo novo na área de trabalho segue as regras sozinho

cyberkde cerca snapshot salvar Trabalho       # também: restaurar | listar | apagar
cyberkde efeito widget-cerca --por-resolucao on
cyberkde cerca backup                         # também: exportar <arquivo> | importar <arquivo> [--aplicar]
```

Tudo fica em `~/.config/cyberkde/cercas/`, que o `cyberkde uninstall` preserva. Remover uma cerca nunca apaga a pasta dela. Sem nome nem pasta, as cercas novas ficam em `Documentos/Cercas` (`--base` muda). As regras nunca mexem em ocultos, atalhos, links, pastas nem downloads pela metade.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## DATASHARD

`SYS.04 // FILE.MANAGER`

O gerenciador de arquivos do tema: cada pasta é um shard. Ele convive com o Dolphin, fica no menu de aplicativos e abre com `cyberkde arquivos`. Ser o padrão do sistema é escolha sua, e desligar devolve o Dolphin.

<p align="center">
  <img src="assets/readme/datashard-pt.gif" width="100%" alt="DATASHARD: pilhas de pastas acendendo ao selecionar, a pasta Imagens, as visões lista e grade e a prévia de uma imagem">
</p>

| Recurso | Como é |
|---|---|
| Visões | PILHAS isométricas que acendem ao selecionar, LISTA de dados e GRADE com miniaturas; cada pasta lembra a sua |
| Navegação | abas, tela dividida, caminho em código clicável (Ctrl+L edita) e Locais com discos e barra de uso |
| Painel LOG | os detalhes se escrevem como um terminal, com prévia, etiquetas, avaliação e comentário |
| Prévia | Espaço abre imagem, vídeo, áudio, PDF e texto sem sair da pasta |
| Operações | fila com progresso, conflitos com escolha, compactar e extrair, renomeação em lote e desfazer com Ctrl+Z (até 30 passos) |
| Busca | filtra a pasta enquanto digita; Enter busca nas subpastas |
| Segurança | sem rede; Del vai para a lixeira, e apagar de vez sempre pede confirmação |
| Tema | cores da corporação, PT/EN e as animações do tema, que respeitam o nível de movimento |

```bash
cyberkde arquivos ~/Downloads     # abre o DATASHARD nessa pasta
cyberkde arquivos --checar        # só confere os pacotes (e mostra os opcionais)
cyberkde efeito datashard on      # padrão para pastas e "Mostrar na pasta"; off devolve o Dolphin
```

F1 mostra os atalhos de teclado. Um `dolphin --daemon` que já esteja rodando continua atendendo o "Mostrar na pasta" até o próximo login.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Widgets

`SYS.05 // DESK.WIDGETS`

Onze widgets do Plasma no visual do tema, nas cores da corporação, mais o Painel FUI e seus 15 módulos avulsos. No modo de edição, cada um muda de tamanho à mão ou pelos presets P·M·G; fora dele, mostra só os dados. O que você escreve neles (notas, gigs, listas) fica guardado ao desligar e volta ao ligar.

<p align="center">
  <img src="assets/readme/widgets.jpg" width="100%" alt="Os widgets nos tamanhos pequeno, médio e grande: notas, gigs, câmbio, mídia, notícias, Docker, relógio e desempenho">
</p>

| Widget | O que mostra |
|---|---|
| Relógio | hora HUD, segundo fuso, calendário e próximos eventos |
| Clima | agora, próximas horas e até 5 dias (Open-Meteo, sem conta) |
| Desempenho | CPU por núcleo, memória, GPU, temperaturas, rede e disco |
| Mídia | o que está tocando, nos estilos HUD, Jukebox, Jukebox mini, só equalizador e Rádio Neon |
| Notas | quadro de notas com cores, fixar, reordenar e checklist |
| Gigs | tarefas como contratos: prioridade, prazo, contratante e status |
| Câmbio | cotações em "eddies", com a variação do dia e gráfico |
| Discos | espaço de cada unidade, alerta ao encher, leitura e escrita ao vivo |
| Docker | contêineres com estado, CPU e memória; inicia, para e reinicia |
| Rede | interface, IP, velocidade, ping, perda e VPN (IP público desligado por padrão) |
| Notícias | manchetes dos feeds RSS/Atom escolhidos |

**Painel FUI.** O painel de interface de Cyberpunk 2077 em grade 4×3, com dados reais do sistema, que escala sem mudar a proporção. O layout `fui` o põe no centro da tela principal, com os widgets ligados em colunas dos lados. Cada um dos 15 módulos também existe sozinho: CPU, Núcleos, Sensores, Memória, GPU, Discos, E/S, Rede, Tráfego, Processos, Log, Sistema, Hora, Clima e Estados.

<p align="center">
  <img src="assets/readme/painel-fui.jpg" width="80%" alt="Painel FUI: núcleos, log, sensores, CPU, processos, GPU, discos, hora, clima, memória, rede e E/S, com dados fictícios de exemplo">
</p>

**Jukebox e Rádio Neon.** O widget Mídia ganhou a tela grande do jukebox do jogo, com equalizador de 12 bandas, "now playing" e botão de volume, e o rádio de néon, com letreiro, moldura que cintila e o selo com a capa do álbum. O equalizador pode ser sintético ou ler o som de verdade (`--espectroReal true`, com PipeWire e numpy; gasta mais CPU), nas cores da corporação ou nas do jukebox (`--paletaJukebox true`).

| | |
|---|---|
| ![Estilo Jukebox do widget Mídia](assets/readme/midia-jukebox.gif) | ![Estilo Rádio Neon do widget Mídia](assets/readme/midia-neon.gif) |

```bash
cyberkde efeito widget-relogio on --posicao superior-direito --modo medio
cyberkde efeito widget-midia on --estilo neon             # hud | jukebox | mini | eq | neon
cyberkde efeito widget-clima --cidade "Night City"        # opções: cyberkde efeito --lista
cyberkde efeito widget-painelfui on
cyberkde efeito widget-layout fui                         # livre devolve cada um ao seu lugar
cyberkde efeito widget-fui-cpu on                         # um módulo sozinho: widget-fui-<módulo>
cyberkde edicao alternar                                  # modo de edição do Plasma: on | off | alternar
```

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Ilha dinâmica

`SYS.06 // DESK.ISLAND`

Uma pílula no topo da tela que mostra o que está acontecendo e abre num painel ao passar o mouse ou clicar. É o porte da ilha do Halo para PyQt6 e QML, com layer-shell nativo: flutua acima de tudo, o clique fora dela atravessa e ela some sozinha com janela em tela cheia. Desligada por padrão; o tema funciona sem ela.

<p align="center">
  <img src="assets/readme/ilha-pt.gif" width="100%" alt="Ilha dinâmica nos temas Halo, Linhas, Neomilitar e Punk exacerbado: aviso na pílula, painel aberto com mídia e atalhos, e HUD de volume">
</p>

| Tema | Como é |
|---|---|
| Halo | a placa preta da ilha do Halo, com as molas e os três estilos |
| Linhas | suave: só linhas finas na cor do tema |
| Neomilitar | chanfro, cantoneiras, micro-dados e moldura traçada |
| Punk exacerbado | glitch, aberração cromática, alerta em bloco e letreiro nas passadas |

**Módulos.** Mídia com espectro, áudio e HUD de volume, avisos, rede, Bluetooth, sistema, relógios, área de trabalho (silêncio, cafeína), cópias, downloads, capturas, gaveta de arquivos, janelas guardadas, celular, discos, teclado, foco com temporizador e uma API local para scripts. Cada um pode ser ligado ou desligado, e tudo se ajusta na seção ILHA do painel: tema, estilo, animação, posição, gesto de abrir, módulos e atalhos.

**Rede.** Letras sincronizadas e clima vêm **desligados**, porque usam a rede: as letras mandam título e artista a [lrclib.net](https://lrclib.net), e o clima consulta open-meteo.com com as coordenadas do widget Clima. O histórico de cópias fica só na memória. Com a ilha do Halo aberta, a do tema fica escondida e avisa.

```bash
cyberkde ilha on          # liga (e entra no login); off desliga
cyberkde ilha status      # estado; --json para programas
```

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Janelas

`SYS.07 // WINDOW.FX` · 21 animações de abrir e fechar

<p align="center">
  <img src="assets/readme/janelas-pt.gif" width="100%" alt="Grade com as 21 animações de janela abrindo e fechando: varredura, moldura traçada, glitch RGB, dados que sobem, holograma, boot de CRT, decodificação e outras">
</p>

Cada animação vale para abrir, para fechar ou para os dois, com duração e intensidade ajustáveis, e uma pode ficar só para a primeira janela de cada app. A moldura das janelas (Aurorae) é chanfrada, nas cores da corporação.

```bash
cyberkde efeito janelas --lista                     # as 21, com descrição e prévia
cyberkde efeito janelas --abrir glitch --fechar crt # escolhe por id
cyberkde efeito movimento reduzido                  # completo | reduzido (só dissoluções curtas) | minimo (nenhum)
```

Ids: `scan`, `moldura`, `glitch`, `dados`, `holograma`, `crt`, `decodificar`, `chanfro`, `braindance`, `cacos`, `convergir`, `desintegrar`, `terminal`, `neon`, `modal`, `pulso`, `pixel`, `persiana`, `portas`, `radar`, `fade`.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Terminal

`SYS.08 // KONSOLE.FX` · cascata de dados + 8 efeitos

No Konsole animado, as linhas que saem da tela sobem numa faixa acima do texto, como uma pluma colorida que se desintegra. O texto nunca é coberto.

<p align="center">
  <img src="assets/readme/konsole-cascata.gif" width="100%" alt="Cascata de dados no Konsole: as linhas que rolam para fora sobem como uma pluma colorida que se desfaz">
</p>

E mais oito efeitos, todos desligados por padrão e com parâmetros próprios (intensidade, densidade, cores do tema ou do vídeo):

<p align="center">
  <img src="assets/readme/konsole-efeitos-pt.gif" width="100%" alt="Os oito efeitos do Konsole: chuva de glifos, grade holográfica, monitor CRT, varredura de luz, HUD nas margens, faíscas ao digitar, glitch no erro e pulso na campainha">
</p>

```bash
cyberkde efeito konsole-cascata on --linhas 8 --cores tema
cyberkde efeito konsole-chuva on     # também: konsole-grade, -crt, -varredura, -hud, -faiscas, -erro, -campainha
```

Os efeitos do terminal precisam do Konsole animado (veja [Dolphin e Konsole animados](#opcional-dolphin-e-konsole-animados)). No Konsole do sistema, o tema aplica o esquema de cores e o perfil.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Estilos e presets

`SYS.09 // UI.STYLE`

O estilo Kvantum dos apps tem 15 ajustes finos (seleção, brilho neon, corte da moldura, densidade, abas, barra de progresso, foco, textura de fundo, dicas, campos, cores de estado…) e sete presets que gravam vários de uma vez.

<p align="center">
  <img src="assets/readme/presets-pt.gif" width="90%" alt="Os sete presets de interface em sequência: Neomilitar, Militar denso, NetWatch limpo, Arasaka luxo, Terminal gasto, Kitsch neon e Leitura">
</p>

```bash
cyberkde efeito estilo-preset --variante netwatch-limpo
cyberkde efeito estilo-corte --variante octogono   # cada ajuste: cyberkde efeito --lista mostra as opções
```

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Login, abertura e bloqueio

`SYS.10 // AUTH`

A tela de login (SDDM), a tela de abertura e a tela de bloqueio seguem a corporação. A entrada do painel, a posição dele, a confirmação de acesso e a duração da abertura são escolhas suas.

<p align="center">
  <img src="assets/readme/login-pt.gif" width="100%" alt="Animações da tela de abertura, do login e do bloqueio: abertura completa, entradas do painel, acesso liberado, painel à esquerda e desbloqueio">
</p>

```bash
cyberkde efeito splash completo                       # completo | curto | nenhum
cyberkde efeito login --entrada fatias --painel esquerda
```

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Papéis de parede, cursor, sons e ícones

`SYS.11 // AMBIENT`

**Papéis de parede.** Quatro opções estáticas para a área de trabalho, o bloqueio e o login, sempre na cor de destaque, mais o papel da corporação, que muda junto com ela (`cyberkde efeito papel corp`, como no topo desta página). `cyberkde papel ~/Imagens/minha.jpg` usa uma imagem sua.

<p align="center"><img src="assets/readme/papeis.png" width="80%" alt="As quatro opções de papel de parede: HUD e cidade, moldura técnica, cidade e painéis"></p>

**Papel animado FUI.** Um papel de parede vivo, com fumaça, feixes com pulsos de luz, partículas, retículo HUD, glitch curto e o logo e o lema da corporação, que se montam ao aparecer. Ele acompanha a corporação, anima só na área de trabalho (no bloqueio e no login fica um quadro parado) e pausa com janela maximizada ou em tela cheia. Gasta de 2 a 4% de uma placa de vídeo dedicada; numa integrada, prefira os estáticos. Intensidade, velocidade, 30 ou 60 fps, logo e textos ficam na seção PAPEL DE PAREDE do painel.

<p align="center">
  <img src="assets/readme/papel-fui.gif" width="100%" alt="Papel animado FUI em seis corporações: Arasaka, Militech, NetWatch, Biotechnica, Kang Tao e Trauma Team">
</p>

```bash
cyberkde efeito papel fui        # animado; a | b | c | d = estáticos fixos; corp = o da corporação
```

**Cursor.** Cursores com cantoneiras e o destaque do tema, em quatro variantes: padrão, neon, mínimo e mira (com a mão que fecha colchetes). É opcional: `cyberkde efeito cursor neon` liga, e `off` devolve o de antes.

<p align="center"><img src="assets/readme/cursores.png" width="90%" alt="As quatro variantes do cursor: padrão, neon, mínimo e mira"></p>

**Sons.** Bipes e varreduras baixos, sintetizados para o tema, em doze eventos (notificação, aviso, erro, login, dispositivos, lixeira, volume…), nas variantes padrão e discreto. Desligados por padrão: `cyberkde efeito som padrao` liga, e `off` devolve os de antes.

**Ícones.** Pastas, locais, tipos de arquivo e um golfinho ciborgue para o Dolphin; seis ícones têm um segundo estilo para escolher um a um (`cyberkde efeito icones`). O resto herda o Breeze Escuro.

**Ícones dos apps.** Os apps favoritos ganham ícone próprio: o logo vem do app instalado na sua máquina (nenhum logo de marca vai no repositório), dentro da moldura chanfrada do tema, e a moldura acompanha a corporação. São 3 estilos: `marca` (o logo original, nas cores da marca), `recolorido` (o logo nos tons do destaque) e `silhueta` (a silhueta desenhada pelo tema). App sem ícone instalado cai na silhueta.

<p align="center"><img src="assets/readme/icones-apps.gif" width="90%" alt="Ícones dos apps no estilo marca, com a moldura mudando de cor de Segotari para Arasaka, Militech e Biotechnica, e depois os estilos recolorido e silhueta"></p>

```bash
cyberkde efeito icones-apps marca      # marca | recolorido | silhueta
```

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## O que ele muda

| Parte | O que muda |
|---|---|
| Cores + Kvantum | esquema de cores e estilo Kvantum chanfrado para todos os apps Qt/KDE, com 15 ajustes e 7 presets |
| Corporação | paleta completa, ícone do menu, logo da abertura e emblema no papel de parede (14 corporações) |
| Arranjo | barra em cima e dock embaixo; também duas telas, compacto e lateral (`cyberkde layout`) |
| Janelas | moldura Aurorae e 21 animações de abrir e fechar (KWin) |
| Plasma | estilo do Plasma (painel, menus, popups, notificações), menu em lista, grade ou tela cheia |
| Ícones | pastas, locais, tipos de arquivo e o golfinho do Dolphin; seis ícones alternativos; apps favoritos com o próprio logo na moldura do tema (3 estilos) |
| Konsole | esquema de cores e perfil; no Konsole animado, a cascata de dados e mais 8 efeitos |
| Login | SDDM, tela de abertura e tela de bloqueio, com animações escolhíveis |
| Papel de parede | quatro opções na cor de destaque, o da corporação, o animado FUI ou uma imagem sua |
| Cyber Fence | cercas na área de trabalho, com regras, layouts, 16+13 animações e atalhos |
| DATASHARD | gerenciador de arquivos do tema, ao lado do Dolphin |
| Widgets | 11 widgets, o Painel FUI e 15 módulos, com Jukebox e Rádio Neon na mídia |
| Ilha dinâmica | pílula no topo da tela com módulos do sistema e 4 temas (desligada por padrão) |
| Opcionais | cursor (4 variantes), sons (2 variantes), anel no clique, áreas de trabalho como módulos |
| Painel | interface gráfica para tudo isso, em português e inglês |

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Instalar

`SYS.12 // INSTALL`

Requisitos: KDE Plasma 6, `python3`, ImageMagick, `qdbus6`, os ícones Breeze e o Kvantum para Qt 6. O painel gráfico, o DATASHARD, a Cyber Fence e a ilha usam o PyQt6 e alguns módulos QML do Qt 6; o tema funciona sem eles.

```bash
# Ubuntu / Debian / Kubuntu
sudo apt install git python3 imagemagick qdbus-qt6 kf6-breeze-icon-theme qt-style-kvantum
# para o painel gráfico (cyberkde painel):
sudo apt install python3-pyqt6 python3-pyqt6.qtqml python3-pyqt6.qtquick qml6-module-qtqml qml6-module-qtquick qml6-module-qtquick-effects \
  qml6-module-qtquick-shapes qml6-module-qtquick-dialogs qml6-module-qtquick-window
# para o DATASHARD (os do painel e mais este) e para a Cyber Fence:
sudo apt install qml6-module-qtmultimedia qml6-module-qt-labs-folderlistmodel
# para a ilha dinâmica (os do painel e mais este):
sudo apt install qml6-module-org-kde-layershell
# opcionais da ilha: volume e espectro, OCR de capturas, celular, temperaturas
sudo apt install pulseaudio-utils tesseract-ocr tesseract-ocr-por spectacle kdeconnect lm-sensors
# opcionais: miniaturas de vídeo e PDF, 7z no DATASHARD; equalizador real do widget Mídia
sudo apt install ffmpegthumbnailer poppler-utils 7zip python3-numpy
# outras distribuições: instale os pacotes equivalentes (o instalador lista o que faltar)

git clone https://github.com/jrcn1991/theme-cyberkde.git
cd theme-cyberkde
./instalar.sh --ligar    # instala e já liga (./instalar.sh só instala)
```

Antes de copiar qualquer coisa, o instalador confere os requisitos e os problemas conhecidos abaixo e mostra a correção de cada um. Um item com `✗` impede a instalação. Um item com `!` deve ser corrigido antes (com `--continuar`, segue assim mesmo). A mesma checagem roda a qualquer hora com `cyberkde checar`.

No Ubuntu 26.04, ele também oferece instalar o [Latte Dock NG](https://github.com/jrcn1991/latte-dock-ng), a dock das capturas (`--sem-latte` pula): o pacote gerado a partir de um commit revisado do fork [jrcn1991/latte-dock-ng](https://github.com/jrcn1991/latte-dock-ng) do [Latte Dock NG](https://github.com/ruizhi-lab/latte-dock-ng) (que por sua vez é a versão para o Plasma 6 do [Latte Dock](https://invent.kde.org/plasma/latte-dock) da KDE), conferido por um SHA-256 fixo no tema. O Latte só é oferecido onde foi validado de ponta a ponta (por enquanto, o Ubuntu 26.04); nos outros sistemas, a dock é um painel flutuante do Plasma. Nada é compilado na sua máquina. Se você já usa o Latte, o tema usa o seu.

A instalação é por usuário. O root só é pedido para o pacote do Latte e para a tela de login. O programa fica em `~/.local/opt/cyberkde` e o comando em `~/.local/bin/cyberkde`, então a pasta clonada pode ser apagada depois. Para atualizar, baixe a versão nova e rode `./instalar.sh` de novo.

### Problemas conhecidos

| Problema | Correção |
|---|---|
| `cyberkde: comando não encontrado` logo depois de instalar | O `~/.local/bin` só entra no `PATH` no login, se a pasta já existir. Saia e entre na sessão; até lá, use `~/.local/bin/cyberkde` ou `export PATH="$HOME/.local/bin:$PATH"`. O `./instalar.sh --ligar` não precisa disso. |
| Tela de login preta depois de reiniciar (Ubuntu com SDDM, sem Xorg) | O SDDM precisa rodar em Wayland. O `cyberkde checar` mostra o arquivo de `/etc/sddm.conf.d` a criar. Não é causado pelo tema. |
| Sem animações numa máquina virtual | Com vídeo por software (llvmpipe), o KWin desliga todas as animações. Ligue a aceleração 3D da VM. O `cyberkde status` diz se as animações estão carregadas. |

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Comandos

`SYS.13 // CLI`

```
cyberkde on              # liga tudo
cyberkde off             # desliga e devolve todos os valores originais
cyberkde status          # o que está ligado (e se as animações carregaram)
cyberkde checar          # requisitos e problemas conhecidos, com a correção de cada um
cyberkde painel          # abre o painel gráfico (também no menu de apps, mesmo com o tema desligado)
cyberkde painel --checar # só confere os pacotes do painel e mostra a linha do apt
cyberkde on <parte>      # só uma parte: dolphin, apps, janelas, carregamento, icones, konsole,
                         # konsole-anim, icones-sistema, kwin-extras, login, papeis-de-parede, plasma,
                         # barra-e-dock, widgets; opcionais (fora do "on"): cursor, som, login-bloqueio, datashard
cyberkde off <parte>     # desliga só uma parte (chave que outra parte ligada ainda usa fica como está)
cyberkde fases           # todas as partes, e quais estão ligadas
cyberkde cor '#5EF6FF'   # troca a cor de destaque ('cyberkde cor padrao' volta ao vermelho);
                         # --secundaria '#hex' troca também a secundária
cyberkde corp militech   # corporação: paleta, ícone do botão do menu, logo da abertura e papel de parede
                         # (arasaka, biotechnica, delamain, dynalar, kangtao, kiroshi, militech, mooretech,
                         # netwatch, nightcorp, petrochem, segotari, traumateam, zetatech;
                         # 'nenhuma' = a paleta do próprio tema)
cyberkde corp --lista    # todas as corporações e as cores de cada uma
cyberkde papel ~/Imagens/minha.jpg   # papel de parede próprio ('cyberkde papel padrao' volta ao do tema)
cyberkde layout lateral --aplicar    # arranjo: tema | duas-telas | compacto | lateral | manter
cyberkde arquivos ~/Downloads  # abre o DATASHARD, o gerenciador de arquivos do tema
cyberkde efeito datashard on    # DATASHARD como padrão para abrir pastas ('off' devolve o Dolphin)
cyberkde ilha on          # liga a ilha dinâmica no topo da tela (off | status; --json)
cyberkde widgets alternar # oculta ou mostra os widgets (ocultar | mostrar | estado)
cyberkde cerca nova       # nova Cyber Fence na tela do mouse (também: alternar | mostrar | ocultar)
cyberkde cerca regras aplicar --simular   # organiza a Área de trabalho nas cercas ('cyberkde cerca regras ajuda')
cyberkde cerca snapshot salvar Trabalho   # guarda o layout das cercas (restaurar | listar | apagar)
cyberkde edicao alternar # modo de edição do Plasma (mover e redimensionar widgets): on | off | alternar
cyberkde latte           # instala o pacote revisado do Latte Dock NG (Ubuntu 26.04)
cyberkde animados        # instala os pacotes do Dolphin e do Konsole animados (Ubuntu 26.04)
cyberkde padrao dolphin  # abre um app com a aparência original, para comparar
cyberkde install         # só instala/atualiza os arquivos do tema
cyberkde uninstall       # desliga e remove tudo (também: ./desinstalar.sh)

cyberkde efeito --lista  # todas as opções configuráveis (39), com o comando de cada uma
cyberkde efeito janelas --abrir <id> --fechar <id>   # animação de abrir e fechar janelas (ou 'nenhuma');
                         # --primeira-vez <id>: uma mais longa na primeira vez que cada app abre
cyberkde efeito janelas --lista      # as animações para escolher, com as prévias
cyberkde efeito konsole-cascata on   # "cascata de dados" no Konsole animado (--linhas 2-20, --cores video|tema)
cyberkde efeito konsole-chuva on     # também: konsole-grade, -crt, -varredura, -hud, -faiscas, -erro, -campainha
cyberkde efeito estilo-preset --variante <id>        # preset de interface; estilo-* = cada ajuste
cyberkde efeito movimento reduzido   # movimento: completo | reduzido (só dissoluções curtas) | minimo (nenhum)
cyberkde efeito papel corp           # papel do tema: a | b | c | d | corp (acompanha a corporação) | fui (animado) | padrao
cyberkde efeito widget-relogio on    # um widget: widget-<nome> [on|off]; widget-layout fui | livre
cyberkde efeito splash curto         # tela de abertura: completo | curto | nenhum
cyberkde efeito login --fundo papel  # login e bloqueio: --entrada, --painel, --sucesso on|off, --fundo
cyberkde efeito icones alt           # ícones alternativos de pastas e lixeira (ou <grupo>=alt)
cyberkde efeito icones-apps marca    # ícones dos apps: marca | recolorido | silhueta
cyberkde efeito menu grade           # menu: lista | grade | tela-cheia
cyberkde efeito dock --indicador ponto --zoom off    # indicador, zoom e pulo ao abrir, no Latte Dock
cyberkde efeito areas 4              # áreas de trabalho como módulos (off | 4 | 6, --nomes cyber|simples)
cyberkde efeito modal-escurecer on   # também: efeito clique on (anéis no clique, nas cores do tema)
cyberkde efeito cursor neon      # liga o cursor do tema na variante: padrao | neon | minimo | mira | off
cyberkde efeito som discreto     # liga os sons do tema na variante: padrao | discreto | off
# --json: resposta em uma linha para programas (status, fases, on, off, cor, corp, efeito, checar...);
# --lang en: mensagens em inglês
```

- **Reversível de propósito.** Cada chave de configuração que o tema muda tem o valor original registrado na primeira vez que é gravada, e cada arquivo substituído ganha uma cópia. O `cyberkde off` percorre esse registro de trás para a frente.
- **Seus painéis também voltam.** O arranjo de barra e dock guarda os painéis do Plasma antes de mudar, e o `cyberkde off` os devolve.
- **Root só para a tela de login.** Ela fica em `/usr` e `/etc`, e por isso o `cyberkde` pede a senha do sudo só nessa parte.
- **Um tema por vez.** Desligue outro tema global antes do `cyberkde on` e rode `cyberkde off` antes de aplicar outro. O tema guarda como "original" o que encontra ao ligar.

### Opcional: Dolphin e Konsole animados

Cascata ao abrir pastas (Dolphin) e, no Konsole, texto "decodificando" com halo e rastro do cursor, além dos efeitos de terminal acima. São o Dolphin e o Konsole com um patch pequeno, distribuídos como pacotes prontos, gerados no Ubuntu 26.04 a partir da mesma versão que o Ubuntu distribui e conferidos por um SHA-256 fixo no tema. Nada é compilado na sua máquina. Eles ficam ao lado dos apps do sistema (em `/opt`); o tema só aponta o atalho para eles, e o `cyberkde off` devolve.

```
cyberkde animados        # o instalador oferece no Ubuntu 26.04
```

São oferecidos só no Ubuntu 26.04 e só enquanto a versão do Dolphin/Konsole dele for a do pacote; depois que o Ubuntu os atualiza, ficam os apps do sistema até sair pacote novo. Sem eles instalados, o `cyberkde on` só os pula.

<p align="center">
  <img src="assets/readme/cyberkde.gif" width="90%" alt="Janelas abrindo com a varredura, a cascata do Dolphin, o Konsole, o menu e a troca da cor de destaque">
</p>

### Junto com o AppleKDE

O CyberKDE e o [AppleKDE](https://github.com/jrcn1991/theme_apple_kde) nunca ficam misturados. Se o AppleKDE estiver ligado, o `cyberkde on` roda antes o `applekde off`, confere que ele desligou de verdade e só então aplica; se não der para confirmar (AppleKDE ocupado, etapa que pede root sem terminal), nada é aplicado e ele diz o que rodar. O `applekde on` faz o mesmo no sentido contrário. Sem o AppleKDE instalado, nada muda.

## Desinstalar

```bash
cyberkde uninstall       # ou ./desinstalar.sh
```

Desliga o tema, devolve todos os valores originais e apaga os arquivos do tema, as suas preferências do CyberKDE e o próprio programa. Ficam as imagens de corporação em `~/.config/cyberkde/corporacoes/`, as regras e os layouts das cercas, o que você guardou nos widgets e a nota e a gaveta da ilha. As pastas das cercas nunca são apagadas.

## Testado em

Kubuntu 26.04 e Ubuntu 26.04 (com o Plasma instalado), Plasma 6.6, Wayland; também numa VM limpa do Ubuntu com 4 GB de memória. Outras distribuições com Plasma 6 devem funcionar. Relatos são bem-vindos nas issues.

<p align="center"><img src="assets/readme/divisor.svg" width="100%" alt=""></p>

## Créditos e marcas

`SYS.14 // LEGAL`

- Código, geradores, patches e arquivos gerados do tema: **GPL-3.0-or-later** (ver [LICENSE](LICENSE)).
- Arte própria (ícones em `assets/icons`, papéis de parede em `assets/wallpapers`): **CC BY-SA 4.0** (ver [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt)). Cursores e sons são gerados pelos scripts do tema.
- Fontes Rajdhani e Orbitron: **SIL Open Font License 1.1** (ver `assets/fonts/`).
- **Logos das corporações** (`assets/corporacoes/`): marcas da CD PROJEKT RED (Cyberpunk 2077) e/ou da R. Talsorian Games (Cyberpunk RED / Cyberpunk 2020), incluídas como homenagem de fã, sem fins lucrativos. Não estão sob a licença do tema. A origem de cada arquivo está em [assets/corporacoes/FONTES.md](assets/corporacoes/FONTES.md).

*Cyberpunk 2077* é marca da CD PROJEKT S.A. Este é um projeto independente de fã, sem ligação com a CD PROJEKT RED nem com a R. Talsorian Games e sem o endosso delas. KDE e Plasma são marcas da KDE e.V. Detalhes em [CREDITS.md](CREDITS.md).
