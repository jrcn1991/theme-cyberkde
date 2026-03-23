"""Base compartilhada dos geradores do CyberKDE: tokens, cores e geometria de peças chanfradas."""
import json
import math
import os
import pathlib
from dataclasses import dataclass, field

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOK = json.loads((ROOT / "tokens" / "cyberkde.json").read_text())


# ---------------------------------------------------------------- cores
def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(v))) for v in c)


def mix(fg, bg, a):
    f, b = rgb(fg), rgb(bg)
    return hexc([b[i] + (f[i] - b[i]) * a for i in range(3)])


def _accent():
    """Cor de destaque: CYBERKDE_COR, ou ~/.config/cyberkde/cor (gravado por "cyberkde cor"), ou o
    vermelho do documento. Valor inválido cai no padrão."""
    value = os.environ.get("CYBERKDE_COR", "")
    if not value:
        saved = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "cyberkde" / "cor"
        value = saved.read_text() if saved.is_file() else ""
    value = value.strip().lstrip("#")
    if len(value) == 6 and all(c in "0123456789abcdefABCDEF" for c in value):
        return "#" + value.upper()
    return TOK["reference"]["red"]


MIN_CONTRASTE = 4.5  # WCAG AA para texto normal


def contraste(a, b):
    """Razão de contraste WCAG entre duas cores em hexadecimal."""
    def luz(h):
        def canal(v):
            v /= 255
            return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
        c = rgb(h)
        return 0.2126 * canal(c[0]) + 0.7152 * canal(c[1]) + 0.0722 * canal(c[2])
    x, y = luz(a), luz(b)
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)


def _legivel(cor):
    """Clareia a cor de destaque até ela ler sobre a superfície mais clara do tema E até o texto
    escuro ler sobre ela. Como as superfícies do CyberKDE são todas escuras, quem reprova é cor
    escura: #202030 dá 1,01:1 contra a superfície, ou seja, invisível. A cor PEDIDA continua sendo
    a gravada e a mostrada pelo "cyberkde cor"; esta é só a usada para gerar o tema."""
    fundo, texto = TOK["surface"]["raised"], TOK["text"]["onRed"]
    ajustada, passo = cor, 0.0
    while passo < 1.0:
        if (contraste(ajustada, fundo) >= MIN_CONTRASTE
                and contraste(texto, ajustada) >= MIN_CONTRASTE):
            return ajustada
        passo += 0.02
        ajustada = mix(TOK["reference"]["white"], cor, passo)
    return ajustada  # branco passa nos dois


# Metadados comuns a todos os pacotes do tema (loja do KDE, SDDM, Aurorae, Kvantum, efeitos…).
AUTHOR = "Rafael Neves"
LICENSE = "GPL-3.0-or-later"
WEBSITE = "https://github.com/jrcn1991/theme-cyberkde"
VERSION = "1.0"

DANGER = TOK["reference"]["red"]  # erros e vermelho ANSI: sempre vermelho, qualquer que seja o destaque
RED_PEDIDO = _accent()            # o que foi pedido em "cyberkde cor"
RED = _legivel(RED_PEDIDO)        # o mesmo tom, clareado se não lesse sobre o tema
CYAN = TOK["reference"]["cyan"]
WHITE = TOK["reference"]["white"]
BASE = TOK["surface"]["base"]
PANEL = TOK["surface"]["panel"]
RAISED = TOK["surface"]["raised"]
INPUT = TOK["surface"]["input"]
ALT = TOK["surface"]["alternate"]
TXT1 = TOK["text"]["primary"]
TXT2 = TOK["text"]["secondary"]
TXTD = TOK["text"]["disabled"]
ONRED = TOK["text"]["onRed"]
ONSEL = TOK["text"]["onSelection"]
LINE = TOK["line"]["neutral"]
BRAND = TOK["line"]["brandOpacity"]
HOV = TOK["fill"]["hoverOpacity"]
SEL = TOK["fill"]["selectedOpacity"]
PRS = TOK["fill"]["pressedOpacity"]
GOLD = TOK["secondary"]["gold"]
GREEN = TOK["secondary"]["green"]
VISITED = "#B46CFA"  # violeta publicado clareado para ler sobre fundo escuro
CONTROL_LINE = "#6B6B7B"  # contorno de controle com contraste >= 3:1 sobre panel
RED_LIGHT = mix(WHITE, RED, 0.18)
CH = TOK["geometry"]


def P(color, a=1.0):
    return (color, a)


# ---------------------------------------------------------------- geometria
@dataclass
class Look:
    fill: tuple | None = None
    border: tuple | None = None
    bw: float = 1.0
    sides: str = "tblr"
    chamfer: dict = field(default_factory=dict)  # {"br": 6}
    marker: tuple | None = None  # (paint, lado, largura)
    inset: tuple = (0, 0, 0, 0)  # topo, direita, base, esquerda


