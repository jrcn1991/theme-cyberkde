# Pedido ao DATA (CLI) e ao Deckard (painel): efeitos alternativos do Konsole

De: Zeta (Konsole C++), 19/10/2026. O patch já está em `konsole/cyberkde-anim.patch`, e o
`cyberkde konsole-build` já instalou a versão nova em `~/.local/opt/cyberkde-konsole`.

## O que é

Oito efeitos novos para o Konsole animado. Cada um tem uma chave própria e todos podem ser
combinados entre si e com a cascata de dados (`PEDIDO-CLI.md`). **Todos vêm desligados por padrão.**

| id do CLI | Chave | O que faz | Onde desenha |
|---|---|---|---|
| `konsole-chuva` | `Chuva` | Chuva de glifos (katakana e dígitos) caindo devagar atrás do texto. Aparece enquanto o terminal está em uso e para sozinha 20 s depois da última saída ou tecla | atrás do texto |
| `konsole-grade` | `Grade` | Grade holográfica fixa, mais forte embaixo, como um piso, e com nós nos cruzamentos | atrás do texto |
| `konsole-crt` | `Crt` | Scanlines finas, vinheta nos cantos e cantos arredondados de tubo de CRT. Imagem parada | por cima (escurece no máximo 15 % numa linha a cada 3 px) |
| `konsole-varredura` | `Varredura` | Uma faixa de luz desce pela tela em 1,8 s, de tempos em tempos | atrás do texto |
| `konsole-hud` | `Hud` | Cantoneiras, réguas (uma marca a cada 10 colunas e a cada 5 linhas) e dados pequenos: `CYBERKDE//TTY`, colunas×linhas, número da sessão e relógio | só nas margens |
| `konsole-faiscas` | `Faiscas` | Faíscas curtas saindo do caractere digitado. Só com digitação, nunca com saída de programa | por cima, perto do cursor (< 0,55 s) |
| `konsole-erro` | `Erro` | Quando um comando falha: um rasgo vermelho e ciano de 0,18 s no prompt seguinte, depois uma barra vermelha na margem e um traço sob o prompt que somem em 0,9 s | por cima, só na linha do prompt |
| `konsole-campainha` | `Campainha` | Um pulso de luz na borda, na cor de alerta, quando toca a campainha (BEL, `\a`) | só na borda (9 px) |

Regras de conforto atendidas por todos:
- O texto nunca se move nem treme. Fundo e varredura são pintados **antes** do texto. Os efeitos que
  ficam por cima são translúcidos, curtos e só aparecem num evento.
- Nada pisca. A campainha faz um pulso por vez, com 0,7 s de pausa depois dele. O rasgo do erro
  tem só dois estados em 0,18 s.
- `CYBER_QUIET_MS`: durante a pausa de 600 ms depois da roda do mouse, a chuva congela, a varredura
  pula a vez e as faíscas não nascem.
- `AnimationDurationFactor=0`: chuva, varredura, faíscas, erro e campainha ficam desligados. Grade,
  CRT e HUD continuam, porque são imagens paradas.
- CPU em repouso: zero com o terminal sem foco. Com foco, a única coisa que se repete é o halo do
  cursor, que já existia (veja a medição abaixo).

## As chaves (já implementadas no Konsole)

Ficam em `~/.config/konsolerc`, grupo `[CyberKDE]`. Seguem o padrão da cascata: o Konsole vigia o
arquivo, a `cor` e a `paleta` com KDirWatch, e a mudança vale **em todas as janelas abertas** em
~150 ms, sem reiniciar. Nenhum desses efeitos muda o tamanho do terminal.

Comuns:
- `<Chave>`: `true` ou `false`, padrão `false`.
- `<Chave>Intensidade`: inteiro de 1 a 100. É a fração da opacidade máxima de cada efeito.
- `<Chave>Cores`: `tema` ou `video`, padrão `tema`.
  - `tema`: destaque (`~/.config/cyberkde/cor`), secundária e alerta (`~/.config/cyberkde/paleta`).
  - `video`: as cores do vídeo da cascata (branco-lavanda, dourado, vermelho-laranja e violeta).

