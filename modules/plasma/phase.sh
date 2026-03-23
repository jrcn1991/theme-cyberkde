# modules/plasma/phase.sh — tema de área de trabalho "CyberKDE" (painel, menu iniciar, popups,
# dicas, notificações) + efeito KWin "cyberkde_popups" (popups, menus e notificações animados).
# Carregado com `source` pelo scripts/cyberkde: só define funções e registra nomes.
CYBERKDE_PHASES+=(plasma)
CYBERKDE_INSTALLS+=(install_plasma)
CYBERKDE_OFF_HOOKS+=(off_plasma)

# Gera o tema e o efeito (modules/plasma/build/) e copia para ~/.local/share. Não ativa nada.
install_plasma() {
  local mod="$project/modules/plasma"
  python3 "$mod/generator/gen_plasma.py" >/dev/null
  mkdir -p "$data/plasma/desktoptheme" "$data/kwin/effects"
  swap_dir "$mod/build/desktoptheme/CyberKDE" "$data/plasma/desktoptheme/CyberKDE"
  swap_dir "$mod/build/kwin-effect/cyberkde_popups" "$data/kwin/effects/cyberkde_popups"
  swap_dir "$mod/build/kwin-effect/cyberkde_barra" "$data/kwin/effects/cyberkde_barra"
  # Painel com a moldura CyberKDE no arranjo das capturas ("cyberkde layout tema", o padrão das
  # instalações novas). Com "manter", a barra continua com a moldura do tema anterior.
  # CYBERKDE_PAINEL=cyberkde|original força um dos dois.
  local painel=${CYBERKDE_PAINEL:-}
  if [[ -z $painel ]]; then if layout_tema; then painel=cyberkde; else painel=original; fi; fi
  if [[ $painel == original ]]; then plasma_keep_original_panel; fi
  # Cache de renderização só deste tema; o Plasma o refaz na próxima leitura.
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_CyberKDE*.kcache
  mkdir -p "$state"
  touch "$state/plasma-tema-instalado"  # plasma_restart_latte: Latte mais antigo que isto relê o tema
}

