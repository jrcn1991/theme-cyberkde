#!/usr/bin/env python3
"""Gera o módulo "login" do CyberKDE a partir de tokens/cyberkde.json.

Saídas (em modules/login/build/, sempre recriadas):
- sddm/cyberkde/                       tema SDDM  -> /usr/share/sddm/themes/cyberkde (fase login, com sudo)
- look-and-feel/org.cyberkde.desktop/  pacote só com o splash -> ~/.local/share/plasma/look-and-feel
- lockscreen/                          LockScreen.qml + cyberkde/ -> pasta lockscreen do shell do Plasma
                                       (fase opcional login-bloqueio, com sudo)
- wallpaper/login.png                  fundo usado pela tela de bloqueio padrão (fase login)

O código-fonte são os QML de modules/login/src/. Aqui só se gera o singleton CK.qml (cores, medidas e
tempos vindos dos tokens), o fundo de reserva e os metadados, e se monta cada pacote.
"""
import json
import os
import pathlib
import shutil
import sys

MOD = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(MOD.parent.parent / "generator"))
from cyberlib import *  # noqa: E402,F401,F403  (ROOT, TOK, RED, CYAN, BASE, ..., rgb, mix)

SRC = MOD / "src"
BUILD = MOD / "build"
PREVIEW = MOD / "preview"
WALLPAPER = ROOT / "assets" / "wallpapers" / "login.png"  # gerado por outro agente, se existir
FONTS = ROOT / "assets" / "fonts"

UI_FONT = "Noto Sans"  # conforto de leitura: fonte do sistema e nunca condensada em texto de leitura
# Tempos da seção 13.1 do documento que ainda não estão nos tokens.
MOTION_DOC = {"context": 320, "scan": 450, "stagger": 30, "introTotal": 820}

SDDM_METADATA = f"""[SddmGreeterTheme]
Name=CyberKDE
Description=Neo-military login screen with chamfered panels and a short scan intro
Description[pt_BR]=Tela de login neomilitar, com painéis chanfrados e uma varredura curta na entrada
Author={AUTHOR}
License={LICENSE}
Website={WEBSITE}
Type=sddm-theme
Version={VERSION}
Screenshot=preview.png
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=cyberkde
Theme-API=2.0
QtVersion=6
"""

SDDM_THEMECONF = """[General]
# Fundo: caminho relativo a esta pasta ou absoluto.
background=background.png
# Velocidade das animações (1 = normal, 0 = sem animação). O SDDM não lê a preferência do usuário.
animationFactor=1
showClock=true
needsFullUserModel=true
"""

LNF_METADATA = {
    "KPackageStructure": "Plasma/LookAndFeel",
    "KPlugin": {
        "Authors": [{"Name": AUTHOR}],
        "Description": "CyberKDE startup splash. Contains only the splash screen, not a full global theme.",
        "Description[pt_BR]": "Splash de inicialização do CyberKDE. Só contém o splash, não é um tema global completo.",
        "Id": "org.cyberkde.desktop",
        "License": LICENSE,
        "Name": "CyberKDE (splash)",
        "Version": VERSION,
        "Website": WEBSITE,
    },
    "X-Plasma-APIVersion": "2",
}


