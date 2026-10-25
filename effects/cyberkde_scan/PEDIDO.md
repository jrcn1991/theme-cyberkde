# Catálogo de animações de janelas: formato fixo (para o DATA e o Deckard)

De: Rachael, 19/10/2026.

## Catálogo

`effects/cyberkde_scan/variantes.json` é uma lista na ordem do shader (posição = número da variante):

```json
[{"id", "nome", "nome_en", "descricao", "descricao_en", "abrir": true, "fechar": true,
  "duracaoAbrir": ms, "duracaoFechar": ms, "referencia"}]
```

- São 20 variantes: scan, moldura, glitch, dados, holograma, crt, decodificar, chanfro, braindance,
  cacos, convergir, desintegrar, terminal, neon, modal, pulso, pixel, persiana, portas, radar.
- Todas servem para abrir e para fechar.
- `nenhuma` não está na lista; é um valor especial aceito nas duas chaves.
- `python3 effects/cyberkde_scan/conferir.py` confere se o JSON, a tabela do `main.js` e o shader
  estão em sincronia.

## Chaves em kwinrc [Effect-cyberkde_scan]

| Chave | Valor | Sem a chave |
|---|---|---|
| `AbrirVariante` | id ou `nenhuma` | `scan` |
| `FecharVariante` | id ou `nenhuma` | a mesma de abrir |
| `OpenDuration` / `CloseDuration` | ms | a duração da variante no catálogo |
| `Intensidade` | 0–100 | 60 |

Um id desconhecido vira `scan`. Aplicação: `reconfigureEffect cyberkde_scan`.

## Pedido ao DATA (obrigatório para as chaves valerem)

O KWin só entrega ao `effect.readConfig` as chaves declaradas em `contents/config/main.xml`. Sem esse
arquivo, ele devolve sempre o padrão. Por isso o efeito antigo nunca leu o kwinrc: as cores vinham do
`sed` do install. Agora existe `effects/cyberkde_scan/main.xml`, e o `install_effect` precisa
copiá-lo:

```bash
mkdir -p "$dst/contents/config"
cp "$src/main.xml" "$dst/contents/config/main.xml"
```

- Sem a cópia, o efeito funciona, mas fica sempre na varredura.
- O `sed` das cores continua igual: os mesmos `#F75049`, `#5EF6FF` e `#12121C` no `main.js`.
- Para o `disponivel`, sugiro testar também a existência de
  `$data/kwin/effects/cyberkde_scan/contents/config/main.xml`, além do `grep AbrirVariante`.

## Prévias

`assets/previas/janelas/<id>-abrir.webp` e `<id>-fechar.webp`: 320×200, animadas, em loop.

## Rodada 6: "primeira vez" (para o DATA: `cyberkde efeito janelas --primeira-vez`)

Duas chaves novas em kwinrc [Effect-cyberkde_scan], declaradas no `main.xml` (o install já copia):

| Chave | Valor | Sem a chave |
|---|---|---|
| `PrimeiraVezVariante` | id de `variantes.json` ou `nenhuma` | `nenhuma` (desligado) |
| `PrimeiraVezDuration` | ms | 1,6 × a `duracaoAbrir` da variante, no máximo 700 ms |

- **Comportamento:** a primeira janela de cada app (por `windowClass`) desde que o efeito foi carregado
  usa essa variante e essa duração; as seguintes usam `AbrirVariante`.
  - A lista de apps vistos fica na memória do efeito: zera quando a sessão (o KWin) recomeça ou quando o
    efeito é descarregado e carregado. O `reconfigureEffect` não zera.
  - Vale mesmo com `AbrirVariante=nenhuma`: só a primeira janela de cada app anima.
- **Sugestão para o CLI:** `cyberkde efeito janelas --primeira-vez <id>|nenhuma` e
  `--duracao-primeira-vez <ms>|padrao`. No estado, os campos `primeiraVez` e `duracaoPrimeiraVez`.
- **Testado** no KWin virtual (abrir=nenhuma, primeira vez=crt): o primeiro Konsole anima, o segundo
  aparece pronto.

## Rodada 6: variante `fade` (pedido do DATA para `cyberkde efeito movimento reduzido`)

- **Onde:** a 21ª variante do catálogo (posição 20), id `fade`. É só opacidade, sem deslocamento,
  varredura nem glitch. Prévias em `assets/previas/janelas/fade-*.webp`.
- **Durações:** abrir 150 ms e fechar 120 ms, abaixo da faixa das outras (o `conferir.py` abre exceção só
  para ela).
- **Primeira vez:** a chave `PrimeiraVezVariante` tem o mesmo nome que o CLI já grava. A ausência da chave
  (ou um valor vazio) vale `nenhuma`. A duração padrão da primeira vez é 1,6 × a do catálogo, no máximo
  700 ms ("montagem completa"). Para usar exatamente a do catálogo, grave `PrimeiraVezDuration` com ela.
