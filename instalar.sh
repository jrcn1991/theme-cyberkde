#!/usr/bin/env bash
# instalar.sh — instala o CyberKDE para o usuário atual (sem root).
#
#   ./instalar.sh              instala (ou atualiza) o programa e os arquivos do tema, sem ligar nada
#   ./instalar.sh --ligar      instala e já liga o tema inteiro
#   ./instalar.sh --continuar  segue mesmo com itens "!" na checagem (o que eles afetam fica diferente)
#   ./instalar.sh --sem-latte  não instala o Latte Dock (a dock fica um painel do Plasma)
#   ./instalar.sh --sem-animados  não instala o Dolphin e o Konsole animados
#
# Antes de tudo, confere os pré-requisitos e os problemas conhecidos ("cyberkde checar") e diz como
# corrigir cada um. O programa vai para ~/.local/opt/cyberkde e o comando para ~/.local/bin/cyberkde.
# Depois disso esta pasta pode ser apagada. Para remover tudo: ./desinstalar.sh (ou "cyberkde uninstall").

set -euo pipefail

src="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
dest="$HOME/.local/opt/cyberkde"
bin_dir="$HOME/.local/bin"
link="$bin_dir/cyberkde"
ligar=0 continuar=0 latte=1 animados=1

for arg in "$@"; do
  case $arg in
    --ligar) ligar=1 ;;
    --continuar) continuar=1 ;;
    --sem-latte) latte=0 ;;
    --sem-animados) animados=0 ;;
    -h | --help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opção desconhecida: $arg (use --ligar, --continuar, --sem-latte, --sem-animados ou --help)" >&2; exit 2 ;;
  esac
done

if (( EUID == 0 )); then
  echo "Rode como o seu usuário, sem sudo: o tema é por usuário. Quando precisar de root (tela de" \
    "login), o próprio cyberkde pede a senha." >&2
  exit 1
fi

# --- Pré-requisitos e problemas conhecidos --------------------------------------------------------
rc=0
"$src/scripts/cyberkde" checar || rc=$?
if (( rc == 1 )); then
  exit 1
elif (( rc == 2 && ! continuar )); then
  echo "Nada foi instalado. Depois de corrigir, rode de novo; para seguir assim mesmo: ./instalar.sh --continuar ${*}" >&2
  exit 1
fi
echo

# --- Cópia do programa ----------------------------------------------------------------------------
# Só o que o tema usa: sem histórico do git, imagens de referência, prévias ou opções descartadas.
lista=$(mktemp)
trap 'rm -f "$lista"' EXIT
if git -C "$src" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Rastreados + novos ainda sem commit (respeitando o .gitignore).
  git -C "$src" ls-files -z --cached --others --exclude-standard >"$lista"
else
  (cd "$src" && find . -type f ! -path './.git/*' -printf '%P\0') >"$lista"
