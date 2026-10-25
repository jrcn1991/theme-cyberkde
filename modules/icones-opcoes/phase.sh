# modules/icones-opcoes/phase.sh — estilos alternativos dos ícones de pastas e da lixeira (efeito "icones").
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes. Não é uma fase: a
# escolha é um efeito ("cyberkde efeito icones"), que o painel monta a partir de "efeito --lista --json".
#
# Seis grupos, cada um com o estilo padrão (assets/icons/ai-final) ou o alternativo
# (assets/icons/alternativos): documents, music, pictures, recent, remote e trash (a lixeira cheia).
# A escolha fica em ~/.config/cyberkde/efeitos, grupo [icones], uma chave por grupo (padrao|alt).
#
# Quem gera é o generator/gen_icons.py com --alt; o padrão do gerador (sem argumento) continua sendo
# o tema versionado em themes/icons/CyberKDE, e por isso o tema com alternativos é gerado FORA do
# repositório (~/.cache/cyberkde/icones-alt) e instalado por cima pelo gancho abaixo, no fim do
# "cyberkde install"/"on" (depois de o install_files instalar o padrão).

CYBERKDE_EFEITOS+=(icones)
CYBERKDE_INSTALLS+=(install_icones-opcoes)

icones_grupos=(documents music pictures recent remote trash)
icones_efeitos_file="$config/cyberkde/efeitos"

icones_grupo_nome() {  # grupo pt|en
  case $1$2 in
    documentspt) echo "Documentos" ;; documentsen) echo "Documents" ;;
    musicpt) echo "Músicas" ;; musicen) echo "Music" ;;
    picturespt) echo "Imagens" ;; picturesen) echo "Pictures" ;;
    recentpt) echo "Recentes" ;; recenten) echo "Recent" ;;
    remotept) echo "Remoto" ;; remoteen) echo "Remote" ;;
    trashpt) echo "Lixeira cheia" ;; trashen) echo "Full trash" ;;
  esac
}

icones_estilo() {  # grupo -> padrao|alt
  local v
  v=$(kreadconfig6 --file "$icones_efeitos_file" --group icones --key "$1" --default padrao 2>/dev/null)
  case $v in alt) echo alt ;; *) echo padrao ;; esac
}

# Grupos com o estilo alternativo, separados por vírgula (vazio: tudo no padrão).
icones_alt_lista() {
  local g out=""
  for g in "${icones_grupos[@]}"; do
    if [[ $(icones_estilo "$g") == alt ]]; then out+="${out:+,}$g"; fi
  done
  printf '%s\n' "$out"
}

# Gera o tema com a lista de alternativos fora do repositório e instala por cima do tema de ícones.
icones_opcoes_gerar() {  # lista
  local saida="${XDG_CACHE_HOME:-$HOME/.cache}/cyberkde/icones-alt"
  rm -rf -- "$saida"
  python3 "$project/generator/gen_icons.py" ${1:+--alt "$1"} --saida "$saida/CyberKDE" >/dev/null || return 1
  swap_dir "$saida/CyberKDE" "$data/icons/CyberKDE"
  rm -rf -- "$saida"
  if declare -F icones_sistema_avisar >/dev/null; then icones_sistema_avisar; fi
}

# O install_files já instalou o padrão; com alternativos escolhidos, troca pelo tema com eles.
install_icones-opcoes() {
  local lista
  lista=$(icones_alt_lista)
  [[ -n $lista ]] || return 0
  icones_opcoes_gerar "$lista"
}

icones_previa() {  # grupo estilo -> caminho absoluto da prévia, ou nada
  local f="$project/assets/previas/icones/$1-$2.webp"
  if [[ -f $f ]]; then printf '%s\n' "$f"; fi
}

efeito_estado_icones() {
  local g out="" instalado=false
  [[ -f $data/icons/CyberKDE/index.theme ]] && instalado=true
  for g in "${icones_grupos[@]}"; do out+="${out:+,}\"$g\":\"$(icones_estilo "$g")\""; done
  printf '{"grupos":{%s},"temaInstalado":%s}' "$out" "$instalado"
}

