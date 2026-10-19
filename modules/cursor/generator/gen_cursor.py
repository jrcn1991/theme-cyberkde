#!/usr/bin/env python3
"""Tema de cursor CyberKDE: desenha os cursores em SVG (grade de 64 unidades), rasteriza com o Inkscape
nos tamanhos 24, 32, 48 e 64 e monta os arquivos Xcursor com o xcursorgen.

Variantes: padrao (contorno claro + detalhe na cor de destaque), neon (destaque com brilho) e minimo.
A cor de destaque e as superficies vêm do cyberlib (cyberkde cor / cyberkde corp).

Uso: gen_cursor.py [--saida DIR] [--variantes padrao,neon,minimo] [--previas DIR]
Saída: DIR/<variante>/{svg,png,cursors}/ e DIR/<variante>/theme/ (a pasta pronta para ~/.local/share/icons).
"""
import argparse
import math
import pathlib
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
sys.path.insert(0, str(ROOT / "generator"))
from cyberlib import BASE, CYAN, RED, TXT1, mix  # noqa: E402

SIZES = (24, 32, 48, 64)
FRAMES = 12      # quadros do cursor de espera
FRAME_MS = 70    # 12 x 70 ms = uma volta em 840 ms
GIRO = (FRAMES, [FRAME_MS] * FRAMES)
# Colchetes que fecham: 2 quadros de 40 ms e o último "para sempre" (o Xcursor repete em laço, então o
# quadro final dura 1 h: a animação só reaparece uma vez por hora, com o ponteiro parado).
FECHA = (3, [40, 40, 3_600_000])
G = 64           # grade do desenho


# ---------------------------------------------------------------- estilos
class Estilo:
    def __init__(self, id, nome, fill, out, ink, det, sw, glow=False):
        self.id, self.nome, self.fill, self.out, self.ink, self.det, self.sw, self.glow = id, nome, fill, out, ink, det, sw, glow


ESTILOS = {
    "padrao": Estilo("padrao", "CyberKDE Cursor", fill=BASE, out=TXT1, ink=TXT1, det=RED, sw=2.6),
    "neon": Estilo("neon", "CyberKDE Cursor Neon", fill=BASE, out=RED, ink=TXT1, det=RED, sw=2.2, glow=True),
    "minimo": Estilo("minimo", "CyberKDE Cursor Mínimo", fill=TXT1, out=BASE, ink=BASE, det=BASE, sw=1.9),
    # mira: o desenho do padrão, mas o ponteiro é uma mira fina e a mão ganha colchetes que fecham
    "mira": Estilo("mira", "CyberKDE Cursor Mira", fill=BASE, out=TXT1, ink=TXT1, det=RED, sw=2.6),
}


def poly(pts, fechar=True):
    return "M" + " L".join(f"{x:g},{y:g}" for x, y in pts) + (" Z" if fechar else "")


