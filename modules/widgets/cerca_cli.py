#!/usr/bin/env python3
"""Motor da Cyber Fence no CLI (chamado pelo modules/widgets/phase.sh, com "cyberkde cerca ...").

Tudo fica em $XDG_CONFIG_HOME/cyberkde/cercas/:
  regras.json       {"regras":[OrganizeRule...]}
  historico.jsonl   uma linha por arquivo movido: {lote, quando, regra, origem, destino, guardado}
  guardados/<lote>/ o que um "sobrescrever" substituiu (o desfazer devolve)
  snapshots/<nome>.json   posições, tamanhos, títulos, pastas, recolhido e a configuração das cercas
  backups/          appletsrc antes de restaurar, regras antes de importar, cópias do "backup"
  ocultas           existe = cercas ocultas (o widget vigia)

OrganizeRule (a do Desktop Fences+, FENCES-DISCOVERY.md 2.4): {id, nome, ativa, extensoes:[...], nomeContem,
  destino, prioridade, conflito, autoCriarCerca, ultimaExecucao, esperarDestravar}
  destino: caminho, ~/..., file:///... ou cerca:<id da instância>. Menor prioridade vem antes; vale a
  primeira regra que casar. conflito: renomear | pular | sobrescrever. extensoes e nomeContem somam (E);
  "*" nas extensões = qualquer uma. autoCriarCerca: cria uma cerca para o destino, se não houver.

Saída: JSON com --json; código 0 ok · 2 uso ou dado inválido · 3 ocupado.
"""
import datetime
import fcntl
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import urllib.parse

CFG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "cyberkde", "cercas")
REGRAS = os.path.join(CFG, "regras.json")
HIST = os.path.join(CFG, "historico.jsonl")
SNAPS = os.path.join(CFG, "snapshots")
BACKUPS = os.path.join(CFG, "backups")
CONFLITOS = ("renomear", "pular", "sobrescrever")
# Download pela metade e temporários nunca entram numa regra.
TEMPORARIOS = (".part", ".crdownload", ".tmp", ".download", ".kate-swp", ".swp", "~")
NOME_SNAP = re.compile(r"^[^\W_][\w .-]{0,59}$")


def erro(msg, codigo=2):
    if "--json" in sys.argv:
        print(json.dumps({"erro": msg, "codigo": codigo}, ensure_ascii=False))
    else:
        print(msg, file=sys.stderr)
    sys.exit(codigo)


