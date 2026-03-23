#!/usr/bin/env python3
"""Gera o tema de área de trabalho do Plasma "CyberKDE" e empacota o efeito KWin "cyberkde_popups".

Saída (recriável) em modules/plasma/build/:
  desktoptheme/CyberKDE/          metadata.json, plasmarc, colors e os SVGs (dialogs, widgets e as
                                  variantes translucent/, opaque/ e solid/);
  kwin-effect/cyberkde_popups/    metadata.json, contents/code/main.js e contents/shaders/popup{,_core}.frag.

Regras do FrameSvg (DOCUMENTACAO.md, seção 5):
  * cada canto recebe a largura da borda vertical vizinha e a altura da horizontal, então todo
    chanfro precisa caber nas bordas;
  * sem "hint-stretch-borders" as bordas viram ladrilhos e aparecem pontinhos no filete de 1 px.
Um arquivo do tema substitui o do Breeze inteiro (não há herança por elemento), por isso cada
SVG gerado traz todos os elementos que o QML do Plasma 6.6 procura nele. Os arquivos que não são
gerados aqui caem no tema "default" (Breeze), recoloridos pelo arquivo "colors".

Uso: gen_plasma.py [--check]   (--check compara os nomes de elementos com os do Breeze do sistema)
"""
import gzip
import json
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

MOD = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(MOD.parent.parent / "generator"))
from cyberlib import *  # noqa: E402,F403 — tokens, cores e geometria de chanfro compartilhados
import gen_kvantum  # noqa: E402 — dono do esquema de cores KDE (fonte única do arquivo "colors")

BUILD = MOD / "build"
THEME = BUILD / "desktoptheme" / "CyberKDE"
EFFECT_SRC = MOD / "effect"
EFFECT = BUILD / "kwin-effect" / "cyberkde_popups"
BARRA_SRC = MOD / "effect-barra"                       # barra superior "filete neon"
BARRA = BUILD / "kwin-effect" / "cyberkde_barra"
BREEZE = pathlib.Path("/usr/share/plasma/desktoptheme/default")

FRAME_POS = {"topleft": (0, 0), "top": (1, 0), "topright": (2, 0),
             "left": (0, 1), "center": (1, 1), "right": (2, 1),
             "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2)}

CW, CS, CSM = CH["chamferWide"], CH["chamferStandard"], CH["chamferSmall"]  # 12, 6, 4
MARK = CH["markerWidth"]                                                    # 3
EMPH = CH["lineEmphasis"]                                                   # 2
FOCUS = TOK["focus"]["width"]                                               # 2
ZERO = 0.001  # margem "zero" (como no Breeze): a camada cobre exatamente a peça de baixo

# Superfícies (documento 6.4: predominantemente opacas; leve translucidez só com blur).
DLG_FILL, DLG_LINE = PANEL, mix(RED, PANEL, 0.55)        # popups, menu iniciar, notificações
BAR_FILL, FILET = BASE, mix(RED, BASE, 0.8)              # painel e filete vermelho
TIP_FILL, TIP_LINE = RAISED, mix(RED, RAISED, 0.45)      # dicas
BTN_LINE = mix(RED, RAISED, BRAND)                       # contorno de botão (igual ao Kvantum)
HEAD_FILL = P(RAISED, 0.55)                              # cabeçalho/rodapé dos popups, sobre o fundo
# Opacidade do preenchimento por variante: "" = com blur, translucent/ = composição sem blur,
# opaque/ = sem composição, solid/ = pedido explícito de fundo sólido (painel opaco, dicas QQC2).
VARIANTS = {"": 0.0, "translucent/": 0.04, "opaque/": 1.0, "solid/": 1.0}


def alpha(base, variant):
    return 1.0 if VARIANTS[variant] >= 1 else min(1.0, base + VARIANTS[variant])


# ---------------------------------------------------------------- folha SVG
class Sheet:
    """Folha SVG com as peças do FrameSvg, cada uma um grupo com id e limites fixos."""
    WRAP = 1400

    def __init__(self, source):
        self.source, self.items = source, []
        self.x = self.y = 10
        self.row = self.w = self.h = 0

    def block(self, w, h):
        if self.x > 10 and self.x + w > self.WRAP:
            self.x, self.y, self.row = 10, self.y + self.row + 14, 0
        pos = (self.x, self.y)
        self.x += w + 14
        self.row = max(self.row, h)
        self.w, self.h = max(self.w, pos[0] + w + 10), max(self.h, pos[1] + h + 10)
        return pos

    def add(self, id_, x, y, w, h, parts=()):
        self.items.append(f'<g id="{id_}">{invisible(round(x, 3), round(y, 3), w, h)}{"".join(parts)}</g>')

    def hint(self, id_, w, h):
        x, y = self.block(w, max(h, 1))
        self.add(id_, x, y, w, h)

    def svg(self):
        return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="0 0 {self.w} {self.h}">\n'
                f'<!-- CyberKDE {self.source} — gerado por modules/plasma/generator/gen_plasma.py; '
                f'não editar à mão -->\n' + "\n".join(self.items) + "\n</svg>\n")