fi
novo="$dest.novo"
rm -rf -- "$novo"
mkdir -p -- "$novo"
while IFS= read -r -d '' f; do
  case $f in
    imagens-referencia/* | backups/* | */preview/* | modules/papeis-de-parede/opcoes/* | \
      assets/icons/ai-raw/* | assets/icons/ai-alt/* | assets/icons/scripts/* | assets/icons/preview*.png | \
      scripts/baixar_imagens_referencia.sh | instalar.sh | desinstalar.sh | */__pycache__/* | .github/* | \
      modules/*/build/* | dolphin/src/* | dolphin/build/* | konsole/src/* | konsole/build/* | latte/*) continue ;;
  esac
  [[ -f $src/$f ]] || continue  # apagado na pasta e ainda não commitado
  install -D -m "$(stat -c %a "$src/$f")" -- "$src/$f" "$novo/$f"
done <"$lista"
# Apps compilados (Dolphin/Konsole): o código baixado fica junto do programa; numa atualização, reaproveita.
for app in dolphin konsole latte; do
  for sub in src build; do
    if [[ -d $dest/$app/$sub ]]; then mkdir -p -- "$novo/$app"; mv -- "$dest/$app/$sub" "$novo/$app/$sub"; fi
  done
done
: >"$novo/.instalado"  # marca: o "cyberkde uninstall" desta cópia também remove o programa
chmod 755 "$novo/scripts/cyberkde"
atualizacao=0
if [[ -d $dest ]]; then atualizacao=1; fi
rm -rf -- "$dest.velho"
if [[ -d $dest ]]; then mv -T -- "$dest" "$dest.velho"; fi
mv -T -- "$novo" "$dest"
rm -rf -- "$dest.velho"

# --- Comando --------------------------------------------------------------------------------------
mkdir -p -- "$bin_dir"
if [[ -e $link && ! -L $link ]]; then
  echo "Já existe um arquivo em $link que não é do CyberKDE; não vou sobrescrever." >&2
  echo "O programa ficou em $dest; rode $dest/scripts/cyberkde diretamente." >&2
  exit 1
fi
ln -sfn -- "$dest/scripts/cyberkde" "$link"
avisos=()
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    # O ~/.profile (Ubuntu/Debian) só põe ~/.local/bin no PATH se a pasta já existia no login. Um
    # terminal novo não resolve: só um login novo.
    if grep -qs '\.local/bin' "$HOME/.profile" "$HOME/.bash_profile"; then
      avisos+=("O comando 'cyberkde' só funciona depois de sair e entrar na sessão (o $bin_dir acabou de ser criado). Até lá, neste terminal: export PATH=\"\$HOME/.local/bin:\$PATH\"  (ou use $link)")
    else
      avisos+=("$bin_dir não está no PATH. Acrescente ao ~/.profile: export PATH=\"\$HOME/.local/bin:\$PATH\"  e saia e entre na sessão (até lá, use $link).")
    fi
    ;;
esac

# --- Barra e dock ---------------------------------------------------------------------------------
# Instalação nova: arranjo das capturas (barra em cima, dock). Quem já usava o CyberKDE continua
# com a barra e a dock que tem ("cyberkde layout tema" muda depois).
layout_pref="${XDG_CONFIG_HOME:-$HOME/.config}/cyberkde/layout"
if [[ ! -s $layout_pref ]]; then
  mkdir -p -- "$(dirname -- "$layout_pref")"
  if (( atualizacao )); then echo manter >"$layout_pref"; else echo tema >"$layout_pref"; fi
fi
# Dock das capturas: o Latte Dock NG, pelo pacote revisado ("cyberkde latte"), só nos ambientes
# validados (hoje, Ubuntu 26.04). Fora deles (ou com --sem-latte), a dock é um painel do Plasma, sem
# pergunta. Nada é compilado.
if [[ $(<"$layout_pref") == tema ]] && (( latte )) && [[ ${XDG_SESSION_TYPE:-wayland} == wayland ]] &&
  "$dest/scripts/cyberkde" latte --disponivel &&
  ! command -v latte-dock-ng >/dev/null && [[ ! -x $HOME/.local/bin/latte-dock-ng ]] && ! command -v latte-dock >/dev/null; then
  resposta=s
  if [[ -t 0 ]]; then
    read -r -p "A dock das capturas é o Latte Dock NG. Instalar agora (pacote revisado; pede a senha)? [S/n] " resposta || resposta=n
  fi
  case ${resposta,,} in
    n | nao | não) avisos+=("Sem o Latte, a dock é um painel do Plasma. Para instalar depois: cyberkde latte") ;;
    *) "$dest/scripts/cyberkde" latte || avisos+=("O Latte não foi instalado; a dock é um painel do Plasma. Para tentar de novo: cyberkde latte") ;;
  esac
fi

# Dolphin e Konsole animados, por pacote revisado (Ubuntu 26.04). Nada é compilado.
if (( animados )) && "$dest/scripts/cyberkde" animados --disponivel; then
  resposta=s
  if [[ -t 0 ]]; then
    read -r -p "Instalar o Dolphin e o Konsole animados (cascata ao abrir pastas, texto animado; pacotes revisados, pede a senha)? [S/n] " resposta || resposta=n
  fi
  case ${resposta,,} in
    n | nao | não) avisos+=("Para instalar depois o Dolphin e o Konsole animados: cyberkde animados") ;;
    *) "$dest/scripts/cyberkde" animados || avisos+=("Dolphin/Konsole animados não instalados; ficam os do sistema.") ;;
  esac
fi

# --- Arquivos do tema -----------------------------------------------------------------------------
echo "Gerando e instalando os arquivos do tema (pode levar um minuto)…"
"$dest/scripts/cyberkde" install

echo
if (( atualizacao )); then echo "CyberKDE atualizado em $dest."; else echo "CyberKDE instalado em $dest."; fi
for a in "${avisos[@]}"; do echo "Aviso: $a"; done
ligado=$("$dest/scripts/cyberkde" status --json | grep -q '"ligado":true' && echo 1 || echo 0)
# Sem ~/.local/bin no PATH ainda, as instruções usam o caminho completo.
cmd=cyberkde
case ":$PATH:" in *":$bin_dir:"*) ;; *) cmd=$link ;; esac
if (( ligar )); then
  "$dest/scripts/cyberkde" on
elif (( ligado )); then
  echo "O tema já estava ligado: rode '$cmd on' para aplicar a versão nova."
else
  echo "Para ligar: $cmd on        Para desligar: $cmd off        Remover tudo: $cmd uninstall"
fi
