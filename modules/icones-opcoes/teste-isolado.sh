#!/usr/bin/env bash
# Teste isolado (sem tocar na sessão): corporação X com estilo=marca, HOME falso com ícones de app "instalados",
# pelo CLI (cyberkde corp ... e cyberkde install) como o painel chama (--json --sem-sudo --progresso, env limpo,
# barramento D-Bus próprio). Uso: teste-isolado.sh <corp> [estilo]    (corp: arasaka, militech...)
set -euo pipefail
origem="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
corp=${1:-arasaka} estilo=${2:-marca}
# O cyberkde regenera arquivos versionados dentro do projeto (themes/): roda numa CÓPIA, nunca no repositório.
projeto=$(mktemp -d /tmp/cyberkde-teste-projeto.XXXX)
# A cópia tem ~600 MB: sai no fim (MANTER=1 a guarda para inspeção).
[[ ${MANTER:-0} == 1 ]] || trap 'rm -rf -- "$projeto"' EXIT
tar -C "$origem" --exclude=.git --exclude=build --exclude=imagens-referencia --exclude=__pycache__ -cf - . | tar -C "$projeto" -xf -
fh=$(mktemp -d /tmp/cyberkde-teste-icones.XXXX); mkdir -p "$fh/.config/cyberkde" "$fh/.local/share/icons/hicolor/256x256/apps" "$fh/run"; chmod 700 "$fh/run"
for n in claude-desktop steam google-chrome; do cp "/usr/share/icons/hicolor/256x256/apps/$n.png" "$fh/.local/share/icons/hicolor/256x256/apps/" 2>/dev/null || true; done
printf '[icones-apps]\nestilo=%s\n' "$estilo" > "$fh/.config/cyberkde/efeitos"
amb=(env -i HOME="$fh" PATH=/usr/bin:/bin:/usr/local/bin XDG_RUNTIME_DIR="$fh/run" CYBERKDE_SEM_SUDO=1 CYBERKDE_LANG=pt_BR)
"${amb[@]}" dbus-run-session -- timeout 120 "$projeto/scripts/cyberkde" corp "$corp" --json --sem-sudo --progresso >/dev/null 2>&1 || true
"${amb[@]}" dbus-run-session -- timeout 250 "$projeto/scripts/cyberkde" install >/dev/null 2>"$fh/install.err" || { echo "install falhou"; tail -5 "$fh/install.err"; }
d="$fh/.local/share/icons/CyberKDE/apps/128"
python3 - "$d" "$projeto" <<'PY'
import sys,hashlib,os
from PIL import Image
d,proj=sys.argv[1:]
for n in ("claude-desktop","steam","google-chrome"):
    f=os.path.join(d,n+".png")
    if not os.path.exists(f): print(n,"AUSENTE"); continue
    im=Image.open(f).convert("RGBA"); w,h=im.size
    # marca: o miolo tem as cores do logo original (laranja do Claude etc.); silhueta: só vermelho/ciano/escuro do mestre
    px=im.getpixel((w//2,h//2)); print(n,"pixel central",px[:3])
PY
[[ ${MANTER:-0} == 1 ]] && echo "projeto copiado: $projeto"
echo "corp=$(cat "$fh/.config/cyberkde/corp" 2>/dev/null) estilo=$estilo  (HOME falso: $fh)"
