# modules/papeis-de-parede/phase.sh — papéis de parede CyberKDE (área de trabalho + bloqueio).
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# Imagens: geradas em assets/wallpapers/ (generator/gen_wallpapers.sh) e copiadas pelo
# install para ~/.local/share/wallpapers/CyberKDE/. O Plasma e o greeter apontam para a cópia,
# e não para o projeto (o caminho tem espaço e acento e pode mudar de lugar).
# O login.png fica em assets/wallpapers/ para o módulo da tela de login (SDDM), que copia por conta própria.
#
# Área de trabalho: as contenções têm IDs dinâmicos no plasma-org.kde.plasma.desktop-appletsrc, por isso
# não passa por set_key. Antes de trocar, a fase grava ID, tela, plugin e imagem de cada área de trabalho em
# $state/papeis-de-parede.tsv (só na primeira vez); o off_papeis-de-parede devolve tudo pelo mesmo caminho.

CYBERKDE_PHASES+=(papeis-de-parede)
CYBERKDE_INSTALLS+=(install_papeis-de-parede)
CYBERKDE_OFF_HOOKS+=(off_papeis-de-parede)

wallpapers_dir() { printf '%s\n' "$data/wallpapers/CyberKDE"; }
wallpapers_record() { printf '%s\n' "$state/papeis-de-parede.tsv"; }  # id  tela  plugin  imagem

install_papeis-de-parede() {
  local src="$project/assets/wallpapers" f
  for f in desktop lockscreen login; do
    [[ -f $src/$f.png ]] || { bash "$project/modules/papeis-de-parede/generator/gen_wallpapers.sh" >/dev/null; break; }
  done
  install -Dm644 -t "$(wallpapers_dir)" "$src/desktop.png" "$src/lockscreen.png" "$src/login.png"
}

# Texto seguro dentro de aspas duplas no JavaScript do Plasma.
wallpapers_js() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }

# Registra o estado atual das áreas de trabalho (só leitura do appletsrc), uma vez.
# Uma contenção é área de trabalho quando tem wallpaperplugin, atividade e tela (lastScreen >= 0)
# e não é painel nem bandeja.
wallpapers_save() {
  local rec appletsrc="$config/plasma-org.kde.plasma.desktop-appletsrc" id plugin wp screen act img
  rec=$(wallpapers_record)
  [[ -s $rec ]] && return 0
  mkdir -p "$state"
  : >"$rec.tmp"
  while read -r id; do
    plugin=$(kreadconfig6 --file "$appletsrc" --group Containments --group "$id" --key plugin)
    wp=$(kreadconfig6 --file "$appletsrc" --group Containments --group "$id" --key wallpaperplugin)
    act=$(kreadconfig6 --file "$appletsrc" --group Containments --group "$id" --key activityId)
    screen=$(kreadconfig6 --file "$appletsrc" --group Containments --group "$id" --key lastScreen --default -1)
    [[ -n $wp && -n $act && $screen -ge 0 && $plugin != org.kde.panel && $plugin != *systemtray* ]] || continue
    img=$(kreadconfig6 --file "$appletsrc" --group Containments --group "$id" --group Wallpaper \
      --group org.kde.image --group General --key Image)
    printf '%s\t%s\t%s\t%s\n' "$id" "$screen" "$wp" "$img" >>"$rec.tmp"
  done < <(grep -soE '^\[Containments\]\[[0-9]+\]$' "$appletsrc" | grep -oE '[0-9]+')
  mv "$rec.tmp" "$rec"
}

