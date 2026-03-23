#!/usr/bin/env python3
"""Gera o tema de ícones "CyberKDE" a partir dos PNGs de assets/icons/ai-final (gerados com GPT/Gemini).

- De 32 px para cima usa os ícones da IA; em 16 e 22 px (painel Locais, lista de detalhes) aponta para os
  ícones do Breeze Escuro, porque os emblemas da IA viram mancha nesses tamanhos.
- Contextos: Places (pastas e locais), Devices, MimeTypes (tipos de arquivo). O nome no index.theme precisa
  ser exatamente esse; com "Mimetypes" o KDE ignora a pasta.
- Variantes de cor da pasta (folder-green…): recoloridas do mestre "folder" com ImageMagick, sem IA.
  Só o vermelho de identidade muda; contorno escuro, trilho cinza e filete ciano ficam intactos.
- Tipos de arquivo: cada ícone base atende também os nomes específicos que o Breeze Escuro tem
  (image-png, application-zip…). Sem esses aliases o KDE acharia o ícone específico do Breeze antes de
  cair no genérico, e o tipo continuaria com cara de Breeze.
Tudo o que não está aqui é herdado do breeze-dark.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cyberlib import BASE, CYAN, GOLD, GREEN, RED, TOK, VISITED, mix  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "icons" / "ai-final"
OUT = ROOT / "themes" / "icons" / "CyberKDE"
BREEZE = [pathlib.Path("/usr/share/icons/breeze-dark"), pathlib.Path("/usr/share/icons/breeze")]
# ImageMagick 7 chama "magick"; o 6, ainda padrão em várias distribuições, chama "convert".
MAGICK = ["magick"] if shutil.which("magick") else ["convert"]

LARGE = [32, 48, 64, 96, 128, 256]
SMALL = [16, 22]

# arquivo em ai-final → (contexto, nomes freedesktop/KDE que ele atende; o primeiro é o arquivo real)
ICONS = {
    # o mestre já é vermelho; Modelos e Público ainda sem desenho próprio usam a pasta simples,
    # senão caem nas azuis do Breeze
    "folder": ("places", ["folder", "folder-red", "folder-templates", "folder-publicshare", "folder-public"]),
    "folder-open": ("places", ["folder-open"]),
    "user-home": ("places", ["user-home", "folder-home"]),
    "user-desktop": ("places", ["user-desktop", "folder-desktop"]),
    "folder-documents": ("places", ["folder-documents"]),
    "folder-download": ("places", ["folder-download", "folder-downloads"]),
    "folder-pictures": ("places", ["folder-pictures", "folder-images"]),
    "folder-music": ("places", ["folder-music", "folder-sound"]),
    "folder-videos": ("places", ["folder-videos", "folder-video"]),
    "folder-development": ("places", ["folder-development"]),
    "folder-games": ("places", ["folder-games"]),
    "folder-remote": ("places", ["folder-remote", "folder-network", "folder-cloud"]),
    "folder-recent": ("places", ["folder-recent", "folder-open-recent"]),
    "user-trash": ("places", ["user-trash"]),
    "user-trash-full": ("places", ["user-trash-full"]),
    "network-workgroup": ("places", ["network-workgroup"]),
    "drive-harddisk": ("devices", ["drive-harddisk"]),
    "drive-removable-media": ("devices", ["drive-removable-media", "drive-removable-media-usb"]),
    "smartphone": ("devices", ["smartphone", "phone"]),
    # ---- apps: Dolphin (o Jones), Konsole, Edge e Obsidian; ocupam 94% do quadro, como os da barra ----
    "org.kde.dolphin": ("apps", ["org.kde.dolphin", "system-file-manager"]),
    "utilities-terminal": ("apps", ["utilities-terminal", "org.kde.konsole"]),
    "microsoft-edge": ("apps", ["microsoft-edge", "com.microsoft.Edge"]),
    "obsidian": ("apps", ["obsidian", "md.obsidian.Obsidian"]),
    # ---- tipos de arquivo (folha com canto dobrado a 45°, derivada de ai-raw/mime-master-clean.png) ----
    "text-x-generic": ("mimetypes", [
        "text-x-generic", "text-plain", "text-x-plain", "text-x-log", "text-x-readme", "text-x-changelog",
        "text-x-authors", "text-x-copying", "text-x-credits", "text-x-install", "text-x-nfo",
        "text-markdown", "text-x-markdown", "text-x-katefilelist"]),
    "application-pdf": ("mimetypes", ["application-pdf", "application-x-pdf"]),
    "image-x-generic": ("mimetypes", [
        "image-x-generic", "image-png", "image-jpeg", "image-gif", "image-bmp", "image-tiff", "image-webp",
        "image-avif", "image-heif", "image-jxl", "image-jpeg2000", "image-svg+xml", "image-svg+xml-compressed",
        "image-x-svg+xml", "image-ico", "image-x-ico", "image-x-icon", "image-vnd.microsoft.icon", "image-x-tga",
        "image-x-portable-bitmap", "image-x-win-bitmap", "image-x-win-bmp", "image-x-adobe-dng"]),
    "video-x-generic": ("mimetypes", [
        "video-x-generic", "video-mp4", "video-webm", "video-x-matroska", "video-mpeg", "video-quicktime",
        "video-mp2t", "video-x-msvideo", "video-x-wmv", "video-x-ms-wmv", "video-x-ms-wmp", "video-x-flv",
        "video-x-theora+ogg", "video-x-ogm+ogg", "video-x-anim", "video-x-flic", "video-x-mng",
        "video-x-javafx", "video-x-google-vlc-plugin", "video-vivo", "video-wavelet", "video-vnd.rn-realvideo"]),
    "audio-x-generic": ("mimetypes", [
        "audio-x-generic", "audio-mpeg", "audio-mp3", "audio-mp4", "audio-x-mpeg", "audio-aac", "audio-ogg",
        "audio-x-vorbis+ogg", "audio-x-opus+ogg", "audio-flac", "audio-x-flac", "audio-x-flac+ogg", "audio-webm",
        "audio-x-wav", "audio-vnd.wave", "audio-x-aiff", "audio-ac3", "audio-midi", "audio-mp2", "audio-x-mp2",
        "audio-x-speex+ogg", "audio-x-adpcm", "audio-x-monkey", "audio-x-ms-wma"]),
    "package-x-generic": ("mimetypes", [
        "package-x-generic", "application-zip", "application-x-zip", "application-x-7z-compressed",
        "application-x-archive", "application-x-bzip", "application-x-bzip-compressed-tar", "application-x-compress",
        "application-x-compressed-tar", "application-x-cpio", "application-gzip", "application-x-gzip",
        "application-x-lzma-compressed-tar", "application-vnd.rar", "application-x-rar", "application-x-tar",
        "application-x-tarz", "application-x-xz", "application-x-xz-compressed-tar", "application-x-xz-pkg",
        "application-zstd", "application-x-zstd-compressed-tar", "application-x-deb",
        "application-vnd.debian.binary-package", "application-x-rpm"]),
    "text-x-script": ("mimetypes", [
        "text-x-script", "application-x-shellscript", "application-x-executable-script", "application-x-csh"]),
    "text-x-python": ("mimetypes", [
        "text-x-python", "text-x-python2", "text-x-python3", "application-x-python-bytecode"]),
    "text-html": ("mimetypes", ["text-html", "application-xhtml+xml"]),
    "application-json": ("mimetypes", ["application-json"]),
    "application-x-executable": ("mimetypes", [
        "application-x-executable", "application-x-ms-dos-executable", "application-x-msdownload",
        "application-x-sharedlib", "application-vnd.appimage"]),
    "x-office-document": ("mimetypes", [
        "x-office-document", "application-vnd.oasis.opendocument.text",
        "application-vnd.oasis.opendocument.text-template", "application-vnd.oasis.opendocument.text-master",
        "application-vnd.openxmlformats-officedocument.wordprocessingml.document", "application-msword",
        "application-msword-template", "application-vnd.ms-word", "application-vnd.ms-word.document.macroenabled.12",
        "application-vnd.ms-word.template.macroenabled.12", "application-rtf", "text-rtf", "text-enriched"]),
    "x-office-spreadsheet": ("mimetypes", [
        "x-office-spreadsheet", "application-vnd.oasis.opendocument.spreadsheet",
        "application-vnd.oasis.opendocument.spreadsheet-template",
        "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application-vnd.ms-excel",
        "application-vnd.ms-excel.sheet.macroenabled.12", "application-vnd.ms-excel.sheet.binary.macroenabled.12",
        "application-vnd.ms-excel.template.macroenabled.12", "application-vnd.ms-excel.addin.macroenabled.12",
        "text-csv"]),
    "x-office-presentation": ("mimetypes", [
        "x-office-presentation", "application-vnd.oasis.opendocument.presentation",
        "application-vnd.oasis.opendocument.presentation-template",
        "application-vnd.openxmlformats-officedocument.presentationml.presentation", "application-vnd.ms-powerpoint",
        "application-vnd.ms-powerpoint.presentation.macroenabled.12",
        "application-vnd.ms-powerpoint.slideshow.macroenabled.12",
        "application-vnd.ms-powerpoint.template.macroenabled.12"]),
    "unknown": ("mimetypes", ["unknown", "application-octet-stream", "application-x-zerosize"]),
    "text-x-csrc": ("mimetypes", [  # código-fonte em geral
        "text-x-csrc", "text-x-c++src", "text-x-chdr", "text-x-c++hdr", "text-x-objcsrc", "text-x-objchdr",
        "text-x-csharp", "text-csharp", "text-x-java", "text-x-java-source", "application-x-java",
        "text-javascript", "text-x-javascript", "application-x-javascript", "text-x-go", "text-rust",
        "text-x-rust", "text-x-kotlin", "text-x-scala", "text-x-haskell", "text-x-lua", "text-x-pascal",
        "text-x-adasrc", "text-x-nim", "text-x-tcl", "text-x-r", "application-x-perl", "application-x-ruby",
        "application-x-php", "text-css", "text-x-sass", "text-x-scss", "text-x-qml", "text-x-cmake",
        "text-x-makefile", "text-xml", "application-xml", "text-x-sql", "text-x-patch", "text-dockerfile"]),
}
EXTRA = {"inode-directory": ("mimetypes", "folder")}  # pastas no Dolphin usam o ícone do tipo MIME
# Nomes de contexto exatos da especificação; o KDE ignora grafias como "Mimetypes".
CONTEXTS = {"places": "Places", "devices": "Devices", "mimetypes": "MimeTypes", "apps": "Applications"}

# Repasse ao Breeze: um ícone de interface que não temos (status, ações, painel…) não pode cair,
# por fallback, num ícone nosso. O KDE procura variações do nome no nosso tema antes de ir ao
# Breeze: "audio-volume-high" virava o nosso audio-x-generic e "user-desktop-symbolic" o nosso
# user-desktop. Um link com o nome exato para o arquivo do Breeze faz valer o original.
GENERIC_PREFIXES = ("audio", "video", "image", "text", "package", "application", "x-office", "unknown")
PASSTHROUGH_SKIP = {"mimetypes"}  # nos tipos de arquivo, o genérico CyberKDE é o esperado

# Variantes de cor que o Dolphin oferece em "Atribuir cor" (mesmos nomes do breeze-dark).
# Cores dos tokens; as que o documento não define saem de misturas deles.
FOLDER_COLORS = {
    "green": GREEN,
    "blue": TOK["secondary"]["blue"],
    "violet": VISITED,  # violeta clareado, legível sobre o fundo escuro
    "orange": TOK["secondary"]["orange"],
    "yellow": GOLD,
    "cyan": CYAN,
    "grey": TOK["text"]["secondary"],
    "black": mix(TOK["text"]["secondary"], BASE, 0.3),  # preto puro sumiria no contorno escuro
    "brown": mix(TOK["secondary"]["orange"], BASE, 0.62),
    "magenta": mix(RED, TOK["secondary"]["violet"], 0.5),
}
# Cores medidas no mestre ai-final/folder.png (vermelho do corpo e escuro do painel).
MASTER_RED = (240, 77, 68)
MASTER_DARK = (17, 16, 27)


def unit(c):
    if isinstance(c, str):
        c = tuple(int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(v / 255 for v in c)


def recolor(src, dst, color):
    """Troca o vermelho do mestre por `color`, mantendo as nuances de borda.

    Cada pixel na linha escuro→vermelho do mestre é descrito por k (0 = escuro, 1 = vermelho) e redesenhado
    como escuro→cor nova com o mesmo k. Pixels fora dessa linha (trilho cinza, filete ciano) ficam como estão.
    """
    (rr, rg, rb), (dr, dg, db), (tr, tg, tb) = unit(MASTER_RED), unit(MASTER_DARK), unit(color)
    fx = (f"kk=max(0,min(1,(u.r-{dr:.4f})/{rr - dr:.4f})); "
          f"qg={dg:.4f}+kk*{rg - dg:.4f}; qb={db:.4f}+kk*{rb - db:.4f}; "
          f"(abs(u.g-qg)<0.09 && abs(u.b-qb)<0.09) ? "
          f"channel({dr:.4f}+kk*{tr - dr:.4f}, {dg:.4f}+kk*{tg - dg:.4f}, {db:.4f}+kk*{tb - db:.4f}, 0) : u")
    subprocess.run([*MAGICK, str(src), "-channel", "RGB", "-fx", fx, "+channel", str(dst)], check=True)


DEFAULT_RED = TOK["reference"]["red"]
CACHE = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache") / "cyberkde"


def accented(src):
    """Ícone da IA recolorido para a cor de destaque atual (cache por cor e por versão do arquivo)."""
    out = CACHE / f"icones-{RED.lstrip('#')}" / f"{src.stem}-{int(src.stat().st_mtime)}.png"
    if not out.exists():
        out.parent.mkdir(parents=True, exist_ok=True)
        recolor(src, out, RED)
    return out


def resize(src, dst, size):
    sharpen = ["-unsharp", "0x0.6+0.6+0"] if size <= 48 else []
    subprocess.run([*MAGICK, str(src), "-filter", "Lanczos", "-resize", f"{size}x{size}", *sharpen,
                    "-strip", str(dst)], check=True)


def breeze_icon(context, size, name):
    for theme in BREEZE:
        for ext in ("svg", "png"):
            path = theme / context / str(size) / f"{name}.{ext}"
            if path.exists():
                return path.resolve()
    return None


def theme_sections(theme):
    """Pastas do index.theme de um tema: "status/24" → linhas Size/Context/Type/… (sem as @2x)."""
    sections, current = {}, None
    for line in (theme / "index.theme").read_text().splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            if current != "Icon Theme" and "@" not in current:
                sections[current] = []
            else:
                current = None
        elif current and "=" in line:
            sections[current].append(line)
    return sections


def captured_by_fallback(name, defined):
    """True se o fallback do KDE levaria este nome do Breeze a um ícone nosso."""
    base = name.removesuffix("-symbolic")
    parts = base.split("-")
    return (any("-".join(parts[:i]) in defined for i in range(1, len(parts) + 1))
            or base.startswith(GENERIC_PREFIXES))


def passthrough(defined):
    """Cria links com o nome exato para os ícones de interface do Breeze que o fallback capturaria."""
    meta = {}
    for theme in BREEZE:
        for key, lines in theme_sections(theme).items():
            if key.split("/")[0] in PASSTHROUGH_SKIP or not (theme / key).is_dir():
                continue
            for icon in (theme / key).iterdir():
                name = icon.name[: -len(icon.suffix)] if icon.suffix in (".svg", ".png") else None
                if not name or name in defined or not captured_by_fallback(name, defined):
                    continue
                link = OUT / key / f"{name}{icon.suffix}"
                if link.exists() or link.is_symlink():
                    continue  # o breeze-dark vem antes do breeze
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(icon.resolve())
                meta.setdefault(key, lines)
    return meta


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    dirs = set()
    seen = {}
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cyberkde-icons-"))
    try:
        # Com outra cor de destaque ("cyberkde cor"), os ícones da IA são recoloridos; a pasta "vermelha"
        # do Dolphin continua sendo o mestre vermelho.
        changed = RED.upper() != DEFAULT_RED.upper()
        source = (lambda base: accented(SRC / f"{base}.png")) if changed else (lambda base: SRC / f"{base}.png")
        entries = []
        for base, (ctx, names) in ICONS.items():
            if changed:
                names = [n for n in names if n != "folder-red"]
            entries.append((source(base), ctx, names))
        entries += [(source(base), ctx, [name]) for name, (ctx, base) in EXTRA.items()]
        if changed:
            entries.append((SRC / "folder.png", "places", ["folder-red"]))
        for color, value in FOLDER_COLORS.items():
            src = tmp / f"folder-{color}.png"
            recolor(SRC / "folder.png", src, value)
            entries.append((src, "places", [f"folder-{color}"]))

        for src, ctx, names in entries:
            for name in names:
                if (ctx, name) in seen:
                    raise SystemExit(f"nome repetido: {ctx}/{name} ({seen[(ctx, name)]} e {src.name})")
                seen[(ctx, name)] = src.name
            if not src.exists():
                raise SystemExit(f"falta o ícone de origem: {src}")

        for src, ctx, names in entries:
            for size in LARGE:
                folder = OUT / ctx / str(size)
                folder.mkdir(parents=True, exist_ok=True)
                dirs.add((ctx, size))
                first = folder / f"{names[0]}.png"
                resize(src, first, size)
                for alias in names[1:]:
                    (folder / f"{alias}.png").symlink_to(first.name)
            for size in SMALL:
                for name in names:
                    target = breeze_icon(ctx, size, name) or breeze_icon(ctx, size, names[0])
                    if target:
                        folder = OUT / ctx / str(size)
                        folder.mkdir(parents=True, exist_ok=True)
                        dirs.add((ctx, size))
                        (folder / f"{name}{target.suffix}").symlink_to(target)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    ordered = sorted(dirs, key=lambda d: (d[0], d[1]))
    ours = [f"{c}/{s}" for c, s in ordered]
    borrowed = passthrough({name for _, name in seen})
    extra = sorted(k for k in borrowed if k not in ours)
    lines = ["[Icon Theme]", "Name=CyberKDE",
             "Comment=CyberKDE neo-military folders, places and file types; inherits Breeze Dark",
             "Comment[pt_BR]=Pastas, locais e tipos de arquivo neomilitares do CyberKDE; herda o Breeze Escuro",
             "Inherits=breeze-dark,hicolor",
             "Directories=" + ",".join(ours + extra), ""]
    for ctx, size in ordered:
        lines += [f"[{ctx}/{size}]", f"Size={size}", f"Context={CONTEXTS[ctx]}", "Type=Fixed", ""]
    for key in extra:  # pastas só com links do Breeze: mesmos metadados do index.theme dele
        lines += [f"[{key}]", *borrowed[key], ""]
    (OUT / "index.theme").write_text("\n".join(lines))
    count = sum(1 for p in OUT.rglob("*") if p.is_file() or p.is_symlink())
    print(f"{count} ícones/links em {len(ordered)} pastas → {OUT}")


if __name__ == "__main__":
    main()
