# modules/kwin-extras/phase.sh — opções do KWin e do KDE escolhidas no painel ("cyberkde efeito ..."):
#   movimento        completo | reduzido | minimo (AnimationDurationFactor do KDE e os efeitos do tema)
#   modal-escurecer  escurecer a janela-mãe de um diálogo modal e a tela num pedido de senha
#   clique           anéis no ponto do clique, nas cores do tema
#   areas            áreas de trabalho virtuais nomeadas como módulos (4 ou 6)
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# A fase "kwin-extras" entra no "cyberkde on" (tudo), mas só grava o que a pessoa escolheu: sem
# nenhuma escolha em ~/.config/cyberkde/efeitos, não mexe em nada. Tudo pelo set_key (o "off" devolve
# o original; o "on" reaplica a escolha guardada).
#
# Chaves conferidas no Plasma 6.6.6 (Ubuntu 26.04):
# - dialogparent e dimscreen: efeitos em JS do KWin (/usr/share/kwin-wayland/effects), ligados por
#   padrão, SEM opção de cor ou força (o escurecimento é fixo no main.js deles). Daqui só se liga e
#   desliga: kwinrc [Plugins] dialogparentEnabled / dimscreenEnabled.
# - mouseclick: efeito embutido, desligado por padrão; kwinrc [Plugins] mouseclickEnabled e
#   [Effect-mouseclick] Color1/Color2/Color3 (botões esquerdo/meio/direito), LineWidth, RingCount,
#   RingLife (ms), RingSize (raio), ShowText (do módulo de configuração kwin_mouseclick_config). Com o
#   efeito carregado, os anéis aparecem depois do atalho do KDE "Alternar efeito de clique do mouse"
#   (Meta+*): o KWin não tem chave para começar já ativo.
# - áreas de trabalho: kwinrc [Desktops] Number, Rows e Name_<n>; com a sessão aberta, o KWin só
#   cria, remove e renomeia pelo D-Bus (org.kde.KWin.VirtualDesktopManager), que o areas_sincronizar
#   usa para deixar a sessão igual ao kwinrc.

CYBERKDE_PHASES+=(kwin-extras)
CYBERKDE_OFF_HOOKS+=(off_kwin-extras)
descreve_fase kwin-extras "Extras do KWin" janelas nao "Opções escolhidas no painel: movimento, escurecer diálogos, anel de clique, áreas de trabalho." \
  "KWin extras" "Options picked in the panel: motion, dim dialogs, click rings, virtual desktops."
CYBERKDE_EFEITOS+=(movimento modal-escurecer clique areas)
CYBERKDE_EFEITO_GRUPO+=([movimento]=sistema [modal-escurecer]=janelas [clique]=interface [areas]=area-de-trabalho)

kx_pref() { kreadconfig6 --file "$efeitos_file" --group "$1" --key "$2" --default "${3:-}" 2>/dev/null; }
kx_gravar() {  # grupo chave valor
  mkdir -p -- "$(dirname -- "$efeitos_file")"
  kwriteconfig6 --file "$efeitos_file" --group "$1" --key "$2" "$3"
}
kx_tem() { [[ -s $efeitos_file ]] && grep -q "^\[$1\]" "$efeitos_file"; }
kx_bool() { [[ $1 == true ]] && echo true || echo false; }

# ------------------------------------------------------------------ aplicar (pela fase)
kx_movimento_aplicar() {
  kx_tem movimento || return 0
  case $(movimento_nivel) in
    reduzido) set_key kdeglobals KDE AnimationDurationFactor 0.5 ;;
    minimo) set_key kdeglobals KDE AnimationDurationFactor 0 ;;
    *) chave_restaurar kdeglobals KDE AnimationDurationFactor ;;  # completo: o fator da pessoa
  esac
}
kx_modal_aplicar() {
  kx_tem modal-escurecer || return 0
  local v
  v=$(kx_bool "$(kx_pref modal-escurecer ligado true)")
  set_key kwinrc Plugins dialogparentEnabled "$v"
  set_key kwinrc Plugins dimscreenEnabled "$v"
}
kx_clique_aplicar() {
  kx_tem clique || return 0
  local v cores c1 c2 c3
  v=$(kx_bool "$(kx_pref clique ligado false)")
  set_key kwinrc Plugins mouseclickEnabled "$v"
  [[ $v == true ]] || return 0
  # Cores do tema: destaque no botão esquerdo, secundária no meio, alerta no direito ("r,g,b").
  cores=$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from cyberlib import RED, CYAN, ALERTA, rgb
print(*(",".join(map(str, rgb(c))) for c in (RED, CYAN, ALERTA)))' "$project/generator")
  read -r c1 c2 c3 <<<"$cores"
  set_key kwinrc Effect-mouseclick Color1 "$c1"
  set_key kwinrc Effect-mouseclick Color2 "$c2"
  set_key kwinrc Effect-mouseclick Color3 "$c3"
  set_key kwinrc Effect-mouseclick LineWidth 1   # filete de 1 px, como o resto do tema
  set_key kwinrc Effect-mouseclick RingCount 2
  set_key kwinrc Effect-mouseclick RingLife 320
  set_key kwinrc Effect-mouseclick RingSize 18
  set_key kwinrc Effect-mouseclick ShowText false
}

