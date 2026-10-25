# modules/login/phase.sh — tela de login (SDDM), splash (KSplash) e tela de bloqueio CyberKDE.
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
#   login           tema SDDM "cyberkde" (sudo), splash org.cyberkde.desktop e fundo CyberKDE na
#                   tela de bloqueio padrão. Entra no "cyberkde on" (tudo).
#   login-bloqueio  OPCIONAL (fora do "on" geral): troca a interface da tela de bloqueio pela
#                   CyberKDE. No Plasma 6.6 ela vem do pacote de shell e não existe chave que a
#                   escolha sem trocar também o shell do plasmashell (ver NOTES.md). Exige sudo.

CYBERKDE_PHASES+=(login)
CYBERKDE_FASES_OPCIONAIS+=(login-bloqueio)
descreve_fase login "Login e abertura" login sim "Tela de login (pede sudo), tela de abertura e fundo da tela de bloqueio." \
  "Login and splash" "Login screen (needs sudo), startup splash and lock screen background."
descreve_fase login-bloqueio "Tela de bloqueio" login sim "Interface CyberKDE na tela de bloqueio (troca um arquivo do Plasma em /usr)." \
  "Lock screen" "CyberKDE interface on the lock screen (replaces a Plasma file in /usr)."
CYBERKDE_INSTALLS+=(install_login)

# Gera tudo a partir dos tokens e instala na pasta do usuário (nada em /usr ou /etc aqui).
install_login() {
  local build="$project/modules/login/build" papel
  # Com --fundo papel, o build já sai com o login da opção de papel em uso (inclusive a da corporação).
  papel=$(login_papel_atual)
  python3 "$project/modules/login/generator/gen_login.py" ${papel:+--fundo "$papel"} >/dev/null
  mkdir -p "$data/plasma/look-and-feel"
  swap_dir "$build/look-and-feel/org.cyberkde.desktop" "$data/plasma/look-and-feel/org.cyberkde.desktop"
  # Logo largo da corporação na tela de abertura (Splash.qml lê images/logo.svg ou .png; corp_logo_largo
  # prefere a versão para fundo escuro). Vai só na cópia instalada, nunca no build/ do projeto: o logo
  # da usuária fica fora do repositório.
  local logo
  logo=$(corp_logo_largo "$(corp_atual)")
  if [[ -n $logo ]]; then
    local ext=svg dst
    if [[ ${logo,,} == *.png ]]; then ext=png; fi
    dst="$data/plasma/look-and-feel/org.cyberkde.desktop/contents/splash/images/logo.$ext"
    install -m644 -- "$logo" "$dst"
    # PNG: já no tamanho em que a tela de abertura o lê (sourceSize 880x220 no Splash.qml), reduzido
    # com Lanczos. Sem isso, o Qt reduz de 1024 px na hora, com filtro simples, e o contorno serrilha.
    # Sem Pillow, fica o original (o QML ainda suaviza com mipmap).
    if [[ $ext == png ]]; then
      python3 - "$dst" <<'PY' 2>/dev/null || true
import sys
from PIL import Image
img = Image.open(sys.argv[1]).convert("RGBA")
esc = min(880 / img.width, 220 / img.height, 1.0)
if esc < 1.0:
    img = img.convert("RGBa").resize((round(img.width * esc), round(img.height * esc)), Image.Resampling.LANCZOS).convert("RGBA")
    img.save(sys.argv[1], "PNG", optimize=True)
PY
    fi
  fi
  install -Dm644 "$build/wallpaper/login.png" "$data/cyberkde/login/login.png"
  splash_aplicar_opcoes
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
  # Tela de bloqueio padrão (interface Breeze) com o mesmo fundo do login (ou o papel de parede).
  login_bloqueio_fundo
}

