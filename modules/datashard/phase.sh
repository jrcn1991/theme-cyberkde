# modules/datashard/phase.sh — DATASHARD (app/arquivos) como gerenciador de arquivos padrão.
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# O app e o lançador (cyberkde-arquivos.desktop, com ícone próprio) são instalados fora do registro,
# como o painel: ficam no menu com o tema ligado ou não, e o uninstall os remove. Este módulo só cuida
# da ESCOLHA de pôr o DATASHARD como padrão para pastas, o efeito "datashard" (padrão desligado):
#   - ligado: a fase grava, com registro, [Default Applications] inode/directory em
#     ~/.config/mimeapps.list (o mesmo que "xdg-mime default cyberkde-arquivos.desktop
#     inode/directory"); o "off datashard" ou o "off" geral devolvem o que havia (normalmente nada: vale
#     o kde-mimeapps.list do sistema, o Dolphin).
#   - e o serviço D-Bus org.freedesktop.FileManager1 ("Mostrar na pasta"), com registro, em
#     ~/.local/share/dbus-1/services: o org.freedesktop.FileManager1.service e o
#     org.kde.dolphin.FileManager1.service (mesmo nome de arquivo do Dolphin do sistema, para encobri-lo),
#     os dois com Exec=python3 <app> --servico. São os mesmos arquivos da fase carregamento (Dolphin
#     animado): com o efeito ligado ela não os grava, e o off_datashard os devolve a ela se ela
#     continuar ligada. Um dono que já esteja no barramento (o "dolphin --daemon") fica até sair: o
#     app nunca toma o nome; a troca vale no próximo login.

CYBERKDE_PHASES+=(datashard)
descreve_fase datashard "DATASHARD padrão" apps nao "DATASHARD como gerenciador de arquivos padrão (só com o efeito datashard ligado)." \
  "Default DATASHARD" "DATASHARD as the default file manager (only with the datashard effect on)."

datashard_desktop=cyberkde-arquivos.desktop
datashard_pref() { kreadconfig6 --file "$efeitos_file" --group datashard --key ligado --default false 2>/dev/null; }
datashard_padrao_atual() {  # o .desktop padrão para pastas, pelo mimeapps.list do usuário (vazio = o do sistema)
  kreadconfig6 --file mimeapps.list --group "Default Applications" --key inode/directory 2>/dev/null
}

# A escolha vale agora (efeito ligado e app nesta cópia)?
datashard_ativo() { [[ $(datashard_pref) == true && -f $project/app/arquivos/cyberkde-arquivos.py ]]; }
datashard_servico="$data/dbus-1/services"

phase_datashard() {
  [[ $(datashard_pref) == true ]] || return 0
  if [[ ! -f $project/app/arquivos/cyberkde-arquivos.py ]]; then
    echo "DATASHARD: o app não está nesta cópia do tema (app/arquivos); o Dolphin continua o padrão." >&2
    return 0
  fi
  arquivos_lancador  # sem o lançador (cópia de desenvolvimento), o padrão apontaria para o nada
  set_key mimeapps.list "Default Applications" inode/directory "$datashard_desktop"
  local service
  for service in org.freedesktop.FileManager1 org.kde.dolphin.FileManager1; do
    # Sem SystemdService: o D-Bus usa este Exec (aspas: o caminho do projeto pode ter espaços).
    printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/python3 "%s" --servico\n' \
      "$project/app/arquivos/cyberkde-arquivos.py" | put_file "$datashard_servico/$service.service"
  done
  kbuildsycoca6 >/dev/null 2>&1 || true
}

# "off datashard" com o Dolphin animado ainda ligado: os .service voltam a ser dele (o off desta fase
# deixou o arquivo como estava, porque as duas o gravavam, ou o apagou, se só esta gravava).
off_datashard() {
  if fase_ligada carregamento && [[ -n $dolphin_wrapper && -x $dolphin_wrapper ]]; then
    (fase_atual=carregamento; carregamento_servicos)
  fi
}
CYBERKDE_OFF_HOOKS+=(off_datashard)

datashard_estado() {
  local atual
  atual=$(datashard_padrao_atual)
  printf '{"ligado":%s,"aplicado":%s,"padraoAtual":%s,"lancador":%s,"disponivel":%s,"servicoDBus":%s}' \
    "$([[ $(datashard_pref) == true ]] && echo true || echo false)" \
    "$([[ $atual == "$datashard_desktop" ]] && echo true || echo false)" \
    "$(json_caminho "$atual")" \
    "$([[ -f $data/applications/$datashard_desktop ]] && echo true || echo false)" \
    "$([[ -f $project/app/arquivos/cyberkde-arquivos.py ]] && echo true || echo false)" \
    "$(grep -qs -- '--servico' "$datashard_servico/org.freedesktop.FileManager1.service" && echo true || echo false)"
}

