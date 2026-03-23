# modules/icones-sistema/phase.sh — tema de ícones CyberKDE no sistema todo.
#
# A fase "icones" (em scripts/cyberkde) grava [Icons] Theme só no dolphinrc, e vale só no Dolphin.
# Esta grava no kdeglobals, e vale para o Plasma e todos os apps KDE/Qt.
# O tema já é gerado (generator/gen_icons.py) e instalado em ~/.local/share/icons/CyberKDE
# pelo install_files do cyberkde; aqui não se repete isso.
# Carregado com "source": só define funções e registra nomes.

CYBERKDE_PHASES+=(icones-sistema)
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
  icones_sistema_avisar
}

# O "off" já restaurou o kdeglobals pelo registro; falta avisar quem está aberto.
off_icones-sistema() {
  icones_sistema_avisar
}