# ---------------------------------------------------------------- camadas de uma peça
def edge_inset(outer, labels, sides, d):
    """Desloca para dentro, por d, só as arestas (e chanfros) que tocam os lados em `sides`."""
    return offset_polygon(outer, labels, lambda s: d if any(c in sides for c in s) else 0)


def surface(fill=None, line=None, sides="tblr", bw=1.0, chamfer=None, bands=()):
    """Descreve uma superfície; devolve f(W, H) -> (contorno externo, camadas).

    Camada = (polígono externo, polígono interno ou None, tinta). `bands` são faixas por lado
    (marcador lateral, filete, separador) desenhadas por cima: (lados, largura, tinta).
    """
    def build(W, H):
        outer, labels = outline(0, 0, W, H, chamfer or {})
        layers = []
        inner = edge_inset(outer, labels, sides, bw) if line else outer
        if fill:
            layers.append((inner, None, fill))
        if line:
            layers.append((outer, inner, line))
        for band_sides, width, pnt in bands:
            layers.append((outer, edge_inset(outer, labels, band_sides, width), pnt))
        return outer, layers
    return build


def draw(layers, box, tx, ty):
    out = []
    for outer, inner, pnt in layers:
        o = clip(outer, *box)
        if area(o) <= 1e-6:
            continue
        if inner is None:
            out.append(f'<path d="{sub(o, tx, ty)}" {paint(pnt)}/>')
            continue
        i = clip(inner, *box)
        if area(o) - area(i) <= 1e-6:
            continue
        d = sub(o, tx, ty) + (" " + sub(i, tx, ty) if area(i) > 1e-6 else "")
        out.append(f'<path d="{d}" {paint(pnt)} fill-rule="evenodd"/>')
    return out


def pieces(sheet, prefix, b, layers, M):
    t, r, bo, l = b
    W, H = l + M + r, t + M + bo
    ox, oy = sheet.block(W + 4, H + 4)
    cols, rows = (0, l, l + M, W), (0, t, t + M, H)
    for pos, (ci, ri) in FRAME_POS.items():
        box = (cols[ci], rows[ri], cols[ci + 1], rows[ri + 1])
        tx, ty = ox + ci * 2, oy + ri * 2  # 2 px entre peças: nada vaza na renderização
        name = f"{prefix}-{pos}" if prefix else pos
        sheet.add(name, box[0] + tx, box[1] + ty, box[2] - box[0], box[3] - box[1], draw(layers, box, tx, ty))


def hints(sheet, prefix, kind, m):
    """hint-<lado>-<kind> (margin/inset) com m = (topo, direita, base, esquerda)."""
    pre = f"{prefix}-" if prefix else ""
    top, right, bottom, left = m
    sheet.hint(f"{pre}hint-top-{kind}", 2, top)
    sheet.hint(f"{pre}hint-bottom-{kind}", 2, bottom)
    sheet.hint(f"{pre}hint-left-{kind}", left, 2)
    sheet.hint(f"{pre}hint-right-{kind}", right, 2)


def frame(sheet, prefix, b, look, M=16, margins=None, mask=False):
    """As 9 peças de um prefixo (+ margens, máscara de blur e marca de esticar bordas)."""
    t, r, bo, l = b
    outer, layers = look(l + M + r, t + M + bo)
    pieces(sheet, prefix, b, layers, M)
    if mask:  # região de blur com o chanfro exato
        pieces(sheet, f"mask-{prefix}" if prefix else "mask", b, [(outer, None, P("#000000"))], M)
    if margins:
        hints(sheet, prefix, "margin", margins)
    if prefix:
        sheet.hint(f"{prefix}-hint-stretch-borders", 4, 4)