login_bloqueio_fundo() {  # fora do padrão phase_*: chamada pela fase login e pelo "efeito login"
  local img
  img=$(login_fundo_imagem "$data/cyberkde/login/login.png" lockscreen)
  set_key kscreenlockerrc Greeter WallpaperPlugin org.kde.image
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" Image "file://$img"
  set_key kscreenlockerrc "Greeter][Wallpaper][org.kde.image][General" PreviewImage "file://$img"
}

login_sddm() {  # fora do padrão phase_*: não é uma fase avulsa
  local build="$project/modules/login/build"
  # SDDM: tema em /usr/share e seleção num arquivo próprio em /etc/sddm.conf.d, lido em ordem
  # alfabética (o último vence). "zz-" fica depois de "20-kubuntu.conf" e também do "kde_settings.conf",
  # que as Configurações do Sistema escrevem ao mexer no login (o antigo "cyberkde.conf" perdia dele).
  # Cópia do tema com as opções do efeito "login" e o fundo escolhido (o usuário sddm não lê a pasta
  # pessoal: o fundo vai para dentro do tema). Mesma pasta de antes = nada a gravar, nem sudo.
  local stage
  stage=$(login_encenar "$build/sddm/cyberkde" components background.png)
  put_dir "$stage" /usr/share/sddm/themes/cyberkde
  rm -rf -- "$stage"
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
  local stage
  stage=$(login_encenar "$build/lockscreen/cyberkde" . background.png lockscreen)
  put_dir "$stage" "$lock/cyberkde"
  rm -rf -- "$stage"
  put_file "$lock/LockScreen.qml" <"$build/lockscreen/LockScreen.qml"
}

# ------------------------------------------------------------------ efeitos "splash" e "login"
# Opções no painel ("cyberkde efeito ..."; modules/CONTRATO.md). A escolha fica em
# ~/.config/cyberkde/efeitos [splash] e [login]; os QML leem um singleton Opcoes.qml que cada cópia
# instalada recebe (login_opcoes_qml):
#   splash  modo     completo (2 s, montagem do logo como no painel) | curto (padrão, ~900 ms) | nenhum
#   login   entrada  completa (820 ms) | curta (metade) | fatias (o painel chega em fatias; só com GPU) | nenhuma
#           painel   centro | esquerda (painel à esquerda, relógio à direita)
#           sucesso  true | false ("ACESSO CONCEDIDO" por ≤200 ms antes de a sessão abrir ou desbloquear)
#           fundo    papel (padrão: segue o papel de parede escolhido, na versão de login dele) | login
# Valem no login (SDDM, sudo), na tela de bloqueio (padrão e CyberKDE) e, o fundo, também no splash.
# Prévias: assets/previas/login/anim-*.webp (render_anim.py).
CYBERKDE_EFEITOS+=(splash login)

login_pref() {  # grupo chave padrão permitidos...  -> valor válido (ou o padrão)
  local g=$1 k=$2 padrao=$3 v
  shift 3
  v=$(kreadconfig6 --file "$efeitos_file" --group "$g" --key "$k" --default "$padrao" 2>/dev/null)
  if [[ " $* " == *" $v "* ]]; then printf '%s\n' "$v"; else printf '%s\n' "$padrao"; fi
}
splash_modo() { login_pref splash modo curto completo curto nenhum; }
login_entrada() { login_pref login entrada completa completa curta fatias nenhuma; }
login_painel() { login_pref login painel centro centro esquerda; }
login_sucesso() { login_pref login sucesso true true false; }
login_fundo() { login_pref login fundo papel login papel; }

login_opcoes_qml() {
  cat <<EOF
// Opções dos efeitos splash e login, gravadas pela fase login (cyberkde efeito splash/login).
pragma Singleton
import QtQuick

QtObject {
    readonly property string splash: "$(splash_modo)"
    readonly property string entrada: "$(login_entrada)"
    readonly property string painel: "$(login_painel)"
    readonly property bool sucesso: $(login_sucesso)
    // o fundo já traz o logo (papel da corporação): o splash não desenha o dele
    readonly property bool logoNoFundo: $(login_fundo_tem_logo && echo true || echo false)
}
EOF
}

