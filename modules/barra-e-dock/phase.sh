# modules/barra-e-dock/phase.sh — o arranjo das capturas: barra do Plasma em cima (bandeja, relógio,
# mostrar área de trabalho) e uma dock no centro de baixo (menu, gerenciador de arquivos, Obsidian se
# houver, navegador, Konsole).
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# A dock é o Latte Dock quando ele está instalado ("cyberkde latte" compila de um commit revisado);
# sem ele, um painel flutuante do próprio Plasma.
#
# Só age com a preferência "tema" (~/.config/cyberkde/layout, comando "cyberkde layout"). Instalações
# novas começam com "tema"; quem já usava o CyberKDE antes desta fase começa com "manter", e a barra e
# a dock continuam como estão.
#
# Reversão: o plasma-org.kde.plasma.desktop-appletsrc (painéis do Plasma) é copiado antes da primeira
# mudança e volta no "off" com o plasmashell parado. As configurações do Latte e o autostart passam
# pelo put_file, então o "off" devolve os originais. Um Latte que o tema ligou é desligado no "off".

CYBERKDE_PHASES+=(barra-e-dock)
descreve_fase barra-e-dock "Barra e dock" sistema nao "Barra fina em cima e dock embaixo, como nas capturas (cyberkde layout tema)." \
  "Bar and dock" "Thin bar on top and dock at the bottom, as in the screenshots (cyberkde layout tema)."
CYBERKDE_INSTALLS+=(install_barra-e-dock)
CYBERKDE_PRE_OFF_HOOKS+=(pre_off_barra-e-dock)
CYBERKDE_OFF_HOOKS+=(off_barra-e-dock)

layout_file="$config/cyberkde/layout"
appletsrc="$config/plasma-org.kde.plasma.desktop-appletsrc"
appletsrc_orig="$state/appletsrc.orig"
# Espessura, flutuação e tamanho de cada painel ficam no plasmashellrc ([PlasmaViews][Panel N]), não no
# appletsrc: sem guardar os dois, o "off" devolvia o painel original sem flutuar e com a espessura da
# barra do tema (33 px em vez de 46). Guardado junto, na primeira aplicação. Instalações antigas (só o
# appletsrc.orig) não têm a cópia: o "off" delas devolve só o appletsrc, como antes.
plasmashellrc="$config/plasmashellrc"
plasmashellrc_orig="$state/plasmashellrc.orig"
latte_iniciado="$state/latte-iniciado-pelo-tema"
dock_plasma_id="$state/dock-plasma-id"
menu_icon="$data/cyberkde/menu.svg"            # dock: blocos sobre fundo escuro
menu_icon_barra="$data/cyberkde/menu-barra.svg" # barra: só os blocos, ocupando o ícone (fica maior em 33 px)

# Versão do arranjo da barra: sobe quando a barra do tema muda, para quem atualiza o tema recebê-la
# (a barra é montada só na primeira aplicação; o original guardado para o off não muda).
barra_versao=5  # 3: sem o menu global (appmenu); 4: barra em todas as telas; 5: ícone do menu da barra
barra_versao_file="$state/barra-versao"

# Presets de layout ("cyberkde layout", catálogo L3):
#   tema        barra em cima em todas as telas + dock embaixo (o Latte em todas as telas)
#   duas-telas  barra em todas as telas + dock só na tela principal
#   compacto    só a barra de cima, com as tarefas dentro dela (sem dock)
#   lateral     um painel vertical de 56 px à esquerda (menu, tarefas, bandeja, relógio), sem dock
#   manter      barra e dock como estão (o tema não monta nada)
layout_presets=(tema duas-telas compacto lateral)
layout_preset() {
  local v
  v=$(cat "$layout_file" 2>/dev/null || true)
  if [[ " ${layout_presets[*]} " == *" $v "* ]]; then echo "$v"; else echo manter; fi
}
layout_tema() { [[ $(layout_preset) != manter ]]; }  # algum preset do tema (não "manter")
layout_com_dock() { [[ $(layout_preset) == tema || $(layout_preset) == duas-telas ]]; }
barra_montagem_file="$state/barra-montagem"  # "preset plugin-do-menu" com que a barra foi montada

