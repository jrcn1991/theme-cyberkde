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


PREFS = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "cyberkde"


def _hex(value):
    """"#RRGGBB" em maiúsculas, ou "" se o valor não for uma cor."""
    value = str(value or "").strip().lstrip("#")
    if len(value) == 6 and all(c in "0123456789abcdefABCDEF" for c in value):
        return "#" + value.upper()
    return ""


def _accent():
    """Cor de destaque: CYBERKDE_COR, ou ~/.config/cyberkde/cor (gravado por "cyberkde cor"), ou o
    vermelho do documento. Valor inválido cai no padrão."""
    value = os.environ.get("CYBERKDE_COR", "")
    if not value:
        saved = PREFS / "cor"
        value = saved.read_text() if saved.is_file() else ""
    return _hex(value) or TOK["reference"]["red"]


def _paleta():
    """Secundária, alerta e fundo da corporação ("cyberkde corp", tokens/corporacoes.json):
    CYBERKDE_COR2, CYBERKDE_ALERTA e CYBERKDE_FUNDO, ou ~/.config/cyberkde/paleta (JSON com as chaves
    "secundaria", "alerta" e "fundo"), ou os do documento. Valor ausente ou inválido cai no padrão,
    então sem nada configurado o tema sai igual ao de sempre."""
    saved = {}
    try:
        saved = json.loads((PREFS / "paleta").read_text())
    except (OSError, ValueError):
        pass
    if not isinstance(saved, dict):
        saved = {}

    def pega(env, chave, padrao):
        return _hex(os.environ.get(env, "")) or _hex(saved.get(chave)) or padrao
    ref = TOK["reference"]
    return (pega("CYBERKDE_COR2", "secundaria", ref["cyan"]), pega("CYBERKDE_ALERTA", "alerta", ref["red"]),
            pega("CYBERKDE_FUNDO", "fundo", ref["darkestBlue"]))


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


def _tingir(fundo):
    """Leva as superfícies escuras (e o que é desenhado nelas: filete neutro, texto sobre o destaque,
    contorno de controle) para o matiz do fundo da corporação. Desloca cada uma pela diferença entre o
    fundo pedido e o #0E0E17 do documento: é um matiz sutil, a luminosidade quase não muda. Se o
    texto secundário perdesse contraste sobre a superfície mais clara, o deslocamento cai pela metade
    até voltar (o fundo é só um tom; a leitura vem antes). Grava em TOK, para quem lê os tokens direto.
    Devolve a função que desloca uma cor (a identidade com o fundo padrão: aí nada muda)."""
    ref = TOK["reference"]["darkestBlue"]
    if fundo.upper() == ref.upper():
        return lambda c: c
    delta = [f - b for f, b in zip(rgb(fundo), rgb(ref))]
    alvo = contraste(TOK["text"]["secondary"], TOK["surface"]["raised"])
    for _ in range(6):
        if contraste(TOK["text"]["secondary"], hexc([v + d for v, d in zip(rgb(TOK["surface"]["raised"]), delta)])) >= alvo * 0.95:
            break
        delta = [d / 2 for d in delta]

    def mover(c):
        return hexc([v + d for v, d in zip(rgb(c), delta)])
    for k, v in TOK["surface"].items():
        TOK["surface"][k] = mover(v)
    TOK["line"]["neutral"] = mover(TOK["line"]["neutral"])
    TOK["text"]["onRed"] = mover(TOK["text"]["onRed"])
    TOK["reference"]["darkestBlue"] = mover(ref)
    return mover


# Paleta da corporação: aplicada nos tokens ANTES de derivar as cores abaixo (o _legivel mede contra a
# superfície já tingida). Com a paleta padrão nada aqui muda.
SECUNDARIA_PEDIDA, ALERTA_PEDIDO, FUNDO = _paleta()
_no_fundo = _tingir(FUNDO)

# Metadados comuns a todos os pacotes do tema (loja do KDE, SDDM, Aurorae, Kvantum, efeitos…).
AUTHOR = "Rafael Neves"
LICENSE = "GPL-3.0-or-later"
WEBSITE = "https://github.com/jrcn1991/theme-cyberkde"
VERSION = "1.0"

