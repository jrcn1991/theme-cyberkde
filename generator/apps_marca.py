"""Ícones de apps no estilo "logo original dentro da moldura CyberKDE", gerados NA INSTALAÇÃO a partir do ícone
que o próprio app instalou na máquina (hicolor do usuário ou do sistema, pixmaps, flatpak, snap, Icon= do
.desktop). Nenhum logo de marca é versionado: o repositório só tem este gerador e a moldura (desenhada aqui).

Estilos (o gen_icons.py escolhe):
  marca       logo original com as cores da marca; só a moldura usa o destaque
  recolorido  logo original nos tons do destaque (o que tem cor vira escala do vermelho-mestre; preto, branco e cinza ficam),
              que o recolor normal do tema leva para o destaque atual
App sem ícone instalado: localiza() devolve None e o chamador cai na silhueta.
"""
import math
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw

HOME = pathlib.Path.home()
DESKTOP_DIRS = [HOME / ".local/share/applications", pathlib.Path("/usr/share/applications"), pathlib.Path("/var/lib/snapd/desktop/applications"),
                HOME / ".local/share/flatpak/exports/share/applications", pathlib.Path("/var/lib/flatpak/exports/share/applications")]
ICON_ROOTS = [HOME / ".local/share/icons/hicolor", pathlib.Path("/usr/share/icons/hicolor"),
              HOME / ".local/share/flatpak/exports/share/icons/hicolor", pathlib.Path("/var/lib/flatpak/exports/share/icons/hicolor"),
              pathlib.Path("/var/lib/snapd/desktop/icons/hicolor")]
PIXMAPS = [pathlib.Path("/usr/share/pixmaps"), HOME / ".local/share/pixmaps"]
CAIXA = 336            # lado máximo do logo dentro da moldura de 512
MESTRE_R, MESTRE_D = "#F04D44", "#11101B"  # vermelho e escuro do mestre (cyberlib.recolor)


def _desktop_icons(did):
    """Os Icon= de TODOS os .desktop com esse id (um override do usuário pode apontar para o nome do tema, e o
    original do sistema ou do snap para o arquivo do app)."""
    achados = []
    for d in DESKTOP_DIRS:
        f = d / did
        if f.is_file():
            for ln in f.read_text(errors="ignore").splitlines():
                if ln.startswith("Icon="):
                    achados.append(ln[5:].strip())
                    break
    return achados


def _rasters_e_svg(nome):
    """Arquivos do app com esse nome: [(tamanho, caminho)] (svg = 0)."""
    achados = []
    for raiz in ICON_ROOTS:
        if not raiz.is_dir():
            continue
        for pasta in raiz.iterdir():
            apps = pasta / "apps"
            for ext in ("png", "svg"):
                f = apps / f"{nome}.{ext}"
                if f.is_file():
                    m = re.match(r"(\d+)x\d+", pasta.name)
                    achados.append((0 if ext == "svg" else (int(m.group(1)) if m else 1), f))
    for raiz in PIXMAPS:
        for ext in ("png", "svg"):
            f = raiz / f"{nome}.{ext}"
            if f.is_file():
                achados.append((0 if ext == "svg" else _lado_png(f), f))
    return achados


def _lado_png(f):
    try:
        with Image.open(f) as im:
            return max(im.size)
    except OSError:
        return 1


def _tem_inkscape():
    return shutil.which("inkscape") is not None


def localiza(nomes, desktops):
    """O melhor arquivo de ícone instalado para um app: raster grande (>= 256) se houver; senão o SVG; senão o maior raster."""
    candidatos = []
    nomes = list(nomes)
    for did in desktops:
        for ic in _desktop_icons(did):
            if ic.startswith("/"):
                p = pathlib.Path(ic)
                if p.is_file():
                    candidatos.append((0 if p.suffix == ".svg" else _lado_png(p), p))
            else:
                nomes.append(ic)
    for n in dict.fromkeys(nomes):
        candidatos += _rasters_e_svg(n)
    candidatos = [c for c in candidatos if c[1].suffix in (".png", ".svg") and "/CyberKDE/" not in str(c[1])]
    if not candidatos:
        return None
    rasters = sorted((c for c in candidatos if c[0] > 0), reverse=True)
    svgs = [c for c in candidatos if c[0] == 0]
    if rasters and rasters[0][0] >= 256:
        return rasters[0][1]
    if svgs and _tem_inkscape():
        return svgs[0][1]
    return rasters[0][1] if rasters else None


