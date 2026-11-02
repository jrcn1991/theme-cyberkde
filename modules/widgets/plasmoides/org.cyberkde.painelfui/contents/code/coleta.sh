#!/bin/sh
# CyberKDE · Painel FUI: coleta só de LEITURA, uma parte por chamada (o widget pede cada uma no seu ritmo).
#   coleta.sh discos     dispositivo TAB total TAB usado TAB livre TAB disco-físico TAB montagem (/, /home, /mnt, mídias)
#   coleta.sh processos  pid TAB %cpu TAB %mem TAB nome   (os 6 de maior uso de CPU, sem este próprio ps)
#   coleta.sh log [nível]  as últimas linhas do journal do usuário: hora TAB origem TAB mensagem (curta)
#   coleta.sh estado     som, microfone, energia e interfaces físicas (chave TAB valor)
#   coleta.sh ping HOST...  latência em ms (ou "x") de cada alvo, com um pacote e 1 s de espera
#   coleta.sh sistema    uptime (s), carga 1/5/15, kernel, contêineres Docker (rodando/total), unidades do
#                        usuário com falha e baterias de periféricos (upower: modelo TAB %)
#   coleta.sh atualizacoes  pacotes com atualização (apt-check: total TAB segurança); lento, chamar raramente
# Segurança: o ping só aceita o gateway padrão e endereços públicos. Endereço privado que não seja o
# gateway é recusado (nunca inicia conexão com outra máquina da rede local).
set -u
LC_ALL=C; export LC_ALL
# gateway padrão (o primeiro, como o "ip route show default") lido de /proc/net/route, sem criar processo
gateway_padrao() {
  { read -r _; while read -r _ dest gw _; do
      [ "$dest" = 00000000 ] || continue
      d=${gw#??????}; c=${gw#????}; c=${c%??}; b=${gw#??}; b=${b%????}; a=${gw%??????}
      printf '%d.%d.%d.%d' "0x$d" "0x$c" "0x$b" "0x$a"
      return
    done; } </proc/net/route 2>/dev/null
}
case ${1:-} in
discos)
  df -B1 --output=source,size,used,avail,target -x tmpfs -x devtmpfs -x squashfs -x efivarfs -x overlay 2>/dev/null |
    tail -n +2 | while read -r src total usado livre alvo; do
      case $src in /dev/*) ;; *) continue ;; esac
      case $alvo in /|/home|/mnt/*|/media/*|/run/media/*) ;; *) continue ;; esac
      pk=$(lsblk -ndo pkname "$src" 2>/dev/null | head -n 1); [ -n "$pk" ] || pk=$(basename "$src")
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$src" "$total" "$usado" "$livre" "$pk" "$alvo"
    done ;;
processos)
  ps -eo pid=,pcpu=,pmem=,comm= --sort=-pcpu 2>/dev/null | awk 'NR>7 { exit } $4 != "ps" && n < 6 { n++; printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4 }' ;;
log)
  # prioridade mínima: $2 (warning por padrão; notice, info…). Só a 1.ª linha de cada mensagem, curta.
  case ${2:-warning} in emerg|alert|crit|err|warning|notice|info) pr=${2:-warning} ;; *) pr=warning ;; esac
  journalctl --user -n 40 -q --no-pager -o short-iso -p "$pr" 2>/dev/null | grep -v '^[[:space:]]' | tail -n 7 |
    sed -E 's/^[0-9-]+T([0-9]{2}:[0-9]{2}):[0-9.]+[+-][0-9:]+ [^ ]+ ([^:[]+)(\[[0-9]+\])?: /\1\t\2\t/' | cut -c1-110 ;;
estado)
  v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); printf 'som\t%s\n' "${v#Volume: }"
  v=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null); printf 'mic\t%s\n' "${v#Volume: }"
  en="AC"
  for b in /sys/class/power_supply/BAT*; do
    if [ -r "$b/capacity" ]; then
      c=; st=; read -r c <"$b/capacity"; [ -r "$b/status" ] && read -r st <"$b/status"
      en="$c $st"
    fi
  done
  printf 'energia\t%s\n' "$en"
  printf 'gateway\t%s\n' "$(gateway_padrao)"
  for i in /sys/class/net/*; do
    n=${i##*/}
    case $n in lo|veth*|br-*|docker*|virbr*|tun*|tap*) continue ;; esac
    [ -e "$i/device" ] || continue
    op=; [ -r "$i/operstate" ] && read -r op <"$i/operstate"
    printf 'if\t%s %s\n' "$n" "$op"
  done ;;
sistema)
  printf 'uptime\t%s\n' "$(cut -d' ' -f1 /proc/uptime)"
  printf 'carga\t%s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
  printf 'kernel\t%s\n' "$(uname -r)"
  if command -v docker >/dev/null 2>&1; then
    r=$(timeout 3 docker ps -q 2>/dev/null | wc -l); t=$(timeout 3 docker ps -aq 2>/dev/null | wc -l)
    timeout 3 docker info >/dev/null 2>&1 && printf 'docker\t%s %s\n' "$r" "$t"
  fi
  printf 'falhas\t%s\n' "$(systemctl --user --failed --no-legend 2>/dev/null | wc -l)"
  for d in $(upower -e 2>/dev/null); do
    case $d in *DisplayDevice|*line_power*) continue ;; esac
    i=$(upower -i "$d" 2>/dev/null)
    pc=$(printf '%s\n' "$i" | sed -n 's/^ *percentage: *\([0-9]*\).*/\1/p' | head -n 1)
    mo=$(printf '%s\n' "$i" | sed -n 's/^ *model: *//p' | head -n 1)
    [ -n "$pc" ] && printf 'bateria\t%s\t%s\n' "${mo:-${d##*/}}" "$pc"
  done ;;
atualizacoes)
  if [ -x /usr/lib/update-notifier/apt-check ]; then
    r=$(timeout 60 /usr/lib/update-notifier/apt-check 2>&1 >/dev/null | tail -n 1)
    case $r in *\;*) printf '%s\t%s\n' "${r%%;*}" "${r##*;}" ;; esac
  fi ;;
ping)
  shift
  gw=$(gateway_padrao)
  for h in "$@"; do
    case $h in *[!0-9.]*|"") printf '%s\tx\n' "$h"; continue ;; esac
    if [ "$h" != "$gw" ]; then
      case $h in 10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|127.*|169.254.*|0.*) printf '%s\tx\n' "$h"; continue ;; esac
    fi
    ms=$(ping -n -c 1 -W 1 "$h" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
    printf '%s\t%s\n' "$h" "${ms:-x}"
  done ;;
esac
