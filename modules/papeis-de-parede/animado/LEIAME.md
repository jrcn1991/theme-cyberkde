# Papel de parede animado FUI (`org.cyberkde.fui`)

Plugin de papel de parede do Plasma 6 que reproduz o fundo da referência "Cyberpunk 2077 UI Art": vermelho enfumaçado com vinheta, feixes diagonais com pulsos de luz que correm por eles (rastro e brilho em cruz), tracejados fora de foco, partículas, retículo HUD, grão e sujeira de filme, e um glitch curto por ciclo de 14,4 s. Por cima, o logo da corporação com o lema, a marca e o texto técnico da lateral esquerda e o emblema embaixo à direita, que se montam em ~1,4 s.

## Arquivos

| Caminho | O que é |
|---|---|
| `org.cyberkde.fui/` | O pacote (vai para `~/.local/share/plasma/wallpapers/org.cyberkde.fui`) |
| `…/contents/ui/main.qml` | `WallpaperItem`: configuração, corporação e regras de pausa |
| `…/contents/ui/Cena.qml` | A cena (shaders + camadas). Não depende do Plasma: o gerador a usa para as prévias e o estático |
| `…/contents/ui/corps.js` | **Gerado.** Cores, nomes, lemas, códigos e arquivos de logo de cada corporação |
| `…/contents/images/corp/` | **Gerado.** Cópia dos SVGs de `assets/corporacoes/` (`<id>-logo.svg` e `<id>.svg`) |
| `…/contents/shaders/*.frag` | Fontes GLSL: `fui` (a cena, com a fumaça, num passo só) e `tingir` (logos numa cor) |
| `…/contents/shaders/*.qsb` | Os mesmos, compilados com o `qsb` do Qt (é o que o Qt carrega) |
| `gen_fui.py` | Gerador: `gerar`, `estatico ID`, `previa ID` e `quadros ID PASTA` |

Depois de mudar `tokens/corporacoes.json`, um logo ou um `.frag`, rode `python3 gen_fui.py gerar`. O `qsb` vem de `$QSB`, do PATH, do Qt do sistema ou do PySide6. Sem ele, os `.qsb` antigos ficam.

## Configuração (grupo `[Wallpaper][org.cyberkde.fui][General]` da área de trabalho)

| Chave | Padrão | O que faz |
|---|---|---|
| `Corporacao` | `arasaka` | id de `tokens/corporacoes.json`. A Arasaka usa o vermelho medido na referência; as outras derivam do destaque e do fundo |
| `Intensidade` | `100` | brilho dos feixes, 30–200 % |
| `Velocidade` | `100` | velocidade dos pulsos e do ciclo, 25–300 % |
| `MostrarLogo` / `MostrarTextos` | `true` | logo e emblema / texto técnico da lateral |
| `FpsMax` | `30` | 30 ou 60 |
| `PausarCoberto` | `true` | congela com janela maximizada ou em tela cheia nesta tela, na área de trabalho e atividade atuais (`TaskManager.TasksModel`) |
| `Movimento` | `auto` | `auto` segue o fator de animação do KDE (0 → mínimo, quadro parado; <0,75 → reduzido, sem glitch e mais lento); `completo`, `reduzido` ou `minimo` força |

Exemplo, pelo script do Plasma:

```js
desktops().forEach(function (d) {
  d.wallpaperPlugin = 'org.cyberkde.fui';
  d.currentConfigGroup = ['Wallpaper', 'org.cyberkde.fui', 'General'];
  d.writeConfig('Corporacao', 'militech');
  d.reloadConfig();
});
```

## Estático (bloqueio e login) e prévias

- `python3 gen_fui.py estatico <id>` grava `modules/papeis-de-parede/build/fui/<id>.png`, em 3840x2160 (o quadro de t = 1,52 s, com um pulso no meio do feixe principal).
- `python3 gen_fui.py previa <id>` grava `assets/previas/papel/fui-<id>.webp`, em 480x270, 4,8 s a 15 fps.

Ambos precisam de uma tela com OpenGL. Para não abrir nada na sessão, rode num Xvfb com `+extension GLX`.

## Custo

Medido na RTX 3060 por EGL sem tela, em um passo e GL_TIME_ELAPSED:

| Resolução | Por quadro | A 30 fps | A 60 fps |
|---|---|---|---|
| 1920x1080 | 1,2 ms | ~3,6 % da GPU | ~7,3 % da GPU |
| 3840x2160 | 4,8 ms | ~14 % da GPU | ~29 % da GPU |

Cada tela tem o seu papel. Pausado (janela maximizada, tela cheia ou movimento mínimo), não há nenhum redesenho: no teste, a CPU caiu ao nível do papel de cor sólida.

# Papel de parede em vídeo (`org.cyberkde.video`)

Toca um vídeo da pasta da pessoa (`cyberkde efeito papel-pasta`, `cyberkde efeito papel usuario:<arquivo>`): em loop, sem som e preenchendo a tela. As regras de pausa estão no começo de `org.cyberkde.video/contents/ui/main.qml`.

| Chave (`[Wallpaper][org.cyberkde.video][General]`) | Padrão | O que faz |
|---|---|---|
| `Video` | vazio | file:// do vídeo |
| `Reserva` | vazio | file:// da imagem mostrada se o vídeo não abre (o CLI põe o `desktop.png` do tema) |
| `Preenchimento` | `cortar` | `cortar`, `ajustar` ou `esticar` |
| `PausarCoberto` / `PausarBloqueio` | `true` | pausa com janela maximizada ou em tela cheia / com a tela bloqueada |
| `Movimento` | `auto` | `auto` segue o fator de animação do KDE (0 = parado); `minimo` força o quadro parado |

`contents/ui/Tocador.qml` não depende do Plasma: dá para testar num `QQuickView` (PyQt6) no Xvfb.