# ------------------------------------------------------------------ opções da dock e do menu
# Preferências em ~/.config/cyberkde/efeitos ("cyberkde efeito dock" e "efeito menu"). Valem no Latte
# (chaves conferidas no código do Latte Dock NG):
#   [Containments][1][Indicator][org.kde.latte.default] activeStyle  0 = linha, 1 = ponto
#   [Containments][1][General] zoomLevel                              0 = sem zoom (o tema usa 12)
#   animationLauncherBouncing (containment e tarefas)                 o ícone pula ao abrir o app
# No painel do Plasma não há equivalente: o indicador vem do tema do Plasma (widgets/tasks), não há
# zoom e o retorno de lançamento é do sistema todo (klaunchrc). Lá, só o menu muda.
# Menu (catálogo L5): lista ou grade = Kickoff com applicationsDisplay/favoritesDisplay 1/0 (conferido
# no plugin do Plasma 6.6); tela cheia = o plasmoide org.kde.plasma.kickerdash no lugar do Kickoff.
dock_pref() { kreadconfig6 --file "$efeitos_file" --group dock --key "$1" --default "$2" 2>/dev/null; }
menu_modo() {
  local m
  m=$(kreadconfig6 --file "$efeitos_file" --group menu --key modo --default padrao 2>/dev/null)
  case $m in lista | grade | tela-cheia) echo "$m" ;; *) echo padrao ;; esac
}
menu_plugin() { [[ $(menu_modo) == tela-cheia ]] && echo org.kde.plasma.kickerdash || echo org.kde.plasma.kickoff; }
# JavaScript do Plasma que acrescenta o menu ao painel "var" (com ícone e modo de exibição).
menu_widget_js() {  # variável-do-painel dock|barra
  local js="var k = $1.addWidget('$(menu_plugin)'); k.currentConfigGroup = ['General']; k.writeConfig('icon', '$(menu_icone "$2")');"
  case $(menu_modo) in
    lista) js+=" k.writeConfig('applicationsDisplay', 1); k.writeConfig('favoritesDisplay', 1);" ;;
    grade) js+=" k.writeConfig('applicationsDisplay', 0); k.writeConfig('favoritesDisplay', 0);" ;;
  esac
  printf '%s' "$js"
}

# Ligada também pelo estado próprio: os painéis guardados, a dock do Plasma criada, o Latte ligado.
ligada_barra-e-dock() { [[ -e $appletsrc_orig || -s $dock_plasma_id || -e $latte_iniciado ]]; }

# Ícones do menu (generator/gen_menu.py): os blocos do tema na cor de destaque, ou o logo da
# corporação ("cyberkde corp"). Vão para o hicolor do usuário com um nome que muda com o conteúdo, e o
# Kickoff aponta para o NOME: o QIcon escolhe o tamanho, e um logo raster sai em PNGs reduzidos com
# Lanczos (apontar para um SVG com o PNG embutido deixava o ícone serrilhado).
menu_icones_file="$data/cyberkde/menu-icones"   # nome do ícone da dock (linha 1) e da barra (linha 2)
menu_hicolor="$data/icons/hicolor"
install_barra-e-dock() {
  python3 "$project/modules/barra-e-dock/generator/gen_menu.py" "$project/generator" "$(dirname -- "$menu_icon")" \
    "$menu_hicolor" "$(corp_logo "$(corp_atual)")"
}

# Ícone do menu para o Kickoff: o nome gerado pelo install_barra-e-dock; sem ele (instalação de uma
# versão anterior), o caminho do SVG.
menu_icone() {  # dock|barra
  local linha=1 svg=$menu_icon
  if [[ $1 == barra ]]; then linha=2 svg=$menu_icon_barra; fi
  local nome
  nome=$(sed -n "${linha}p" "$menu_icones_file" 2>/dev/null || true)
  printf '%s\n' "${nome:-$svg}"
}

# Os Kickoffs que o tema configurou (ícone com um caminho ou nome do tema) passam para o ícone atual. A
# barra e a dock do Plasma são montadas só na primeira aplicação; sem isto, uma troca de corporação
# (ou a passagem do SVG para o ícone com nome) não chegaria a elas. Um Kickoff com outro ícone,
# escolhido pela pessoa, fica como está.
menu_kickoffs_atualizar() {
  plasma_js "
    var dock = '$(menu_icone dock)', barra = '$(menu_icone barra)';
    var modo = $(case $(menu_modo) in lista) echo 1 ;; grade) echo 0 ;; *) echo -1 ;; esac);
    var p = panels();
    for (var i = 0; i < p.length; i++) {
      var w = p[i].widgets('org.kde.plasma.kickoff').concat(p[i].widgets('org.kde.plasma.kickerdash'));
      for (var j = 0; j < w.length; j++) {
        w[j].currentConfigGroup = ['General'];
        var ic = String(w[j].readConfig('icon', ''));
        var nosso = true;
        if (ic == '$menu_icon_barra' || /^cyberkde-menu-barra-[0-9a-f]+\$/.test(ic)) { if (ic != barra) w[j].writeConfig('icon', barra); }
        else if (ic == '$menu_icon' || /^cyberkde-menu-[0-9a-f]+\$/.test(ic)) { if (ic != dock) w[j].writeConfig('icon', dock); }
        else nosso = false;
        // Lista ou grade (cyberkde efeito menu), só nos menus do tema e só no Kickoff.
        if (nosso && modo >= 0 && w[j].type == 'org.kde.plasma.kickoff') {
          w[j].writeConfig('applicationsDisplay', modo); w[j].writeConfig('favoritesDisplay', modo);
        }
      }
    }
  " >/dev/null
}

