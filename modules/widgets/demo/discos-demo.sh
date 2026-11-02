#!/bin/sh
# Coletor FALSO do widget Discos, só para as prévias (mesmo formato do contents/code/discos.sh).
T=$(printf '\t')
printf '%s\n' \
  "/dev/sda2${T}ext4${T}1000204886016${T}536870912000${T}412316860416${T}sda${T}41000${T}/" \
  "/dev/sda3${T}ext4${T}1000204886016${T}322122547200${T}627065225216${T}sda${T}41000${T}/home" \
  "/dev/sdb1${T}ext4${T}2000398934016${T}1868310695936${T}32212254720${T}sdb${T}47000${T}/mnt/braindance" \
  "/dev/sdc1${T}ext4${T}4000787030016${T}1503238553600${T}2336462209024${T}sdc${T}38000${T}/mnt/datashard" \
  "/dev/sdd1${T}ext4${T}2000398934016${T}644245094400${T}1261404782592${T}sdd${T}36000${T}/mnt/arquivo"
