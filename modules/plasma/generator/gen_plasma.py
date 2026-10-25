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
# Opções de estilo (cyberlib.ESTILO; modules/estilo): sem nenhuma escolhida, tudo sai como sempre.
EST = ESTILO
CW, CS, CSM = tam(CW), tam(CS), tam(CSM)
CORNERS = ("topleft", "topright", "bottomleft", "bottomright")
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


def surface(fill=None, line=None, sides="tblr", bw=1.0, chamfer=None, bands=(), bracket=None, texture=None):
    """Descreve uma superfície; devolve f(W, H) -> (contorno externo, camadas).

    Camada = (polígono externo, polígono interno ou None, tinta[, peças]). `bands` são faixas por lado
    (marcador lateral, filete, separador) desenhadas por cima: (lados, largura, tinta[, peças]); com
    `peças`, a faixa só aparece nessas peças (ex.: marcador parcial só no canto de cima). `bracket` =
    (tinta, largura[, peças]): contorno só nas peças de canto (cantoneiras, opção V2/V34). `texture` =
    função (x0, y0, x1, y1) -> camadas extras do centro (textura V30, com hint-tile-center).
    """
    def build(W, H):
        outer, labels = outline(0, 0, W, H, chamfer or {})
        layers = []
        inner = edge_inset(outer, labels, sides, bw) if line else outer
        if fill:
            layers.append((inner, None, fill))
        if texture:
            layers += texture(W, H)
        if line:
            layers.append((outer, inner, line))
        if bracket:
            pnt, width, *where = bracket
            layers.append((outer, edge_inset(outer, labels, "tblr", width), pnt, where[0] if where else CORNERS))
        for band_sides, width, pnt, *where in bands:
            layers.append((outer, edge_inset(outer, labels, band_sides, width), pnt, *where))
        return outer, layers
    return build


def draw(layers, box, tx, ty, pos=None):
    out = []
    for outer, inner, pnt, *where in layers:
        if where and pos not in where[0]:
            continue
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
    Mw, Mh = M if isinstance(M, tuple) else (M, M)  # miolo retangular: centro em ladrilhos
    W, H = l + Mw + r, t + Mh + bo
    ox, oy = sheet.block(W + 4, H + 4)
    cols, rows = (0, l, l + Mw, W), (0, t, t + Mh, H)
    for pos, (ci, ri) in FRAME_POS.items():
        box = (cols[ci], rows[ri], cols[ci + 1], rows[ri + 1])
        tx, ty = ox + ci * 2, oy + ri * 2  # 2 px entre peças: nada vaza na renderização
        name = f"{prefix}-{pos}" if prefix else pos
        sheet.add(name, box[0] + tx, box[1] + ty, box[2] - box[0], box[3] - box[1], draw(layers, box, tx, ty, pos))


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


def shadows(sheet, chamfer, over, spread, strength, M=16, prefix="shadow", glow=False):
    """Sombra curta em 9 peças: o KWin a usa nos popups (DialogShadows) e o QML nas dicas (prefixo "shadow").

    over = quanto a peça entra por baixo da janela (cobre o chanfro); spread = alcance para fora.
    glow: com a opção "brilho" (V4), a sombra vira um halo na cor de destaque.
    """
    win = over * 2 + M
    total = win + 2 * spread
    outer, labels = outline(spread, spread, spread + win, spread + win, chamfer)
    color, core = "#000000", None
    if glow and BRILHO[1] is not None:
        color, strength, core = BRILHO
    rings, prev = [], outer
    for i in range(1, spread + 1):
        grown = offset_polygon(outer, labels, lambda _, i=i: -i)
        a = strength * (1 - (i - 1) / spread) ** 2
        rings.append((grown, prev, P(core, 0.65) if core and i == 1 else P(color, a)))
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


# ---------------------------------------------------------------- opções de estilo
MARCADOR, MOLDURA, SELECAO = EST["marcador"], EST["moldura"], EST["selecao"]
DCH = corte(CW)          # cantos chanfrados de popups e widgets (V1)
PARCIAL_T = 24           # V3 "parcial": altura do bloco, que vira a borda de cima da peça
TEXTURA = EST["textura"] if EST["textura_onde"] in ("ambos", "popups") else "lisa"


def marcas(tinta=None):
    """Faixas do marcador lateral (V3) dos popups e widgets."""
    tinta = tinta or P(RED)
    return {"cheio": [("l", MARK, tinta)], "parcial": [("l", MARK, tinta, ("topleft",))],
            "topo": [("t", MARK, tinta)], "nenhum": []}[MARCADOR]


