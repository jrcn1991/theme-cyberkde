# modules/som/phase.sh — sons do tema: bipes digitais, varreduras e glitches discretos, SINTETIZADOS por
# nós (generator/gen_som.py: numpy + wave, nada de terceiros), em OGG. Duas variantes, "padrao"
# (CyberKDE) e "discreto" (CyberKDE-discreto: mais suave, curta e baixa). Eventos do tema freedesktop
# que o KDE usa: notificação, informação, aviso, erro, login, logout, dispositivo conectado e removido,
# lixeira esvaziada, completar, campainha e alteração de volume.
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# Fase OPCIONAL (fora do "cyberkde on" de tudo, como o cursor): "cyberkde on som" liga, "cyberkde off som"
# devolve o tema de som de antes. Instala as duas variantes em ~/.local/share/sounds/CyberKDE[-discreto]
# e grava kdeglobals [Sounds] Theme (a chave que o KNotification/canberra e o módulo "Tema de som" das
# Configurações do Sistema usam no Plasma 6). A variante é uma preferência, em ~/.config/cyberkde/efeitos:
#   [som]
#   variante=padrao|discreto

CYBERKDE_FASES_OPCIONAIS+=(som)
descreve_fase som "Sons do tema" sistema nao "Sons de interface cyberpunk (bipes, varreduras e glitches discretos), baixos e opcionais, em 2 variantes (padrão, discreto)." \
  "Theme sounds" "Cyberpunk interface sounds (beeps, sweeps and subtle glitches), quiet and optional, in 2 variants (default, subtle)."
CYBERKDE_EFEITOS+=(som)
CYBERKDE_EFEITO_GRUPO+=([som]=sistema)
CYBERKDE_OFF_HOOKS+=(off_som)

som_build="$project/modules/som/build"
som_variantes=(padrao discreto)

# Variante escolhida (padrao se a chave não existe ou não é uma das duas).
som_variante() {
  local v
  v=$(kreadconfig6 --file "$config/cyberkde/efeitos" --group som --key variante --default padrao 2>/dev/null)
  case $v in padrao | discreto) printf '%s\n' "$v" ;; *) echo padrao ;; esac
}

# Nome do tema (e da pasta em ~/.local/share/sounds) de uma variante.
som_tema_nome() {  # variante
  if [[ $1 == padrao ]]; then echo CyberKDE; else echo CyberKDE-discreto; fi
}

# Gera de novo só quando o gerador mudou (ou falta algo). Leva ~2 s.
som_gerar() {
  local gen="$project/modules/som/generator/gen_som.py" v
  if [[ -s $som_build/.carimbo && $(cat "$som_build/.carimbo") == "$(python3 "$gen" --carimbo)" ]]; then
    for v in "${som_variantes[@]}"; do [[ -s $som_build/$v/theme/index.theme ]] || { python3 "$gen" --saida "$som_build" >/dev/null; return; }; done
    return 0
  fi
  python3 "$gen" --saida "$som_build" >/dev/null
}

# Arquivo de uma variante e evento (.ogg, ou .wav se a máquina não tinha codificador), ou nada.
som_arquivo() {  # variante evento
  local f
  for f in "$som_build/$1/theme/stereo/$2".{ogg,wav}; do
    if [[ -f $f ]]; then printf '%s\n' "$f"; return; fi
  done
}

# Grava a variante escolhida (rodando como a fase "som"): o set_key anota o tema de antes para o "off".
efeito_som_aplicar() {
  local nome
  nome=$(som_tema_nome "$(som_variante)")
  [[ -d $data/sounds/$nome ]] || return 0  # ainda não instalado: o próximo "on som" instala
  set_key kdeglobals Sounds Theme "$nome"
  kconfig_avisar kdeglobals Sounds "$nome"
}

phase_som() {
  som_gerar
  local v
  for v in "${som_variantes[@]}"; do
    put_dir "$som_build/$v/theme" "$data/sounds/$(som_tema_nome "$v")"
  done
  efeito_som_aplicar
}

