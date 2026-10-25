#!/usr/bin/env python3
"""Papéis de parede por corporação (3840x2160): área de trabalho, bloqueio e login na identidade de cada uma.

Composição programática e reproduzível (semente fixa por corporação), a partir de
  - a paleta da corporação (tokens/corporacoes.json: destaque, secundária, alerta, fundo);
  - o logo vetorial (assets/corporacoes/<id>-logo[-escuro].svg) e o símbolo (<id>.svg);
  - um motivo geométrico próprio (Arasaka austero, Militech com divisas, Biotechnica orgânico, NetWatch
    com rede e globo, Trauma Team com ECG, Kang Tao com circuito, Zetatech com raio em Z, Delamain com
    pistas, Dynalar com impressão digital, Kiroshi com íris, Night Corp art déco, Petrochem com
    tubulação, Segotari com grade retrô).
Sem texto além do logo. O centro fica calmo (ícones, relógio e painel de login).

Uso: gen_corp.py <id|todas> [--saida DIR] [--previas DIR] [--prancha ARQ]
  --saida    onde gravar {desktop,lockscreen,login}.png (padrão: modules/papeis-de-parede/build/corp/<id>)
  --previas  também grava <DIR>/corp-<id>.webp (480x270, a área de trabalho)
  --prancha  grava uma prancha com a área de trabalho de todas as corporações geradas
Precisa de Pillow e Inkscape. Um id sem motivo próprio sai com o motivo genérico.
"""
import argparse
import json
import math
import pathlib
import random
import re
import subprocess
import sys
import tempfile
import zlib

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
sys.path.insert(0, str(ROOT / "generator"))
from cyberlib import ALERTA, CYAN, RED, TOK, hexc, mix, rgb  # noqa: E402

W, H = 3840, 2160
CX, CY = W / 2, H / 2


# ---------------------------------------------------------------- paleta
def paleta(id_):
    """destaque, secundária, alerta, fundo da corporação; sem corporação, a paleta atual do tema."""
    try:
        dados = json.loads((ROOT / "tokens" / "corporacoes.json").read_text())["corporacoes"]
    except (OSError, ValueError, KeyError):
        dados = []
    c = next((x for x in dados if x.get("id") == id_), None)
    if c and c.get("destaque"):
        return dict(id=id_, nome=c.get("nome", id_), d=c["destaque"], s=c["secundaria"], a=c["alerta"], f=c["fundo"])
    return dict(id=id_, nome=id_, d=RED, s=CYAN, a=ALERTA, f=TOK["reference"]["darkestBlue"])


def ids_corporacoes():
    dados = json.loads((ROOT / "tokens" / "corporacoes.json").read_text())["corporacoes"]
    return [c["id"] for c in dados if c.get("logo") and (ROOT / "assets" / "corporacoes" / f"{c['id']}-logo.svg").is_file()]


