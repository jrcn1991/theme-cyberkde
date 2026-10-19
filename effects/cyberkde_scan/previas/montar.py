"""Monta as prévias animadas (WebP 320×200, em loop) a partir das fotos em câmera lenta do KWin virtual.

  montar.py FOTOS SAIDA [LENTO_MS]

Cada foto tem o horário de gravação (mtime); o progresso dela é (mtime - t0) / LENTO, com t0 = horário em
que o KWin anunciou a janela (abrir) ou o fechamento (fechar), lidos de kwin-eventos.log.
"""
import glob, json, os, re, sys
from PIL import Image

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
fotos, saida = sys.argv[1], sys.argv[2]
LENTO = float(sys.argv[3]) if len(sys.argv) > 3 else 16000.0
GRAVA_MS = 90.0  # a foto é salva um pouco depois de capturada
cat = json.load(open(os.path.join(PROJ, "effects/cyberkde_scan/variantes.json")))
ev = open(os.path.join(fotos, "kwin-eventos.log")).read()
adds = [(int(m[0]), tuple(map(int, m[1:]))) for m in re.findall(r"CYBERKDE-ADD (\d+) (\d+) (\d+) (\d+) (\d+)", ev)]
dels = [int(m) for m in re.findall(r"CYBERKDE-DEL (\d+)", ev)]
os.makedirs(saida, exist_ok=True)
prancha = []
# Ordem em que o cena.sh gravou (pode ser só parte do catálogo): o k-ésimo evento é da k-ésima variante.
ordem_arq = os.path.join(fotos, "ordem")
ordem = open(ordem_arq).read().split() if os.path.isfile(ordem_arq) else [v["id"] for v in cat]
por_id = {v["id"]: v for v in cat}

for i, vid in enumerate(ordem):
    v = por_id.get(vid)
    if v is None:
        print(f"{vid}: não está no catálogo, pulando")
        continue
    if i >= len(adds) or i >= len(dels):
        print(f"{v['id']}: sem eventos, pulando")
        continue
    t_add, (x, y, w, h) = adds[i]
    cx, cy = x + w / 2, y + h / 2
    cw = w * 1.1
    ch = cw / 1.6
    box = (round(cx - cw / 2), round(cy - ch / 2), round(cx + cw / 2), round(cy + ch / 2))
    for lado, t0, dur in (("abrir", t_add, v["duracaoAbrir"]), ("fechar", dels[i], v["duracaoFechar"])):
        arqs = glob.glob(os.path.join(fotos, f"{v['id']}-{lado}_*.png"))
        prog = sorted(((os.stat(a).st_mtime_ns / 1e6 - GRAVA_MS - t0) / LENTO, a) for a in arqs)
        n = max(2, round(dur / 33.3))
        quadros, tempos = [], []
        def pega(p):
            return min(prog, key=lambda q: abs(q[0] - p))[1]
        def img(a):
            return Image.open(a).convert("RGB").crop(box).resize((320, 200), Image.LANCZOS)
        if lado == "abrir":
            antes = [a for p, a in prog if p < 0] or [prog[0][1]]
            quadros.append(img(antes[-1])); tempos.append(400)
        else:
            depois_cheio = [a for p, a in prog if p < 0]
            quadros.append(img(depois_cheio[-1] if depois_cheio else pega(0.0))); tempos.append(500)
        usados = []
        for k in range(1, n + 1):
            a = pega(k / n)
            usados.append(a)
            quadros.append(img(a)); tempos.append(round(dur / n))
        if lado == "abrir":
            tempos[-1] = 900  # segura a janela pronta antes de repetir
        else:
            fim = [a for p, a in prog if p > 1.05]
            quadros.append(img(fim[0] if fim else usados[-1])); tempos.append(350)
        destino = os.path.join(saida, f"{v['id']}-{lado}.webp")
        quadros[0].save(destino, save_all=True, append_images=quadros[1:], duration=tempos, loop=0,
                        quality=50, method=6)
        prancha.append((v["id"], lado, quadros[1:-1] if lado == "fechar" else quadros[1:]))
        print(f"{v['id']}-{lado}: {len(quadros)} quadros, {os.path.getsize(destino) // 1024} KB, fotos {len(arqs)}")

# Prancha de conferência: 8 quadros por animação.
if prancha:
    cols = 8
    folha = Image.new("RGB", (cols * 162 + 110, len(prancha) * 102), (25, 25, 25))
    from PIL import ImageDraw
    d = ImageDraw.Draw(folha)
    for r, (vid, lado, qs) in enumerate(prancha):
        d.text((4, r * 102 + 40), f"{vid}\n{lado}", fill=(255, 220, 0))
        for c in range(cols):
            q = qs[min(len(qs) - 1, round(c * (len(qs) - 1) / (cols - 1)))]
            folha.paste(q.resize((160, 100)), (110 + c * 162, r * 102))
    folha.save(os.path.join(fotos, "prancha-kwin.png"))
