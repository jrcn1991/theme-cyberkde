# Roda DENTRO da sessão virtual (sessao.sh). Para cada variante: abre um Konsole em câmera lenta
# (16 s), fotografa sem parar, fecha em câmera lenta e fotografa de novo. Fotos com horário (ms).
set -u
T=${LENTO:-16000}
IDS=${IDS:-$(python3 -c 'import json,sys; print(" ".join(v["id"] for v in json.load(open(sys.argv[1]))))' "$project/effects/cyberkde_scan/variantes.json")}
out=${FOTOS:?pasta das fotos}; mkdir -p "$out"
printf '%s\n' $IDS >"$out/ordem"  # o montar.py casa os eventos do KWin com as variantes por esta ordem

# Fundo: o papel de parede do tema em tela cheia, abaixo de tudo (o KWin virtual não tem área de trabalho).
cat >"$tmp/fundo.js" <<'JS'
workspace.windowAdded.connect(function (w) {
    if (String(w.resourceClass).indexOf("gwenview") === -1) return;
    w.keepBelow = true; w.noBorder = true; w.skipTaskbar = true;
    w.frameGeometry = { x: 0, y: 0, width: 1600, height: 1000 };
});
JS
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/fundo.js" fundo)
qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
gwenview -f "$project/assets/wallpapers/desktop.png" >"$tmp/gwenview.log" 2>&1 &
sleep 5

# Posição fixa do Konsole e horário de entrada/saída das janelas no log do KWin.
cat >"$tmp/vigia.js" <<'JS'
workspace.windowAdded.connect(function (w) {
    if (String(w.resourceClass).indexOf("konsole") === -1) return;
    const g = w.frameGeometry;
    print("CYBERKDE-ADD " + Date.now() + " " + Math.round(g.x) + " " + Math.round(g.y) + " " + Math.round(g.width) + " " + Math.round(g.height));
});
workspace.windowRemoved.connect(function (w) {
    if (String(w.resourceClass).indexOf("konsole") !== -1) print("CYBERKDE-DEL " + Date.now());
});
JS
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/vigia.js" vigia)
qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
printf 'for (const w of workspace.windowList()) if (String(w.resourceClass).indexOf("konsole") !== -1) w.closeWindow();\n' >"$tmp/fecha.js"

cat >"$tmp/demo.sh" <<'EOF'
export PS1='\[\e[31m\]▌\[\e[0m\] \[\e[36m\]netrunner\[\e[0m\]@\[\e[31m\]night-city\[\e[0m\] › '
clear
printf '\e[31m▌ CYBERKDE\e[0m \e[90m// window animations\e[0m\n\n'
printf '\e[36mnetrunner\e[0m@\e[31mnight-city\e[0m › scan --target arasaka.tower\n'
for i in 01 02 03 04 05 06 07 08; do printf '\e[32m[ OK ]\e[0m node %s  \e[33m0x%04X\e[0m  ICE \e[35mbypassed\e[0m  trace %s%%\n' $i $((RANDOM)) $((RANDOM % 90)); done
printf '\e[31m[FAIL]\e[0m firewall  \e[36mretrying…\e[0m\n\e[35mwake up, samurai\e[0m\n'
exec bash --norc -i
EOF

fotos() {  # prefixo segundos
  local fim=$(( $(date +%s%3N) + $2 * 1000 )) t
  while (( $(date +%s%3N) < fim )); do
    t=$(date +%s%3N)
    spectacle -f -b -n -e -o "$out/$1_$t.png" >/dev/null 2>&1
  done
}

for v in $IDS; do
  kwriteconfig6 --file kwinrc --group Effect-cyberkde_scan --key AbrirVariante "$v"
  kwriteconfig6 --file kwinrc --group Effect-cyberkde_scan --key FecharVariante "$v"
  kwriteconfig6 --file kwinrc --group Effect-cyberkde_scan --key OpenDuration "$T"
  kwriteconfig6 --file kwinrc --group Effect-cyberkde_scan --key CloseDuration "$T"
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect cyberkde_scan
  sleep 0.5
  konsole --separate --hide-menubar --hide-tabbar -e bash --norc "$tmp/demo.sh" >/dev/null 2>&1 &
  fotos "$v-abrir" $(( T / 1000 + 2 ))
  id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp/fecha.js" "fecha-$v")
  qdbus6 org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null
  fotos "$v-fechar" $(( T / 1000 + 2 ))
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "fecha-$v" >/dev/null
  echo "$v pronto"
done
grep -E "CYBERKDE-(ADD|DEL)|cyberkde|[Ss]hader" "$tmp/kwin.log" >"$out/kwin-eventos.log"
cp "$tmp/kwin.log" "$out/kwin.log"