| Chave | Valores | Padrão | Observação |
|---|---|---|---|
| `Chuva` | `true`/`false` | `false` | |
| `ChuvaIntensidade` | 1–100 | `35` | Ponta da gota a ~25 % de opacidade no padrão |
| `ChuvaDensidade` | 1–100 | `50` | Quantas colunas têm gota ao mesmo tempo (50 ≈ 1 a cada 4 colunas) |
| `ChuvaDirecao` | `cair` / `subir` | `cair` | `subir` combina com a cascata |
| `ChuvaCores` | `tema` / `video` | `tema` | |
| `Grade` | `true`/`false` | `false` | |
| `GradeIntensidade` | 1–100 | `30` | Linhas a ~6,6 % embaixo e ~2,6 % em cima no padrão |
| `GradeTamanho` | 1–20 | `3` | Lado do quadrado, em linhas de texto |
| `GradeCores` | `tema` / `video` | `tema` | |
| `Crt` | `true`/`false` | `false` | |
| `CrtIntensidade` | 1–100 | `30` | Força das scanlines e da vinheta |
| `CrtVinheta` | `true`/`false` | `true` | |
| `CrtCurvatura` | `true`/`false` | `true` | Cantos arredondados |
| `Varredura` | `true`/`false` | `false` | |
| `VarreduraIntensidade` | 1–100 | `40` | |
| `VarreduraIntervalo` | 5–600 (segundos) | `20` | A primeira passada vem 2 s depois de ligar. Só passa na janela ativa |
| `VarreduraCores` | `tema` / `video` | `tema` | |
| `Hud` | `true`/`false` | `false` | |
| `HudIntensidade` | 1–100 | `60` | |
| `HudDados` | `true`/`false` | `true` | `false` deixa só as cantoneiras e as réguas, sem textos nem relógio |
| `HudCores` | `tema` / `video` | `tema` | |
| `Faiscas` | `true`/`false` | `false` | |
| `FaiscasIntensidade` | 1–100 | `60` | Também controla quantas faíscas saem (3 a 9 por tecla) |
| `FaiscasCores` | `tema` / `video` | `tema` | |
| `Erro` | `true`/`false` | `false` | Precisa da integração do shell (abaixo). Cores fixas: vermelho ANSI (perigo) e ciano do cursor |
| `ErroIntensidade` | 1–100 | `60` | |
| `Campainha` | `true`/`false` | `false` | |
| `CampainhaIntensidade` | 1–100 | `60` | |
| `CampainhaCores` | `tema` / `video` | `tema` | Usa a cor de alerta da paleta |

Como gravar:

```sh
kwriteconfig6 --file konsolerc --group CyberKDE --key Chuva true
kwriteconfig6 --file konsolerc --group CyberKDE --key ChuvaIntensidade 50
kwriteconfig6 --file konsolerc --group CyberKDE --key ChuvaDirecao subir
kreadconfig6  --file konsolerc --group CyberKDE --key Chuva --default false
```

## Pedido ao DATA (`scripts/cyberkde`)

1. Registrar os oito ids em `CYBERKDE_EFEITOS`, com o mesmo formato do `konsole-cascata`:
   `cyberkde efeito konsole-<id> on|off [--json]`.
   - Extras sugeridos, que só gravam chaves:
     - todos: `... intensidade <1-100>`;
     - os que têm cores: `... cores tema|video`;
     - `konsole-chuva densidade <1-100>` e `konsole-chuva direcao cair|subir`;
     - `konsole-grade tamanho <1-20>`;
     - `konsole-crt vinheta on|off` e `konsole-crt curvatura on|off`;
     - `konsole-varredura intervalo <5-600>`;
     - `konsole-hud dados on|off`.
   - Valor fora da faixa: o Konsole já limita (`qBound`). Mesmo assim, o CLI deve recusar com o código
     de "uso inválido" para o painel mostrar o erro.
   - Saída `--json` sugerida, com as chaves do efeito em camelCase e sem o prefixo:
     `{"efeito":"konsole-chuva","ligado":true,"intensidade":35,"densidade":50,"direcao":"cair","cores":"tema","disponivel":true}`.
   - `disponivel`: mesma regra da cascata, com outra chave na busca:
     `find "$prefix" -name 'libkonsoleprivate.so*' -type f -exec grep -qa VarreduraIntervalo {} + 2>/dev/null`.
     Vale para os oito, que vieram no mesmo patch.