def agora():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def ler_json(arq, padrao):
    try:
        with open(arq, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


def gravar_json(arq, dados):
    os.makedirs(os.path.dirname(arq), exist_ok=True)
    novo = arq + ".novo"
    with open(novo, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=1)
    os.replace(novo, arq)


def saida(dados, texto=None):
    if "--json" in sys.argv or texto is None:
        print(json.dumps(dados, ensure_ascii=False, separators=(",", ":")))
    else:
        print(texto)


def trava():
    os.makedirs(CFG, exist_ok=True)
    f = open(os.path.join(CFG, ".regras.lock"), "w")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        erro("ocupado: outra organização está em andamento", 3)
    return f


def args_opcoes(args, com_valor):
    """--chave valor: devolve (dicionário, posicionais). --json e flags ficam de fora."""
    op, pos = {}, []
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--") and a[2:] in com_valor:
            if i + 1 >= len(args):
                erro("falta o valor de " + a)
            op[a[2:]] = args[i + 1]
            i += 2
        elif a.startswith("--"):
            op[a[2:]] = True
            i += 1
        else:
            pos.append(a)
            i += 1
    return op, pos


# ------------------------------------------------------------------ regras
def regras_ler():
    d = ler_json(REGRAS, {})
    return d.get("regras", []) if isinstance(d, dict) else []


def regras_gravar(rs):
    gravar_json(REGRAS, {"regras": rs})


def caminho(destino):
    """Caminho local de um destino; "" se não houver (cerca sem pasta ou desconhecida)."""
    d = str(destino or "").strip()
    if d.startswith("cerca:"):
        d = str(json.loads(os.environ.get("CERCAS_JSON") or "{}").get(d[6:]) or "")
    if d.startswith("file://"):
        d = urllib.parse.unquote(d[7:])
    if d.startswith("~"):
        d = os.path.expanduser(d)
    return d if d.startswith("/") else ""


def normaliza_regra(op, r=None):
    r = dict(r or {})
    if "nome" in op:
        r["nome"] = str(op["nome"])
    if "extensoes" in op:
        v = op["extensoes"]
        lista = v if isinstance(v, list) else re.split(r"[;, ]+", str(v))
        r["extensoes"] = [("*" if str(e).strip() in ("*", "*.*") else str(e).strip().lstrip("*.").lower()) for e in lista if str(e).strip()]
    if "contem" in op:
        r["nomeContem"] = str(op["contem"])
    if "destino" in op:
        r["destino"] = str(op["destino"])
    if "prioridade" in op:
        try:
            r["prioridade"] = int(op["prioridade"])
        except (TypeError, ValueError):
            erro("prioridade: um número inteiro")
    if "conflito" in op:
        r["conflito"] = str(op["conflito"])
    if "esperar" in op:
        if op["esperar"] not in ("on", "off"):
            erro("--esperar: on ou off")
        r["esperarDestravar"] = op["esperar"] == "on"
    if "criar-cerca" in op:
        if op["criar-cerca"] not in ("on", "off"):
            erro("--criar-cerca: on ou off")
        r["autoCriarCerca"] = op["criar-cerca"] == "on"
    r.setdefault("autoCriarCerca", False)
    r.setdefault("ultimaExecucao", None)
    r.setdefault("nome", r.get("destino", ""))
    r.setdefault("ativa", True)
    r.setdefault("extensoes", [])
    r.setdefault("nomeContem", "")
    r.setdefault("prioridade", 100)
    r.setdefault("conflito", "renomear")
    r["esperarDestravar"] = not op.get("sem-esperar") if "sem-esperar" in op else r.get("esperarDestravar", True)
    if r["conflito"] not in CONFLITOS:
        erro("conflito: renomear, pular ou sobrescrever")
    if not r.get("extensoes") and not r.get("nomeContem"):
        erro("a regra precisa de --extensoes ou --contem")
    if not r.get("destino"):
        erro("a regra precisa de --destino")
    if not str(r["destino"]).startswith("cerca:") and not caminho(r["destino"]):
        erro("destino: caminho absoluto, ~/... ou cerca:<id>")
    return r


def casa(r, nome):
    if not r.get("ativa", True):
        return False
    base = nome.lower()
    ext = r.get("extensoes")
    if ext and "*" not in ext and os.path.splitext(base)[1].lstrip(".") not in ext:
        return False
    return not r.get("nomeContem") or r["nomeContem"].lower() in base


def abertos_para_escrita():
    """Arquivos que algum processo da pessoa tem aberto para escrita agora."""
    abertos = set()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fds = "/proc/%s/fd" % pid
        try:
            for fd in os.listdir(fds):
                p = os.path.join(fds, fd)
                if os.lstat(p).st_mode & stat.S_IWUSR:
                    abertos.add(os.readlink(p))
        except OSError:
            continue
    return abertos


def destravado(arq, abertos, espera=5.0):
    """Espera o arquivo parar de crescer e ninguém o ter aberto para escrita, por até "espera" s."""
    fim = time.time() + espera
    while True:
        try:
            st = os.stat(arq)
        except OSError:
            return False
        recente = time.time() - st.st_mtime < 2
        if not recente and arq not in abertos:
            return True
        if time.time() >= fim:
            return False
        time.sleep(0.5)
        abertos = abertos_para_escrita()


def destino_livre(pasta, nome):
    alvo = os.path.join(pasta, nome)
    if not os.path.lexists(alvo):
        return alvo
    raiz, ext = os.path.splitext(nome)
    n = 2
    while os.path.lexists(os.path.join(pasta, "%s (%d)%s" % (raiz, n, ext))):
        n += 1
    return os.path.join(pasta, "%s (%d)%s" % (raiz, n, ext))


def origem_padrao():
    try:
        d = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True).stdout.strip()
    except OSError:
        d = ""
    return d if d and d.rstrip("/") != os.path.expanduser("~") else os.path.expanduser("~/Desktop")