def shadows(sheet, chamfer, over, spread, strength, M=16, prefix="shadow"):
    """Sombra curta em 9 peças: o KWin a usa nos popups (DialogShadows) e o QML nas dicas (prefixo "shadow").

    over = quanto a peça entra por baixo da janela (cobre o chanfro); spread = alcance para fora.
    """
    win = over * 2 + M
    total = win + 2 * spread
    outer, labels = outline(spread, spread, spread + win, spread + win, chamfer)
    rings, prev = [], outer
    for i in range(1, spread + 1):
        grown = offset_polygon(outer, labels, lambda _, i=i: -i)
        rings.append((grown, prev, P("#000000", strength * (1 - (i - 1) / spread) ** 2)))
        prev = grown
    T = spread + over
    ox, oy = sheet.block(total + 4, total + 4)
    cuts = (0, T, T + M, total)
    for pos, (ci, ri) in FRAME_POS.items():
        box = (cuts[ci], cuts[ri], cuts[ci + 1], cuts[ri + 1])
        tx, ty = ox + ci * 2, oy + ri * 2
        sheet.add(f"{prefix}-{pos}", box[0] + tx, box[1] + ty, box[2] - box[0], box[3] - box[1],
                  draw(rings, box, tx, ty))
    hints(sheet, prefix, "margin", (spread,) * 4)


def ring_chamfer(c, d):
    """Chanfro do contorno externo de um anel de largura d em volta de uma peça com chanfro c."""
    return c + d * (2 - math.sqrt(2))


# ---------------------------------------------------------------- arquivos do tema
def dialog_svg(variant):
    """dialogs/background: popups do Plasma (menu iniciar, calendário, bandeja) e notificações."""
    s = Sheet(f"{variant}dialogs/background")
    look = surface(P(DLG_FILL, alpha(0.94, variant)), P(DLG_LINE), chamfer={"br": CW},
                   bands=[("l", MARK, P(RED))])
    frame(s, "", (CW,) * 4, look, margins=(6, 6, 6, MARK + 6), mask=True)
    shadows(s, {"br": CW}, CW, 10, 0.32)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


PANEL_EDGE = {"north": "b", "south": "t", "west": "r", "east": "l"}  # lado voltado para as janelas
# Os dois cantos do lado voltado para as janelas, chanfrados por igual: numa dock (Latte, largura
# parcial) um só lado chanfrado ficava torto.
PANEL_CUT = {"north": ("bl", "br"), "south": ("tl", "tr"), "west": ("tr", "br"), "east": ("tl", "bl")}


def panel_svg(variant):
    """widgets/panel-background: fundo escuro com filete vermelho de 1 px no lado das janelas."""
    s = Sheet(f"{variant}widgets/panel-background")
    a = alpha(0.90, variant)
    for pre, edge in PANEL_EDGE.items():
        # Sem contorno nos outros lados: numa dock (Latte, largura parcial) a linha clara em volta
        # marcava o fim dela e ficava feia. Só o filete na cor de destaque, do lado das janelas.
        look = surface(P(BAR_FILL, a), P(LINE), sides="",
                       chamfer={c: CSM for c in PANEL_CUT[pre]}, bands=[(edge, 1, P(FILET))])
        frame(s, pre, (4,) * 4, look, margins=(4,) * 4, mask=True)
    # Sem prefixo (painéis de terceiros, Latte em modos sem lado): peça completa e marcador.
    look = surface(P(BAR_FILL, a), P(mix(RED, BASE, BRAND)), chamfer={"br": CS}, bands=[("l", MARK, P(RED))])
    frame(s, "", (CS,) * 4, look, margins=(4,) * 4, mask=True)
    # "thick": só métricas de painéis grossos (Panel.qml), como no Breeze.
    x, y = s.block(32, 32)
    s.add("thick-center", x, y, 32, 32)
    hints(s, "thick", "margin", (8, 8, 8, 8))
    shadows(s, {}, 4, 6, 0.22)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def tooltip_svg(variant):
    """widgets/tooltip: superfície opaca elevada, moldura fina (documento, seção 9)."""
    s = Sheet(f"{variant}widgets/tooltip")
    look = surface(P(TIP_FILL, alpha(0.96, variant)), P(TIP_LINE), chamfer={"br": CS})
    frame(s, "", (CS,) * 4, look, margins=(6, 8, 6, 8), mask=True)
    shadows(s, {"br": CS}, CS, 6, 0.30)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def background_svg(variant):
    """widgets/background: widgets soltos na área de trabalho."""
    s = Sheet(f"{variant}widgets/background")
    look = surface(P(DLG_FILL, alpha(0.92, variant)), P(mix(RED, PANEL, BRAND)), chamfer={"br": CW},
                   bands=[("l", MARK, P(RED))])
    frame(s, "", (CW,) * 4, look, margins=(12, 12, 12, 12 + MARK), mask=True)
    if variant == "translucent/":
        # Widgets com fundo desfocado ("blurred"): mesma peça, e a máscara com o nome que o QML usa.
        frame(s, "blurred", (CW,) * 4, look, margins=(12, 12, 12, 12 + MARK))
        pieces(s, "blurred-mask", (CW,) * 4, [(look(2 * CW + 16, 2 * CW + 16)[0], None, P("#000000"))], 16)
    shadows(s, {"br": CW}, CW, 8, 0.28)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def state(fill=None, line=None, marker=False, chamfer=CSM, bw=1.0, bands=()):
    extra = [("l", MARK, P(RED))] if marker else []
    return surface(fill, line, bw=bw, chamfer={"br": chamfer} if chamfer else None, bands=extra + list(bands))


