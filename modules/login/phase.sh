# modules/login/phase.sh — tela de login (SDDM), splash (KSplash) e tela de bloqueio CyberKDE.
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
#   login           tema SDDM "cyberkde" (sudo), splash org.cyberkde.desktop e fundo CyberKDE na
#                   tela de bloqueio padrão. Entra no "cyberkde on" (tudo).
#   login-bloqueio  OPCIONAL (fora do "on" geral): troca a interface da tela de bloqueio pela
#                   CyberKDE. No Plasma 6.6 ela vem do pacote de shell e não existe chave que a
#                   escolha sem trocar também o shell do plasmashell (ver NOTES.md). Exige sudo.

CYBERKDE_PHASES+=(login)
CYBERKDE_INSTALLS+=(install_login)

# Gera tudo a partir dos tokens e instala na pasta do usuário (nada em /usr ou /etc aqui).
install_login() {
  local build="$project/modules/login/build"
  python3 "$project/modules/login/generator/gen_login.py" >/dev/null
  mkdir -p "$data/plasma/look-and-feel"
  swap_dir "$build/look-and-feel/org.cyberkde.desktop" "$data/plasma/look-and-feel/org.cyberkde.desktop"
  install -Dm644 "$build/wallpaper/login.png" "$data/cyberkde/login/login.png"
}

phase_login() {
  # Tela de login só onde o gerenciador de login é o SDDM; o splash e o bloqueio valem sempre.
  if [[ -d /usr/share/sddm/themes ]]; then
    login_sddm
  else
    echo "  (sem SDDM: a tela de login fica como está)"
  fi
  # Splash: o padrão atual vem de ~/.config/kdedefaults/ksplashrc (Breeze Escuro); o "off" apaga
  # estas chaves e o padrão volta sozinho.
  set_key ksplashrc KSplash Engine KSplashQML
  set_key ksplashrc KSplash Theme org.cyberkde.desktop
  # Tela de bloqueio padrão (interface Breeze) com o mesmo fundo do login.
  set_key kscreenlockerrc Greeter WallpaperPlugin org.kde.image
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" Image "file://$data/cyberkde/login/login.png"
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" PreviewImage "file://$data/cyberkde/login/login.png"
}

login_sddm() {  # fora do padrão phase_*: não é uma fase avulsa
  local build="$project/modules/login/build"
  # SDDM: tema em /usr/share e seleção num arquivo próprio em /etc/sddm.conf.d, lido em ordem
  # alfabética (o último vence). "zz-" fica depois de "20-kubuntu.conf" e também do "kde_settings.conf",
  # que as Configurações do Sistema escrevem ao mexer no login (o antigo "cyberkde.conf" perdia dele).
  put_dir "$build/sddm/cyberkde" /usr/share/sddm/themes/cyberkde
  printf '[Theme]\nCurrent=cyberkde\n' | put_file /etc/sddm.conf.d/zz-cyberkde.conf
}

# Opcional: "cyberkde on login-bloqueio". Mexe só no ponto de entrada da tela de bloqueio do shell do
# Plasma (LockScreen.qml, 1 arquivo pequeno) e acrescenta a pasta cyberkde/ ao lado; o "off" devolve
# o original. Se o QML falhar, o kscreenlocker cai sozinho no bloqueio interno de emergência.
phase_login-bloqueio() {
  local build="$project/modules/login/build"
  local lock=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen
  if [[ ! -f $lock/LockScreen.qml || ! -f $lock/PasswordSync.qml ]]; then
    echo "A estrutura da tela de bloqueio do Plasma mudou; nada foi aplicado." >&2
    return 1
  fi
  put_dir "$build/lockscreen/cyberkde" "$lock/cyberkde"
  put_file "$lock/LockScreen.qml" <"$build/lockscreen/LockScreen.qml"
}
