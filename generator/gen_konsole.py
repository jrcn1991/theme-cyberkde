#!/usr/bin/env python3
"""Gera o esquema de cores e o perfil do Konsole "CyberKDE" a partir de tokens/cyberkde.json."""
import struct
import zlib

from cyberlib import *  # noqa: F403 — tokens e cores compartilhados

OUT = ROOT / "themes" / "konsole"
# Textura de fundo (opção de estilo V30, desligada por padrão): um ladrilho PNG transparente que o
# Konsole desenha por cima da cor de fundo (chave Wallpaper do esquema). O ladrilho é gerado fora do
# repositório (~/.cache/cyberkde/konsole, como os ícones recoloridos), e o Konsole só aceita caminho
# absoluto: o esquema aponta para a cópia instalada em ~/.local/share/konsole (modules/estilo copia).
TEXTURA = ESTILO["textura"] if ESTILO["textura_onde"] in ("ambos", "konsole") else "lisa"
DATA = pathlib.Path(os.environ.get("XDG_DATA_HOME") or pathlib.Path.home() / ".local" / "share")
TEXTURA_ARQ = f"CyberKDE-textura-{TEXTURA}.png"
TEXTURA_CACHE = CACHE / "konsole"


def png(w, h, pixel):
    """PNG RGBA mínimo (sem dependências); pixel(x, y) -> (r, g, b, a)."""
    raw = b"".join(b"\0" + b"".join(bytes(pixel(x, y)) for x in range(w)) for y in range(h))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def textura_png():
    """Grade a cada 24 px ou scanline a cada 3 px, com 4% de opacidade: aparece sem disputar com o texto."""
    r, g, b = rgb(TXT1)
    a = round(255 * 0.04)
    if TEXTURA == "grade":
        return png(24, 24, lambda x, y: (r, g, b, a if x == 0 or y == 0 else 0))
    return png(1, 3, lambda x, y: (r, g, b, a if y == 0 else 0))

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
    papel = "" if TEXTURA == "lisa" else str(DATA / "konsole" / TEXTURA_ARQ)
    out += f"[General]\nDescription=CyberKDE\nOpacity=1\nBlur=false\nWallpaper={papel}\n"
    if papel:
        out += "FillStyle=Tile\nWallpaperOpacity=1\n"
    return "# CyberKDE — gerado por generator/gen_konsole.py; não editar à mão\n\n" + out


# V21: título técnico nas abas ("TTY-3 │ pasta"); no padrão o perfil não define (fica o do Konsole).
TABS = ("LocalTabTitleFormat=TTY-%# │ %d\nRemoteTabTitleFormat=NET-%# │ %u@%H\n"
        if ESTILO["konsole_abas"] == "tecnico" else "")

# AlternatingBars=0: com a integração do shell (efeito konsole-erro), o Konsole desenharia uma barra
# cinza alternada ao lado da saída de cada comando, que é só ruído (generator/PEDIDO-DO-CLI.md).
PROFILE = f"""[Appearance]
AntiAliasFonts=true
BoldIntense=true
ColorScheme=CyberKDE
Font=JetBrains Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing={ {"compacto": 0, "espacoso": 3}.get(ESTILO["densidade"], 1)}

[Cursor Options]
CursorShape=0
UseCustomCursorColor=true
CustomCursorColor={kc(CYAN)}
CustomCursorTextColor={kc(BASE)}

[General]
Name=CyberKDE
Parent=FALLBACK/
TerminalCenter=false
TerminalMargin={dens(10)}
DimWhenInactive=false
AlternatingBars=0
{TABS}
[Terminal Features]
BlinkingCursorEnabled=false
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "CyberKDE.colorscheme").write_text(colorscheme())
    (OUT / "CyberKDE.profile").write_text(PROFILE)
    # Sobras de versões que gravavam o ladrilho em themes/ (não versionado) e ladrilhos antigos do cache.
    for old in [*OUT.glob("CyberKDE-textura-*.png"), *TEXTURA_CACHE.glob("CyberKDE-textura-*.png")]:
        old.unlink()
    if TEXTURA != "lisa":
        TEXTURA_CACHE.mkdir(parents=True, exist_ok=True)
        (TEXTURA_CACHE / TEXTURA_ARQ).write_bytes(textura_png())
    print(f"esquema de cores + perfil → {OUT}")


if __name__ == "__main__":
    main()