def viewitem_svg():
    """widgets/viewitem (PlasmaExtras.Highlight: listas do menu iniciar, bandeja, KRunner)."""
    s = Sheet("widgets/viewitem")
    looks = {
        "normal": state(),
        "hover": state(P(RED, HOV), P(RED, 0.22)),                       # hover tonal
        "selected": state(P(RED, SEL), P(RED, 0.45), marker=True),       # marcador vermelho
        "selected+hover": state(P(RED, SEL + 0.06), P(RED, 0.60), marker=True),
    }
    for pre, look in looks.items():  # sem hint de margem: margens = bordas (5 px), como no Breeze
        frame(s, pre, (5,) * 4, look)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def listitem_svg():
    """widgets/listitem (itens de lista antigos do PlasmaExtras e cabeçalhos de seção)."""
    s = Sheet("widgets/listitem")
    looks = {
        "normal": state(),
        "hover": state(P(RED, HOV), P(RED, 0.22)),
        "pressed": state(P(RED, SEL), P(RED, 0.45), marker=True),
        "section": state(chamfer=0, bands=[("b", 1, P(LINE))]),
    }
    for pre, look in looks.items():
        frame(s, pre, (4,) * 4, look, margins=(6,) * 4)
    x, y = s.block(40, 1)
    s.add("separator", x, y, 40, 1, [box(0, 0, 40, 1, LINE)(x, y)])
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def button_svg():
    """widgets/button: botões e botões de ferramenta do PlasmaComponents 3."""
    s = Sheet("widgets/button")
    ring = state(line=P(CYAN), bw=FOCUS, chamfer=ring_chamfer(CSM, FOCUS))  # foco pelo teclado
    frame(s, "normal", (5,) * 4, state(P(RAISED), P(BTN_LINE)), margins=(6,) * 4)
    frame(s, "hover", (5,) * 4, state(P(RED, HOV), P(RED, 0.75)), margins=(ZERO,) * 4)
    frame(s, "pressed", (5,) * 4, state(P(mix(RED, RAISED, PRS)), P(RED)), margins=(6,) * 4)
    frame(s, "focus", (7,) * 4, ring, margins=(FOCUS,) * 4)
    frame(s, "toolbutton-hover", (5,) * 4, state(P(RED, HOV), P(RED, 0.30)), margins=(4,) * 4)
    frame(s, "toolbutton-pressed", (5,) * 4, state(P(RED, 0.28), P(RED, 0.70)), margins=(4,) * 4)
    frame(s, "toolbutton-focus", (7,) * 4, ring, margins=(FOCUS,) * 4)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def lineedit_svg():
    """widgets/lineedit: campos de texto e busca (foco ciano, documento 9)."""
    s = Sheet("widgets/lineedit")
    frame(s, "base", (5,) * 4, state(P(INPUT), P(CONTROL_LINE)), margins=(6,) * 4)
    frame(s, "hover", (5,) * 4, state(line=P(RED, 0.60)), margins=(ZERO,) * 4)
    frame(s, "focus", (5,) * 4, state(line=P(CYAN)), margins=(ZERO,) * 4)
    frame(s, "focusframe", (7,) * 4, state(line=P(CYAN), bw=FOCUS, chamfer=ring_chamfer(CSM, FOCUS)),
          margins=(FOCUS,) * 4)
    s.hint("hint-focus-over-base", 2, 2)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def scrollbar_svg():
    """widgets/scrollbar: barra fina; medidas e recuos iguais aos do Breeze (mesmo layout)."""
    s = Sheet("widgets/scrollbar")
    looks = {"background-vertical": P(TXT1, 0.06), "background-horizontal": P(TXT1, 0.06),
             "slider": P(mix(TXT2, BASE, 0.55)), "mouseover-slider": P(RED)}
    for pre, fill in looks.items():
        frame(s, pre, (3,) * 4, surface(fill), M=3)
        # Recuo de 6 px nos quatro lados (o Breeze usa elementos 6×3 e 3×6): trilha de 6 px num
        # controle de 18 px, com a alça do mesmo tamanho.
        hints(s, pre, "inset", (6,) * 4)
    s.hint("hint-scrollbar-size", 6, 6)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def plasmoidheading_svg():
    """widgets/plasmoidheading: cabeçalho e rodapé dos popups.

    O PlasmoidHeading estende o fundo até as bordas da janela (recuos negativos do tamanho da
    margem do diálogo), por isso as peças repetem o contorno, o marcador e o chanfro do diálogo.
    """
    s = Sheet("widgets/plasmoidheading")
    header = surface(HEAD_FILL, P(DLG_LINE), sides="tr",
                     bands=[("l", MARK, P(RED)), ("b", 1, P(LINE))])
    # Rodapé sem contorno próprio: o fundo recua 1 px da direita, da base e do chanfro, e o contorno
    # que aparece é sempre o do diálogo. Com contorno próprio, as duas molduras discordavam quando o
    # Plasma liga bordas diferentes nelas. No menu do Latte (popup encostado no dock), o chanfro do
    # rodapé ficava por cima da borda direita reta do diálogo, que seguia até o fundo (14/09).
    footer = surface(HEAD_FILL, P(DLG_LINE, 0.0), sides="rb", chamfer={"br": CW},
                     bands=[("l", MARK, P(RED)), ("t", 1, P(LINE))])
    for pre, look in (("header", header), ("footer", footer)):
        frame(s, pre, (CW,) * 4, look, margins=(6,) * 4)
    hints(s, "", "margin", (6,) * 4)  # o Breeze só tem as margens sem prefixo
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