# ---------------------------------------------------------------- SVG
class Cena:
    def __init__(self, pal, rnd):
        self.p, self.r, self.o, self.defs = pal, rnd, [], []

    def add(self, s):
        self.o.append(s)

    def linha(self, x1, y1, x2, y2, cor, w=3, op=1.0, extra=""):
        self.add(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{cor}" stroke-width="{w}" opacity="{op}" {extra}/>')

    def poli(self, pts, fill="none", stroke="none", w=3, op=1.0, extra=""):
        d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.add(f'<polygon points="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{op}" stroke-linejoin="miter" {extra}/>')

    def trilha(self, pts, cor, w=3, op=1.0, extra=""):
        d = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.add(f'<polyline points="{d}" fill="none" stroke="{cor}" stroke-width="{w}" opacity="{op}" stroke-linejoin="miter" {extra}/>')

    def circ(self, x, y, r, fill="none", stroke="none", w=3, op=1.0, extra=""):
        self.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{op}" {extra}/>')

    def elip(self, x, y, rx, ry, fill="none", stroke="none", w=3, op=1.0, extra=""):
        self.add(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{op}" {extra}/>')

    def ret(self, x, y, w, h, fill="none", stroke="none", sw=3, op=1.0, extra=""):
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" {extra}/>')

    def path(self, d, fill="none", stroke="none", w=3, op=1.0, extra=""):
        self.add(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{op}" {extra}/>')


def chanfro(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def hexagono(cx, cy, r, rot=0):
    return [(cx + r * math.cos(math.radians(60 * k + rot)), cy + r * math.sin(math.radians(60 * k + rot))) for k in range(6)]


# ---------------------------------------------------------------- motivos (um por corporação)
def m_arasaka(s, p):
    d, c2 = p["d"], p["s"]
    cx, cy = 2900, 1080
    for r, w, op in ((250, 4, .5), (300, 3, .3), (520, 2, .25), (560, 2, .16), (900, 2, .13), (1300, 2, .1), (1800, 2, .07)):
        s.circ(cx, cy, r, stroke=d, w=w, op=op)
    for dx, dy, r in ((0, -150, 85), (-140, 70, 85), (140, 70, 85)):  # as três esferas do brasão, só em filete
        s.circ(cx + dx, cy + dy, r, stroke=d, w=3, op=.35)
    s.linha(cx, cy - 60, cx, cy + 190, d, 3, .35)
    for x in range(0, W, 120):  # fios verticais, como as treliças de um shoji
        s.linha(x, 0, x, H, c2, 2, .045)
    s.linha(96, 1720, W - 96, 1720, c2, 2, .22)
    for x in range(480, W, 480):
        s.ret(x - 8, 1712, 16, 16, fill=d, op=.8)
    s.ret(96, 1180, 12, 540, fill=d, op=.9)
    s.ret(96, 340, 12, 160, fill=d, op=.5)


def m_militech(s, p):
    d, c2 = p["d"], p["s"]
    for col in range(7):  # divisas grandes apontando à direita
        for row in range(3):
            x, y = 2050 + col * 230, 330 + row * 560
            s.trilha([(x, y), (x + 150, y + 215), (x, y + 430)], d, 22, max(.03, .22 - col * .028))
    for gx in range(120, W, 120):
        for gy in range(120, H, 120):
            s.circ(gx, gy, 2.5, fill=c2, op=.12)
    for (x, y, w, h) in ((96, 150, 900, 40), (W - 996, H - 190, 900, 40)):  # faixas de aviso listradas
        clip = f"hz{int(x)}"
        s.defs.append(f'<clipPath id="{clip}"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath>')
        s.add(f'<g clip-path="url(#{clip})">' + "".join(
            f'<line x1="{x + i * 56}" y1="{y + h + 8}" x2="{x + i * 56 + h + 16}" y2="{y - 8}" stroke="{d}" stroke-width="22" opacity=".75"/>'
            for i in range(-2, int(w / 56) + 3)) + "</g>")
    rx, ry = 2900, 1020  # retículo
    s.circ(rx, ry, 430, stroke=d, w=4, op=.3)
    s.circ(rx, ry, 250, stroke=d, w=3, op=.35, extra='stroke-dasharray="28 16"')
    for k in range(72):
        a = math.radians(k * 5)
        l = 36 if k % 6 == 0 else 16
        s.linha(rx + math.cos(a) * 430, ry + math.sin(a) * 430, rx + math.cos(a) * (430 - l), ry + math.sin(a) * (430 - l), d, 3, .5)
    s.linha(rx - 560, ry, rx - 120, ry, d, 3, .4)
    s.linha(rx + 120, ry, rx + 560, ry, d, 3, .4)
    s.linha(rx, ry - 560, rx, ry - 120, d, 3, .4)
    s.linha(rx, ry + 120, rx, ry + 560, d, 3, .4)
    for i, w in enumerate((420, 300, 360, 220, 480)):
        s.ret(W - 96 - w, 360 + i * 34, w, 14, fill=d, op=.14)


def m_biotechnica(s, p):
    d, c2, r = p["d"], p["s"], s.r
    hr = 78
    for row in range(-1, int(H / (hr * 1.5)) + 2):
        for col in range(-1, int(W / (hr * 1.732)) + 2):
            x = col * hr * 1.732 + (hr * .866 if row % 2 else 0)
            y = row * hr * 1.5
            fade = max(0.0, (x - 1700) / 2140)
            if fade <= 0.02:
                continue
            s.poli(hexagono(x, y, hr - 3, 30), stroke=d, w=2, op=.28 * fade)
            if r.random() < .09:
                s.poli(hexagono(x, y, hr - 3, 30), fill=d, op=.10 * fade)

    def ramo(x, y, ang, comp, prof, larg):
        if prof == 0 or comp < 30:
            s.elip(x, y, 26, 10, fill=d, op=.20, extra=f'transform="rotate({math.degrees(ang):.0f} {x:.1f} {y:.1f})"')
            return
        ang2 = ang + r.uniform(-.35, .35)
        x2, y2 = x + math.cos(ang2) * comp, y + math.sin(ang2) * comp
        mx, my = (x + x2) / 2 + math.cos(ang + 1.57) * comp * .15, (y + y2) / 2 + math.sin(ang + 1.57) * comp * .15
        s.path(f"M{x:.1f},{y:.1f} Q{mx:.1f},{my:.1f} {x2:.1f},{y2:.1f}", stroke=d, w=larg, op=.34, extra='stroke-linecap="round"')
        for da in (-.55, .5):
            ramo(x2, y2, ang2 + da + r.uniform(-.15, .15), comp * r.uniform(.68, .8), prof - 1, max(1.5, larg * .72))
    ramo(40, H - 60, -.9, 360, 7, 9)
    ramo(300, H + 20, -1.15, 300, 6, 7)
    ramo(W - 40, 60, 2.35, 260, 6, 6)
    for _ in range(18):
        s.circ(r.uniform(0, W), r.uniform(0, H), r.uniform(30, 120), fill=c2, op=r.uniform(.015, .05), extra='filter="url(#desf)"')


def m_netwatch(s, p):
    d, c2, r = p["d"], p["s"], s.r
    gx, gy, R = 2950, 1080, 820
    s.circ(gx, gy, R, stroke=d, w=4, op=.4)
    for k in range(0, 180, 20):
        s.elip(gx, gy, R * abs(math.cos(math.radians(k))), R, stroke=d, w=2, op=.22)
    for lat in range(-70, 80, 20):
        a = math.radians(lat)
        s.elip(gx, gy + R * math.sin(a), R * math.cos(a), R * math.cos(a) * .13, stroke=d, w=2, op=.22)
    for rr, dash in ((960, "50 30"), (1060, "6 20"), (1180, "120 40 30 40")):
        s.circ(gx, gy, rr, stroke=c2, w=2, op=.16, extra=f'stroke-dasharray="{dash}"')
    s.defs.append(f'<radialGradient id="sweep" cx="{gx}" cy="{gy}" r="1000" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="{d}" stop-opacity=".0"/><stop offset="1" stop-color="{d}" stop-opacity=".32"/></radialGradient>')
    a0, a1 = math.radians(-35), math.radians(-5)
    s.path(f"M{gx},{gy} L{gx + 1000 * math.cos(a0):.1f},{gy + 1000 * math.sin(a0):.1f} A1000,1000 0 0 1 {gx + 1000 * math.cos(a1):.1f},{gy + 1000 * math.sin(a1):.1f} Z", fill="url(#sweep)")
    pts = [(r.uniform(160, 2200), r.uniform(200, 1960)) for _ in range(70)]
    for i, (x, y) in enumerate(pts):
        for (x2, y2) in pts[i + 1:]:
            if math.hypot(x - x2, y - y2) < 400:
                s.linha(x, y, x2, y2, d, 2, .2)
    for (x, y) in pts:
        s.circ(x, y, 6, fill=c2, op=.7)
        if r.random() < .12:
            s.circ(x, y, 22, stroke=c2, w=2, op=.5)
    for y in range(0, H, 10):
        s.linha(0, y, W, y, "#000000", 2, .06)


def m_traumateam(s, p):
    d, c2, a = p["d"], p["s"], p["a"]
    for x in range(110, W, 220):
        for y in range(110, H, 220):
            s.linha(x - 16, y, x + 16, y, d, 3, .12)
            s.linha(x, y - 16, x, y + 16, d, 3, .12)
    pts, x = [(0, 1660)], 0
    while x < W:
        pts += [(x + 160, 1660), (x + 200, 1580), (x + 260, 1830), (x + 330, 1480), (x + 390, 1660)]
        x += 760
    for ex, op in ((' filter="url(#desf)"', .7), ("", .85)):
        s.trilha(pts, d, 7, op, extra=ex.strip())
    s.circ(2950, 920, 560, stroke=d, w=4, op=.28)
    s.circ(2950, 920, 440, stroke=d, w=2, op=.2, extra='stroke-dasharray="14 18"')
    b = 150
    s.poli([(2950 - b / 2, 920 - 3 * b / 2), (2950 + b / 2, 920 - 3 * b / 2), (2950 + b / 2, 920 - b / 2), (2950 + 3 * b / 2, 920 - b / 2), (2950 + 3 * b / 2, 920 + b / 2),
            (2950 + b / 2, 920 + b / 2), (2950 + b / 2, 920 + 3 * b / 2), (2950 - b / 2, 920 + 3 * b / 2), (2950 - b / 2, 920 + b / 2), (2950 - 3 * b / 2, 920 + b / 2),
            (2950 - 3 * b / 2, 920 - b / 2), (2950 - b / 2, 920 - b / 2)], fill=d, op=.08)
    s.defs.append('<clipPath id="tt"><polygon points="2500,90 3744,90 3744,330 2380,330"/></clipPath>')
    s.add('<g clip-path="url(#tt)">' + "".join(f'<line x1="{2300 + i * 50}" y1="340" x2="{2380 + i * 50}" y2="80" stroke="{a}" stroke-width="18" opacity=".55"/>' for i in range(34)) + "</g>")


def m_kangtao(s, p):
    d, c2, r = p["d"], p["s"], s.r
    G = 60
    dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    for _ in range(34):
        x, y = r.randrange(0, W // G) * G, r.randrange(0, H // G) * G
        di = r.randrange(8)
        pts = [(x, y)]
        for _k in range(r.randrange(5, 12)):
            di = (di + r.choice((-1, 0, 0, 1))) % 8
            n = r.randrange(2, 7) * G
            dx, dy = dirs[di]
            n2 = n * (0.7071 if dx and dy else 1)
            x, y = x + dx * n2, y + dy * n2
            pts.append((x, y))
        s.trilha(pts, d, 3, r.uniform(.12, .3))
        s.circ(*pts[0], 9, stroke=d, w=3, op=.5)
        s.circ(*pts[-1], 14, fill=d, op=.35)
    for (x, y, w, h) in ((2650, 300, 700, 420), (2900, 1250, 760, 460), (2100, 1540, 520, 300)):  # lajes inclinadas, como o bloco do logo
        s.poli([(x + 60, y), (x + w, y), (x + w - 60, y + h), (x, y + h)], fill=d, op=.07)
        s.poli([(x + 60, y), (x + w, y), (x + w - 60, y + h), (x, y + h)], stroke=d, w=3, op=.3)
    for i in range(10):
        s.ret(160 + i * 46, 1860, 30, 30, stroke=c2, sw=2, op=.28)


def m_zetatech(s, p):
    d, c2, r = p["d"], p["s"], s.r
    bolt = [(-760, -380), (700, -460), (80, -60), (780, -90), (-800, 460), (-120, 40)]
    ox, oy = 2800, 1070
    s.poli([(ox + x, oy + y) for x, y in bolt], stroke=d, w=5, op=.3)
    s.poli([(ox + x * .8, oy + y * .8) for x, y in bolt], stroke=c2, w=2, op=.2)
    s.poli([(ox + x, oy + y) for x, y in bolt], fill=d, op=.05)
    for _ in range(26):
        x, y = r.uniform(-300, 3200), r.uniform(100, 2000)
        l = r.uniform(300, 1200)
        s.linha(x, y, x + l, y - l * .2, d if r.random() < .6 else c2, r.choice((3, 5, 9)), r.uniform(.06, .22))
    px, py, n = 190, 1470, 380
    for k, w in ((0, 4), (60, 3), (120, 2)):
        s.ret(px + k, py + k, n - 2 * k, n - 2 * k, stroke=d, sw=w, op=.4)
    for i in range(12):
        t = px + 30 + i * 28
        for (x1, y1, x2, y2) in ((t, py - 44, t, py), (t, py + n, t, py + n + 44), (px - 44, py + 30 + i * 28, px, py + 30 + i * 28), (px + n, py + 30 + i * 28, px + n + 44, py + 30 + i * 28)):
            s.linha(x1, y1, x2, y2, c2, 3, .35)


def m_delamain(s, p):
    d, c2, r = p["d"], p["s"], s.r
    vx, vy = 1920, 940
    for i in range(-14, 15):
        s.linha(vx + i * 60, vy, vx + i * 520, H, d, 3, .2)
    for k in range(1, 15):
        y = vy + (H - vy) * (k / 14) ** 2.1
        s.linha(0, y, W, y, d, 2, .1 + .08 * k / 14)
    s.linha(vx, vy, vx, H, c2, 8, .5, extra='stroke-dasharray="70 70"')
    rota = [(330, 1760), (900, 1500), (1250, 1500), (1500, 1250), (2250, 1250), (2650, 1000), (3350, 1000)]
    for ex, op, w in ((' filter="url(#desf)"', .6, 14), ("", .75, 6)):
        s.trilha(rota, c2, w, op, extra=ex.strip())
    for (x, y) in rota:
        s.circ(x, y, 16, fill=p["f"], stroke=c2, w=5)
    for k, c in enumerate((620, 500, 380)):  # o D do logo, em filete chanfrado
        x0, y0 = 2750 - c, 330 - c * .1
        s.poli([(x0, y0), (x0 + c * 1.5, y0), (x0 + c * 1.9, y0 + c * .4), (x0 + c * 1.9, y0 + c * 1.5), (x0 + c * 1.5, y0 + c * 1.9), (x0, y0 + c * 1.9)], stroke=d, w=3, op=.24 - k * .05)
    for _ in range(90):
        s.circ(r.uniform(0, W), r.uniform(0, vy), r.choice((2, 3, 4)), fill=c2, op=r.uniform(.15, .5))


def m_dynalar(s, p):
    d, c2, r = p["d"], p["s"], s.r
    fx, fy = 2900, 1100
    for k in range(1, 30):
        rx, ry = 50 + k * 38, 70 + k * 52
        s.elip(fx, fy, rx, ry, stroke=d, w=3, op=.22 if k % 5 else .38, extra=f'stroke-dasharray="{r.randrange(180, 900)} {r.randrange(30, 140)}" transform="rotate(-14 {fx} {fy})"')
    for i in range(11):  # atuador segmentado
        w = 520 - i * 24
        s.ret(150, 300 + i * 118, w, 78, stroke=d, sw=3, op=.22, extra='rx="10"')
        s.ret(150 + 18, 300 + i * 118 + 18, w * (0.35 + 0.5 * ((i * 37) % 10) / 10), 42, fill=d, op=.10)
    for row in range(5):
        for col in range(14):
            x = 160 + col * 118 + (59 if row % 2 else 0)
            s.poli(hexagono(x, 1550 + row * 102, 44, 0), stroke=c2, w=2, op=.16)
            if r.random() < .15:
                s.poli(hexagono(x, 1550 + row * 102, 44, 0), fill=d, op=.18)


def m_kiroshi(s, p):
    d, c2, r = p["d"], p["s"], s.r
    ix, iy = 2900, 1080
    aneis = ((130, None, 0, d, .5, 5), (230, "34 18", 0, d, .4, 4), (330, None, 0, c2, .22, 2), (420, "260 70 40 70", 0, d, .38, 6),
             (520, "6 16", 0, c2, .3, 4), (640, "420 90", 0, d, .3, 3), (760, None, 0, d, .18, 2), (900, "50 30", 0, c2, .2, 3))
    for rr, dash, _, c, op, w in aneis:
        s.circ(ix, iy, rr, stroke=c, w=w, op=op, extra=f'stroke-dasharray="{dash}"' if dash else "")
    s.circ(ix, iy, 120, fill=d, op=.16)
    s.circ(ix, iy, 46, fill=d, op=.5)
    for k in range(120):
        a = math.radians(k * 3)
        l = 40 if k % 5 == 0 else 18
        s.linha(ix + math.cos(a) * 780, iy + math.sin(a) * 780, ix + math.cos(a) * (780 + l), iy + math.sin(a) * (780 + l), d, 3, .35)
    for a in (0, 90, 180, 270):
        a = math.radians(a)
        s.linha(ix + math.cos(a) * 200, iy + math.sin(a) * 200, ix + math.cos(a) * 1000, iy + math.sin(a) * 1000, d, 3, .3)
    for (ox, oy, rx, ry) in ((-420, -260, 180, 60), (360, 300, 120, 40), (-200, 400, 90, 30)):
        s.elip(ix + ox, iy + oy, rx, ry, fill=d, op=.10, extra='filter="url(#desf)"')


def m_nightcorp(s, p):
    d, c2 = p["d"], p["s"]
    ox, oy, n = 1920, H + 60, 44
    for k in range(n):
        a0, a1 = math.pi + k * math.pi / n, math.pi + (k + .5) * math.pi / n
        s.poli([(ox, oy), (ox + 3000 * math.cos(a0), oy + 3000 * math.sin(a0)), (ox + 3000 * math.cos(a1), oy + 3000 * math.sin(a1))], fill=d, op=.045)
    for k, rr in enumerate(range(260, 2000, 170)):
        s.path(f"M{ox - rr},{oy} A{rr},{rr} 0 0 1 {ox + rr},{oy}", stroke=d, w=3 if k % 2 else 5, op=.16 if k % 2 else .26)
    for side in (0, 1):  # caneluras nas laterais
        for i in range(8):
            x = 70 + i * 36 if not side else W - 70 - i * 36
            s.linha(x, 140, x, H - 140, d, 2, .22 - i * .02)
    for sx, sy in ((1, 1), (-1, 1)):  # degraus art déco nos cantos de cima
        bx = 0 if sx == 1 else W
        for k in range(5):
            m = 130 + k * 70
            s.trilha([(bx + sx * m, 0), (bx + sx * m, m * .5), (bx + sx * (m - 70), m * .5 + 40)], d, 3, .3 - k * .04)


def m_petrochem(s, p):
    d, c2, r = p["d"], p["s"], s.r
    def tubo(x1, y1, x2, y2, larg=70):
        horiz = abs(y2 - y1) < abs(x2 - x1)
        if horiz:
            s.ret(x1, y1 - larg / 2, x2 - x1, larg, fill=d, op=.05)
            s.linha(x1, y1 - larg / 2, x2, y1 - larg / 2, d, 3, .35)
            s.linha(x1, y1 + larg / 2, x2, y1 + larg / 2, d, 3, .35)
            for x in range(int(x1) + 240, int(x2), 480):
                s.ret(x - 14, y1 - larg / 2 - 16, 28, larg + 32, fill=d, op=.2)
        else:
            s.ret(x1 - larg / 2, y1, larg, y2 - y1, fill=d, op=.05)
            s.linha(x1 - larg / 2, y1, x1 - larg / 2, y2, d, 3, .35)
            s.linha(x1 + larg / 2, y1, x1 + larg / 2, y2, d, 3, .35)
            for y in range(int(y1) + 200, int(y2), 400):
                s.ret(x1 - larg / 2 - 16, y - 14, larg + 32, 28, fill=d, op=.2)
    tubo(0, 1640, 3840, 1640)
    tubo(0, 1790, 2600, 1790, 50)
    tubo(520, 0, 520, 1640)
    tubo(3300, 280, 3300, 1640)
    tubo(2300, 280, 3300, 280, 50)
    gx, gy, gr = 3020, 640, 190
    s.circ(gx, gy, gr, stroke=d, w=5, op=.45)
    s.circ(gx, gy, gr - 26, stroke=c2, w=2, op=.3)
    for k in range(41):
        a = math.radians(135 + k * 6.75)
        l = 26 if k % 5 == 0 else 12
        s.linha(gx + math.cos(a) * (gr - 26), gy + math.sin(a) * (gr - 26), gx + math.cos(a) * (gr - 26 - l), gy + math.sin(a) * (gr - 26 - l), c2, 3, .5)
    a = math.radians(135 + 29 * 6.75)
    s.linha(gx, gy, gx + math.cos(a) * 130, gy + math.sin(a) * 130, p["a"], 6, .8)
    s.defs.append('<clipPath id="pz"><rect x="96" y="120" width="1000" height="40"/></clipPath>')
    s.add('<g clip-path="url(#pz)">' + "".join(f'<line x1="{96 + i * 60}" y1="168" x2="{96 + i * 60 + 56}" y2="112" stroke="{c2}" stroke-width="24" opacity=".6"/>' for i in range(-1, 19)) + "</g>")


def m_segotari(s, p):
    d, c2, r = p["d"], p["s"], s.r
    vx, vy = 2500, 1260
    s.defs.append(f'<linearGradient id="sol" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c2}" stop-opacity=".85"/><stop offset="1" stop-color="{d}" stop-opacity=".85"/></linearGradient>')
    s.defs.append(f'<clipPath id="solc"><rect x="{vx - 600}" y="{vy - 600}" width="1200" height="600"/></clipPath>')
    s.add('<g clip-path="url(#solc)" opacity=".42">' + f'<circle cx="{vx}" cy="{vy}" r="560" fill="url(#sol)"/>'
          + "".join(f'<rect x="{vx - 600}" y="{vy - 40 - k * (28 + k * 5)}" width="1200" height="{6 + k * 2.4}" fill="{p["f"]}"/>' for k in range(1, 12)) + "</g>")
    for i in range(-18, 19):
        s.linha(vx + i * 70, vy, vx + i * 650, H, d, 3, .45)
    for k in range(1, 16):
        y = vy + (H - vy) * (k / 15) ** 2
        s.linha(0, y, W, y, d, 3, .22 + .2 * k / 15)
    s.linha(0, vy, W, vy, c2, 4, .6)
    for k, (cor, rr) in enumerate(((d, 1150), (c2, 1010), (d, 870), (c2, 730), (d, 590))):  # faixas curvas, como as do logo
        s.path(f"M0,{rr} A{rr},{rr} 0 0 1 {rr},0", stroke=cor, w=26, op=.30 - k * .035)
    for _ in range(36):
        s.ret(r.randrange(0, W // 40) * 40, r.randrange(0, 1200 // 40) * 40, 36, 36, fill=r.choice((d, c2)), op=r.uniform(.03, .09))
    for y in range(0, H, 8):
        s.linha(0, y, W, y, "#000000", 2, .07)


def m_mooretech(s, p):
    """Cyberware de corpo inteiro: esqueleto mecânico em esquema (servos, pistões, vértebras) à direita e
    placas de blindagem rebitadas ao fundo."""
    d, c2, r = p["d"], p["s"], s.r
    for row in range(6):  # placas de blindagem
        for col in range(4):
            x, y, w, h = 150 + col * 340 + (row % 2) * 90, 250 + row * 270, 300, 230
            s.poli(chanfro(x, y, x + w, y + h, 38), stroke=d, w=2, op=.14)
            if r.random() < .35:
                s.poli(chanfro(x, y, x + w, y + h, 38), fill=d, op=.045)
            for (rx, ry) in ((x + 22, y + 22), (x + w - 22, y + 22), (x + 22, y + h - 22), (x + w - 22, y + h - 22)):
                s.circ(rx, ry, 5, fill=d, op=.3)
    cx = 2900
    ln = lambda *a, **k: s.linha(*a, **k)

    def junta(x, y, rr=34):
        s.circ(x, y, rr, stroke=d, w=4, op=.5)
        s.circ(x, y, rr * .45, fill=d, op=.4)
        ln(x - rr * 1.4, y, x + rr * 1.4, y, c2, 2, .3)

    def membro(p0, p1, larg):  # segmento com duas longarinas e um pistão no meio
        (x0, y0), (x1, y1) = p0, p1
        L = math.hypot(x1 - x0, y1 - y0)
        nx, ny = -(y1 - y0) / L, (x1 - x0) / L
        for sg in (-1, 1):
            ln(x0 + nx * larg * sg, y0 + ny * larg * sg, x1 + nx * larg * sg, y1 + ny * larg * sg, d, 4, .42)
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        ln(x0 + (x1 - x0) * .25, y0 + (y1 - y0) * .25, x0 + (x1 - x0) * .75, y0 + (y1 - y0) * .75, c2, 10, .22)
        for t in (.15, .85):
            ln(x0 + (x1 - x0) * t + nx * larg * 1.4, y0 + (y1 - y0) * t + ny * larg * 1.4,
               x0 + (x1 - x0) * t - nx * larg * 1.4, y0 + (y1 - y0) * t - ny * larg * 1.4, d, 5, .5)
    s.circ(cx, 330, 100, stroke=d, w=4, op=.5)  # crânio e mandíbula
    s.poli([(cx - 70, 400), (cx + 70, 400), (cx + 50, 470), (cx - 50, 470)], stroke=d, w=4, op=.45)
    s.circ(cx - 38, 330, 22, stroke=c2, w=3, op=.5)
    s.circ(cx + 38, 330, 22, stroke=c2, w=3, op=.5)
    for k in range(14):  # coluna
        y = 480 + k * 42
        w = 34 + 18 * math.sin(k / 13 * math.pi)
        s.poli([(cx - w, y), (cx + w, y), (cx + w * .8, y + 30), (cx - w * .8, y + 30)], stroke=d, w=3, op=.5)
    ln(cx - 300, 560, cx + 300, 560, d, 5, .5)
    for sg in (-1, 1):
        for k in range(6):  # costelas
            y = 590 + k * 52
            wd = 190 - abs(k - 2) * 12
            s.path(f"M{cx + sg * 40},{y} C{cx + sg * (wd * .6)},{y - 18} {cx + sg * wd},{y + 20} {cx + sg * (wd - 20)},{y + 82}", stroke=d, w=3, op=.38)
        junta(cx + sg * 300, 560)
        membro((cx + sg * 300, 600), (cx + sg * 360, 900), 26)
        junta(cx + sg * 360, 920, 30)
        membro((cx + sg * 360, 960), (cx + sg * 330, 1240), 22)
        s.poli([(cx + sg * 330 - 40, 1240), (cx + sg * 330 + 40, 1240), (cx + sg * 330 + 30, 1330), (cx + sg * 330 - 30, 1330)], stroke=d, w=3, op=.4)
        junta(cx + sg * 110, 1180, 38)
        membro((cx + sg * 110, 1220), (cx + sg * 150, 1620), 32)
        junta(cx + sg * 150, 1650, 34)
        membro((cx + sg * 150, 1690), (cx + sg * 120, 2000), 26)
        ln(cx + sg * 60, 2010, cx + sg * 230, 2010, d, 5, .45)
    s.poli([(cx - 200, 1040), (cx + 200, 1040), (cx + 240, 1100), (cx + 150, 1230), (cx - 150, 1230), (cx - 240, 1100)], stroke=d, w=4, op=.45)
    for y, w in ((520, 330), (870, 360), (1180, 330), (1650, 330)):  # chamadas de medida
        ln(cx + w + 60, y, cx + w + 360, y, c2, 2, .3)
        s.ret(cx + w + 360, y - 14, 60, 28, stroke=c2, sw=2, op=.35)


def m_generico(s, p):
    d, c2 = p["d"], p["s"]
    for rr in range(300, 2200, 260):
        s.circ(2900, 1080, rr, stroke=d, w=2, op=.14)
    for x in range(0, W, 160):
        s.linha(x, 0, x, H, c2, 2, .04)
    for y in range(0, H, 160):
        s.linha(0, y, W, y, c2, 2, .04)


MOTIVOS = {"arasaka": m_arasaka, "militech": m_militech, "biotechnica": m_biotechnica, "netwatch": m_netwatch,
           "traumateam": m_traumateam, "kangtao": m_kangtao, "zetatech": m_zetatech, "delamain": m_delamain,
           "dynalar": m_dynalar, "kiroshi": m_kiroshi, "nightcorp": m_nightcorp, "petrochem": m_petrochem,
           "segotari": m_segotari, "mooretech": m_mooretech}
# régua de marcas na moldura: as corporações austeras ou orgânicas ficam sem
# sem a marca d'água do símbolo (o motivo já ocupa o lado direito)
SEM_MARCA = {"mooretech"}
SEM_REGUA = {"arasaka", "nightcorp", "biotechnica"}


# ---------------------------------------------------------------- moldura HUD e composição do fundo
def moldura(s, p):
    d, c2 = p["d"], p["s"]
    s.poli(chanfro(56, 56, W - 56, H - 56, 84), stroke=d, w=3, op=.5)
    if p["id"] == "arasaka":
        s.poli(chanfro(76, 76, W - 76, H - 76, 70), stroke=c2, w=2, op=.18)
    L = 240
    for (ax, ay, dx, dy) in ((56, 56, 1, 1), (W - 56, 56, -1, 1), (56, H - 56, 1, -1), (W - 56, H - 56, -1, -1)):
        s.trilha([(ax + dx * L, ay), (ax + dx * 84, ay), (ax, ay + dy * 84), (ax, ay + dy * L)], d, 10, .95, extra='stroke-linecap="butt"')
    if p["id"] not in SEM_REGUA:
        for x in range(420, W - 420, 40):
            l = 30 if (x // 40) % 5 == 0 else 14
            s.linha(x, 56, x, 56 + l, c2, 2, .35)
            s.linha(x, H - 56, x, H - 56 - l, c2, 2, .35)
        for y in range(420, H - 420, 40):
            l = 30 if (y // 40) % 5 == 0 else 14
            s.linha(56, y, 56 + l, y, c2, 2, .3)
            s.linha(W - 56, y, W - 56 - l, y, c2, 2, .3)
    for i in range(6):  # marcadores no canto superior direito e barra de progresso embaixo
        s.ret(W - 420 + i * 44, 130, 24, 24, fill=d if i < 3 else "none", stroke=d, sw=2, op=.8)
    for i in range(14):
        s.ret(W - 760 + i * 44, H - 150, 30, 12, fill=d if i < 5 else "none", stroke=d, sw=2, op=.6)


def logo_svg(id_):
    base = ROOT / "assets" / "corporacoes"
    for nome in (f"{id_}-logo-escuro.svg", f"{id_}-logo.svg"):
        if (base / nome).is_file():
            return base / nome
    return None


def tinge_neutro(texto, destaque):
    """Símbolo de uma cor só e clara/neutra (branco, cinza claro): passa para a cor de destaque, senão a
    marca d'água sairia como uma mancha cinza. Símbolos coloridos ou de várias cores ficam como estão."""
    cores = set(re.findall(r'fill="(#[0-9A-Fa-f]{6})"', texto))
    if len(cores) != 1:
        return texto
    c = next(iter(cores))
    r, g, b = rgb(c)
    if min(r, g, b) > 185 and max(r, g, b) - min(r, g, b) < 40:
        return texto.replace(c, destaque)
    return texto


def interior_svg(arq, x, y, w, h, op=1.0, destaque=None):
    """O vetor (símbolo ou logo) como <svg> aninhado numa caixa x,y,w,h, centralizado, mantendo a proporção."""
    t = arq.read_text()
    if destaque:
        t = tinge_neutro(t, destaque)
    vb = re.search(r'viewBox="([^"]+)"', t)
    corpo = re.search(r"<svg[^>]*>(.*)</svg>", t, re.S)
    if not vb or not corpo:
        return ""
    return f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" viewBox="{vb.group(1)}" opacity="{op}">{corpo.group(1)}</svg>'


def fundo_svg(p):
    rnd = random.Random(zlib.crc32(p["id"].encode()))
    s = Cena(p, rnd)
    d, f = p["d"], p["f"]
    MOTIVOS.get(p["id"], m_generico)(s, p)
    motivo = "\n".join(s.o)
    simbolo = ROOT / "assets" / "corporacoes" / f"{p['id']}.svg"
    marca = interior_svg(simbolo, 2150, 330, 1500, 1500, .10, destaque=d) if simbolo.is_file() and p["id"] not in SEM_MARCA else ""
    s.o = []
    moldura(s, p)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
<radialGradient id="luz" cx="0.68" cy="0.5" r="0.8"><stop offset="0" stop-color="{mix(d, f, .16)}"/><stop offset="1" stop-color="{f}"/></radialGradient>
<radialGradient id="calmo" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#000" stop-opacity=".72"/><stop offset="0.7" stop-color="#000" stop-opacity=".25"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
<mask id="mm"><rect width="{W}" height="{H}" fill="#fff"/><ellipse cx="{CX}" cy="{CY}" rx="1250" ry="760" fill="url(#calmo)"/></mask>
<filter id="desf" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="9"/></filter>
{"".join(s.defs)}
</defs>
<rect width="{W}" height="{H}" fill="{f}"/>
<rect width="{W}" height="{H}" fill="url(#luz)"/>
<g mask="url(#mm)">
{motivo}
</g>
{marca}
{chr(10).join(s.o)}
</svg>
'''


def inkscape(svg, png, w=None):
    cmd = ["inkscape", str(svg), "-o", str(png)] + (["-w", str(w)] if w else [])
    subprocess.run(cmd, check=True, capture_output=True)


# ---------------------------------------------------------------- composição final (Pillow)
def placa(img, p, logo, cx, topo=None, base=None, caixa=(1000, 400), pad=64, area=330_000):
    """Logo numa placa HUD: fundo escuro translúcido, filete, cantoneiras e marcador lateral."""
    d, f = p["d"], p["f"]
    bw, bh = caixa
    lw, lh = logo.size
    k = min(bw / lw, bh / lh, (area / (lw * lh)) ** .5)
    lg = logo.resize((max(1, round(lw * k)), max(1, round(lh * k))), Image.LANCZOS)
    pw, ph = lg.width + 2 * pad, lg.height + 2 * pad
    x0 = round(cx - pw / 2)
    y0 = round(topo if topo is not None else base - ph)
    ss = 2
    cam = Image.new("RGBA", (pw * ss, ph * ss), (0, 0, 0, 0))
    dr = ImageDraw.Draw(cam)
    c = 36 * ss
    pts = [(c, 0), (pw * ss - 1, 0), (pw * ss - 1, ph * ss - c), (pw * ss - c, ph * ss - 1), (0, ph * ss - 1), (0, c)]
    dr.polygon(pts, fill=rgb(f) + (170,))
    dr.line(pts + [pts[0]], fill=rgb(d) + (130,), width=2 * ss, joint="curve")
    L = 90 * ss
    for (ax, ay, dx, dy) in ((0, 0, 1, 1), (pw * ss - 1, ph * ss - 1, -1, -1)):
        dr.line([(ax + dx * L, ay), (ax, ay), (ax, ay + dy * L)], fill=rgb(d) + (255,), width=6 * ss)
    dr.rectangle([0, ph * ss * .3, 10 * ss, ph * ss * .7], fill=rgb(d) + (255,))
    cam = cam.resize((pw, ph), Image.LANCZOS)
    cam.alpha_composite(lg, (pad, pad))
    sombra = Image.new("RGBA", (pw + 160, ph + 160), (0, 0, 0, 0))
    sombra.paste((0, 0, 0, 150), (80, 80, 80 + pw, 80 + ph))
    sombra = sombra.filter(ImageFilter.GaussianBlur(26))
    img.alpha_composite(sombra, (x0 - 80, y0 - 80))
    img.alpha_composite(cam, (x0, y0))


def mascara_central(fw, fh, desfoque):
    zw, zh = W * fw, H * fh
    x0, y0, x1, y1 = (W - zw) / 2, (H - zh) / 2, (W + zw) / 2, (H + zh) / 2
    c = zh * .12
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(chanfro(x0, y0, x1, y1, c), fill=255)
    return m.filter(ImageFilter.GaussianBlur(H * desfoque))


def rebaixa(img, cor, op, masc):
    m = masc.point(lambda v: round(v * op))
    return Image.composite(Image.new("RGB", img.size, rgb(cor)), img, m)


def moldura_login(img, cor):
    k, s = 2, H / 1080
    zw, zh = 560 * s, 400 * s
    x0, y0 = (W - zw) / 2, (H - zh) / 2
    x1, y1 = x0 + zw, y0 + zh
    arm, ch = 26 * s, 10 * s
    cam = Image.new("L", (W * k, H * k), 0)
    d = ImageDraw.Draw(cam)
    for ax, ay, dx, dy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        d.line([((ax + dx * arm) * k, ay * k), ((ax + dx * ch) * k, ay * k), (ax * k, (ay + dy * ch) * k), (ax * k, (ay + dy * arm) * k)],
               fill=255, width=max(1, round(s)) * k, joint="curve")
    alfa = cam.resize((W, H), Image.LANCZOS).point(lambda v: round(v * .35))
    return Image.composite(Image.new("RGB", img.size, rgb(cor)), img, alfa)


def gera(id_, saida):
    p = paleta(id_)
    saida = pathlib.Path(saida)
    saida.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="cyberkde-corp-") as tmp:
        tmp = pathlib.Path(tmp)
        (tmp / "fundo.svg").write_text(fundo_svg(p))
        inkscape(tmp / "fundo.svg", tmp / "fundo.png")
        base = Image.open(tmp / "fundo.png").convert("RGB")
        lsvg = logo_svg(id_)
        logo = None
        if lsvg:
            inkscape(lsvg, tmp / "logo.png", 1600)
            logo = Image.open(tmp / "logo.png").convert("RGBA")
    vistas = {}
    desk = base.convert("RGBA")
    if logo:
        placa(desk, p, logo, cx=180 + 600, base=H - 260, caixa=(1160, 640))
    vistas["desktop"] = desk.convert("RGB")
    lock = rebaixa(base, p["f"], .55, mascara_central(.52, .56, .09)).convert("RGBA")
    if logo:
        placa(lock, p, logo, cx=CX, topo=170, caixa=(900, 420), pad=52, area=190_000)
    vistas["lockscreen"] = lock.convert("RGB")
    lg = ImageEnhance.Brightness(base).enhance(.88)
    lg = moldura_login(rebaixa(lg, p["f"], .82, mascara_central(.40, .48, .07)), p["d"]).convert("RGBA")
    if logo:
        placa(lg, p, logo, cx=CX, topo=170, caixa=(900, 420), pad=52, area=190_000)
    vistas["login"] = lg.convert("RGB")
    for nome, im in vistas.items():
        im.save(saida / f"{nome}.png", compress_level=4)
    return saida


def previa(id_, saida, destino):
    destino.mkdir(parents=True, exist_ok=True)
    im = Image.open(pathlib.Path(saida) / "desktop.png").convert("RGB").resize((480, 270), Image.LANCZOS)
    arq = destino / f"corp-{id_}.webp"
    im.save(arq, "WEBP", quality=80, method=6)
    return arq


def prancha(ids, base, arq):
    cols, cw, chh = 4, 480, 270
    lin = math.ceil(len(ids) / cols)
    S = Image.new("RGB", (cols * (cw + 10) + 10, lin * (chh + 36) + 10), (14, 14, 23))
    d = ImageDraw.Draw(S)
    for i, id_ in enumerate(ids):
        x, y = 10 + (i % cols) * (cw + 10), 10 + (i // cols) * (chh + 36)
        S.paste(Image.open(pathlib.Path(base) / id_ / "desktop.png").convert("RGB").resize((cw, chh), Image.LANCZOS), (x, y))
        d.text((x, y + chh + 6), paleta(id_)["nome"], fill=(220, 220, 228))
    S.save(arq)


def carimbo(id_):
    """Muda com o gerador, a paleta da corporação e os vetores dela: quem instala só regera então."""
    import hashlib
    p = paleta(id_)
    h = hashlib.sha256(HERE.joinpath("gen_corp.py").read_bytes())
    h.update(json.dumps(p, sort_keys=True).encode())
    for arq in (logo_svg(id_), ROOT / "assets" / "corporacoes" / f"{id_}.svg"):
        if arq and arq.is_file():
            h.update(arq.read_bytes())
    return h.hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id", help="id da corporação ou 'todas'")
    ap.add_argument("--carimbo", action="store_true", help="só imprime o carimbo da corporação")
    ap.add_argument("--saida", default="")
    ap.add_argument("--previas", default="")
    ap.add_argument("--prancha", default="")
    a = ap.parse_args()
    if a.carimbo:
        print(carimbo(a.id))
        return
    ids = ids_corporacoes() if a.id == "todas" else [a.id]
    base = pathlib.Path(a.saida) if a.saida else HERE.parent / "build" / "corp"
    for id_ in ids:
        destino = (base / id_) if (a.id == "todas" or not a.saida) else base
        gera(id_, destino)
        (destino / ".carimbo").write_text(carimbo(id_) + "\n")
        if a.previas:
            previa(id_, destino, pathlib.Path(a.previas))
        print(id_, destino, flush=True)
    if a.prancha and a.id == "todas":
        prancha(ids, base, a.prancha)


if __name__ == "__main__":
    main()
