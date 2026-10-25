#!/usr/bin/env python3
"""Ícones do botão do menu (Kickoff) da barra e da dock.

    gen_menu.py <pasta-generator> <pasta-saida> <pasta-hicolor> [logo]

Sem logo: os quatro blocos do tema, na cor de destaque. Com o logo da corporação ("cyberkde corp"):
na barra, o logo sozinho; na dock, o logo sobre o fundo escuro arredondado.

O ícone vai para o tema hicolor do usuário (<pasta-hicolor>/<tamanho>/apps/) com um NOME, e o Kickoff
aponta para o nome, não para um arquivo. Assim o QIcon escolhe o tamanho certo:
- desenho vetorial (os blocos, um SVG de verdade): um SVG em scalable/apps;
- desenho raster (PNG, ou SVG que só embute um PNG, como os ícones oficiais das corporações): um PNG
  por tamanho, reduzido com Lanczos. Apontar o Kickoff para um SVG com o PNG embutido deixava o ícone
  SERRILHADO: o QtSvg desenha a imagem embutida reduzindo-a sem suavização (de 512 para 22 px).
O nome leva um resumo do conteúdo (cyberkde-menu-<hash>): um logo novo é um nome novo, e nenhum cache
de ícones (o do KDE fica em disco, entre sessões) devolve a imagem antiga. Os de antes são apagados.

Grava também <pasta-saida>/menu.svg e menu-barra.svg (o caminho antigo, para uma barra configurada por
uma versão anterior do tema que ainda aponte para eles) e <pasta-saida>/menu-icones, com os nomes da
dock e da barra, uma linha cada.
"""
import base64
import hashlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

sys.path.insert(0, sys.argv[1])
from cyberlib import RED  # noqa: E402

SAIDA, HICOLOR = pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
LOGO = sys.argv[4] if len(sys.argv) > 4 else ""
SVG, XLINK = "http://www.w3.org/2000/svg", "http://www.w3.org/1999/xlink"
# Tamanhos do hicolor que o Plasma pede para um botão de painel (barra de 33 px, dock de 48 px, telas
# com escala 1,25 a 2): o QIcon pega o mais próximo e quase não precisa reduzir.
TAMANHOS = (16, 22, 24, 32, 48, 64, 96, 128, 256)

r, g, b = (int(RED[i:i + 2], 16) for i in (1, 3, 5))
mix = lambda t, k: "#%02x%02x%02x" % tuple(round(c + (t - c) * k) for c in (r, g, b))
fundo, claro, claro2 = mix(0, 0.69), mix(255, 0.55), mix(255, 0.72)
FUNDO = f'<rect x="15" y="15" width="482" height="482" rx="101" fill="{fundo}"/>'
# Medidas no quadro de 512: fundo da dock (15..497, raio 101), logo na dock (320) e na barra. Na barra,
# um PNG solto ocupa 448 (margem própria do tema); o de um SVG, o quadro inteiro, como o SVG desenha.
LOGO_DOCK = 320 / 512
LOGO_BARRA = {"png": 448 / 512, "svg": 1.0}


def blocos():
    """(dock, barra) em SVG: os blocos do tema. O da dock ocupa 94% do quadro, como os outros ícones
    de apps do tema; o da barra é como o menu da barra da autora (quatro blocos claros, sem fundo)."""
    dock = f'''<svg xmlns="{SVG}" width="512" height="512" viewBox="0 0 512 512">
{FUNDO}
<rect x="103" y="103" width="127" height="127" rx="25" fill="{RED}"/>
<rect x="282" y="103" width="127" height="127" rx="25" fill="{claro}"/>
<rect x="103" y="282" width="127" height="127" rx="25" fill="{claro2}"/>
<rect x="282" y="282" width="127" height="127" rx="25" fill="{RED}"/>
</svg>
'''
    barra = f'''<svg xmlns="{SVG}" width="512" height="512" viewBox="0 0 512 512">
<rect x="56" y="56" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="272" y="56" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="56" y="272" width="184" height="184" rx="40" fill="{claro}"/>
<rect x="272" y="272" width="184" height="184" rx="40" fill="{claro}"/>
</svg>
'''
    return dock, barra


