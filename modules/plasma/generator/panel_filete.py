#!/usr/bin/env python3
"""Filete neon na moldura de painel copiada do tema original (opção 1 da barra superior, 14/09/2026).

Uso: panel_filete.py <widgets/panel-background.svg|svgz> <#RRGGBB>

Numa barra de largura total o Plasma só desenha a borda de baixo da moldura (esticada), então o
filete vai no elemento "bottom": uma linha de 1 px na cor de destaque na base, com um brilho curto
de 3 px acima dela. Também acrescenta "hint-stretch-borders" (sem ele as bordas viram ladrilhos e
aparecem pontinhos no filete). Não repete se o filete já estiver lá.
"""
import gzip
import pathlib
import re
import sys

MARK = "cyberkde-filete"


def main():
    path, color = pathlib.Path(sys.argv[1]), sys.argv[2]
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
        sys.exit(f"panel_filete: cor inválida: {color}")
    raw = path.read_bytes()
    zipped = raw[:2] == b"\x1f\x8b"
    svg = (gzip.decompress(raw) if zipped else raw).decode()
    if MARK in svg:
        return

    group = re.search(r'(<g\b[^>]*\bid="bottom"[^>]*>)(.*?)(</g>)', svg, re.S)
    if not group:
        sys.exit("panel_filete: elemento \"bottom\" não encontrado")
    # Tamanho da peça: o primeiro retângulo do grupo (no BreezeGlass, 32 x 12).
    rect = re.search(r'<rect\b[^>]*>', group.group(2))
    size = rect and (re.search(r'\bwidth="([\d.]+)"', rect.group(0)), re.search(r'\bheight="([\d.]+)"', rect.group(0)))
    if not size or not all(size):
        sys.exit("panel_filete: não achei o tamanho do elemento \"bottom\"")
    w, h = float(size[0].group(1)), float(size[1].group(1))

    filete = (
        f'<linearGradient id="{MARK}-brilho" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{color}" stop-opacity="0"/>'
        f'<stop offset="1" stop-color="{color}" stop-opacity="0.22"/></linearGradient>'
        f'<rect x="0" y="{h - 4:g}" width="{w:g}" height="3" fill="url(#{MARK}-brilho)"/>'
        f'<rect id="{MARK}" x="0" y="{h - 1:g}" width="{w:g}" height="1" fill="{color}" fill-opacity="0.85"/>'
    )
    svg = svg[:group.end(2)] + filete + svg[group.end(2):]
    if 'id="hint-stretch-borders"' not in svg:
        svg = svg.replace("</svg>", '<rect id="hint-stretch-borders" x="0" y="0" width="4" height="4" fill="none"/>\n</svg>')

    data = svg.encode()
    path.write_bytes(gzip.compress(data) if zipped else data)


if __name__ == "__main__":
    main()
