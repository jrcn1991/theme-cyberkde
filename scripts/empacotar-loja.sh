#!/usr/bin/env bash
# empacotar-loja.sh — gera os pacotes do CyberKDE para a KDE Store (store.kde.org) em dist/loja/.
#
#   scripts/empacotar-loja.sh
#
# Tudo sai na cor padrão (vermelho) e com o painel CyberKDE, gerado numa pasta pessoal temporária:
# a configuração e a cor de quem roda não entram nos pacotes. Nada é instalado no sistema.

set -euo pipefail

project="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
out="$project/dist/loja"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

version=$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from cyberlib import VERSION; print(VERSION)' "$project/generator")

echo "Gerando os arquivos do tema (cor padrão, pasta temporária)…"
env -u CYBERKDE_COR -u CYBERKDE_WALLPAPER HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" \
  XDG_DATA_HOME="$tmp/home/.local/share" XDG_STATE_HOME="$tmp/home/.local/state" \
  XDG_CACHE_HOME="$tmp/home/.cache" CYBERKDE_PAINEL=cyberkde \
  "$project/scripts/cyberkde" install >/dev/null
data="$tmp/home/.local/share"
cfg="$tmp/home/.config"

rm -rf -- "$out"
mkdir -p -- "$out"
pack() {  # arquivo.tar.gz pasta-base item
  # Permissões normalizadas: um umask restritivo deixaria o tema ilegível para outros usuários (o SDDM
  # roda como o usuário "sddm").
  tar --owner=0 --group=0 --numeric-owner --mode='u+rwX,go+rX,go-w' -C "$2" -czf "$out/$1" "$3"
  echo "  $1"
}

# Papel de parede como pacote do Plasma (o Tema Global aponta para ele pelo nome).
wp="$tmp/wallpaper/CyberKDE"
mkdir -p "$wp/contents/images"
cp "$project/assets/wallpapers/desktop.png" "$wp/contents/images/1920x1080.png"
magick "$project/assets/wallpapers/desktop.png" -resize 400x250^ -gravity center -extent 400x250 "$wp/contents/screenshot.png"
cat >"$wp/metadata.json" <<EOF
{
  "KPlugin": {
    "Authors": [{ "Name": "Rafael Neves" }],
    "Id": "CyberKDE",
    "License": "CC-BY-SA-4.0",
    "Name": "CyberKDE",
    "Version": "$version",
    "Website": "https://github.com/jrcn1991/theme-cyberkde"
  }
}
EOF

# Tema Global: o splash que o tema já gera + "defaults" apontando para as outras peças.
lnf="$tmp/lnf/org.cyberkde.desktop"
mkdir -p "$(dirname "$lnf")"
cp -a "$data/plasma/look-and-feel/org.cyberkde.desktop" "$lnf"
cat >"$lnf/contents/defaults" <<'EOF'
[kdeglobals][KDE]
widgetStyle=kvantum

[kdeglobals][General]
ColorScheme=CyberKDE

[kdeglobals][Icons]
Theme=CyberKDE

[plasmarc][Theme]
name=CyberKDE

[Wallpaper]
Image=CyberKDE

[kcminputrc][Mouse]
cursorTheme=breeze_cursors

[kwinrc][org.kde.kdecoration2]
library=org.kde.kwin.aurorae
theme=__aurorae__svg__CyberKDE

[KSplash]
Theme=org.cyberkde.desktop
EOF
python3 - "$lnf/metadata.json" <<'EOF'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
k = d["KPlugin"]
k["Name"] = "CyberKDE"
k["Description"] = ("Neo-military global theme for Plasma 6: colors, Kvantum style, window decoration, "
                    "Plasma style, icons, splash and wallpaper. Install the CyberKDE parts first.")
k["Description[pt_BR]"] = ("Tema global neomilitar para o Plasma 6: cores, estilo Kvantum, moldura das janelas, "
                           "estilo do Plasma, ícones, splash e papel de parede. Instale antes as peças do CyberKDE.")
json.dump(d, open(path, "w"), ensure_ascii=False, indent=4)
EOF
mkdir -p "$lnf/contents/previews"
# Prévias provisórias (o papel de parede); troque por capturas reais em assets/loja/, se existirem.
for f in preview.png fullscreenpreview.jpg; do
  if [[ -f $project/assets/loja/$f ]]; then
    cp "$project/assets/loja/$f" "$lnf/contents/previews/$f"
  fi
done
[[ -f $lnf/contents/previews/fullscreenpreview.jpg ]] ||
  magick "$project/assets/wallpapers/desktop.png" -quality 90 "$lnf/contents/previews/fullscreenpreview.jpg"
[[ -f $lnf/contents/previews/preview.png ]] ||
  magick "$project/assets/wallpapers/desktop.png" -resize 600x338 "$lnf/contents/previews/preview.png"

echo "Pacotes em $out:"
pack "CyberKDE-global-theme-$version.tar.gz" "$(dirname "$lnf")" org.cyberkde.desktop
pack "CyberKDE-plasma-style-$version.tar.gz" "$data/plasma/desktoptheme" CyberKDE
pack "CyberKDE-window-decoration-$version.tar.gz" "$data/aurorae/themes" CyberKDE
pack "CyberKDE-kvantum-$version.tar.gz" "$cfg/Kvantum" CyberKDE
pack "CyberKDE-icons-$version.tar.gz" "$data/icons" CyberKDE
pack "CyberKDE-sddm-$version.tar.gz" "$project/modules/login/build/sddm" cyberkde
pack "CyberKDE-wallpaper-$version.tar.gz" "$tmp/wallpaper" CyberKDE
pack "CyberKDE-kwin-scan-$version.tar.gz" "$data/kwin/effects" cyberkde_scan
pack "CyberKDE-kwin-popups-$version.tar.gz" "$data/kwin/effects" cyberkde_popups
install -m644 "$data/color-schemes/CyberKDE.colors" "$out/CyberKDE.colors" && echo "  CyberKDE.colors"
install -m644 "$data/konsole/CyberKDE.colorscheme" "$out/CyberKDE.colorscheme" && echo "  CyberKDE.colorscheme"