# Troca plugin e imagem de uma área de trabalho. Com o plasmashell rodando usa o script do Plasma
# (efeito imediato); sem ele, grava direto no appletsrc (seguro, pois ninguém vai sobrescrever).
# Entrada: linhas "id<TAB>tela<TAB>plugin<TAB>imagem"; id "*" = todas as áreas de trabalho.
# (Campo vazio não serve: tab é espaço em branco para o read, e o campo sumiria.)
wallpapers_set() {
  local js='' id screen wp img appletsrc="$config/plasma-org.kde.plasma.desktop-appletsrc"
  local -a lines=()
  mapfile -t lines
  if qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
    for line in "${lines[@]}"; do
      IFS=$'\t' read -r id screen wp img <<<"$line"
      js+="apply(\"$(wallpapers_js "$id")\", ${screen:--1}, \"$(wallpapers_js "$wp")\", \"$(wallpapers_js "$img")\");"
    done
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
      function apply(id, screen, plugin, image) {
        var all = desktops(), hit = [];
        for (var i = 0; i < all.length; i++)
          if (id === '*' || String(all[i].id) === id) hit.push(all[i]);
        if (hit.length === 0 && screen >= 0)
          for (var j = 0; j < all.length; j++) if (all[j].screen === screen) hit.push(all[j]);
        for (var k = 0; k < hit.length; k++) {
          var d = hit[k];
          d.wallpaperPlugin = plugin;
          d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
          d.writeConfig('Image', image);
          d.reloadConfig();
        }
      }
      $js" >/dev/null
  elif ! pgrep -x plasmashell >/dev/null; then
    for line in "${lines[@]}"; do
      IFS=$'\t' read -r id screen wp img <<<"$line"
      [[ $id != '*' ]] || continue  # "todas" só pelo script; sem Plasma rodando, só a volta por ID
      kwriteconfig6 --file "$appletsrc" --group Containments --group "$id" --key wallpaperplugin "$wp"
      kwriteconfig6 --file "$appletsrc" --group Containments --group "$id" --group Wallpaper \
        --group org.kde.image --group General --key Image "$img"
    done
  else
    echo "papeis-de-parede: o plasmashell não respondeu; área de trabalho não alterada." >&2
    return 1
  fi
}

# Imagem própria escolhida com "cyberkde papel /caminho/imagem" (gravada em ~/.config/cyberkde/
# papel-de-parede); CYBERKDE_WALLPAPER=/caminho/imagem vale por cima, só naquela execução.
wallpapers_own() {
  local own=${CYBERKDE_WALLPAPER:-}
  if [[ -z $own && -s $config/cyberkde/papel-de-parede ]]; then own=$(<"$config/cyberkde/papel-de-parede"); fi
  printf '%s\n' "$own"
}

# Imagem da área de trabalho e do bloqueio: a própria, se existir; senão, as do tema.
wallpapers_image() {  # desktop|lockscreen
  local own
  own=$(wallpapers_own)
  if [[ -n $own && -f $own ]]; then
    printf '%s\n' "$own"
  else
    printf '%s\n' "$(wallpapers_dir)/$1.png"
  fi
}

phase_papeis-de-parede() {
  local dir
  dir=$(wallpapers_dir)
  [[ -f $dir/desktop.png && -f $dir/lockscreen.png ]] || install_papeis-de-parede

  # Área de trabalho (todas as telas): registra o original e troca.
  wallpapers_save
  printf '*\t-1\torg.kde.image\tfile://%s\n' "$(wallpapers_image desktop)" | wallpapers_set

  # Tela de bloqueio: kscreenlockerrc [Greeter] e [Greeter][Wallpaper][org.kde.image][General].
  set_key kscreenlockerrc Greeter WallpaperPlugin org.kde.image
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" Image "file://$(wallpapers_image lockscreen)"
}

# O "off" já devolveu as chaves do kscreenlockerrc; aqui volta a área de trabalho de cada tela.
off_papeis-de-parede() {
  local rec
  rec=$(wallpapers_record)
  [[ -s $rec ]] || { rm -f -- "$rec"; return 0; }  # registro vazio: nada a devolver
  if wallpapers_set <"$rec"; then
    rm -f "$rec"
  else
    # Precisa devolver 1: o cmd_off apaga ledger/files e sairia 0, escondendo a falha, e o
    # papel de parede ficaria preso no do CyberKDE.
    echo "papeis-de-parede: registro mantido em $rec para tentar de novo." >&2
    return 1
  fi
}