def octogono(cx, cy, r):
    return [(cx + r * math.cos(math.radians(22.5 + 45 * k)), cy + r * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]


def espelha_x(pts):
    return [(G - x, y) for x, y in pts]


def gira(pts, graus, cx=32, cy=32):
    c, s = math.cos(math.radians(graus)), math.sin(math.radians(graus))
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


# ---------------------------------------------------------------- camadas (dependem do estilo)
class Pincel:
    def __init__(self, e):
        self.e = e

    def corpo(self, paths, tr=""):
        """União de peças: contorno (todas engrossadas) por baixo, preenchimento por cima. Sem linha
        interna onde as peças se encontram."""
        e = self.e
        o = []
        grp = f' transform="{tr}"' if tr else ""
        if e.glow:
            o.append(f'<g{grp} filter="url(#glow)" opacity="0.95" fill="{e.out}" stroke="{e.out}" stroke-width="{e.sw * 2 + 2.5:g}" stroke-linejoin="round">'
                     + "".join(f'<path d="{d}"/>' for d in paths) + "</g>")
        o.append(f'<g{grp} fill="{e.out}" stroke="{e.out}" stroke-width="{e.sw * 2:g}" stroke-linejoin="miter" stroke-miterlimit="3">'
                 + "".join(f'<path d="{d}"/>' for d in paths) + "</g>")
        o.append(f'<g{grp} fill="{e.fill}" stroke="{e.fill}" stroke-width="0.5" stroke-linejoin="miter">'
                 + "".join(f'<path d="{d}"/>' for d in paths) + "</g>")
        return "".join(o)

    def solido(self, paths, cor=None, tr=""):
        """Peça cheia na cor dada, com friso escuro em volta para separar de qualquer fundo."""
        e = self.e
        cor = cor or e.ink
        grp = f' transform="{tr}"' if tr else ""
        casing = e.fill if e.id != "minimo" else e.out
        return (f'<g{grp} fill="{casing}" stroke="{casing}" stroke-width="3.2" stroke-linejoin="miter" stroke-miterlimit="3">'
                + "".join(f'<path d="{d}"/>' for d in paths) + "</g>"
                + f'<g{grp} fill="{cor}">' + "".join(f'<path d="{d}"/>' for d in paths) + "</g>")

    def detalhe(self, paths, tr="", cor=None):
        e = self.e
        cor = cor or e.det
        grp = f' transform="{tr}"' if tr else ""
        o = ""
        if e.glow:
            o += f'<g{grp} filter="url(#glow)" fill="{cor}" opacity="0.9">' + "".join(f'<path d="{d}"/>' for d in paths) + "</g>"
        return o + f'<g{grp} fill="{cor}">' + "".join(f'<path d="{d}"/>' for d in paths) + "</g>"

    def traco(self, d, w=2.8, cor=None, tr="", extra=""):
        e = self.e
        cor = cor or e.det
        grp = f' transform="{tr}"' if tr else ""
        o = ""
        if e.glow:
            o += f'<path{grp} d="{d}" fill="none" stroke="{cor}" stroke-width="{w + 1.5:g}" stroke-linejoin="round" filter="url(#glow)" opacity="0.9" {extra}/>'
        return o + f'<path{grp} d="{d}" fill="none" stroke="{cor}" stroke-width="{w:g}" stroke-linejoin="miter" stroke-miterlimit="3" {extra}/>'


def doc(e, corpo):
    glow = f'<filter id="glow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="{2.4 if e.glow else 0}"/></filter>' if e.glow else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{G}" height="{G}" viewBox="0 0 {G} {G}">'
            f'<defs>{glow}</defs>{corpo}</svg>\n')


# ---------------------------------------------------------------- geometria dos cursores
ARROW = [(8, 6), (8, 50), (19, 39), (27, 56), (34, 52.5), (26, 36), (42, 36)]
ARROW_LISTRA = [(11.5, 13), (14.5, 16), (14.5, 37), (11.5, 40)]
ARROW_TR = "translate(8 6) scale(0.8) translate(-8 -6)"  # seta menor quando há selo
PLACA = [(39, 34), (57, 34), (61, 38), (61, 56), (57, 60), (39, 60), (35, 56), (35, 38)]  # selo 26x26 no canto
MAIS = [(28, 6), (36, 6), (36, 28), (58, 28), (58, 36), (36, 36), (36, 58), (28, 58), (28, 36), (6, 36), (6, 28), (28, 28)]
H2 = [(5, 32), (16, 20), (16, 28), (48, 28), (48, 20), (59, 32), (48, 44), (48, 36), (16, 36), (16, 44)]
H2_MIOLO = [(32, 27.5), (36.5, 32), (32, 36.5), (27.5, 32)]
CRUZ4 = [(32, 4), (43, 15), (36, 15), (36, 28), (49, 28), (49, 21), (60, 32), (49, 43), (49, 36), (36, 36), (36, 49), (43, 49),
         (32, 60), (21, 49), (28, 49), (28, 36), (15, 36), (15, 43), (4, 32), (15, 21), (15, 28), (28, 28), (28, 15), (21, 15)]
CRUZ4_MIOLO = [(32, 28), (36, 32), (32, 36), (28, 32)]
SETA_CIMA = [(32, 5), (51, 26), (38, 26), (38, 59), (26, 59), (26, 26), (13, 26)]
SETA_E = [(4, 32), (14, 22), (14, 28), (25, 28), (25, 36), (14, 36), (14, 42)]
CANTO = [(6, 6), (19, 6), (19, 9.5), (9.5, 9.5), (9.5, 19), (6, 19)]


def cantoneiras():
    a = CANTO
    b = [(G - x, y) for x, y in a]
    c = [(x, G - y) for x, y in a]
    d = [(G - x, G - y) for x, y in a]
    return [poly(a), poly(b), poly(c), poly(d)]


def seta(p, extra_tr="", com_listra=True):
    s = p.corpo([poly(ARROW)], extra_tr)
    if com_listra:
        s += p.detalhe([poly(ARROW_LISTRA)], extra_tr)
    return s


