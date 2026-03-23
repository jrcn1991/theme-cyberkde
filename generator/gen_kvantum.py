#!/usr/bin/env python3
"""Gera o tema Kvantum "CyberKDE" (SVG + kvconfig) e o esquema de cores KDE a partir de tokens/cyberkde.json.

Cada estado de widget é descrito por um Look (preenchimento, contorno, chanfros,
marcador lateral). O gerador desenha a peça inteira e a recorta nas 9 partes que
o Kvantum espera (interior + 8 molduras), sempre com coordenadas absolutas.
"""
from cyberlib import *  # noqa: F403 — tokens, cores e geometria compartilhados com gen_aurorae.py

OUT = ROOT / "themes" / "kvantum" / "CyberKDE"


# ---------------------------------------------------------------- tela SVG
class Canvas:
    def __init__(self, width=1600):
        self.width, self.x, self.y, self.row, self.items = width, 10, 10, 0, []

    def place(self, w, h):
        if self.x + w > self.width:
            self.x, self.y, self.row = 10, self.y + self.row + 10, 0
        pos = (self.x, self.y)
        self.x += w + 10
        self.row = max(self.row, h)
        return pos

    def svg(self):
        h = self.y + self.row + 10
        body = "\n".join(self.items)
        return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{h}" '
                f'viewBox="0 0 {self.width} {h}">\n'
                f'<!-- CyberKDE — gerado por generator/gen_kvantum.py; não editar à mão -->\n{body}\n</svg>\n')