2. `status --json`: um objeto por efeito em `"efeitos"`, por exemplo
   `"konsoleChuva":{...}`, `"konsoleGrade":{...}`, `"konsoleCrt":{...}`, `"konsoleVarredura":{...}`,
   `"konsoleHud":{...}`, `"konsoleFaiscas":{...}`, `"konsoleErro":{"ligado":false,"intensidade":60,"integracaoShell":false,"disponivel":true}`
   e `"konsoleCampainha":{...}`.
3. `off` e `uninstall`: como na cascata. O `off` não mexe nas chaves, e o `uninstall` apaga o grupo
   `[CyberKDE]` inteiro: `kwriteconfig6 --file konsolerc --group CyberKDE --key <K> --delete` para cada
   chave das tabelas.
4. **Integração do shell, necessária para o `konsole-erro`.** O Konsole só fica sabendo que um comando
   falhou se o shell mandar o código de saída por OSC 133. O bash da usuária não manda: o
   `/etc/profile.d/vte-2.91.sh` só age em terminais VTE, e o `80-systemd-osc-context.sh` só entra em
   shell de login. Sugestão: o `konsole-erro on` instala `~/.config/cyberkde/konsole-shell.sh` e uma
   linha `source` no `~/.bashrc`, marcada como do CyberKDE para o `uninstall` remover. Conteúdo
   testado, o mesmo esquema do VTE:

   ```sh
   # CyberKDE: integração semântica do shell (OSC 133) para o Konsole. Só em bash interativo no Konsole.
   if [[ $- == *i* && -n ${KONSOLE_VERSION:-} && $PS1 != *']133;'* ]]; then
     PS1='\[\e]133;D;$?\e\\\e]133;A\e\\\]'"$PS1"'\[\e]133;B\e\\\]'
     PS0='\e]133;C\e\\'"${PS0:-}"
   fi
   ```

   - O `D;$?` precisa vir junto do `A`. Sem a marca de início de prompt (`A`), o Konsole percorre o
     histórico inteiro marcando as linhas como "erro" (`Screen::setExitCode`).
   - **Efeito colateral visível:** com o OSC 133, o Konsole liga recursos nativos do perfil. Por
     padrão eles desenham uma barra cinza ao lado da saída de cada comando, alternando
     (`AlternatingBars=2`), e uma barra vermelha ao lado da saída que falhou (`ErrorBars=2`). Dá para
     ver isso na prancha. Recomendo que o `gen_konsole.py` grave `AlternatingBars=0` no
     `[General]` do `CyberKDE.profile`, porque é ruído visual. O `ErrorBars` pode ficar: ele marca a
     saída que falhou e não se mexe. A decisão é do Orquestrador e da usuária.
   - zsh: `precmd`/`preexec` equivalentes (mesmo esquema do `vte-2.91.sh`). A usuária usa bash.
5. Na ajuda (`sed -n '2,/^$/p'`), uma linha cobrindo os oito, por exemplo:
   `cyberkde efeito konsole-{chuva,grade,crt,varredura,hud,faiscas,erro,campainha} on|off`.

## Pedido ao Deckard (painel, `app/`)

- Uma seção "Efeitos do terminal" com um interruptor por efeito, todos desligados por padrão, que
  chamam `cyberkde efeito konsole-<id> on|off --json` e leem o estado do `status --json`.