# Nomes das áreas: códigos técnicos (catálogo L7) ou nomes simples.
areas_nomes() {  # cyber|simples quantidade
  local -a cyber=("SYS.01 TRABALHO" "NET.02 WEB" "DEV.03 CÓDIGO" "MID.04 MÍDIA" "COM.05 CONVERSA" "ARQ.06 ARQUIVO")
  local -a simples=("Trabalho" "Web" "Código" "Mídia" "Conversa" "Arquivo")
  local i
  for (( i = 0; i < $2; i++ )); do
    if [[ $1 == simples ]]; then echo "${simples[i]}"; else echo "${cyber[i]}"; fi
  done
}
areas_marca="$state/areas-do-tema"
kx_areas_aplicar() {
  kx_tem areas || return 0
  local n nomes i nome
  n=$(kx_pref areas numero 0) nomes=$(kx_pref areas nomes cyber)
  if [[ $n != 4 && $n != 6 ]]; then  # desligado: o que o tema gravou volta ao original
    for i in Number Rows Name_1 Name_2 Name_3 Name_4 Name_5 Name_6; do chave_restaurar kwinrc Desktops "$i"; done
    if [[ -e $areas_marca ]]; then areas_sincronizar; rm -f -- "$areas_marca"; fi
    return 0
  fi
  # Marca "o tema mexeu nas áreas" (só então se sincroniza a sessão), com a quantidade e os nomes que a
  # sessão tinha antes (linha 1: quantidade; depois, um nome por linha), para o "off" voltar a elas
  # mesmo se o kwinrc original não dizia o número nem os nomes.
  if [[ ! -e $areas_marca ]]; then
    mkdir -p -- "$state"
    areas_retrato >"$areas_marca" || : >"$areas_marca"
  fi
  set_key kwinrc Desktops Number "$n"
  set_key kwinrc Desktops Rows 1
  i=0
  while IFS= read -r nome; do
    i=$(( i + 1 ))
    set_key kwinrc Desktops "Name_$i" "$nome"
  done < <(areas_nomes "$nomes" "$n")
}

phase_kwin-extras() {
  local g algum=0
  for g in movimento modal-escurecer clique areas; do kx_tem "$g" && algum=1; done
  (( algum )) || return 0  # nada escolhido: nada gravado, nada recarregado
  kx_movimento_aplicar
  kx_modal_aplicar
  kx_clique_aplicar
  kx_areas_aplicar
  kx_recarregar
}