def selo(p, glifo):
    return p.corpo([poly(PLACA)]) + glifo


def glifo_mais(p):
    return p.detalhe(["M46.5,39.5 L49.5,39.5 L49.5,45.5 L55.5,45.5 L55.5,48.5 L49.5,48.5 L49.5,54.5 L46.5,54.5 L46.5,48.5 L40.5,48.5 L40.5,45.5 L46.5,45.5 Z"])


def glifo_proibido(p):
    return p.traco(poly(octogono(48, 47, 7.6)), 2.6) + p.traco("M43,42 L53,52", 2.6)


def glifo_ajuda(p):
    return (p.traco("M41.5,43.5 L41.5,41 L44,38.5 L52,38.5 L54.5,41 L54.5,45 L48.6,49 L48.6,51.5", 2.8, extra='stroke-linecap="butt"')
            + p.detalhe(["M47,53.5 L50.2,53.5 L50.2,56.5 L47,56.5 Z"]))


def glifo_link(p):
    return p.traco("M42,53 L52.5,42.5", 3.0) + p.detalhe(["M46,39.5 L56,39.5 L56,49.5 Z"])


def glifo_mover(p):
    return p.detalhe([poly(CRUZ4)], "translate(48 47) scale(0.25) translate(-32 -32)")


def glifo_menu(p):
    return p.detalhe([poly([(40, 40), (56, 40), (56, 42.6), (40, 42.6)]), poly([(40, 46), (56, 46), (56, 48.6), (40, 48.6)]),
                      poly([(40, 52), (56, 52), (56, 54.6), (40, 54.6)])])


def mao_pontar(p, tr=""):
    pecas = [poly([(21, 9), (24, 6), (26, 6), (29, 9), (29, 33), (21, 33)]),                # indicador
             poly([(30.5, 25), (37, 25), (37, 33), (30.5, 33)]),                            # dedos dobrados
             poly([(38.5, 28), (45, 28), (45, 34), (38.5, 34)]),
             poly([(46.5, 31), (52, 31), (52, 40), (46.5, 40)]),
             poly([(15, 32), (52, 32), (52, 47), (45, 56), (24, 56), (15, 46)]),              # palma
             poly([(9, 36), (14, 31), (21, 39), (21, 47), (14, 43)])]                         # polegar
    return p.corpo(pecas, tr) + p.detalhe([poly([(24, 49), (45, 49), (45, 52), (24, 52)])], tr)


def colchetes(x0, y0, x1, y1, braco=9.0, e=3.0):
    """Quatro cantoneiras em L em volta do retângulo (x0,y0)-(x1,y1)."""
    return [poly([(x0, y0), (x0 + braco, y0), (x0 + braco, y0 + e), (x0 + e, y0 + e), (x0 + e, y0 + braco), (x0, y0 + braco)]),
            poly([(x1, y0), (x1 - braco, y0), (x1 - braco, y0 + e), (x1 - e, y0 + e), (x1 - e, y0 + braco), (x1, y0 + braco)]),
            poly([(x0, y1), (x0 + braco, y1), (x0 + braco, y1 - e), (x0 + e, y1 - e), (x0 + e, y1 - braco), (x0, y1 - braco)]),
            poly([(x1, y1), (x1 - braco, y1), (x1 - braco, y1 - e), (x1 - e, y1 - e), (x1 - e, y1 - braco), (x1, y1 - braco)])]


MAO_PEQUENA = "translate(32 32) scale(0.74) translate(-30.5 -31.5)"


def mao_colchetes(p, k):
    """Mão com colchetes que fecham em volta dela: quadro 0 abertos, 1 a meio caminho, 2 firmes."""
    abre = (6.0, 2.8, 0.0)[k]
    op = (0.55, 0.8, 1.0)[k]
    cor = p.e.det if p.e.id != "minimo" else p.e.fill
    return (mao_pontar(p, MAO_PEQUENA)
            + f'<g opacity="{op}">' + p.solido(colchetes(9 - abre, 7 - abre, 55 + abre, 57 + abre), cor) + "</g>")