efeito_json_icones() {
  local g opcoes="" comparacao=""
  for g in "${icones_grupos[@]}"; do
    opcoes+="${opcoes:+,}{\"id\":\"$g\",\"nome\":$(json_str "$(icones_grupo_nome "$g" pt)"),\"nome_en\":$(json_str "$(icones_grupo_nome "$g" en)"),\"tipo\":\"escolha\",\"padrao\":\"padrao\",\"valores\":[{\"id\":\"padrao\",\"nome\":\"Padrão\",\"nome_en\":\"Default\",\"previa\":$(json_caminho "$(icones_previa "$g" padrao)")},{\"id\":\"alt\",\"nome\":\"Alternativo\",\"nome_en\":\"Alternative\",\"previa\":$(json_caminho "$(icones_previa "$g" alt)")}]}"
  done
  [[ -f $project/assets/previas/icones/comparacao.webp ]] && comparacao="$project/assets/previas/icones/comparacao.webp"
  printf '{"id":"icones","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","previa":%s,"opcoes":[%s],"estado":%s}' \
    "$(json_str "Ícones alternativos")" "$(json_str "Alternative icons")" \
    "$(json_str "Seis ícones de pastas e da lixeira com um segundo estilo, escolhido um a um. Vale na hora, nos apps abertos.")" \
    "$(json_str "Six folder and trash icons with a second style, picked one by one. Applies right away, in open apps.")" \
    "$(json_caminho "$comparacao")" "$opcoes" "$(efeito_estado_icones)"
}

#   cyberkde efeito icones [padrao|alt|<grupo>=<padrao|alt>...] [--json]   (sem argumento: só lê)
#   padrao/alt valem para os seis grupos; <grupo>=<estilo> só para aquele. Grupos: documents music
#   pictures recent remote trash. --json: {"efeito":"icones",<estado>,"avisos":[...]}. Saída: 0 · 1 falha ·
#   2 uso · 3 ocupado
efeito_cmd_icones() {
  local -a pares=()
  local arg g e ok
  for arg in "$@"; do
    case $arg in
      padrao | alt) for g in "${icones_grupos[@]}"; do pares+=("$g=$arg"); done ;;
      *=padrao | *=alt)
        g=${arg%%=*} e=${arg#*=} ok=0
        for x in "${icones_grupos[@]}"; do [[ $x == "$g" ]] && ok=1; done
        (( ok )) || pares+=("invalido=1")
        pares+=("$g=$e") ;;
      *) pares+=("invalido=1") ;;
    esac
  done
  local p
  for p in "${pares[@]}"; do
    [[ $p != invalido=1 ]] || cor_exit 2 "$(t "uso: cyberkde efeito icones [padrao|alt|<grupo>=<padrao|alt>...] [--json] (grupos: ${icones_grupos[*]})" "usage: cyberkde efeito icones [padrao|alt|<group>=<padrao|alt>...] [--json] (groups: ${icones_grupos[*]})")"
  done
  local -a avisos=()
  if (( ${#pares[@]} )); then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$icones_efeitos_file")"
    for p in "${pares[@]}"; do kwriteconfig6 --file "$icones_efeitos_file" --group icones --key "${p%%=*}" "${p#*=}"; done
    if [[ -f $data/icons/CyberKDE/index.theme ]]; then
      icones_opcoes_gerar "$(icones_alt_lista)" || cor_exit 1 "$(t "não consegui gerar o tema de ícones" "could not generate the icon theme")"
    else
      avisos+=("$(t "O tema de ícones CyberKDE não está instalado: a escolha foi guardada e vale no próximo cyberkde install." "The CyberKDE icon theme is not installed: the choice was saved and applies on the next cyberkde install.")")
    fi
  fi
  local estado
  estado=$(efeito_estado_icones)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"icones",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$(t "Ícones alternativos" "Alternative icons"): $estado"
    for p in "${avisos[@]}"; do echo "$(t Aviso Note): $p" >&2; done
  fi
}