# O fundo em uso é o papel da corporação (opção "corp" do MAX), que já traz a placa com o logo: o splash
# não desenha o logo de novo (achado F7 do QA). Papel próprio da pessoa ou corporação sem papel: não.
login_fundo_tem_logo() {
  [[ $(login_fundo) == papel ]] || return 1
  declare -F papel_opcao >/dev/null && [[ $(papel_opcao) == corp ]] || return 1
  declare -F papel_corp_id >/dev/null && papel_corp_id >/dev/null 2>&1 || return 1
  if declare -F wallpapers_own >/dev/null && [[ -n $(wallpapers_own 2>/dev/null) && -f $(wallpapers_own 2>/dev/null) ]]; then return 1; fi
  [[ -n $(login_papel_atual) ]]
}

# Imagem de fundo com fundo=papel (módulo papeis-de-parede, "cyberkde efeito papel"): o papel próprio
# da pessoa, se houver; senão a versão de LOGIN da opção escolhida (papel_instalado login, que o MAX gera
# para cada opção). Sem o módulo ou sem a imagem, ou com fundo=login: o fundo do login.
# A opção "corp" do papel (login-corp.png, lockscreen-corp.png) entra pelo mesmo papel_instalado.
login_papel_atual() {  # [login|lockscreen] -> imagem do papel em uso, ou nada (fundo=login ou sem imagem)
  local tipo=${1:-login} img=""
  [[ $(login_fundo) == papel ]] || return 0
  if declare -F wallpapers_own >/dev/null; then img=$(wallpapers_own 2>/dev/null || true); fi
  if [[ ! -f $img ]] && declare -F papel_instalado >/dev/null; then img=$(papel_instalado "$tipo" 2>/dev/null || true); fi
  if [[ ! -f $img && $tipo != login ]] && declare -F papel_instalado >/dev/null; then img=$(papel_instalado login 2>/dev/null || true); fi
  if [[ ! -f $img ]] && declare -F wallpapers_image >/dev/null; then img=$(wallpapers_image desktop 2>/dev/null || true); fi
  if [[ -n $img && -f $img ]]; then printf '%s\n' "$img"; fi
}
login_fundo_imagem() {  # [reserva] [login|lockscreen]
  local img
  img=$(login_papel_atual "${2:-login}")
  printf '%s\n' "${img:-${1:-$project/modules/login/build/wallpaper/login.png}}"
}

# Para quem troca o papel ou a corporação (efeito papel, papel_corp_seguir, cyberkde corp): o login, o
# bloqueio e o splash acompanham o papel novo. Com a fase login ligada, a tela de login pede sudo
# (ou fica pendente, sem terminal). Sem nada a mudar, não grava nada.
login_fundo_seguir() {
  [[ $(login_fundo) == papel ]] || return 0
  splash_aplicar_opcoes
  if fase_ligada login; then
    (fase_atual=login; [[ -d /usr/share/sddm/themes ]] && login_sddm; login_bloqueio_fundo)
  fi
  if fase_ligada login-bloqueio; then
    (fase_atual=login-bloqueio; phase_login-bloqueio)
  fi
  return 0
}

# Cópia temporária de um pacote do build com o Opcoes.qml e o fundo da escolha atual, legível por
# todos (o SDDM roda como outro usuário). Imprime o caminho; quem chama apaga.
login_encenar() {  # origem pasta-dos-componentes arquivo-de-fundo [login|lockscreen]
  local stage
  stage=$(mktemp -d)
  cp -r -- "$1/." "$stage/"
  login_opcoes_qml >"$stage/$2/Opcoes.qml"
  cp -- "$(login_fundo_imagem "" "${4:-login}")" "$stage/$3"
  find "$stage" -type d -exec chmod 755 {} + && find "$stage" -type f -exec chmod 644 {} +
  printf '%s\n' "$stage"
}

