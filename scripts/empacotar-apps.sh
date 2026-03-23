#!/usr/bin/env bash
# empacotar-apps.sh — gera o .deb do Dolphin ou do Konsole com o patch do CyberKDE, para o Ubuntu 26.04.
#
#   scripts/empacotar-apps.sh dolphin|konsole [pasta-de-saída]
#
# Roda como root DENTRO de um contêiner ubuntu:26.04 (o workflow .github/workflows/apps.yml usa a imagem
# fixada por digest). Compila a MESMA versão do app que o Ubuntu distribui, com o patch de <app>/*.patch,
# em /opt/cyberkde-<app>, e empacota como "cyberkde-<app>" (não substitui o app do sistema: o tema troca
# só o atalho e o comando, e o "off" devolve os originais). Assim ninguém compila nada no próprio PC.
# Saída: cyberkde-<app>_<versão>-cyberkde1_amd64.deb e o .sha256 ao lado.

set -euo pipefail

app=${1:?uso: empacotar-apps.sh dolphin|konsole [saída]}
out=${2:-$PWD/dist/apps}
case $app in
  dolphin) repo=system/dolphin ;;
  konsole) repo=utilities/konsole ;;
  *) echo "app desconhecido: $app" >&2; exit 2 ;;
esac
project="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
export DEBIAN_FRONTEND=noninteractive

# Código-fonte do apt para o build-dep (a imagem vem só com "deb").
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get build-dep -y -qq "$app" >/dev/null
apt-get install -y -qq git ninja-build dpkg-dev "$app" >/dev/null

debver=$(dpkg-query -W -f='${Version}' "$app")   # ex.: 4:25.12.3-0ubuntu1
version=${debver#*:}
version=${version%%-*}                             # ex.: 25.12.3
prefix=/opt/cyberkde-$app
multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
work=$(mktemp -d)

git clone -q --depth 1 -b "v$version" "https://invent.kde.org/$repo.git" "$work/src"
git -C "$work/src" apply "$project/$app/"*.patch
cmake -S "$work/src" -B "$work/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_RPATH="$prefix/lib/$multiarch;$prefix/lib" >/dev/null
cmake --build "$work/build"
DESTDIR="$work/pkg" cmake --install "$work/build" >/dev/null
echo "$version" >"$work/pkg$prefix/.cyberkde-version"

pkgver="$version-cyberkde1"
mkdir -p "$work/pkg/DEBIAN"
# Só o app do sistema como dependência: ele traz as bibliotecas de que o binário precisa. Sem versão
# exata, para não travar as atualizações do Ubuntu; o tema confere a versão antes de usar o pacote.
cat >"$work/pkg/DEBIAN/control" <<EOF
Package: cyberkde-$app
Version: $pkgver
Architecture: amd64
Maintainer: CyberKDE <https://github.com/jrcn1991/theme-cyberkde>
Depends: $app
Section: kde
Priority: optional
Homepage: https://github.com/jrcn1991/theme-cyberkde
Description: $app $version with the CyberKDE animation patch
 Built from the $app $version source with the patch in the CyberKDE theme
 repository and installed in $prefix. It does not replace the system $app:
 the CyberKDE theme points its launcher at this build and "cyberkde off"
 points it back.
EOF
mkdir -p "$out"
deb="$out/cyberkde-${app}_${pkgver}_amd64.deb"
dpkg-deb --root-owner-group --build "$work/pkg" "$deb" >/dev/null
(cd "$out" && sha256sum "$(basename "$deb")" >"$(basename "$deb").sha256")
rm -rf "$work"
echo "$deb"
cat "$deb.sha256"
