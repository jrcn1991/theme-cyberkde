"""Item de arquivo: stat -> dicionário com os papéis do modelo (spec 14.3), grupos das pilhas,
códigos hex, ordenação natural e formatação de tamanho e data. Funções puras, usadas também nas
threads de leitura (cada thread cria o próprio QMimeDatabase)."""

import os
import re
import stat
import time
import unicodedata
from urllib.parse import quote

from PyQt6.QtCore import QMimeDatabase, QUrl

# ordem das pilhas na visão PILHAS
GRUPOS = ("pastas", "imagem", "video", "audio", "documento", "codigo", "compactado", "executavel", "outro")

_COMPACTADOS = {
    "application/zip", "application/x-7z-compressed", "application/x-tar", "application/x-compressed-tar",
    "application/x-bzip-compressed-tar", "application/x-xz-compressed-tar", "application/x-zstd-compressed-tar",
    "application/gzip", "application/x-bzip2", "application/x-xz", "application/zstd", "application/x-rar",
    "application/vnd.rar", "application/x-rar-compressed", "application/x-lzma", "application/x-cpio",
    "application/vnd.debian.binary-package", "application/x-rpm", "application/x-iso9660-image",
    "application/java-archive", "application/x-archive",
}
_DOCUMENTOS_PREFIXO = ("application/vnd.oasis.opendocument", "application/vnd.openxmlformats",
                       "application/vnd.ms-", "application/msword", "application/pdf", "application/epub",
                       "application/rtf", "application/x-mobipocket", "text/markdown", "text/x-markdown",
                       "text/csv", "application/vnd.comicbook")
_CODIGO = {
    "text/x-python", "text/x-python3", "application/x-shellscript", "text/x-shellscript", "application/javascript",
    "text/javascript", "application/json", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr",
    "text/x-java", "text/x-rust", "text/x-go", "text/rust", "text/x-kotlin", "application/x-php", "text/x-php",
    "text/html", "text/css", "application/xml", "text/xml", "application/x-yaml", "text/x-yaml", "application/yaml",
    "application/toml", "text/x-toml", "text/x-qml", "text/x-cmake", "text/x-makefile", "application/sql",
    "text/x-sql", "application/x-ruby", "text/x-lua", "text/x-csharp", "application/typescript",
    "text/x-typescript", "application/x-desktop", "text/x-patch", "text/x-diff", "application/x-perl",
    "application/x-gdscript", "text/x-gdscript", "application/x-godot-scene", "text/x-tex", "text/x-log",
    "application/x-ipynb+json", "text/x-dart", "text/x-swift", "text/x-scss", "text/x-sass",
}
_EXECUTAVEIS = {"application/x-executable", "application/x-sharedlib", "application/x-pie-executable",
                "application/x-appimage", "application/vnd.appimage", "application/x-ms-dos-executable",
                "application/x-msdownload", "application/x-msi", "application/vnd.flatpak.ref"}


def grupo_de(mime, eh_pasta, executavel=False):
    if eh_pasta:
        return "pastas"
    if mime in _COMPACTADOS:
        return "compactado"
    if mime in _CODIGO:
        return "codigo"
    if mime.startswith("image/"):
        return "imagem"
    if mime.startswith("video/"):
        return "video"
    if mime.startswith("audio/"):
        return "audio"
    if mime.startswith(_DOCUMENTOS_PREFIXO):
        return "documento"
    if mime in _EXECUTAVEIS or (executavel and not mime.startswith("text/")):
        return "executavel"
    if mime.startswith("text/"):
        return "documento" if mime == "text/plain" else "codigo"
    return "outro"


def codigo(st_ino, st_dev=0):
    """Código hex de 6 dígitos, estável enquanto o arquivo existir (inode + dispositivo)."""
    return f"0x{(st_ino ^ (st_dev << 7) ^ (st_dev >> 3)) & 0xFFFFFF:06X}"


def codigo_caminho(caminho):
    try:
        st = os.stat(caminho)
        return codigo(st.st_ino, st.st_dev)
    except OSError:
        return "0x000000"


