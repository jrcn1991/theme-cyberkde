#!/bin/bash
# Prévias dos widgets que leem o sistema (Painel FUI, módulos fui-*, Discos e Desempenho) com dados
# INVENTADOS. Roda o plasmawindowed num Xvfb com D-Bus e XDG próprios, sem logind e sem KWin; os widgets
# não mudam: o módulo org.kde.ksysguard.sensors é trocado por qml/ (QML_IMPORT_PATH) e os coletores por
# *-demo.sh, só na cópia de teste. A cidade do clima é "Night City" e o fuso, o de lá.
#   uso: previas-demo.sh [DIR-DE-TRABALHO]     (padrão: um diretório novo em /tmp)
set -u
DEMO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
R=$(cd -- "$DEMO/../../.." && pwd)
TRAB=${1:-$(mktemp -d /tmp/cyberkde-demo.XXXX)}
DEST=$R/assets/previas/widgets
FD=:92
mkdir -p "$TRAB" || exit 1
paleta() {
  read -r COR COR2 ALE FUN < <(python3 -c "
import json,sys; c={x['id']:x for x in json.load(open(sys.argv[1]))['corporacoes']}[sys.argv[2]]
print(c['destaque'], c['secundaria'], c['alerta'], c['fundo'])" "$R/tokens/corporacoes.json" "$1")
  mkdir -p "$TRAB/cfgvazio"
  XDG_CONFIG_HOME=$TRAB/cfgvazio CYBERKDE_COR=$COR CYBERKDE_COR2=$COR2 CYBERKDE_ALERTA=$ALE CYBERKDE_FUNDO=$FUN python3 - "$R/generator" "$1" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from cyberlib import RED, CYAN, ALERTA, BASE, PANEL, RAISED, TXT1, TXT2, TXTD, LINE, ONRED, TOK
cores = {"destaque": RED, "secundaria": CYAN, "alerta": ALERTA, "fundo": TOK["reference"]["darkestBlue"],
         "superficie": BASE, "painel": PANEL, "elevado": RAISED, "texto": TXT1, "textoSecundario": TXT2,
         "textoDesativado": TXTD, "linha": LINE, "textoSobreDestaque": ONRED}
print("pragma Singleton\nimport QtQuick\n\nQtObject {")
for k, v in cores.items():
    print(f'    readonly property color {k}: "{v}"')
print(f'    readonly property string corp: "{sys.argv[2]}"')
print("}")
PY
}
limpar() {  # processos do ambiente isolado (serviços ativados pelo D-Bus sobrevivem a ele)
  local p
  for p in $(pgrep -u "$USER" -f .); do
    [[ $p == "$$" || $p == "$BASHPID" ]] && continue
    grep -qz "^XDG_RUNTIME_DIR=$1" "/proc/$p/environ" 2>/dev/null && kill "$p" 2>/dev/null
  done
  return 0
}
capturar() {  # ID CORP LARG ALT SAIDA SEGUNDOS [chave=valor...]
  local id=$1 corp=$2 L=$3 A=$4 saida=$5 seg=$6; shift 6
  local S; S=$(mktemp -d "$TRAB/s.XXXX")
  (
    export HOME=$S/h XDG_CONFIG_HOME=$S/h/.config XDG_DATA_HOME=$S/h/.local/share XDG_CACHE_HOME=$S/h/.cache \
      XDG_STATE_HOME=$S/h/.local/state XDG_RUNTIME_DIR=$S/run TMPDIR=$S/tmp TZ=America/Los_Angeles \
      DISPLAY=$FD QT_QPA_PLATFORM=xcb LANG=${LANG_TESTE:-pt_BR.UTF-8} QML_IMPORT_PATH=$DEMO/qml
    unset XDG_SESSION_ID XDG_SEAT XDG_VTNR WAYLAND_DISPLAY SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
    P=$XDG_DATA_HOME/plasma/plasmoids
    mkdir -p "$XDG_CONFIG_HOME" "$P" "$XDG_RUNTIME_DIR" "$TMPDIR" "$XDG_DATA_HOME/dbus-1/services" "$XDG_DATA_HOME/fonts"
    chmod 700 "$XDG_RUNTIME_DIR"
    for s in org.kde.kded6 org.kde.kdeconnect org.kde.kdeconnectd org.bluez.obex org.gnome.evolution.dataserver.Sources5 org.gnome.OnlineAccounts \
             org.freedesktop.portal.Desktop org.freedesktop.impl.portal.desktop.kde org.kde.ActivityManager org.kde.kglobalaccel \
             org.freedesktop.secrets org.kde.secretservicecompat org.kde.kwalletd6 org.kde.kwalletd5 org.freedesktop.portal.Documents \
             org.gtk.vfs.Daemon org.kde.ksystemstats1; do
      printf '[D-BUS Service]\nName=%s\nExec=/bin/false\n' "$s" >"$XDG_DATA_HOME/dbus-1/services/$s.service"
    done
    cp "$R"/assets/fonts/*.ttf "$XDG_DATA_HOME/fonts/" 2>/dev/null
    "$R/modules/widgets/plasmoides/montar.sh" "$P" "$id" >/dev/null || exit 1
    [[ -f $P/$id/contents/code/coleta.sh ]] && cp "$DEMO/coleta-demo.sh" "$P/$id/contents/code/coleta.sh"
    [[ -f $P/$id/contents/code/discos.sh ]] && cp "$DEMO/discos-demo.sh" "$P/$id/contents/code/discos.sh"
    [[ $corp == arasaka ]] || paleta "$corp" >"$P/$id/contents/ui/comum/Paleta.qml"
    cat >"$XDG_CONFIG_HOME/kdeglobals" <<'K'
[General]
font=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
[Icons]
Theme=breeze-dark
K
    { printf '[Applets][4]\nplugin=%s\n\n[Applets][4][Configuration]\ngeometry=0,0,%s,%s\n\n[Applets][4][Configuration][General]\najustado=true\n' "$id" "$L" "$A"
      printf 'cidade=\ncidadeResolvida=Night City\nlatitude=37.77\nlongitude=-122.42\n'
      for kv in "$@"; do printf '%s\n' "$kv"; done; } >"$XDG_CONFIG_HOME/plasmawindowedrc"
    dbus-run-session -- bash -c "plasmawindowed '$id' >'$S/pw.log' 2>&1 & sleep $seg; import -display $FD -window root -crop ${L}x${A}+0+0 +repage '$saida'; kill %1; wait" </dev/null >/dev/null 2>&1
  )
  grep -E "TypeError|ReferenceError|is not installed|error when loading" "$S/pw.log" | head -5
  limpar "$S/run"
  rm -rf "$S"
}
cantos() {  # tira o fundo branco da janela que aparece pelos chanfros
  local f=$1 W H; W=$(identify -format %w "$f"); H=$(identify -format %h "$f")
  # só canto claro: num canto escuro o preenchimento correria pelo fundo e apagaria os traços fracos
  (( $(magick "$f" -format '%[fx:int(255*p{0,0}.g)]' info:) > 128 )) || return 0
  magick "$f" -fuzz 12% -fill '#0E0E17' -draw "color 0,0 floodfill" -draw "color $((W-1)),$((H-1)) floodfill" "$f"
}
pgrep -f "^Xvfb $FD" >/dev/null || { setsid Xvfb $FD -screen 0 1920x1080x24 -nolisten tcp </dev/null >/dev/null 2>&1 & sleep 1; }
tira() {  # NOME-DA-PREVIA ID "P" "M" "G" (tamanhos LxA); Arasaka e Militech
  local nome=$1 id=$2 p=$3 m=$4 g=$5 corp t tam fs suf
  for corp in arasaka militech; do
    fs=()
    for t in pequeno medio grande; do
      case $t in pequeno) tam=$p ;; medio) tam=$m ;; grande) tam=$g ;; esac
      capturar "$id" "$corp" "${tam%x*}" "${tam#*x}" "$TRAB/$nome-$corp-$t.png" 9 "modo=$t" opacidade=100
      cantos "$TRAB/$nome-$corp-$t.png"; fs+=("$TRAB/$nome-$corp-$t.png")
    done
    suf=$([[ $corp == arasaka ]] || echo "-$corp")
    magick -background '#0E0E17' "${fs[@]}" -bordercolor '#0E0E17' -border 12 -gravity north +append -border 4 -quality 92 "$DEST/$nome$suf.webp"
    echo "$nome$suf.webp"
  done
}
tira painelfui org.cyberkde.painelfui 240x96 776x656 960x816
tira discos org.cyberkde.discos 240x96 324x270 378x504
tira desempenho org.cyberkde.desempenho 236x96 324x252 378x432
for mid in cpu nucleos sensores memoria gpu discos es rede trafego processos log sistema hora clima estados; do
  capturar "org.cyberkde.fui-$mid" arasaka 500 300 "$TRAB/fui-$mid.png" 9 modo=grande opacidade=100
  magick "$TRAB/fui-$mid.png" -bordercolor '#0E0E17' -border 8 -quality 92 "$DEST/fui-$mid.webp"
  echo "fui-$mid.webp"
done
pkill -u "$USER" -f "^Xvfb $FD" 2>/dev/null
echo "pronto: $TRAB"