def ck_qml():
    g, m = TOK["geometry"], TOK["motion"]
    colors = {
        "red": RED, "cyan": CYAN, "base": BASE, "panel": PANEL, "raised": RAISED, "input": INPUT,
        "txt1": TXT1, "txt2": TXT2, "txtd": TXTD, "textOnRed": ONRED, "line": LINE,  # "onX" seria sinal no QML
        "controlLine": CONTROL_LINE, "gold": GOLD, "green": GREEN,
        "danger": DANGER,  # erro de senha: sempre vermelho, qualquer que seja a cor de destaque
    }
    ints = {
        "chamferSmall": g["chamferSmall"],
        "chamferButton": 2 * g["unit"],               # chanfro padrão do documento (8 px)
        "chamferPanel": g["chamferWide"] + g["unit"],  # chanfro amplo de painel grande (16 px)
        "markerWidth": g["markerWidth"],
        "band": g["unit"],                            # faixa vermelha lateral (4 px)
        "focusWidth": TOK["focus"]["width"],
        **{k: m[k] for k in ("press", "micro", "fast", "standard", "close", "modal")},
        **MOTION_DOC,
    }
    reals = {"hover": HOV, "selected": SEL, "pressed": PRS, "brand": BRAND}
    strings = {"fontUi": UI_FONT, "fontIdentity": TOK["font"]["identity"]}

    lines = [
        "// GERADO por modules/login/generator/gen_login.py a partir de tokens/cyberkde.json. Não editar.",
        "pragma Singleton",
        "import QtQuick",
        "",
        "QtObject {",
    ]
    lines += [f'    readonly property color {k}: "{v}"' for k, v in colors.items()]
    lines += [f"    readonly property int {k}: {v}" for k, v in ints.items()]
    lines += [f"    readonly property real {k}: {v}" for k, v in reals.items()]
    lines += [f'    readonly property string {k}: "{v}"' for k, v in strings.items()]
    marks = "false" if WALLPAPER.is_file() else "true"
    lines += [
        "    // Brackets e réguas desenhados por cima do fundo: só no fundo de reserva (o papel de parede já os tem).",
        f"    readonly property bool backdropMarks: {marks}",
        "",
        "    // Fator de velocidade das animações (a raiz de cada tela define; 0 = sem animação).",
        "    property real factor: 1",
        "",
        "    function dur(ms) { return Math.round(ms * factor) }",
        "    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }",
        "    function css(c, a) {",
        '        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","'
        ' + Math.round(c.b * 255) + "," + a + ")"',
        "    }",
        "    // Curva de entrada do documento: Bézier cúbica (0.2, 0, 0, 1).",
        "    function ease(x) {",
        "        if (x <= 0) return 0",
        "        if (x >= 1) return 1",
        "        let lo = 0, hi = 1, s = x",
        "        for (let i = 0; i < 22; i++) {",
        "            s = (lo + hi) / 2",
        "            const bx = 0.6 * s * (1 - s) * (1 - s) + s * s * s",
        "            if (bx < x) lo = s; else hi = s",
        "        }",
        "        return 3 * s * s - 2 * s * s * s",
        "    }",
        "    // Progresso (0..1, com a curva) de uma camada que começa em start e dura d, no instante t.",
        "    function ramp(t, start, d) {",
        "        if (d <= 0) return t >= start ? 1 : 0",
        "        return ease((t - start) / d)",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


def fallback_background(dst, w=1920, h=1080):
    """Fundo de reserva: gradiente escuro, brilhos muito fracos e trama técnica só nas margens."""
    from PIL import Image, ImageChops, ImageDraw, ImageFilter

    top, low = rgb(mix(TXT1, BASE, 0.035)), rgb(mix("#000000", BASE, 0.35))
    small = Image.new("RGB", (32, 18))
    for y in range(18):
        for x in range(32):
            a = x / 31 * 0.55 + y / 17 * 0.45
            small.putpixel((x, y), tuple(round(top[i] + (low[i] - top[i]) * a) for i in range(3)))
    img = small.resize((w, h), Image.BICUBIC).convert("RGBA")

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((-520, h - 430, 720, h + 500), fill=rgb(RED) + (30,))
    d.ellipse((w - 640, -430, w + 430, 390), fill=rgb(CYAN) + (16,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(170)))

    # hachura a 45° multiplicada por uma máscara que só existe perto das bordas
    hatch = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(hatch)
    for k in range(-h, w, 9):
        d.line((k, 0, k + h, h), fill=255, width=1)
    edge = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(edge)
    band = 260
    for i in range(band, -1, -1):
        d.rectangle((i, i, w - 1 - i, h - 1 - i), outline=round(255 * (1 - i / band) ** 2))
    mask = ImageChops.multiply(hatch, edge).point(lambda v: round(v * 0.05))
    tint = Image.new("RGBA", (w, h), rgb(TXT1) + (0,))
    tint.putalpha(mask)
    img = Image.alpha_composite(img, tint)

    # linhas de varredura muito leves
    scan = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(scan)
    for y in range(0, h, 4):
        d.line((0, y, w, y), fill=(0, 0, 0, 20))
    img = Image.alpha_composite(img, scan)

    # cruzes de enquadramento e uma régua discreta
    marks = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(marks)
    c = rgb(TXT1) + (46,)
    for x, y in ((150, 132), (w - 150, 132), (150, h - 132), (w - 150, h - 132)):
        d.line((x - 8, y, x + 8, y), fill=c)
        d.line((x, y - 8, x, y + 8), fill=c)
    y = h - 132
    d.line((190, y, 520, y), fill=rgb(TXT1) + (22,))
    for i, x in enumerate(range(190, 521, 22)):
        d.line((x, y, x, y - (6 if i % 5 == 0 else 3)), fill=rgb(TXT1) + (30,))
    d.line((w - 520, 132, w - 190, 132), fill=rgb(RED) + (60,))
    img = Image.alpha_composite(img, marks)
    img.convert("RGB").save(dst, optimize=True)


def components_into(dst):
    dst.mkdir(parents=True, exist_ok=True)
    names = []
    for f in sorted((SRC / "common").glob("*.qml")):
        shutil.copyfile(f, dst / f.name)
        names.append(f.stem)
    (dst / "CK.qml").write_text(ck_qml())
    qmldir = ["# GERADO por modules/login/generator/gen_login.py", "singleton CK 1.0 CK.qml"]
    qmldir += [f"{n} 1.0 {n}.qml" for n in names]
    (dst / "qmldir").write_text("\n".join(qmldir) + "\n")


def publish_modes(top):
    """O projeto usa umask 007; o SDDM (usuário sddm) e o greeter precisam ler tudo: 755/644."""
    for p in [top, *top.rglob("*")]:
        os.chmod(p, 0o755 if p.is_dir() else 0o644)


def main():
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)

    bg = BUILD / "background.png"
    if WALLPAPER.is_file():
        shutil.copyfile(WALLPAPER, bg)
        origin = f"papel de parede {WALLPAPER.relative_to(ROOT)}"
    else:
        fallback_background(bg)
        origin = "fundo de reserva gerado (assets/wallpapers/login.png não existe)"

    # SDDM
    sddm = BUILD / "sddm" / "cyberkde"
    components_into(sddm / "components")
    shutil.copyfile(SRC / "sddm" / "Main.qml", sddm / "Main.qml")
    shutil.copyfile(bg, sddm / "background.png")
    (sddm / "metadata.desktop").write_text(SDDM_METADATA)
    (sddm / "theme.conf").write_text(SDDM_THEMECONF)
    if (PREVIEW / "login.png").is_file():
        shutil.copyfile(PREVIEW / "login.png", sddm / "preview.png")

    # tela de bloqueio (fase opcional)
    lock = BUILD / "lockscreen"
    components_into(lock / "cyberkde")
    shutil.copyfile(SRC / "lockscreen" / "LockScreen.qml", lock / "LockScreen.qml")
    shutil.copyfile(bg, lock / "cyberkde" / "background.png")

    # splash (pacote look-and-feel só com o splash)
    lnf = BUILD / "look-and-feel" / "org.cyberkde.desktop"
    splash = lnf / "contents" / "splash"
    components_into(splash / "components")
    shutil.copyfile(SRC / "splash" / "Splash.qml", splash / "Splash.qml")
    (splash / "images").mkdir()
    shutil.copyfile(bg, splash / "images" / "background.png")
    (splash / "fonts").mkdir()
    for f in ("Orbitron-VariableFont_wght.ttf", "OFL-Orbitron.txt"):
        shutil.copyfile(FONTS / f, splash / "fonts" / f)
    (lnf / "metadata.json").write_text(json.dumps(LNF_METADATA, indent=4, ensure_ascii=False) + "\n")
    if (PREVIEW / "splash.png").is_file():
        (lnf / "contents" / "previews").mkdir()
        shutil.copyfile(PREVIEW / "splash.png", lnf / "contents" / "previews" / "splash.png")

    # fundo da tela de bloqueio padrão (usado pela fase login via kscreenlockerrc)
    (BUILD / "wallpaper").mkdir()
    shutil.move(bg, BUILD / "wallpaper" / "login.png")

    publish_modes(BUILD)
    print(f"login: fundo = {origin}")
    print(f"login: gerado em {BUILD}")


if __name__ == "__main__":
    main()