def mira_fina(p):
    """Mira fina de centro vazado, em ciano, com quatro pontos de destaque nas diagonais."""
    ticks = [poly([(30.5, 4), (33.5, 4), (33.5, 23), (30.5, 23)]), poly([(30.5, 41), (33.5, 41), (33.5, 60), (30.5, 60)]),
             poly([(4, 30.5), (23, 30.5), (23, 33.5), (4, 33.5)]), poly([(41, 30.5), (60, 30.5), (60, 33.5), (41, 33.5)])]
    pontos = [poly([(cx - 1.8, cy - 1.8), (cx + 1.8, cy - 1.8), (cx + 1.8, cy + 1.8), (cx - 1.8, cy + 1.8)])
              for cx, cy in ((19, 19), (45, 19), (19, 45), (45, 45))]
    return p.solido(ticks, CYAN) + p.solido(pontos, p.e.det if p.e.id != "minimo" else p.e.fill)


def mao_aberta(p):
    xs = [(18, 16), (26.5, 9), (35, 7), (43.5, 13)]
    pecas = [poly([(x, y + 3), (x + 2.5, y), (x + 5.5, y), (x + 8, y + 3), (x + 8, 32), (x, 32)]) for x, y in xs]
    pecas += [poly([(18, 28), (51.5, 28), (51.5, 46), (44, 57), (25, 57), (18, 46)]), poly([(9, 33), (14, 28), (20, 38), (20, 47), (13, 43)])]
    return p.corpo(pecas) + p.detalhe([poly([(24, 50), (45, 50), (45, 53), (24, 53)])])


def mao_fechada(p):
    xs = [18, 26.5, 35, 43.5]
    pecas = [poly([(x, 25.5), (x + 2.5, 23), (x + 5.5, 23), (x + 8, 25.5), (x + 8, 33), (x, 33)]) for x in xs]
    pecas += [poly([(17, 30), (51.5, 30), (51.5, 46), (44, 57), (25, 57), (17, 46)]), poly([(9, 38), (14, 33), (20, 41), (20, 47), (13, 45)])]
    return p.corpo(pecas) + p.detalhe([poly([(24, 50), (45, 50), (45, 53), (24, 53)])])


def ibeam(p, graus=0):
    tr = f"rotate({graus} 32 32)" if graus else ""
    pecas = [poly([(30, 11), (34, 11), (34, 53), (30, 53)]),
             poly([(24, 6), (40, 6), (42, 8), (42, 11), (22, 11), (22, 8)]),
             poly([(22, 53), (42, 53), (42, 56), (40, 58), (24, 58), (22, 56)])]
    return p.corpo(pecas, tr) + p.detalhe([poly([(25.5, 7.2), (38.5, 7.2), (38.5, 9.6), (25.5, 9.6)]),
                                           poly([(25.5, 54.4), (38.5, 54.4), (38.5, 56.8), (25.5, 56.8)])], tr)


def duplo(p, graus):
    tr = f"rotate({graus} 32 32)" if graus else ""
    return p.corpo([poly(H2)], tr) + p.detalhe([poly(H2_MIOLO)], tr)


def divisor(p, graus):
    tr = f"rotate({graus} 32 32)" if graus else ""
    pecas = [poly([(30, 8), (34, 8), (34, 56), (30, 56)]), poly(SETA_E), poly(espelha_x(SETA_E))]
    return p.corpo(pecas, tr) + p.detalhe([poly([(30, 28), (34, 28), (34, 36), (30, 36)])], tr)


def mover4(p):
    return p.corpo([poly(CRUZ4)]) + p.detalhe([poly(CRUZ4_MIOLO)])


def proibido(p):
    return (p.corpo([poly(octogono(32, 32, 24))])
            + p.traco(poly(octogono(32, 32, 16.5)), 4.2)
            + p.solido(["M20.5,20.5 L23.5,17.5 L46.5,40.5 L43.5,43.5 Z"], p.e.det))


def mira(p):
    ticks = [poly([(30, 4), (34, 4), (34, 24), (30, 24)]), poly([(30, 40), (34, 40), (34, 60), (30, 60)]),
             poly([(4, 30), (24, 30), (24, 34), (4, 34)]), poly([(40, 30), (60, 30), (60, 34), (40, 34)])]
    return p.corpo(ticks) + p.detalhe([poly([(29, 29), (35, 29), (35, 35), (29, 35)])]) + p.solido(cantoneiras(), p.e.det if p.e.id != "minimo" else p.e.fill)


def celula(p):
    return p.corpo([poly(MAIS)]) + p.detalhe([poly([(29.5, 29.5), (34.5, 29.5), (34.5, 34.5), (29.5, 34.5)])])