# Splash: o pacote fica na pasta da pessoa (install_login), então a escolha vale na hora, sem sudo.
splash_dir() { printf '%s\n' "$data/plasma/look-and-feel/org.cyberkde.desktop/contents/splash"; }
splash_aplicar_opcoes() {
  local dir
  dir=$(splash_dir)
  [[ -d $dir/components ]] || return 0
  login_opcoes_qml >"$dir/components/.Opcoes.qml.novo" && mv -f "$dir/components/.Opcoes.qml.novo" "$dir/components/Opcoes.qml"
  install -m644 -- "$(login_fundo_imagem)" "$dir/images/.background.png.novo"
  mv -f "$dir/images/.background.png.novo" "$dir/images/background.png"
}

login_previa() {  # nome -> caminho absoluto da prévia, ou nada
  local f="$project/assets/previas/login/$1.webp"
  if [[ -f $f ]]; then printf '%s\n' "$f"; fi
}
login_valor_json() {  # id nome nome_en previa
  printf '{"id":"%s","nome":%s,"nome_en":%s,"previa":%s}' "$1" "$(json_str "$2")" "$(json_str "$3")" "$(json_caminho "$(login_previa "$4")")"
}

efeito_estado_splash() {
  local aplicado=null f
  f="$(splash_dir)/components/Opcoes.qml"
  if [[ -f $f ]]; then aplicado=$(json_str "$(sed -n 's/.*property string splash: "\(.*\)".*/\1/p' "$f")"); fi
  printf '{"modo":"%s","aplicado":%s,"instalado":%s,"faseLogin":%s}' "$(splash_modo)" "$aplicado" \
    "$([[ -d $(splash_dir) ]] && echo true || echo false)" "$(fase_ligada login && echo true || echo false)"
}

efeito_json_splash() {
  local valores
  valores="$(login_valor_json completo "Completo" "Full" anim-splash-completo),$(login_valor_json curto "Curto" "Short" anim-splash-curto),$(login_valor_json nenhum "Nenhum" "None" anim-splash-nenhum)"
  printf '{"id":"splash","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[{"id":"modo","nome":"Duração","nome_en":"Length","tipo":"variante","padrao":"curto","valores":[%s]}],"estado":%s}' \
    "$(json_str "Tela de abertura")" "$(json_str "Startup splash")" \
    "$(json_str "Como a tela de abertura se monta a cada login: completa (2 s, o logo se monta em fatias), curta (padrão, ~0,9 s) ou sem animação. O progresso real aparece em todas.")" \
    "$(json_str "How the startup splash assembles at every login: full (2 s, the logo assembles in slices), short (default, ~0.9 s) or no animation. Real progress shows in all of them.")" \
    "$valores" "$(efeito_estado_splash)"
}

