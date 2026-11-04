#!/usr/bin/env python3
"""Gerador do papel de parede animado FUI (org.cyberkde.fui).

  gen_fui.py gerar                 corps.js (cores, nomes, logos) de tokens/corporacoes.json, os SVGs das
                                   corporações dentro do pacote e os shaders compilados (.qsb)
  gen_fui.py estatico ID [SAIDA]   quadro estático 3840x2160 (PNG) para o bloqueio e o login
                                   (padrão: modules/papeis-de-parede/build/fui/ID.png)
  gen_fui.py previa ID [SAIDA]     prévia animada (WebP) do papel (padrão: assets/previas/papel/fui-ID.webp)
  gen_fui.py quadros ID PASTA --de T0 --ate T1 --passo DT [--largura W --altura H]
                                   quadros PNG soltos (pranchas de comparação, testes)

Os comandos que renderizam precisam de uma tela com OpenGL (na sessão: a do usuário, com uma janela
fora da vista que fecha sozinha; nos testes: Xvfb com GLX).

Cores: a Arasaka usa as cores MEDIDAS na referência (base cinza #111111, luz e fumaça só no vermelho:
G e B não mudam). As outras derivam do destaque e do fundo da paleta: a luz é o destaque saturado
(o canal mais fraco puxado para baixo), a fumaça é a luz a 22% e a base mistura o fundo com o #111111.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
PACOTE = os.path.join(AQUI, "org.cyberkde.fui")
CORPS_JSON = os.path.join(RAIZ, "tokens", "corporacoes.json")
ASSETS_CORP = os.path.join(RAIZ, "assets", "corporacoes")

# medidas da referência (GIF de 481 quadros, ver shaders/fui.frag)
ARASAKA = {"luz": "#C40000", "nevoa": "#2E0000", "base": "#111111"}
# o código no emblema (como o "ASC54" da referência): 3 letras e 2 dígitos estáveis por corporação
CODIGOS = {"arasaka": "ASC54"}


def hex2rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def rgb2hex(c):
    return "#" + "".join("%02X" % round(max(0, min(1, v)) * 255) for v in c)


def derivar(destaque, fundo):
    d = hex2rgb(destaque)
    mx, mn = max(d), min(d)
    # satura: o canal mais fraco desce, o mais forte vai a 0,85
    luz = [(v - mn * 0.7) / max(1e-6, mx - mn * 0.7) * 0.85 for v in d]
    nevoa = [v * 0.22 for v in luz]
    f = hex2rgb(fundo)
    base = [(a + 0x11 / 255) / 2 for a in f]
    return {"luz": rgb2hex(luz), "nevoa": rgb2hex(nevoa), "base": rgb2hex(base)}


def codigo_de(cid):
    if cid in CODIGOS:
        return CODIGOS[cid]
    letras = (cid[0] + cid[len(cid) // 2] + cid[-1]).upper()
    n = sum(ord(ch) * (i + 3) for i, ch in enumerate(cid)) % 90 + 10
    return "%s%d" % (letras, n)


def carregar():
    d = json.load(open(CORPS_JSON, encoding="utf-8"))["corporacoes"]
    return d.values() if isinstance(d, dict) else d


def tons(arq):
    """Luminância (0–1) da cor mais escura e da mais clara do SVG; a tinta em dois tons usa as duas, e um logo de
    uma cor só (ou de cores quase iguais) fica num tom só."""
    if not arq:
        return [0.0, 0.0]
    import re
    ls = []
    for h in re.findall(r'fill="#([0-9A-Fa-f]{6})"', open(os.path.join(ASSETS_CORP, arq), encoding="utf-8").read()):
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        ls.append(0.3 * r + 0.59 * g + 0.11 * b)
    return [round(min(ls), 3), round(max(ls), 3)] if len(ls) > 1 and max(ls) - min(ls) >= 0.15 else [0.0, 0.0]


def tabela():
    """Lista de corporações com as cores do papel e os arquivos de logo/emblema (só os que existem)."""
    out = []
    for c in carregar():
        cid = c["id"]
        cores = ARASAKA if cid == "arasaka" else derivar(c["destaque"], c["fundo"])
        # para fundo escuro: a versão "-logo-escuro", quando existe, mantém o recorte interno (as folhas da Biotechnica)
        logo = "%s-logo-escuro.svg" % cid
        if not os.path.exists(os.path.join(ASSETS_CORP, logo)):
            logo = "%s-logo.svg" % cid
        emb = "%s.svg" % cid
        out.append({
            "id": cid,
            "nome": c["nome"] if cid != "nenhuma" else "CyberKDE",
            "nomeExibido": c["nome"],
            "lema": c.get("lema_en", ""),
            "codigo": codigo_de(cid),
            "luz": cores["luz"], "nevoa": cores["nevoa"], "base": cores["base"],
            "texto": "#EEEEEE",
            "logo": logo if os.path.exists(os.path.join(ASSETS_CORP, logo)) else "",
            "emblema": emb if os.path.exists(os.path.join(ASSETS_CORP, emb)) else "",
        })
        out[-1]["tonsLogo"] = tons(out[-1]["logo"])
        out[-1]["tonsEmblema"] = tons(out[-1]["emblema"])
    return out


def qsb():
    """O compilador de shaders do Qt (qsb): $QSB, no PATH, no Qt do sistema ou no PySide6."""
    if os.environ.get("QSB") and os.path.exists(os.environ["QSB"]):
        return os.environ["QSB"]
    for c in ("qsb", "/usr/lib/qt6/bin/qsb", "/usr/lib/x86_64-linux-gnu/qt6/bin/qsb"):
        if shutil.which(c) or os.path.exists(c):
            return shutil.which(c) or c
    try:
        import PySide6  # noqa
        c = os.path.join(os.path.dirname(PySide6.__file__), "qsb")
        if os.path.exists(c):
            return c
    except ImportError:
        pass
    return None


def gerar():
    corps = tabela()
    js = ["// GERADO por modules/papeis-de-parede/animado/gen_fui.py a partir de tokens/corporacoes.json: não editar.",
          ".pragma library", "",
          "var CORPS = " + json.dumps(corps, ensure_ascii=False, indent=1) + ";", "",
          "function de(id) {",
          "    for (var i = 0; i < CORPS.length; i++) if (CORPS[i].id === id) return CORPS[i];",
          "    for (var j = 0; j < CORPS.length; j++) if (CORPS[j].id === \"arasaka\") return CORPS[j];",
          "    return CORPS[0];",
          "}",
          "function lista() { return CORPS; }", ""]
    with open(os.path.join(PACOTE, "contents", "ui", "corps.js"), "w", encoding="utf-8") as f:
        f.write("\n".join(js))
    img = os.path.join(PACOTE, "contents", "images", "corp")
    os.makedirs(img, exist_ok=True)
    for c in corps:
        for k in ("logo", "emblema"):
            if c[k]:
                shutil.copyfile(os.path.join(ASSETS_CORP, c[k]), os.path.join(img, c[k]))
    q = qsb()
    sh = os.path.join(PACOTE, "contents", "shaders")
    if q:
        for nome in ("fui", "tingir"):
            src = os.path.join(sh, nome + ".frag")
            subprocess.run([q, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", src + ".qsb", src], check=True)
    else:
        print("aviso: qsb não encontrado; os .qsb do pacote não foram refeitos", file=sys.stderr)
    print("gerado: %d corporações, logos em %s" % (len(corps), os.path.relpath(img, RAIZ)))


# ---------------------------------------------------------------- renderização
RENDER = r'''
import sys, json, os
from PyQt6.QtCore import QUrl, QTimer, Qt
from PyQt6.QtGui import QGuiApplication, QColor
from PyQt6.QtQuick import QQuickView
a = json.loads(sys.argv[1])
app = QGuiApplication(sys.argv[:1])
v = QQuickView()
v.setColor(QColor("black"))
v.setFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowDoesNotAcceptFocus | Qt.WindowType.Tool)
v.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
v.setSource(QUrl.fromLocalFile(a["cena"]))
if v.status() != QQuickView.Status.Ready:
    for e in v.errors(): print(e.toString(), file=sys.stderr)
    sys.exit(1)
r = v.rootObject()
c = a["corp"]
base = os.path.dirname(a["cena"]) + "/../images/corp/"
props = {"corLuz": QColor(c["luz"]), "corNevoa": QColor(c["nevoa"]), "corBase": QColor(c["base"]), "corTexto": QColor(c["texto"]),
         "logo": QUrl.fromLocalFile(base + c["logo"]) if c["logo"] and a.get("logo", True) else QUrl(),
         "emblema": QUrl.fromLocalFile(base + c["emblema"]) if c["emblema"] and a.get("logo", True) else QUrl(),
         "nome": c["nome"], "lema": c["lema"], "codigo": c["codigo"], "grao": a.get("grao", 1.0),
         "tonsLogo": c.get("tonsLogo", [0, 0]), "tonsEmblema": c.get("tonsEmblema", [0, 0]),
         "mostrarTextos": a.get("textos", True), "intensidade": a.get("intensidade", 1.0), "comEntrada": bool(a.get("entrada"))}
for k, val in props.items(): r.setProperty(k, val)
v.resize(a["largura"], a["altura"])
v.setPosition(-a["largura"] - 200, 0)
tempos = a["tempos"]; i = [0]; esperando = [3]; pedido = [False]
def quadro():
    if a.get("entrada"): r.setProperty("decorrido", tempos[i[0]])
    r.setProperty("tempoFixo", tempos[i[0]])
    pedido[0] = True
    v.update()
def trocou():
    if esperando[0] > 0:          # primeiros quadros: imagens (SVG) carregando
        esperando[0] -= 1; QTimer.singleShot(60, quadro); return
    if not pedido[0]:             # quadro extra (o grabWindow redesenha): não é um tempo novo
        return
    pedido[0] = False
    img = v.grabWindow()
    img.save(a["saida"] % i[0])
    i[0] += 1
    if i[0] >= len(tempos): app.quit(); return
    QTimer.singleShot(0, quadro)
v.frameSwapped.connect(trocou)
v.show()
QTimer.singleShot(200, quadro)
app.exec()
'''


def render(cid, tempos, padrao_saida, largura, altura, **extra):
    corp = next((c for c in tabela() if c["id"] == cid), None)
    if not corp:
        sys.exit("corporação desconhecida: %s" % cid)
    if not os.path.exists(os.path.join(PACOTE, "contents", "ui", "corps.js")):
        gerar()
    a = {"cena": os.path.join(PACOTE, "contents", "ui", "Cena.qml"), "corp": corp, "tempos": tempos,
         "saida": padrao_saida, "largura": largura, "altura": altura, **extra}
    subprocess.run([sys.executable, "-c", RENDER, json.dumps(a)], check=True)


# instante bonito para o estático: um pulso no meio do feixe principal, retículo aceso, sem glitch
T_ESTATICO = 1.52


def estatico(cid, saida):
    saida = saida or os.path.join(RAIZ, "modules", "papeis-de-parede", "build", "fui", cid + ".png")
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        render(cid, [T_ESTATICO], os.path.join(tmp, "q%04d.png"), 3840, 2160, grao=0.6)
        shutil.move(os.path.join(tmp, "q0000.png"), saida)
    print(saida)


def previa(cid, saida, segundos=4.8, fps=15, largura=480, altura=270):
    saida = saida or os.path.join(RAIZ, "assets", "previas", "papel", "fui-%s.webp" % cid)
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    # do meio do arranjo A até o glitch (75% do ciclo de 14,4 s fica em 10,8 s: a prévia pega 0,6–5,4 s)
    tempos = [0.6 + k / fps for k in range(int(segundos * fps))]
    with tempfile.TemporaryDirectory() as tmp:
        # renderiza em 2x e reduz (o grão fica fino como na tela)
        render(cid, tempos, os.path.join(tmp, "q%04d.png"), largura * 2, altura * 2)
        quadros = sorted(os.path.join(tmp, f) for f in os.listdir(tmp))
        subprocess.run(["magick", "-delay", str(round(100 / fps)), *quadros, "-resize", "%dx%d" % (largura, altura),
                        "-loop", "0", "-quality", "62", "-define", "webp:method=6", saida], check=True)
    print(saida)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("acao", choices=["gerar", "estatico", "previa", "quadros"])
    ap.add_argument("id", nargs="?")
    ap.add_argument("saida", nargs="?")
    ap.add_argument("--de", type=float, default=0)
    ap.add_argument("--ate", type=float, default=1)
    ap.add_argument("--passo", type=float, default=0.03)
    ap.add_argument("--largura", type=int, default=1600)
    ap.add_argument("--altura", type=int, default=900)
    ap.add_argument("--sem-logo", action="store_true")
    ap.add_argument("--sem-textos", action="store_true")
    ap.add_argument("--entrada", action="store_true", help="quadros: simula a entrada (o tempo também é o decorrido)")
    a = ap.parse_args()
    if a.acao == "gerar":
        gerar()
    elif a.acao == "estatico":
        estatico(a.id or "arasaka", a.saida)
    elif a.acao == "previa":
        previa(a.id or "arasaka", a.saida)
    else:
        os.makedirs(a.saida, exist_ok=True)
        n = int(round((a.ate - a.de) / a.passo)) + 1
        render(a.id or "arasaka", [a.de + k * a.passo for k in range(n)], os.path.join(a.saida, "q%04d.png"),
               a.largura, a.altura, logo=not a.sem_logo, textos=not a.sem_textos, entrada=a.entrada)


if __name__ == "__main__":
    main()
