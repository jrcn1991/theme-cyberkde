#!/bin/sh
# Coletor FALSO do Painel FUI, só para as prévias: substitui o contents/code/coleta.sh na cópia de teste.
# Mesmas partes e mesmo formato; todos os dados são inventados (ver previas-demo.sh).
T=$(printf '\t')
case ${1:-} in
discos) printf '%s\n' \
  "/dev/sda2${T}1000204886016${T}536870912000${T}412316860416${T}sda${T}/" \
  "/dev/sda3${T}1000204886016${T}322122547200${T}627065225216${T}sda${T}/home" \
  "/dev/sdb1${T}2000398934016${T}1868310695936${T}32212254720${T}sdb${T}/mnt/braindance" \
  "/dev/sdc1${T}4000787030016${T}1503238553600${T}2336462209024${T}sdc${T}/mnt/datashard" \
  "/dev/sdd1${T}2000398934016${T}644245094400${T}1261404782592${T}sdd${T}/mnt/arquivo" ;;
processos) printf '%s\n' \
  "2077${T}86.4${T}3.1${T}relic-daemon" "1337${T}41.2${T}6.8${T}netrunnerd" "4242${T}22.7${T}1.9${T}kiroshi-optics" \
  "3141${T}14.3${T}2.4${T}blackwall-gw" "8086${T}9.8${T}0.7${T}sandevistan" "6502${T}4.1${T}1.2${T}braindance" ;;
log) printf '%s\n' \
  "20:41${T}netrunnerd${T}Handshake com o subnet Watson concluído" \
  "20:44${T}blackwall-gw${T}Daemon desconhecido bloqueado na porta 2077" \
  "20:48${T}kiroshi-optics${T}Calibração do firmware concluída" \
  "20:51${T}relic-daemon${T}Engrama sincronizado em 98 %" ;;
estado) printf '%s\n' "som${T}0.65" "mic${T}0.40" "energia${T}AC" "gateway${T}10.0.77.1" "if${T}eth0 up" "if${T}wlan0 up" ;;
ping) shift; for h in "$@"; do case $h in 10.*) printf '%s\t2.4\n' "$h" ;; *) printf '%s\t11.8\n' "$h" ;; esac; done ;;
sistema) printf '%s\n' "uptime${T}266400" "carga${T}3.12 2.84 2.20" "kernel${T}6.20.77-cyberkde" "docker${T}3 5" "falhas${T}0" \
  "bateria${T}Kiroshi Mouse${T}64" "bateria${T}Dynalar Headset${T}82" ;;
atualizacoes) printf '12\t2\n' ;;
esac