def chave_natural(nome):
    """Ordenação "natural" (arquivo2 antes de arquivo10), sem caixa e sem acento."""
    base = unicodedata.normalize("NFKD", nome.casefold())
    base = "".join(c for c in base if not unicodedata.combining(c))
    return [(0, int(p), "") if p.isdigit() else (1, 0, p) for p in re.split(r"(\d+)", base) if p]


def sem_acento(texto):
    base = unicodedata.normalize("NFKD", texto.casefold())
    return "".join(c for c in base if not unicodedata.combining(c))


def tamanho_texto(n, idioma="pt_BR"):
    if n is None or n < 0:
        return ""
    unidades = ("B", "KiB", "MiB", "GiB", "TiB", "PiB")
    v = float(n)
    i = 0
    while v >= 1024 and i < len(unidades) - 1:
        v /= 1024
        i += 1
    if i == 0:
        txt = f"{int(v)} B"
    else:
        txt = f"{v:.1f} {unidades[i]}" if v < 100 else f"{v:.0f} {unidades[i]}"
    return txt.replace(".", ",") if idioma.startswith("pt") else txt


def data_texto(ts):
    if not ts:
        return ""
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(ts))


def abreviar(caminho):
    """/home/x/Documentos -> ~/Documentos (para mostrar; o caminho real fica em pastaPai)."""
    casa = os.path.expanduser("~")
    return "~" + caminho[len(casa):] if caminho == casa or caminho.startswith(casa + "/") else caminho


def permissoes(modo):
    return stat.filemode(modo)[1:]


# pastas XDG conhecidas ganham o ícone próprio do tema
_ICONES_XDG = {}


def registrar_icones_xdg(mapa):
    _ICONES_XDG.clear()
    _ICONES_XDG.update(mapa)


def icone_url(nome, generico=""):
    q = f"?g={quote(generico)}" if generico else ""
    return f"image://icone/{quote(nome)}{q}"


def miniatura_url(caminho, mtime):
    return f"image://miniatura/{quote(caminho)}?m={int(mtime)}"


# tipos que o provedor de miniaturas sabe gerar
# miniaturas que já falharam nesta sessão: caminho -> mtime (s). Preenchido pelo provedor (U16)
FALHAS_MINIATURA = {}


def tem_miniatura(mime):
    return (mime.startswith("image/") and mime not in ("image/x-icns",)) or mime.startswith("video/") \
        or mime == "application/pdf"


def ler_item(caminho, db=None, entrada=None, idioma="pt_BR"):
    """Dicionário com os papéis do modelo, ou None se o arquivo sumiu. `entrada` é um os.DirEntry
    (evita um stat a mais)."""
    db = db or QMimeDatabase()
    nome = os.path.basename(caminho.rstrip("/")) or caminho
    try:
        lst = entrada.stat(follow_symlinks=False) if entrada is not None else os.lstat(caminho)
    except OSError:
        return None
    eh_link = stat.S_ISLNK(lst.st_mode)
    alvo = ""
    st = lst
    quebrado = False
    if eh_link:
        try:
            alvo = os.readlink(caminho)
        except OSError:
            pass
        try:
            st = os.stat(caminho)
        except OSError:
            quebrado = True
    eh_pasta = stat.S_ISDIR(st.st_mode)
    executavel = bool(st.st_mode & 0o111) and stat.S_ISREG(st.st_mode)
    if eh_pasta:
        mime = "inode/directory"
        mt = db.mimeTypeForName(mime)
        icone = _ICONES_XDG.get(caminho, "folder")
        generico = "folder"
    elif quebrado:
        mime = "inode/symlink"
        mt = db.mimeTypeForName(mime)
        icone, generico = "emblem-symbolic-link", "text-x-generic"
    else:
        mt = db.mimeTypeForFile(caminho, QMimeDatabase.MatchMode.MatchExtension)
        if mt.isDefault() and stat.S_ISREG(st.st_mode) and st.st_size > 0:
            mt = db.mimeTypeForFile(caminho, QMimeDatabase.MatchMode.MatchDefault)
        mime = mt.name()
        icone = mt.iconName() or "text-x-generic"
        generico = mt.genericIconName() or "text-x-generic"
    tamanho = -1 if eh_pasta else st.st_size
    item = {
        "nome": nome,
        "caminho": caminho,
        "url": QUrl.fromLocalFile(caminho).toString(),
        "ehPasta": eh_pasta,
        "ehLink": eh_link,
        "alvoLink": alvo,
        "oculto": nome.startswith("."),
        "tamanho": tamanho,
        "tamanhoTexto": tamanho_texto(tamanho, idioma),
        "modificado": int(st.st_mtime * 1000),
        "modificadoTexto": data_texto(st.st_mtime),
        "mime": mime,
        "tipo": mt.comment() if mt.isValid() else mime,
        "grupo": grupo_de(mime, eh_pasta, executavel),
        "icone": icone,
        "iconeUrl": icone_url(icone, generico),
        "miniatura": miniatura_url(caminho, st.st_mtime) if not eh_pasta and tem_miniatura(mime)
        and FALHAS_MINIATURA.get(caminho) != int(st.st_mtime) else "",
        "filhos": -1,
        "filhosLimite": False,   # True: a pasta tem mais de 999 itens ("999+")
        # visão PILHAS (spec 19): preenchidos depois, por subpastas.py, só nas pastas pedidas
        "subpastas": [],
        "subpastasTotal": -1,
        "arquivosTotal": -1,
        "subpastasEstado": "",
        # etiquetas, avaliação (0–10) e comentário, nos xattr do Baloo (tags.py)
        **_xattrs(caminho),
        "codigo": codigo(lst.st_ino, lst.st_dev),
        "permissoes": permissoes(st.st_mode),
        "legivel": os.access(caminho, os.R_OK),
        "gravavel": os.access(caminho, os.W_OK),
        "selecionado": False,
        "pastaPai": os.path.dirname(caminho),
        "local": abreviar(os.path.dirname(caminho)),
        "origem": "",
        "apagadoEm": "",
    }
    return item


