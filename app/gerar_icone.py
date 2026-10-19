#!/usr/bin/env python3
"""Ícone do painel do CyberKDE que acompanha a cor e a corporação do tema.

Moldura chanfrada do tema (a mesma de app/cyberkde-painel.svg) + o símbolo da corporação
(assets/corporacoes/<id>.svg, vetor) + a cor de destaque. Sem corporação, sai o ícone neutro
app/cyberkde-painel.svg, já na cor de destaque atual.

Saída (padrão: ~/.cache/cyberkde/icone-app):
  <saida>/cyberkde-painel.svg                              vetor, 64x64
  <saida>/hicolor/<N>x<N>/apps/cyberkde-painel.png         N = 16, 22, 24, 32, 48, 64, 128, 256

Uso: gerar_icone.py [--corp ID] [--cor #RRGGBB] [--saida DIR|ARQUIVO.svg] [--neutro] [--so-svg]
  --saida ARQ.svg  grava só esse SVG, nesse caminho (forma que o painel usa); com uma pasta, SVG + PNGs
  --neutro         ignora a corporação: ícone neutro do tema, na cor de destaque
  --corp  id da corporação (padrão: a de ~/.config/cyberkde/corp; "nenhuma"/"personalizada"/sem
          símbolo = ícone neutro)
  --cor   destaque (padrão: ~/.config/cyberkde/cor, ou a cor da corporação, ou a do tema)
Como módulo: gerar(corp, cor, saida) -> caminho do SVG.
"""
import argparse
import json
import os
import pathlib
import re
import subprocess
import sys

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent
TAMANHOS = (16, 22, 24, 32, 48, 64, 128, 256)
NEUTRO = AQUI / "cyberkde-painel.svg"
NEUTRO_VERMELHO = "#F75049"
FUNDO = "#12121C"
MOLDURA = "M14 4H60V48L46 60H4V16Z"


def _config():
    return pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "cyberkde"


def _ler(arq):
    try:
        return arq.read_text().strip()
    except OSError:
        return ""


def _hex(v):
    v = str(v or "").strip().lstrip("#")
    return "#" + v.upper() if re.fullmatch(r"[0-9a-fA-F]{6}", v) else ""


def corporacao(id_):
    """Dados da corporação em tokens/corporacoes.json, ou {} (sem corporação ou id desconhecido)."""
    try:
        dados = json.loads((RAIZ / "tokens" / "corporacoes.json").read_text())
    except (OSError, ValueError):
        return {}
    return next((c for c in dados.get("corporacoes", []) if c.get("id") == id_), {})


def simbolo_svg(id_):
    """(viewBox, conteúdo) do vetor do símbolo, ou None se a corporação não tem."""
    arq = RAIZ / "assets" / "corporacoes" / f"{id_}.svg"
    if not id_ or not arq.is_file():
        return None
    s = arq.read_text()
    vb = re.search(r'viewBox="([^"]+)"', s)
    m = re.search(r"<svg[^>]*>(.*)</svg>", s, re.S)
    if not (vb and m) or "<image" in m.group(1):
        return None
    return vb.group(1), m.group(1).strip()


def monta_svg(corp="", cor=""):
    corp = "" if corp in ("nenhuma", "personalizada") else corp
    dados = corporacao(corp)
    cor = _hex(cor) or _hex(dados.get("destaque")) or NEUTRO_VERMELHO
    sim = simbolo_svg(corp) if dados else None
    if sim is None:  # neutro: o ícone atual, na cor de destaque
        return NEUTRO.read_text().replace(NEUTRO_VERMELHO, cor)
    fundo = _hex(dados.get("fundo")) or FUNDO
    vb, miolo = sim
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'
            f'  <!-- Ícone do painel do CyberKDE: moldura chanfrada do tema, símbolo da corporação ({corp}) e a cor de destaque. -->\n'
            f'  <path d="{MOLDURA}" fill="{fundo}" stroke="{cor}" stroke-width="4" stroke-linejoin="miter"/>\n'
            f'  <svg x="13" y="12" width="38" height="38" viewBox="{vb}">{miolo}</svg>\n'
            f'  <path d="M46 60L60 48H46Z" fill="{cor}"/>\n'
            f'</svg>\n')


def png(svg, saida, tamanhos=TAMANHOS):
    """PNGs em saida/hicolor/NxN/apps/, num único processo do Inkscape (modo shell)."""
    lote = []
    for n in tamanhos:
        d = saida / "hicolor" / f"{n}x{n}" / "apps"
        d.mkdir(parents=True, exist_ok=True)
        lote.append((n, d / "cyberkde-painel.png"))
    cmds = "".join(f"file-open:{svg}; export-filename:{p}; export-width:{n}; export-height:{n}; export-do; file-close\n" for n, p in lote)
    subprocess.run(["inkscape", "--shell"], input=cmds, text=True, capture_output=True)
    for n, p in lote:
        if not p.is_file():
            subprocess.run(["inkscape", str(svg), "-o", str(p), "-w", str(n), "-h", str(n)], check=True, capture_output=True)


def gerar(corp="", cor="", saida=None, so_svg=False, neutro=False):
    if neutro:
        corp = ""
    if saida and str(saida).lower().endswith(".svg"):  # um arquivo: só o SVG, nesse caminho
        svg = pathlib.Path(saida)
        svg.parent.mkdir(parents=True, exist_ok=True)
        svg.write_text(monta_svg(corp, cor))
        return svg
    saida = pathlib.Path(saida or (pathlib.Path(os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache") / "cyberkde" / "icone-app"))
    saida.mkdir(parents=True, exist_ok=True)
    svg = saida / "cyberkde-painel.svg"
    svg.write_text(monta_svg(corp, cor))
    if not so_svg:
        png(svg, saida)
    return svg


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corp", default=None)
    ap.add_argument("--cor", default=None)
    ap.add_argument("--saida", default="")
    ap.add_argument("--so-svg", action="store_true")
    ap.add_argument("--neutro", action="store_true")
    a = ap.parse_args()
    corp = a.corp if a.corp is not None else _ler(_config() / "corp")
    cor = a.cor if a.cor is not None else _ler(_config() / "cor")
    print(gerar(corp, cor, a.saida or None, a.so_svg, a.neutro))


if __name__ == "__main__":
    main()