def margem_esq():
    return MARK if MARCADOR in ("cheio", "parcial") else 0


def bordas(c):
    """Bordas (topo, direita, base, esquerda) de popup/widget: o "parcial" pede a de cima mais alta."""
    return (max(c, PARCIAL_T) if MARCADOR == "parcial" else c, c, c, c)


def contorno(linha, onde=CORNERS):
    """(linha, cantoneira) da moldura (V2): contorno inteiro, só os cantos, ou filete neutro + cantos."""
    if MOLDURA == "contorno":
        return linha, None
    return (P(LINE) if MOLDURA == "misto" else None), (P(RED), EMPH, onde)


def textura(b):
    """V30: grade (16 px) ou scanline (4 px) a 4% no centro em ladrilhos (hint-tile-center) dos popups."""
    if TEXTURA == "lisa":
        return None
    t, _, _, l = b

    def layers(W, H):
        tinta = P(TXT1, 0.04)
        if TEXTURA == "grade":
            rects = [rectpoly(l, t, l + 16, t + 1), rectpoly(l, t + 1, l + 1, t + 16)]
        else:
            rects = [rectpoly(l, t + y, l + 16, t + y + 1) for y in (0, 4, 8, 12)]
        return [(r, None, tinta, ("center",)) for r in rects]
    return layers


# ---------------------------------------------------------------- arquivos do tema
def dialog_svg(variant):
    """dialogs/background: popups do Plasma (menu iniciar, calendário, bandeja) e notificações."""
    s = Sheet(f"{variant}dialogs/background")
    b = bordas(CW)
    linha, bracket = contorno(P(DLG_LINE))
    look = surface(P(DLG_FILL, alpha(0.94, variant)), linha, chamfer=DCH,
                   bands=marcas(), bracket=bracket, texture=textura(b))
    frame(s, "", b, look, margins=(dens(6), dens(6), dens(6), margem_esq() + dens(6)), mask=True)
    shadows(s, DCH, CW, 10, 0.32, glow=True)
    if TEXTURA != "lisa":
        s.hint("hint-tile-center", 4, 4)
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
    dica, ch = EST["dica"], corte(CS)
    linha, bracket, bands = P(TIP_LINE), None, []
    if dica == "cantoneira":
        linha, bracket = None, (P(RED), EMPH)
    elif dica == "chanfro":
        linha, bracket = contorno(P(TIP_LINE))
    elif dica == "faixa":
        bands = [("t", 3, P(CYAN))]
    else:
        bands = [("l", MARK, P(RED))]
    c = max(CS, 8) if bracket else CS
    look = surface(P(TIP_FILL, alpha(0.96, variant)), linha, chamfer=ch, bands=bands, bracket=bracket)
    frame(s, "", (c,) * 4, look, margins=(dens(6), dens(8), dens(6), dens(8)), mask=True)
    shadows(s, ch, CS, 6, 0.30, glow=True)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def background_svg(variant):
    """widgets/background: widgets soltos na área de trabalho."""
    s = Sheet(f"{variant}widgets/background")
    b = bordas(CW)
    linha, bracket = contorno(P(mix(RED, PANEL, BRAND)))
    look = surface(P(DLG_FILL, alpha(0.92, variant)), linha, chamfer=DCH, bands=marcas(), bracket=bracket)
    m = (dens(12), dens(12), dens(12), dens(12) + margem_esq())
    frame(s, "", b, look, margins=m, mask=True)
    if variant == "translucent/":
        # Widgets com fundo desfocado ("blurred"): mesma peça, e a máscara com o nome que o QML usa.
        frame(s, "blurred", b, look, margins=m)
        pieces(s, "blurred-mask", b, [(look(b[3] + b[1] + 16, b[0] + b[2] + 16)[0], None, P("#000000"))], 16)
    shadows(s, DCH, CW, 8, 0.28, glow=True)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def state(fill=None, line=None, marker=False, chamfer=CSM, bw=1.0, bands=()):
    extra = [("l", MARK, P(RED))] if marker else []
    return surface(fill, line, bw=bw, chamfer=corte(chamfer) if chamfer else None, bands=extra + list(bands))