def xis(p):
    return p.corpo([poly(MAIS)], "rotate(45 32 32)") + p.detalhe([poly([(29.5, 29.5), (34.5, 29.5), (34.5, 34.5), (29.5, 34.5)])], "rotate(45 32 32)")


def seta_dir(p, graus):
    tr = f"rotate({graus} 32 32)" if graus else ""
    return p.corpo([poly(SETA_CIMA)], tr) + p.detalhe([poly([(30, 33), (34, 33), (34, 54), (30, 54)])], tr)


def pipeta(p):
    tr = "translate(9 57) rotate(45)"
    pecas = [poly([(0, 0), (-3, -9), (-3, -26), (3, -26), (3, -9)]), poly([(-7, -26), (7, -26), (7, -31), (-7, -31)]),
             poly([(-5, -33), (-3, -35), (3, -35), (5, -33), (5, -46), (-5, -46)])]
    return p.corpo(pecas, tr) + p.detalhe([poly([(-7, -26.8), (7, -26.8), (7, -30.2), (-7, -30.2)])], tr)


def lapis(p):
    tr = "translate(9 57) rotate(45)"
    pecas = [poly([(0, 0), (-5, -9), (-5, -36), (5, -36), (5, -9)]), poly([(-5, -39), (5, -39), (5, -46), (-5, -46)])]
    return p.corpo(pecas, tr) + p.detalhe([poly([(-5, -32), (5, -32), (5, -36), (-5, -36)]), poly([(-1.4, -6), (1.4, -6), (0, -1)])], tr)


def lupa(p, sinal):
    pecas = [poly(octogono(26, 26, 19)), poly([(37, 41), (41, 37), (61, 56), (56, 61)])]
    e = p.e
    vidro = mix(e.det, e.fill, 0.18) if e.id != "minimo" else mix(e.out, e.fill, 0.15)
    s = p.corpo(pecas) + f'<path d="{poly(octogono(26, 26, 12))}" fill="{vidro}"/>'
    glifo = [poly([(19.5, 24.5), (32.5, 24.5), (32.5, 27.5), (19.5, 27.5)])]
    if sinal:
        glifo.append(poly([(24.5, 19.5), (27.5, 19.5), (27.5, 32.5), (24.5, 32.5)]))
    return s + p.detalhe(glifo)


def espera(p, k, so_giro=False):
    """Disco com 12 marcas; a marca k e a cabeça do cometa (cor de destaque), as de trás vão apagando."""
    e = p.e
    o = "" if so_giro else p.corpo([poly(octogono(32, 32, 22))])
    dim = e.ink
    marcas = []
    for i in range(12):
        atras = (k - i) % 12
        cor, op = (e.det, 1.0) if atras == 0 else (None, 0)
        if atras == 0:
            cor, op = e.det, 1.0
        elif atras <= 3:
            cor, op = e.det, (0.75, 0.5, 0.3)[atras - 1]
        else:
            cor, op = dim, 0.28
        if e.id == "minimo" and atras == 0:
            cor, op = e.ink, 1.0
        elif e.id == "minimo" and atras <= 3:
            cor, op = e.ink, (0.75, 0.5, 0.3)[atras - 1] + 0.1
        a = math.radians(i * 30 - 90)
        x1, y1, x2, y2 = (32 + math.cos(a) * 7.5, 32 + math.sin(a) * 7.5, 32 + math.cos(a) * 15.5, 32 + math.sin(a) * 15.5)
        glow = ""
        if e.glow and atras <= 3:
            glow = (f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="{cor}" stroke-width="5" '
                    f'stroke-linecap="butt" opacity="{op * 0.9:.2f}" filter="url(#glow)"/>')
        marcas.append(glow + f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="{cor}" stroke-width="3.4" '
                      f'stroke-linecap="butt" opacity="{op:.2f}"/>')
    return o + "".join(marcas)


def espera_completa(p, k):
    return espera(p, k) + p.solido(cantoneiras(), p.e.det if p.e.id != "minimo" else p.e.fill)


def progresso(p, k):
    tr = "translate(48 47) scale(0.58) translate(-32 -32)"
    return seta(p, ARROW_TR) + f'<g transform="{tr}">' + espera(p, k) + "</g>"


# nome -> (função(p) ou função(p, k), hotspot na grade, animação: None ou (quadros, atrasos em ms))
def catalogo(est=None):
    cat = _catalogo()
    if est is not None and est.id == "mira":
        cat["default"] = (mira_fina, (32, 32), None)
        cat["pointer"] = (mao_colchetes, (28, 13), FECHA)
    return cat


