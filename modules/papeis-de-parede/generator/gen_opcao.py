#!/usr/bin/env python3
"""Papéis de parede das opções B, C e D do CyberKDE: a área de trabalho é a imagem final
(assets/wallpapers/opcoes/<opção>.webp, 1920x1080) e o bloqueio e o login saem dela como na opção A
(gen_wallpapers.sh): centro rebaixado com chanfros de 45° e, no login, base mais escura e cantoneiras
a 35% em volta da zona do painel. A cor de destaque NÃO é aplicada aqui: quem instala recolore pela
paleta (cyberlib.accented), igual à opção A.

Uso: gen_opcao.py <b|c|d> [--saida DIR] [--previas DIR]
Saída: DIR/{desktop,lockscreen,login}.png (padrão: modules/papeis-de-parede/build/<opção>)
--previas: grava só as miniaturas assets/previas/papel/<a|b|c|d>.webp (480x270) e sai.
"""
import argparse
import pathlib
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
sys.path.insert(0, str(ROOT / "generator"))
from cyberlib import TOK, hexc, rgb  # noqa: E402

OPCOES = {
    "a": ("A · HUD e cidade", "A · HUD and city", ROOT / "assets" / "wallpapers" / "desktop.png"),
    "b": ("B · Moldura técnica", "B · Technical frame", ROOT / "assets" / "wallpapers" / "opcoes" / "b-moldura-tecnica.webp"),
    "c": ("C · Cidade", "C · City", ROOT / "assets" / "wallpapers" / "opcoes" / "c-cidade.webp"),
    "d": ("D · Painéis", "D · Panels", ROOT / "assets" / "wallpapers" / "opcoes" / "d-paineis.webp"),
}
BASE = TOK["surface"]["base"]       # as cores do documento: o recolor da instalação cuida da paleta
RED = TOK["reference"]["red"]


def mascara_central(w, h, fw, fh, desfoque):
    """Retângulo com chanfros de 45° (linguagem do kit), bem desfocado: 0..1."""
    zw, zh = w * fw, h * fh
    x0, y0, x1, y1 = (w - zw) / 2, (h - zh) / 2, (w + zw) / 2, (h + zh) / 2
    c = zh * 0.12
    pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.filter(ImageFilter.GaussianBlur(h * desfoque))


def rebaixa(img, opacidade, mascara):
    """Escurece com a cor de base: opacidade máxima dentro da máscara."""
    m = mascara.point(lambda v: round(v * opacidade))
    return Image.composite(Image.new("RGB", img.size, BASE), img, m)


def moldura_login(img):
    """Filete a 35% e cantoneiras em volta da zona do painel (560x400 no centro, sem texto)."""
    w, h = img.size
    k = 4  # supersampling para a linha de 1 px sair suave
    s = h / 1080
    zw, zh = 560 * s, 400 * s
    x0, y0 = (w - zw) / 2, (h - zh) / 2
    x1, y1 = x0 + zw, y0 + zh
    arm, ch = 26 * s, 10 * s
    camada = Image.new("L", (w * k, h * k), 0)
    d = ImageDraw.Draw(camada)
    for ax, ay, dx, dy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        pts = [(ax + dx * arm, ay), (ax + dx * ch, ay), (ax, ay + dy * ch), (ax, ay + dy * arm)]
        d.line([(x * k, y * k) for x, y in pts], fill=255, width=max(1, round(s)) * k, joint="curve")
    alfa = camada.resize((w, h), Image.LANCZOS).point(lambda v: round(v * 0.35))
    return Image.composite(Image.new("RGB", img.size, RED), img, alfa)


def gera(opcao, saida):
    desktop = Image.open(OPCOES[opcao][2]).convert("RGB")
    if desktop.size != (1920, 1080):
        desktop = desktop.resize((1920, 1080), Image.LANCZOS)
    w, h = desktop.size
    saida.mkdir(parents=True, exist_ok=True)
    desktop.save(saida / "desktop.png", optimize=True)
    rebaixa(desktop, 0.55, mascara_central(w, h, 0.52, 0.56, 0.09)).save(saida / "lockscreen.png", optimize=True)
    base = ImageEnhance.Brightness(desktop).enhance(0.88)
    moldura_login(rebaixa(base, 0.82, mascara_central(w, h, 0.40, 0.48, 0.07))).save(saida / "login.png", optimize=True)


def previas(destino):
    destino.mkdir(parents=True, exist_ok=True)
    for oid, (_, _, src) in OPCOES.items():
        im = Image.open(src).convert("RGB").resize((480, 270), Image.LANCZOS)
        im.save(destino / f"{oid}.webp", "WEBP", quality=80, method=6)
        print(destino / f"{oid}.webp")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("opcao", nargs="?", choices=["b", "c", "d"])
    ap.add_argument("--saida", default="")
    ap.add_argument("--previas", default="")
    a = ap.parse_args()
    if a.previas:
        previas(pathlib.Path(a.previas))
        return
    if not a.opcao:
        ap.error("diga a opção (b, c ou d) ou use --previas")
    gera(a.opcao, pathlib.Path(a.saida) if a.saida else HERE.parent / "build" / a.opcao)


if __name__ == "__main__":
    main()
