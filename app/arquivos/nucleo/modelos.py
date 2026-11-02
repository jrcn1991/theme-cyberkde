"""Modelos de "Criar novo": a pasta XDG de modelos (~/Modelos, ~/Templates…: cada arquivo vira uma
opção) e os modelos do KDE (.desktop Type=Link em <XDG_DATA_DIRS>/templates, como os do LibreOffice)."""

import configparser
import os
from pathlib import Path

from PyQt6.QtCore import QLocale, QMimeDatabase, QStandardPaths


def _dirs_kde():
    casa = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    outros = [Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p]
    return [d / "templates" for d in [casa] + outros]


def listar():
    """[{id, nome, icone, extensao, origem}] — id = caminho do arquivo-fonte."""
    loc = QLocale.system().name()
    db = QMimeDatabase()
    res, vistos = [], set()
    pasta = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.TemplatesLocation)
    if pasta and os.path.isdir(pasta) and os.path.realpath(pasta) != os.path.realpath(str(Path.home())):
        for f in sorted(os.listdir(pasta)):
            p = os.path.join(pasta, f)
            if os.path.isfile(p) and not f.startswith("."):
                mt = db.mimeTypeForFile(p)
                base, ext = os.path.splitext(f)
                res.append({"id": p, "nome": base, "icone": mt.iconName(), "extensao": ext, "origem": p})
                vistos.add(f)
    for d in _dirs_kde():
        if not d.is_dir():
            continue
        for arq in sorted(d.glob("*.desktop")):
            if arq.name in vistos:
                continue
            vistos.add(arq.name)
            cp = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
            cp.optionxform = str
            try:
                cp.read(arq, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if e.get("Type") != "Link" or not e.get("URL"):
                continue
            fonte = (arq.parent / e["URL"]).resolve() if not e["URL"].startswith("/") else Path(e["URL"])
            if not fonte.is_file():
                continue
            nome = e.get(f"Name[{loc}]") or e.get(f"Name[{loc.split('_')[0]}]") or e.get("Name") or fonte.stem
            nome = nome.replace("...", "").replace("…", "").strip()
            res.append({"id": str(fonte), "nome": nome, "icone": e.get("Icon", db.mimeTypeForFile(str(fonte)).iconName()),
                        "extensao": "".join(fonte.suffixes[-1:]), "origem": str(fonte)})
    return res