def _catalogo():
    return {
        "default": (lambda p: seta(p), (8, 6), None),
        "pointer": (mao_pontar, (25, 6), None),
        "text": (lambda p: ibeam(p), (32, 32), None),
        "vertical-text": (lambda p: ibeam(p, 90), (32, 32), None),
        "wait": (espera_completa, (32, 32), GIRO),
        "progress": (progresso, (8, 6), GIRO),
        "size_hor": (lambda p: duplo(p, 0), (32, 32), None),
        "size_ver": (lambda p: duplo(p, 90), (32, 32), None),
        "size_bdiag": (lambda p: duplo(p, -45), (32, 32), None),
        "size_fdiag": (lambda p: duplo(p, 45), (32, 32), None),
        "col-resize": (lambda p: divisor(p, 0), (32, 32), None),
        "row-resize": (lambda p: divisor(p, 90), (32, 32), None),
        "fleur": (mover4, (32, 32), None),
        "not-allowed": (proibido, (32, 32), None),
        "no-drop": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_proibido(p)), (8, 6), None),
        "crosshair": (mira, (32, 32), None),
        "help": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_ajuda(p)), (8, 6), None),
        "alias": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_link(p)), (8, 6), None),
        "copy": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_mais(p)), (8, 6), None),
        "dnd-move": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_mover(p)), (8, 6), None),
        "context-menu": (lambda p: seta(p, ARROW_TR) + selo(p, glifo_menu(p)), (8, 6), None),
        "cell": (celula, (32, 32), None),
        "x-cursor": (xis, (32, 32), None),
        "color-picker": (pipeta, (9, 57), None),
        "pencil": (lapis, (9, 57), None),
        "zoom-in": (lambda p: lupa(p, True), (26, 26), None),
        "zoom-out": (lambda p: lupa(p, None), (26, 26), None),
        "openhand": (mao_aberta, (32, 32), None),
        "closedhand": (mao_fechada, (32, 32), None),
        "up-arrow": (lambda p: seta_dir(p, 0), (32, 5), None),
        "right-arrow": (lambda p: seta_dir(p, 90), (59, 32), None),
        "down-arrow": (lambda p: seta_dir(p, 180), (32, 59), None),
        "left-arrow": (lambda p: seta_dir(p, -90), (5, 32), None),
        "right_ptr": (lambda p: seta(p, "translate(64 0) scale(-1 1)"), (56, 6), None),
        "center_ptr": (lambda p: seta(p, "translate(24 0) rotate(25 8 6)"), (32, 6), None),
    }


# nome -> nome do arquivo real (as listas do Breeze: X11, CSS, Qt, Wayland e os nomes com hash do Xcursor)
LINKS = {
    "left_ptr": "default", "arrow": "default", "top_left_arrow": "default", "wayland-cursor": "default",
    "size-bdiag": "default", "size-fdiag": "default", "size-hor": "default", "size-ver": "default",
    "hand1": "pointer", "hand2": "pointer", "pointing_hand": "pointer",
    "9d800788f1b08800ae810202380a0822": "pointer", "e29285e634086352946a0e7090d73106": "pointer",
    "ibeam": "text", "xterm": "text",
    "watch": "wait",
    "left_ptr_watch": "progress", "half-busy": "progress", "00000000000000020006000e7e9ffc3f": "progress",
    "08e8e1c95fe2fc01f976f1e063a24ccd": "progress", "3ecb610c1bf2410f44200f48c40d3599": "progress",
    "e-resize": "size_hor", "w-resize": "size_hor", "ew-resize": "size_hor", "h_double_arrow": "size_hor",
    "sb_h_double_arrow": "size_hor", "left_side": "size_hor", "right_side": "size_hor",
    "n-resize": "size_ver", "s-resize": "size_ver", "ns-resize": "size_ver", "v_double_arrow": "size_ver",
    "sb_v_double_arrow": "size_ver", "top_side": "size_ver", "bottom_side": "size_ver",
    "00008160000006810000408080010102": "size_ver",
    "ne-resize": "size_bdiag", "sw-resize": "size_bdiag", "nesw-resize": "size_bdiag",
    "top_right_corner": "size_bdiag", "bottom_left_corner": "size_bdiag",
    "nw-resize": "size_fdiag", "se-resize": "size_fdiag", "nwse-resize": "size_fdiag",
    "top_left_corner": "size_fdiag", "bottom_right_corner": "size_fdiag",
    "split_h": "col-resize", "split_v": "row-resize",
    "move": "fleur", "size_all": "fleur", "all-scroll": "fleur",
    "circle": "not-allowed", "crossed_circle": "not-allowed", "pirate": "not-allowed",
    "03b6e0fcb3499374a867c041f52298f0": "not-allowed",
    "forbidden": "no-drop", "dnd-no-drop": "no-drop",
    "cross": "crosshair", "tcross": "crosshair",
    "left_ptr_help": "help", "question_arrow": "help", "whats_this": "help",
    "5c6cd98b3f3ebcb1f9c7f1c204630408": "help", "d9ce0ab605698f320427677b458ad60b": "help",
    "link": "alias", "3085a0e285430894940527032f8b26df": "alias", "640fb0e74195791501fd1ed57b41487f": "alias",
    "a2a266d0498c3104214a47bd64ab0fc8": "alias",
    "dnd-copy": "copy", "1081e37283d90000800003c07f3ef6bf": "copy", "6407b0e94181790501fd1e167b474872": "copy",
    "b66166c04f8c3109214a4fbd64a50fc8": "copy",
    "dnd-none": "dnd-move", "4498f0e0c1937ffe01fd06f973665830": "dnd-move", "9081237383d90e509aa00f00170e968f": "dnd-move",
    "fcf21c00b30f7e3f83fe0dfd12e71cff": "dnd-move",
    "plus": "cell", "draft": "pencil",
    "grab": "openhand", "grabbing": "closedhand",
}


