# modules/ilha/phase.sh — Ilha Dinâmica (app/ilha, seção 7 de docs/interno/ilha-spec.md).
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# Efeito "ilha" (padrão desligado), "cyberkde ilha on|off|status [--json]". A escolha fica em
# ~/.config/cyberkde/efeitos [ilha] ligado; a fase ilha grava, com registro, o autostart
# ~/.config/autostart/cyberkde-ilha.desktop e sobe o app solto. O "off" (geral ou da fase) devolve o
# autostart e pede para o app sair por D-Bus (org.cyberkde.Ilha.Sair); a escolha fica para o próximo "on".
# O app confere a escolha no --daemon e sai se estiver desligado. Quem grava a configuração da ilha é ele
# (--esquema, --estado, --definir): o CLI não mexe no ilha.json.

CYBERKDE_PHASES+=(ilha)
descreve_fase ilha "Ilha dinâmica" sistema nao "Ilha no topo da tela, com mídia, avisos e atalhos do sistema (só com o efeito ilha ligado)." \
  "Dynamic island" "Island at the top of the screen with media, notices and system shortcuts (only with the ilha effect on)."
CYBERKDE_OFF_HOOKS+=(off_ilha)
CYBERKDE_EFEITOS+=(ilha)
CYBERKDE_EFEITO_GRUPO+=([ilha]=area-de-trabalho)

ilha_app="$project/app/ilha/cyberkde-ilha.py"
ilha_autostart="$config/autostart/cyberkde-ilha.desktop"
ilha_pref() {  # ligado
  if (( efeitos_lote_ativo )); then efeitos_lote_ler ilha ligado false; return 0; fi
  kreadconfig6 --file "$efeitos_file" --group ilha --key ligado --default false 2>/dev/null
}
ilha_rodando() { qdbus6 org.cyberkde.Ilha /org/cyberkde/Ilha >/dev/null 2>&1; }

# Pacotes obrigatórios: os do painel e o layer-shell (a janela da ilha).
ilha_deps_faltando() {
  {
    painel_deps_faltando
    compgen -G '/usr/lib/*/qt6/qml/org/kde/layershell/qmldir' >/dev/null ||
      [[ -f /usr/lib/qt6/qml/org/kde/layershell/qmldir ]] || echo qml6-module-org-kde-layershell
  } | sort -u
}
# Opcionais: sem eles só some o recurso. pacote<TAB>para quê (PT)<TAB>(EN).
ilha_opcionais_faltando() {
  command -v pactl >/dev/null || printf 'pulseaudio-utils\tvolume e espectro\tvolume and spectrum\n'
  command -v tesseract >/dev/null || printf 'tesseract-ocr\tOCR de capturas\tOCR of screenshots\n'
  compgen -G '/usr/share/tesseract-ocr/*/tessdata/por.traineddata' >/dev/null ||
    printf 'tesseract-ocr-por\tOCR em português\tOCR in Portuguese\n'
  command -v spectacle >/dev/null || printf 'spectacle\tcapturas de tela\tscreenshots\n'
  command -v kdeconnect-cli >/dev/null || printf 'kdeconnect\tcelular\tphone\n'
  command -v sensors >/dev/null || printf 'lm-sensors\ttemperaturas\ttemperatures\n'
}

ilha_subir() {
  ilha_rodando && return 0
  mkdir -p -- "$state"
  # exec: sem isso, o subshell que espera o app fica vivo, segurando a trava e a saída de quem chamou.
  ( exec setsid python3 "$ilha_app" --daemon 3>&- 4>&- 9>&- ) >"$state/ilha.log" 2>&1 </dev/null &
}
ilha_parar() {  # pede para sair e espera a saída (até ~2 s); fora do ar, nada
  ilha_rodando || return 0
  qdbus6 org.cyberkde.Ilha /org/cyberkde/Ilha org.cyberkde.Ilha.Sair >/dev/null 2>&1 || true
  local i
  for i in {1..20}; do ilha_rodando || return 0; sleep 0.1; done
  return 1
}

phase_ilha() {
  [[ $(ilha_pref) == true ]] || return 0
  if [[ ! -f $ilha_app ]]; then
    echo "Ilha: o app não está nesta cópia do tema (app/ilha)." >&2
    return 0
  fi
  put_file "$ilha_autostart" <<EOF
[Desktop Entry]
Type=Application
Name=CyberKDE Ilha
Comment=Ilha dinâmica do CyberKDE
Exec=python3 "$ilha_app" --daemon
Icon=cyberkde-painel
Terminal=false
NoDisplay=true
X-KDE-autostart-phase=2
EOF
  if [[ -z $(ilha_deps_faltando) ]]; then ilha_subir; fi
}
# O registro já devolveu o autostart.
off_ilha() { ilha_parar || echo "Ilha: o app não saiu; ele fecha no próximo login." >&2; }