def selecao(pressed="selected", hover_sel="selected+hover"):
    """Estados de seleção das listas (V17): marcador, bloco, colchetes ou sublinhado."""
    if SELECAO == "marcador":
        return {pressed: state(P(RED, SEL), P(RED, 0.45), marker=True),
                hover_sel: state(P(RED, SEL + 0.06), P(RED, 0.60), marker=True)}
    if SELECAO == "bloco":  # o Plasma não troca a cor do texto na seleção: bloco a 55% para o texto ler
        return {pressed: state(P(RED, 0.55), P(RED)), hover_sel: state(P(RED, 0.65), P(RED))}
    if SELECAO == "colchetes":
        def colch(a):
            return surface(P(RED, a), bands=[("l", 2, P(RED)), ("r", 2, P(RED)),
                                             ("t", 2, P(RED), CORNERS), ("b", 2, P(RED), CORNERS)])
        return {pressed: colch(0.10), hover_sel: colch(0.16)}
    return {pressed: state(P(RED, HOV), bands=[("b", 2, P(RED))]),
            hover_sel: state(P(RED, HOV + 0.06), bands=[("b", 2, P(RED))])}


def viewitem_svg():
    """widgets/viewitem (PlasmaExtras.Highlight: listas do menu iniciar, bandeja, KRunner)."""
    s = Sheet("widgets/viewitem")
    looks = {
        "normal": state(),
        "hover": state(P(RED, HOV), P(RED, 0.22)),                       # hover tonal
        **selecao(),                                                     # marcador vermelho (padrão)
    }
    b = max(5, tam(CSM) + 1)
    for pre, look in looks.items():  # sem hint de margem: margens = bordas (5 px), como no Breeze
        frame(s, pre, (b,) * 4, look)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def listitem_svg():
    """widgets/listitem (itens de lista antigos do PlasmaExtras e cabeçalhos de seção)."""
    s = Sheet("widgets/listitem")
    looks = {
        "normal": state(),
        "hover": state(P(RED, HOV), P(RED, 0.22)),
        "pressed": selecao("pressed", "-")["pressed"],
        "section": state(chamfer=0, bands=[("b", 1, P(LINE))]),
    }
    b = max(4, tam(CSM))
    for pre, look in looks.items():
        frame(s, pre, (b,) * 4, look, margins=(dens(6),) * 4)
    x, y = s.block(40, 1)
    s.add("separator", x, y, 40, 1, [box(0, 0, 40, 1, LINE)(x, y)])
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def focus_ring():
    """Anel de foco pelo teclado (V34): (bordas, margem, superfície)."""
    if EST["foco"] == "grosso":
        return 8, 3, state(line=P(CYAN), bw=3, chamfer=ring_chamfer(CSM, 3))
    if EST["foco"] == "cantoneira":
        return 7, FOCUS, surface(chamfer=corte(ring_chamfer(CSM, FOCUS)), bracket=(P(CYAN), FOCUS))
    return 7, FOCUS, state(line=P(CYAN), bw=FOCUS, chamfer=ring_chamfer(CSM, FOCUS))