#   cyberkde efeito splash [completo|curto|nenhum] [--json]   (sem modo: só lê)
#   --json: {"efeito":"splash",<estado>,"avisos":[...]}. Saída: 0 · 2 uso · 3 ocupado
efeito_cmd_splash() {
  local modo="" arg
  for arg in "$@"; do
    case $arg in
      completo | curto | nenhum) [[ -z $modo ]] && modo=$arg || modo=invalido ;;
      *) modo=invalido ;;
    esac
  done
  [[ $modo != invalido ]] || cor_exit 2 "$(t "uso: cyberkde efeito splash [completo|curto|nenhum] [--json]" "usage: cyberkde efeito splash [completo|curto|nenhum] [--json]")"
  local -a avisos=()
  if [[ -n $modo ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    kwriteconfig6 --file "$efeitos_file" --group splash --key modo "$modo"
    if [[ -d $(splash_dir) ]]; then
      splash_aplicar_opcoes
      fase_ligada login || avisos+=("$(t "A fase login está desligada: a tela de abertura do tema não está em uso (cyberkde on login)." "The login part is off: the theme splash is not in use (cyberkde on login).")")
    else
      avisos+=("$(t "A tela de abertura ainda não foi instalada: vale depois do cyberkde install." "The splash is not installed yet: applies after cyberkde install.")")
    fi
  fi
  local estado
  estado=$(efeito_estado_splash)
  if (( cor_json )); then
    local corpo=${estado#\{}
    # "retomar" sempre null: o splash fica na pasta do usuário, nunca pede sudo (campo do contrato).
    printf '{"efeito":"splash",%s,"avisos":%s,"retomar":null}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "$(t "Tela de abertura" "Startup splash"): $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

efeito_estado_login() {
  printf '{"entrada":"%s","painel":"%s","sucesso":%s,"fundo":"%s","faseLogin":%s,"faseBloqueio":%s}' \
    "$(login_entrada)" "$(login_painel)" "$(login_sucesso)" "$(login_fundo)" \
    "$(fase_ligada login && echo true || echo false)" "$(fase_ligada login-bloqueio && echo true || echo false)"
}

efeito_json_login() {
  local entrada painel sucesso fundo
  entrada="$(login_valor_json completa "Completa" "Full" anim-login-entrada-completa),$(login_valor_json curta "Curta" "Short" anim-login-entrada-curta),$(login_valor_json fatias "Em fatias" "Slices" anim-login-entrada-fatias),$(login_valor_json nenhuma "Nenhuma" "None" anim-login-entrada-nenhuma)"
  painel="$(login_valor_json centro "Centro" "Center" anim-login-entrada-completa),$(login_valor_json esquerda "À esquerda" "Left" anim-login-painel-esquerda)"
  sucesso="$(login_valor_json true "Ligado" "On" anim-login-sucesso),$(login_valor_json false "Desligado" "Off" -)"
  fundo="$(login_valor_json papel "Papel de parede" "Wallpaper" -),$(login_valor_json login "Fundo próprio do login" "Own login background" -)"
  printf '{"id":"login","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","opcoes":[%s,%s,%s,%s],"estado":%s}' \
    "$(json_str "Login e bloqueio")" "$(json_str "Login and lock screen")" \
    "$(json_str "Entrada do painel, posição, confirmação de acesso e fundo da tela de login e da tela de bloqueio. O login pede sudo para gravar.")" \
    "$(json_str "Panel entrance, position, access confirmation and background of the login and lock screens. The login screen needs sudo to save.")" \
    "{\"id\":\"entrada\",\"nome\":\"Entrada\",\"nome_en\":\"Entrance\",\"tipo\":\"variante\",\"padrao\":\"completa\",\"valores\":[$entrada]}" \
    "{\"id\":\"painel\",\"nome\":\"Painel\",\"nome_en\":\"Panel\",\"tipo\":\"variante\",\"padrao\":\"centro\",\"valores\":[$painel]}" \
    "{\"id\":\"sucesso\",\"nome\":\"Acesso concedido\",\"nome_en\":\"Access granted\",\"tipo\":\"liga\",\"padrao\":true,\"valores\":[$sucesso]}" \
    "{\"id\":\"fundo\",\"nome\":\"Fundo\",\"nome_en\":\"Background\",\"tipo\":\"variante\",\"padrao\":\"papel\",\"valores\":[$fundo]}" \
    "$(efeito_estado_login)"
}

#   cyberkde efeito login [--entrada completa|curta|fatias|nenhuma] [--painel centro|esquerda]
#                         [--sucesso on|off] [--fundo login|papel] [--json]   (sem opção: só lê)
#   --json: {"efeito":"login",<estado>,"pendentesSudo":[...],"avisos":[...],"retomar":"comando"|null}.
#   Saída: 0 · 2 uso · 3 ocupado
efeito_cmd_login() {
  local entrada="" painel="" sucesso="" fundo="" ruim=0 arg
  for (( ; $# ; )); do
    arg=$1; shift
    case $arg in
      --entrada) entrada=${1:-}; shift || true; [[ $entrada =~ ^(completa|curta|fatias|nenhuma)$ ]] || ruim=1 ;;
      --painel) painel=${1:-}; shift || true; [[ $painel =~ ^(centro|esquerda)$ ]] || ruim=1 ;;
      --sucesso)
        case ${1:-} in on | true) sucesso=true ;; off | false) sucesso=false ;; *) ruim=1 ;; esac
        shift || true ;;
      --fundo) fundo=${1:-}; shift || true; [[ $fundo =~ ^(login|papel)$ ]] || ruim=1 ;;
      *) ruim=1 ;;
    esac
  done
  (( ruim == 0 )) || cor_exit 2 "$(t "uso: cyberkde efeito login [--entrada completa|curta|fatias|nenhuma] [--painel centro|esquerda] [--sucesso on|off] [--fundo login|papel] [--json]" "usage: cyberkde efeito login [--entrada completa|curta|fatias|nenhuma] [--painel centro|esquerda] [--sucesso on|off] [--fundo login|papel] [--json]")"
  local -a avisos=() pendentes=()
  # O comando exato para completar com sudo (campo "retomar"): o mesmo pedido, num terminal.
  local retomar="cyberkde efeito login"
  [[ -z $entrada ]] || retomar+=" --entrada $entrada"
  [[ -z $painel ]] || retomar+=" --painel $painel"
  [[ -z $sucesso ]] || retomar+=" --sucesso $([[ $sucesso == true ]] && echo on || echo off)"
  [[ -z $fundo ]] || retomar+=" --fundo $fundo"
  if [[ -n $entrada$painel$sucesso$fundo ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    local w=(kwriteconfig6 --file "$efeitos_file" --group login)
    [[ -z $entrada ]] || "${w[@]}" --key entrada "$entrada"
    [[ -z $painel ]] || "${w[@]}" --key painel "$painel"
    [[ -z $sucesso ]] || "${w[@]}" --key sucesso "$sucesso"
    [[ -z $fundo ]] || "${w[@]}" --key fundo "$fundo"
    [[ -z $fundo ]] || splash_aplicar_opcoes
    if [[ $fundo == papel ]] && ! declare -F papel_instalado >/dev/null; then
      avisos+=("$(t "O módulo de papel de parede não está presente: fica o fundo do login." "The wallpaper module is missing: the login background stays.")")
    fi
    # Quem grava é a fase dona (set_key/put_dir anotam a fase, para o "off" devolver o original).
    local pend
    pend=$(mktemp)
    if fase_ligada login; then
      (fase_atual=login sem_sudo_pendentes=$pend; [[ -d /usr/share/sddm/themes ]] && login_sddm; login_bloqueio_fundo)
    else
      avisos+=("$(t "A fase login está desligada: a escolha foi guardada e vale no próximo cyberkde on." "The login part is off: the choice was saved and applies on the next cyberkde on.")")
    fi
    if fase_ligada login-bloqueio; then
      (fase_atual=login-bloqueio sem_sudo_pendentes=$pend; phase_login-bloqueio)
    fi
    mapfile -t pendentes <"$pend"
    rm -f -- "$pend"
    if (( ${#pendentes[@]} )); then
      avisos+=("$(t "Sem sudo, a tela de login (e a de bloqueio CyberKDE) ficou com a escolha anterior: rode num terminal: $retomar" "Without sudo, the login screen (and the CyberKDE lock screen) kept the previous choice: run in a terminal: $retomar")")
    fi
  fi
  local estado
  estado=$(efeito_estado_login)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"login",%s,"pendentesSudo":%s,"avisos":%s%s}\n' "${corpo%\}}" "$(json_list_str "${pendentes[@]}")" "$(json_list_str "${avisos[@]}")" \
      "$(retomar_json "$( (( ${#pendentes[@]} )) && echo "$retomar")")" >&3
  else
    echo "$(t "Login e bloqueio" "Login and lock screen"): $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}
