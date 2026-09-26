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
CYBERKDE_INSTALLS+=(install_barra-e-dock)
CYBERKDE_PRE_OFF_HOOKS+=(pre_off_barra-e-dock)
CYBERKDE_OFF_HOOKS+=(off_barra-e-dock)

layout_file="$config/cyberkde/layout"
appletsrc="$config/plasma-org.kde.plasma.desktop-appletsrc"
appletsrc_orig="$state/appletsrc.orig"
latte_iniciado="$state/latte-iniciado-pelo-tema"
dock_plasma_id="$state/dock-plasma-id"
menu_icon="$data/cyberkde/menu.svg"            # dock: blocos sobre fundo escuro
menu_icon_barra="$data/cyberkde/menu-barra.svg" # barra: só os blocos, ocupando o ícone (fica maior em 33 px)

# Versão do arranjo da barra: sobe quando a barra do tema muda, para quem atualiza o tema recebê-la
# (a barra é montada só na primeira aplicação; o original guardado para o off não muda).
barra_versao=5  # 3: sem o menu global (appmenu); 4: barra em todas as telas; 5: ícone do menu da barra
barra_versao_file="$state/barra-versao"

layout_tema() { [[ $(cat "$layout_file" 2>/dev/null) == tema ]]; }

# Ícones do menu: quatro blocos na cor de destaque (acompanham o "cyberkde cor"). O da dock ocupa 94% do
# quadro, como os outros ícones de apps do tema (com 86% ficava menor que eles).
install_barra-e-dock() {
  mkdir -p "$(dirname -- "$menu_icon")"
  python3 - "$project/generator" "$menu_icon" "$menu_icon_barra" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
from cyberlib import RED
r, g, b = (int(RED[i:i + 2], 16) for i in (1, 3, 5))
mix = lambda t, k: "#%02x%02x%02x" % tuple(round(c + (t - c) * k) for c in (r, g, b))
fundo, claro, claro2 = mix(0, 0.69), mix(255, 0.55), mix(255, 0.72)
open(sys.argv[2], "w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<rect x="15" y="15" width="482" height="482" rx="101" fill="{fundo}"/>
<rect x="103" y="103" width="127" height="127" rx="25" fill="{RED}"/>
<rect x="282" y="103" width="127" height="127" rx="25" fill="{claro}"/>
<rect x="103" y="282" width="127" height="127" rx="25" fill="{claro2}"/>
<rect x="282" y="282" width="127" height="127" rx="25" fill="{RED}"/>
</svg>
''')
# Barra: como o menu da barra da autora do tema (quatro blocos claros, sem fundo).
open(sys.argv[3], "w").write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<rect x="56" y="56" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="272" y="56" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="56" y="272" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="272" y="272" width="184" height="184" rx="40" fill="{claro}"/>
</svg>
''')
EOF
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
    TMPDIR="$state/latte-tmp" setsid "$bin" >/dev/null 2>&1 </dev/null 9>&- &
  elif ! systemctl --user start 'app-org.kde.latte\x2ddock@autostart.service' >/dev/null 2>&1; then
    systemd-run --user --quiet --collect --unit="latte-dock-ng-$(date +%s)" "$bin" >/dev/null 2>&1 9>&- || true
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
      if (p[i].location == 'top' && (!porTela[t] || porTela[t].location != 'top')) porTela[t] = p[i];
      else if (p[i].location == 'bottom' && !porTela[t]) porTela[t] = p[i];
    }
    var barras = [];
    for (var t in porTela) barras.push(porTela[t]);
    if (barras.length == 0) barras.push(new Panel());
    for (var b = 0; b < barras.length; b++) montar(barras[b]);
    function montar(bar) {
    bar.location = 'top';
    bar.height = 33;
    bar.floating = false;
    var w = bar.widgets();
    for (var j = 0; j < w.length; j++) w[j].remove();
    var k = bar.addWidget('org.kde.plasma.kickoff');
    k.currentConfigGroup = ['General'];
    k.writeConfig('icon', '$menu_icon_barra');
    bar.addWidget('org.kde.plasma.panelspacer');
    bar.addWidget('org.kde.plasma.systemtray');
    bar.addWidget('org.kde.milou');
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
    var k = d.addWidget('org.kde.plasma.kickoff');
    k.currentConfigGroup = ['General'];
    k.writeConfig('icon', '$menu_icon');
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
  printf '[UniversalSettings]\nmemoryUsage=0\nshowInfoWindow=false\nsingleModeLayoutName=CyberKDE\nversion=2\n' |
    put_file "$config/lattedockrc"
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
screensGroup=1
viewType=0
visibility=0

[Containments][1][Applets][2]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][1][Applets][2][Configuration]
popupHeight=548
popupWidth=726

[Containments][1][Applets][2][Configuration][General]
icon=$menu_icon

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.latte.plasmoid

[Containments][1][Applets][3][Configuration][General]
isInLatteDock=true
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
zoomLevel=12

[Containments][1][Indicator]
enabled=true
type=org.kde.latte.default


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
  if ! qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
    echo "O Plasma (plasmashell) não está rodando; a barra e a dock ficam para o próximo 'cyberkde on'." >&2
    return 1
  fi
  # Primeira vez: guarda os painéis originais e monta a barra. Depois disso (ex.: "cyberkde cor"), só
  # confere a dock.
  if [[ ! -e $appletsrc_orig ]]; then
    mkdir -p "$state"
    if [[ -f $appletsrc ]]; then cp -a -- "$appletsrc" "$appletsrc_orig"; else : >"$appletsrc_orig"; fi
    barra_aplicar
    echo "$barra_versao" >"$barra_versao_file"
  elif (( $(cat "$barra_versao_file" 2>/dev/null || echo 1) < barra_versao )); then
    barra_aplicar  # barra de uma versão antiga do tema: remonta (o original do off continua o mesmo)
    echo "$barra_versao" >"$barra_versao_file"
  fi
  if [[ -n $(latte_bin) ]]; then
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
  rm -f -- "$appletsrc_orig" "$barra_versao_file"
}