def raster_do_svg(raiz):
    """Os bytes do PNG/JPEG se o SVG só desenha uma imagem embutida (data:); senão, None."""
    desenho = [el for el in raiz.iter() if el is not raiz and el.tag.split("}")[-1] not in
               ("g", "defs", "title", "desc", "metadata", "style")]
    if len(desenho) != 1 or desenho[0].tag.split("}")[-1] != "image":
        return None
    href = desenho[0].get("href") or desenho[0].get(f"{{{XLINK}}}href") or ""
    m = re.match(r"data:image/(png|jpe?g);base64,(.*)", href, re.S)
    return base64.b64decode(m.group(2)) if m else None


def svg_com_logo(raiz):
    """(dock, barra) em SVG para um logo vetorial: na barra, o arquivo como está; na dock, o conteúdo
    num <g> escalado sobre o fundo (o QtSvg não aceita <svg> dentro de <svg>), em 320 dos 512 px."""
    for el in raiz.iter():  # SVG 2 (<image href>) e o QtSvg antigo, que só lê xlink:href
        if el.tag.endswith("image") and el.get("href") and not el.get(f"{{{XLINK}}}href"):
            el.set(f"{{{XLINK}}}href", el.get("href"))
    barra = ET.tostring(raiz, encoding="unicode") + "\n"
    if raiz.get("viewBox"):
        x0, y0, w, h = (float(v) for v in re.split(r"[\s,]+", raiz.get("viewBox").strip()))
    else:
        num = lambda v: float(re.sub(r"[a-z%]+$", "", v or "512"))
        x0, y0, w, h = 0.0, 0.0, num(raiz.get("width")), num(raiz.get("height"))
    s = 320 / max(w, h)
    g = ET.Element(f"{{{SVG}}}g", transform=f"translate({256 - (x0 + w / 2) * s:.3f} {256 - (y0 + h / 2) * s:.3f}) scale({s:.5f})")
    for a in ("fill", "stroke", "style", "color", "fill-rule", "stroke-width", "opacity"):
        if raiz.get(a) is not None:
            g.set(a, raiz.get(a))
    g.extend(list(raiz))
    dock = ET.Element(f"{{{SVG}}}svg", width="512", height="512", viewBox="0 0 512 512")
    dock.append(ET.fromstring(FUNDO.replace("<rect", f'<rect xmlns="{SVG}"')))
    dock.append(g)
    return ET.tostring(dock, encoding="unicode") + "\n", barra