- Por efeito: um controle de intensidade (1–100) e, quando houver, o seletor de cores ("Cores do
  tema" / "Vídeo"). Extras: densidade e direção (chuva), tamanho (grade), vinheta e curvatura (CRT),
  intervalo (varredura), dados (HUD).
- Prévias animadas (400×250, em loop): `assets/previas/konsole/<id>.webp`, com `<id>` = `chuva`,
  `grade`, `crt`, `varredura`, `hud`, `faiscas`, `erro` e `campainha`. Foram gravadas com os valores
  padrão e cores `tema`.
- Textos de ajuda sugeridos:
  - Chuva: "Glifos caem devagar atrás do texto enquanto você usa o terminal e param sozinhos quando ele fica parado."
  - Grade: "Uma grade holográfica fraca atrás do texto, mais forte na parte de baixo."
  - CRT: "Linhas de varredura finas, cantos escurecidos e arredondados, como um monitor de tubo."
  - Varredura: "De tempos em tempos, uma faixa de luz desce por trás do texto."
  - HUD: "Cantoneiras, réguas e dados pequenos nas margens. O texto não é coberto."
  - Faíscas: "Faíscas curtas saem das letras enquanto você digita."
  - Erro: "Quando um comando falha, o prompt seguinte dá um glitch rápido e ganha uma marca vermelha que some."
    Com `integracaoShell=false`, mostrar o aviso "Precisa da integração do shell".
  - Campainha: "Quando o terminal toca a campainha, a borda acende uma vez na cor de alerta."
- Com `disponivel=false`, mostrar os interruptores desabilitados ou com o aviso "Atualize o Konsole
  animado", como na cascata.

## Custo de CPU medido

Konsole de teste em Xvfb (400×290), configuração isolada, janelas de 10 a 40 s, `utime+stime` do
processo. A base varia entre 1,6 % e 3 % com foco, por causa do halo do cursor que já existia, que
repinta a 60 fps. Os números abaixo são a diferença sobre essa base, e a margem de ruído é de ±0,5 pp.

| Efeito | Terminal parado, com foco | Sem foco | Em uso |
|---|---|---|---|
| (base, sem efeito novo) | 1,6–3 % | 0 % | — |
| Grade | +0,5 pp | 0 | — |
| CRT | +0,5 pp | 0 | — |
| HUD | +0,3 pp | 0 | relógio: uma repintura das margens por minuto |
| Chuva | 0 depois de 20 s sem atividade | 0 | +1 pp enquanto cai |
| Varredura | ~0 (a cada 20 s); +0,4 pp com intervalo de 5 s | 0 (não passa) | — |
| Faíscas | 0 | 0 | +2,3 pp digitando 10 teclas/s sem parar |
| Erro | 0 | 0 | ~+1 pp com uma falha a cada 1,5 s (0,9 s por falha) |
| Campainha | 0 | 0 | ~+0,8 pp com um toque a cada 1,5 s |
| Todos ligados com `AnimationDurationFactor=0` | 0 % | 0 % | — |

## Pendências que não são do CLI nem do painel (para o Orquestrador)

- **Mexi em duas coisas que não são efeitos novos, mas o patch é um só:**
  - `Vt102Emulation.cpp`: 4 linhas que avisam o `TerminalDisplay` quando chega `OSC 133;D;<código≠0>`.
  - Rastro do cursor (efeito que já existia): quando um rastro novo começava antes de o anterior
    acabar, o anterior nunca era apagado. Ficavam blocos vermelho e ciano pela tela, inclusive na
    margem. A correção é uma linha que repinta a área do rastro substituído. O visual do efeito
    não mudou.
- Bug que **não** corrigi, porque é do efeito que a usuária gosta: o halo do cursor é desenhado em
  volta de um bloco de 3×3 células, não do cursor. A causa é o `highdpi_adjust_rect`, que aumenta o
  retângulo em uma célula para cada lado antes do `imageToWidget`. Aparece nas prévias como um
  retângulo fino em volta do cursor. Se a intenção era um halo justo de 4 px, basta tirar o
  `highdpi_adjust_rect` do cálculo do `cursorRect` em `cyberPaintCursorEffects` e
  `cyberAnimationTick`. A decisão é da usuária.
- Ficaram de fora, de propósito:
  - "Decodificação" com o texto embaralhado: o efeito de escrita atual já faz a decodificação, e a
    usuária pediu para não mexer nele.
  - Variações da cascata (subir, cair, dispersar): o código é da Rachael. A `ChuvaDirecao=subir`
    cobre parte da ideia sem tocar na cascata. Se quiserem as variações na própria cascata, o pedido
    é para a Rachael.
- DOCUMENTACAO.md: falta uma seção com as chaves acima e a frase "todos desligados por padrão".
- O pacote `.deb` só leva os efeitos quando sair o próximo `-cyberkde2` pelo CI, como a cascata.