def outline(x0, y0, x1, y1, ch):
    """Retângulo chanfrado em sentido horário; devolve (vértices, rótulo da aresta que sai de cada vértice)."""
    pts = []
    c = ch.get("tl", 0)
    pts += [((x0, y0 + c), "tl"), ((x0 + c, y0), "t")] if c else [((x0, y0), "t")]
    c = ch.get("tr", 0)
    pts += [((x1 - c, y0), "tr"), ((x1, y0 + c), "r")] if c else [((x1, y0), "r")]
    c = ch.get("br", 0)
    pts += [((x1, y1 - c), "br"), ((x1 - c, y1), "b")] if c else [((x1, y1), "b")]
    c = ch.get("bl", 0)
    pts += [((x0 + c, y1), "bl"), ((x0, y1 - c), "l")] if c else [((x0, y1), "l")]
    return [p for p, _ in pts], [s for _, s in pts]


def offset_polygon(pts, labels, dist):
    """Desloca cada aresta para dentro por dist(rótulo) (negativo = para fora) e intersecta as vizinhas."""
    n = len(pts)
    lines = []
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        nx, ny = -dy / length, dx / length
        d = dist(labels[i])
        lines.append(((x0 + nx * d, y0 + ny * d), (dx, dy)))
    out = []
    for i in range(n):
        (p, u), (q, v) = lines[i - 1], lines[i]
        den = u[0] * v[1] - u[1] * v[0]
        t = ((q[0] - p[0]) * v[1] - (q[1] - p[1]) * v[0]) / den
        out.append((p[0] + t * u[0], p[1] + t * u[1]))
    return out


def clip(poly, xa, ya, xb, yb):
    """Sutherland–Hodgman contra um retângulo alinhado aos eixos."""
    def ix(a, b, x):
        t = (x - a[0]) / (b[0] - a[0])
        return (x, a[1] + t * (b[1] - a[1]))

    def iy(a, b, y):
        t = (y - a[1]) / (b[1] - a[1])
        return (a[0] + t * (b[0] - a[0]), y)

    tests = (
        (lambda p: p[0] >= xa, lambda a, b: ix(a, b, xa)),
        (lambda p: p[0] <= xb, lambda a, b: ix(a, b, xb)),
        (lambda p: p[1] >= ya, lambda a, b: iy(a, b, ya)),
        (lambda p: p[1] <= yb, lambda a, b: iy(a, b, yb)),
    )
    pts = list(poly)
    for inside, inter in tests:
        if not pts:
            break
        res = []
        for i in range(len(pts)):
            cur, prev = pts[i], pts[i - 1]
            if inside(cur):
                if not inside(prev):
                    res.append(inter(prev, cur))
                res.append(cur)
            elif inside(prev):
                res.append(inter(prev, cur))
        pts = res
    return pts


def area(pts):
    return abs(sum(pts[i - 1][0] * p[1] - p[0] * pts[i - 1][1] for i, p in enumerate(pts))) / 2 if len(pts) > 2 else 0


def rectpoly(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def sub(pts, tx, ty):
    return "M" + " L".join(f"{x + tx:.3f},{y + ty:.3f}" for x, y in pts) + " Z"


def paint(p):
    color, a = p
    return f'fill="{color}"' + (f' fill-opacity="{a:.3f}"' if a < 1 else "")


def shape_svg(outer, inner, fill, border, tx, ty, box=None):
    """Preenchimento (dentro do contorno) + anel do contorno (evenodd), sem sobreposição."""
    out = []
    f = clip(inner, *box) if box else inner
    if fill and area(f) > 1e-6:
        out.append(f'<path d="{sub(f, tx, ty)}" {paint(fill)}/>')
    if border:
        a = clip(outer, *box) if box else outer
        b = clip(inner, *box) if box else inner
        if area(a) - area(b) > 1e-6:
            d = sub(a, tx, ty) + (" " + sub(b, tx, ty) if area(b) > 1e-6 else "")
            out.append(f'<path d="{d}" {paint(border)} fill-rule="evenodd"/>')
    return out


def invisible(x, y, w, h):
    """Retângulo transparente que fixa os limites (bounds) de uma peça SVG."""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000000" fill-opacity="0"/>'


# ---------------------------------------------------------------- formas de ícone (desenhadas em (ox, oy))
def poly(pts, color, a=1.0):
    return lambda ox, oy: f'<path d="{sub(pts, ox, oy)}" {paint(P(color, a))}/>'


def box(x, y, w, h, color, a=1.0):
    return poly(rectpoly(x, y, x + w, y + h), color, a)


def strokes(segments, color, width):
    def f(ox, oy):
        d = " ".join("M" + " L".join(f"{x + ox:.3f},{y + oy:.3f}" for x, y in seg) for seg in segments)
        return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" '
                f'stroke-linecap="square" stroke-linejoin="miter"/>')
    return f


def circle(cx, cy, rad, fill=None, stroke=None, sw=1.0):
    def f(ox, oy):
        fa = f'fill="{fill}"' if fill else 'fill="none"'
        sa = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        return f'<circle cx="{cx + ox}" cy="{cy + oy}" r="{rad}" {fa}{sa}/>'
    return f


def chamfered(w, h, c, fill, border, bw=1.0, x=0, y=0):
    """Forma chanfrada (canto inferior direito) usada em ícones de controle."""
    outer, labels = outline(x, y, x + w, y + h, {"br": c})
    inner = offset_polygon(outer, labels, lambda _: bw) if border else outer
    return lambda ox, oy: "".join(shape_svg(outer, inner, fill, border, ox, oy))
