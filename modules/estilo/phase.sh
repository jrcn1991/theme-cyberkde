# modules/estilo/phase.sh — opções de estilo da interface (docs/interno/catalogo-interface.md): seleção,
# brilho, corte, densidade, abas, progresso, marcador, cantoneiras, foco, controles do Plasma, textura,
# abas do Konsole, dicas, campos, cores de estado e os presets. Cada opção é um efeito do tipo
# "variante" ("cyberkde efeito estilo-<opção> ..."); o painel monta a lista com "cyberkde efeito --lista
# --json". Carregado com `source` pelo scripts/cyberkde: só define funções e registra nomes.
#
# A escolha fica em ~/.config/cyberkde/estilo (JSON), que os geradores leem (generator/cyberlib.py,
# ESTILO). Não há chave de programa para gravar: são os próprios arquivos do tema (Kvantum, Aurorae,
# Konsole, Plasma) que mudam. Com o tema ligado, o comando regenera só o que a opção afeta, instala por
# cima e recarrega (Kvantum: os apps reabrem; Aurorae: reconfigure do KWin; Plasma: o plasmashell
# reinicia só se o tema dele mudou). Com o tema desligado, só guarda: vale no próximo "cyberkde on".
estilo_py="$project/modules/estilo/estilo.py"
CYBERKDE_INSTALLS+=(install_estilo)
CYBERKDE_OFF_HOOKS+=(off_estilo)
CYBERKDE_EFEITOS_LOTE+=(estilo_estados)
estilo_textura_cache="${XDG_CACHE_HOME:-$HOME/.cache}/cyberkde/konsole"

# Os 16 estados num Python só (status --json): "id<TAB>objeto" por linha.
estilo_estados() { CYBERKDE_LANG=$cyberkde_lang python3 "$estilo_py" estados; }

# Ids fixos aqui (sem rodar Python ao carregar); a lista é a mesma de "estilo.py ids".
estilo_ids=(estilo-preset estilo-selecao estilo-brilho estilo-corte estilo-densidade estilo-abas estilo-progresso
  estilo-marcador estilo-moldura estilo-foco estilo-pecas estilo-textura estilo-konsole-abas estilo-dica
  estilo-campos estilo-estados)
CYBERKDE_EFEITOS+=("${estilo_ids[@]}")
for _e in "${estilo_ids[@]}"; do
  eval "efeito_cmd_$_e() { estilo_cmd $_e \"\$@\"; }