def aplicar(args):
    op, _ = args_opcoes(args, {"origem"})
    simular = bool(op.get("simular"))
    origem = caminho(op.get("origem", "")) or origem_padrao()
    if "origem" in op and not caminho(op["origem"]):
        erro("--origem: caminho absoluto ou ~/...")
    if not os.path.isdir(origem):
        erro("pasta de origem não encontrada: " + origem)
    trava_f = None if simular else trava()
    regras = sorted((r for r in regras_ler() if r.get("ativa", True)), key=lambda r: r.get("prioridade", 100))
    lote = agora() + "-%d" % os.getpid()
    movidos, pulados, sem_regra = [], [], 0
    abertos = None
    reservados = set()  # no --simular nada é movido: dois arquivos não podem "ganhar" o mesmo nome
    for nome in sorted(os.listdir(origem)):
        arq = os.path.join(origem, nome)
        if nome.startswith(".") or nome.endswith(TEMPORARIOS) or nome.endswith(".desktop"):
            continue
        if os.path.islink(arq) or not os.path.isfile(arq):
            continue
        r = next((x for x in regras if casa(x, nome)), None)
        if not r:
            sem_regra += 1
            continue
        pasta = caminho(r.get("destino"))
        if not pasta:
            pulados.append({"arquivo": arq, "regra": r["id"], "motivo": "destino sem pasta"})
            continue
        if os.path.realpath(pasta) == os.path.realpath(origem):
            continue
        if r.get("esperarDestravar", True) and not simular:
            if abertos is None:
                abertos = abertos_para_escrita()
            if not destravado(arq, abertos):
                pulados.append({"arquivo": arq, "regra": r["id"], "motivo": "em uso"})
                continue
        alvo = os.path.join(pasta, nome)
        acao = "mover"
        if os.path.lexists(alvo) or alvo in reservados:
            if r.get("conflito") == "pular":
                pulados.append({"arquivo": arq, "regra": r["id"], "motivo": "já existe no destino"})
                continue
            if r.get("conflito") == "sobrescrever":
                acao = "sobrescrever"
            else:
                acao = "renomear"
                alvo = destino_livre(pasta, nome)
                while alvo in reservados:
                    alvo = alvo + "_"
        reservados.add(alvo)
        item = {"arquivo": arq, "destino": alvo, "regra": r["id"], "acao": acao}
        if simular:
            movidos.append(item)
            continue
        guardado = ""
        try:
            os.makedirs(pasta, exist_ok=True)
            if acao == "sobrescrever" and os.path.lexists(alvo):
                # O substituído não se perde: vai para guardados/, e o desfazer o devolve.
                pg = os.path.join(CFG, "guardados", lote)
                os.makedirs(pg, exist_ok=True)
                guardado = destino_livre(pg, os.path.basename(alvo))
                shutil.move(alvo, guardado)
            shutil.move(arq, alvo)
        except OSError as e:
            pulados.append({"arquivo": arq, "regra": r["id"], "motivo": str(e)})
            continue
        with open(HIST, "a", encoding="utf-8") as f:
            f.write(json.dumps({"lote": lote, "quando": agora(), "regra": r["id"], "origem": arq, "destino": alvo,
                                "guardado": guardado}, ensure_ascii=False) + "\n")
            f.flush()
            os.fsync(f.fileno())
        movidos.append(item)
    if movidos and not simular:
        # Última execução de cada regra, e as cercas que ela pede (o CLI as cria depois).
        usadas = {m["regra"] for m in movidos}
        todas = regras_ler()
        tem = {os.path.realpath(caminho(v)) for v in json.loads(os.environ.get("CERCAS_JSON") or "{}").values() if caminho(v)}
        criar = []
        for x in todas:
            if x.get("id") in usadas:
                x["ultimaExecucao"] = agora()
                pasta = caminho(x.get("destino"))
                if x.get("autoCriarCerca") and pasta and os.path.realpath(pasta) not in tem and pasta not in criar:
                    criar.append(pasta)
        regras_gravar(todas)
        if criar:
            with open(os.path.join(CFG, "criar-cercas"), "a", encoding="utf-8") as f:
                f.write("".join(c + "\n" for c in criar))
    del trava_f
    if op.get("vigia") and not movidos and not pulados:
        return
    r = {"simulado": simular, "lote": None if simular or not movidos else lote, "origem": origem,
         "movidos": movidos, "pulados": pulados, "semRegra": sem_regra}
    linhas = ["%s %s -> %s" % ("simular:" if simular else "movido:", os.path.basename(m["arquivo"]), m["destino"]) for m in movidos]
    linhas += ["pulado: %s (%s)" % (os.path.basename(p["arquivo"]), p["motivo"]) for p in pulados]
    saida(r, "\n".join(linhas) or "Nada a organizar.")


