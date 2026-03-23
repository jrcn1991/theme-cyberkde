#!/usr/bin/env python3
"""Gera o esquema de cores e o perfil do Konsole "CyberKDE" a partir de tokens/cyberkde.json."""
from cyberlib import *  # noqa: F403 — tokens e cores compartilhados

OUT = ROOT / "themes" / "konsole"

# Cores ANSI: paleta do documento. O azul e o violeta publicados ficam abaixo de 4:1
# sobre o fundo escuro, então usam tons um pouco mais claros para o texto.
ANSI = [
    ("#2A2A3A", "#4A4A5E"),          # 0 preto (distinto do fundo)
    (DANGER, "#FF7A73"),             # 1 vermelho (erros: fica vermelho mesmo com outra cor de destaque)
    (GREEN, "#6BFFB0"),              # 2 verde
    (GOLD, "#FFD36B"),               # 3 amarelo
    ("#4A8FEA", "#7DB4FF"),          # 4 azul
    (VISITED, "#D39BFF"),            # 5 magenta
    (CYAN, "#A6FBFF"),               # 6 ciano
    (TXT1, TXT1),                    # 7 branco (intenso no mesmo tom do Dolphin: branco puro cansa a vista)
]


def kc(h):
    return ",".join(str(v) for v in rgb(h))


def group(name, normal, intense):
    return (f"[{name}]\nColor={kc(normal)}\n\n"
            f"[{name}Intense]\nColor={kc(intense)}\n\n"
            f"[{name}Faint]\nColor={kc(mix(normal, BASE, 0.6))}\n\n")


def colorscheme():
    # Texto em negrito/intenso no mesmo tom do texto normal (o do Dolphin), sem branco puro.
    out = group("Background", BASE, PANEL) + group("Foreground", TXT1, TXT1)
    for i, (normal, intense) in enumerate(ANSI):
        out += group(f"Color{i}", normal, intense)
    out += "[General]\nDescription=CyberKDE\nOpacity=1\nBlur=false\nWallpaper=\n"
    return "# CyberKDE — gerado por generator/gen_konsole.py; não editar à mão\n\n" + out


PROFILE = f"""[Appearance]
AntiAliasFonts=true
BoldIntense=true
ColorScheme=CyberKDE
Font=JetBrains Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=1

[Cursor Options]
CursorShape=0
UseCustomCursorColor=true
CustomCursorColor={kc(CYAN)}
CustomCursorTextColor={kc(BASE)}

[General]
Name=CyberKDE
Parent=FALLBACK/
TerminalCenter=false
TerminalMargin=10
DimWhenInactive=false

[Terminal Features]
BlinkingCursorEnabled=false
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "CyberKDE.colorscheme").write_text(colorscheme())
    (OUT / "CyberKDE.profile").write_text(PROFILE)
    print(f"esquema de cores + perfil → {OUT}")


if __name__ == "__main__":
    main()