efeito_json_$_e() { CYBERKDE_LANG=\$cyberkde_lang python3 \"\$estilo_py\" json $_e; }
efeito_estado_$_e() { CYBERKDE_LANG=\$cyberkde_lang python3 \"\$estilo_py\" estado $_e; }"
done
unset _e

# Textura do Konsole (opção estilo-textura): o gen_konsole gera o ladrilho em ~/.cache/cyberkde/konsole
# (fora do repositório) e o esquema aponta para a cópia em ~/.local/share/konsole, que o install_files
# não faz (só o esquema e o perfil). Ladrilho instalado que não é mais o atual sai.
install_estilo() {
  local f
  for f in "$data"/konsole/CyberKDE-textura-*.png; do
    [[ -f $f && ! -f $estilo_textura_cache/${f##*/} ]] && rm -f -- "$f"
  done
  for f in "$estilo_textura_cache"/CyberKDE-textura-*.png; do
    [[ -f $f ]] && install -Dm644 -t "$data/konsole" "$f"
  done
  return 0
}

# "off" completo (e o uninstall, que passa por ele): o perfil CyberKDE deixa de ser usado, então o
# ladrilho instalado sai. O próximo "on" (install_files -> install_estilo) o põe de volta.
off_estilo() {
  rm -f -- "$data"/konsole/CyberKDE-textura-*.png
  rmdir -- "$data/konsole" 2>/dev/null || true
}

# Impressão digital do que um alvo gera, para recarregar só o que mudou de fato.
estilo_soma() {  # alvo  (arquivo ausente, como o ladrilho sem textura, não pode derrubar o pipefail)
  { case $1 in
    kvantum) cat "$project/themes/kvantum/CyberKDE/"* "$project/themes/color-schemes/CyberKDE.colors" ;;
    aurorae) cat "$project/themes/aurorae/CyberKDE/"* ;;
    konsole) cat "$project/themes/konsole/"* "$estilo_textura_cache"/CyberKDE-textura-*.png ;;
    plasma) find "$project/modules/plasma/build/desktoptheme/CyberKDE" -type f -print0 | sort -z | xargs -0 cat ;;
  esac 2>/dev/null || true; } | md5sum | cut -d' ' -f1
}

# Regenera, instala e recarrega os alvos (uma linha por alvo). Ecoa os que mudaram.
estilo_regenerar() {
  local alvo antes mudou=() cores=0
  for alvo in "$@"; do
    antes=$(estilo_soma "$alvo")
    case $alvo in
      kvantum)
        local cores_antes
        cores_antes=$(md5sum <"$project/themes/color-schemes/CyberKDE.colors")
        python3 "$project/generator/gen_kvantum.py" >/dev/null
        if [[ $(estilo_soma kvantum) != "$antes" ]]; then
          [[ $(md5sum <"$project/themes/color-schemes/CyberKDE.colors") == "$cores_antes" ]] || cores=1
          install -Dm644 "$project/themes/color-schemes/CyberKDE.colors" "$data/color-schemes/CyberKDE.colors"
          install -Dm644 -t "$config/Kvantum/CyberKDE" "$project/themes/kvantum/CyberKDE/CyberKDE.kvconfig" \
            "$project/themes/kvantum/CyberKDE/CyberKDE.svg"
          mudou+=(kvantum)
        fi ;;
      aurorae)
        python3 "$project/generator/gen_aurorae.py" >/dev/null
        if [[ $(estilo_soma aurorae) != "$antes" ]]; then
          swap_dir "$project/themes/aurorae/CyberKDE" "$data/aurorae/themes/CyberKDE"
          mudou+=(aurorae)
        fi ;;
      konsole)
        python3 "$project/generator/gen_konsole.py" >/dev/null
        if [[ $(estilo_soma konsole) != "$antes" ]]; then
          install -Dm644 -t "$data/konsole" "$project/themes/konsole/CyberKDE.colorscheme" "$project/themes/konsole/CyberKDE.profile"
          # O perfil foi regravado: a integração do shell do konsole-erro (General/Command) volta, se
          # estava ligada (o install_files do CLI faz o mesmo).
          if declare -F konsole_efeito_aplicar >/dev/null && grep -qsF -- "$konsole_perfil"$'\t'General$'\t'Command$'\t' "$ledger"; then
            (fase_atual=konsole-anim; konsole_efeito_aplicar erro)
          fi
          install_estilo
          mudou+=(konsole)
        fi ;;
      plasma)
        python3 "$project/modules/plasma/generator/gen_plasma.py" >/dev/null
        if [[ $(estilo_soma plasma) != "$antes" ]]; then
          if declare -F install_plasma >/dev/null; then install_plasma >/dev/null; fi
          mudou+=(plasma)
        fi ;;
    esac
  done
  # Recarga: só do que mudou e só se a fase que usa aquilo está ligada.
  if [[ " ${mudou[*]} " == *" aurorae "* ]] && fase_ligada janelas; then reload_kwin >/dev/null; fi
  if (( cores )) && fase_ligada apps && declare -F apply_colorscheme >/dev/null; then apply_colorscheme CyberKDE >/dev/null; fi
  if [[ " ${mudou[*]} " == *" plasma "* ]] && fase_ligada plasma; then
    restart_plasmashell >/dev/null 2>&1 || echo "$(t "Aviso: o plasmashell não reiniciou; o Plasma muda no próximo login." "Note: plasmashell did not restart; Plasma changes on next login.")" >&2
  fi
  printf '%s\n' "${mudou[@]}"
}

#   cyberkde efeito estilo-<opção> [on|off] [--variante v | v] [--<opção> valor] [--json]
#   sem argumentos: só lê. "off" volta ao padrão (e lembra a escolha); "on" sem variante religa a última
#   escolhida, com as opções dela, ou a primeira que não é o padrão (preset: militar-denso). --json: {"efeito":id,<estado>,"aplicado":[...],"avisos":[...]}
#   Saída: 0 · 2 uso · 3 ocupado
estilo_cmd() {
  local id=$1 alvos saida
  shift
  local -a avisos=() aplicado=()
  if (( $# )); then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    if ! saida=$(CYBERKDE_LANG=$cyberkde_lang python3 "$estilo_py" aplicar "$id" "$@" 2>&1); then
      cor_exit 2 "uso: cyberkde efeito $id [on|off] [--variante valor] — $saida"
    fi
    alvos=$saida
    if [[ -n $alvos ]]; then
      if tema_ligado; then
        mapfile -t aplicado < <(estilo_regenerar $alvos)
        if [[ " ${aplicado[*]} " == *" kvantum "* ]]; then
          avisos+=("$(t "Os aplicativos abertos mudam ao reabrir." "Open applications change when reopened.")")
        fi
        if [[ " ${aplicado[*]} " == *" konsole "* ]]; then
          avisos+=("$(t "O Konsole muda nas janelas novas." "Konsole changes in new windows.")")
        fi
      else
        avisos+=("$(t "O tema está desligado: a escolha foi guardada e vale no próximo cyberkde on." "The theme is off: the choice was saved and applies on the next cyberkde on.")")
      fi
    fi
  fi
  local estado
  estado=$(CYBERKDE_LANG=$cyberkde_lang python3 "$estilo_py" estado "$id")
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"%s",%s,"aplicado":%s,"avisos":%s}\n' "$id" "${corpo%\}}" \
      "$(json_list "${aplicado[@]}")" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$id: $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}
