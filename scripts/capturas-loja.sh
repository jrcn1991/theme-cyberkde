#!/usr/bin/env bash
# capturas-loja.sh — tira as capturas de tela da loja num KWin VIRTUAL (monitor invisível).
#
#   scripts/capturas-loja.sh
#
# Nada aparece na tela de quem roda e nada da sessão real entra nas imagens: pasta pessoal
# temporária, sessão D-Bus própria (os comandos para o KWin e o Plasma só alcançam a cena virtual),
# tema no vermelho padrão, textos em inglês. A barra de cima e a dock saem da MESMA fase que a
# instalação usa ("cyberkde on barra-e-dock", com o Latte Dock compilado pelo "cyberkde latte"): o
# que aparece nas imagens é o que quem instala recebe.
# O Latte é o commit revisado (763718f do jrcn1991/latte-dock-ng) compilado por quem mantém o tema em
# latte/build, com prefixo ~/.local, e copiado para o ~/.local da pasta temporária pela lista de
# instalação do cmake. Só aqui, na máquina de quem mantém: o tema nunca compila o Latte para quem instala.
# Compilação (em latte/, fora do git): commit em latte/src; cmake -S latte/src -B latte/build -G Ninja
#   -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=$PWD/latte/prefix
#   -DKDE_INSTALL_QMLDIR=$PWD/latte/prefix/lib/x86_64-linux-gnu/qt6/qml; build e install; depois copiar
#   containment/plasmoid/separator/shell/indicators para latte/prefix/share como o install.sh do Latte,
#   acrescentando os arquivos ao install_manifest.txt.
# Saída: assets/loja/{fullscreenpreview.jpg,preview.png,desktop.png,dolphin.png,konsole.png,menu.png,vazio.png}

set -euo pipefail

project="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
out="$project/assets/loja"
tmp=$(mktemp -d)
[[ -n ${CAPTURAS_MANTER:-} ]] || trap 'rm -rf "$tmp"' EXIT
W=1920 H=1080
latte_manifest="$project/latte/build/install_manifest.txt"
[[ -f $latte_manifest ]] || { echo "Latte não compilado nesta pasta: compile o commit revisado ali (ver o comentário no topo)." >&2; exit 1; }
latte_prefix=$(sed -n 's/^CMAKE_INSTALL_PREFIX:PATH=//p' "$project/latte/build/CMakeCache.txt")

export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_DATA_HOME="$tmp/home/.local/share" \
  XDG_CACHE_HOME="$tmp/home/.cache" XDG_STATE_HOME="$tmp/home/.local/state"
# Interface em inglês sem depender do locale en_US gerado na máquina.
export LANG=C.UTF-8 LANGUAGE=en_US:en
unset LC_ALL CYBERKDE_COR CYBERKDE_WALLPAPER DISPLAY SESSION_MANAGER
export XDG_CONFIG_DIRS=/etc/xdg  # sem os padrões (kdedefaults) da sessão de quem roda
# TUDO que nascer nesta sessão (inclusive serviços ativados pelo D-Bus) vai para o monitor virtual.
# Sem isto, um programa ativado pelo D-Bus caía no monitor padrão, que é a tela real de quem roda.
export WAYLAND_DISPLAY=wayland-cyberkde-loja QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland
mkdir -p "$HOME" "$out"

echo "Instalando o tema na pasta temporária…"
mkdir -p "$XDG_CONFIG_HOME/cyberkde"
echo tema >"$XDG_CONFIG_HOME/cyberkde/layout"  # arranjo de uma instalação nova
"$project/scripts/cyberkde" install >/dev/null

