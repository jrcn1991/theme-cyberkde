#!/usr/bin/env bash
# Sessão KWin VIRTUAL para testar o efeito cyberkde_scan: monitor invisível, HOME e TMPDIR
# temporários, sessão D-Bus própria (dbus-run-session): nada fala com o KWin real.
# Uso: sessao.sh <script-da-cena> (roda dentro da sessão, com $tmp, $W, $H exportados)
# Diferente do capturas-loja.sh, a cena tem XDG_RUNTIME_DIR próprio: nem o PipeWire nem o gvfs da
# sessão real ficam ao alcance. Nunca usa --replace: o KWin virtual é um processo à parte.
set -euo pipefail
project="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"
real_home=$HOME
tmp=$(mktemp -d)
# Na saída: o gvfs e o portal de documentos da cena montam FUSE em $XDG_RUNTIME_DIR (run/gvfs, run/doc);
# desmonta (lazy) antes de apagar, senão o rm falha com a pasta ainda montada.
limpar() {
  local m
  for m in "$tmp/run/gvfs" "$tmp/run/doc"; do fusermount3 -uz "$m" 2>/dev/null || true; done
  rm -rf -- "$tmp" 2>/dev/null || true
  # serviços da cena que ainda estavam saindo (ex.: kwalletd) podem recriar algo: segunda passada
  sleep 1
  rm -rf -- "$tmp" 2>/dev/null || true
}
[[ -n ${PREVIAS_MANTER:-} ]] || trap limpar EXIT
export tmp project W=${W:-1600} H=${H:-1000}  # tamanho da tela virtual
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_DATA_HOME="$tmp/home/.local/share" \
  XDG_CACHE_HOME="$tmp/home/.cache" XDG_STATE_HOME="$tmp/home/.local/state" TMPDIR="$tmp/tmp"
export LANG=C.UTF-8 LANGUAGE=en_US:en XDG_CONFIG_DIRS=/etc/xdg
unset LC_ALL DISPLAY SESSION_MANAGER
# Pasta de execução própria: sem ela, programas da cena achavam o PipeWire e o gvfs da sessão real.
export XDG_RUNTIME_DIR="$tmp/run"
export WAYLAND_DISPLAY=wayland-cyberkde-janelas QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland
mkdir -p "$HOME" "$TMPDIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Efeito montado como o install_effect monta, mais o contents/config/main.xml.
src="$project/effects/cyberkde_scan" dst="$XDG_DATA_HOME/kwin/effects/cyberkde_scan"
mkdir -p "$dst/contents/code" "$dst/contents/shaders" "$dst/contents/config"
cp "$src/metadata.json" "$dst/"
cp "$src/main.js" "$dst/contents/code/main.js"
cp "$src/main.xml" "$dst/contents/config/main.xml"
{ printf '#version 140\n#include "colormanagement.glsl"\n#define TEX texture\nin vec2 texcoord0;\nout vec4 fragColor;\n\n'
  cat "$src/shader.glsl"; } >"$dst/contents/shaders/scan_core.frag"
{ printf '#include "colormanagement.glsl"\n#define TEX texture2D\n#define fragColor gl_FragColor\nvarying vec2 texcoord0;\n\n'
  cat "$src/shader.glsl"; } >"$dst/contents/shaders/scan.frag"

# Visual do tema só por cópia (leitura) do que já está instalado: decoração, perfil do Konsole.
if [[ -d $real_home/.local/share/aurorae/themes/CyberKDE ]]; then
  mkdir -p "$XDG_DATA_HOME/aurorae/themes"; cp -r "$real_home/.local/share/aurorae/themes/CyberKDE" "$XDG_DATA_HOME/aurorae/themes/"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__CyberKDE
fi
mkdir -p "$XDG_DATA_HOME/konsole"
cp "$real_home/.local/share/konsole/"CyberKDE.* "$XDG_DATA_HOME/konsole/" 2>/dev/null || true
# Tamanho fixo pelo perfil (a janela não é redimensionada depois) e sem o rótulo de tamanho.
kwriteconfig6 --file "$XDG_DATA_HOME/konsole/CyberKDE.profile" --group General --key TerminalColumns 96
kwriteconfig6 --file "$XDG_DATA_HOME/konsole/CyberKDE.profile" --group General --key TerminalRows 22
kwriteconfig6 --file "$XDG_DATA_HOME/konsole/CyberKDE.profile" --group General --key ShowTerminalSizeHint false
kwriteconfig6 --file plasma-welcomerc --group General --key LastSeenVersion 99.0
kwriteconfig6 --file plasma-welcomerc --group General --key ShowUpdatePage false
# Cores e estilo dos apps (CyberKDE) por cópia do que ela já usa; a cena não escreve na pasta real.
cp "$real_home/.config/kdeglobals" "$XDG_CONFIG_HOME/kdeglobals" 2>/dev/null || true
cp -r "$real_home/.config/Kvantum" "$XDG_CONFIG_HOME/" 2>/dev/null || true
mkdir -p "$XDG_DATA_HOME/color-schemes"; cp "$real_home/.local/share/color-schemes/"CyberKDE*.colors "$XDG_DATA_HOME/color-schemes/" 2>/dev/null || true
# Konsole sempre no mesmo lugar (regra forçada; o tamanho vem do perfil).
cat >"$XDG_CONFIG_HOME/kwinrulesrc" <<'R'
[General]
count=1
rules=1

[1]
Description=cena
wmclass=konsole
wmclassmatch=2
position=290,200
positionrule=2
R
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile CyberKDE.profile
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 1
kwriteconfig6 --file kwinrc --group Plugins --key cyberkde_scanEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key scaleEnabled false
kwriteconfig6 --file kwinrc --group Compositing --key LockScreenAutoLockActive false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
mkdir -p "$XDG_CONFIG_HOME/autostart"
for f in /etc/xdg/autostart/*.desktop /usr/share/autostart/*.desktop; do printf '[Desktop Entry]\nHidden=true\n' >"$XDG_CONFIG_HOME/autostart/${f##*/}"; done

dbus-run-session -- bash -c '
  env -u WAYLAND_DISPLAY kwin_wayland --virtual --width "$W" --height "$H" --socket wayland-cyberkde-janelas --no-lockscreen >"$tmp/kwin.log" 2>&1 &
  for i in $(seq 1 100); do [[ -S $XDG_RUNTIME_DIR/wayland-cyberkde-janelas ]] && break; sleep 0.1; done
  for i in $(seq 1 100); do qdbus6 org.kde.KWin /KWin >/dev/null 2>&1 && break; sleep 0.1; done
  dbus-update-activation-environment WAYLAND_DISPLAY QT_QPA_PLATFORM HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME TMPDIR
  bash "$0"
  kill $(jobs -p) 2>/dev/null
' "$1"