DANGER = TOK["reference"]["red"]  # vermelho ANSI do terminal: sempre vermelho, qualquer que seja a paleta
RED_PEDIDO = _accent()            # o que foi pedido em "cyberkde cor"
RED = _legivel(RED_PEDIDO)        # o mesmo tom, clareado se não lesse sobre o tema
# Alerta (erros na interface: fechar janela, senha errada, texto "negativo"): o da corporação. Na
# Arasaka o destaque já é vermelho, e o alerta laranja não se confunde com ele.
ALERTA = _legivel(ALERTA_PEDIDO)
# Secundária: o ciano do tema inteiro (foco, dados, links, cursor), trocado pela da corporação.
CYAN = _legivel(SECUNDARIA_PEDIDA)
TOK["reference"]["cyan"] = TOK["focus"]["ring"] = CYAN
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
# Texto sobre a seleção (fundo = destaque). Branco, como no documento, enquanto ler (3:1, o mínimo
# para controles; o vermelho padrão dá 3,4:1); com destaque claro (amarelo, verde, prata: 1,1 a 1,6:1)
# o branco some, e vale o texto escuro, o mesmo que já vai sobre o destaque nos botões.
ONSEL = TOK["text"]["onSelection"] if contraste(TOK["text"]["onSelection"], RED) >= 3 else ONRED
LINE = TOK["line"]["neutral"]
BRAND = TOK["line"]["brandOpacity"]
HOV = TOK["fill"]["hoverOpacity"]
SEL = TOK["fill"]["selectedOpacity"]
PRS = TOK["fill"]["pressedOpacity"]
GOLD = TOK["secondary"]["gold"]
GREEN = TOK["secondary"]["green"]
VISITED = "#B46CFA"  # violeta publicado clareado para ler sobre fundo escuro
CONTROL_LINE = _no_fundo("#6B6B7B")  # contorno de controle com contraste >= 3:1 sobre panel
RED_LIGHT = mix(WHITE, RED, 0.18)
CH = TOK["geometry"]


def P(color, a=1.0):
    return (color, a)


# ---------------------------------------------------------------- recolorir imagens
# Imagens desenhadas em vermelho (ícones da IA, papéis de parede) viram a cor de destaque. Cada pixel é
# descrito como escuro + k·(vermelho − escuro) + w·(branco − vermelho): k é o quanto de vermelho ele tem,
# w o quanto do vermelho foi clareado para o branco (realces, cantos brilhantes). O pixel é redesenhado
# com os mesmos k e w sobre a cor nova. O que fica longe desse plano (trilho cinza, filete ciano, texto)
# não muda. O clareado só vale por cima do vermelho (w <= k): sem isso, o ciano (quase todo "branco
# − vermelho") viraria magenta.
MASTER_DARK = "#11101B"   # escuro dos desenhos (painel dos ícones, fundo dos papéis de parede)
CACHE = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache") / "cyberkde"


def recolor(src, dst, color, master=None):
    """Troca o vermelho `master` (padrão: o vermelho do documento) de `src` por `color` e grava `dst`.
    Com numpy e Pillow, usa o plano escuro/vermelho/branco; sem eles, só a linha escuro→vermelho,
    pelo ImageMagick (os realces clareados ficam avermelhados, mas o tema funciona do mesmo jeito)."""
    master = master or TOK["reference"]["red"]
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        return _recolor_magick(src, dst, color, master)
    D, R, T = (np.array(rgb(c), dtype=np.float32) / 255 for c in (MASTER_DARK, master, color))
    W = np.ones(3, dtype=np.float32)
    img = Image.open(src)
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255
    p = (a[..., :3] - D).reshape(-1, 3).T
    base = np.stack([R - D, W - R], 1)
    (k, w), *_ = np.linalg.lstsq(base, p, rcond=None)
    so_linha = (w < 0) | (w > k)
    k = np.clip(np.where(so_linha, (R - D) @ p / ((R - D) @ (R - D)), k), 0, None)
    w = np.where(so_linha, 0, w)
    res = np.linalg.norm(p - base @ np.stack([k, w]), axis=0)
    novo = np.clip(D[:, None] + k * (T - D)[:, None] + w * (W - T)[:, None], 0, 1)
    # Peso: 1 no plano, cai a 0 com a distância (bordas suaves); pixel sem vermelho (k ~ 0) não muda.
    m = np.clip(1 - (res - 0.16) / 0.08, 0, 1) * np.clip(k / 0.05, 0, 1)
    rgb_novo = (p + D[:, None]) * (1 - m) + novo * m
    a[..., :3] = rgb_novo.T.reshape(a.shape[:2] + (3,))
    out = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA")
    (out if img.mode == "RGBA" or "transparency" in img.info else out.convert("RGB")).save(dst)


