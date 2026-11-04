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
descreve_fase papeis-de-parede "Papel de parede" sistema nao "Papel de parede do tema na área de trabalho e na tela de bloqueio." \
  "Wallpaper" "Theme wallpaper on the desktop and the lock screen."
CYBERKDE_INSTALLS+=(install_papeis-de-parede)
CYBERKDE_OFF_HOOKS+=(off_papeis-de-parede)
CYBERKDE_EFEITOS+=(papel)  # "cyberkde efeito papel <a|b|c|d|corp|fui>": a opção de papel de parede (modules/CONTRATO.md)
CYBERKDE_INSTALLS+=(install_papel_fui)

wallpapers_dir() { printf '%s\n' "$data/wallpapers/CyberKDE"; }
wallpapers_record() { printf '%s\n' "$state/papeis-de-parede.tsv"; }  # id  tela  plugin  imagem

# Opção de papel de parede: a (a do tema, em assets/wallpapers) ou b, c, d (assets/wallpapers/opcoes/*.webp;
# o gerador gen_opcao.py deriva bloqueio e login delas, como o gen_wallpapers.sh faz com a opção A).
# A escolha é uma preferência em ~/.config/cyberkde/efeitos, grupo [papel], chave opcao.
papel_opcao() {
  local v
  v=$(kreadconfig6 --file "$config/cyberkde/efeitos" --group papel --key opcao --default a 2>/dev/null)
  case $v in a | b | c | d | corp | fui) printf '%s\n' "$v" ;; *) echo a ;; esac
}