def svg_com_raster(dados, barra_frac):
    """(dock, barra) em SVG com a imagem embutida: só para o caminho antigo (menu.svg)."""
    b64 = base64.b64encode(dados).decode()
    lado = round(512 * barra_frac)
    img = lambda p, t: (f'<image x="{p}" y="{p}" width="{t}" height="{t}" preserveAspectRatio="xMidYMid meet" '
                        f'xlink:href="data:image/png;base64,{b64}"/>')
    cab = f'<svg xmlns="{SVG}" xmlns:xlink="{XLINK}" width="512" height="512" viewBox="0 0 512 512">'
    return cab + FUNDO + img(96, 320) + "</svg>\n", cab + img((512 - lado) // 2, lado) + "</svg>\n"


def pngs_pillow(dados, barra_frac):
    """{tamanho: (png da dock, png da barra)} com Pillow. Redução Lanczos em alfa pré-multiplicado
    (sem ele, a borda transparente escurece o contorno). O fundo arredondado é desenhado 4x maior e
    reduzido, para a borda sair suavizada."""
    from PIL import Image, ImageDraw
    logo = Image.open(io.BytesIO(dados)).convert("RGBA").convert("RGBa")
    cor = tuple(int(fundo[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    out = {}
    for t in TAMANHOS:
        def no_quadro(frac):
            lado = max(1, round(t * frac))
            esc = min(lado / logo.width, lado / logo.height)
            l = logo.resize((max(1, round(logo.width * esc)), max(1, round(logo.height * esc))),
                            Image.Resampling.LANCZOS).convert("RGBA")
            q = Image.new("RGBA", (t, t), (0, 0, 0, 0))
            q.alpha_composite(l, ((t - l.width) // 2, (t - l.height) // 2))
            return q
        grande = Image.new("RGBA", (t * 4, t * 4), (0, 0, 0, 0))
        k = t * 4 / 512
        ImageDraw.Draw(grande).rounded_rectangle((15 * k, 15 * k, 497 * k, 497 * k), radius=101 * k, fill=cor)
        dock = grande.convert("RGBa").resize((t, t), Image.Resampling.LANCZOS).convert("RGBA")
        dock.alpha_composite(no_quadro(LOGO_DOCK))
        out[t] = (png(dock), png(no_quadro(barra_frac)))
    return out


def png(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def pngs_magick(dados, barra_frac):
    """O mesmo sem Pillow, pelo ImageMagick (pré-requisito do tema)."""
    magick = ["magick"]
    out = {}
    with tempfile.TemporaryDirectory() as d:
        src = pathlib.Path(d) / "logo.png"
        src.write_bytes(dados)
        for t in TAMANHOS:
            res = []
            for frac, com_fundo in ((LOGO_DOCK, True), (barra_frac, False)):
                lado, k = max(1, round(t * frac)), t / 512
                dst = pathlib.Path(d) / f"{t}-{com_fundo}.png"
                cmd = [*magick, "-size", f"{t}x{t}", "xc:none"]
                if com_fundo:
                    cmd += ["-fill", fundo, "-draw", f"roundrectangle {15 * k},{15 * k} {497 * k},{497 * k} {101 * k},{101 * k}"]
                cmd += ["(", str(src), "-filter", "Lanczos", "-resize", f"{lado}x{lado}", ")",
                        "-gravity", "center", "-composite", str(dst)]
                subprocess.run(cmd, check=True)
                res.append(dst.read_bytes())
            out[t] = tuple(res)
    return out


def instalar(nome_dock, nome_barra, svgs=None, pngs=None):
    """Grava o ícone no hicolor e apaga as versões anteriores (outro hash)."""
    for velho in HICOLOR.glob("*/apps/cyberkde-menu-*"):
        if velho.stem not in (nome_dock, nome_barra):
            velho.unlink()
    if svgs:
        pasta = HICOLOR / "scalable" / "apps"
        pasta.mkdir(parents=True, exist_ok=True)
        (pasta / f"{nome_dock}.svg").write_text(svgs[0], encoding="utf-8")
        (pasta / f"{nome_barra}.svg").write_text(svgs[1], encoding="utf-8")
    for t, (dock, barra) in (pngs or {}).items():
        pasta = HICOLOR / f"{t}x{t}" / "apps"
        pasta.mkdir(parents=True, exist_ok=True)
        (pasta / f"{nome_dock}.png").write_bytes(dock)
        (pasta / f"{nome_barra}.png").write_bytes(barra)


def main():
    svgs, raster, tipo = blocos(), None, "png"
    if LOGO:
        try:
            if LOGO.lower().endswith(".svg"):
                ET.register_namespace("", SVG)
                ET.register_namespace("xlink", XLINK)
                raiz = ET.fromstring(pathlib.Path(LOGO).read_text(encoding="utf-8"))
                raster, tipo = raster_do_svg(raiz), "svg"
                if raster is None:
                    svgs = svg_com_logo(raiz)
            else:
                raster = pathlib.Path(LOGO).read_bytes()
        except (OSError, ValueError, ET.ParseError) as e:
            print(f"barra-e-dock: não consegui usar o logo {LOGO} ({e}); o menu fica com os blocos do tema.", file=sys.stderr)
            raster = None
    pngs = None
    if raster is not None:
        try:
            pngs = pngs_pillow(raster, LOGO_BARRA[tipo])
        except ImportError:
            pngs = pngs_magick(raster, LOGO_BARRA[tipo])
        svgs = svg_com_raster(raster, LOGO_BARRA[tipo])
    resumo = hashlib.sha1()
    for parte in (svgs if pngs is None else [b"".join(v) for v in pngs.values()]):
        resumo.update(parte.encode() if isinstance(parte, str) else parte)
    h = resumo.hexdigest()[:10]
    nome_dock, nome_barra = f"cyberkde-menu-{h}", f"cyberkde-menu-barra-{h}"
    instalar(nome_dock, nome_barra, svgs=None if pngs else svgs, pngs=pngs)
    SAIDA.mkdir(parents=True, exist_ok=True)
    (SAIDA / "menu.svg").write_text(svgs[0], encoding="utf-8")
    (SAIDA / "menu-barra.svg").write_text(svgs[1], encoding="utf-8")
    (SAIDA / "menu-icones").write_text(f"{nome_dock}\n{nome_barra}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
