#!/usr/bin/env python3
"""Ícones de aplicativos no estilo CyberKDE (placa chanfrada de moldura dupla + emblema do app).

Os de Dolphin, Konsole, Obsidian e Edge vêm da IA (assets/icons/ai-final). Os demais apps favoritos da
usuária são desenhados aqui, em vetor (SVG → PNG 512 com o Inkscape), com as cores do mestre
(vermelho #F04D44, escuro #11101B, ciano de acento), para o gen_icons.py recolorir pela paleta como os outros.

Uso:
  gen_apps_icons.py              grava assets/icons/apps/<id>.png e assets/icons/apps/apps.json
  gen_apps_icons.py --levantar   só leitura: favoritos (Latte, painéis do Plasma, Kickoff, mais usados),
                                 o .desktop e o Icon= de cada um e se o tema CyberKDE já o cobre (JSON)
  gen_apps_icons.py --prancha ARQ.png   prancha 32/48/128 px com os novos ao lado dos existentes
"""
import argparse
import json
import math
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = ROOT / "assets" / "icons" / "apps"

R, R2, R3, C, D = "#F04D44", "#B2403B", "#FF8A82", "#5EF6FF", "#11101B"  # vermelho do mestre, tons, ciano, escuro


# ---------------------------------------------------------------- peças
def P(pts, fill=R, extra=""):
    return f'<polygon points="{" ".join(f"{x:g},{y:g}" for x, y in pts)}" fill="{fill}" {extra}/>'


def L(d, w=7, cor=R, extra=""):
    return f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{w}" stroke-linejoin="miter" stroke-linecap="butt" {extra}/>'


def F(d, fill=R, extra=""):
    return f'<path d="{d}" fill="{fill}" {extra}/>'


def circ(x, y, r, fill=R, extra=""):
    return f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="{fill}" {extra}/>'


def ring(x, y, r, w=7, cor=R):
    return f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="none" stroke="{cor}" stroke-width="{w}"/>'


