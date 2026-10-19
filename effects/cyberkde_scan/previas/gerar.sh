#!/usr/bin/env bash
# gerar.sh — grava as prévias das animações de janelas num KWin VIRTUAL e monta os WebP.
#
#   effects/cyberkde_scan/previas/gerar.sh [id ...]
#
# Nada aparece na tela de quem roda: kwin_wayland --virtual, HOME/TMPDIR/XDG_RUNTIME_DIR temporários e
# sessão D-Bus própria (sessao.sh). Cada animação roda em câmera lenta (16 s) e é fotografada sem
# parar com o spectacle; o montar.py escolhe as fotos pelo progresso e grava
# assets/previas/janelas/<id>-abrir.webp e <id>-fechar.webp (320×200, em loop).
# Precisa de Python 3 com Pillow (com WebP).
set -euo pipefail
aqui="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
project="$(cd -- "$aqui/../../.." && pwd)"
fotos=$(mktemp -d)
trap 'rm -rf "$fotos"' EXIT
IDS="$*" FOTOS="$fotos" LENTO=16000 "$aqui/sessao.sh" "$aqui/cena.sh" >"$fotos/sessao.log" 2>&1
python3 "$aqui/montar.py" "$fotos" "$project/assets/previas/janelas" 16000
cp "$fotos/prancha-kwin.png" "${TMPDIR:-/tmp}/cyberkde-previas-janelas.png" 2>/dev/null || true
