#!/usr/bin/env python3
"""Gera o tema de ícones "CyberKDE" a partir dos PNGs de assets/icons/ai-final (gerados com GPT/Gemini).

- De 32 px para cima usa os ícones da IA; em 16 e 22 px (painel Locais, lista de detalhes) aponta para os
  ícones do Breeze Escuro, porque os emblemas da IA viram mancha nesses tamanhos.
- Contextos: Places (pastas e locais), Devices, MimeTypes (tipos de arquivo). O nome no index.theme precisa
  ser exatamente esse; com "Mimetypes" o KDE ignora a pasta.
- Variantes de cor da pasta (folder-green…): recoloridas do mestre "folder" por recolor() do cyberlib, sem IA.
  Só o vermelho de identidade muda; contorno escuro, trilho cinza e filete ciano ficam intactos.
- Tipos de arquivo: cada ícone base atende também os nomes específicos que o Breeze Escuro tem
  (image-png, application-zip…). Sem esses aliases o KDE acharia o ícone específico do Breeze antes de
  cair no genérico, e o tipo continuaria com cara de Breeze.
Tudo o que não está aqui é herdado do breeze-dark.
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import apps_marca  # noqa: E402
import cyberlib  # noqa: E402
from cyberlib import BASE, CYAN, GOLD, GREEN, RED, TOK, VISITED, mix  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "icons" / "ai-final"
BASE_ESCURO = (18, 18, 28, 255)  # fundo das miniaturas (surface.base)
ALT_SRC = ROOT / "assets" / "icons" / "alternativos"  # estilos alternativos (mesmos nomes do ai-final), só os 6 de ALT_GRUPOS
OUT = ROOT / "themes" / "icons" / "CyberKDE"
# grupo da opção "cyberkde efeito icones" → ícone do ai-final que o estilo alternativo substitui
ALT_GRUPOS = {
    "documents": "folder-documents", "music": "folder-music", "pictures": "folder-pictures",
    "recent": "folder-recent", "remote": "folder-remote", "trash": "user-trash-full",
}
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
# Apps favoritos desenhados em generator/gen_apps_icons.py (assets/icons/apps/<id>.png + apps.json):
# cada um atende todos os nomes de ícone listados no apps.json (o primeiro é o arquivo real).
APPS_SRC = ROOT / "assets" / "icons" / "apps"
APPS_NOVOS = set()
APPS_META = {}
if (APPS_SRC / "apps.json").is_file():
    for _id, _m in json.loads((APPS_SRC / "apps.json").read_text()).items():
        ICONS[_id] = ("apps", _m["nomes"])
        APPS_NOVOS.add(_id)
        APPS_META[_id] = _m
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
# Vermelho medido no mestre ai-final/folder.png (o escuro do painel é o MASTER_DARK do cyberlib).
MASTER_RED = "#F04D44"
DEFAULT_RED = TOK["reference"]["red"]


def recolor(src, dst, color):
    """Troca o vermelho do mestre por `color` (ver recolor no cyberlib)."""
    cyberlib.recolor(src, dst, color, MASTER_RED)


def accented(src):
    """Ícone da IA recolorido para a cor de destaque atual (cache por cor e por versão do arquivo)."""
    return cyberlib.accented(src, MASTER_RED)


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


def app_fonte(aid, estilo, tmp):
    """Arquivo de origem de um app favorito, já na cor certa, ou None (o app fica sem ícone do tema).
    estilo: "marca" e "recolorido" usam o ícone que o app instalou na máquina (apps_marca; nada disso é versionado);
    "silhueta" (e o que não tem ícone instalado) usa a silhueta de assets/icons/apps; "nenhum" não gera apps
    (é o padrão, porque themes/icons/CyberKDE é versionado e não pode levar arte de marca)."""
    if estilo == "nenhum":
        return None
    if estilo in ("marca", "recolorido"):
        m = APPS_META.get(aid, {})
        src = apps_marca.localiza(m.get("nomes", []), m.get("desktops", []))
        if src is not None:
            try:
                return apps_marca.compoe(src, estilo, RED, tmp, accented)
            except (OSError, subprocess.CalledProcessError) as e:
                print(f"aviso: {aid}: não consegui usar {src} ({e}); fica a silhueta", file=sys.stderr)
    arq = APPS_SRC / f"{aid}.png"
    if not arq.is_file():
        return None
    return accented(arq) if RED.upper() != DEFAULT_RED.upper() else arq


def checa_apps_instalados(estilo):
    """Os estilos marca e recolorido dependem do ícone que cada app instalou. Se NENHUM dos apps tem ícone achado,
    o ambiente está errado (HOME/XDG, pasta de ícones ilegível...): em vez de cair na silhueta em todos de uma vez,
    aborta com erro, e quem chamou (o gancho de instalação) mantém o tema de ícones sem os apps (eles ficam com o ícone original), em vez de pôr silhueta em todos. Um app sem ícone instalado
    é outra coisa: cai na silhueta só ele, e isso vai para o stderr."""
    if estilo not in ("marca", "recolorido") or not APPS_META:
        return
    sem = [a for a, m in APPS_META.items() if apps_marca.localiza(m.get("nomes", []), m.get("desktops", [])) is None]
    if len(sem) == len(APPS_META) and len(APPS_META) >= 5:
        sys.exit(f"erro: nenhum dos {len(APPS_META)} apps tem ícone instalado (HOME={pathlib.Path.home()}); "
                 "ambiente suspeito, não gero o tema dos apps em silhueta por engano")
    if sem:
        print(f"aviso: sem ícone instalado, ficam na silhueta: {', '.join(sem)}", file=sys.stderr)


def fonte(base, alt):
    """Arquivo de origem de um ícone: o alternativo, se o grupo dele foi escolhido; senão, o do ai-final."""
    if base in APPS_NOVOS:
        return APPS_SRC / f"{base}.png"
    if base in alt:
        return ALT_SRC / f"{base}.png"
    return SRC / f"{base}.png"


# Contexto do hicolor → nome exato no index.theme (especificação de temas de ícones)
CONTEXTOS_HICOLOR = {"apps": "Applications", "actions": "Actions", "categories": "Categories", "devices": "Devices",
                     "emblems": "Emblems", "mimetypes": "MimeTypes", "places": "Places", "status": "Status"}


def icones_de_passagem(nomes_nossos):
    """Ícones instalados (hicolor do usuário e do sistema, flatpak, pixmaps) cujo nome começa com "<nome nosso>-" e que não
    são nossos. O KIconLoader/Qt corta o nome no último hífen quando não o acha ("claude-mascot" → "claude") e acharia o NOSSO
    ícone antes de chegar ao hicolor; um link com o nome exato para o arquivo original faz valer o original.
    Devolve [(contexto, tamanho|"scalable", nome com extensão, caminho original)]. Só roda na instalação (os links
    apontam para caminhos desta máquina: nunca vão para o tema versionado)."""
    prefixos = tuple(f"{n}-" for n in nomes_nossos)
    home = pathlib.Path.home()
    achados = []
    for raiz in (home / ".local/share/icons/hicolor", pathlib.Path("/usr/share/icons/hicolor"),
                 home / ".local/share/flatpak/exports/share/icons/hicolor", pathlib.Path("/var/lib/flatpak/exports/share/icons/hicolor")):
        if not raiz.is_dir():
            continue
        for pasta in sorted(raiz.iterdir()):
            if "@" in pasta.name or not (pasta.name == "scalable" or pasta.name[:1].isdigit()):
                continue
            tam = "scalable" if pasta.name == "scalable" else pasta.name.split("x")[0]
            for ctx_dir in pasta.iterdir():
                if ctx_dir.name not in CONTEXTOS_HICOLOR or not ctx_dir.is_dir():
                    continue
                for arq in ctx_dir.iterdir():
                    if arq.suffix in (".png", ".svg") and arq.stem.startswith(prefixos) and arq.stem not in nomes_nossos:
                        achados.append((ctx_dir.name, tam, arq.name, arq))
    for raiz in (pathlib.Path("/usr/share/pixmaps"), home / ".local/share/pixmaps"):
        if not raiz.is_dir():
            continue
        for arq in raiz.iterdir():
            if arq.suffix in (".png", ".svg") and arq.stem.startswith(prefixos) and arq.stem not in nomes_nossos:
                tam = "scalable"
                if arq.suffix == ".png":
                    try:
                        from PIL import Image
                        with Image.open(arq) as im:
                            tam = str(max(im.size))
                    except OSError:
                        continue
                achados.append(("apps", tam, arq.name, arq))
    return achados


def liga_passagem(nomes_nossos, dirs, extra_meta):
    """Cria os links de icones_de_passagem em OUT e registra as pastas novas (dirs: as da numeração normal; extra_meta:
    linhas do index.theme das pastas que o tema ainda não tinha, como apps/512 e apps/scalable)."""
    feitos = {}
    for ctx, tam, nome, origem in icones_de_passagem(nomes_nossos):
        chave = f"{ctx}/{tam}"
        destino = OUT / ctx / tam / nome
        if destino.exists() or destino.is_symlink() or (chave, nome[: -len(destino.suffix)]) in feitos:
            continue
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.symlink_to(origem)
        feitos[(chave, destino.stem)] = origem
        if tam == "scalable":
            extra_meta.setdefault(chave, ["Size=128", f"Context={CONTEXTOS_HICOLOR[ctx]}", "Type=Scalable", "MinSize=8", "MaxSize=512"])
        elif (ctx, int(tam)) not in dirs:
            extra_meta.setdefault(chave, [f"Size={tam}", f"Context={CONTEXTOS_HICOLOR[ctx]}", "Type=Fixed"])
    return len(feitos)


def main(alt=frozenset(), apps_estilo="nenhum"):
    shutil.rmtree(OUT, ignore_errors=True)
    dirs = set()
    seen = {}
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cyberkde-icons-"))
    checa_apps_instalados(apps_estilo)
    try:
        # Com outra cor de destaque ("cyberkde cor"), os ícones da IA são recoloridos; a pasta "vermelha"
        # do Dolphin continua sendo o mestre vermelho.
        changed = RED.upper() != DEFAULT_RED.upper()
        # Recolorir e redimensionar são processos/arrays independentes: rodam em paralelo, um por núcleo.
        with ThreadPoolExecutor(os.cpu_count() or 4) as pool:
            source = accented if changed else (lambda path: path)
            pending = []
            for base, (ctx, names) in ICONS.items():
                if changed:
                    names = [n for n in names if n != "folder-red"]
                if base in APPS_NOVOS:
                    pending.append((pool.submit(app_fonte, base, apps_estilo, tmp), ctx, names))
                    continue
                pending.append((pool.submit(source, fonte(base, alt)), ctx, names))
            pending += [(pool.submit(source, SRC / f"{base}.png"), ctx, [name]) for name, (ctx, base) in EXTRA.items()]
            for color, value in FOLDER_COLORS.items():
                src = tmp / f"folder-{color}.png"
                pending.append((pool.submit(lambda s=src, v=value: (recolor(SRC / "folder.png", s, v), s)[1]),
                                "places", [f"folder-{color}"]))
            entries = [(fut.result(), ctx, names) for fut, ctx, names in pending]
            entries = [e for e in entries if e[0] is not None]  # app sem ícone: fica sem o do tema
            if changed:
                entries.append((SRC / "folder.png", "places", ["folder-red"]))

            for src, ctx, names in entries:
                for name in names:
                    if (ctx, name) in seen:
                        raise SystemExit(f"nome repetido: {ctx}/{name} ({seen[(ctx, name)]} e {src.name})")
                    seen[(ctx, name)] = src.name
                if not src.exists():
                    raise SystemExit(f"falta o ícone de origem: {src}")

            jobs = []
            for src, ctx, names in entries:
                for size in LARGE:
                    folder = OUT / ctx / str(size)
                    folder.mkdir(parents=True, exist_ok=True)
                    dirs.add((ctx, size))
                    jobs.append(pool.submit(resize, src, folder / f"{names[0]}.png", size))
            for job in jobs:
                job.result()  # repassa o erro de qualquer redimensionamento

        for src, ctx, names in entries:
            for size in LARGE:
                folder = OUT / ctx / str(size)
                for alias in names[1:]:
                    (folder / f"{alias}.png").symlink_to(f"{names[0]}.png")
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
    if apps_estilo != "nenhum":  # só na instalação: os links apontam para arquivos desta máquina
        n_passagem = liga_passagem({name for c, name in seen if c == "apps"}, dirs, borrowed)
        print(f"{n_passagem} links de passagem para ícones instalados (claude-mascot etc.)")
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


def previas(destino):
    """Miniaturas das opções (cor padrão): <grupo>-padrao.webp, <grupo>-alt.webp (128 px, alfa) e a
    comparacao.webp (as seis lado a lado, padrão em cima e alternativo embaixo, sobre o fundo escuro)."""
    from PIL import Image
    destino.mkdir(parents=True, exist_ok=True)
    pares = {g: (SRC / f"{b}.png", ALT_SRC / f"{b}.png") for g, b in ALT_GRUPOS.items()}
    tela = Image.new("RGBA", (len(pares) * 168 + 8, 2 * 168 + 8), BASE_ESCURO)
    for i, (grupo, caminhos) in enumerate(pares.items()):
        for j, (estilo, src) in enumerate(zip(("padrao", "alt"), caminhos)):
            im = Image.open(src).convert("RGBA")
            im.resize((128, 128), Image.LANCZOS).save(destino / f"{grupo}-{estilo}.webp", "WEBP", quality=92, alpha_quality=100, method=6)
            tela.alpha_composite(im.resize((160, 160), Image.LANCZOS), (8 + i * 168, 8 + j * 168))
    tela.convert("RGB").save(destino / "comparacao.webp", "WEBP", quality=88, method=6)
    print(f"prévias em {destino}")


def grade_apps(arq, estilo):
    """Grade de todos os apps no estilo pedido (128 e 48/32/22 px) e a lista dos que não tinham ícone instalado."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cyberkde-grade-"))
    try:
        itens, sem = [], []
        for aid, m in APPS_META.items():
            instalado = apps_marca.localiza(m["nomes"], m.get("desktops", [])) is not None
            p = app_fonte(aid, estilo, tmp)
            if p is None:
                sem.append(f"{aid} (sem ícone e sem silhueta)")
                continue
            itens.append((m["nome"] + ("" if instalado else " [silhueta]"), p))
            if not instalado:
                sem.append(f"{aid} (sem ícone instalado → silhueta)")
        apps_marca.grade(itens, arq)
        print(f"{len(itens)} apps em {arq}")
        for x in sem:
            print("  sem ícone instalado:", x)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def argumentos():
    """--alt documents,music,...|todos: estilos alternativos (assets/icons/alternativos).
    --saida DIR: gera fora de themes/icons/CyberKDE (que é versionado)."""
    import argparse
    global OUT
    ap = argparse.ArgumentParser(description="Gera o tema de ícones CyberKDE.")
    ap.add_argument("--alt", default="", help="grupos com o estilo alternativo: " + ",".join(ALT_GRUPOS) + " ou todos")
    ap.add_argument("--saida", default="", help="pasta de saída (padrão: themes/icons/CyberKDE)")
    ap.add_argument("--previas", default="", help="só grava as miniaturas das opções nesta pasta e sai")
    ap.add_argument("--apps-estilo", default="nenhum", choices=["nenhum", "marca", "recolorido", "silhueta"],
                    help="ícones dos apps favoritos (padrão: nenhum, para o tema versionado não levar arte de marca)")
    ap.add_argument("--grade", default="", help="só grava a grade de conferência dos apps no estilo de --apps-estilo e sai")
    a = ap.parse_args()
    if a.previas:
        previas(pathlib.Path(a.previas))
        raise SystemExit(0)
    if a.grade:
        grade_apps(a.grade, a.apps_estilo if a.apps_estilo != "nenhum" else "marca")
        raise SystemExit(0)
    grupos = list(ALT_GRUPOS) if a.alt.strip() == "todos" else [g for g in a.alt.replace(" ", "").split(",") if g]
    ruim = [g for g in grupos if g not in ALT_GRUPOS]
    if ruim:
        ap.error(f"grupo desconhecido: {', '.join(ruim)} (há: {', '.join(ALT_GRUPOS)})")
    if a.saida:
        OUT = pathlib.Path(a.saida)
    return frozenset(ALT_GRUPOS[g] for g in grupos), a.apps_estilo


if __name__ == "__main__":
    _alt, _estilo = argumentos()
    main(_alt, _estilo)
