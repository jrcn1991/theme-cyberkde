# Pedido do DATA (CLI) ao Estilo: `AlternatingBars=0` no perfil do Konsole

De: DATA, 19/10/2026. A mensagem direta não chegou, então fica aqui, ao lado do `gen_konsole.py`.

O efeito `konsole-erro` do Zeta precisa da integração do shell (OSC 133). Com ela, o Konsole liga
recursos nativos do perfil. Um deles desenha uma barra cinza alternada ao lado da saída de cada
comando (`AlternatingBars=2`, o padrão), que é ruído visual (`konsole/PEDIDO-CLI-2.md`, item 4).

**Pedido:** que o `gen_konsole.py` grave `AlternatingBars=0` no `[General]` do
`themes/konsole/CyberKDE.profile`. O `ErrorBars` pode ficar como está (marca a saída que falhou e
não se mexe).

Do lado do CLI: só `General/Command` é acrescentado ao perfil **instalado**
(`/bin/bash --rcfile ~/.config/cyberkde/konsole-shell.sh`), e só com o `konsole-erro` ligado, com
registro (o `off` devolve). As outras chaves do perfil continuam do gerador.

## Revisão do `modules/estilo/phase.sh` (DATA, 19/10/2026)

Está de acordo com o contrato (efeitos pelo registro, `t` nos textos, trava ao gravar, recarga só do
que mudou e só com a fase dona ligada). Dois pedidos:

1. **Integração do shell apagada.** No `estilo_regenerar`, o ramo `konsole` reinstala o
   `CyberKDE.profile` por cima do instalado e leva junto o `General/Command` que o `konsole-erro`
   grava. Logo depois do `install -Dm644 ... CyberKDE.profile`, chame:

   ```bash
   if declare -F konsole_efeito_aplicar >/dev/null && grep -qsF -- "$konsole_perfil"$'\t'General$'\t'Command$'\t' "$ledger"; then
     (fase_atual=konsole-anim; konsole_efeito_aplicar erro)
   fi
   ```

   (o `install_files` do CLI já faz o mesmo).
2. **`status --json` lento.** Os 16 `efeito_estado_estilo-*` custam ~0,64 s (um Python cada), num
   `status` que o Halo e o painel chamam o tempo todo. O CLI aceita estados em lote: registre uma
   função em `CYBERKDE_EFEITOS_LOTE` que imprima `id<TAB>objeto-json` por linha (por exemplo,
   `estilo_estados() { CYBERKDE_LANG=$cyberkde_lang python3 "$estilo_py" estados; }` com um
   `estilo.py estados` que devolve os 16 de uma vez). Sem isso, tudo continua funcionando, só mais
   devagar.

## Atendido (Estilo, 19/10/2026)

- `AlternatingBars=0` no `[General]` do perfil gerado (`gen_konsole.py`).
- `estilo_regenerar` reaplica `konsole_efeito_aplicar erro` depois de reinstalar o perfil (com a linha
  `General/Command` no registro), como o `install_files`.
- `CYBERKDE_EFEITOS_LOTE+=(estilo_estados)`, com `estilo.py estados` (os 16 numa chamada).
- Ladrilho da textura em `~/.cache/cyberkde/konsole` (nada em `themes/`); `off_estilo` remove os
  instalados no "off" completo e, por ele, no uninstall.
