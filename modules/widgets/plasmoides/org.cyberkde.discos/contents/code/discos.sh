#!/bin/sh
# CyberKDE · Discos: uma linha por sistema de arquivos montado, separada por TAB:
#   dispositivo  tipo  total  usado  livre  disco-físico  temperatura(m°C ou vazio)  ponto-de-montagem
# (o ponto de montagem por último: pode ter espaços). Temperatura: o hwmon do disco (drivetemp nos SATA,
# o controlador nos NVMe), quando existir.
LC_ALL=C df -B1 --output=source,fstype,size,used,avail,target \
  -x tmpfs -x devtmpfs -x squashfs -x efivarfs -x overlay -x ramfs -x autofs 2>/dev/null |
  tail -n +2 | while read -r src tipo total usado livre alvo; do
    case $src in /dev/*) ;; *) continue ;; esac
    pk=$(lsblk -ndo pkname "$src" 2>/dev/null | head -n 1)
    [ -n "$pk" ] || pk=$(basename "$src")
    temp=$(cat /sys/block/"$pk"/device/hwmon/hwmon*/temp1_input /sys/block/"$pk"/device/hwmon*/temp1_input 2>/dev/null | head -n 1)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$src" "$tipo" "$total" "$usado" "$livre" "$pk" "$temp" "$alvo"
  done
