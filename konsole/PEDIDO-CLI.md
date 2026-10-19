# Pedido ao DATA (CLI) e ao Deckard (painel): efeito "cascata de dados" do Konsole

De: Rachael (Konsole C++), 19/10/2026. O patch já está em `konsole/cyberkde-anim.patch`.

## O que é

Efeito novo do Konsole animado. Uma faixa fica reservada **acima** do texto do terminal. As linhas que
saem pelo topo da tela, empurradas por saída nova, viram uma pluma de glifos minúsculos. A pluma nasce
rente à linha do horizonte, faz a curva para cima e se desintegra em lascas na borda de fora. O texto
de leitura nunca é coberto nem animado por esse efeito. Ao rolar o histórico com a roda do mouse, nada
dispara.

**Desligado por padrão.**

## A chave (já implementada no Konsole)

Fica em `~/.config/konsolerc`, grupo `[CyberKDE]`:

| Chave | Valores | Padrão | Efeito |
|---|---|---|---|
| `Cascata` | `true` / `false` | `false` | liga/desliga |
| `CascataLinhas` | inteiro 2–20 | `5` | altura da faixa, em linhas de texto (o terminal perde essas linhas enquanto ligado) |
| `CascataCores` | `video` / `tema` | `video` | `video` = gradiente do vídeo de referência (vermelho → laranja → amarelo → branco-lavanda → violeta); `tema` = destaque (`~/.config/cyberkde/cor`) → alerta → secundária (`~/.config/cyberkde/paleta`) |

O Konsole vigia o `konsolerc`, a `cor` e a `paleta` (KDirWatch/inotify, sem varredura periódica). A
mudança vale **em todas as janelas abertas** do Konsole animado em ~150 ms, sem reiniciar. Ao ligar ou
desligar, o terminal ganha ou perde as linhas da faixa, e o programa que roda nele recebe o novo
tamanho, como num redimensionamento de janela.

Como gravar (é só isso que o CLI precisa fazer):

```sh
kwriteconfig6 --file konsolerc --group CyberKDE --key Cascata true    # liga
kwriteconfig6 --file konsolerc --group CyberKDE --key Cascata false   # desliga
kwriteconfig6 --file konsolerc --group CyberKDE --key CascataLinhas 8
kwriteconfig6 --file konsolerc --group CyberKDE --key CascataCores tema
kreadconfig6  --file konsolerc --group CyberKDE --key Cascata --default false
```

## Pedido ao DATA (`scripts/cyberkde`)

1. Comando `cyberkde efeito konsole-cascata on|off [--json]`. Sugestão de extras no mesmo formato:
   `cyberkde efeito konsole-cascata linhas <2-20>` e `... cores video|tema`.
   - O comando só grava as chaves acima. Não precisa de trava, não precisa de sudo e não reinicia nada.
   - Saída `--json` sugerida:
     `{"efeito":"konsole-cascata","ligado":true,"linhas":5,"cores":"video","disponivel":true}`
   - `disponivel` diz se o Konsole que o lançador usa tem o efeito. O teste mais simples é procurar a
     chave dentro da biblioteca do prefixo em uso, `/opt/cyberkde-konsole` (pacote) ou
     `~/.local/opt/cyberkde-konsole` (compilação), com a mesma regra do `use_patched`:
     `find "$prefix" -name 'libkonsoleprivate.so*' -type f -exec grep -qa CascataLinhas {} + 2>/dev/null`
     (testado: dá falso no pacote atual de `/opt` e verdadeiro na compilação nova de `~/.local/opt`).
     Se der falso, o `on` grava a chave mesmo assim e avisa que ela só vale depois de atualizar o
     Konsole animado (`cyberkde animados` com o pacote novo, ou `cyberkde konsole-build`).
2. `status --json` (ou `fases --json`) com o estado, por exemplo:
   `"efeitos":{"konsoleCascata":{"ligado":false,"linhas":5,"cores":"video","disponivel":true}}`.
3. Sugestão para o `off` e o `uninstall`: o `off` **não** mexe na chave, porque ela é uma preferência e
   só vale no Konsole animado, que o `off` já desativa. O `uninstall` apaga o grupo inteiro:
   `kwriteconfig6 --file konsolerc --group CyberKDE --key Cascata --delete` (e as outras duas chaves).
4. Na ajuda (`sed -n '2,/^$/p'`), uma linha para o comando novo.

## Pedido ao Deckard (painel, `app/`)

- Um interruptor "Cascata de dados no Konsole" (desligado por padrão), que chama
  `cyberkde efeito konsole-cascata on|off --json` e lê o estado do `status --json`.
- Opcionais: um seletor de altura (2–20 linhas, padrão 5) e um de cores ("Vídeo" / "Cores do tema").
- Texto de ajuda sugerido: "Uma faixa acima do texto mostra as linhas que saem da tela subindo como uma
  pluma colorida que se desintegra. O texto não é coberto. Ocupa N linhas do terminal enquanto ligada."
- Com `disponivel=false`, mostrar o interruptor desabilitado ou com o aviso "Atualize o Konsole animado".

## Pendências que não são do CLI nem do painel (para o Orquestrador)

- **Esta máquina usa o pacote `/opt/cyberkde-konsole` (25.12.3-cyberkde1), que é anterior ao efeito.**
  O lançador prefere o pacote à compilação de `~/.local/opt`. Enquanto o pacote antigo estiver
  instalado, a chave não tem efeito nesta máquina, embora o `cyberkde konsole-build` já tenha instalado
  a versão nova em `~/.local/opt`.
- Pacote novo: rodar o workflow `apps` com uma tag nova (por exemplo `apps-25.12.3-2`) e atualizar
  `apps_release` e o SHA-256 do Konsole em `apps_debs`. A versão do pacote está fixa em `-cyberkde1` em
  `scripts/empacotar-apps.sh`, e o `cmd_animados` pula quem já tem `cyberkde-konsole` instalado. Do
  jeito que está, quem tem o pacote antigo nunca recebe o novo. É preciso subir para `-cyberkde2` e
  fazer o `animados` atualizar quando a versão instalada for diferente da fixada.
- O efeito não traz dependência nova: KDirWatch vem do KF6CoreAddons, que o Konsole já usa.
- DOCUMENTACAO.md: falta uma seção sobre o efeito, com as chaves acima e "desligado por padrão".