def historico():
    linhas = []
    try:
        with open(HIST, encoding="utf-8") as f:
            for l in f:
                try:
                    linhas.append(json.loads(l))
                except ValueError:
                    continue
    except OSError:
        pass
    return linhas


def lotes(linhas):
    vistos = {}
    for l in linhas:
        if l.get("desfeito"):
            continue
        vistos.setdefault(l["lote"], []).append(l)
    return vistos


def desfazer(args):
    _, pos = args_opcoes(args, set())
    t = trava()
    linhas = historico()
    por_lote = lotes(linhas)
    if not por_lote:
        erro("nada a desfazer")
    lote = pos[0] if pos else list(por_lote)[-1]
    if lote not in por_lote:
        erro("lote desconhecido: " + lote)
    devolvidos, conflitos = 0, []
    for l in reversed(por_lote[lote]):
        if not os.path.lexists(l["destino"]):
            conflitos.append({"arquivo": l["destino"], "motivo": "não está mais no destino"})
            continue
        if os.path.lexists(l["origem"]):
            conflitos.append({"arquivo": l["origem"], "motivo": "já existe outro arquivo na origem"})
            continue
        try:
            os.makedirs(os.path.dirname(l["origem"]), exist_ok=True)
            shutil.move(l["destino"], l["origem"])
            if l.get("guardado") and os.path.lexists(l["guardado"]):
                shutil.move(l["guardado"], l["destino"])
        except OSError as e:
            conflitos.append({"arquivo": l["destino"], "motivo": str(e)})
            continue
        l["desfeito"] = True
        devolvidos += 1
    novo = HIST + ".novo"
    with open(novo, "w", encoding="utf-8") as f:
        for l in linhas:
            f.write(json.dumps(l, ensure_ascii=False) + "\n")
    os.replace(novo, HIST)
    pg = os.path.join(CFG, "guardados", lote)
    if os.path.isdir(pg) and not os.listdir(pg):
        os.rmdir(pg)
    del t
    saida({"lote": lote, "devolvidos": devolvidos, "conflitos": conflitos},
          "%d arquivo(s) devolvido(s).%s" % (devolvidos, " %d com conflito." % len(conflitos) if conflitos else ""))


AJUDA = """cyberkde cerca regras                      lista as regras
  adicionar --destino D [--extensoes a,b] [--contem T] [--nome N] [--prioridade P]
            [--conflito renomear|pular|sobrescrever] [--criar-cerca on|off] [--esperar on|off]
  editar <id> (as mesmas opções) · remover <id> · ativar <id> · desativar <id>
  aplicar [--simular] [--origem P]          limpeza única (padrão: a Área de trabalho)
  desfazer [lote] · historico
Destino: caminho, ~/... ou cerca:<id>. Menor prioridade vem antes; vale a primeira que casar.
Para vigiar a Área de trabalho: cyberkde efeito widget-cerca --vigiar on (--simular antes é uma boa)."""