# Troca a moldura de painel (widgets/panel-background e as variantes translucent/opaque/solid) do tema
# instalado pela do tema anterior, lido do registro do "on" ou do plasmarc atual. Se o original
# não tem moldura própria, tirar a nossa faz o CyberKDE cair no mesmo tema padrão que ele usava.
# O Latte Dock carrega o tema do Plasma e os ícones só ao iniciar: sem reiniciar, o menu do dock
# (Kickoff) continua com o tema de antes. Só reinicia se ele estiver rodando. Ele sobe num serviço
# próprio do systemd, então não herda o terminal, a trava nem as saídas deste script (quem lê o
# stdout até o fim não fica preso).
#
# Outros programas podem reiniciar o Latte por conta própria, às vezes numa unit transitória do
# systemd. Por isso:
# - a unit é descoberta pelo cgroup do processo (não se supõe a de autostart);
# - um Latte que subiu depois da instalação dos arquivos do tema não é reiniciado;
# - no fim, se dois reinícios se cruzaram, fica só o Latte mais novo.
plasma_restart_latte() {
  local autostart='app-org.kde.latte\x2ddock@autostart.service'
  local stamp="$state/plasma-tema-instalado" pid unit started i bin
  # Capturas e testes num KWin virtual: o Latte que o pgrep acharia é o da sessão real.
  [[ -z ${CYBERKDE_CENA:-} ]] || return 0
  pid=$(pgrep -x latte-dock-ng | head -1 || true)
  [[ -n $pid ]] || return 0
  # O binário é o do processo em execução, onde quer que esteja instalado.
  bin=$(readlink -f "/proc/$pid/exe" 2>/dev/null || command -v latte-dock-ng || echo latte-dock-ng)
  if [[ -e $stamp ]]; then
    started=$(( $(date +%s) - $(ps -o etimes= -p "$pid" | tr -d ' ') ))
    if (( started > $(stat -c %Y "$stamp") )); then return 0; fi
  fi
  unit=$(sed -n 's|^0::.*/||p' "/proc/$pid/cgroup")
  if [[ $unit == *.service && $(systemctl --user show -p Transient --value "$unit" 2>/dev/null) == no ]]; then
    systemctl --user restart "$unit" || true
  else
    # Unit transitória (systemd-run), scope ou desconhecida: para, espera sair e recria com o mesmo
    # nome, se for serviço; senão, sobe pelo autostart.
    if [[ $unit == *.service ]]; then systemctl --user stop "$unit" 2>/dev/null || true; fi
    pkill -x latte-dock-ng 2>/dev/null || true
    for i in {1..50}; do
      pgrep -x latte-dock-ng >/dev/null || break
      sleep 0.1
    done
    pkill -9 -x latte-dock-ng 2>/dev/null || true
    # 9>&-: por garantia. Quem cria o processo aqui é o systemd, que não herda os nossos
    # descritores, mas se algum dia isto virar um spawn direto a trava vazaria (ver sem_travas).
    if [[ $unit == *.service ]] && systemd-run --user --quiet --unit="${unit%.service}" "$bin" >/dev/null 2>&1 9>&-; then
      :
    elif ! systemctl --user start "$autostart" 2>/dev/null; then
      systemd-run --user --quiet --collect --unit="latte-dock-ng-$(date +%s)" "$bin" >/dev/null 2>&1 9>&- || true
    fi
  fi
  # Dois reinícios cruzados deixariam dois docks: fica só o mais novo.
  sleep 2
  local -a pids
  mapfile -t pids < <(ps -o pid= --sort=start_time -C latte-dock-ng | tr -d ' ')
  if (( ${#pids[@]} > 1 )); then
    kill "${pids[@]:0:${#pids[@]}-1}" 2>/dev/null || true
  fi
  # Todo passo acima termina em "|| true": sem esta conferência, uma falha some sem mensagem e a
  # usuário só descobre que perdeu o dock olhando para a tela.
  for i in {1..20}; do
    if pgrep -x latte-dock-ng >/dev/null; then return 0; fi
    sleep 0.25
  done
  systemctl --user start "$autostart" >/dev/null 2>&1 || true
  sleep 1
  if ! pgrep -x latte-dock-ng >/dev/null; then
    echo "Aviso: o Latte Dock não voltou depois do reinício. Rode:" \
      "systemctl --user start '$autostart'" >&2
  fi
}

# Menus do Latte com borda de baixo. O CompactApplet.qml do Latte NG tira a borda do lado do dock
# (AtPanelEdges, como nos painéis do Plasma), mas o menu aparece flutuando acima do dock, com um
# vão, e fica sem borda embaixo. A cópia instalada é ajustada para tirar a borda só na borda da
# tela. O original fica guardado (put_file) e volta no off. O Latte relê o arquivo ao reiniciar.
plasma_latte_popups() {
  local qml="$data/plasma/shells/org.kde.latte.shell/contents/applet/CompactApplet.qml"
  local from=': PlasmaCore.AppletPopup.AtScreenEdges | PlasmaCore.AppletPopup.AtPanelEdges'
  [[ -f $qml ]] || return 0
  if grep -qF -- "$from" "$qml"; then
    sed "s/$from/: PlasmaCore.AppletPopup.AtScreenEdges \/\/ CyberKDE: sem AtPanelEdges (menu flutua acima do dock)/" "$qml" |
      put_file "$qml"
  elif ! grep -qF 'CyberKDE: sem AtPanelEdges' "$qml"; then
    echo "plasma: o CompactApplet.qml do Latte mudou; os menus do dock ficam como estão." >&2
  fi
}

plasma_keep_original_panel() {
  local theme_dir="$data/plasma/desktoptheme/CyberKDE" orig="" dir f
  [[ -f $ledger ]] && orig=$(awk -F'\t' '$1 == "plasmarc" && $2 == "Theme" && $3 == "name" {print $4}' "$ledger")
  [[ -z $orig ]] && orig=$(kreadconfig6 --file plasmarc --group Theme --key name --default default)
  [[ $orig == "$absent" || $orig == CyberKDE ]] && orig=default
  find "$theme_dir" -path '*widgets/panel-background.*' -delete
  for dir in "$data/plasma/desktoptheme/$orig" "/usr/share/plasma/desktoptheme/$orig"; do
    [[ -d $dir ]] || continue
    while IFS= read -r f; do
      install -Dm644 "$dir/$f" "$theme_dir/$f"
    done < <(cd "$dir" && find . -path '*widgets/panel-background.*')
    break
  done
  # Filete neon (opção 1 da barra, escolhida em 14/09): linha na cor de destaque na borda de baixo,
  # desenhada pela própria moldura. Para a moldura original pura: CYBERKDE_FILETE=nao cyberkde on
  if [[ ${CYBERKDE_FILETE:-sim} != nao ]]; then
    for f in "$theme_dir"/widgets/panel-background.svg*; do
      if [[ -f $f ]]; then python3 "$project/modules/plasma/generator/panel_filete.py" "$f" "$(accent_color)"; fi
    done
  fi
}

phase_plasma() {
  set_key plasmarc Theme name CyberKDE
  # Os efeitos de popup do sistema animariam as mesmas janelas: desliga os dois e liga o nosso.
  set_key kwinrc Plugins fadingpopupsEnabled false
  set_key kwinrc Plugins slidingpopupsEnabled false
  set_key kwinrc Plugins cyberkde_popupsEnabled true
  # Barra superior "filete neon" (efeito cyberkde_barra): DESLIGADO desde 14/09 20:24.
  # Aplicado nas barras recriadas pelo reinício do plasmashell, o shader permanente (set) congelou a
  # imagem delas: relógio parado, bandeja pela metade, uma barra vazia. Só volta depois de corrigido.
  set_key kwinrc Plugins cyberkde_barraEnabled false
  plasma_latte_popups
  plasma_notify_theme
  plasma_reload_effects
  plasma_restart_latte
}

# O "off" já devolveu plasmarc e kwinrc aos valores originais; aqui só se avisa quem está rodando.
off_plasma() {
  # Pedido do contrato. Porém, com o plasmarc já restaurado, esta ferramenta responde que o tema
  # "já está definido" e não faz nada. Por isso o aviso do plasma_notify_theme vem logo depois.
  plasma-apply-desktoptheme "$(kreadconfig6 --file plasmarc --group Theme --key name --default default)" >/dev/null 2>&1 || true
  touch "$state/plasma-tema-instalado"  # o tema mudou: o Latte precisa reler
  plasma_notify_theme
  plasma_reload_effects
  plasma_restart_latte
}

# O set_key grava sem --notify, e o Plasma (plasmashell e Latte Dock) só troca o tema em execução
# ao receber o aviso do KConfigWatcher. Emite o mesmo sinal que o kwriteconfig6 --notify emitiria:
# grupo "Theme", chave "name" (bytes sem o \0 final).
plasma_notify_theme() {
  gdbus emit --session --object-path /kconfig/plasmarc \
    --signal org.kde.kconfig.notify.ConfigChanged \
    "{'Theme': [[byte 0x6e, 0x61, 0x6d, 0x65]]}" >/dev/null 2>&1 || true
}

# Carrega ou descarrega os três efeitos conforme o kwinrc atual. O "reconfigure" sozinho não
# descarrega um efeito quando a chave some. O nosso é sempre recarregado, para pegar os arquivos novos.
plasma_reload_effects() {
  local id default
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  for id in fadingpopups slidingpopups cyberkde_popups cyberkde_barra; do
    default=true
    [[ $id == cyberkde_* ]] && default=false
    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$id" >/dev/null 2>&1 || true
    if [[ $(kreadconfig6 --file kwinrc --group Plugins --key "${id}Enabled" --default "$default") == true ]]; then
      qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$id" >/dev/null 2>&1 || true
    fi
  done
}