# ------------------------------------------------------------------ papel animado FUI (org.cyberkde.fui)
# Plugin de papel de parede do Plasma 6 (modules/papeis-de-parede/animado, LEIAME.md lá). A área de
# trabalho usa o plugin (chave Corporacao = a corporação do "cyberkde corp"); o bloqueio e o login
# usam o quadro estático dele (gen_fui.py estatico, 3840x2160), da mesma corporação. Os .qsb vêm
# compilados no pacote: a instalação não precisa do qsb.
papel_fui_src="$project/modules/papeis-de-parede/animado"
papel_fui_plugin=org.cyberkde.fui
# Corporação do FUI: a do "cyberkde corp"; sem corporação (ou cor personalizada), a do próprio tema.
papel_fui_corp() {
  local id
  id=$(corp_atual 2>/dev/null) || id=nenhuma
  case $id in "" | personalizada) id=nenhuma ;; esac
  printf '%s\n' "$id"
}
# O pacote em ~/.local/share/plasma/wallpapers (fica em "Papel de parede" das Configurações também
# com outra opção escolhida; fora do registro, como os widgets: o uninstall remove).
install_papel_fui() {
  [[ -f $papel_fui_src/$papel_fui_plugin/metadata.json ]] || return 0
  local tmp
  tmp=$(mktemp -d)
  cp -a -- "$papel_fui_src/$papel_fui_plugin/." "$tmp/"
  chmod 755 "$tmp"
  swap_dir "$tmp" "$data/plasma/wallpapers/$papel_fui_plugin"
  rm -rf -- "$tmp"
}
# Controles do FUI (o painel, pelo contrato do Deckard): preferência em ~/.config/cyberkde/efeitos
# [papel-fui] e gravados nas chaves do plugin em cada área de trabalho com ele. Sem escolha, os padrões
# do main.xml do pacote.
papel_fui_pref() { kreadconfig6 --file "$config/cyberkde/efeitos" --group papel-fui --key "$1" --default "$2" 2>/dev/null; }
papel_fui_json() {  # -> {"intensidade":N,"velocidade":N,"fps":N,"logo":b,"textos":b,"pausar":b}
  local v k i=() b=()
  for k in intensidade:100 velocidade:100 fps:30; do
    v=$(papel_fui_pref "${k%%:*}" "${k#*:}"); [[ $v =~ ^[0-9]+$ ]] || v=${k#*:}; i+=("$v")
  done
  for k in logo textos pausar; do
    [[ $(papel_fui_pref "$k" true) == false ]] && b+=(false) || b+=(true)
  done
  printf '{"intensidade":%d,"velocidade":%d,"fps":%d,"logo":%s,"textos":%s,"pausar":%s}' "${i[@]}" "${b[@]}"
}
# As mesmas, com os nomes das chaves do plugin (objeto JS).
papel_fui_chaves() {
  local j
  j=$(papel_fui_json)
  python3 -c 'import json, sys; d = json.loads(sys.argv[1])
print(json.dumps({"Intensidade": d["intensidade"], "Velocidade": d["velocidade"], "FpsMax": d["fps"],
                  "MostrarLogo": d["logo"], "MostrarTextos": d["textos"], "PausarCoberto": d["pausar"]}))' "$j"
}
# Ao vivo: grava as chaves nas áreas de trabalho que estão com o FUI (o plugin lê a configuração na hora:
# sem reiniciar o plasmashell). Sem plasmashell, nada (o próximo "on" grava pelo wallpapers_set).
papel_fui_ao_vivo() {
  qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || return 0
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var c = $(papel_fui_chaves), ds = desktops(), n = 0;
    for (var i = 0; i < ds.length; i++) { var d = ds[i]; if (d.wallpaperPlugin != 'org.cyberkde.fui') continue;
      d.currentConfigGroup = ['Wallpaper', 'org.cyberkde.fui', 'General'];
      for (var k in c) d.writeConfig(k, c[k]);
      d.reloadConfig(); n++; }
    print(n);" 2>/dev/null
}

# Quadro estático da corporação, em cache (refeito quando o gerador, a cena, as cores ou os logos mudam).
# Renderiza num Xvfb (nada aparece na sessão); o QT_QPA_PLATFORM=xcb é obrigatório: na sessão Wayland o
# Qt ignoraria o DISPLAY do Xvfb e abriria a janela na tela da pessoa. Sem Xvfb, usa a sessão (o
# gerador abre uma janela fora da vista, que fecha sozinha).
papel_fui_estatico() {  # id -> caminho do PNG
  local id=$1 out="$project/modules/papeis-de-parede/build/fui/$1.png" gen="$papel_fui_src/gen_fui.py" f velho=0
  if [[ -f $out ]]; then
    for f in "$gen" "$papel_fui_src/$papel_fui_plugin/contents/ui/Cena.qml" "$project/tokens/corporacoes.json" \
      "$project/assets/corporacoes/$id-logo.svg" "$project/assets/corporacoes/$id.svg"; do
      [[ -f $f && $f -nt $out ]] && velho=1
    done
  else
    velho=1
  fi
  if (( velho )); then
    mkdir -p -- "$(dirname -- "$out")"
    if command -v xvfb-run >/dev/null; then
      env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=xcb \
        xvfb-run -a -s "-screen 0 3840x2160x24 +extension GLX" python3 "$gen" estatico "$id" "$out.novo.png" >/dev/null || return 1
    else
      python3 "$gen" estatico "$id" "$out.novo.png" >/dev/null || return 1
    fi
    mv -f -- "$out.novo.png" "$out"
  fi
  printf '%s\n' "$out"
}
# Corporação atual ("cyberkde corp") quando ela tem papel próprio (logo vetorial em assets/corporacoes);
# senão falha, e a opção corp cai na A.
papel_corp_id() {
  local id
  id=$(corp_atual 2>/dev/null) || return 1
  case $id in "" | nenhuma | personalizada) return 1 ;; esac
  [[ -f $project/assets/corporacoes/$id-logo.svg ]] || return 1
  printf '%s\n' "$id"
}
# Sufixo do arquivo instalado: nenhum na opção a (como sempre foi) e -b/-c/-d nas outras. O caminho muda
# com a opção, e assim o Plasma e o bloqueio recarregam a imagem na troca.
papel_sufixo() { local o; o=$(papel_opcao); [[ $o == a ]] || printf -- '-%s' "$o"; }
# Pasta com desktop/lockscreen/login.png de uma opção (gera b, c e d quando faltam ou estão velhas).
papel_origem() {  # opção
  local o=$1 gen="$project/modules/papeis-de-parede/generator/gen_opcao.py" dir id
  if [[ $o == a ]]; then printf '%s\n' "$project/assets/wallpapers"; return 0; fi
  if [[ $o == fui ]]; then
    # Os três (desktop, lockscreen, login) são o mesmo quadro estático; a área de trabalho usa o plugin,
    # o desktop.png é a reserva (e o que o login usa com fundo=papel).
    local png
    png=$(papel_fui_estatico "$(papel_fui_corp)") || { papel_origem a; return; }
    dir="$project/modules/papeis-de-parede/build/fui/opcao"
    mkdir -p -- "$dir"
    for f in desktop lockscreen login; do ln -sfn -- "$png" "$dir/$f.png"; done
    printf '%s\n' "$dir"
    return 0
  fi
  if [[ $o == corp ]]; then
    # Papel da corporação atual (gen_corp.py), em cache; refaz só quando a paleta, o logo ou o gerador mudam.
    id=$(papel_corp_id) || { papel_origem a; return; }
    gen="$project/modules/papeis-de-parede/generator/gen_corp.py"
    dir="$project/modules/papeis-de-parede/build/corp/$id"
    if [[ ! -f $dir/login.png || ! -f $dir/.carimbo || $(<"$dir/.carimbo") != "$(python3 "$gen" --carimbo "$id")" ]]; then
      python3 "$gen" "$id" --saida "$dir" >/dev/null || return 1
    fi
    printf '%s\n' "$dir"
    return 0
  fi
  dir="$project/modules/papeis-de-parede/build/$o"
  if [[ ! -f $dir/login.png || $gen -nt $dir/login.png ]] || [[ -n $(find "$project/assets/wallpapers/opcoes" -name "$o-*.webp" -newer "$dir/login.png" 2>/dev/null) ]]; then
    python3 "$gen" "$o" --saida "$dir" >/dev/null || return 1
  fi
  printf '%s\n' "$dir"
}
# Caminho instalado da imagem do tema na opção atual (desktop|lockscreen|login).
papel_instalado() { printf '%s/%s%s.png\n' "$(wallpapers_dir)" "$1" "$(papel_sufixo)"; }