def button_svg():
    """widgets/button: botões e botões de ferramenta do PlasmaComponents 3."""
    s = Sheet("widgets/button")
    fb, fm, ring = focus_ring()  # foco pelo teclado
    frame(s, "normal", (5,) * 4, state(P(RAISED), P(BTN_LINE)), margins=(dens(6),) * 4)
    frame(s, "hover", (5,) * 4, state(P(RED, HOV), P(RED, 0.75)), margins=(ZERO,) * 4)
    frame(s, "pressed", (5,) * 4, state(P(mix(RED, RAISED, PRS)), P(RED)), margins=(dens(6),) * 4)
    frame(s, "focus", (fb,) * 4, ring, margins=(fm,) * 4)
    frame(s, "toolbutton-hover", (5,) * 4, state(P(RED, HOV), P(RED, 0.30)), margins=(dens(4),) * 4)
    frame(s, "toolbutton-pressed", (5,) * 4, state(P(RED, 0.28), P(RED, 0.70)), margins=(dens(4),) * 4)
    frame(s, "toolbutton-focus", (fb,) * 4, ring, margins=(fm,) * 4)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def lineedit_svg():
    """widgets/lineedit: campos de texto e busca (foco ciano, documento 9)."""
    s = Sheet("widgets/lineedit")
    ch = corte(CSM)
    if EST["campos"] == "sublinhado":  # V15: só a linha de baixo; foco = linha grossa e lateral ciano
        base = surface(P(INPUT, 0.55), P(CONTROL_LINE), sides="b", chamfer=ch)
        hover = surface(None, P(RED, 0.60), sides="b", chamfer=ch)
        focus = surface(None, P(CYAN), sides="b", bw=2, chamfer=ch, bands=[("l", 2, P(CYAN))])
    elif EST["campos"] == "bloco":     # fundo sem contorno; foco = faixa ciano à esquerda
        base = surface(P(INPUT), chamfer=ch)
        hover = surface(None, chamfer=ch, bands=[("l", 2, P(RED, 0.6))])
        focus = surface(None, chamfer=ch, bands=[("l", 3, P(CYAN))])
    else:
        base, hover, focus = state(P(INPUT), P(CONTROL_LINE)), state(line=P(RED, 0.60)), state(line=P(CYAN))
    fb, fm, ring = focus_ring()
    frame(s, "base", (5,) * 4, base, margins=(dens(6),) * 4)
    frame(s, "hover", (5,) * 4, hover, margins=(ZERO,) * 4)
    frame(s, "focus", (5,) * 4, focus, margins=(ZERO,) * 4)
    frame(s, "focusframe", (fb,) * 4, ring, margins=(fm,) * 4)
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
    # Sem a faixa cheia à esquerda, o contorno do diálogo passa por lá e o cabeçalho também o desenha.
    esq = "" if MARCADOR == "cheio" else "l"
    hline, hbr = contorno(P(DLG_LINE), ("topleft", "topright"))
    header = surface(HEAD_FILL, hline, sides="tr" + esq, chamfer=corte(CW, "tl tr"), bracket=hbr,
                     bands=marcas() + [("b", 1, P(LINE))])
    # Rodapé sem contorno próprio: o fundo recua 1 px da direita, da base e do chanfro, e o contorno
    # que aparece é sempre o do diálogo. Com contorno próprio, as duas molduras discordavam quando o
    # Plasma liga bordas diferentes nelas. No menu do Latte (popup encostado no dock), o chanfro do
    # rodapé ficava por cima da borda direita reta do diálogo, que seguia até o fundo (14/09).
    _, fbr = contorno(P(DLG_LINE), ("bottomleft", "bottomright"))
    footer = surface(HEAD_FILL, P(DLG_LINE, 0.0), sides="rb" + esq, chamfer=corte(CW, "bl br"), bracket=fbr,
                     bands=([("l", MARK, P(RED))] if MARCADOR == "cheio" else []) + [("t", 1, P(LINE))])
    for pre, look, b in (("header", header, bordas(CW)), ("footer", footer, (CW,) * 4)):
        frame(s, pre, b, look, margins=(dens(6),) * 4)
    hints(s, "", "margin", (dens(6),) * 4)  # o Breeze só tem as margens sem prefixo
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


# Aba ativa: faixa de 2 px no lado do conteúdo; margens iguais às do Breeze.
TABS = {"north": ("b", (3, 6, 3, 6), (10, 6, 10, 6)), "south": ("t", (3, 6, 3, 6), (10, 6, 10, 6)),
        "east": ("l", (6, 3, 6, 3), (6, 4, 6, 8)), "west": ("r", (6, 3, 6, 3), (6, 8, 6, 4))}


def tabbar_svg():
    s = Sheet("widgets/tabbar")
    abas = EST["abas"]
    for side, (edge, b, m) in TABS.items():
        if abas == "sublinhada":   # V10: só o traço ciano
            look = surface(P(CYAN, 0.06), bands=[(edge, EMPH, P(CYAN))])
        elif abas == "bloco":      # o Plasma não escurece o texto da aba: bloco a 45%
            look = surface(P(RED, 0.45), bands=[(edge, EMPH, P(RED))])
        elif abas == "cartao":     # contorno nos outros três lados e faixa grossa embaixo
            look = surface(P(RED, HOV), P(mix(RED, PANEL, BRAND)), sides="tblr".replace(edge, ""),
                           bands=[(edge, 3, P(RED))])
        else:
            look = surface(P(RED, HOV), bands=[(edge, EMPH, P(RED))])
        frame(s, f"{side}-active-tab", b, look, margins=m)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def frame_svg():
    """widgets/frame: molduras plain/raised/sunken usadas por alguns widgets."""
    s = Sheet("widgets/frame")
    frame(s, "plain", (4,) * 4, state(line=P(LINE)), margins=(dens(6),) * 4)
    frame(s, "raised", (4,) * 4, state(P(RAISED), P(LINE)), margins=(dens(6), dens(6), dens(8), dens(6)))
    frame(s, "sunken", (4,) * 4, state(P(INPUT), P(LINE)), margins=(dens(6),) * 4)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def line_svg():
    s = Sheet("widgets/line")
    for id_, w, h in (("horizontal-line", 8, 1), ("vertical-line", 1, 8)):
        x, y = s.block(w, h)
        s.add(id_, x, y, w, h, [box(0, 0, w, h, LINE)(x, y)])
    return s.svg()


