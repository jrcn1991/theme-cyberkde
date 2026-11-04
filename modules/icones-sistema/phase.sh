# modules/icones-sistema/phase.sh — tema de ícones CyberKDE no sistema todo.
#
# A fase "icones" (em scripts/cyberkde) grava [Icons] Theme só no dolphinrc, e vale só no Dolphin.
# Esta grava no kdeglobals, e vale para o Plasma e todos os apps KDE/Qt.
# O tema já é gerado (generator/gen_icons.py) e instalado em ~/.local/share/icons/CyberKDE
# pelo install_files do cyberkde; aqui não se repete isso.
# Carregado com "source": só define funções e registra nomes.

CYBERKDE_PHASES+=(icones-sistema)
descreve_fase icones-sistema "Ícones do sistema" sistema nao "Ícones do tema no Plasma e em todos os apps." \
  "System icons" "Theme icons in Plasma and every app."
CYBERKDE_OFF_HOOKS+=(off_icones-sistema)

# Avisa os aplicativos abertos que o tema de ícones mudou, como faz o plasma-changeicons:
# KIconLoader (apps KF6) e KGlobalSettings/IconChanged=4 (integração Qt do Plasma).
icones_sistema_avisar() {
  command -v dbus-send >/dev/null || return 0
  dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:0 >/dev/null 2>&1 || true
  dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:4 int32:0 >/dev/null 2>&1 || true
}

phase_icones-sistema() {
  [[ -f $data/icons/CyberKDE/index.theme ]] || { echo "Tema de ícones CyberKDE não instalado (rode 'cyberkde install')." >&2; return 1; }
  set_key kdeglobals Icons Theme CyberKDE
  icones_desktops_aplicar
  icones_sistema_avisar
}

# Apps com ícone por caminho absoluto (Icon=/snap/...png) não passam pelo tema de ícones: uma cópia de
# usuário do .desktop em ~/.local/share/applications, com só o Icon= trocado pelo nome do tema
# (assets/icons/apps/desktop-icones.json, do generator/gen_apps_icons.py). A base é o .desktop original,
# lido na hora; sem original, ou com uma cópia de usuário que não é do tema, nada. O "off" remove as cópias.
icones_desktops_aplicar() {
  local mapa="$project/assets/icons/apps/desktop-icones.json" f nome d orig dst
  [[ -f $mapa ]] || return 0
  while IFS=$'\t' read -r f nome; do
    [[ $f == *.desktop && $f != */* && -n $nome ]] || continue
    dst="$data/applications/$f"
    # Já existe uma do usuário que não foi o tema que pôs: é dela.
    if [[ -e $dst ]] && ! grep -qsF -- "$dst"$'\t' "$files"; then continue; fi
    orig=""
    for d in /var/lib/snapd/desktop/applications /usr/local/share/applications /usr/share/applications \
      /var/lib/flatpak/exports/share/applications "$data/flatpak/exports/share/applications"; do
      [[ -f $d/$f ]] && { orig=$d/$f; break; }
    done
    [[ -n $orig ]] || continue
    grep -q '^Icon=/' "$orig" || continue  # o original já usa um nome: o tema cobre sozinho
    sed "s|^Icon=/.*|Icon=$nome|" "$orig" | put_file "$dst"
  done < <(python3 -c 'import json, sys
for k, v in json.load(open(sys.argv[1], encoding="utf-8")).items():
    print("%s\t%s" % (k, v))' "$mapa" 2>/dev/null)
  command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
}

# O "off" já restaurou o kdeglobals pelo registro; falta avisar quem está aberto.
off_icones-sistema() {
  icones_sistema_avisar
}