# Aparência (o que o Tema Global da loja aplica) + Kvantum e Konsole.
k() { kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }
k kdeglobals Icons Theme CyberKDE
k kdeglobals KDE AnimationDurationFactor 0
k plasmarc Theme name CyberKDE
k kwinrc org.kde.kdecoration2 library org.kde.kwin.aurorae
k kwinrc org.kde.kdecoration2 theme __aurorae__svg__CyberKDE
k kwinrc Compositing LockScreenAutoLockActive false
k kscreenlockerrc Daemon Autolock false
k "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" General theme CyberKDE
k konsolerc "Desktop Entry" DefaultProfile CyberKDE.profile
k dolphinrc General RememberOpenedTabs false
k dolphinrc General ShowFullPath false
# Ícones do tema, sem miniaturas (os arquivos de exemplo não têm conteúdo de verdade).
mkdir -p "$XDG_DATA_HOME/dolphin/view_properties/global"
printf '[Dolphin]\nPreviewsShown=false\nVersion=4\nViewMode=0\n' >"$XDG_DATA_HOME/dolphin/view_properties/global/.directory"
k plasma-welcomerc General LastSeenVersion 99.0
k plasma-welcomerc General ShowUpdatePage false
# Nenhum programa de inicialização automática: nada de boas-vindas, KDE Connect etc.
mkdir -p "$XDG_CONFIG_HOME/autostart"
for f in /etc/xdg/autostart/*.desktop /usr/share/autostart/*.desktop; do
  [[ -f $f ]] && printf '[Desktop Entry]\nHidden=true\n' >"$XDG_CONFIG_HOME/autostart/${f##*/}"
done

# Latte no ~/.local da pasta temporária, arquivo por arquivo da lista do cmake.
while IFS= read -r f; do
  [[ -e $f || -L $f ]] || continue
  install -D -m "$(stat -c %a "$f")" -- "$f" "$HOME/.local/${f#"$latte_prefix"/}"
done <"$latte_manifest"
export PATH="$HOME/.local/bin:$PATH"

# Pasta de demonstração, com locais só dela (sem discos, rede, recentes nem etiquetas).
demo="$HOME/Night City"
mkdir -p "$demo"/{Documents,Downloads,Pictures,Music,Videos,Projects,Games}
( cd "$demo"
  printf '%%PDF-1.4\n%%demo\n' > mission-report.pdf
  printf 'Contract: Arasaka Tower\nTime: 23:00\n' > notes.txt
  magick -size 64x64 xc:'#F75049' street.png
  printf 'ID3\x03\x00\x00\x00\x00\x00\x00demo' > soundtrack.mp3
  printf '\x00\x00\x00\x18ftypmp42demo' > recording.mp4
  printf '{"netrunner": true}\n' > profile.json
  printf '#!/usr/bin/env python3\nprint("wake up, samurai")\n' > quickhack.py
  printf '<html><body>demo</body></html>\n' > index.html
  printf 'int main(void) { return 0; }\n' > implant.c
  printf 'demo\n' > payload.tar
  printf 'Report\n' > briefing.odt
  printf 'Budget\n' > eddies.ods )
python3 - "$demo" "$XDG_DATA_HOME/user-places.xbel" <<'EOF'
import sys, urllib.parse
demo, out = sys.argv[1], sys.argv[2]
groups = ["Remote", "Devices", "RemovableDevices", "SearchFor", "RecentlySaved", "Tags"]
places = [("Night City", "", "user-home"), ("Documents", "Documents", "folder-documents"),
          ("Downloads", "Downloads", "folder-download"), ("Pictures", "Pictures", "folder-pictures"),
          ("Music", "Music", "folder-music"), ("Videos", "Videos", "folder-videos"),
          ("Projects", "Projects", "folder-development"), ("Trash", None, "user-trash")]
x = ['<?xml version="1.0" encoding="UTF-8"?>', "<!DOCTYPE xbel>",
     '<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks">',
     ' <info><metadata owner="http://www.kde.org"><kde_places_version>4</kde_places_version>'
     "<withBaloo>true</withBaloo><withRecentlyUsed>true</withRecentlyUsed>"
     + "".join(f"<GroupState-{g}-IsHidden>true</GroupState-{g}-IsHidden>" for g in groups)
     + "<GroupState-Places-IsHidden>false</GroupState-Places-IsHidden></metadata></info>"]