# Aba ativa: faixa de 2 px no lado do conteúdo; margens iguais às do Breeze.
TABS = {"north": ("b", (3, 6, 3, 6), (10, 6, 10, 6)), "south": ("t", (3, 6, 3, 6), (10, 6, 10, 6)),
        "east": ("l", (6, 3, 6, 3), (6, 4, 6, 8)), "west": ("r", (6, 3, 6, 3), (6, 8, 6, 4))}


def tabbar_svg():
    s = Sheet("widgets/tabbar")
    for side, (edge, b, m) in TABS.items():
        frame(s, f"{side}-active-tab", b, surface(P(RED, HOV), bands=[(edge, EMPH, P(RED))]), margins=m)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def frame_svg():
    """widgets/frame: molduras plain/raised/sunken usadas por alguns widgets."""
    s = Sheet("widgets/frame")
    frame(s, "plain", (4,) * 4, state(line=P(LINE)), margins=(6,) * 4)
    frame(s, "raised", (4,) * 4, state(P(RAISED), P(LINE)), margins=(6, 6, 8, 6))
    frame(s, "sunken", (4,) * 4, state(P(INPUT), P(LINE)), margins=(6,) * 4)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def line_svg():
    s = Sheet("widgets/line")
    for id_, w, h in (("horizontal-line", 8, 1), ("vertical-line", 1, 8)):
        x, y = s.block(w, h)
        s.add(id_, x, y, w, h, [box(0, 0, w, h, LINE)(x, y)])
    return s.svg()


