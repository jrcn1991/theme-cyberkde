#!/usr/bin/env python3
"""Gera a animação do README (assets/readme/cyberkde.gif) a partir das capturas reais do tema.

    scripts/capturas-loja.sh          # capturas no KWin virtual (inclui assets/loja/vazio.png)
    python3 scripts/animacao-readme.py

Cada quadro é desenhado com Pillow/numpy sobre as telas reais; o ffmpeg monta o GIF em loop, sem
áudio. Os movimentos imitam os do tema: janelas abrindo com a varredura do cyberkde_scan (mira,
linha de varredura, estabilização), a cascata do Dolphin compilado, o texto novo do Konsole com
tinta ciano, o menu revelado a partir da dock e a troca da cor de destaque ("cyberkde cor").
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "assets" / "loja"
OUT = ROOT / "assets" / "readme" / "cyberkde.gif"
sys.path.insert(0, str(ROOT / "generator"))
from cyberlib import CYAN, TOK  # noqa: E402

S = 0.5                     # 1920x1080 → 960x540
W, H = int(1920 * S), int(1080 * S)
FPS = 20
DUR = 9.3
RED = TOK["reference"]["red"]
GREEN_HUE = 107             # #1DED83 na escala 0-255 do modo HSV do Pillow
BG_VIEW = (18, 18, 28)      # fundo das vistas do Dolphin e do Konsole nas capturas
PANEL_Y = int(1036 * S)


def rgb(hexa):
    hexa = hexa.lstrip("#")
    return tuple(int(hexa[i:i + 2], 16) for i in (0, 2, 4))


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def prog(t, t0, t1):
    return clamp((t - t0) / (t1 - t0))


def ease(p):
    return 1 - (1 - p) ** 3


def scaled(img, f):
    return img.resize((round(img.width * f), round(img.height * f)), Image.LANCZOS)


def font(name, size):
    return ImageFont.truetype(str(name), round(size))


# ---------------------------------------------------------------- material
vazio = scaled(Image.open(SHOTS / "vazio.png").convert("RGB"), S)
menu_full = Image.open(SHOTS / "menu.png").convert("RGB")
MENU_BOX = (480, 444, 1223, 1004)   # menu da dock, centralizado acima dela
menu = scaled(menu_full.crop(MENU_BOX), S)
MENU_XY = (round(MENU_BOX[0] * S), round(MENU_BOX[1] * S))

WIN_F = 0.82 * S
dolphin_src = Image.open(SHOTS / "dolphin.png").convert("RGB")
konsole_src = Image.open(SHOTS / "konsole.png").convert("RGB")


def bands(img, x0, x1, y0, y1, thr=40, gap=12, min_h=8):
    """Faixas horizontais com conteúdo (linhas de ícones, linhas de texto) sobre o fundo da vista."""
    a = np.asarray(img).astype(int)[y0:y1, x0:x1]
    rows = (np.abs(a - np.array(BG_VIEW)).sum(axis=2) > thr).any(axis=1)
    out, start, last = [], None, None
    for i, v in enumerate(rows):
        if v:
            if start is None:
                start = i
            elif i - last > gap:
                out.append((start + y0, last + 1 + y0))
                start = i
            last = i
    if start is not None:
        out.append((start + y0, last + 1 + y0))
    return [b for b in out if b[1] - b[0] >= min_h]


DOLPHIN_ROWS = [b for b in bands(dolphin_src, 140, 1250, 85, 705, gap=14)]
KONSOLE_LINES = [b for b in bands(konsole_src, 20, 1200, 75, 740, gap=2)]
DOLPHIN_VIEW_X = 140


def window_layer(src, t, rows=None, row_t0=0.0, row_x0=0, typed=None):
    """Janela com a cascata (Dolphin) ou a digitação (Konsole) no instante t (segundos)."""
    img = src.copy()
    draw = ImageDraw.Draw(img)
    if rows is not None:
        for i, (y0, y1) in enumerate(rows):
            p = ease(prog(t, row_t0 + i * 0.16, row_t0 + i * 0.16 + 0.28))
            if p >= 1:
                continue
            band = src.crop((row_x0, y0, src.width - 12, y1))
            draw.rectangle((row_x0, y0 - 14, src.width - 12, y1 + 14), fill=BG_VIEW)
            if p > 0:
                a = Image.new("L", band.size, round(255 * p))
                img.paste(band, (row_x0, y0 + round(12 * (1 - p))), a)
    if typed is not None:
        lines, t0 = typed
        for i, (y0, y1) in enumerate(lines):
            p = prog(t, t0 + i * 0.13, t0 + i * 0.13 + 0.22)
            x_rev = round(6 + (src.width - 26) * p)
            draw.rectangle((x_rev, y0, src.width - 14, y1), fill=BG_VIEW)
            # tinta ciano no texto que acabou de aparecer
            tint = 1 - prog(t, t0 + i * 0.13 + 0.10, t0 + i * 0.13 + 0.45)
            if p > 0 and tint > 0:
                reg = img.crop((6, y0, x_rev, y1))
                cy = Image.new("RGB", reg.size, rgb(CYAN))
                mask = reg.convert("L").point(lambda v: 255 if v > 60 else 0)
                reg = Image.composite(Image.blend(reg, cy, 0.55 * tint), reg, mask)
                img.paste(reg, (6, y0))
    return scaled(img, WIN_F)


def shadow(size, radius=10, alpha=110):
    w, h = size
    pad = radius * 3
    s = Image.new("L", (w + pad * 2, h + pad * 2), 0)
    ImageDraw.Draw(s).rectangle((pad, pad + 6, pad + w, pad + h + 6), fill=alpha)
    return s.filter(ImageFilter.GaussianBlur(radius)), pad


def brackets(draw, box, grow, alpha, color=RED, length=18, width=2):
    x0, y0, x1, y1 = box
    x0 -= grow; y0 -= grow; x1 += grow; y1 += grow
    c = rgb(color) + (round(255 * alpha),)
    for (cx, cy, dx, dy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        draw.line((cx, cy, cx + dx * length, cy), fill=c, width=width)
        draw.line((cx, cy, cx, cy + dy * length), fill=c, width=width)


def put_window(frame, win, xy, t_open, t, t_close=None):
    """Abre (e fecha) a janela com a varredura do cyberkde_scan."""
    if t < t_open:
        return
    p = prog(t, t_open, t_open + 0.7)
    closing = t_close is not None and t >= t_close
    if closing:
        p = 1 - prog(t, t_close, t_close + 0.45)
        if p <= 0:
            return
    x, y = xy
    w, h = win.size
    box = (x, y, x + w, y + h)
    over = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    # mira: cantos que fecham sobre a região de destino
    pb = ease(prog(p, 0.0, 0.25))
    if p < 0.95:
        brackets(od, box, round(16 * (1 - pb)), pb * (1 - prog(p, 0.8, 0.95)))
    # varredura: revela de cima para baixo, com linha ciano e um rastro
    r = ease(prog(p, 0.15, 0.8))
    cut = round(h * r)
    if cut > 0:
        sh, pad = shadow((w, cut))
        frame.paste((6, 6, 12), (x - pad, y - pad), sh)
        part = win.crop((0, 0, w, cut))
        settle = 1 - prog(p, 0.8, 1.0)
        if settle > 0 and r >= 1:
            part = Image.blend(part, Image.new("RGB", part.size, rgb(CYAN)), 0.10 * settle)
        frame.paste(part, (x, y))
        if r < 1:
            for i, a in enumerate((70, 40, 18)):
                od.rectangle((x, y + cut - 4 - i * 4, x + w, y + cut - i * 4), fill=rgb(CYAN) + (a,))
            od.rectangle((x - 3, y + cut - 1, x + w + 3, y + cut + 1), fill=rgb(CYAN) + (255,))
    frame.paste(over, (0, 0), over)


def put_menu(frame, t_open, t, t_close):
    if t < t_open or t >= t_close + 0.25:
        return
    p = ease(prog(t, t_open, t_open + 0.32)) if t < t_close else 1 - prog(t, t_close, t_close + 0.25)
    w, h = menu.size
    vis = round(h * (0.35 + 0.65 * p))
    part = menu.crop((0, h - vis, w, h))
    a = Image.new("L", part.size, round(255 * clamp(p * 1.4)))
    frame.paste(part, (MENU_XY[0], MENU_XY[1] + h - vis), a)


def title(frame, t, t0, t1):
    if not (t0 <= t < t1):
        return
    pin = prog(t, t0, t0 + 0.25)
    pout = prog(t, t1 - 0.25, t1)
    alpha = ease(pin) * (1 - pout)
    lay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cy = H // 2 - round(20 * S) - round(40 * pout)
    d.rectangle((0, cy - round(120 * S), W, cy + round(110 * S)), fill=(10, 10, 18, round(170 * alpha)))
    big = font(ROOT / "assets/fonts/Rajdhani-Bold.ttf", 190 * S)
    small = font(ROOT / "assets/fonts/Rajdhani-Medium.ttf", 44 * S)
    txt, sub = "CYBERKDE", "NEO-MILITARY THEME FOR KDE PLASMA 6"
    tw = d.textlength(txt, font=big)
    sw = d.textlength(sub, font=small)
    tx, ty = (W - tw) / 2, cy - round(115 * S)
    glitch = t - t0 < 0.3 and int((t - t0) * FPS) % 2 == 0
    if glitch:  # acento breve: fantasmas vermelho/ciano deslocados
        d.text((tx - 6, ty), txt, font=big, fill=rgb(CYAN) + (round(200 * alpha),))
        d.text((tx + 6, ty), txt, font=big, fill=rgb(RED) + (round(200 * alpha),))
    d.text((tx, ty), txt, font=big, fill=rgb(RED) + (round(255 * alpha),))
    d.rectangle(((W - sw) / 2 - 22, cy + round(62 * S), (W - sw) / 2 - 16, cy + round(98 * S)),
                fill=rgb(RED) + (round(255 * alpha),))
    d.text(((W - sw) / 2, cy + round(55 * S)), sub, font=small, fill=(220, 220, 228, round(255 * alpha)))
    frame.paste(lay, (0, 0), lay)


def caption(frame, t, text, t0, t1):
    if not (t0 <= t < t1):
        return
    alpha = ease(prog(t, t0, t0 + 0.2)) * (1 - prog(t, t1 - 0.2, t1))
    n = round(len(text) * prog(t, t0 + 0.1, t0 + 0.1 + 0.035 * len(text)))
    f = font("/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf", 30 * S)
    lay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    full_w = d.textlength("$ " + text, font=f)
    x0, y1 = W - round(40 * S) - full_w - 28, PANEL_Y - round(26 * S)
    y0 = y1 - round(64 * S)
    c = round(10 * S)
    d.polygon([(x0, y0), (W - round(40 * S), y0), (W - round(40 * S), y1 - c), (W - round(40 * S) - c, y1),
               (x0, y1)], fill=(12, 12, 20, round(225 * alpha)), outline=rgb(RED) + (round(255 * alpha),))
    d.rectangle((x0, y0, x0 + 3, y1), fill=rgb(RED) + (round(255 * alpha),))
    d.text((x0 + 16, y0 + round(14 * S)), "$ ", font=f, fill=rgb(RED) + (round(255 * alpha),))
    d.text((x0 + 16 + d.textlength("$ ", font=f), y0 + round(14 * S)), text[:n], font=f,
           fill=(220, 220, 228, round(255 * alpha)))
    if int(t * 3) % 2 == 0:
        cx = x0 + 16 + d.textlength("$ " + text[:n], font=f) + 2
        d.rectangle((cx, y0 + round(16 * S), cx + round(14 * S), y1 - round(16 * S)), fill=rgb(CYAN) + (round(255 * alpha),))
    frame.paste(lay, (0, 0), lay)


def recolor(frame, frac, reverse=False):
    """Troca o vermelho pelo verde à esquerda da linha de varredura (ou à direita, na volta)."""
    if frac <= 0:
        return frame
    hsv = np.asarray(frame.convert("HSV")).copy()
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1], hsv[..., 2]
    red = ((h < 14) | (h > 240)) & (s > 90) & (v > 60)
    xs = np.arange(frame.width)[None, :]
    edge = round(frame.width * frac)
    zone = xs < edge if not reverse else xs >= frame.width - edge
    sel = red & zone
    hsv[..., 0][sel] = GREEN_HUE
    out = Image.fromarray(hsv, "HSV").convert("RGB")
    if 0 < frac < 1:
        x = edge if not reverse else frame.width - edge
        d = ImageDraw.Draw(out)
        d.rectangle((x - 1, 0, x + 1, frame.height), fill=rgb(CYAN))
    return out


# ---------------------------------------------------------------- linha do tempo (segundos)
T_DOLPHIN, T_KONSOLE, T_MENU = 1.6, 3.0, 5.1
T_CLOSE = 8.0
dolphin_xy = (round(640 * S), round(215 * S))
konsole_xy = (round(110 * S), round(95 * S))


def render(t):
    f = vazio.copy()
    title(f, t, 0.25, 1.6)
    put_window(f, window_layer(dolphin_src, t, rows=DOLPHIN_ROWS, row_t0=T_DOLPHIN + 0.55,
                               row_x0=DOLPHIN_VIEW_X), dolphin_xy, T_DOLPHIN, t, T_CLOSE + 0.15)
    put_window(f, window_layer(konsole_src, t, typed=(KONSOLE_LINES, T_KONSOLE + 0.6)),
               konsole_xy, T_KONSOLE, t, T_CLOSE)
    put_menu(f, T_MENU, t, T_CLOSE - 0.1)
    caption(f, t, "cyberkde on", 1.5, 6.1)
    caption(f, t, "cyberkde cor '#1DED83'", 6.2, 8.2)
    if t < 8.3:
        f = recolor(f, ease(prog(t, 6.3, 7.2)))
    else:  # volta ao vermelho, da direita para a esquerda: o último quadro é igual ao primeiro
        f = recolor(f, 1 - ease(prog(t, 8.3, 8.9)))
    return f


def main():
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cyberkde-anim-"))
    try:
        n = round(DUR * FPS)
        for i in range(n):
            render(i / FPS).save(tmp / f"f{i:04d}.png")
        OUT.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", str(tmp / "f%04d.png"),
                        "-vf", "split[a][b];[a]palettegen=stats_mode=diff:max_colors=160[p];"
                               "[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle",
                        "-loop", "0", str(OUT)], check=True)
        # quadros de conferência
        for t in (0.9, 2.6, 4.6, 5.8, 6.8, 7.6):
            render(t).save(tmp.parent / f"cyberkde-anim-{t:.1f}.png")
        print(f"{OUT} ({OUT.stat().st_size / 1e6:.1f} MB, {n} quadros)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