def bar_meter_svg():
    """widgets/bar_meter_horizontal: barra de progresso (bateria, volume, cópia de arquivos).

    Com a opção "progresso" escolhida (V24), a parte cheia usa o mesmo padrão do Kvantum: centro em
    ladrilhos (hint-tile-center) e borda de 1 px. Sem a opção, lisa como sempre."""
    s = Sheet("widgets/bar_meter_horizontal")
    frame(s, "bar-inactive", (3,) * 4, surface(P(INPUT), P(LINE)), M=6)
    prog = EST["progresso"] if "progresso" in ESTILO_DEFINIDO else "lisa"
    if prog == "lisa":
        frame(s, "bar-active", (3,) * 4, surface(P(RED)), M=6)
    else:
        tw, th = {"segmentada": (8, 4), "hachurada": (8, 8), "pontos": (4, 4)}[prog]
        if prog == "segmentada":
            cells = [rectpoly(1, 1, 7, 5)]
        elif prog == "pontos":
            cells = [rectpoly(2, 2, 4, 4)]
        else:  # faixas a 45° que emendam nos dois sentidos, sobre o destaque a 30%
            cells = [rectpoly(1, 1, 9, 9)]
            cells += [clip([(k - 20, 20), (k + 20, -20), (k + 23, -20), (k - 17, 20)], 1, 1, 9, 9)
                      for k in (-6, 2, 10)]
        layers = [(rectpoly(0, 0, tw + 2, th + 2), rectpoly(1, 1, tw + 1, th + 1), P(RED, 0.45))]
        layers += [(c, None, P(RED, 0.30 if prog == "hachurada" and i == 0 else 1.0), ("center",))
                   for i, c in enumerate(cells) if area(c) > 1e-6]
        pieces(s, "bar-active", (1,) * 4, layers, (tw, th))
        s.hint("hint-tile-center", 4, 4)
    s.hint("hint-bar-size", 6, 6)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


# ---------------------------------------------------------------- peças próprias (opção "pecas")
# Com "pecas" = cyberkde, o tema passa a ter chave, slider, marcas, rádio e indicador de ocupado
# próprios, com os ids que o PlasmaComponents 3 (Plasma 6.6) procura; senão, ficam os do Breeze.
def element_at(sheet, id_, w, h, shapes):
    """Peça única (sem 9 partes): formas desenhadas em (ox, oy) dentro de w x h."""
    x, y = sheet.block(w, h)
    sheet.add(id_, x, y, w, h, [f(x, y) for f in shapes])


def three_slice(sheet, prefix, l, m, r, h, look):
    """Moldura horizontal de 3 partes (left/center/right), como a trilha do switch do Breeze."""
    W = l + m + r
    outer, layers = look(W, h)
    ox, oy = sheet.block(W + 4, h + 4)
    for i, (pos, xa, xb) in enumerate((("left", 0, l), ("center", l, l + m), ("right", l + m, W))):
        box_ = (xa, 0, xb, h)
        tx, ty = ox + i * 2, oy
        sheet.add(f"{prefix}-{pos}", xa + tx, ty, xb - xa, h, draw(layers, box_, tx, ty, pos))


def handle(size, inner, fill, border=None, c=3):
    """Cursor quadrado chanfrado (inner x inner) centrado numa peça size x size."""
    o = (size - inner) / 2
    return [chamfered(inner, inner, c, P(fill) if fill else None, border, x=o, y=o)]


def ring_shape(size, inner, color, width=2, c=3):
    o = (size - inner) / 2
    return [chamfered(inner, inner, c + width * (2 - math.sqrt(2)), None, P(color), bw=width, x=o, y=o)]