def carrega(src, lado):
    """O ícone no maior lado `lado` (mantém a proporção), em RGBA."""
    if src.suffix == ".svg":
        with tempfile.TemporaryDirectory() as t:
            p = pathlib.Path(t) / "i.png"
            subprocess.run(["inkscape", str(src), "-o", str(p), "-w", str(lado), "-h", str(lado)], check=True, capture_output=True)
            return Image.open(p).convert("RGBA")
    im = Image.open(src).convert("RGBA")
    k = lado / max(im.size)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


# ---------------------------------------------------------------- moldura (desenhada aqui, sem marca)
def _cham(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def placa(borda, fundo=MESTRE_D, ss=4):
    """Octógono escuro de moldura dupla (a mesma placa dos ícones do tema), com a moldura na cor `borda`."""
    S = 512 * ss
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = 2 - math.sqrt(2)

    def poli(x0, y0, x1, y1, c, o, cor):  # octógono deslocado de `o` (positivo = para fora), em px de 512
        d.polygon([(x * ss, y * ss) for x, y in _cham(x0 - o, y0 - o, x1 + o, y1 + o, c + o * k)], fill=cor)
    for (x0, y0, x1, y1, c, w) in ((24, 24, 488, 488, 66, 14), (54, 54, 458, 458, 44, 5)):
        poli(x0, y0, x1, y1, c, w / 2, borda)
        poli(x0, y0, x1, y1, c, -w / 2, fundo)
    return im.resize((512, 512), Image.LANCZOS)


# ---------------------------------------------------------------- recolorido
def tinge(im):
    """Partes com cor viram a escala do vermelho-mestre (escuro → vermelho → claro, pela luminosidade);
    preto, branco e cinza ficam. Precisa do numpy; sem ele devolve o logo como está."""
    try:
        import numpy as np
    except ImportError:
        return im
    a = np.asarray(im).astype(float)
    rgbv = a[..., :3] / 255
    mx, mn = rgbv.max(-1), rgbv.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    pesos = np.array([.299, .587, .114])
    L = rgbv @ pesos
    h = lambda c: np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], float) / 255
    R, D, W = h(MESTRE_R), h(MESTRE_D), np.ones(3)
    Lr = float(R @ pesos)
    k = np.clip(L / Lr, 0, 1)[..., None]
    w = np.clip((L - Lr) / (1 - Lr), 0, 1)[..., None]
    mestre = np.where((L <= Lr)[..., None], D + (R - D) * k, R + (W - R) * w)
    peso = np.clip((s - 0.18) / 0.22, 0, 1)[..., None]
    a[..., :3] = (rgbv * (1 - peso) + mestre * peso) * 255
    return Image.fromarray(a.round().astype(np.uint8))


def compoe(src, estilo, destaque, tmp, accented):
    """PNG 512 do ícone: `src` (arquivo do ícone instalado), `estilo` marca|recolorido, `destaque` (hex) da moldura.
    `accented(arquivo)` é o recolor do tema (cyberlib.accented com o vermelho-mestre do gen_icons)."""
    logo = carrega(src, CAIXA)
    if estilo == "recolorido":
        placa_img = placa(MESTRE_R)
        logo = tinge(logo)
    else:
        placa_img = placa(destaque)
    placa_img.alpha_composite(logo, ((512 - logo.width) // 2, (512 - logo.height) // 2))
    saida = pathlib.Path(tmp) / f"app-{estilo}-{abs(hash(str(src)))}.png"
    placa_img.save(saida)
    return accented(saida) if estilo == "recolorido" else saida


# ---------------------------------------------------------------- grade de conferência
def grade(itens, arq):
    """itens: [(nome, caminho do PNG)] → grade com 128 e 48 px sobre o fundo escuro."""
    from PIL import ImageFont
    cols = 6
    fonte = None
    for f in ("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.isfile(f):
            fonte = ImageFont.truetype(f, 12)
            break
    S = Image.new("RGB", (cols * 170 + 10, ((len(itens) + cols - 1) // cols) * 200 + 10), (18, 18, 28))
    dr = ImageDraw.Draw(S)
    for i, (nome, p) in enumerate(itens):
        x, y = 10 + (i % cols) * 170, 8 + (i // cols) * 200
        im = Image.open(p).convert("RGBA")
        g = im.resize((128, 128), Image.LANCZOS)
        S.paste(g, (x, y), g)
        for sz, dx in ((48, 0), (32, 60), (22, 100)):
            t = im.resize((sz, sz), Image.LANCZOS)
            S.paste(t, (x + dx, y + 136), t)
        # nome longo: corta o nome, não a marca " [silhueta]" do fim
        base, _, marca = nome.partition(" [")
        marca = f" [{marca}" if marca else ""
        if len(nome) > 26:
            nome = base[:max(1, 25 - len(marca))] + "…" + marca
        dr.text((x, y + 176), nome, font=fonte, fill=(220, 220, 228))
    S.save(arq)