ilha_estado() {
  printf '{"ligado":%s,"escolhido":%s,"rodando":%s,"autostart":%s,"disponivel":%s}' \
    "$([[ $(ilha_pref) == true && -e $ilha_autostart ]] && echo true || echo false)" \
    "$([[ $(ilha_pref) == true ]] && echo true || echo false)" \
    "$(ilha_rodando && echo true || echo false)" \
    "$([[ -e $ilha_autostart ]] && echo true || echo false)" \
    "$([[ -f $ilha_app ]] && echo true || echo false)"
}
efeito_estado_ilha() { ilha_estado; }
efeito_json_ilha() {
  # Prévia do tema em uso (ilha.json); sem prévia dele, a do neomilitar.
  local tema previa
  tema=$(sed -n 's/.*"tema": *"\([a-z0-9_-]*\)".*/\1/p' "$config/cyberkde/ilha.json" 2>/dev/null | head -1)
  previa="$project/assets/previas/ilha/${tema:-neomilitar}.webp"
  [[ -f $previa ]] || previa="$project/assets/previas/ilha/neomilitar.webp"
  [[ -f $previa ]] || previa=""
  printf '{"id":"ilha","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"liga","previa":%s,"opcoes":[],"forma":{"liga":true,"opcoes":{}},"comando":"cyberkde efeito ilha [on|off]","estado":%s}' \
    "$(json_str "Ilha dinâmica")" "$(json_str "Dynamic island")" \
    "$(json_str "Uma ilha no topo da tela, com mídia, avisos, atalhos e o estado do sistema. As opções ficam na página Ilha do painel.")" \
    "$(json_str "An island at the top of the screen with media, notices, shortcuts and system status. Its options are on the panel's Island page.")" \
    "$(json_caminho "$previa")" "$(ilha_estado)"
}

# Status com as dependências (mais caro: não entra no status --json geral).
ilha_status_json() {
  local falta opc est corpo
  falta=$(ilha_deps_faltando | paste -sd' ' -)
  opc=$(ilha_opcionais_faltando | cut -f1 | paste -sd' ' -)
  est=$(ilha_estado); corpo=${est%\}}
  local -a f=() o=()
  [[ -z $falta ]] || read -ra f <<<"$falta"
  [[ -z $opc ]] || read -ra o <<<"$opc"
  printf '%s,"faltando":%s,"opcionais":%s}' "$corpo" "$(json_list_str "${f[@]}")" "$(json_list_str "${o[@]}")"
}

#   cyberkde efeito ilha [on|off] [--json] · cyberkde ilha on|off|status [--json]
#   --json: {"efeito":"ilha",<estado>,"avisos":[...]}. Saída: 0 · 1 falha · 2 uso · 3 ocupado
# A escolha é gravada com a trava; depois a trava é solta e a fase é ligada ou desligada pelo próprio
# "cyberkde on|off ilha" (efeito_fase_alternar), que tem registro e reversão completos.
efeito_cmd_ilha() {
  local acao="" arg rc=0
  for arg in "$@"; do
    case $arg in
      on | off) [[ -z $acao ]] && acao=$arg || acao=invalida ;;
      *) acao=invalida ;;
    esac
  done
  [[ $acao != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito ilha [on|off] [--json]" "usage: cyberkde efeito ilha [on|off] [--json]")"
  local -a avisos=()
  if [[ $acao == on ]]; then
    [[ -f $ilha_app ]] || cor_exit 1 "$(t "A ilha não está nesta cópia do tema (app/ilha)." "The island is not in this copy of the theme (app/ilha).")"
    local falta
    falta=$(ilha_deps_faltando | paste -sd' ' -)
    [[ -z $falta ]] || cor_exit 1 "$(t "A ilha precisa de pacotes que faltam: sudo apt install $falta" "The island needs missing packages: sudo apt install $falta")"
  fi
  if [[ -n $acao ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    kwriteconfig6 --file "$efeitos_file" --group ilha --key ligado "$([[ $acao == on ]] && echo true || echo false)"
    if [[ $acao == on ]]; then
      efeito_fase_alternar on ilha || rc=$?
      efeito_fase_erro "$rc" ilha
    else
      if fase_ligada ilha; then efeito_fase_alternar off ilha || rc=$?; efeito_fase_erro "$rc" ilha; fi
      ilha_parar || avisos+=("$(t "O app não saiu; ele fecha no próximo login." "The app did not exit; it closes at the next login.")")
    fi
  fi
  local estado
  estado=$(ilha_estado)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"ilha",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$(t "Ilha" "Island"): $estado" >&3
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

cmd_ilha() {
  local sub="" arg
  for arg in "$@"; do
    case $arg in
      --json) cor_json=1 ;;
      *) if [[ -z $sub ]]; then sub=$arg; else sub=invalida; fi ;;
    esac
  done
  if (( cor_json )); then exec 3>&1 1>&2; else exec 3>&1; fi
  case ${sub:-status} in
    on | off) efeito_cmd_ilha "$sub" ;;
    status) ilha_status_json >&3; echo >&3 ;;
    *) cor_exit 2 "$(t "uso: cyberkde ilha on|off|status [--json]" "usage: cyberkde ilha on|off|status [--json]")" ;;
  esac
}