efeito_estado_datashard() { datashard_estado; }
efeito_json_datashard() {
  local previa="" f
  for f in "$project"/assets/previas/datashard.{webp,png} "$project"/assets/previas/datashard/previa.{webp,png}; do
    [[ -f $f ]] && { previa=$f; break; }
  done
  printf '{"id":"datashard","grupo":"sistema","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"liga","previa":%s,"opcoes":[],"forma":{"liga":true,"opcoes":{}},"comando":"cyberkde efeito datashard [on|off]","estado":%s}' \
    "$(json_str "DATASHARD como padrão")" "$(json_str "DATASHARD as default")" \
    "$(json_str "Abre as pastas no DATASHARD, o gerenciador de arquivos do tema, em vez do Dolphin. Desligar devolve o Dolphin. O DATASHARD fica no menu de qualquer jeito (cyberkde arquivos).")" \
    "$(json_str "Opens folders in DATASHARD, the theme's file manager, instead of Dolphin. Turning it off brings Dolphin back. DATASHARD stays in the menu either way (cyberkde arquivos).")" \
    "$(json_caminho "$previa")" "$(datashard_estado)"
}

#   cyberkde efeito datashard [on|off] [--json]   (sem on/off: só lê)
#   --json: {"efeito":"datashard",<estado>,"avisos":[...]}. Saída: 0 · 1 falha · 2 uso · 3 ocupado
# A escolha é gravada com a trava; depois a trava é solta e a fase é ligada ou desligada pelo próprio
# "cyberkde on|off datashard", que tem trava, registro e reversão completos.
efeito_cmd_datashard() {
  local acao="" arg
  for arg in "$@"; do
    case $arg in
      on | off) [[ -z $acao ]] && acao=$arg || acao=invalida ;;
      *) acao=invalida ;;
    esac
  done
  [[ $acao != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito datashard [on|off] [--json]" "usage: cyberkde efeito datashard [on|off] [--json]")"
  local -a avisos=()
  if [[ -n $acao ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    kwriteconfig6 --file "$efeitos_file" --group datashard --key ligado "$([[ $acao == on ]] && echo true || echo false)"
    flock -u 9; exec 9>&-
    local rc=0
    if [[ $acao == on && ! -f $project/app/arquivos/cyberkde-arquivos.py ]]; then
      avisos+=("$(t "O DATASHARD não está nesta cópia do tema: a escolha foi guardada; o Dolphin continua o padrão." "DATASHARD is not in this copy of the theme: the choice was saved; Dolphin stays the default.")")
    elif ! tema_ligado; then
      avisos+=("$(t "O tema está desligado: a escolha foi guardada e vale no próximo cyberkde on." "The theme is off: the choice was saved and applies on the next cyberkde on.")")
    elif [[ $acao == on ]]; then
      "$project/scripts/cyberkde" on datashard --sem-sudo >&2 </dev/null || rc=$?
    elif fase_ligada datashard; then
      "$project/scripts/cyberkde" off datashard >&2 </dev/null || rc=$?
    fi
    case $rc in
      0 | 4) ;;
      3) cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")" ;;
      *) cor_exit 1 "$(t "falha ao aplicar a escolha do DATASHARD (detalhes na saída de erro)" "failed to apply the DATASHARD choice (details on stderr)")" ;;
    esac
    if [[ $acao == on && $rc == 0 ]] && tema_ligado && datashard_ativo; then
      avisos+=("$(t "\"Mostrar na pasta\" passa ao DATASHARD quando o Dolphin em segundo plano sair (no próximo login, ou já, se ele não estiver rodando)." "\"Show in folder\" moves to DATASHARD once the background Dolphin exits (at the next login, or now if it is not running).")")
    fi
    if [[ $acao == on ]] && [[ -n $(arquivos_deps_faltando) ]]; then
      avisos+=("$(t "O DATASHARD precisa de pacotes que faltam: sudo apt install $(arquivos_deps_faltando | paste -sd' ' -)" "DATASHARD needs missing packages: sudo apt install $(arquivos_deps_faltando | paste -sd' ' -)")")
    fi
  fi
  local estado
  estado=$(datashard_estado)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"datashard",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "datashard: $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

CYBERKDE_EFEITOS+=(datashard)
CYBERKDE_EFEITO_GRUPO+=([datashard]=sistema)
