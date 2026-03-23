#!/usr/bin/env bash
# desinstalar.sh — desliga o CyberKDE, devolve tudo ao original e remove o tema e o programa.
# É o mesmo que "cyberkde uninstall".
set -euo pipefail

instalado="$HOME/.local/opt/cyberkde/scripts/cyberkde"
if [[ -x $instalado ]]; then
  exec "$instalado" uninstall
fi
# Não instalado pelo instalar.sh: usa o script desta pasta (remove o tema, não a pasta).
exec "$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/scripts/cyberkde" uninstall