def _recolor_magick(src, dst, color, master):
    import shutil
    import subprocess
    (rr, rg, rb), (dr, dg, db), (tr, tg, tb) = ([v / 255 for v in rgb(c)] for c in (master, MASTER_DARK, color))
    fx = (f"kk=max(0,min(1,(u.r-{dr:.4f})/{rr - dr:.4f})); "
          f"qg={dg:.4f}+kk*{rg - dg:.4f}; qb={db:.4f}+kk*{rb - db:.4f}; "
          f"(abs(u.g-qg)<0.09 && abs(u.b-qb)<0.09) ? "
          f"channel({dr:.4f}+kk*{tr - dr:.4f}, {dg:.4f}+kk*{tg - dg:.4f}, {db:.4f}+kk*{tb - db:.4f}, 0) : u")
    magick = ["magick"] if shutil.which("magick") else ["convert"]
    subprocess.run([*magick, str(src), "-channel", "RGB", "-fx", fx, "+channel", str(dst)], check=True)


def accented(src, master=None):
    """`src` na cor de destaque atual: o próprio arquivo com a cor padrão; senão, uma cópia recolorida
    em ~/.cache/cyberkde (por cor e por versão do arquivo, para a próxima troca não refazer)."""
    src = pathlib.Path(src)
    if RED.upper() == TOK["reference"]["red"].upper():
        return src
    out = CACHE / f"cor-{RED.lstrip('#')}" / f"{src.stem}-{int(src.stat().st_mtime)}{src.suffix}"
    if not out.exists():
        out.parent.mkdir(parents=True, exist_ok=True)
        tmp = out.with_name(f".{out.name}.{os.getpid()}{out.suffix}")  # outro processo não lê pela metade
        recolor(src, tmp, RED, master)
        tmp.replace(out)
    return out


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


# ---------------------------------------------------------------- estilo de interface
# Opções de forma dos geradores (docs/interno/catalogo-interface.md), escolhidas com "cyberkde efeito
# estilo-*" (modules/estilo). Ficam em ~/.config/cyberkde/estilo (JSON plano: {"selecao": "bloco", ...});
# CYBERKDE_ESTILO_<CHAVE> (ex.: CYBERKDE_ESTILO_SELECAO=bloco) vale por cima, para testes. Chave ausente
# ou valor inválido = o primeiro valor da lista, que é o desenho de sempre: sem nada configurado, a
# saída dos geradores é idêntica à de antes das opções.
ESTILO_VALORES = {
    "selecao": ("marcador", "bloco", "colchetes", "sublinhado"),  # V17 seleção em listas e menus
    "brilho": ("off", "suave", "neon"),                            # V4 sombra da janela ativa e dos popups
    "corte": ("canto", "oposto", "topo", "octogono", "reto"),       # V1 cantos chanfrados
    "tamanho": ("padrao", "pequeno", "largo"),                     # V1 tamanho dos chanfros
    "densidade": ("padrao", "compacto", "espacoso"),               # V32 margens e espaçamentos
    "abas": ("moldura", "sublinhada", "bloco", "cartao"),          # V10
    "progresso": ("segmentada", "hachurada", "pontos", "lisa"),    # V24 (Kvantum e Plasma)
    "marcador": ("cheio", "parcial", "topo", "nenhum"),            # V3 faixa de identidade
    "moldura": ("contorno", "cantoneira", "misto"),                # V2 popups, dicas e grupos
    "foco": ("anel", "cantoneira", "grosso"),                      # V34 anel de foco
    "pecas": ("breeze", "cyberkde"),                               # chave, slider, marcas e ocupado do Plasma
    "textura": ("lisa", "grade", "scanline"),                      # V30 fundo do Konsole e dos popups
    "textura_onde": ("ambos", "konsole", "popups"),
    "konsole_abas": ("padrao", "tecnico"),                         # V21 título das abas do Konsole
    "dica": ("chanfro", "faixa", "marcador", "cantoneira"),        # V28
    "campos": ("caixa", "sublinhado", "bloco"),                    # V15 campos de texto
    "atencao": ("dourado", "laranja"),                             # V33 cores de estado
    "sucesso": ("verde", "ciano"),
    "perigo": ("alerta", "magenta", "vermelho"),
}