# ------------------------------------------------------------------ sessão aberta
# Deixa a sessão igual ao kwinrc: o fator de animação avisado aos apps, os efeitos carregados ou
# descarregados, e as áreas de trabalho criadas, removidas e renomeadas pelo D-Bus do KWin.
kx_recarregar() {
  kconfig_avisar kdeglobals KDE AnimationDurationFactor
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  local e padrao
  for e in dialogparent:true dimscreen:true mouseclick:false; do
    padrao=${e#*:} e=${e%%:*}
    if [[ $(kreadconfig6 --file kwinrc --group Plugins --key "${e}Enabled" --default "$padrao") == true ]]; then
      qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$e" >/dev/null 2>&1 || true
      qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect "$e" >/dev/null 2>&1 || true
    else
      qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$e" >/dev/null 2>&1 || true
    fi
  done
  # Áreas de trabalho: só quando o tema mexeu nelas (a marca). Sem isto, qualquer recarga deixaria a
  # sessão igual ao kwinrc, e um kwinrc sem [Desktops] (o padrão é 1) apagaria áreas que a pessoa
  # criou e nunca pediu para o tema tocar.
  if [[ -e $areas_marca ]]; then areas_sincronizar; fi
}

# Ids das áreas na ordem, a partir do texto do gdbus: "(<[(uint32 0, 'id', 'nome'), (1, 'id2', ...)]>,)"
# (só o primeiro item traz o tipo "uint32").
# Áreas da sessão na ordem, a partir do texto do gdbus: "(<[(uint32 0, 'id', 'nome'), (1, 'id2', ...)]>,)"
# (só o primeiro item traz o tipo "uint32"). areas_ids: um id por linha; areas_nomes_sessao: um nome.
areas_lista() {
  TEXTO=$1 python3 -c 'import os, re
for m in re.finditer(r"\((?:uint32 )?\d+, \x27([^\x27]+)\x27, \x27([^\x27]*)\x27", os.environ["TEXTO"]):
    print(m.group(1) + "\t" + m.group(2))'
}
areas_ids() { areas_lista "$1" | cut -f1; }

areas_texto() {
  gdbus call --session --dest org.kde.KWin --object-path /VirtualDesktopManager \
    --method org.freedesktop.DBus.Properties.Get org.kde.KWin.VirtualDesktopManager desktops 2>/dev/null
}
areas_retrato() {  # quantidade (linha 1) e nomes (um por linha) das áreas da sessão; falha sem KWin
  local tx n
  tx=$(areas_texto) || return 1
  n=$(areas_ids "$tx" | grep -c .)
  (( n > 0 )) || return 1
  echo "$n"
  areas_lista "$tx" | cut -f2
}

# Áreas de trabalho da sessão = as do kwinrc (quantidade e nomes). Só age se o KWin responde no D-Bus;
# nunca remove a última área, e o KWin leva as janelas de uma área removida para a vizinha.
# Os nomes desejados são lidos ANTES de criar ou remover áreas: o KWin reescreve o kwinrc ao criar uma
# (com "Área de trabalho N"), e lidos depois só as primeiras ficavam com o nome certo. Área sem nome no
# kwinrc (o original devolvido pelo "off") recebe o nome que tinha antes do tema, guardado na marca.
areas_sincronizar() {
  local alvo atual i nome
  alvo=$(kreadconfig6 --file kwinrc --group Desktops --key Number)
  # Sem Number no kwinrc (o original não dizia): a quantidade de antes do tema, guardada na marca.
  [[ -n $alvo ]] || alvo=$(head -1 "$areas_marca" 2>/dev/null || true)
  [[ $alvo =~ ^[0-9]+$ ]] && (( alvo >= 1 && alvo <= 20 )) || return 0
  local -a nomes=()
  for (( i = 1; i <= alvo; i++ )); do
    nome=$(kreadconfig6 --file kwinrc --group Desktops --key "Name_$i")
    [[ -n $nome ]] || nome=$(sed -n "$(( i + 1 ))p" "$areas_marca" 2>/dev/null || true)
    nomes+=("$nome")
  done
  atual=$(areas_texto) || return 0
  local -a ids=()
  mapfile -t ids < <(areas_ids "$atual")
  (( ${#ids[@]} )) || return 0
  for (( i = ${#ids[@]}; i < alvo; i++ )); do
    gdbus call --session --dest org.kde.KWin --object-path /VirtualDesktopManager \
      --method org.kde.KWin.VirtualDesktopManager.createDesktop "$i" "${nomes[i]}" >/dev/null 2>&1 || true
  done
  for (( i = ${#ids[@]}; i > alvo && i > 1; i-- )); do
    gdbus call --session --dest org.kde.KWin --object-path /VirtualDesktopManager \
      --method org.kde.KWin.VirtualDesktopManager.removeDesktop "${ids[i-1]}" >/dev/null 2>&1 || true
  done
  # Os ids das áreas novas só existem agora; os nomes já estavam lidos.
  atual=$(areas_texto) || return 0
  mapfile -t ids < <(areas_ids "$atual")
  for (( i = 0; i < ${#ids[@]} && i < alvo; i++ )); do
    [[ -n ${nomes[i]} ]] || continue
    gdbus call --session --dest org.kde.KWin --object-path /VirtualDesktopManager \
      --method org.kde.KWin.VirtualDesktopManager.setDesktopName "${ids[i]}" "${nomes[i]}" >/dev/null 2>&1 || true
  done
}

# O "off" já devolveu as chaves; falta a sessão aberta segui-las (as áreas, só se o tema as mudou).
off_kwin-extras() {
  kx_recarregar
  rm -f -- "$areas_marca"
}

# Grava a escolha e, com a fase ligada, aplica como ela; senão, avisa que vale no próximo "on".
kx_aplicar_agora() {  # função-de-aplicar...
  if tema_ligado; then
    local f
    for f in "$@"; do (fase_atual=kwin-extras; "$f"); done
    kx_recarregar
    return 0
  fi
  return 1
}
kx_responder() {  # id estado-json avisos...
  local id=$1 estado=$2
  shift 2
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"%s",%s,"avisos":%s}\n' "$id" "${corpo%\}}" "$(json_list_str "$@")" >&3
  else
    echo "$id: $estado"
    local a
    for a in "$@"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}
kx_aviso_desligado() { t "O tema está desligado: a escolha foi guardada e vale no próximo cyberkde on." "The theme is off: the choice was saved and applies on the next cyberkde on."; }

# ------------------------------------------------------------------ movimento
efeito_estado_movimento() {
  printf '{"nivel":"%s","fator":%s}' "$(movimento_nivel)" \
    "$(json_str "$(kreadconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor --default 1)")"
}
efeito_json_movimento() {
  printf '{"id":"movimento","grupo":"sistema","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"nivel","nome":"Nível","nome_en":"Level","tipo":"escolha","padrao":"completo","valores":[%s,%s,%s]}],"estado":%s}' \
    "$(json_str "Movimento")" "$(json_str "Motion")" \
    "$(json_str "Completo: todas as animações. Reduzido: só dissoluções curtas, sem varredura, glitch nem cascata. Mínimo: sem animação.")" \
    "$(json_str "Full: every animation. Reduced: only short fades, no scan, glitch or cascade. Minimal: no animation.")" \
    '{"id":"completo","nome":"Completo","nome_en":"Full"}' '{"id":"reduzido","nome":"Reduzido","nome_en":"Reduced"}' \
    '{"id":"minimo","nome":"Mínimo","nome_en":"Minimal"}' "$(efeito_estado_movimento)"
}
#   cyberkde efeito movimento [completo|reduzido|minimo] [--json]
efeito_cmd_movimento() {
  local nivel="" arg
  for arg in "$@"; do
    case $arg in completo | reduzido | minimo) nivel=$arg ;; *) nivel=invalido ;; esac
  done
  [[ $nivel != invalido ]] || cor_exit 2 "$(t "uso: cyberkde efeito movimento [completo|reduzido|minimo] [--json]" "usage: cyberkde efeito movimento [completo|reduzido|minimo] [--json]")"
  local -a avisos=()
  if [[ -n $nivel ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    kx_gravar movimento nivel "$nivel"
    if tema_ligado; then
      (fase_atual=kwin-extras; kx_movimento_aplicar)
      # Os efeitos do tema que obedecem ao nível regravam a própria configuração, como as fases deles.
      if fase_ligada janelas; then (fase_atual=janelas; efeito_janelas_aplicar); janelas_recarregar_efeito; fi
      if fase_ligada konsole-anim; then (fase_atual=konsole-anim; efeitos_konsole_aplicar); fi
      kx_recarregar
    else
      avisos+=("$(kx_aviso_desligado)")
    fi
  fi
  kx_responder movimento "$(efeito_estado_movimento)" "${avisos[@]}"
}

# ------------------------------------------------------------------ liga/desliga (modal, clique)
kx_estado_liga() {  # grupo padrão
  printf '{"ligado":%s,"escolhido":%s}' "$(kx_bool "$(kx_pref "$1" ligado "$2")")" "$(kx_tem "$1" && echo true || echo false)"
}
kx_cmd_liga() {  # id padrão função-de-aplicar args...
  local id=$1 padrao=$2 aplicar=$3 acao="" arg
  shift 3
  for arg in "$@"; do case $arg in on | off) acao=$arg ;; *) acao=invalida ;; esac; done
  [[ $acao != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito $id [on|off] [--json]" "usage: cyberkde efeito $id [on|off] [--json]")"
  local -a avisos=()
  if [[ -n $acao ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    kx_gravar "$id" ligado "$([[ $acao == on ]] && echo true || echo false)"
    kx_aplicar_agora "$aplicar" || avisos+=("$(kx_aviso_desligado)")
  fi
  if [[ $id == clique && $(kx_pref clique ligado false) == true ]]; then
    avisos+=("$(t "Os anéis aparecem depois do atalho Meta+* (Alternar efeito de clique do mouse): o KWin não tem opção para começar já ativo." "The rings show after the Meta+* shortcut (Toggle Mouse Click Effect): KWin has no option to start active.")")
  fi
  kx_responder "$id" "$(kx_estado_liga "$id" "$padrao")" "${avisos[@]}"
}

efeito_estado_modal-escurecer() { kx_estado_liga modal-escurecer true; }
efeito_json_modal-escurecer() {
  printf '{"id":"modal-escurecer","grupo":"janelas","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"liga","opcoes":[],"estado":%s}' \
    "$(json_str "Escurecer atrás de diálogos")" "$(json_str "Dim behind dialogs")" \
    "$(json_str "A janela-mãe escurece enquanto um diálogo modal está aberto, e a tela escurece num pedido de senha. Efeito do próprio KWin (sem opção de cor).")" \
    "$(json_str "The parent window dims while a modal dialog is open, and the screen dims for a password prompt. A built-in KWin effect (no color option).")" \
    "$(efeito_estado_modal-escurecer)"
}
efeito_cmd_modal-escurecer() { kx_cmd_liga modal-escurecer true kx_modal_aplicar "$@"; }

efeito_estado_clique() { kx_estado_liga clique false; }
efeito_json_clique() {
  printf '{"id":"clique","grupo":"interface","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"liga","opcoes":[],"estado":%s}' \
    "$(json_str "Anel no clique")" "$(json_str "Click rings")" \
    "$(json_str "Anéis finos no ponto do clique, nas cores do tema (destaque, secundária e alerta para os três botões). Alterna com Meta+*.")" \
    "$(json_str "Thin rings where you click, in the theme colors (accent, secondary and alert for the three buttons). Toggle with Meta+*.")" \
    "$(efeito_estado_clique)"
}
efeito_cmd_clique() { kx_cmd_liga clique false kx_clique_aplicar "$@"; }

# ------------------------------------------------------------------ áreas de trabalho
efeito_estado_areas() {
  local n
  n=$(kx_pref areas numero 0)
  [[ $n == 4 || $n == 6 ]] || n=0
  printf '{"numero":%d,"nomes":"%s","ligado":%s,"atual":%s}' "$n" "$(kx_pref areas nomes cyber)" \
    "$([[ $n != 0 ]] && echo true || echo false)" \
    "$(kreadconfig6 --file kwinrc --group Desktops --key Number --default 1 | tr -cd '0-9' | sed 's/^$/1/')"
}
efeito_json_areas() {
  printf '{"id":"areas","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"numero","nome":"Áreas","nome_en":"Desktops","tipo":"escolha","padrao":"off","valores":[{"id":"off","nome":"Como estão","nome_en":"As they are"},{"id":"4","nome":"4 áreas","nome_en":"4 desktops"},{"id":"6","nome":"6 áreas","nome_en":"6 desktops"}]},{"id":"nomes","nome":"Nomes","nome_en":"Names","tipo":"escolha","padrao":"cyber","valores":[{"id":"cyber","nome":"Códigos (SYS.01 TRABALHO)","nome_en":"Codes (SYS.01 TRABALHO)"},{"id":"simples","nome":"Simples (Trabalho)","nome_en":"Plain (Trabalho)"}]}],"estado":%s}' \
    "$(json_str "Áreas de trabalho como módulos")" "$(json_str "Desktops as modules")" \
    "$(json_str "Áreas de trabalho virtuais nomeadas com código técnico, como os módulos da interface. Off devolve as de antes.")" \
    "$(json_str "Virtual desktops named with technical codes, like the interface modules. Off brings back the previous ones.")" \
    "$(efeito_estado_areas)"
}
#   cyberkde efeito areas [off|4|6] [--nomes cyber|simples] [--json]
efeito_cmd_areas() {
  local n="" nomes="" arg
  while (( $# )); do
    arg=$1; shift
    case $arg in
      off | 4 | 6) n=$arg ;;
      --nomes) nomes=${1:-}; shift || true; [[ $nomes == cyber || $nomes == simples ]] || n=invalido ;;
      *) n=invalido ;;
    esac
  done
  [[ $n != invalido ]] || cor_exit 2 "$(t "uso: cyberkde efeito areas [off|4|6] [--nomes cyber|simples] [--json]" "usage: cyberkde efeito areas [off|4|6] [--nomes cyber|simples] [--json]")"
  local -a avisos=()
  if [[ -n $n$nomes ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    [[ -z $n ]] || kx_gravar areas numero "$([[ $n == off ]] && echo 0 || echo "$n")"
    [[ -z $nomes ]] || kx_gravar areas nomes "$nomes"
    kx_aplicar_agora kx_areas_aplicar || avisos+=("$(kx_aviso_desligado)")
  fi
  kx_responder areas "$(efeito_estado_areas)" "${avisos[@]}"
}