def bar_meter_svg():
    """widgets/bar_meter_horizontal: barra de progresso (bateria, volume, cópia de arquivos)."""
    s = Sheet("widgets/bar_meter_horizontal")
    frame(s, "bar-inactive", (3,) * 4, surface(P(INPUT), P(LINE)), M=6)
    frame(s, "bar-active", (3,) * 4, surface(P(RED)), M=6)
    s.hint("hint-bar-size", 6, 6)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def files():
    out = {}
    for v in VARIANTS:
        out[f"{v}dialogs/background.svg"] = dialog_svg(v)
        out[f"{v}widgets/panel-background.svg"] = panel_svg(v)
        out[f"{v}widgets/tooltip.svg"] = tooltip_svg(v)
        out[f"{v}widgets/background.svg"] = background_svg(v)
    out.update({
        "widgets/viewitem.svg": viewitem_svg(),
        "widgets/listitem.svg": listitem_svg(),
        "widgets/button.svg": button_svg(),
        "widgets/lineedit.svg": lineedit_svg(),
        "widgets/scrollbar.svg": scrollbar_svg(),
        "widgets/plasmoidheading.svg": plasmoidheading_svg(),
        "widgets/tabbar.svg": tabbar_svg(),
        "widgets/frame.svg": frame_svg(),
        "widgets/line.svg": line_svg(),
        "widgets/bar_meter_horizontal.svg": bar_meter_svg(),
    })
    return out


METADATA = {
    "KPlugin": {
        "Id": "CyberKDE",
        "Name": "CyberKDE",
        "Description": "Neo-military Plasma style: panel with an accent rule, chamfered popups with a side "
                       "marker, marker-style selection and cyan focus.",
        "Description[pt_BR]": "Estilo neomilitar do Plasma: painel com filete na cor de destaque, popups "
                              "chanfrados com marcador lateral, seleção com marcador e foco ciano.",
        "Authors": [{"Name": AUTHOR}],
        "License": LICENSE,
        "Version": VERSION,
        "Website": WEBSITE,
    },
    "X-Plasma-API-Minimum-Version": "6.0",
}

# Contraste do KWin desligado: ele satura o que está atrás dos popups e mudaria as cores dos tokens.
PLASMARC = """[ContrastEffect]
enabled=false

[BlurBehindEffect]
enabled=true

[AdaptiveTransparency]
enabled=true
"""


def colors():
    body = gen_kvantum.COLORS.split("\n", 1)[1]  # tira o cabeçalho do gen_kvantum
    return ("# CyberKDE (tema do Plasma) — esquema de generator/gen_kvantum.py a partir de tokens/cyberkde.json,\n"
            "# gravado por modules/plasma/generator/gen_plasma.py; não editar à mão.\n" + body)


# ---------------------------------------------------------------- efeito KWin
# Mesmo cabeçalho que o `cyberkde install` usa no cyberkde_scan (GLSL 1.40 e legado).
FRAG_CORE = '#version 140\n#include "colormanagement.glsl"\n#define TEX texture\nin vec2 texcoord0;\nout vec4 fragColor;\n\n'
FRAG_LEGACY = '#include "colormanagement.glsl"\n#define TEX texture2D\n#define fragColor gl_FragColor\nvarying vec2 texcoord0;\n\n'


def effect_tokens():
    m = TOK["motion"]
    return {"micro": m["micro"], "fast": m["fast"], "standard": m["standard"], "close": m["close"],
            "red": RED, "cyan": CYAN, "surface": BASE}


