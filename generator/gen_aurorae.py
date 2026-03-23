#!/usr/bin/env python3
"""Gera a decoração de janelas Aurorae "CyberKDE" (SVG + rc + metadata) a partir de tokens/cyberkde.json.

Moldura neomilitar (documento, seção 8.1): faixa vermelha em toda a lateral esquerda
da janela ativa, chanfros nos cantos da direita, contorno de 1 px e sombra curta.
O FrameSvg do Plasma dá a cada canto a largura da borda vizinha, por isso os
chanfros ficam limitados à largura das bordas direita e inferior.
"""
from cyberlib import *  # noqa: F403 — tokens, cores e geometria compartilhados

OUT = ROOT / "themes" / "aurorae" / "CyberKDE"

PAD = 8                                  # área da sombra curta em volta da janela
BORDER_L, BORDER_R, BORDER_B = 4, 6, 4   # esquerda = faixa de 3 px + 1 px de respiro
EDGE_T, TITLE_H, EDGE_B = 4, 24, 4
TITLE = EDGE_T + TITLE_H + EDGE_B
M = 16                                   # miolo esticável das peças
MARK = CH["markerWidth"]
CHAMFER = {"tr": BORDER_R, "br": BORDER_B}
BTN_W, BTN_H = 30, 24
FRAME_POS = {"topleft": (0, 0), "top": (1, 0), "topright": (2, 0),
             "left": (0, 1), "center": (1, 1), "right": (2, 1),
             "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2)}


class Sheet:
    """Folha SVG: cada peça é um grupo com id, desenhado em coordenadas absolutas."""

    def __init__(self):
        self.items, self.width, self.height = [], 0, 0

    def add(self, id_, x, y, w, h, parts):
        self.items.append(f'<g id="{id_}">{invisible(x, y, w, h)}{"".join(parts)}</g>')
        self.width, self.height = max(self.width, x + w + 10), max(self.height, y + h + 10)

    def svg(self):
        return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" '
                f'viewBox="0 0 {self.width} {self.height}">\n'
                f'<!-- CyberKDE — gerado por generator/gen_aurorae.py; não editar à mão -->\n'
                + "\n".join(self.items) + "\n</svg>\n")


def ring(outer, inner, color, a, box, tx, ty):
    """Faixa entre dois polígonos (evenodd), recortada à peça."""
    o, i = clip(outer, *box), clip(inner, *box)
    if area(o) - area(i) <= 1e-6:
        return []
    d = sub(o, tx, ty) + (" " + sub(i, tx, ty) if area(i) > 1e-6 else "")
    return [f'<path d="{d}" {paint(P(color, a))} fill-rule="evenodd"/>']


def frame(sheet, prefix, active, oy):
    """Um estado completo da moldura (9 peças), com sombra, contorno, separador e faixa lateral."""
    W = PAD + BORDER_L + M + BORDER_R + PAD
    H = PAD + TITLE + M + BORDER_B + PAD
    x0, y0, x1, y1 = PAD, PAD, W - PAD, H - PAD
    outer, labels = outline(x0, y0, x1, y1, CHAMFER)
    inner = offset_polygon(outer, labels, lambda s: 1 if s in ("t", "r", "b", "tr", "br") else 0)
    line = mix(RED, BASE, BRAND) if active else LINE
    strength = 0.22 if active else 0.14

    shadow, prev = [], outer
    for i in range(1, PAD + 1):
        grown = offset_polygon(outer, labels, lambda _, i=i: -i)
        shadow.append((grown, prev, strength * (1 - (i - 1) / PAD) ** 2))
        prev = grown

    separator = rectpoly(x0 + BORDER_L, y0 + TITLE - 1, x1 - BORDER_R, y0 + TITLE)
    marker = rectpoly(x0, y0, x0 + (MARK if active else 1), y1)
    mark_color = RED if active else LINE

    cols, rows = (0, PAD + BORDER_L, PAD + BORDER_L + M, W), (0, PAD + TITLE, PAD + TITLE + M, H)
    for pos, (ci, ri) in FRAME_POS.items():
        bx = (cols[ci], rows[ri], cols[ci + 1], rows[ri + 1])
        tx, ty = 10 + ci * 2, oy + ri * 2
        parts = []
        for grown, inside, a in shadow:
            parts += ring(grown, inside, "#000000", a, bx, tx, ty)
        parts += shape_svg(outer, inner, P(BASE), P(line), tx, ty, bx)
        for shape, color in ((separator, LINE), (marker, mark_color)):
            s = clip(shape, *bx)
            if area(s) > 1e-6:
                parts.append(f'<path d="{sub(s, tx, ty)}" {paint(P(color))}/>')
        sheet.add(f"{prefix}-{pos}", bx[0] + tx, bx[1] + ty, bx[2] - bx[0], bx[3] - bx[1], parts)
    return oy + H + 20


def decoration_svg():
    sheet = Sheet()
    oy = frame(sheet, "decoration", True, 10)
    oy = frame(sheet, "decoration-inactive", False, oy)
    # Maximizada: só o centro (faixa de título) é usado.
    for i, prefix in enumerate(("decoration-maximized", "decoration-maximized-inactive")):
        x = 10 + i * (M + 20)
        sheet.add(f"{prefix}-center", x, oy, M, TITLE_H, [box(0, 0, M, TITLE_H, BASE)(x, oy)])
    # O FrameSvg repete as bordas em ladrilhos por padrão, deixando emendas no filete de 1 px;
    # estas marcas pedem para esticar as bordas.
    for i, hint in enumerate(("hint-stretch-borders", "decoration-hint-stretch-borders",
                              "decoration-inactive-hint-stretch-borders")):
        sheet.add(hint, 10 + i * 6, oy + TITLE_H + 10, 4, 4, [])
    return sheet.svg()