for i, (title, sub, icon) in enumerate(places):
    href = "trash:/" if sub is None else "file://" + urllib.parse.quote(demo + ("/" + sub if sub else ""))
    x.append(f' <bookmark href="{href}"><title>{title}</title><info>'
             f'<metadata owner="http://freedesktop.org"><bookmark:icon name="{icon}"/></metadata>'
             f'<metadata owner="http://www.kde.org"><ID>demo/{i}</ID></metadata></info></bookmark>')
x.append("</xbel>")
open(out, "w").write("\n".join(x) + "\n")
EOF

# Texto do Konsole: prompt e saída coloridos com a paleta ANSI do tema.
cat >"$tmp/konsole-demo.sh" <<'EOF'
cd "$HOME/Night City"
export PS1='\[\e[31m\]▌\[\e[0m\] \[\e[36m\]netrunner\[\e[0m\]@\[\e[31m\]night-city\[\e[0m\] \[\e[33m\]\w\[\e[0m\] › '
clear
printf '\e[31m▌ CYBERKDE\e[0m \e[90m// neo-military theme for KDE Plasma 6\e[0m\n\n'
printf '\e[36mnetrunner\e[0m@\e[31mnight-city\e[0m \e[33m~/Night City\e[0m › ls\n'
ls --color=always -p
printf '\n\e[36mnetrunner\e[0m@\e[31mnight-city\e[0m \e[33m~/Night City\e[0m › python3 quickhack.py\n'
printf '\e[32m[ OK ]\e[0m ICE bypassed   \e[33m[WARN]\e[0m trace 12%%   \e[31m[FAIL]\e[0m firewall\n'
printf '\e[35mwake up, samurai\e[0m\n\n'
exec bash --norc -i
EOF

cat >"$tmp/cena.sh" <<'EOF'
#!/usr/bin/env bash
# Roda DENTRO do dbus-run-session: tudo aqui fala com o KWin/Plasma virtuais.
set -u
# O próprio KWin não é cliente de ninguém: sem WAYLAND_DISPLAY ele não tenta se ligar à tela real.
env -u WAYLAND_DISPLAY kwin_wayland --virtual --width "$W" --height "$H" --socket wayland-cyberkde-loja --no-lockscreen >"$tmp/kwin.log" 2>&1 &
for i in $(seq 1 100); do [[ -S $XDG_RUNTIME_DIR/wayland-cyberkde-loja ]] && break; sleep 0.1; done
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true
dbus-update-activation-environment WAYLAND_DISPLAY QT_QPA_PLATFORM GDK_BACKEND XDG_SESSION_TYPE XDG_CURRENT_DESKTOP LANG LANGUAGE HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
plasmashell --no-respawn >"$tmp/plasma.log" 2>&1 &
for i in $(seq 1 100); do qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break; sleep 0.2; done
sleep 4
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
  var d = desktops();
  for (var i = 0; i < d.length; i++) {
    d[i].wallpaperPlugin = 'org.kde.image';
    d[i].currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d[i].writeConfig('Image', 'file://$project/assets/wallpapers/desktop.png');
    d[i].reloadConfig();
  }" >/dev/null
