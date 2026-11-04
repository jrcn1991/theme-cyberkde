#!/usr/bin/env python3
"""Vetoriza o emblema de um ícone de app (a silhueta real da marca) para assets/icons/apps/emblemas/<id>.json.

Ferramenta de manutenção, fora do fluxo do tema: precisa do potracer (venv só para isso):
  python3 -m venv /tmp/vt && /tmp/vt/bin/pip install potracer numpy pillow
  /tmp/vt/bin/python generator/vetorizar_emblema.py steam /usr/share/icons/hicolor/256x256/apps/steam.png
O gen_apps_icons.py só lê o JSON gerado (sem dependência nova).

Modo "claro": o emblema é a parte clara do ícone (luminância > corte) dentro do disco; o disco vem da caixa do alfa.
"""
import os
import json
import math
import pathlib
import sys

import numpy as np
import potrace
from PIL import Image, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icons" / "apps" / "emblemas"


def vetoriza(m, f=4, blur=1.2):
    h, w = m.shape
    im = Image.fromarray((m * 255).astype("uint8")).resize((w * f, h * f), Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur))
    bm = potrace.Bitmap(~(np.asarray(im) > 127))  # o potracer pinta o False
    out = []
    for cv in bm.trace(turdsize=30, alphamax=1.0, opticurve=True, opttolerance=0.5):
        fm = lambda p: f"{p.x / f:.2f} {p.y / f:.2f}"
        d = [f"M{fm(cv.start_point)}"]
        for sg in cv.segments:
            d.append(f"L{fm(sg.c)}L{fm(sg.end_point)}" if sg.is_corner else f"C{fm(sg.c1)} {fm(sg.c2)} {fm(sg.end_point)}")
        out.append("".join(d) + "Z")
    return "".join(out)


def main():
    nome, src = sys.argv[1], sys.argv[2]
    corte = int(sys.argv[3]) if len(sys.argv) > 3 else 150
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im)
    alfa = a[..., 3] > 128
    lum = np.asarray(im.convert("L")).astype(int)
    ys, xs = np.where(alfa)
    cx, cy, r = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2, (xs.max() - xs.min() + 1) / 2
    m = alfa & (lum > corte)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{nome}.json").write_text(json.dumps({"fonte": os.path.basename(str(src)), "tamanho": im.width, "disco": [cx, cy, r], "d": vetoriza(m)}) + "\n")
    print(OUT / f"{nome}.json", "disco", cx, cy, r)


if __name__ == "__main__":
    main()