def cham(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def oct_(cx, cy, r):
    return [(cx + r * math.cos(math.radians(22.5 + 45 * k)), cy + r * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]


def wedge(cx, cy, r, a0, a1, fill):
    x0, y0, x1, y1 = (cx + r * math.cos(math.radians(a)) for a in (a0,)), 0, 0, 0
    p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
    p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
    return F(f"M{cx:g},{cy:g} L{p0[0]:.2f},{p0[1]:.2f} A{r:g},{r:g} 0 0 1 {p1[0]:.2f},{p1[1]:.2f} Z", fill)


# ---------------------------------------------------------------- emblemas (grade 0-100, centro em 50,50)
def g_jetbrains(letras):
    base = P(cham(20, 20, 80, 80, 6), R) + P([(26, 69), (50, 69), (50, 74), (26, 74)], C)
    if letras == "PC":
        t = L("M27,60 V29 H41 Q52,29 52,38 Q52,47 41,47 H27", 7, D) + L("M75,36 Q71,29 64,29 Q56,29 56,40 V49 Q56,60 64,60 Q71,60 75,53", 7, D)
    else:  # DG
        t = L("M27,29 H38 Q52,29 52,44 Q52,60 38,60 H27 Z", 7, D) + L("M76,36 Q72,29 64,29 Q56,29 56,44 Q56,60 64,60 Q74,60 76,50 H66", 7, D)
    return base + t


def g_database():
    o = ""
    for i, (y, c) in enumerate(((22, R3), (42, R), (62, R2))):
        o += F(f"M22,{y} A28,9 0 0 1 78,{y} V{y + 14} A28,9 0 0 1 22,{y + 14} Z", c)
        o += L(f"M22,{y + 4} A28,9 0 0 0 78,{y + 4}", 3, D)
    return o + circ(70, 49, 3.5, C) + circ(70, 69, 3.5, C)


def emblema_json(nome):
    """Silhueta real da marca vetorizada por generator/vetorizar_emblema.py."""
    return json.loads((OUT / "emblemas" / f"{nome}.json").read_text())


def g_steam(estilo="anel"):
    """Steam: a silhueta REAL do ícone que o app instala (disco, haste e os dois anéis da biela), vetorizada.
    estilo "disco": disco vermelho com a biela vazada em escuro; "anel": disco escuro com filete e biela vermelha."""
    e = emblema_json("steam")
    cx, cy, r = e["disco"]
    k = 39 / r
    tr = f'transform="translate(50 50) scale({k:.5f}) translate({-cx:g} {-cy:g})"'
    glifo = lambda cor: f'<path d="{e["d"]}" fill="{cor}" fill-rule="evenodd" {tr}/>'
    if estilo == "disco":
        return circ(50, 50, 39) + glifo(D)
    return circ(50, 50, 37.5, D, f'stroke="{R}" stroke-width="4.5"') + glifo(R)


# PyCharm: as formas e o "PC" do ícone que o app instala (/snap/pycharm/current/bin/pycharm.svg), com as
# formas coloridas reduzidas a dois tons e o quadrado escuro, o "PC" e a barra (o que identifica) mantidos.
def g_jetbrains_real(nome):
    """PyCharm/DataGrip: formas, quadrado, letras e barra do SVG que o app instala (em emblemas/<nome>.json), com
    as formas coloridas reduzidas a dois tons e o quadrado escuro, as letras e a barra mantidos."""
    e = emblema_json(nome)
    tr = 'transform="translate(50 50) scale(1.5) translate(-32 -32)"'
    f1, f2, f3 = e["formas"]
    formas = F(f3, R, tr) + F(f1, R2, tr) + F(f2, R2, tr)
    return (formas + F(e["quadrado"], D, tr + ' stroke="#FFFFFF" stroke-opacity=".45" stroke-width="0.7"')
            + F(e["letras"], "#FFFFFF", tr) + F(e["barra"], C, tr))


def g_pycharm():
    return g_jetbrains_real("pycharm")


def g_datagrip():
    return g_jetbrains_real("datagrip")


COR_MESTRE = {"R": R, "R2": R2, "R3": R3, "C": C, "D": D, "W": "#FFFFFF"}


def g_real(aid, extra=""):
    """Silhueta real do ícone que o app instala, vetorizada em camadas de cor-mestre
    (generator/vetorizar_apps.py → emblemas/<id>.json), ajustada para caber na placa."""
    e = emblema_json(aid)
    x0, y0, x1, y1 = e["caixa"]
    k = 78 / max(x1 - x0, y1 - y0)
    tr = f'transform="translate(50 50) scale({k:.5f}) translate({-(x0 + x1) / 2:g} {-(y0 + y1) / 2:g})"'
    return "".join(F(c["d"], COR_MESTRE[c["cor"]], f'fill-rule="evenodd" {tr}') for c in e["camadas"] if c["d"]) + extra


def g_chrome():
    o = wedge(50, 50, 36, -90, 30, R) + wedge(50, 50, 36, 30, 150, R2) + wedge(50, 50, 36, 150, 270, R3)
    return o + circ(50, 50, 19, D) + circ(50, 50, 12.5, C)


def g_claude():
    o = ""
    for k in range(12):
        a = math.radians(k * 30 - 90)
        L1 = 43 if k % 2 == 0 else 32
        ca, sa = math.cos(a), math.sin(a)
        nx, ny = -sa, ca
        pts = [(50 + ca * 7 + nx * 6, 50 + sa * 7 + ny * 6), (50 + ca * L1, 50 + sa * L1), (50 + ca * 7 - nx * 6, 50 + sa * 7 - ny * 6)]
        o += P(pts, R if k % 2 == 0 else R3)
    return o + circ(50, 50, 7, C)


def g_spotify():
    return (circ(50, 50, 37) + L("M26,38 Q50,29 76,40", 7.5, D) + L("M30,52 Q50,44 71,53", 6, D) + L("M34,64 Q50,58 66,65", 4.5, D) + circ(76, 40, 0.1, C))


def g_1password():
    return ring(50, 50, 36, 7) + F("M41,30 H59 V53 L55,59 V71 H45 V59 L41,53 Z") + circ(50, 41, 3.6, C)


def g_telegram():
    return circ(50, 50, 37) + P([(74, 29), (25, 48), (40, 55)], D) + P([(74, 29), (40, 55), (48, 72), (55, 60)], "#6B1F1C") + P([(74, 29), (55, 60), (68, 70)], D) + L("M74,29 L45,58", 2.5, C)


def g_obs():
    o = circ(50, 50, 37)
    for a in (-90, 30, 150):
        x, y = 50 + 17 * math.cos(math.radians(a)), 50 + 17 * math.sin(math.radians(a))
        o += f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="9" ry="19" fill="{D}" transform="rotate({a + 90} {x:.1f} {y:.1f})"/>'
    return o + circ(50, 50, 5, C)


def g_remmina():
    return (P(cham(18, 24, 82, 64, 6), D, f'stroke="{R}" stroke-width="7" stroke-linejoin="miter"') + P([(42, 66), (58, 66), (60, 74), (40, 74)]) + P([(32, 76), (68, 76), (68, 80), (32, 80)])
            + P([(30, 44), (42, 36), (42, 41), (58, 41), (58, 36), (70, 44), (58, 52), (58, 47), (42, 47), (42, 52)], C))


def g_filezilla():
    return P([(34, 20), (48, 38), (39, 38), (39, 72), (29, 72), (29, 38), (20, 38)]) + P([(66, 80), (52, 62), (61, 62), (61, 28), (71, 28), (71, 62), (80, 62)], R3) + L("M24,84 H76", 3.5, C)


def g_virtualbox():
    return P([(50, 14), (82, 32), (50, 50), (18, 32)], R3) + P([(18, 32), (50, 50), (50, 86), (18, 68)], R2) + P([(82, 32), (82, 68), (50, 86), (50, 50)], R) + L("M34,52 L50,62 L66,52", 3.5, C)


def g_kate():
    return (P([(22, 26), (52, 26), (52, 32), (22, 32)]) + P([(22, 40), (46, 40), (46, 46), (22, 46)], R3) + P([(22, 54), (40, 54), (40, 60), (22, 60)])
            + P([(66, 20), (80, 34), (50, 74), (44, 76), (46, 68)], R2) + P([(66, 20), (80, 34), (74, 41), (60, 27)], C))


def g_spectacle():
    o = ""
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        x, y = 50 + sx * 32, 50 + sy * 32
        o += L(f"M{x - sx * 16:g},{y:g} H{x:g} V{y - sy * 16:g}", 7.5)
    return o + ring(50, 50, 13, 6, C) + circ(50, 50, 4)


def g_gear(furos=C):
    pts = []
    n = 12
    for k in range(n * 2):
        a0 = (k * 180 / n) - 7.5
        r = 38 if k % 2 == 0 else 29
        for da in (0, 7.5 + (0)):
            pts.append((50 + r * math.cos(math.radians(a0 + da)), 50 + r * math.sin(math.radians(a0 + da))))
    return P(pts) + circ(50, 50, 13, D) + ring(50, 50, 13, 3.5, furos)


def g_monitor():
    return (L("M18,20 V80 H84", 5) + P([(24, 70), (36, 70), (36, 78), (24, 78)], R2) + P([(42, 58), (54, 58), (54, 78), (42, 78)], R) + P([(60, 40), (72, 40), (72, 78), (60, 78)], R3)
            + L("M20,50 L36,38 L50,46 L70,24 L84,30", 3.5, C))


def g_doc():
    return P([(24, 14), (60, 14), (78, 32), (78, 86), (24, 86)], R) + P([(60, 14), (78, 32), (60, 32)], R2) + P([(32, 46), (70, 46), (70, 52), (32, 52)], D) + P([(32, 60), (70, 60), (70, 66), (32, 66)], D) + P([(32, 72), (54, 72), (54, 77), (32, 77)], C)


def g_bag():
    return L("M38,40 V32 Q38,20 50,20 Q62,20 62,32 V40", 6) + P([(24, 40), (76, 40), (72, 84), (28, 84)], R) + P([(24, 40), (76, 40), (75, 48), (25, 48)], R2) + circ(50, 62, 8, C) + circ(50, 62, 3.5, D)


def g_vscode():
    return L("M40,28 L18,50 L40,72", 10) + L("M60,28 L82,50 L60,72", 10, R3) + L("M55,24 L45,76", 6, C)


def g_film():
    o = P(cham(20, 22, 80, 78, 5), D, f'stroke="{R}" stroke-width="6"')
    for y in (30, 42, 54, 66):
        o += P([(24, y), (30, y), (30, y + 5), (24, y + 5)]) + P([(70, y), (76, y), (76, y + 5), (70, y + 5)])
    return o + P([(42, 36), (62, 50), (42, 64)], C)


def g_layers():
    return P([(50, 18), (84, 34), (50, 50), (16, 34)], R3) + P([(16, 50), (50, 66), (84, 50), (84, 56), (50, 72), (16, 56)], R) + P([(16, 66), (50, 82), (84, 66), (84, 72), (50, 88), (16, 72)], R2) + circ(50, 34, 5, C)


def g_mesh():
    pts = [(50, 14), (84, 34), (84, 68), (50, 86), (16, 68), (16, 34)]
    o = P(pts, R2, f'stroke="{R}" stroke-width="5" stroke-linejoin="miter"')
    for a, b in ((0, 3), (1, 5), (2, 4), (1, 4), (0, 2), (0, 4)):
        o += L(f"M{pts[a][0]},{pts[a][1]} L{pts[b][0]},{pts[b][1]}", 2.6, R3)
    return o + circ(50, 50, 5, C)


def g_editor():
    return P([(22, 26), (78, 26), (78, 32), (22, 32)]) + P([(22, 40), (68, 40), (68, 46), (22, 46)], R3) + P([(22, 54), (58, 54), (58, 60), (22, 60)]) + P([(64, 52), (69, 52), (69, 76), (64, 76)], C)


def g_calc():
    o = P(cham(24, 14, 76, 86, 5), R) + P([(31, 22), (69, 22), (69, 38), (31, 38)], D)
    for r in range(3):
        for c in range(3):
            o += P([(31 + c * 14, 46 + r * 13), (40 + c * 14, 46 + r * 13), (40 + c * 14, 54 + r * 13), (31 + c * 14, 54 + r * 13)], C if (r, c) == (2, 2) else D)
    return o


# id → (nome legível, nomes do ícone (o primeiro é o arquivo), emblema)
APPS = {
    "pycharm": ("PyCharm", ["jetbrains-pycharm", "pycharm", "pycharm-community", "pycharm-professional", "pycharm-edu", "jetbrains-pycharm-ce", "pycharm_pycharm"], g_pycharm),
    "datagrip": ("DataGrip", ["datagrip", "jetbrains-datagrip"], g_datagrip),
    "dbeaver": ("DBeaver", ["dbeaver", "dbeaver-ce", "io.dbeaver.DBeaverCommunity", "dbeaver_dbeaver"], lambda: g_real("dbeaver")),
    "steam": ("Steam", ["steam", "steam_icon_steam", "com.valvesoftware.Steam", "steam-launcher"], g_steam),
    "google-chrome": ("Google Chrome", ["google-chrome", "google-chrome-stable", "google-chrome-beta", "chromium", "chromium-browser", "com.google.Chrome"], lambda: g_real("google-chrome")),
    "claude-desktop": ("Claude", ["claude-desktop", "com.anthropic.Claude", "claude", "claude-ai"], lambda: g_real("claude-desktop", circ(50, 50, 5.5, C))),
    "spotify": ("Spotify", ["spotify-client", "spotify", "com.spotify.Client"], lambda: g_real("spotify")),
    "1password": ("1Password", ["1password", "com.onepassword.OnePassword", "onepassword"], lambda: g_real("1password")),
    "telegram": ("Telegram", ["telegram", "org.telegram.desktop", "telegram-desktop", "org.telegram.desktop.desktop", "telegramdesktop"], lambda: g_real("telegram")),
    "obs-studio": ("OBS Studio", ["com.obsproject.Studio", "obs", "obs-studio"], lambda: g_real("obs-studio")),
    "remmina": ("Remmina", ["org.remmina.Remmina", "remmina", "remmina-main"], lambda: g_real("remmina")),
    "filezilla": ("FileZilla", ["filezilla", "org.filezilla_project.Filezilla"], lambda: g_real("filezilla")),
    "virtualbox": ("VirtualBox", ["virtualbox", "org.virtualbox.VirtualBox", "virtualbox-ose"], lambda: g_real("virtualbox")),
    "kate": ("Kate", ["kate", "org.kde.kate", "kate-symbolic-app"], lambda: g_real("kate")),
    "systemsettings": ("Configurações do sistema", ["systemsettings", "org.kde.systemsettings"], g_gear),
    "plasma-systemmonitor": ("Monitor do sistema", ["org.kde.plasma-systemmonitor", "org.kde.plasma.systemmonitor"], g_monitor),
    "libreoffice": ("LibreOffice", ["libreoffice-startcenter", "libreoffice-main", "libreoffice"], lambda: g_real("libreoffice")),
    "software": ("Loja de programas", ["kubuntu-manage-software", "org.kubuntu.manage-software", "snap-store", "org.gnome.Software", "org.kde.discover", "plasmadiscover"], lambda: g_real("software")),
    "vscode": ("Visual Studio Code", ["vscode", "code", "visual-studio-code", "com.visualstudio.code", "com.visualstudio.code.oss"], lambda: g_real("vscode")),
    "shotcut": ("Shotcut", ["org.shotcut.Shotcut", "shotcut"], lambda: g_real("shotcut")),
    "cura": ("Ultimaker Cura", ["cura-icon", "com.ultimaker.cura", "cura"], lambda: g_real("cura")),
    "meshmixer": ("Meshmixer", ["meshmixer"], lambda: g_real("meshmixer")),
    "text-editor": ("Editor de texto", ["org.gnome.TextEditor", "accessories-text-editor"], g_editor),
    "calculator": ("Calculadora", ["org.gnome.Calculator", "accessories-calculator", "org.kde.kcalc", "kcalc"], g_calc),
}


def tile(emblema):
    """Placa: octógono escuro com moldura dupla vermelha (como Edge e Obsidian) e o emblema no centro."""
    pts = lambda p: " ".join(f"{x:g},{y:g}" for x, y in p)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'<polygon points="{pts(cham(24, 24, 488, 488, 66))}" fill="{D}" stroke="{R}" stroke-width="14" stroke-linejoin="miter"/>'
            f'<polygon points="{pts(cham(54, 54, 458, 458, 44))}" fill="none" stroke="{R}" stroke-width="5" stroke-linejoin="miter"/>'
            f'<g transform="translate(256 256) scale(3.05) translate(-50 -50)">{emblema}</g></svg>\n')


# .desktop de cada app (para achar o ícone que ele instalou: ver apps_marca.localiza)
DESKTOPS = {
    "pycharm": ["pycharm_pycharm.desktop", "jetbrains-pycharm.desktop", "jetbrains-pycharm-ce.desktop"], "datagrip": ["datagrip.desktop"],
    "dbeaver": ["dbeaver-ce.desktop", "dbeaver.desktop"], "steam": ["steam.desktop"], "google-chrome": ["google-chrome.desktop"],
    "claude-desktop": ["com.anthropic.Claude.desktop", "claude-desktop.desktop"], "spotify": ["spotify.desktop"], "1password": ["1password.desktop"],
    "telegram": ["org.telegram.desktop.desktop", "telegramdesktop.desktop"], "obs-studio": ["com.obsproject.Studio.desktop"],
    "remmina": ["org.remmina.Remmina.desktop"], "filezilla": ["filezilla.desktop"], "virtualbox": ["virtualbox.desktop"],
    "kate": ["org.kde.kate.desktop"], "systemsettings": ["systemsettings.desktop"], "plasma-systemmonitor": ["org.kde.plasma-systemmonitor.desktop"],
    "libreoffice": ["libreoffice-startcenter.desktop"], "software": ["org.kubuntu.manage-software.desktop", "snap-store_snap-store.desktop"],
    "vscode": ["code.desktop"], "shotcut": ["org.shotcut.Shotcut.desktop"], "cura": ["com.ultimaker.cura.desktop"],
    "meshmixer": ["meshmixer.desktop"], "text-editor": ["org.gnome.TextEditor.desktop"], "calculator": ["org.gnome.Calculator.desktop"],
}

# .desktop cujo Icon= é um caminho de arquivo: o tema de ícones não alcança. Para o ícone do tema valer, o
# .desktop precisa de um override do usuário (~/.local/share/applications/<id>) com Icon=<nome>; quem aplica
# (reversível, put_file) é o orquestrador. O nome é o primeiro de APPS[...] do app.
OVERRIDES = {"pycharm_pycharm.desktop": "jetbrains-pycharm", "dbeaver-ce.desktop": "dbeaver", "datagrip.desktop": "datagrip",
             "snap-store_snap-store.desktop": "snap-store"}


def gera():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    with tempfile.TemporaryDirectory(prefix="cyberkde-apps-") as tmp:
        tmp = pathlib.Path(tmp)
        cmds = ""
        for aid, (nome, nomes, fn) in APPS.items():
            (tmp / f"{aid}.svg").write_text(tile(fn()))
            cmds += f"file-open:{tmp / (aid + '.svg')}; export-filename:{OUT / (aid + '.png')}; export-width:512; export-height:512; export-do; file-close\n"
            meta[aid] = {"nome": nome, "nomes": nomes, "desktops": DESKTOPS.get(aid, [])}
        subprocess.run(["inkscape", "--shell"], input=cmds, text=True, capture_output=True)
        for aid in APPS:
            if not (OUT / f"{aid}.png").is_file():
                subprocess.run(["inkscape", str(tmp / f"{aid}.svg"), "-o", str(OUT / f"{aid}.png"), "-w", "512", "-h", "512"], check=True, capture_output=True)
    (OUT / "apps.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n")
    (OUT / "desktop-icones.json").write_text(json.dumps(OVERRIDES, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(meta)} ícones em {OUT}")


# ---------------------------------------------------------------- levantamento (só leitura)
def desktop_dirs():
    h = pathlib.Path.home()
    return [pathlib.Path("/usr/share/applications"), h / ".local/share/applications", pathlib.Path("/var/lib/snapd/desktop/applications"),
            h / ".local/share/flatpak/exports/share/applications", pathlib.Path("/var/lib/flatpak/exports/share/applications")]


def acha_desktop(did):
    for d in desktop_dirs():
        if (d / did).is_file():
            return d / did
    return None


def icone_do(f):
    nome = ""
    for ln in f.read_text(errors="ignore").splitlines():
        if ln.startswith("Icon="):
            nome = ln[5:].strip()
            break
    return nome


def cobertura(nome):
    """"tema" (nosso, com estilo), "breeze" (cai no Breeze/hicolor), "caminho" (o .desktop aponta para um arquivo: o tema não alcança)."""
    if not nome:
        return "sem-icone"
    if nome.startswith("/"):
        return "caminho"
    for a in APPS.values():
        if nome in a[1]:
            return "tema"
    if nome in ("org.kde.dolphin", "system-file-manager", "utilities-terminal", "org.kde.konsole", "microsoft-edge", "obsidian", "com.microsoft.Edge", "md.obsidian.Obsidian"):
        return "tema"
    return "breeze"


def levantar():
    h = pathlib.Path.home()
    itens = {}

    def add(did, origem):
        if did.startswith("preferred://"):
            itens.setdefault(did, {"desktop": None, "icon": "", "origens": []})["origens"].append(origem)
            return
        did = did.split(":", 1)[1] if did.startswith("applications:") else did
        did = did if did.endswith(".desktop") else did + ".desktop"
        e = itens.setdefault(did, {"desktop": None, "icon": "", "origens": []})
        f = acha_desktop(did)
        e["desktop"], e["icon"] = (str(f), icone_do(f)) if f else (None, "")
        if origem not in e["origens"]:
            e["origens"].append(origem)
    for lay in sorted((h / ".config/latte").glob("*.layout.latte*")):
        for ln in lay.read_text(errors="ignore").splitlines():
            if ln.startswith("launchers59="):
                for item in ln.split("=", 1)[1].split(","):
                    if item.strip():
                        add(item.strip(), "latte")
    ap = h / ".config/plasma-org.kde.plasma.desktop-appletsrc"
    if ap.is_file():
        for ln in ap.read_text(errors="ignore").splitlines():
            if ln.startswith(("launchers=", "favorites=")):
                for item in ln.split("=", 1)[1].split(","):
                    if item.strip():
                        add(item.strip(), "painel")
    db = h / ".local/share/kactivitymanagerd/resources/database"
    if db.is_file():
        c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        for (r,) in c.execute("select targettedResource from ResourceLink where initiatingAgent='org.kde.plasma.favorites.applications'"):
            add(r, "kickoff")
        for r, s in c.execute("select targettedResource,sum(cachedScore) from ResourceScoreCache where targettedResource like 'applications:%' group by targettedResource order by 2 desc limit 20"):
            add(r, f"mais-usado({s:.0f})")
    out = []
    for did, e in itens.items():
        out.append({"desktop_id": did, "arquivo": e["desktop"], "icone": e["icon"], "estado": cobertura(e["icon"]) if e["desktop"] else "sem-desktop", "origens": e["origens"]})
    return out


# ---------------------------------------------------------------- prancha
def prancha(arq):
    from PIL import Image, ImageDraw
    novos = list(APPS)
    velhos = ["org.kde.dolphin", "utilities-terminal", "microsoft-edge", "obsidian"]
    linhas = [("já existentes (IA)", [(n, ROOT / "assets" / "icons" / "ai-final" / f"{n}.png") for n in velhos]),
              ("novos", [(n, OUT / f"{n}.png") for n in novos])]
    cols = 9
    cw = 128 + 20
    total = sum(math.ceil(len(i) / cols) for _, i in linhas)
    S = Image.new("RGB", (cols * cw + 10, total * 250 + 40 * len(linhas) + 10), (18, 18, 28))
    d = ImageDraw.Draw(S)
    y = 6
    for titulo, itens in linhas:
        d.text((10, y), titulo, fill=(220, 220, 228))
        y += 22
        for i, (n, p) in enumerate(itens):
            if i and i % cols == 0:
                y += 250
            x = 10 + (i % cols) * cw
            im = Image.open(p).convert("RGBA")
            S.paste(im.resize((128, 128), Image.LANCZOS), (x, y), im.resize((128, 128), Image.LANCZOS))
            S.paste(im.resize((48, 48), Image.LANCZOS), (x, y + 134), im.resize((48, 48), Image.LANCZOS))
            S.paste(im.resize((32, 32), Image.LANCZOS), (x + 60, y + 134), im.resize((32, 32), Image.LANCZOS))
            S.paste(im.resize((22, 22), Image.LANCZOS), (x + 106, y + 134), im.resize((22, 22), Image.LANCZOS))
            d.text((x, y + 180), n[:20], fill=(169, 169, 186))
        y += 250
    S.save(arq)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levantar", action="store_true")
    ap.add_argument("--prancha", default="")
    a = ap.parse_args()
    if a.levantar:
        print(json.dumps(levantar(), ensure_ascii=False, indent=1))
    elif a.prancha:
        prancha(a.prancha)
    else:
        gera()


if __name__ == "__main__":
    main()
