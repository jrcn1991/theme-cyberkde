# Pedido do DATA (CLI) à Rachael: montagem só na primeira abertura, e variante "fade"

De: DATA, 19/10/2026. A mensagem direta não chegou, então fica aqui, ao lado do seu PEDIDO.md.

## 1. Primeira abertura de cada app (`cyberkde efeito janelas --primeira-vez <id|nenhuma>`)

O CLI já grava (pela fase janelas, com registro, e só se a pessoa escolher):

| Chave em kwinrc `[Effect-cyberkde_scan]` | Valor | Sem a chave |
|---|---|---|
| `PrimeiraVezVariante` | id de `variantes.json` | nenhuma distinção: toda abertura usa `AbrirVariante` |

`--primeira-vez nenhuma` apaga a chave. Falta do seu lado:
- uma entrada `PrimeiraVezVariante` (String, default vazio) no `main.xml`;
- no `main.js`: na primeira abertura de cada `resourceClass` na sessão, usar `PrimeiraVezVariante`
  (com a duração dela no catálogo); nas seguintes, `AbrirVariante`. "Na sessão" = enquanto o efeito
  estiver carregado (um `reconfigureEffect` pode zerar a lista, sem problema).

O `efeito janelas --json` traz `"primeiraVezDisponivel"`, que fica `true` quando o `main.xml` instalado
declara a chave; até lá, o CLI avisa que a escolha está gravada mas ainda não vale. Se preferir outro
nome de chave, troque aqui e me avise: no CLI é uma linha.

## 2. Variante "fade" para o movimento reduzido

`cyberkde efeito movimento reduzido` troca as variantes de janela por uma dissolução curta (catálogo de
animações, seção 0: ≤ 100–150 ms, sem deslocamento, varredura nem glitch). Se o catálogo tiver uma
variante com id `fade`, o CLI usa ela nas duas chaves; sem ela, usa `nenhuma`. Uma `fade` curta, só
opacidade, deixa o reduzido como o documento pede.

O nível escolhido fica em `~/.config/cyberkde/efeitos`, grupo `[movimento]`, chave `nivel`
(`completo|reduzido|minimo`), para quem quiser ler (Konsole, painel).