def cmd_regras(args):
    args = [a for a in args]
    sub = next((a for a in args if not a.startswith("--")), "lista")
    if args and sub in args:
        args.remove(sub)
    com_valor = {"destino", "extensoes", "contem", "nome", "prioridade", "conflito", "criar-cerca", "esperar"}
    rs = regras_ler()
    if sub in ("lista", "listar"):
        saida({"regras": sorted(rs, key=lambda r: r.get("prioridade", 100))},
              "\n".join("%s %s [%s] %s -> %s" % (r["id"], "●" if r.get("ativa", True) else "○", r.get("prioridade"),
                                                 ",".join(r.get("extensoes", [])) or r.get("nomeContem"), r.get("destino"))
                        for r in sorted(rs, key=lambda r: r.get("prioridade", 100))) or "Nenhuma regra.")
    elif sub == "ajuda":
        print(AJUDA)
    elif sub == "adicionar":
        op, _ = args_opcoes(args, com_valor)
        r = normaliza_regra(op)
        n = 1 + max([int(x["id"][1:]) for x in rs if re.match(r"^r\d+$", str(x.get("id")))] or [0])
        r["id"] = "r%d" % n
        regras_gravar(rs + [r])
        saida({"regra": r}, "Regra %s criada." % r["id"])
    elif sub in ("editar", "remover", "ativar", "desativar"):
        op, pos = args_opcoes(args, com_valor)
        if not pos or not any(x.get("id") == pos[0] for x in rs):
            erro("regra desconhecida: %s" % (pos[0] if pos else ""))
        if sub == "remover":
            rs = [x for x in rs if x["id"] != pos[0]]
        else:
            for i, x in enumerate(rs):
                if x["id"] == pos[0]:
                    x = normaliza_regra(op, x)
                    if sub != "editar":
                        x["ativa"] = sub == "ativar"
                    rs[i] = x
        regras_gravar(rs)
        saida({"regras": rs}, "Regra %s: %s." % (pos[0], sub))
    elif sub == "aplicar":
        aplicar(args)
    elif sub == "desfazer":
        desfazer(args)
    elif sub == "historico":
        por = lotes(historico())
        saida({"lotes": [{"lote": k, "quando": v[0]["quando"], "arquivos": len(v)} for k, v in por.items()]},
              "\n".join("%s %d arquivo(s)" % (k, len(v)) for k, v in por.items()) or "Nada no histórico.")
    else:
        erro("subcomando desconhecido: %s\n%s" % (sub, AJUDA))


# ------------------------------------------------------------------ snapshots
# Entrada dos comandos abaixo (stdin): {"telas":[{tela,d,off:{x,y},largura,altura}],
# "cercas":[{applet,tela,d,x,y,largura,altura,cfg:{"General|k":v}}]} (o que o Plasma diz agora).
def registro(arq):
    """applet -> chave da instância, do widgets.tsv."""
    m = {}
    try:
        with open(arq, encoding="utf-8") as f:
            for l in f:
                p = l.rstrip("\n").split("\t")
                if len(p) == 4 and (p[0] == "cerca" or p[0].startswith("cerca@")):
                    m[p[3]] = p[0]
    except OSError:
        pass
    return m


def chave_id(k):
    return k.split("@")[1] if "@" in k else "1"


def nome_valido(n):
    if not NOME_SNAP.match(n or ""):
        erro("nome inválido: use letras, números, espaço, ponto, hífen e sublinhado (até 60)")
    return n


def snap_arq(n):
    return os.path.join(SNAPS, nome_valido(n) + ".json")


def retrato(atual, reg_arq, nome, resolucao):
    reg = registro(reg_arq)
    cercas = []
    for c in atual.get("cercas", []):
        cfg = {k: v for k, v in c.get("cfg", {}).items() if k != "General|novaCerca"}
        if str(c.get("cfg", {}).get("General|novaCerca")) == "true":
            continue  # ainda sem nome
        k = reg.get(str(c["applet"]))
        cercas.append({"id": chave_id(k) if k else "a%s" % c["applet"], "tela": c["tela"], "x": c["x"], "y": c["y"],
                       "largura": c["largura"], "altura": c["altura"], "titulo": str(cfg.get("General|titulo", "")),
                       "pasta": str(cfg.get("General|url", "")), "recolhido": str(cfg.get("General|IsRolled", "")) == "true",
                       "cfg": cfg})
    return {"nome": nome, "criado": agora(), "resolucao": resolucao, "cercas": cercas}


def cmd_snap_gravar(args):
    nome, reg_arq, resolucao = args[0], args[1], args[2]
    arq = snap_arq(nome)
    s = retrato(json.load(sys.stdin), reg_arq, nome, resolucao)
    gravar_json(arq, s)
    saida({"snapshot": nome, "cercas": len(s["cercas"]), "resolucao": resolucao},
          "Snapshot '%s': %d cerca(s)." % (nome, len(s["cercas"])))


def snaps():
    r = []
    try:
        nomes = sorted(os.listdir(SNAPS))
    except OSError:
        nomes = []
    for f in nomes:
        if f.endswith(".json"):
            d = ler_json(os.path.join(SNAPS, f), {})
            r.append({"nome": f[:-5], "criado": d.get("criado"), "resolucao": d.get("resolucao"), "cercas": len(d.get("cercas", []))})
    return r


def cmd_snap_listar():
    r = snaps()
    saida({"snapshots": r}, "\n".join("%s  %s  %s  %d cerca(s)" % (s["nome"], s["criado"], s["resolucao"], s["cercas"]) for s in r) or "Nenhum snapshot.")