def renderiza(lote):
    """lote: [(svg, png, tamanho)] -> um único processo do Inkscape (modo shell)."""
    cmds = "".join(f'file-open:{s}; export-filename:{p}; export-width:{n}; export-height:{n}; export-do; file-close\n' for s, p, n in lote)
    r = subprocess.run(["inkscape", "--shell"], input=cmds, text=True, capture_output=True)
    faltam = [p for _, p, _ in lote if not pathlib.Path(p).is_file()]
    if faltam:
        # sem modo shell funcional: um processo por arquivo
        for s, p, n in lote:
            if not pathlib.Path(p).is_file():
                subprocess.run(["inkscape", s, "-o", p, "-w", str(n), "-h", str(n)], check=True, capture_output=True)


def gera_variante(est, saida):
    base = saida / est.id
    if base.exists():
        shutil.rmtree(base)
    svgd, pngd, curd = base / "svg", base / "png", base / "cursors"
    for d in (svgd, curd) + tuple(pngd / str(n) for n in SIZES):
        d.mkdir(parents=True, exist_ok=True)
    p = Pincel(est)
    cat = catalogo(est)
    lote, cfg = [], {}
    for nome, (fn, hot, anim) in cat.items():
        quadros = range(anim[0]) if anim else [None]
        for k in quadros:
            sufixo = "" if k is None else f"_{k:02d}"
            svg = svgd / f"{nome}{sufixo}.svg"
            svg.write_text(doc(est, fn(p) if k is None else fn(p, k)))
            for n in SIZES:
                lote.append((str(svg), str(pngd / str(n) / f"{nome}{sufixo}.png"), n))
    renderiza(lote)
    for nome, (fn, hot, anim) in cat.items():
        linhas = []
        for n in SIZES:
            hx, hy = (min(n - 1, max(0, round(v * n / G))) for v in hot)
            if anim:
                for k in range(anim[0]):
                    linhas.append(f"{n} {hx} {hy} png/{n}/{nome}_{k:02d}.png {anim[1][k]}")
            else:
                linhas.append(f"{n} {hx} {hy} png/{n}/{nome}.png")
        conf = base / f"{nome}.cfg"
        conf.write_text("\n".join(linhas) + "\n")
        subprocess.run(["xcursorgen", conf.name, f"cursors/{nome}"], check=True, cwd=base)  # caminhos relativos: o xcursorgen não lê espaços
        conf.unlink()
    for alias, alvo in LINKS.items():
        assert alvo in cat, alvo
        (curd / alias).symlink_to(alvo)
    tema = base / "theme"
    tema.mkdir()
    shutil.move(str(curd), str(tema / "cursors"))
    (tema / "index.theme").write_text(
        f"[Icon Theme]\nName={est.nome}\nComment=Cursores do tema CyberKDE ({est.id}): seta chanfrada, cantoneiras e destaque do tema\n"
        "Inherits=breeze_cursors\n")
    return base


