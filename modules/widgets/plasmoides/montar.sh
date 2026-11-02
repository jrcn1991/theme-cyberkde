#!/usr/bin/env bash
# Monta os pacotes dos widgets CyberKDE em DESTINO (um diretório por plasmoide, prontos para
# kpackagetool6 --install ou cópia em ~/.local/share/plasma/plasmoids): copia o pacote e põe os
# componentes comuns (modules/widgets/comum) em contents/ui/comum de cada um, com a Paleta padrão
# (o install_widgets do CLI faz o mesmo e grava a Paleta aplicada).
#   uso: montar.sh DESTINO [id...]   (sem ids: todos os org.cyberkde.*)
set -euo pipefail
aqui=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
destino=${1:?uso: montar.sh DESTINO [id...]}
shift
ids=("$@")
if (( ${#ids[@]} == 0 )); then
  for d in "$aqui"/org.cyberkde.*/; do ids+=("$(basename "$d")"); done
fi
mkdir -p "$destino"
for id in "${ids[@]}"; do
  [[ -f $aqui/$id/metadata.json ]] || { echo "pacote inexistente: $id" >&2; exit 2; }
  rm -rf "${destino:?}/$id"
  cp -r "$aqui/$id" "$destino/$id"
  mkdir -p "$destino/$id/contents/ui/comum"
  cp "$aqui"/../comum/* "$destino/$id/contents/ui/comum/"
  echo "$destino/$id"
done