def cmd_snap_apagar(args):
    arq = snap_arq(args[0] if args else "")
    if not os.path.isfile(arq):
        erro("snapshot desconhecido: %s" % args[0])
    os.remove(arq)
    saida({"apagado": args[0]}, "Snapshot apagado.")


def cmd_snap_por_resolucao(args):
    """O snapshot mais novo daquela resolução, ou nada."""
    r = [s for s in snaps() if s["resolucao"] == args[0]]
    if r:
        print(max(r, key=lambda s: s["criado"] or "")["nome"])


def cmd_snap_plano(args):
    """Linha 1: plano do Plasma (quem sai e entra). Linha 2: {id: cfg} (só configuração, ao vivo).
    Depois: "criar <id-provisório> <chave|-> <tela> <contêiner>" dos que não existem mais."""
    nome, reg_arq = args[0], args[1]
    s = ler_json(snap_arq(nome), None)
    if not isinstance(s, dict):
        erro("snapshot desconhecido: %s" % nome)
    atual = json.load(sys.stdin)
    reg = registro(reg_arq)
    por_tela = {t["tela"]: t for t in atual.get("telas", [])}
    if not por_tela:
        erro("nenhuma área de trabalho", 1)
    primeira = atual["telas"][0]
    vivos = {str(c["applet"]): c for c in atual.get("cercas", [])}
    chave_ap = {k: a for a, k in reg.items()}
    usados, plano, config, criar = set(), [], {}, []
    falso = 9000000
    for it in s.get("cercas", []):
        alvo = None
        i = str(it.get("id"))
        if i.startswith("a"):
            alvo = i[1:] if i[1:] in vivos and i[1:] not in reg else None
        else:
            k = "cerca" if i == "1" else "cerca@" + i
            a = chave_ap.get(k)
            alvo = a if a in vivos else None
        if alvo is None or alvo in usados:
            alvo = next((a for a, c in vivos.items() if a not in usados and str(c["cfg"].get("General|url", "")) == it.get("pasta")
                         and str(c["cfg"].get("General|titulo", "")) == it.get("titulo")), None)
        t = por_tela.get(it.get("tela"), primeira)
        w, h = int(it["largura"]), int(it["altura"])
        x = max(0, min(int(it["x"]), t["largura"] - w))
        y = max(0, min(int(it["y"]), t["altura"] - h))
        r = {"x": x, "y": y, "width": w, "height": h}
        cfg = dict(it.get("cfg", {}))
        cfg.pop("__geo", None)
        cfg["General|IsRolled"] = "true" if it.get("recolhido") else "false"  # recolhida depois do snapshot volta
        if alvo is None:
            falso += 1
            k = None if i.startswith("a") else ("cerca" if i == "1" else "cerca@" + i)
            if k in chave_ap and chave_ap[k] in vivos:
                k = None  # a chave está em uso por outra cerca; a do snapshot sumiu
            plano.append({"id": falso, "d": t["d"], "tela": t["tela"], "r": r, "off": t["off"], "cfg": cfg, "plugin": "org.cyberkde.cerca"})
            criar.append("criar %d %s %s %s" % (falso, k or "-", t["tela"], t["d"]))
            continue
        usados.add(alvo)
        c = vivos[alvo]
        perto = c["tela"] == t["tela"] and all(abs(c[a] - b) < 16 for a, b in (("x", x), ("y", y), ("largura", w), ("altura", h)))
        if perto:
            config[alvo] = cfg
        else:
            plano.append({"id": int(alvo), "d": t["d"], "tela": t["tela"], "r": r, "off": t["off"], "cfg": cfg, "plugin": "org.cyberkde.cerca", "sai": True})
    print(json.dumps(plano, ensure_ascii=False, separators=(",", ":")))
    print(json.dumps(config, ensure_ascii=False, separators=(",", ":")))
    for l in criar:
        print(l)


def cmd_chave_telas(args):
    """Chave da combinação de telas: "DP-1:1920x1080+HDMI-A-1:1920x1080"."""
    try:
        d = json.loads(subprocess.run(["kscreen-doctor", "-j"], capture_output=True, text=True, timeout=5).stdout)
        partes = []
        for o in d.get("outputs", []):
            if o.get("enabled"):
                m = next((m for m in o.get("modes", []) if m.get("id") == o.get("currentModeId")), None)
                if m:
                    partes.append("%s:%dx%d" % (o["name"], m["size"]["width"], m["size"]["height"]))
        if partes:
            print("+".join(sorted(partes)))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        pass