# Cores e estilo em todos os apps, barra em cima e dock: as fases da instalação. CYBERKDE_CENA
# mantém tudo nesta sessão D-Bus (o Latte sobe direto nela, não pelo systemd da sessão real).
export CYBERKDE_CENA=1 CYBERKDE_NAVEGADOR=microsoft-edge.desktop
"$project/scripts/cyberkde" on apps >"$tmp/on-apps.log" 2>&1
"$project/scripts/cyberkde" on barra-e-dock >"$tmp/on-dock.log" 2>&1
sleep 5
dolphin --new-window "$HOME/Night City" >"$tmp/dolphin.log" 2>&1 &
sleep 3
konsole --separate --nofork -e bash --norc "$tmp/konsole-demo.sh" >"$tmp/konsole.log" 2>&1 &
sleep 4
# Posições fixas: Konsole à esquerda, Dolphin à direita, os dois inteiros na tela.
cat >"$tmp/arruma.js" <<JS
for (const w of workspace.windowList()) {
    if (!w.normalWindow) continue;
    if (String(w.resourceClass).indexOf("konsole") !== -1)
        w.frameGeometry = { x: 90, y: 110, width: 860, height: 560 };
    if (String(w.resourceClass).indexOf("dolphin") !== -1) {
        w.frameGeometry = { x: 720, y: 250, width: 1100, height: 680 };
        workspace.activeWindow = w;
    }
    print("CYBERKDE-GEO " + w.resourceClass + " " + Math.round(w.frameGeometry.x) + " " + Math.round(w.frameGeometry.y)
          + " " + Math.round(w.frameGeometry.width) + " " + Math.round(w.frameGeometry.height));
}
JS
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/arruma.js" arruma)
qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
sleep 3
spectacle -f -b -n -e -o "$tmp/desktop.png" >/dev/null 2>&1; sleep 3
# Uma janela de cada vez em foco, para os recortes saírem sem sobreposição.
for app in konsole dolphin; do
  printf 'for (const w of workspace.windowList()) if (w.normalWindow) { if (String(w.resourceClass).indexOf("%s") !== -1) { w.frameGeometry = {x: 330, y: 150, width: 1260, height: 760}; w.minimized = false; workspace.activeWindow = w; } else w.minimized = true; }\n' "$app" >"$tmp/so-$app.js"
  id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/so-$app.js" "so-$app")
  qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
  sleep 2.5
  spectacle -f -b -n -e -o "$tmp/so-$app.png" >/dev/null 2>&1; sleep 3
done
# Menu iniciar aberto por cima da área de trabalho (só a cena virtual recebe o pedido).
printf 'for (const w of workspace.windowList()) if (w.normalWindow) w.minimized = true;\n' >"$tmp/limpa.js"
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/limpa.js" limpa)
qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
sleep 1
# Área de trabalho vazia (base da animação do README).
spectacle -f -b -n -e -o "$tmp/vazio.png" >/dev/null 2>&1; sleep 3
qdbus6 org.kde.lattedock /Latte org.kde.LatteDock.activateLauncherMenu >/dev/null 2>&1
sleep 2.5
spectacle -f -b -n -e -o "$tmp/menu.png" >/dev/null 2>&1; sleep 3
kill $(jobs -p) 2>/dev/null
EOF
chmod +x "$tmp/cena.sh"

echo "Montando a cena no KWin virtual (${W}x${H}, nada aparece na tela)…"
export tmp W H project
timeout 300 dbus-run-session -- "$tmp/cena.sh" >/dev/null 2>&1 || true
# Encerra tudo o que nasceu da sessão (serviços ativados pelo D-Bus sobrevivem ao fim dela).
sobras() {
  local pid
  for pid in $(pgrep -u "$USER" . 2>/dev/null); do
    # 2>/dev/null antes do "<": o ambiente de alguns processos é ilegível e o erro da própria
    # redireção encerrava o script (set -e) antes de copiar as capturas.
    { tr '\0' '\n' <"/proc/$pid/environ"; } 2>/dev/null | grep -qxF "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" && echo "$pid"
  done
  return 0
}
mapfile -t restos < <(sobras)
if (( ${#restos[@]} )); then kill -TERM "${restos[@]}" 2>/dev/null; sleep 2; kill -KILL $(sobras) 2>/dev/null || true; fi

for f in desktop so-konsole so-dolphin menu vazio; do
  [[ -s $tmp/$f.png ]] || { echo "Falhou a captura '$f' (logs em $tmp)." >&2; trap - EXIT; exit 1; }
done
cp "$tmp/desktop.png" "$out/desktop.png"
magick "$tmp/desktop.png" -quality 90 "$out/fullscreenpreview.jpg"
magick "$tmp/desktop.png" -resize 600x338 "$out/preview.png"
magick "$tmp/so-konsole.png" -crop 1260x760+330+150 +repage "$out/konsole.png"
magick "$tmp/so-dolphin.png" -crop 1260x760+330+150 +repage "$out/dolphin.png"
cp "$tmp/menu.png" "$out/menu.png"
cp "$tmp/vazio.png" "$out/vazio.png"
echo "Capturas em $out:"
ls "$out"
