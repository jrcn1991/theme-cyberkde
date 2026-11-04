#!/usr/bin/env python3
"""Vetoriza a silhueta real dos ícones que os apps instalam, em camadas de cor, para
assets/icons/apps/emblemas/<id>.json (lido pelo gen_apps_icons.py, sem dependência nova).

Ferramenta de manutenção; precisa do potracer (venv só para isso):
  python3 -m venv /tmp/vt && /tmp/vt/bin/pip install potracer numpy pillow
  /tmp/vt/bin/python generator/vetorizar_apps.py [id ...]     (sem ids: todos)
Cada app tem uma lista de camadas (de baixo para cima): a cor-mestre em que cada região do ícone original
vira (R vermelho, R2 escuro, R3 claro, C ciano, W branco, D escuro) e a regra que escolhe os pixels.
O SVG do PyCharm e do DataGrip entram direto (já são vetor), em emblemas/pycharm.json e datagrip.json.
"""
import os
import colorsys
import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
import potrace
from PIL import Image, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons" / "apps" / "emblemas"
HI = "/usr/share/icons/hicolor"
T = 512  # tamanho de trabalho


def carrega(src):
    if src.endswith(".svg"):
        with tempfile.TemporaryDirectory() as t:
            p = pathlib.Path(t) / "i.png"
            subprocess.run(["inkscape", src, "-o", str(p), "-w", str(T), "-h", str(T)], check=True, capture_output=True)
            return Image.open(p).convert("RGBA")
    im = Image.open(src).convert("RGBA")
    k = T / max(im.size)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    c = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    c.paste(im, ((T - im.width) // 2, (T - im.height) // 2))
    return c


def hsv(a):
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = d > 1e-6
    h[m & (mx == r)] = ((g - b)[m & (mx == r)] / d[m & (mx == r)]) % 6
    h[m & (mx == g)] = ((b - r)[m & (mx == g)] / d[m & (mx == g)]) + 2
    h[m & (mx == b)] = ((r - g)[m & (mx == b)] / d[m & (mx == b)]) + 4
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    lum = (rgb @ np.array([.299, .587, .114]))
    return h * 60, s, lum


def camadas_de(im, regras):
    a = np.asarray(im)
    h, s, L = hsv(a)
    al = a[..., 3] > 128
    out = []
    for fill, f in regras:
        out.append((fill, al & f(h, s, L)))
    return out, al


def traca(m, blur=1.1):
    if not m.any():
        return ""
    im = Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(blur))
    bm = potrace.Bitmap(~(np.asarray(im) > 127))
    out = []
    for cv in bm.trace(turdsize=24, alphamax=1.0, opticurve=True, opttolerance=0.6):
        fm = lambda p: f"{p.x:.1f} {p.y:.1f}"
        d = [f"M{fm(cv.start_point)}"]
        for sg in cv.segments:
            d.append(f"L{fm(sg.c)}L{fm(sg.end_point)}" if sg.is_corner else f"C{fm(sg.c1)} {fm(sg.c2)} {fm(sg.end_point)}")
        out.append("".join(d) + "Z")
    return "".join(out)


TUDO = lambda h, s, L: np.ones_like(L, bool)
claro = lambda lim, smax=1.0: (lambda h, s, L: (L > lim) & (s < smax))
escuro = lambda lim: (lambda h, s, L: L < lim)
def matiz(h0, h1, smin=0.25, lmin=0.0, lmax=1.01):
    return lambda h, s, L: (((h >= h0) & (h <= h1)) if h0 <= h1 else ((h >= h0) | (h <= h1))) & (s > smin) & (L >= lmin) & (L < lmax)


# id: (arquivo do ícone original, [(cor-mestre, regra)...] de baixo para cima)
APPS = {
    "claude-desktop": (f"{HI}/256x256/apps/claude-desktop.png", [("R", claro(0.82, 0.3))]),
    "google-chrome": (f"{HI}/256x256/apps/google-chrome.png", [("W", claro(0.85, 0.2)), ("R", matiz(340, 25, 0.5)), ("R3", matiz(35, 70, 0.4)), ("R2", matiz(90, 170, 0.35)), ("C", matiz(195, 240, 0.5))]),
    "spotify": (f"{HI}/512x512/apps/spotify-client.png", [("R", TUDO), ("D", escuro(0.28))]),
    "1password": (f"{HI}/512x512/apps/1password.png", [("W", TUDO), ("R", matiz(200, 255, 0.35, 0.0, 0.75)), ("D", escuro(0.2))]),
    "telegram": (str(pathlib.Path.home() / ".local/share/icons/hicolor/256x256/apps/telegram.png"), [("R", TUDO), ("W", claro(0.86, 0.22))]),
    "obs-studio": (f"{HI}/scalable/apps/com.obsproject.Studio.svg", [("R", claro(0.45))]),
    "remmina": (f"{HI}/scalable/apps/org.remmina.Remmina.svg", [("R", matiz(195, 240, 0.3)), ("R2", matiz(130, 175, 0.3))]),
    "filezilla": (f"{HI}/scalable/apps/filezilla.svg", [("R", matiz(340, 20, 0.5)), ("W", claro(0.8, 0.25))]),
    "virtualbox": (f"{HI}/64x64/apps/virtualbox.png", [("R", matiz(165, 205, 0.3)), ("R3", matiz(20, 50, 0.4))]),
    "kate": (f"{HI}/scalable/apps/kate.svg", [("R", TUDO), ("R3", claro(0.6, 0.45)), ("W", claro(0.86, 0.3))]),
    "libreoffice": (f"{HI}/scalable/apps/libreoffice-main.svg", [("R2", TUDO), ("R3", claro(0.55)), ("W", claro(0.88))]),
    "software": (f"{HI}/scalable/apps/kubuntu-manage-software.svg", [("R", TUDO), ("W", claro(0.82, 0.3)), ("R2", escuro(0.35))]),
    "vscode": ("/usr/share/pixmaps/vscode.png", [("R2", TUDO), ("R", lambda h, s, L: L > 0.38), ("R3", lambda h, s, L: L > 0.5)]),
    "shotcut": (f"{HI}/128x128/apps/org.shotcut.Shotcut.png", [("R", matiz(170, 215, 0.25))]),
    "cura": (str(pathlib.Path.home() / ".local/share/icons/hicolor/256x256/apps/cura-icon.png"), [("W", TUDO), ("R", matiz(200, 235, 0.5))]),
    "meshmixer": (str(pathlib.Path.home() / ".local/share/icons/hicolor/256x256/apps/meshmixer.png"), [("R", TUDO), ("R2", lambda h, s, L: (((h > 5) & (h < 35) & (s > 0.35)) | ((s < 0.35) & (L < 0.42)))), ("R3", lambda h, s, L: (s < 0.35) & (L > 0.52))]),
    "dbeaver": ("/usr/share/dbeaver-ce/dbeaver.png", [("R2", lambda h, s, L: (L < 0.5) & (s > 0.15) & (h > 10) & (h < 50)), ("R", lambda h, s, L: (L >= 0.5) & (L < 0.85) & (s > 0.12) & (h > 10) & (h < 50)), ("C", matiz(165, 200, 0.3))]),
}


def vetoriza(aid):
    src, regras = APPS[aid]
    im = carrega(src)
    camadas, al = camadas_de(im, regras)
    ys, xs = np.where(np.any([m for _, m in camadas], axis=0))
    caixa = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{aid}.json").write_text(json.dumps({"fonte": os.path.basename(str(src)), "tamanho": T, "caixa": caixa, "camadas": [{"cor": c, "d": traca(m)} for c, m in camadas]}) + "\n")
    print(aid, caixa, [len(traca(m)) for _, m in camadas])


if __name__ == "__main__":
    for aid in (sys.argv[1:] or APPS):
        vetoriza(aid)