C = Canvas()
PIECES = {"topleft": (0, 0), "top": (1, 0), "topright": (2, 0),
          "left": (0, 1), "": (1, 1), "right": (2, 1),
          "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2)}


def element(name, state, frames, look, interior=True, M=12):
    """Emite as 9 peças de um estado. frames = (topo, base, esquerda, direita)."""
    t, b, l, r = frames
    W, H = l + M + r, t + M + b
    it, ir, ib, il = look.inset
    x0, y0, x1, y1 = il, it, W - ir, H - ib
    outer, labels = outline(x0, y0, x1, y1, look.chamfer)
    if look.border:
        def dist(lbl):
            if len(lbl) == 1:
                return look.bw if lbl in look.sides else 0
            return look.bw if (lbl[0] in look.sides or lbl[1] in look.sides) else 0
        inner = offset_polygon(outer, labels, dist)
    else:
        inner = outer
    mk = None
    if look.marker:
        mp, side, w = look.marker
        ch = look.chamfer
        mk = {"left": rectpoly(x0, y0 + ch.get("tl", 0), x0 + w, y1 - ch.get("bl", 0)),
              "right": rectpoly(x1 - w, y0 + ch.get("tr", 0), x1, y1 - ch.get("br", 0)),
              "top": rectpoly(x0 + ch.get("tl", 0), y0, x1 - ch.get("tr", 0), y0 + w),
              "bottom": rectpoly(x0 + ch.get("bl", 0), y1 - w, x1 - ch.get("br", 0), y1)}[side]

    base_id = name if state is None else f"{name}-{state}"
    ox, oy = C.place(W + 4, H + 4)
    cols, rows = (0, l, l + M, W), (0, t, t + M, H)
    for pos, (ci, ri) in PIECES.items():
        xa, xb, ya, yb = cols[ci], cols[ci + 1], rows[ri], rows[ri + 1]
        if xb <= xa or yb <= ya or (pos == "" and not interior):
            continue
        tx, ty = ox + ci * 2, oy + ri * 2  # vista "explodida" só para leitura no Inkscape
        parts = [invisible(xa + tx, ya + ty, xb - xa, yb - ya)]
        parts += shape_svg(outer, inner, look.fill, look.border, tx, ty, (xa, ya, xb, yb))
        if mk:
            m = clip(mk, xa, ya, xb, yb)
            if area(m) > 1e-6:
                parts.append(f'<path d="{sub(m, tx, ty)}" {paint(mp)}/>')
        pid = base_id if pos == "" else f"{base_id}-{pos}"
        C.items.append(f'<g id="{pid}">{"".join(parts)}</g>')


def widget(name, frames, states, **kw):
    for st, lk in states.items():
        element(name, st, frames, lk, **kw)


def icon(id_, w, h, *shapes):
    ox, oy = C.place(w + 4, h + 4)
    body = "".join(s(ox, oy) for s in shapes)
    C.items.append(f'<g id="{id_}">{invisible(ox, oy, w, h)}{body}</g>')


# ---------------------------------------------------------------- widgets
FR = {}  # molduras por elemento, reaproveitadas no kvconfig


def frames(name, t, b, l, r):
    FR[name] = (t, b, l, r)
    return FR[name]


cs, cm = CH["chamferSmall"], CH["chamferStandard"]
mw = CH["markerWidth"]

# Botão (PanelButtonCommand) — chanfro padrão no canto inferior direito
widget("button", frames("button", 2, cm, 2, cm), {
    "normal": Look(P(RAISED), P(mix(RED, RAISED, BRAND)), chamfer={"br": cm}),
    "focused": Look(P(mix(RED, RAISED, HOV)), P(RED), chamfer={"br": cm}),
    "pressed": Look(P(mix(RED, RAISED, PRS)), P(RED), chamfer={"br": cm}),
    "toggled": Look(P(mix(RED, RAISED, SEL)), P(RED), chamfer={"br": cm}),
})

# Botão de ferramenta (toolbar do Dolphin) — chanfro pequeno
widget("tbutton", frames("tbutton", 1, cs, 1, cs), {
    "normal": Look(None, P(mix(RED, PANEL, BRAND)), chamfer={"br": cs}),
    "focused": Look(P(mix(RED, BASE, HOV)), P(mix(RED, BASE, BRAND)), chamfer={"br": cs}),
    "pressed": Look(P(mix(RED, BASE, PRS)), P(RED), chamfer={"br": cs}),
    "toggled": Look(P(mix(RED, BASE, SEL)), P(RED), chamfer={"br": cs}),
})

# Item de lista/ícone (seleção do Dolphin): hover tonal, seleção com marcador lateral
iv = dict(chamfer={"br": cs})
widget("itemview", frames("itemview", 1, cs, cs, cs), {
    "focused": Look(P(RED, HOV), P(RED, BRAND), **iv),
    "pressed": Look(P(RED, SEL), P(RED), marker=(P(RED), "left", mw), **iv),
    "toggled": Look(P(RED, SEL + 0.06), P(RED), marker=(P(RED), "left", mw), **iv),
    "pressed-inactive": Look(P(RED, 0.12), P(RED, 0.45), marker=(P(RED, 0.6), "left", mw), **iv),
    "toggled-inactive": Look(P(RED, 0.12), P(RED, 0.45), marker=(P(RED, 0.6), "left", mw), **iv),
})

# Campo de texto: contorno neutro, foco ciano de 2 px
widget("lineedit", frames("lineedit", 2, cs, 2, cs), {
    "normal": Look(P(INPUT), P(CONTROL_LINE), chamfer={"br": cs}),
    "focused": Look(P(INPUT), P(CYAN), bw=2, chamfer={"br": cs}),
})

# Abas: inativa = só filete inferior; ativa = moldura vermelha + faixa de 2 px
widget("tab", frames("tab", cs, 2, 1, cs), {
    "normal": Look(None, P(LINE), sides="b", chamfer={"tr": cs}),
    "focused": Look(P(mix(RED, PANEL, HOV)), P(mix(RED, PANEL, BRAND)), chamfer={"tr": cs}),
    "pressed": Look(P(mix(RED, PANEL, SEL)), P(RED), sides="tlr", chamfer={"tr": cs}, marker=(P(RED), "bottom", 2)),
    "toggled": Look(P(mix(RED, PANEL, SEL)), P(RED), sides="tlr", chamfer={"tr": cs}, marker=(P(RED), "bottom", 2)),
})
widget("tabframe", frames("tabframe", 1, 1, 1, 1), {"normal": Look(None, P(LINE))})

# Cabeçalho de colunas (modo detalhes)
widget("header", frames("header", 0, 1, 0, 1), {
    "normal": Look(P(BASE), P(LINE), sides="b"),
    "focused": Look(P(mix(RED, BASE, HOV)), P(mix(RED, BASE, 0.5)), sides="b"),
    "pressed": Look(P(mix(RED, BASE, SEL)), P(RED), sides="b"),
    "toggled": Look(P(mix(RED, BASE, HOV)), P(mix(RED, BASE, 0.5)), sides="b"),
})
icon("header-separator", 1, 20, box(0, 5, 1, 10, LINE))

# Molduras genéricas e grupos
widget("common", frames("common", 1, 1, 1, 1), {"normal": Look(None, P(LINE)), "focused": Look(None, P(LINE))})
widget("group", frames("group", 1, cm, 1, cm), {"normal": Look(None, P(LINE), chamfer={"br": cm})})

# Barra de ferramentas: superfície base + filete vermelho de identidade embaixo
widget("toolbar", frames("toolbar", 1, 1, 1, 1), {"normal": Look(P(BASE), P(mix(RED, BASE, BRAND)), sides="b")})
icon("toolbar-separator", 5, 20, box(2, 4, 1, 12, LINE))

# Barra de menus e seus itens
widget("menubar", frames("menubar", 0, 1, 0, 0), {"normal": Look(P(BASE), P(mix(RED, BASE, BRAND)), sides="b")})
widget("menubaritem", frames("menubaritem", 2, 2, 2, 2), {
    "focused": Look(P(mix(RED, BASE, HOV)), marker=(P(RED), "bottom", 2)),
    "pressed": Look(P(mix(RED, BASE, SEL)), marker=(P(RED), "bottom", 2)),
    "toggled": Look(P(mix(RED, BASE, SEL)), marker=(P(RED), "bottom", 2)),
})

# Menus (popup opaco chanfrado) e itens com marcador lateral
widget("menu", frames("menu", 2, cm, 2, cm), {"normal": Look(P(RAISED), P(mix(RED, RAISED, BRAND)), chamfer={"br": cm})})
widget("menuitem", frames("menuitem", 1, 1, mw + 1, 1), {
    "focused": Look(P(mix(RED, RAISED, HOV)), marker=(P(RED), "left", mw)),
    "pressed": Look(P(mix(RED, RAISED, SEL)), marker=(P(RED), "left", mw)),
    "toggled": Look(P(mix(RED, RAISED, SEL)), marker=(P(RED), "left", mw)),
})
icon("menuitem-separator", 20, 9, box(0, 4, 20, 1, LINE))

# Dica (tooltip)
widget("tooltip", frames("tooltip", cm, cm, cm, cm), {"normal": Look(P(RAISED), P(mix(RED, RAISED, BRAND)), chamfer={"br": cm})})

# Rolagem: trilho de 1 px e cursor de 6 px
widget("scrollbargroove", frames("scrollbargroove", 0, 0, 4, 5), {"normal": Look(P(LINE), inset=(0, 5, 0, 4))})
widget("scrollbarslider", frames("scrollbarslider", 2, 2, 2, 2), {
    "normal": Look(P(mix(RED, BASE, 0.40)), inset=(0, 2, 0, 2)),
    "focused": Look(P(RED), inset=(0, 2, 0, 2)),
    "pressed": Look(P(RED_LIGHT), inset=(0, 2, 0, 2)),
})

# Divisor entre painéis
widget("splitter", frames("splitter", 0, 0, 2, 2), {
    "normal": Look(P(LINE), inset=(0, 2, 0, 2)),
    "focused": Look(P(mix(RED, PANEL, 0.6)), inset=(0, 2, 0, 2)),
    "pressed": Look(P(RED), inset=(0, 2, 0, 2)),
})

# Barra de progresso segmentada
widget("progress", frames("progress", 1, 1, 1, 1), {"normal": Look(P(BASE), P(LINE))})
icon("progress-pattern-normal", 8, 8, box(0, 0, 6, 8, RED))
icon("progress-pattern-disabled", 8, 8, box(0, 0, 6, 8, TXTD))

# Slider: trilha fina e cursor sólido chanfrado
icon("slider-normal", 4, 12, box(0, 0, 4, 12, LINE))
icon("slider-toggled", 4, 12, box(0, 0, 4, 12, RED))
for st, fill, brd in (("normal", RED, None), ("focused", RED_LIGHT, P(WHITE)),
                      ("pressed", CYAN, None), ("disabled", TXTD, None)):
    icon(f"slidercursor-{st}", 14, 14, chamfered(14, 14, 4, P(fill), brd))

# Foco por teclado: anel ciano de 2 px (sem estados, sem interior)
element("focus", None, frames("focus", 2, cs, 2, cs),
        Look(None, P(CYAN), bw=TOK["focus"]["width"], chamfer={"br": cs}), interior=False)

# ---------------------------------------------------------------- indicadores
ARROW_STATES = {"normal": TXT2, "focused": WHITE, "pressed": RED, "toggled": WHITE, "disabled": TXTD}
TRI = {"down": [(1, 2.5), (8, 2.5), (4.5, 6.5)], "up": [(1, 6.5), (8, 6.5), (4.5, 2.5)],
       "right": [(2.5, 1), (2.5, 8), (6.5, 4.5)], "left": [(6.5, 1), (6.5, 8), (2.5, 4.5)]}
for st, col in ARROW_STATES.items():
    for d, pts in TRI.items():
        icon(f"arrow-{d}-{st}", 9, 9, poly(pts, col))
    icon(f"arrow-plus-{st}", 9, 9, box(1, 3.75, 7, 1.5, col), box(3.75, 1, 1.5, 7, col))
    icon(f"arrow-minus-{st}", 9, 9, box(1, 3.75, 7, 1.5, col))

for st, col in {"normal": TXT2, "focused": RED, "pressed": RED, "disabled": TXTD}.items():
    icon(f"tree-plus-{st}", 9, 9, poly(TRI["right"], col))
    icon(f"tree-minus-{st}", 9, 9, poly(TRI["down"], col))

for st, col in {"normal": TXT2, "focused": WHITE, "disabled": TXTD}.items():
    icon(f"menuitem-right-{st}", 9, 9, poly(TRI["right"], col))
    icon(f"menuitem-left-{st}", 9, 9, poly(TRI["left"], col))

for st, col in {"normal": TXT2, "focused": RED, "pressed": CYAN, "disabled": TXTD}.items():
    icon(f"tab-close-{st}", 10, 10, strokes([[(2.5, 2.5), (7.5, 7.5)], [(7.5, 2.5), (2.5, 7.5)]], col, 1.5))

CHECK = [[(3.5, 8.5), (6.5, 11.5), (12.5, 5)]]
cb = {
    "normal": (P(INPUT), P(CONTROL_LINE)),
    "focused": (P(mix(RED, INPUT, HOV)), P(RED)),
    "pressed": (P(mix(RED, INPUT, 0.25)), P(RED)),
    "disabled": (P(INPUT), P(TXTD, 0.5)),
}
for st, (fill, brd) in cb.items():
    icon(f"checkbox-{st}", 16, 16, chamfered(16, 16, 4, fill, brd))
    icon(f"checkbox-tristate-{st}", 16, 16, chamfered(16, 16, 4, fill, P(RED) if st != "disabled" else brd),
         box(4, 7, 8, 2, RED if st != "disabled" else TXTD))
for st, fill in {"normal": RED, "focused": RED_LIGHT, "pressed": mix(RED, BASE, 0.7), "disabled": TXTD}.items():
    icon(f"checkbox-checked-{st}", 16, 16, chamfered(16, 16, 4, P(fill), None),
         strokes(CHECK, ONRED if st != "disabled" else BASE, 2))

for st, (fill, brd) in cb.items():
    icon(f"radio-{st}", 16, 16, circle(8, 8, 7.5, fill[0], brd[0]))
for st, dot in {"normal": RED, "focused": RED_LIGHT, "pressed": mix(RED, BASE, 0.7), "disabled": TXTD}.items():
    ring = TXTD if st == "disabled" else RED
    icon(f"radio-checked-{st}", 16, 16, circle(8, 8, 7.5, INPUT, ring), circle(8, 8, 3.5, dot))


# ---------------------------------------------------------------- kvconfig
def fr(name):
    t, b, l, r = FR[name]
    return f"frame.top={t}\nframe.bottom={b}\nframe.left={l}\nframe.right={r}"


def margins(name, pad_v, pad_h):
    """Margens de texto que compensam molduras assimétricas, centralizando o conteúdo."""
    t, b, l, r = FR[name]
    big_v, big_h = max(t, b), max(l, r)
    return (f"text.margin=true\ntext.margin.top={pad_v + big_v - t}\ntext.margin.bottom={pad_v + big_v - b}\n"
            f"text.margin.left={pad_h + big_h - l}\ntext.margin.right={pad_h + big_h - r}")


TEXT_WHITE = (f"text.normal.color={TXT1}\ntext.focus.color={TXT1}\n"
              f"text.press.color={TXT1}\ntext.toggle.color={TXT1}")
TEXT_SOFT = (f"text.normal.color={TXT2}\ntext.focus.color={TXT1}\n"
             f"text.press.color={TXT1}\ntext.toggle.color={TXT1}")

KV = f"""[%General]
author={AUTHOR}
comment=CyberKDE: neo-military Kvantum theme with 45° chamfers ({WEBSITE})
respect_DE=true
x11drag=menubar_and_primary_toolbar
alt_mnemonic=true
click_behavior=0
left_tabs=true
attach_active_tab=false
joined_inactive_tabs=false
group_toolbar_buttons=false
toolbar_item_spacing=2
toolbar_interior_spacing=2
toolbar_separator_thickness=5
spread_progressbar=false
composite=true
menu_shadow_depth=0
tooltip_shadow_depth=0
shadowless_popup=true
translucent_windows=false
blurring=false
popup_blurring=false
reduce_menu_opacity=0
scrollable_menu=true
menu_separator_height=9
submenu_overlap=0
submenu_delay=150
animate_states=true
no_inactiveness=false
splitter_width=2
scroll_width=10
scroll_min_extent=40
scroll_arrows=false
scrollbar_in_view=true
transient_scrollbar=false
tree_branch_line=true
slider_width=4
slider_handle_width=14
slider_handle_length=14
check_size=16
tooltip_delay={TOK["motion"].get("tooltipDelay", 350)}
combo_as_lineedit=true
inline_spin_indicators=true
fill_rubberband=false
layout_spacing=4
layout_margin=6

[GeneralColors]
window.color={PANEL}
base.color={BASE}
alt.base.color={ALT}
button.color={RAISED}
light.color={LINE}
mid.light.color=#2A2A38
dark.color=#05050B
mid.color=#23232F
shadow.color=#000000
highlight.color={RED}
inactive.highlight.color={mix(RED, BASE, 0.5)}
tooltip.base.color={RAISED}
text.color={TXT1}
window.text.color={TXT1}
button.text.color={TXT1}
disabled.text.color={TXTD}
tooltip.text.color={TXT1}
highlight.text.color={ONSEL}
link.color={CYAN}
link.visited.color=#B46CFA
progress.indicator.text.color={ONRED}

[Hacks]
respect_darkness=true
transparent_ktitle_label=true
transparent_menutitle=true
transparent_arrow_button=true
no_selection_tint=true
transparent_dolphin_view=false

[PanelButtonCommand]
frame=true
frame.element=button
interior=true
interior.element=button
{fr("button")}
indicator.size=9
indicator.element=arrow
{TEXT_WHITE}
text.shadow=false
text.iconspacing=6
{margins("button", 4, 6)}

[PanelButtonTool]
inherits=PanelButtonCommand
frame.element=tbutton
interior.element=tbutton
{fr("tbutton")}
{margins("tbutton", 2, 2)}

[Dock]
inherits=PanelButtonCommand
frame=false
interior=false

[DockTitle]
inherits=PanelButtonCommand
frame=false
interior=false
{TEXT_SOFT}
text.bold=true
text.margin=true
text.margin.top=4
text.margin.bottom=4
text.margin.left=4
text.margin.right=4

[IndicatorSpinBox]
inherits=PanelButtonCommand
frame=true
frame.element=spin
interior.element=spin
indicator.element=arrow
indicator.size=9

[RadioButton]
inherits=PanelButtonCommand
frame=false
interior.element=radio
text.margin.top=2
text.margin.bottom=2
text.margin.left=4
text.margin.right=4

[CheckBox]
inherits=PanelButtonCommand
frame=false
interior.element=checkbox
text.margin.top=2
text.margin.bottom=2
text.margin.left=4
text.margin.right=4

[Focus]
inherits=PanelButtonCommand
frame=true
interior=false
frame.element=focus
{fr("focus")}

[GenericFrame]
inherits=PanelButtonCommand
frame=true
interior=false
frame.element=common
interior.element=common
{fr("common")}

[LineEdit]
inherits=PanelButtonCommand
frame.element=lineedit
interior.element=lineedit
{fr("lineedit")}
{margins("lineedit", 2, 3)}

[DropDownButton]
inherits=PanelButtonCommand
indicator.element=arrow-down

[IndicatorArrow]
indicator.element=arrow
indicator.size=9

[ToolboxTab]
inherits=PanelButtonCommand

[Tab]
inherits=PanelButtonCommand
frame.element=tab
interior.element=tab
indicator.element=tab
{fr("tab")}
{TEXT_SOFT}
{margins("tab", 3, 8)}

[TabFrame]
inherits=PanelButtonCommand
frame.element=tabframe
interior=false
{fr("tabframe")}

[TabBarFrame]
inherits=GenericFrame
frame=false
interior=false

[TreeExpander]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.element=tree
indicator.size=9

[HeaderSection]
inherits=PanelButtonCommand
frame.element=header
interior.element=header
{fr("header")}
indicator.element=arrow
indicator.size=8
{TEXT_SOFT}
text.margin=true
text.margin.top=3
text.margin.bottom=3
text.margin.left=6
text.margin.right=6

[SizeGrip]
indicator.element=resize-grip

[Toolbar]
inherits=PanelButtonCommand
indicator.element=toolbar
indicator.size=5
frame=true
frame.element=toolbar
interior=true
interior.element=toolbar
{fr("toolbar")}
text.margin=false

[Slider]
inherits=PanelButtonCommand
frame=false
interior=true
interior.element=slider

[SliderCursor]
inherits=PanelButtonCommand
frame=false
interior=true
interior.element=slidercursor

[Progressbar]
inherits=PanelButtonCommand
frame=true
frame.element=progress
interior=true
interior.element=progress
{fr("progress")}
text.margin=false
text.normal.color={TXT1}
text.focus.color={TXT1}
text.bold=false

[ProgressbarContents]
inherits=PanelButtonCommand
frame=false
interior=true
interior.element=progress-pattern
interior.x.patternsize=8

[ItemView]
inherits=PanelButtonCommand
frame=true
frame.element=itemview
interior=true
interior.element=itemview
{fr("itemview")}
{TEXT_WHITE}
text.margin=true
text.margin.top=1
text.margin.bottom=1
text.margin.left=2
text.margin.right=2

[Splitter]
inherits=PanelButtonCommand
frame=true
frame.element=splitter
interior=true
interior.element=splitter
{fr("splitter")}
indicator.element=splitter-grip
indicator.size=16

[Scrollbar]
inherits=PanelButtonCommand
indicator.element=arrow
indicator.size=8

[ScrollbarGroove]
inherits=PanelButtonCommand
frame=true
frame.element=scrollbargroove
interior=true
interior.element=scrollbargroove
{fr("scrollbargroove")}

[ScrollbarSlider]
inherits=PanelButtonCommand
frame=true
frame.element=scrollbarslider
interior=true
interior.element=scrollbarslider
{fr("scrollbarslider")}
indicator.element=grip

[MenuItem]
inherits=PanelButtonCommand
frame=true
frame.element=menuitem
interior=true
interior.element=menuitem
indicator.element=menuitem
{fr("menuitem")}
{TEXT_WHITE}
text.margin=true
text.margin.top=3
text.margin.bottom=3
text.margin.left=6
text.margin.right=8
min_height=1.6font

[MenuBarItem]
inherits=PanelButtonCommand
frame=true
frame.element=menubaritem
interior=true
interior.element=menubaritem
{fr("menubaritem")}
{TEXT_WHITE}
text.margin=true
text.margin.top=3
text.margin.bottom=3
text.margin.left=6
text.margin.right=6

[MenuBar]
inherits=PanelButtonCommand
frame=true
frame.element=menubar
interior=true
interior.element=menubar
{fr("menubar")}
text.normal.color={TXT1}

[TitleBar]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.element=mdi
text.normal.color={TXT2}
text.focus.color={TXT1}

[ComboBox]
inherits=PanelButtonCommand

[Menu]
inherits=PanelButtonCommand
frame=true
frame.element=menu
interior=true
interior.element=menu
{fr("menu")}
{TEXT_WHITE}

[GroupBox]
inherits=GenericFrame
frame=true
frame.element=group
interior=false
{fr("group")}
text.margin=false
text.normal.color={TXT2}

[ToolTip]
inherits=GenericFrame
frame=true
frame.element=tooltip
interior=true
interior.element=tooltip
{fr("tooltip")}
text.margin=false
text.normal.color={TXT1}

[StatusBar]
inherits=GenericFrame
frame=false
interior=false

[Window]
interior=false

[Dialog]
interior=false
"""


# ---------------------------------------------------------------- esquema de cores KDE
def kc(h):
    return ",".join(str(v) for v in rgb(h))


def color_group(bg, alt, fg=TXT1, inactive=TXT2, negative=DANGER):
    return (f"BackgroundAlternate={kc(alt)}\nBackgroundNormal={kc(bg)}\n"
            f"DecorationFocus={kc(CYAN)}\nDecorationHover={kc(RED)}\n"
            f"ForegroundActive={kc(CYAN)}\nForegroundInactive={kc(inactive)}\n"
            f"ForegroundLink={kc(CYAN)}\nForegroundNegative={kc(negative)}\n"
            f"ForegroundNeutral={kc(GOLD)}\nForegroundNormal={kc(fg)}\n"
            f"ForegroundPositive={kc(GREEN)}\nForegroundVisited={kc(VISITED)}\n")


# O fundo Selection é o vermelho puro: o Dolphin 25.x desenha a própria seleção com
# QPalette::Accent (= fundo Selection) a 32% de opacidade.
COLORS = f"""# CyberKDE — gerado por generator/gen_kvantum.py a partir de tokens/cyberkde.json; não editar à mão.

[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Enable=false

[Colors:Button]
{color_group(RAISED, PANEL)}
[Colors:Complementary]
{color_group(BASE, PANEL)}
[Colors:Header]
{color_group(BASE, PANEL)}
[Colors:Header][Inactive]
{color_group(BASE, PANEL, TXT2, TXTD)}
[Colors:Selection]
{color_group(RED, mix(RED, BASE, SEL), ONSEL, TXT2, mix(WHITE, DANGER, 0.4))}
[Colors:Tooltip]
{color_group(RAISED, PANEL)}
[Colors:View]
{color_group(BASE, ALT)}
[Colors:Window]
{color_group(PANEL, RAISED)}
[General]
ColorScheme=CyberKDE
Name=CyberKDE
shadeSortColumn=false

[KDE]
contrast=4

[WM]
activeBackground={kc(BASE)}
activeBlend={kc(RED)}
activeForeground={kc(TXT1)}
inactiveBackground={kc(BASE)}
inactiveBlend={kc(LINE)}
inactiveForeground={kc(TXTD)}
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "CyberKDE.svg").write_text(C.svg())
    (OUT / "CyberKDE.kvconfig").write_text(KV)
    (ROOT / "themes" / "color-schemes" / "CyberKDE.colors").write_text(COLORS)
    print(f"{len(C.items)} objetos SVG → {OUT}; esquema de cores → themes/color-schemes/CyberKDE.colors")


if __name__ == "__main__":
    main()