def _estilo():
    """(valores resolvidos, chaves definidas pela pessoa)."""
    salvo = {}
    try:
        salvo = json.loads((PREFS / "estilo").read_text())
    except (OSError, ValueError):
        pass
    if not isinstance(salvo, dict):
        salvo = {}
    valores, definidas = {}, set()
    for chave, opcoes in ESTILO_VALORES.items():
        v = os.environ.get("CYBERKDE_ESTILO_" + chave.upper()) or salvo.get(chave)
        if v in opcoes:
            valores[chave] = v
            definidas.add(chave)
        else:
            valores[chave] = opcoes[0]
    return valores, definidas


ESTILO, ESTILO_DEFINIDO = _estilo()

# V1: tamanho dos chanfros. Os três do documento (4, 6, 12) viram 3/4/8 ou 6/8/16.
_TAMANHOS = {"pequeno": {4: 3, 6: 4, 12: 8}, "largo": {4: 6, 6: 8, 12: 16}}


def tam(c):
    """Chanfro c no tamanho escolhido (o próprio c no padrão)."""
    t = _TAMANHOS.get(ESTILO["tamanho"])
    if not t:
        return c
    return t.get(c, round(c * (0.67 if ESTILO["tamanho"] == "pequeno" else 1.33)))


def corte(c, so=None):
    """Cantos chanfrados de uma peça, conforme o corte escolhido, com o chanfro c já no tamanho final.
    `so`: só os cantos desse conjunto (ex.: "tl tr" para um cabeçalho que encosta no alto)."""
    cantos = {"canto": ("br",), "oposto": ("tl", "br"), "topo": ("tr",),
              "octogono": ("tl", "tr", "bl", "br"), "reto": ()}[ESTILO["corte"]]
    return {k: c for k in cantos if so is None or k in so.split()}


def dens(v):
    """Medida de espaçamento na densidade escolhida (a própria no padrão)."""
    f = {"compacto": 0.67, "espacoso": 1.5}.get(ESTILO["densidade"])
    return v if f is None else max(0, round(v * f))


# V33: cores de estado (negativo = erro/perigo, neutro = atenção, positivo = sucesso). O padrão é o de
# sempre: alerta da corporação, dourado e verde.
NEGATIVO = {"alerta": ALERTA, "magenta": _legivel("#FF3EA5"), "vermelho": _legivel("#FF4040")}[ESTILO["perigo"]]
NEUTRO = {"dourado": GOLD, "laranja": TOK["secondary"]["orange"]}[ESTILO["atencao"]]
POSITIVO = {"verde": GREEN, "ciano": CYAN}[ESTILO["sucesso"]]

# V4: cor e força da sombra da moldura ativa: (cor, força, núcleo claro de 1 px).
BRILHO = {"off": ("#000000", None, None), "suave": (RED, 0.20, None),
          "neon": (RED, 0.42, mix(WHITE, RED, 0.25))}[ESTILO["brilho"]]