# Lançadores da dock, só com o que existe na máquina.
dock_launchers() {
  local -a l=(preferred://filemanager)
  local d browser=${CYBERKDE_NAVEGADOR:-}
  for d in "$data/applications" /usr/share/applications /var/lib/flatpak/exports/share/applications \
    "$data/flatpak/exports/share/applications"; do
    if [[ -f $d/obsidian.desktop ]]; then l+=(applications:obsidian.desktop); break; fi
    if [[ -f $d/md.obsidian.Obsidian.desktop ]]; then l+=(applications:md.obsidian.Obsidian.desktop); break; fi
  done
  [[ -n $browser ]] || browser=$(xdg-settings get default-web-browser 2>/dev/null || true)
  if [[ -n $browser ]]; then l+=("applications:$browser"); else l+=(preferred://browser); fi
  l+=(applications:org.kde.konsole.desktop)
  local IFS=,
  echo "${l[*]}"
}

# CYBERKDE_DOCK=plasma: dock do Plasma mesmo com o Latte instalado (as capturas usam, para mostrar o
# que uma instalação nova recebe).
latte_bin() {
  [[ ${CYBERKDE_DOCK:-} != plasma ]] || return 0
  latte_instalado
}
# Binário do Latte instalado, também em ~/.local/bin fora do PATH (o "cyberkde latte" instala ali).
latte_instalado() {
  command -v latte-dock-ng || command -v latte-dock ||
    { [[ -x $HOME/.local/bin/latte-dock-ng ]] && echo "$HOME/.local/bin/latte-dock-ng"; } || true
}

# Processos do Latte desta sessão gráfica (a das capturas roda outro Latte, num monitor virtual).
latte_pids() {
  local pid wd=${WAYLAND_DISPLAY:-wayland-0} env
  for pid in $(pgrep -x latte-dock-ng; pgrep -x latte-dock); do
    if env=$(tr '\0' '\n' 2>/dev/null <"/proc/$pid/environ"); then
      grep -qxF "WAYLAND_DISPLAY=$wd" <<<"$env" && echo "$pid"
    elif [[ -z ${CYBERKDE_CENA:-} ]]; then
      echo "$pid"  # ambiente ilegível: numa sessão normal, só pode ser o Latte desta sessão
    fi
  done
  return 0
}

# A dock do Latte está na tela? Um script do KWin conta as janelas "dock" do Latte e imprime no log
# (o jornal do systemd). Saída: 0 visível · 1 Latte sem dock na tela · 2 não deu para saber.
latte_visivel() {
  [[ -z ${CYBERKDE_CENA:-} ]] || return 2  # na cena, o log do KWin não vai para o jornal
  command -v journalctl >/dev/null || return 2
  local js marca n id since
  js=$(mktemp --suffix=.js)
  marca="CYBERKDE-LATTE-$$-$RANDOM"
  printf 'var n = 0;\nfor (const w of workspace.windowList()) if (w.dock && String(w.resourceClass).indexOf("latte") !== -1 && !w.hidden) n++;\nprint("%s " + n);\n' "$marca" >"$js"
  since=$(date '+%Y-%m-%d %H:%M:%S')
  id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$js" cyberkde-latte-visivel 2>/dev/null) || { rm -f "$js"; return 2; }
  qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1 || true
  sleep 1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript cyberkde-latte-visivel >/dev/null 2>&1 || true
  rm -f "$js"
  n=$(journalctl --user --since "$since" -o cat 2>/dev/null | sed -n "s/.*$marca \([0-9]*\).*/\1/p" | tail -1)
  [[ -n $n ]] || return 2
  if (( n > 0 )); then return 0; fi
  return 1
}

# Liga o Latte e confere se a dock apareceu. Na primeira partida (configuração recém-criada), às vezes
# o processo sobe e a dock não aparece; um reinício resolve.
latte_start_conferido() {
  local i tentativa r
  for tentativa in 1 2; do
    latte_start
    for i in {1..40}; do
      qdbus6 org.kde.lattedock /Latte >/dev/null 2>&1 && break
      sleep 0.25
    done
    sleep 3
    r=0
    latte_visivel || r=$?
    (( r == 1 )) || return 0
    echo "  (o Latte subiu sem mostrar a dock; reiniciando)"
    latte_stop
  done
  latte_start
}

latte_start() {
  local bin
  bin=$(latte_bin)
  if [[ -n ${CYBERKDE_CENA:-} ]]; then
    # Capturas: processo direto na sessão D-Bus da cena, com trava própria (o Latte cria a dele em
    # TMPDIR e desiste se vê outro rodando).
    mkdir -p "$state/latte-tmp"
    TMPDIR="$state/latte-tmp" setsid "$bin" >/dev/null 2>&1 </dev/null 3>&- 4>&- 9>&- &
  elif ! systemctl --user start 'app-org.kde.latte\x2ddock@autostart.service' >/dev/null 2>&1; then
    systemd-run --user --quiet --collect --unit="latte-dock-ng-$(date +%s)" "$bin" >/dev/null 2>&1 3>&- 4>&- 9>&- || true
  fi
}

latte_stop() {
  local -a pids
  mapfile -t pids < <(latte_pids)
  (( ${#pids[@]} )) || return 0
  kill "${pids[@]}" 2>/dev/null || true
  local i
  for i in {1..40}; do
    [[ -z $(latte_pids) ]] && return 0
    sleep 0.1
  done
  kill -9 $(latte_pids) 2>/dev/null || true
}

plasma_js() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

# Barra em cima: o primeiro painel vira a barra da autora do tema, igual à da máquina dela: fina (33 px),
# colada no topo, com menu, espaçador, bandeja, busca, relógio e mostrar área de trabalho. SEM o menu
# global (appmenu): com ele, o KDE põe o appmenu-gtk-module nos módulos do GTK, os apps GTK abertos o
# carregam na hora e, quando o tema é desligado e religado, caem executando o módulo descarregado
# (segfault do xdg-desktop-portal-gtk e outros na VM, 25/09).
# O relógio fica numa linha só (data ao lado da hora, no formato padrão do idioma), com a fonte Andale
# Mono (pacote ttf-mscorefonts-installer; sem ela, o Qt usa uma parecida e o "cyberkde checar" avisa).
barra_aplicar() {
  plasma_js "
    var p = panels();
    // Uma barra por tela: em cada tela, o painel de cima (reaplicação) ou o de baixo original. A dock do
    // Plasma que o tema cria nunca é barra.
    var dock = '$(cat "$dock_plasma_id" 2>/dev/null)';
    var porTela = {};
    for (var i = 0; i < p.length; i++) {
      if (String(p[i].id) == dock) continue;
      var t = p[i].screen;
      if ((p[i].location == 'top' || p[i].location == 'left') && (!porTela[t] || porTela[t].location == 'bottom')) porTela[t] = p[i];
      else if (p[i].location == 'bottom' && !porTela[t]) porTela[t] = p[i];
    }
    var barras = [];
    for (var t in porTela) barras.push(porTela[t]);
    if (barras.length == 0) barras.push(new Panel());
    for (var b = 0; b < barras.length; b++) montar(barras[b]);
    function tarefas(bar) {
      var t = bar.addWidget('org.kde.plasma.icontasks');
      t.currentConfigGroup = ['General'];
      t.writeConfig('launchers', '$(dock_launchers)'.split(','));
    }
    function montar(bar) {
    var preset = '$(layout_preset)';
    bar.location = preset == 'lateral' ? 'left' : 'top';
    bar.height = preset == 'lateral' ? 56 : 33;
    bar.floating = false;
    var w = bar.widgets();
    for (var j = 0; j < w.length; j++) w[j].remove();
    $(menu_widget_js bar barra)
    // compacto e lateral: as tarefas ficam na própria barra (não há dock).
    if (preset == 'compacto' || preset == 'lateral') tarefas(bar);
    if (preset != 'compacto') bar.addWidget('org.kde.plasma.panelspacer');
    bar.addWidget('org.kde.plasma.systemtray');
    if (preset != 'lateral') bar.addWidget('org.kde.milou');
    var c = bar.addWidget('org.kde.plasma.digitalclock');
    c.currentConfigGroup = ['Appearance'];
    c.writeConfig('fontFamily', 'Andale Mono');
    c.writeConfig('fontStyleName', 'Regular');
    c.writeConfig('fontWeight', 400);
    c.writeConfig('dateDisplayFormat', 1);  // 1 = BesideTime (Enum: 0 Adaptive, 1 BesideTime, 2 BelowTime)
    bar.addWidget('org.kde.plasma.showdesktop');
    }
  " >/dev/null
}

# Dock do Plasma (sem Latte): painel flutuante no centro de baixo, do tamanho do conteúdo.
dock_plasma_aplicar() {
  local id launchers
  launchers=$(dock_launchers)
  id=$(plasma_js "
    var d = new Panel();
    d.location = 'bottom';
    d.height = 56;
    d.alignment = 'center';
    d.lengthMode = 'fit';
    d.floating = true;
    d.hiding = 'dodgewindows';
    $(menu_widget_js d dock)
    var t = d.addWidget('org.kde.plasma.icontasks');
    t.currentConfigGroup = ['General'];
    t.writeConfig('launchers', '$launchers'.split(','));
    print(d.id);
  ")
  printf '%s\n' "$id" >"$dock_plasma_id"
}

dock_plasma_remover() {
  [[ -s $dock_plasma_id ]] || return 0
  plasma_js "var d = panelById($(<"$dock_plasma_id")); if (d) d.remove();" >/dev/null 2>&1 || true
  rm -f -- "$dock_plasma_id"
}

dock_latte_aplicar() {
  local launchers
  launchers=$(dock_launchers)
  # O layout da pessoa também é guardado: ao religar, o Latte regrava as cópias da dock nas outras
  # telas e já trocou a ordem dos applets (menu depois das tarefas). O "off" devolve o arquivo original.
  local atual
  atual=$(kreadconfig6 --file lattedockrc --group UniversalSettings --key singleModeLayoutName 2>/dev/null || true)
  if [[ -n $atual && $atual != CyberKDE && -f $config/latte/$atual.layout.latte ]]; then
    remember_path "$config/latte/$atual.layout.latte"
  fi
  # Layout da pessoa já guardado num "on" anterior (agora o atual é o CyberKDE e o if acima não o vê):
  # passa de novo pelo remember_path, que só anota a fase, para o "off barra-e-dock" o devolver.
  local guardado
  while IFS=$'\t' read -r guardado _; do
    case $guardado in "$config/latte/"*.layout.latte) remember_path "$guardado" ;; esac
  done < <(cat -- "$files" 2>/dev/null || true)
  printf '[UniversalSettings]\nmemoryUsage=0\nshowInfoWindow=false\nsingleModeLayoutName=CyberKDE\nversion=2\n' |
    put_file "$config/lattedockrc"
  # Opções da dock ("cyberkde efeito dock") e do menu ("efeito menu"), e as telas pelo preset do layout.
  local latte_telas=1 latte_zoom=12 latte_pula=true latte_indicador=0 latte_menu_modo=""
  [[ $(layout_preset) == duas-telas ]] && latte_telas=0  # 0 = só uma tela (a principal); 1 = todas
  [[ $(dock_pref zoom on) == off ]] && latte_zoom=0
  [[ $(dock_pref lancamento on) == off ]] && latte_pula=false
  [[ $(dock_pref indicador linha) == ponto ]] && latte_indicador=1
  case $(menu_modo) in
    lista) latte_menu_modo=$'applicationsDisplay=1\nfavoritesDisplay=1' ;;
    grade) latte_menu_modo=$'applicationsDisplay=0\nfavoritesDisplay=0' ;;
  esac
  put_file "$config/latte/CyberKDE.layout.latte" <<EOF
[ActionPlugins][1]
RightButton;NoModifier=org.kde.latte.contextmenu

[Containments][1]
formfactor=2
immutability=1
location=4
name=Dock
onPrimary=true
plugin=org.kde.latte.containment
screensGroup=$latte_telas
viewType=0
visibility=0

[Containments][1][Applets][2]
immutability=1
plugin=$(menu_plugin)

[Containments][1][Applets][2][Configuration]
popupHeight=548
popupWidth=726

[Containments][1][Applets][2][Configuration][General]
icon=$(menu_icone dock)
$latte_menu_modo

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.latte.plasmoid

[Containments][1][Applets][3][Configuration][General]
isInLatteDock=true
animationLauncherBouncing=$latte_pula
launchers59=$launchers
${CYBERKDE_CENA:+showAudioBadge=false}

[Containments][1][General]
alignmentUpgraded=true
# Ajustado a olho com a autora na tela real (25/09): as bolinhas das janelas abertas ficam na margem da
# borda (o indicador do Latte NG ignora o thickMargin do indicador), então 2 px as tiram da borda; o
# fundo no mínimo (panelSize 0) deixa o filete a 10 px da borda; a faixa sob os ícones fica em 28%.
screenEdgeMargin=2
thickMargin=28
# 48 e não 44: o menu (Kickoff) arredonda o ícone para um tamanho padrão do KDE (32, 48…) e, com 44,
# ficava em 32, bem menor que os outros ícones da dock.
appletOrder=2;3
iconSize=48
panelSize=0
# Sem o fundo (moldura chanfrada) sob os ícones: só os ícones e as bolinhas das janelas abertas.
useThemePanel=false
shadowOpacity=60
shadowSize=45
shadows=All
shadowsUpgraded=true
tasksUpgraded=true
titleTooltips=false
# Zoom e animação de lançamento: "cyberkde efeito dock" (o padrão do tema é zoom 12 e pulo ligado).
zoomLevel=$latte_zoom
animationLauncherBouncing=$latte_pula

[Containments][1][Indicator]
enabled=true
type=org.kde.latte.default

[Containments][1][Indicator][org.kde.latte.default]
activeStyle=$latte_indicador


[LayoutSettings]
activities=
backgroundStyle=0
showInMenu=true
version=2
EOF
  # Autostart: o Latte volta a cada login.
  local desk
  for desk in /usr/share/applications/org.kde.latte-dock.desktop "$data/applications/org.kde.latte-dock.desktop"; do
    if [[ -f $desk ]]; then
      sed "s|^Exec=latte-dock-ng|Exec=$(latte_bin)|" "$desk" | put_file "$config/autostart/org.kde.latte-dock.desktop"
      break
    fi
  done
  # Relê o layout: um Latte que já rodava é reiniciado; um que não rodava é ligado (e desligado no off).
  if [[ -n $(latte_pids) ]]; then
    latte_stop
  else
    : >"$latte_iniciado"
  fi
  latte_start_conferido
}

phase_barra-e-dock() {
  if ! layout_tema; then
    echo "  (barra e dock: mantidas como estão; 'cyberkde layout tema' usa o arranjo das capturas)"
    return 0
  fi
  # O plasmashell pode estar reiniciando (por outro programa, ou fora do ar desde antes): espera até ~15 s
  # e, se nem o processo existe, sobe o serviço. Só desiste se mesmo assim ele não responder.
  if ! plasmashell_garantir; then
    echo "O Plasma (plasmashell) não respondeu em 15 s; a barra e a dock ficam para o próximo 'cyberkde on'." >&2
    return 1
  fi
  # Primeira vez: guarda os painéis originais e monta a barra. Depois disso (ex.: "cyberkde cor"), só
  # confere a dock.
  if [[ ! -e $appletsrc_orig ]]; then
    mkdir -p "$state"
    if [[ -f $appletsrc ]]; then cp -a -- "$appletsrc" "$appletsrc_orig"; else : >"$appletsrc_orig"; fi
    if [[ -f $plasmashellrc ]]; then cp -a -- "$plasmashellrc" "$plasmashellrc_orig"; else : >"$plasmashellrc_orig"; fi
    barra_aplicar
    echo "$barra_versao" >"$barra_versao_file"
    echo "$(layout_preset) $(menu_plugin)" >"$barra_montagem_file"
  elif (( $(cat "$barra_versao_file" 2>/dev/null || echo 1) < barra_versao )); then
    barra_aplicar  # barra de uma versão antiga do tema: remonta (o original do off continua o mesmo)
    echo "$barra_versao" >"$barra_versao_file"
    echo "$(layout_preset) $(menu_plugin)" >"$barra_montagem_file"
  fi
  # Preset ou menu em tela cheia trocados depois da montagem: só valem remontando a barra a partir dos
  # painéis guardados ("cyberkde layout <preset> --aplicar" faz o off e o on desta fase).
  local montada
  montada=$(cat "$barra_montagem_file" 2>/dev/null || echo "tema org.kde.plasma.kickoff")
  if [[ $montada != "$(layout_preset) $(menu_plugin)" ]]; then
    echo "  (barra montada como '${montada%% *}'; para valer '$(layout_preset)': cyberkde layout $(layout_preset) --aplicar)" >&2
  fi
  menu_kickoffs_atualizar
  if ! layout_com_dock; then
    dock_plasma_remover  # compacto e lateral: as tarefas ficam na barra, sem dock
  elif [[ -n $(latte_bin) ]]; then
    dock_plasma_remover  # o Latte chegou depois de uma dock do Plasma
    dock_latte_aplicar
  elif [[ ! -s $dock_plasma_id ]]; then
    dock_plasma_aplicar
  fi
}

# Antes do "off" devolver os arquivos: o Latte regrava a configuração dele ao sair, então ele para
# primeiro. O da pessoa (já rodava antes do tema) volta depois, com o layout dela.
latte_religar=""
pre_off_barra-e-dock() {
  [[ -e $latte_iniciado || -e $appletsrc_orig ]] || return 0
  if [[ -n $(latte_pids) ]]; then
    [[ -e $latte_iniciado ]] || latte_religar=1
    latte_stop
  fi
  rm -f -- "$latte_iniciado"
}

# O "off" já devolveu as configurações do Latte (put_file). Aqui: Latte da pessoa e painéis do Plasma.
off_barra-e-dock() {
  if [[ -n $latte_religar ]]; then latte_start; fi
  rm -f -- "$dock_plasma_id"
  [[ -e $appletsrc_orig ]] || return 0
  # Com o plasmashell no ar, ele regravaria o arquivo ao sair. O "off" o reinicia logo depois.
  plasmashell_parar
  if [[ -s $appletsrc_orig ]]; then
    cp -a -- "$appletsrc_orig" "$appletsrc"
  else
    rm -f -- "$appletsrc"  # não havia painéis salvos: o Plasma recria o padrão
  fi
  # Espessura e flutuação dos painéis originais (com o plasmashell parado, como o appletsrc).
  if [[ -e $plasmashellrc_orig ]]; then
    if [[ -s $plasmashellrc_orig ]]; then cp -a -- "$plasmashellrc_orig" "$plasmashellrc"; else rm -f -- "$plasmashellrc"; fi
  fi
  rm -f -- "$appletsrc_orig" "$plasmashellrc_orig" "$barra_versao_file" "$barra_montagem_file"
}

# ------------------------------------------------------------------ efeitos: layout, dock, menu
CYBERKDE_EFEITOS+=(layout dock menu)
CYBERKDE_EFEITO_GRUPO+=([layout]=area-de-trabalho [dock]=area-de-trabalho [menu]=area-de-trabalho)

# Reaplica a fase com a escolha nova, num cyberkde separado (o mesmo caminho do "on"/"off" de sempre,
# que guarda e devolve os painéis). Solta a trava antes: o filho precisa dela. "refazer" = off e on
# da fase, para remontar a barra a partir dos painéis guardados (preset novo, menu em tela cheia).
barra_reaplicar() {  # refazer|dock
  exec 9>&-
  local cli="$project/scripts/cyberkde" rc=0
  if [[ $1 == refazer ]]; then sem_travas "$cli" off barra-e-dock >&2 || rc=$?; fi
  if (( rc == 0 || rc == 4 )); then sem_travas "$cli" on barra-e-dock >&2 || rc=$?; fi
  return "$rc"
}
barra_responder() {  # id estado avisos...
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

declare -A layout_nomes=([tema]="Barra e dock" [duas-telas]="Duas telas" [compacto]="Compacto" [lateral]="Lateral" [manter]="Manter os meus painéis")
declare -A layout_nomes_en=([tema]="Bar and dock" [duas-telas]="Two screens" [compacto]="Compact" [lateral]="Side panel" [manter]="Keep my panels")
declare -A layout_desc=([tema]="Barra fina em cima em todas as telas e dock embaixo." [duas-telas]="Barra em todas as telas e a dock só na principal." \
  [compacto]="Só a barra de cima, com as janelas abertas dentro dela." [lateral]="Um painel vertical à esquerda com menu, janelas, bandeja e relógio." \
  [manter]="O tema não mexe nos painéis.")
declare -A layout_desc_en=([tema]="Thin bar on top of every screen and a dock at the bottom." [duas-telas]="Bar on every screen, dock on the main one only." \
  [compacto]="Only the top bar, with open windows inside it." [lateral]="A vertical panel on the left with menu, windows, tray and clock." \
  [manter]="The theme leaves the panels alone.")
efeito_estado_layout() {
  printf '{"preset":"%s","montado":%s,"aplicado":%s}' "$(layout_preset)" \
    "$(json_caminho "$(cut -d' ' -f1 "$barra_montagem_file" 2>/dev/null || true)")" \
    "$(fase_ligada barra-e-dock && echo true || echo false)"
}
efeito_json_layout() {
  local p valores=""
  for p in "${layout_presets[@]}" manter; do
    valores+="${valores:+,}{\"id\":\"$p\",\"nome\":$(json_str "${layout_nomes[$p]}"),\"nome_en\":$(json_str "${layout_nomes_en[$p]}"),\"descricao\":$(json_str "${layout_desc[$p]}"),\"descricao_en\":$(json_str "${layout_desc_en[$p]}")}"
  done
  printf '{"id":"layout","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"preset","nome":"Arranjo","nome_en":"Arrangement","tipo":"escolha","padrao":"tema","valores":[%s]}],"estado":%s}' \
    "$(json_str "Barra e dock")" "$(json_str "Bar and dock")" \
    "$(json_str "Onde ficam a barra, a dock e as janelas abertas. Trocar remonta os painéis a partir dos seus, guardados.")" \
    "$(json_str "Where the bar, the dock and the open windows go. Switching rebuilds the panels from your saved ones.")" \
    "$valores" "$(efeito_estado_layout)"
}
#   cyberkde efeito layout <tema|duas-telas|compacto|lateral|manter> [--json]  (= cyberkde layout <p> --aplicar)
efeito_cmd_layout() {
  local p=${1:-}
  if [[ -z $p ]]; then barra_responder layout "$(efeito_estado_layout)"; return; fi
  [[ $# == 1 && ( " ${layout_presets[*]} " == *" $p "* || $p == manter ) ]] ||
    cor_exit 2 "$(t "uso: cyberkde efeito layout [tema|duas-telas|compacto|lateral|manter] [--json]" "usage: cyberkde efeito layout [tema|duas-telas|compacto|lateral|manter] [--json]")"
  layout_trocar "$p"
}

# Grava o preset e, com a barra e a dock do tema ligadas, remonta. "manter" com a fase ligada = off
# dela (os painéis de antes voltam); um preset com o tema ligado e a fase desligada = on dela.
layout_trocar() {  # preset
  local p=$1
  local -a avisos=()
  take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
  mkdir -p -- "$(dirname -- "$layout_file")"
  echo "$p" >"$layout_file"
  if tema_ligado; then
    if [[ $p == manter ]]; then
      if fase_ligada barra-e-dock; then exec 9>&-; sem_travas "$project/scripts/cyberkde" off barra-e-dock >&2 || true; fi
    elif fase_ligada barra-e-dock; then
      barra_reaplicar refazer || avisos+=("$(t "A remontagem não terminou; rode cyberkde layout $p --aplicar de novo." "Rebuilding did not finish; run cyberkde layout $p --aplicar again.")")
    else
      barra_reaplicar dock || true
    fi
  else
    avisos+=("$(t "O tema está desligado: o arranjo vale no próximo cyberkde on." "The theme is off: the arrangement applies on the next cyberkde on.")")
  fi
  barra_responder layout "$(efeito_estado_layout)" "${avisos[@]}"
}

efeito_estado_dock() {
  local backend=nenhuma
  if layout_com_dock; then if [[ -n $(latte_bin) ]]; then backend=latte; else backend=plasma; fi; fi
  printf '{"indicador":"%s","zoom":"%s","lancamento":"%s","dock":"%s","suportado":{"latte":true,"plasma":false}}' \
    "$(dock_pref indicador linha)" "$(dock_pref zoom on)" "$(dock_pref lancamento on)" "$backend"
}
efeito_json_dock() {
  printf '{"id":"dock","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[%s,%s,%s],"estado":%s}' \
    "$(json_str "Dock")" "$(json_str "Dock")" \
    "$(json_str "Indicador das janelas abertas, zoom ao passar o mouse e o pulo do ícone ao abrir. Valem no Latte Dock; a dock do Plasma não tem essas opções.")" \
    "$(json_str "Open-window indicator, zoom on hover and the icon bounce on launch. They apply to Latte Dock; the Plasma dock has no such options.")" \
    '{"id":"indicador","nome":"Indicador","nome_en":"Indicator","tipo":"escolha","padrao":"linha","valores":[{"id":"linha","nome":"Linha","nome_en":"Line"},{"id":"ponto","nome":"Ponto","nome_en":"Dot"}]}' \
    '{"id":"zoom","nome":"Zoom","nome_en":"Zoom","tipo":"escolha","padrao":"on","valores":["on","off"]}' \
    '{"id":"lancamento","nome":"Animação ao abrir","nome_en":"Launch animation","tipo":"escolha","padrao":"on","valores":["on","off"]}' \
    "$(efeito_estado_dock)"
}
#   cyberkde efeito dock [--indicador linha|ponto] [--zoom on|off] [--lancamento on|off] [--json]
efeito_cmd_dock() {
  local ind="" zoom="" lanc="" bad=0
  while (( $# )); do
    case $1 in
      --indicador) ind=${2:-}; shift 2 || shift; [[ $ind == linha || $ind == ponto ]] || bad=1 ;;
      --zoom) zoom=${2:-}; shift 2 || shift; [[ $zoom == on || $zoom == off ]] || bad=1 ;;
      --lancamento) lanc=${2:-}; shift 2 || shift; [[ $lanc == on || $lanc == off ]] || bad=1 ;;
      *) bad=1; shift ;;
    esac
  done
  (( bad == 0 )) || cor_exit 2 "$(t "uso: cyberkde efeito dock [--indicador linha|ponto] [--zoom on|off] [--lancamento on|off] [--json]" "usage: cyberkde efeito dock [--indicador linha|ponto] [--zoom on|off] [--lancamento on|off] [--json]")"
  local -a avisos=()
  if [[ -n $ind$zoom$lanc ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    [[ -z $ind ]] || kwriteconfig6 --file "$efeitos_file" --group dock --key indicador "$ind"
    [[ -z $zoom ]] || kwriteconfig6 --file "$efeitos_file" --group dock --key zoom "$zoom"
    [[ -z $lanc ]] || kwriteconfig6 --file "$efeitos_file" --group dock --key lancamento "$lanc"
    if fase_ligada barra-e-dock && layout_com_dock && [[ -n $(latte_bin) ]]; then
      barra_reaplicar dock || true  # regrava o layout do Latte e o reinicia (só o Latte desta sessão)
    elif layout_com_dock && [[ -z $(latte_bin) ]]; then
      avisos+=("$(t "A dock é o painel do Plasma, que não tem essas opções; elas valem com o Latte Dock (cyberkde latte)." "The dock is a Plasma panel, which has no such options; they apply with Latte Dock (cyberkde latte).")")
    else
      avisos+=("$(t "A escolha foi guardada e vale quando a dock do tema estiver ligada." "The choice was saved and applies once the theme dock is on.")")
    fi
  fi
  barra_responder dock "$(efeito_estado_dock)" "${avisos[@]}"
}

efeito_estado_menu() {
  printf '{"modo":"%s","plugin":"%s"}' "$(menu_modo)" "$(menu_plugin)"
}
efeito_json_menu() {
  printf '{"id":"menu","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"modo","nome":"Exibição","nome_en":"Layout","tipo":"escolha","padrao":"padrao","valores":[{"id":"padrao","nome":"Padrão do KDE","nome_en":"KDE default"},{"id":"lista","nome":"Lista","nome_en":"List"},{"id":"grade","nome":"Grade","nome_en":"Grid"},{"id":"tela-cheia","nome":"Tela cheia","nome_en":"Full screen"}]}],"estado":%s}' \
    "$(json_str "Menu iniciar")" "$(json_str "Application menu")" \
    "$(json_str "O menu do botão da barra e da dock em lista, em grade ou em tela cheia.")" \
    "$(json_str "The bar and dock menu as a list, a grid or full screen.")" "$(efeito_estado_menu)"
}
#   cyberkde efeito menu [padrao|lista|grade|tela-cheia] [--json]
efeito_cmd_menu() {
  local m=${1:-} antes
  if [[ -z $m ]]; then barra_responder menu "$(efeito_estado_menu)"; return; fi
  [[ $# == 1 && ( $m == padrao || $m == lista || $m == grade || $m == tela-cheia ) ]] ||
    cor_exit 2 "$(t "uso: cyberkde efeito menu [padrao|lista|grade|tela-cheia] [--json]" "usage: cyberkde efeito menu [padrao|lista|grade|tela-cheia] [--json]")"
  take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
  antes=$(menu_plugin)
  mkdir -p -- "$(dirname -- "$efeitos_file")"
  kwriteconfig6 --file "$efeitos_file" --group menu --key modo "$m"
  local -a avisos=()
  if fase_ligada barra-e-dock; then
    # Lista e grade são configuração do Kickoff (o "on" da fase regrava); tela cheia troca o plasmoide,
    # e isso só com a barra remontada.
    if [[ $antes != "$(menu_plugin)" ]]; then barra_reaplicar refazer || true; else barra_reaplicar dock || true; fi
  else
    avisos+=("$(t "A escolha foi guardada e vale quando a barra e a dock do tema estiverem ligadas." "The choice was saved and applies once the theme bar and dock are on.")")
  fi
  barra_responder menu "$(efeito_estado_menu)" "${avisos[@]}"
}