def _xattrs(caminho):
    from .tags import ler
    return ler(caminho)


def contar_filhos(caminho, limite=999, ocultos=True):
    """Entradas da pasta (sem as ocultas, se ocultos=False), até `limite`."""
    return contar_pasta(caminho, limite, ocultos)[0]


def contar_pasta(caminho, limite=999, ocultos=True):
    """(n, passou_do_limite): n vai até `limite`; True quando havia mais (o QML escreve "999+")."""
    n = 0
    try:
        with os.scandir(caminho) as it:
            for e in it:
                if not ocultos and e.name.startswith("."):
                    continue
                if n >= limite:
                    return n, True
                n += 1
    except OSError:
        return 0, False
    return n, False


def chave_ordem(item, ordem):
    """Tupla de ordenação; pastas sempre primeiro (como o Dolphin)."""
    pasta = 0 if item["ehPasta"] else 1
    nat = chave_natural(item["nome"])
    if ordem == "tamanho":
        return (pasta, item["tamanho"] if not item["ehPasta"] else item.get("filhos", 0), nat)
    if ordem == "data":
        return (pasta, item["modificado"], nat)
    if ordem == "tipo":
        return (pasta, item["tipo"].casefold(), nat)
    return (pasta, nat)


def ordenar(itens, ordem="nome", decrescente=False):
    """Pastas primeiro também na ordem decrescente."""
    pastas = [i for i in itens if i["ehPasta"]]
    arquivos = [i for i in itens if not i["ehPasta"]]
    pastas.sort(key=lambda i: chave_ordem(i, ordem), reverse=decrescente)
    arquivos.sort(key=lambda i: chave_ordem(i, ordem), reverse=decrescente)
    return pastas + arquivos


def nome_livre(pasta, nome):
    """Nome que ainda não existe em `pasta`: "foto.png" -> "foto (2).png"."""
    if not os.path.lexists(os.path.join(pasta, nome)):
        return nome
    base, ext = os.path.splitext(nome)
    if base.endswith(".tar"):  # foto.tar.gz -> foto (2).tar.gz
        base, ext = base[:-4], ".tar" + ext
    if not base:  # ".bashrc"
        base, ext = nome, ""
    m = re.match(r"^(.*) \((\d+)\)$", base)
    if m:
        base, n = m.group(1), int(m.group(2)) + 1
    else:
        n = 2
    while True:
        cand = f"{base} ({n}){ext}"
        if not os.path.lexists(os.path.join(pasta, cand)):
            return cand
        n += 1
