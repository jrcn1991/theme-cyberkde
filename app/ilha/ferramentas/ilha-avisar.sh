#!/usr/bin/env bash
# Publica um aviso ou uma atividade na ilha do CyberKDE, pela API local (socket Unix 0600).
#   ilha-avisar.sh "Deploy pronto" "produção" ok
#   ilha-avisar.sh --atividade build-1 "npm run build"            # começa
#   ilha-avisar.sh --atividade build-1 "npm run build" ok "12s"   # termina
#   ilha-avisar.sh --atividade cp "copiando" andamento "" 0.4     # progresso
# Sem a ilha de pé (socket ausente) sai em silêncio: um hook não pode falhar por causa de um enfeite.
set -u
sock="${XDG_RUNTIME_DIR:-/tmp}/cyberkde-ilha.sock"
[ -S "$sock" ] || exit 0
exec python3 - "$sock" "$@" <<'PY'
import json, socket, sys
a = sys.argv[1:]; sock = a.pop(0)
if a and a[0] == "--atividade":
    m = {"tipo": "atividade", "id": a[1], "titulo": a[2] if len(a) > 2 else ""}
    if len(a) > 3: m["estado"] = a[3]
    if len(a) > 4 and a[4]: m["detalhe"] = a[4]
    if len(a) > 5: m["progresso"] = float(a[5])
else:
    m = {"tipo": "aviso", "titulo": a[0] if a else "", "detalhe": a[1] if len(a) > 1 else "", "nivel": a[2] if len(a) > 2 else "ok"}
s = socket.socket(socket.AF_UNIX); s.settimeout(1)
try:
    s.connect(sock); s.sendall((json.dumps(m) + "\n").encode()); s.recv(100)
except OSError:
    pass
PY