# ---------------------------------------------------------------- prévia
def quadro_previa(anim):
    """Quadro mostrado na prancha: o do meio do giro, ou o último (firme) dos colchetes."""
    if not anim:
        return None
    return 3 if anim is GIRO else anim[0] - 1


def previa(est, base, destino):
    from PIL import Image, ImageDraw, ImageFont
    cat = catalogo(est)
    fonte = None
    for f in ("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if pathlib.Path(f).is_file():
            fonte = ImageFont.truetype(f, 13)
            break
    fonte = fonte or ImageFont.load_default()
    nomes = list(cat)
    colunas, cw, ch = 8, 132, 134
    linhas = math.ceil(len(nomes) / colunas)
    fundo = mix("#000000", BASE, 0.35)
    claro = "#E6E6EC"
    extra = [n for n in nomes if cat[n][2] and cat[n][2] is not GIRO]
    W, H = colunas * cw, linhas * ch + 150 + (110 if extra else 0)
    im = Image.new("RGB", (W, H), fundo)
    d = ImageDraw.Draw(im)

    def abre(nome, n, k=None):
        suf = "" if k is None else f"_{k:02d}"
        return Image.open(base / "png" / str(n) / f"{nome}{suf}.png").convert("RGBA")
    for i, nome in enumerate(nomes):
        x, y = (i % colunas) * cw, (i // colunas) * ch
        k = quadro_previa(cat[nome][2])
        g = abre(nome, 64, k)
        im.paste(g, (x + (cw - 64) // 2, y + 10), g)
        for j, n in enumerate((24, 32)):
            s = abre(nome, n, k)
            im.paste(s, (x + 38 + j * 34, y + 84), s)
        d.text((x + cw // 2, y + ch - 10), nome, fill="#A9A9BA", font=fonte, anchor="mm")
    # faixa de teste sobre fundos claros e médios
    y0 = linhas * ch + 6
    teste = ["default", "pointer", "text", "wait", "not-allowed", "crosshair", "help", "size_fdiag"]
    for j, cor in enumerate((claro, "#8A8A96")):
        d.rectangle([0, y0 + j * 70, W, y0 + j * 70 + 68], fill=cor)
        for i, nome in enumerate(teste):
            k = quadro_previa(cat[nome][2])
            for q, n in enumerate((32, 48)):
                g = abre(nome, n, k)
                im.paste(g, (i * cw + 14 + q * 56, y0 + j * 70 + 10), g)
    if extra:  # animações curtas (colchetes): todos os quadros, do aberto ao firme
        yq = linhas * ch + 150
        for i, nome in enumerate(extra):
            anim = cat[nome][2]
            for k in range(anim[0]):
                g = abre(nome, 64, k)
                im.paste(g, (14 + (i * 4 + k) * 74, yq + 6), g)
            d.text((14, yq + 88), f"{nome}: quadros 1 a {anim[0]} ({'+'.join(str(x) for x in anim[1][:-1])} ms e o último fica)", fill="#A9A9BA", font=fonte, anchor="lm")
    d.text((10, H - 8), f"{est.nome} — 24/32/48/64 px; faixas de baixo: legibilidade em fundo claro e médio", fill="#A9A9BA", font=fonte, anchor="lm")
    destino.mkdir(parents=True, exist_ok=True)
    im.save(destino / f"{est.id}.png", optimize=True)


def carimbo():
    """Muda quando muda a paleta (cyberkde cor/corp) ou este gerador: o phase.sh só regera então."""
    import hashlib
    h = hashlib.sha256(" ".join((RED, CYAN, BASE, TXT1)).encode())
    h.update(pathlib.Path(__file__).read_bytes())
    return h.hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--carimbo", action="store_true", help="só imprime o carimbo da paleta e do gerador")
    ap.add_argument("--saida", default=str(HERE.parent / "build"))
    ap.add_argument("--variantes", default=",".join(ESTILOS))
    ap.add_argument("--previas", default="")
    a = ap.parse_args()
    if a.carimbo:
        print(carimbo())
        return
    saida = pathlib.Path(a.saida)
    for vid in a.variantes.split(","):
        est = ESTILOS[vid]
        base = gera_variante(est, saida)
        if a.previas:
            previa(est, base, pathlib.Path(a.previas))
        print(f"{vid}: {base / 'theme'}")
    (saida / ".carimbo").write_text(carimbo() + "\n")


if __name__ == "__main__":
    main()