install_papeis-de-parede() {
  local opcao src f cru=0
  install_papel_fui
  opcao=$(papel_opcao)
  src=$(papel_origem "$opcao") || return 1
  [[ $opcao == corp && $src == */build/corp/* ]] && cru=1  # já sai na paleta da corporação
  [[ $opcao == fui && $src == */build/fui/* ]] && cru=1
  for f in desktop lockscreen login; do
    [[ -f $src/$f.png ]] || { bash "$project/modules/papeis-de-parede/generator/gen_wallpapers.sh" >/dev/null; break; }
  done
  # Os detalhes vermelhos acompanham a cor de destaque ("cyberkde cor"): com outra cor, instala a cópia
  # recolorida (cache em ~/.cache/cyberkde). O Plasma aponta sempre para o mesmo caminho instalado.
  local -a imgs=()
  if (( cru )); then
    imgs=("$src"/desktop.png "$src"/lockscreen.png "$src"/login.png)
  else
    mapfile -t imgs < <(python3 - "$project/generator" "$src"/{desktop,lockscreen,login}.png <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from cyberlib import accented
for f in sys.argv[2:]:
    print(accented(f))
PY
    )
  fi
  (( ${#imgs[@]} == 3 )) || return 1
  local dir i names=(desktop lockscreen login) suf
  dir=$(wallpapers_dir)
  suf=$(papel_sufixo)
  mkdir -p "$dir"
  for i in 0 1 2; do
    install -m644 "${imgs[i]}" "$dir/.${names[i]}.png.novo"
    mv -f "$dir/.${names[i]}.png.novo" "$dir/${names[i]}$suf.png"  # troca de uma vez: o Plasma nunca lê pela metade
  done
}

# Apaga as imagens das outras opções (depois de aplicar a atual: o Plasma ainda pode estar lendo a velha).
papel_limpar() {
  local dir f keep
  dir=$(wallpapers_dir)
  for f in desktop lockscreen login; do
    keep=$f$(papel_sufixo).png
    find "$dir" -maxdepth 1 \( -name "$f.png" -o -name "$f-[bcd].png" -o -name "$f-corp.png" -o -name "$f-fui.png" \) 2>/dev/null | while IFS= read -r p; do
      [[ $(basename -- "$p") == "$keep" ]] || rm -f -- "$p"
    done
  done
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
      var fuiChaves = $(papel_fui_chaves 2>/dev/null || echo '{}');
      function apply(id, screen, plugin, image) {
        var all = desktops(), hit = [];
        for (var i = 0; i < all.length; i++)
          if (id === '*' || String(all[i].id) === id) hit.push(all[i]);
        if (hit.length === 0 && screen >= 0)
          for (var j = 0; j < all.length; j++) if (all[j].screen === screen) hit.push(all[j]);
        for (var k = 0; k < hit.length; k++) {
          var d = hit[k];
          d.wallpaperPlugin = plugin;
          if (plugin === 'org.cyberkde.fui') {
            // papel animado: a imagem vem como corp:<id>
            d.currentConfigGroup = ['Wallpaper', 'org.cyberkde.fui', 'General'];
            d.writeConfig('Corporacao', image.replace(/^corp:/, ''));
            for (var ch in fuiChaves) d.writeConfig(ch, fuiChaves[ch]);
          } else {
            d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
            d.writeConfig('Image', image);
          }
          d.reloadConfig();
        }
      }
      $js" >/dev/null
  elif ! pgrep -x plasmashell >/dev/null; then
    for line in "${lines[@]}"; do
      IFS=$'\t' read -r id screen wp img <<<"$line"
      [[ $id != '*' ]] || continue  # "todas" só pelo script; sem Plasma rodando, só a volta por ID
      kwriteconfig6 --file "$appletsrc" --group Containments --group "$id" --key wallpaperplugin "$wp"
      if [[ $wp == "$papel_fui_plugin" ]]; then
        kwriteconfig6 --file "$appletsrc" --group Containments --group "$id" --group Wallpaper \
          --group "$papel_fui_plugin" --group General --key Corporacao "${img#corp:}"
      else
        kwriteconfig6 --file "$appletsrc" --group Containments --group "$id" --group Wallpaper \
          --group org.kde.image --group General --key Image "$img"
      fi
    done
  else
    echo "papeis-de-parede: o plasmashell não respondeu; área de trabalho não alterada." >&2
    return 1
  fi
}

# Imagem própria escolhida com "cyberkde papel /caminho/imagem" (gravada em ~/.config/cyberkde/
# papel-de-parede); CYBERKDE_WALLPAPER=/caminho/imagem vale por cima, só naquela execução.
wallpapers_own() {
  # Com o FUI escolhido, a imagem própria fica guardada (volta com outra opção), mas não vale.
  [[ $(papel_opcao) != fui ]] || return 0
  # Uma opção escolhida pelo efeito (a-d, corp) é escolha explícita: a imagem própria fica guardada e
  # volta com "cyberkde papel <imagem>" ([papel] propria=true).
  local own=${CYBERKDE_WALLPAPER:-}
  if [[ -z $own && $(kreadconfig6 --file "$config/cyberkde/efeitos" --group papel --key propria --default true 2>/dev/null) == false ]]; then return 0; fi
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
    papel_instalado "$1"
  fi
}

# Troca a área de trabalho e o bloqueio para as imagens da opção atual (registra o original na primeira vez).
papel_aplicar() {
  # Área de trabalho (todas as telas): registra o original e troca.
  wallpapers_save
  if [[ $(papel_opcao) == fui && -d $data/plasma/wallpapers/$papel_fui_plugin ]]; then
    printf '*\t-1\t%s\tcorp:%s\n' "$papel_fui_plugin" "$(papel_fui_corp)" | wallpapers_set
  else
    printf '*\t-1\torg.kde.image\tfile://%s\n' "$(wallpapers_image desktop)" | wallpapers_set
  fi

  # Tela de bloqueio: kscreenlockerrc [Greeter] e [Greeter][Wallpaper][org.kde.image][General].
  set_key kscreenlockerrc Greeter WallpaperPlugin org.kde.image
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" Image "file://$(wallpapers_image lockscreen)"
  papel_limpar
}

phase_papeis-de-parede() {
  [[ -f $(papel_instalado desktop) && -f $(papel_instalado lockscreen) ]] || install_papeis-de-parede
  papel_aplicar
}

# Ligada também pelo registro próprio: o papel da área de trabalho não passa pelo set_key.
ligada_papeis-de-parede() { [[ -s $(wallpapers_record) ]]; }

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

# ------------------------------------------------------------------ efeito "papel" (modules/CONTRATO.md)
# "cyberkde efeito papel [a|b|c|d|corp|padrao]": a=padrao é o papel do tema (HUD e cidade); b, c e d são as
# opções extras. Gerado pela paleta (cyberkde cor) como a opção A. Uma imagem própria ("cyberkde papel
# /caminho") continua valendo por cima da opção. A escolha fica em ~/.config/cyberkde/efeitos [papel];
# quem grava no bloqueio e na área de trabalho é a fase papeis-de-parede.
papel_nome() {  # id pt|en
  case $1$2 in
    apt) echo "A · HUD e cidade" ;; aen) echo "A · HUD and city" ;;
    bpt) echo "B · Moldura técnica" ;; ben) echo "B · Technical frame" ;;
    cpt) echo "C · Cidade" ;; cen) echo "C · City" ;;
    dpt) echo "D · Painéis" ;; den) echo "D · Panels" ;;
    corppt) echo "Corporação (a atual)" ;; corpen) echo "Corporation (the current one)" ;;
    fuipt) echo "FUI animado (a corporação atual)" ;; fuien) echo "Animated FUI (the current corporation)" ;;
  esac
}
papel_previa() {  # id -> caminho absoluto da prévia, ou nada
  local f="$project/assets/previas/papel/$1.webp" cid
  if [[ $1 == corp ]]; then
    cid=$(papel_corp_id) || return 0
    f="$project/assets/previas/papel/corp-$cid.webp"
  elif [[ $1 == fui ]]; then
    f="$project/assets/previas/papel/fui-$(papel_fui_corp).webp"
  fi
  if [[ -f $f ]]; then printf '%s\n' "$f"; fi
}

# Pela fase papeis-de-parede (ou pelo "efeito papel" com ela ligada, como se fosse ela).
efeito_papel_aplicar() {
  install_papeis-de-parede || return 1
  papel_aplicar
}

efeito_estado_papel() {
  local ligado=false propria=false
  if fase_ligada papeis-de-parede; then ligado=true; fi
  [[ -n $(wallpapers_own) ]] && propria=true
  local cid=""
  cid=$(papel_corp_id 2>/dev/null) || cid=""
  printf '{"opcao":"%s","corp":%s,"ligado":%s,"imagemPropria":%s,"fui":%s,"ligarCom":"cyberkde on papeis-de-parede","desligarCom":"cyberkde off papeis-de-parede"}' \
    "$(papel_opcao)" "$(json_caminho "$cid")" "$ligado" "$propria" "$(papel_fui_json)"
}

efeito_json_papel() {
  local o valores=""
  for o in a b c d corp fui; do
    valores+="${valores:+,}{\"id\":\"$o\",\"nome\":$(json_str "$(papel_nome "$o" pt)"),\"nome_en\":$(json_str "$(papel_nome "$o" en)"),\"previa\":$(json_caminho "$(papel_previa "$o")")}"
  done
  printf '{"id":"papel","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"opcao","nome":"Opção","nome_en":"Option","tipo":"variante","padrao":"a","valores":[%s]}],"estado":%s}' \
    "$(json_str "Papel de parede")" "$(json_str "Wallpaper")" \
    "$(json_str "Papéis de parede do tema para a área de trabalho, o bloqueio e o login, na cor de destaque; o FUI é animado na área de trabalho (estático no bloqueio e no login) e segue a corporação. Vale na hora com a fase papeis-de-parede ligada.")" \
    "$(json_str "Theme wallpapers for the desktop, the lock screen and the login, in the accent color; FUI is animated on the desktop (still on the lock screen and login) and follows the corporation. Applies right away while the wallpaper part is on.")" \
    "$valores" "$(efeito_estado_papel)"
}

#   cyberkde efeito papel [a|b|c|d|corp|fui|padrao] [--json]   (sem opção: só lê)
#   cyberkde efeito papel fui [--intensidade 30..200] [--velocidade 25..300] [--fps 30|60] [--logo on|off]
#                             [--textos on|off] [--pausar on|off] [--json]
#   Os controles do FUI valem ao vivo nas telas com ele; com o FUI já escolhido, mudar só os controles
#   não reaplica o papel (nem o bloqueio e o login).
#   --json: {"efeito":"papel",<estado>,"avisos":[...]}. Saída: 0 · 1 falha · 2 uso · 3 ocupado
efeito_cmd_papel() {
  local opcao="" arg v
  local -A fui=()
  while (( $# )); do
    arg=$1; shift
    case $arg in
      a | b | c | d | corp | fui) [[ -z $opcao ]] && opcao=$arg || opcao=invalida ;;
      padrao) [[ -z $opcao ]] && opcao=a || opcao=invalida ;;
      --intensidade | --velocidade | --fps)
        v=${1:-}; shift || true; v=${v%\%}
        if [[ $v =~ ^[0-9]{1,3}$ ]]; then v=$((10#$v)); else opcao=invalida; continue; fi
        case $arg in
          --intensidade) (( v >= 30 && v <= 200 )) || opcao=invalida ;;
          --velocidade) (( v >= 25 && v <= 300 )) || opcao=invalida ;;
          --fps) (( v == 30 || v == 60 )) || opcao=invalida ;;
        esac
        fui[${arg#--}]=$v ;;
      --logo | --textos | --pausar)
        case ${1:-} in on | true) fui[${arg#--}]=true ;; off | false) fui[${arg#--}]=false ;; *) opcao=invalida ;; esac
        shift || true ;;
      *) opcao=invalida ;;
    esac
  done
  # Os controles são do FUI: com outra opção na mesma chamada (ou escolhida antes, sem "fui"), não valem.
  if (( ${#fui[@]} )) && [[ $opcao != invalida ]]; then
    [[ ${opcao:-$(papel_opcao)} == fui ]] || opcao=invalida
  fi
  [[ $opcao != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito papel [a|b|c|d|corp|fui|padrao] [--json]; o FUI: cyberkde efeito papel fui [--intensidade 30..200] [--velocidade 25..300] [--fps 30|60] [--logo on|off] [--textos on|off] [--pausar on|off]" "usage: cyberkde efeito papel [a|b|c|d|corp|fui|padrao] [--json]; FUI: cyberkde efeito papel fui [--intensidade 30..200] [--velocidade 25..300] [--fps 30|60] [--logo on|off] [--textos on|off] [--pausar on|off]")"
  local -a avisos=()
  if (( ${#fui[@]} )); then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$config/cyberkde"
    local k
    for k in "${!fui[@]}"; do kwriteconfig6 --file "$config/cyberkde/efeitos" --group papel-fui --key "$k" "${fui[$k]}"; done
    # Já no FUI: só os controles, ao vivo (sem reaplicar papel, bloqueio e login).
    if [[ $(papel_opcao) == fui ]] && fase_ligada papeis-de-parede; then
      [[ $(papel_fui_ao_vivo) =~ ^[1-9] ]] || avisos+=("$(t "Nenhuma tela está com o FUI agora: os controles foram guardados e valem quando ele for aplicado." "No screen is showing FUI right now: the controls were saved and apply when it is applied.")")
      [[ $opcao == fui ]] && opcao=""
    fi
  fi
  if [[ -n $opcao ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$config/cyberkde"
    kwriteconfig6 --file "$config/cyberkde/efeitos" --group papel --key opcao "$opcao"
    if fase_ligada papeis-de-parede; then
      (fase_atual=papeis-de-parede; efeito_papel_aplicar) || cor_exit 1 "$(t "não consegui aplicar o papel de parede" "could not apply the wallpaper")"
    else
      avisos+=("$(t "O papel de parede do tema está desligado: a opção foi guardada; para usar, cyberkde on papeis-de-parede." "The theme wallpaper is off: the option was saved; to use it, cyberkde on papeis-de-parede.")")
    fi
    if [[ $opcao == corp ]] && ! papel_corp_id >/dev/null; then
      avisos+=("$(t "A corporação atual não tem papel próprio (ou não há corporação escolhida: cyberkde corp <id>); fica a opção A até escolher uma." "The current corporation has no wallpaper of its own (or none is chosen: cyberkde corp <id>); option A is used until one is picked.")")
    fi
    if [[ -n $(wallpapers_own) ]]; then
      avisos+=("$(t "Há uma imagem própria escolhida (cyberkde papel); ela vale por cima da opção. Para voltar às do tema: cyberkde papel padrao." "A custom image is set (cyberkde papel); it overrides the option. To go back to the theme ones: cyberkde papel padrao.")")
    fi
  fi
  local estado
  estado=$(efeito_estado_papel)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"papel",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$(t "Papel de parede" "Wallpaper"): $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

# Para o DATA: chamar depois de trocar a corporação ("cyberkde corp") ou a cor, para o papel "corp" seguir a
# corporação nova. Não faz nada se a opção escolhida não é corp ou se a fase está desligada.
papel_corp_seguir() {
  [[ $(papel_opcao) == corp || $(papel_opcao) == fui ]] || return 0  # o FUI troca a Corporacao e o estático
  fase_ligada papeis-de-parede || return 0
  (fase_atual=papeis-de-parede; efeito_papel_aplicar)
}