# ---------------------------------------------------------------- botões (glifo 10x10 centrado)
GX, GY = (BTN_W - 10) / 2, (BTN_H - 10) / 2


def outline_shape(pts, width, color):
    """Contorno de um polígono convexo em sentido horário, com espessura fixa."""
    inner = offset_polygon(pts, list(range(len(pts))), lambda _: width)
    return lambda ox, oy: "".join(shape_svg(pts, inner, None, P(color), ox, oy))


GLYPHS = {
    "close": lambda c: [strokes([[(GX + 1, GY + 1), (GX + 9, GY + 9)], [(GX + 9, GY + 1), (GX + 1, GY + 9)]], c, 1.5)],
    "minimize": lambda c: [box(GX, GY + 8, 10, 1.5, c)],
    "maximize": lambda c: [outline_shape(outline(GX, GY, GX + 10, GY + 10, {"br": 3})[0], 1.3, c)],
    "restore": lambda c: [box(GX + 3, GY, 7, 1.3, c), box(GX + 8.7, GY, 1.3, 7, c),
                          outline_shape(outline(GX, GY + 3, GX + 7, GY + 10, {"br": 2})[0], 1.3, c)],
    "keepabove": lambda c: [poly([(GX + 1, GY + 7), (GX + 5, GY + 2), (GX + 9, GY + 7)], c)],
    "keepbelow": lambda c: [poly([(GX + 1, GY + 3), (GX + 9, GY + 3), (GX + 5, GY + 8)], c)],
    "alldesktops": lambda c: [outline_shape([(GX + 5, GY), (GX + 10, GY + 5), (GX + 5, GY + 10), (GX, GY + 5)], 1.3, c)],
    "shade": lambda c: [box(GX, GY + 1, 10, 1.5, c), box(GX, GY + 4.5, 10, 1, c, 0.5)],
}


def button_svg(name):
    panel = outline(1, 2, BTN_W - 1, BTN_H - 2, {"br": 4})[0]
    states = {
        "active": (None, None, TXT2),
        "hover": (P(mix(RED, BASE, 0.12)), P(mix(RED, BASE, 0.5)), TXT1),
        "pressed": (P(mix(RED, BASE, PRS)), P(RED), TXT1),
        "inactive": (None, None, TXTD),
        "deactivated": (None, None, mix(TXTD, BASE, 0.5)),
    }
    if name == "close":  # fechar: vermelho sólido com glifo escuro (ação destrutiva), qualquer que seja o destaque
        states["hover"] = (P(DANGER), None, ONRED)
        states["pressed"] = (P(mix(DANGER, BASE, 0.7)), None, ONRED)
    sheet = Sheet()
    for i, (state, (fill, border, glyph)) in enumerate(states.items()):
        x, y = 10 + i * (BTN_W + 10), 10
        inner = offset_polygon(panel, list(range(len(panel))), lambda _: 1) if border else panel
        parts = shape_svg(panel, inner, fill, border, x, y) + [g(x, y) for g in GLYPHS[name](glyph)]
        sheet.add(f"{state}-center", x, y, BTN_W, BTN_H, parts)
    return sheet.svg()


def kc(h, a=255):
    return ",".join(str(v) for v in rgb(h)) + f",{a}"


RC = f"""[General]
TitleAlignment=Left
TitleVerticalAlignment=Center
Animation={TOK["motion"]["micro"]}
ActiveTextColor={kc(TXT1)}
InactiveTextColor={kc(TXTD)}
UseTextShadow=false
Shadow=true
LeftButtons=M
RightButtons=IAX

[Layout]
BorderLeft={BORDER_L}
BorderRight={BORDER_R}
BorderBottom={BORDER_B}
TitleEdgeTop={EDGE_T}
TitleEdgeBottom={EDGE_B}
TitleEdgeLeft=4
TitleEdgeRight={BORDER_R + 2}
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE_H}
ButtonWidth={BTN_W}
ButtonHeight={BTN_H}
ButtonSpacing=2
ButtonMarginTop=0
ExplicitButtonSpacer=10
PaddingTop={PAD}
PaddingBottom={PAD}
PaddingLeft={PAD}
PaddingRight={PAD}
"""

METADATA = f"""[Desktop Entry]
Name=CyberKDE
Comment=Neo-military window decoration with 45° chamfers
Comment[pt_BR]=Decoração de janelas neomilitar, com chanfros a 45°
X-KDE-PluginInfo-Name=CyberKDE
X-KDE-PluginInfo-Author={AUTHOR}
X-KDE-PluginInfo-Version={VERSION}
X-KDE-PluginInfo-License={LICENSE}
X-KDE-PluginInfo-Website={WEBSITE}
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "decoration.svg").write_text(decoration_svg())
    for name in GLYPHS:
        (OUT / f"{name}.svg").write_text(button_svg(name))
    (OUT / "CyberKDErc").write_text(RC)
    (OUT / "metadata.desktop").write_text(METADATA)
    print(f"decoração + {len(GLYPHS)} botões → {OUT}")


if __name__ == "__main__":
    main()