def switch_svg():
    """widgets/switch (V12): trilha angular chanfrada e cursor quadrado."""
    s = Sheet("widgets/switch")
    trilho = {"inactive": surface(P(INPUT), P(CONTROL_LINE), chamfer=corte(4)),
              "active": surface(P(mix(RED, INPUT, 0.35)), P(RED), chamfer=corte(4))}
    for pre, look in trilho.items():
        three_slice(s, pre, 8, 5, 8, 16, look)
    for id_, fill, brd in (("handle", TXT2, None), ("handle-hover", TXT1, P(RED)),
                           ("handle-pressed", CYAN, None), ("handle-active", RED_LIGHT, None)):
        element_at(s, id_, 18, 18, handle(18, 12, fill, brd))
    element_at(s, "handle-focus", 24, 24, ring_shape(24, 18, CYAN))
    element_at(s, "handle-shadow", 18, 18, [])
    s.hint("hint-bar-size", 36, 16)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def slider_svg():
    """widgets/slider (V14): trilha fina e cursor chanfrado, como no Kvantum."""
    s = Sheet("widgets/slider")
    frame(s, "groove", (3,) * 4, surface(P(INPUT), P(CONTROL_LINE)), M=3)
    frame(s, "groove-highlight", (3,) * 4, surface(P(RED)), M=3)
    for d in ("horizontal", "vertical"):
        element_at(s, f"{d}-slider-handle", 20, 20, handle(20, 14, RED, None, 4))
        element_at(s, f"{d}-slider-hover", 20, 20, handle(20, 14, RED_LIGHT, P(TXT1), 4))
        element_at(s, f"{d}-slider-focus", 24, 24, ring_shape(24, 18, CYAN, c=4))
        element_at(s, f"{d}-slider-shadow", 20, 20, [])
    s.hint("hint-handle-size", 20, 20)
    s.hint("hint-stretch-borders", 4, 4)
    return s.svg()


def checkmarks_svg():
    """widgets/checkmarks (V11): marca da caixa de seleção (desenhada sobre o botão "normal")."""
    s = Sheet("widgets/checkmarks")
    element_at(s, "checkbox", 16, 16, [strokes([[(3.5, 8.5), (6.5, 11.5), (12.5, 5)]], RED, 2)])
    element_at(s, "radiobutton", 16, 16, [circle(8, 8, 3.5, RED)])
    return s.svg()


def radiobutton_svg():
    """widgets/radiobutton (V11): anel com miolo, como o rádio do Kvantum."""
    s = Sheet("widgets/radiobutton")
    element_at(s, "normal", 16, 16, [circle(8, 8, 7.5, INPUT, CONTROL_LINE)])
    element_at(s, "checked", 16, 16, [circle(8, 8, 7.5, None, RED)])
    element_at(s, "hover", 16, 16, [circle(8, 8, 7.5, None, mix(RED, INPUT, 0.6))])
    element_at(s, "focus", 20, 20, [circle(10, 10, 9, None, CYAN, 2)])
    element_at(s, "symbol", 6, 6, [circle(3, 3, 3, RED)])
    element_at(s, "shadow", 16, 16, [])
    s.hint("hint-size", 16, 16)
    return s.svg()


def busy_ring(size):
    """Anel de 8 blocos com opacidade decrescente: girando, vira o indicador segmentado (V25)."""
    c, r0, r1, w = size / 2, size * 0.30, size * 0.48, size * 0.16
    shapes = []
    for i in range(8):
        ang = math.radians(i * 45 - 90)
        dx, dy, px, py = math.cos(ang), math.sin(ang), -math.sin(ang), math.cos(ang)
        pts = [(c + dx * r0 + px * w / 2, c + dy * r0 + py * w / 2), (c + dx * r1 + px * w / 2, c + dy * r1 + py * w / 2),
               (c + dx * r1 - px * w / 2, c + dy * r1 - py * w / 2), (c + dx * r0 - px * w / 2, c + dy * r0 - py * w / 2)]
        shapes.append(poly(pts, RED, 1.0 - i * 0.11))
    return shapes


def busywidget_svg():
    s = Sheet("widgets/busywidget")
    element_at(s, "busywidget", 36, 36, busy_ring(36))
    element_at(s, "22-22-busywidget", 22, 22, busy_ring(22))
    element_at(s, "16-16-busywidget", 16, 16, busy_ring(16))
    element_at(s, "stopped", 36, 36, busy_ring(36)[:1])
    s.hint("hint-rotation-angle", 45, 45)  # passo de 45°: um bloco por vez (usado pelo busywidget antigo)
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
    if EST["pecas"] == "cyberkde":
        out.update({
            "widgets/switch.svg": switch_svg(),
            "widgets/slider.svg": slider_svg(),
            "widgets/checkmarks.svg": checkmarks_svg(),
            "widgets/radiobutton.svg": radiobutton_svg(),
            "widgets/busywidget.svg": busywidget_svg(),
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