# O registro já devolveu o kdeglobals e removeu as pastas; basta avisar quem vigia a chave.
off_som() {
  local t
  t=$(kreadconfig6 --file kdeglobals --group Sounds --key Theme --default ocean 2>/dev/null)
  kconfig_avisar kdeglobals Sounds "$t"
}

# Estado: a variante escolhida, se a fase está ligada e o tema de som em uso agora.
efeito_estado_som() {
  local ligado=false
  if fase_ligada som; then ligado=true; fi
  printf '{"variante":"%s","ligado":%s,"aplicado":%s,"ligarCom":"cyberkde on som","desligarCom":"cyberkde off som"}' \
    "$(som_variante)" "$ligado" "$(json_str "$(kreadconfig6 --file kdeglobals --group Sounds --key Theme --default ocean 2>/dev/null)")"
}

# Lista de sons de uma variante em JSON: [{"evento","previaSom"}...] (os próprios arquivos).
som_lista_json() {  # variante
  local e out=""
  for e in message-new-instant dialog-information dialog-warning dialog-error desktop-login desktop-logout \
    device-added device-removed trash-empty complete bell audio-volume-change; do
    out+="${out:+,}{\"evento\":\"$e\",\"previaSom\":$(json_caminho "$(som_arquivo "$1" "$e")")}"
  done
  printf '[%s]' "$out"
}

efeito_json_som() {
  som_gerar 2>/dev/null || true
  local v valores="" nome nome_en
  for v in "${som_variantes[@]}"; do
    case $v in
      padrao) nome="Padrão"; nome_en="Default" ;;
      *) nome="Discreto"; nome_en="Subtle" ;;
    esac
    valores+="${valores:+,}{\"id\":\"$v\",\"nome\":$(json_str "$nome"),\"nome_en\":$(json_str "$nome_en"),\"previa\":null,\"previaSom\":$(json_caminho "$(som_arquivo "$v" message-new-instant)"),\"sons\":$(som_lista_json "$v")}"
  done
  printf '{"id":"som","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"variante","nome":"Variante","nome_en":"Variant","tipo":"variante","padrao":"padrao","valores":[%s]}],"estado":%s}' \
    "$(json_str "Sons do tema")" "$(json_str "Theme sounds")" \
    "$(json_str "Bipes e varreduras cyberpunk, baixos, para notificação, aviso, erro, login, dispositivos, lixeira e volume. Desligado por padrão; liga e desliga pela fase som.")" \
    "$(json_str "Quiet cyberpunk beeps and sweeps for notifications, warnings, errors, login, devices, trash and volume. Off by default; turned on and off by the som part.")" \
    "$valores" "$(efeito_estado_som)"
}

#   cyberkde efeito som [padrao|discreto] [--json]   (sem variante: só lê)
#   --json: {"efeito":"som",<estado>,"avisos":[...]}. Saída: 0 · 2 uso · 3 ocupado
efeito_cmd_som() {
  local variante="" arg
  for arg in "$@"; do
    case $arg in
      padrao | discreto) [[ -z $variante ]] && variante=$arg || variante=invalida ;;
      *) variante=invalida ;;
    esac
  done
  [[ $variante != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito som [padrao|discreto] [--json]" "usage: cyberkde efeito som [padrao|discreto] [--json]")"
  local -a avisos=()
  if [[ -n $variante ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    kwriteconfig6 --file "$efeitos_file" --group som --key variante "$variante"
    if fase_ligada som; then
      (fase_atual=som; efeito_som_aplicar)
    else
      avisos+=("$(t "Os sons do tema estão desligados: a variante foi guardada; para usar, cyberkde on som." "Theme sounds are off: the variant was saved; to use it, cyberkde on som.")")
    fi
  fi
  local estado
  estado=$(efeito_estado_som)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"som",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$(t "Sons do tema" "Theme sounds"): $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}