def build_effect():
    js = (EFFECT_SRC / "main.js").read_text()
    block = "const TOKENS = " + json.dumps(effect_tokens(), indent=4) + ";"
    js, n = re.subn(r"(// @tokens-begin[^\n]*\n).*?(\n// @tokens-end)",
                    lambda mt: mt.group(1) + block + mt.group(2), js, flags=re.S)
    if n != 1:
        sys.exit("gen_plasma: marcadores // @tokens-begin/end não encontrados em effect/main.js")
    shader = (EFFECT_SRC / "shader.glsl").read_text()
    (EFFECT / "contents" / "code").mkdir(parents=True, exist_ok=True)
    (EFFECT / "contents" / "shaders").mkdir(parents=True, exist_ok=True)
    (EFFECT / "metadata.json").write_text((EFFECT_SRC / "metadata.json").read_text())
    (EFFECT / "contents" / "code" / "main.js").write_text(js)
    # O KWin escolhe popup_core.frag (GLSL 1.40) ou popup.frag (legado) conforme o contexto OpenGL.
    (EFFECT / "contents" / "shaders" / "popup_core.frag").write_text(FRAG_CORE + shader)
    (EFFECT / "contents" / "shaders" / "popup.frag").write_text(FRAG_LEGACY + shader)

    # Barra superior ("filete neon"): mesmo esquema, com a cor de destaque atual.
    js = (BARRA_SRC / "main.js").read_text()
    block = "const TOKENS = " + json.dumps({"accent": RED}, indent=4) + ";"
    js, n = re.subn(r"(// @tokens-begin[^\n]*\n).*?(\n// @tokens-end)",
                    lambda mt: mt.group(1) + block + mt.group(2), js, flags=re.S)
    if n != 1:
        sys.exit("gen_plasma: marcadores // @tokens-begin/end não encontrados em effect-barra/main.js")
    shader = (BARRA_SRC / "shader.glsl").read_text()
    (BARRA / "contents" / "code").mkdir(parents=True, exist_ok=True)
    (BARRA / "contents" / "shaders").mkdir(parents=True, exist_ok=True)
    (BARRA / "metadata.json").write_text((BARRA_SRC / "metadata.json").read_text())
    (BARRA / "contents" / "code" / "main.js").write_text(js)
    (BARRA / "contents" / "shaders" / "barra_core.frag").write_text(FRAG_CORE + shader)
    (BARRA / "contents" / "shaders" / "barra.frag").write_text(FRAG_LEGACY + shader)


# ---------------------------------------------------------------- verificação
STRUCT = re.compile(r"^(mask-|shadow-)?([a-z+-]+-)?(top|bottom|left|right|center|topleft|topright|"
                    r"bottomleft|bottomright)$|hint-")


def ids(svg_text):
    return {el.get("id") for el in ET.fromstring(svg_text).iter() if el.get("id")}


# Ausências intencionais: centro esticado (não ladrilhado), dicas privadas, sobras antigas do Breeze,
# e sombra/máscara dos botões (sem elas o botão fica sem sombra, que é o desejado).
IGNORE = re.compile(r"^(hint-tile-center|private-.*|toolbutton-pressed-center|border-bottomleft|"
                    r".*hint-compose-over-border|mask-normal-.*|shadow-.*)$")


def check(generated):
    """Compara os nomes estruturais com os do Breeze: o que o QML procura e não geramos."""
    problems = 0
    for rel, text in generated.items():
        ours = ids(text)
        src = BREEZE / (rel + "z")
        if not src.exists():
            continue
        theirs = {i for i in ids(gzip.decompress(src.read_bytes()).decode()) if STRUCT.search(i)}

        def expected(i):
            if i.endswith("-inset") and "scrollbar" not in rel:
                return False  # recuos zerados do Breeze; o libplasmaquick só lê shadow-hint-*-margin
            if i.startswith("shadow-") and "button" not in rel:
                return True  # a sombra só é dispensável nos botões
            if IGNORE.match(i):
                return False
            return not i.endswith("-inset") or "scrollbar" in rel  # recuos zerados do Breeze
        missing = sorted(i for i in theirs - ours if expected(i))
        if missing:
            problems += 1
            print(f"{rel}: faltam {len(missing)}: {' '.join(missing)}")
    print("check: ok" if not problems else f"check: {problems} arquivo(s) com elementos a revisar")


def main():
    generated = files()
    if THEME.exists():
        for old in THEME.rglob("*.svg"):
            old.unlink()
    for rel, text in generated.items():
        ET.fromstring(text)  # falha cedo se algum SVG sair malformado
        path = THEME / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    (THEME / "metadata.json").write_text(json.dumps(METADATA, indent=4, ensure_ascii=False) + "\n")
    (THEME / "plasmarc").write_text(PLASMARC)
    (THEME / "colors").write_text(colors())
    build_effect()
    print(f"{len(generated)} SVGs → {THEME}; efeito → {EFFECT}")
    if "--check" in sys.argv:
        check(generated)


if __name__ == "__main__":
    main()
