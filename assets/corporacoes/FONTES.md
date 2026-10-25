# Fontes dos logos das corporações

Todas as marcas abaixo pertencem à CD PROJEKT RED (Cyberpunk 2077) e/ou à R. Talsorian Games (Cyberpunk RED / Cyberpunk 2020). Estão aqui como homenagem de fã, sem fins lucrativos; o tema CyberKDE não tem ligação oficial com os detentores.

| Corporação | Arquivo original | Observação |
|---|---|---|
| Arasaka | `Arasaka_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| Biotechnica | `Biotechnica_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| Kang Tao | `Kang_Tao_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| Militech | `Militech_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| NetWatch | `NetWatch_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| Segotari | `Segotari_Logo_CPRED.webp` | marca da R. Talsorian Games (Cyberpunk RED) / CD PROJEKT RED |
| Zetatech | `Zetatech_Logo_CP2077.webp` | marca da CD PROJEKT RED / R. Talsorian Games |
| Trauma Team | `trauma_team_colorido.png` (símbolo) e `trauma_team_branco.png` (logo), do catálogo da usuária | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Kiroshi | `kiroshi_branco.png`, do catálogo da usuária (ícone = o "O" em forma de olho) | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Night Corp | `night_corp_preto.png`, do catálogo da usuária | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Petrochem | `petrochem_branco.png`, do catálogo da usuária | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Moore Tech | `moore_tech_branco.png` (decal `cyberware_moore_logo_01`, 1030×346), do catálogo da usuária (ícone = os dois "O") | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Delamain | `delamain_branco.png` (símbolo) e `delamain_branco_2.png` (logo), do catálogo da usuária | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |
| Dynalar | `dynalar_branco.png`, do catálogo da usuária (ícone = a letra "D") | extraído do jogo; marca da CD PROJEKT RED / R. Talsorian Games |

Arquivos derivados, por id: `<id>-logo.png` (logo completo, fundo transparente), `<id>-logo-escuro.png` (partes pretas em #DCDCE4, só biotechnica, netwatch e zetatech), `<id>-icone.png` (símbolo 512×512) e `<id>.svg` / `<id>-icone.svg` (vetor de verdade, com paths, sem imagem embutida). `genericos/` guarda os emblemas provisórios antigos.

## Escolha de cada vetor (rodada 4: entrega final do catálogo × vetores próprios)

Todos os SVG são só `<path>` (sem imagem embutida), vetorizados com potrace. O catálogo da usuária (`logos/_pedidos/cyberkde/<id>/`) e os vetores próprios saem do mesmo tipo de fonte, então a maioria ficou igual; ficou o melhor de cada:

| id | Ícone (`<id>.svg`) | Logo (`<id>-logo.svg`) |
|---|---|---|
| arasaka | catálogo: emblema do decal `corpo_arasaka_decal_a_m` (512 px, máscara) | composição horizontal: emblema do catálogo + nome do decal `corpo_arasaka_decal_b_m` (1024 px), com as proporções da imagem enviada. O `logo.svg` do catálogo é empilhado e não foi usado |
| militech | catálogo: quadrado do V do decal `militech_logo_a_m` (512 px) | composição horizontal: quadrado do catálogo + nome do decal `militech_logo_b_m` (1024 px), com as proporções da imagem enviada |
| biotechnica | próprio, da imagem enviada (círculo de ~265 px, mais suave que o de 230 px do catálogo, que sai com degraus) | próprio, da imagem enviada ("bio" verde + TECHNICA, empilhado). O `logo.svg` do catálogo usa outro desenho do nome (tudo em caixa alta, do decal do jogo) e não foi usado |
| netwatch | próprio, da imagem enviada (mantém o cinza das linhas do globo; o catálogo só tem branco) | idem |
| kangtao, segotari, zetatech | próprio, das imagens enviadas (o catálogo tem só o branco, e o Segotari não existe nele) | idem |
| mooretech | próprio, do decal de 1030 px (`moore_tech_branco.png`): o logo com a moldura branca e, como ícone, os dois "O" | idem |
| traumateam, kiroshi, nightcorp, petrochem, delamain, dynalar | próprio, do mesmo PNG do catálogo; equivalente ao `simbolo.svg`/`logo.svg` dele (conferido lado a lado) | idem |

Cores: as das imagens enviadas (Arasaka #E60000, Militech #F8E800), e não as do catálogo (#E10000, #F5E100, que vêm da textura do jogo). Partes escuras em #DCDCE4 (no catálogo, Night Corp usa #E8EAF2). Variantes extras do catálogo não usadas: `biotechnica/logo-claro.svg` (horizontal, símbolo de 230 px), `night_corp/*-claro`, `arasaka/simbolo-vermelho`, `militech/simbolo-amarelo` (equivalem aos nossos) e `netwatch/logo-dourado`.

Vetorização feita com `potracer` num venv em /tmp (fora do projeto). Ícone sem símbolo separado no jogo: Kiroshi usa o "O" em forma de olho e Dynalar usa a letra "D".