# ------------------------------------------------------------------ backup, exportar, importar
def pacote(atual):
    return {"formato": "cyberkde-cercas", "versao": 1, "criado": agora(), "regras": regras_ler(),
            "snapshots": {s["nome"]: ler_json(os.path.join(SNAPS, s["nome"] + ".json"), {}) for s in snaps()}, "atual": atual}


def cmd_exportar(args):
    arq, reg_arq, resolucao = args[0], args[1], args[2]
    atual = retrato(json.load(sys.stdin), reg_arq, "atual", resolucao)
    os.makedirs(os.path.dirname(os.path.abspath(arq)), exist_ok=True)
    with open(arq, "w", encoding="utf-8") as f:
        json.dump(pacote(atual), f, ensure_ascii=False, indent=1)
    saida({"arquivo": arq, "cercas": len(atual["cercas"]), "regras": len(regras_ler()), "snapshots": len(snaps())},
          "Exportado em %s." % arq)


def cmd_importar(args):
    p = ler_json(args[0], None)
    if not isinstance(p, dict) or p.get("formato") != "cyberkde-cercas" or not isinstance(p.get("regras"), list):
        erro("arquivo que não é um pacote de cercas: %s" % args[0])
    limpas = []
    for r in p["regras"]:
        if not isinstance(r, dict) or not re.match(r"^r\d+$", str(r.get("id"))):
            erro("regra inválida no pacote")
        limpas.append(dict(normaliza_regra({}, r), id=r["id"]))
    snaps_novos = p.get("snapshots") or {}
    for nome in snaps_novos:  # tudo validado antes de gravar qualquer coisa
        nome_valido(nome)
    if os.path.isfile(REGRAS):
        os.makedirs(BACKUPS, exist_ok=True)
        shutil.copy2(REGRAS, os.path.join(BACKUPS, "regras-%s.json" % agora()))
    regras_gravar(limpas)
    importados = []
    for nome, s in snaps_novos.items():
        n = nome
        k = 2
        while os.path.exists(snap_arq(n)):  # nada é sobrescrito
            n = "%s-%d" % (nome[:56], k)
            k += 1
        gravar_json(snap_arq(n), dict(s, nome=n))
        importados.append(n)
    atual = ""
    if isinstance(p.get("atual"), dict):
        atual = "importado-" + agora()
        gravar_json(snap_arq(atual), dict(p["atual"], nome=atual))
    saida({"regras": len(limpas), "snapshots": importados, "atual": atual},
          "Importado: %d regra(s), %d snapshot(s)." % (len(limpas), len(importados)))


def cmd_estado():
    """Para o estado do widget-cerca: pedaço de JSON, começando com vírgula."""
    rs = regras_ler()
    por = lotes(historico())
    print(',"regras":{"total":%d,"ativas":%d,"desfazer":%s},"snapshots":%s' % (
        len(rs), sum(1 for r in rs if r.get("ativa", True)), json.dumps(list(por)[-1] if por else None),
        json.dumps(snaps(), ensure_ascii=False, separators=(",", ":"))))


def main():
    a = [x for x in sys.argv[1:] if x != "--json"]
    if not a:
        erro(__doc__)
    c, r = a[0], a[1:]
    if c == "regras":
        cmd_regras(r)
    elif c == "snap-gravar":
        cmd_snap_gravar(r)
    elif c == "snap-listar":
        cmd_snap_listar()
    elif c == "snap-apagar":
        cmd_snap_apagar(r)
    elif c == "snap-plano":
        cmd_snap_plano(r)
    elif c == "snap-resolucao":
        cmd_snap_por_resolucao(r)
    elif c == "nome-valido":
        nome_valido(r[0] if r else "")
    elif c == "chave-telas":
        cmd_chave_telas(r)
    elif c == "exportar":
        cmd_exportar(r)
    elif c == "importar":
        cmd_importar(r)
    elif c == "estado":
        cmd_estado()
    else:
        erro("comando desconhecido: " + c)


if __name__ == "__main__":
    main()
