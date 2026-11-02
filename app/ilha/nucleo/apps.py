"""Busca de aplicativos pelos .desktop e abertura de caminhos (porte do motor do lançador, reduzido)."""

import configparser
import os
import shutil
import unicodedata
from pathlib import Path

from PyQt6.QtCore import QProcess

_INDICE = None


def _dirs():
    casa = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    outros = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return [casa / "applications"] + [Path(p) / "applications" for p in outros if p]


def _sem_acento(t):
    return "".join(c for c in unicodedata.normalize("NFKD", t.casefold()) if not unicodedata.combining(c))


def indice():
    global _INDICE
    if _INDICE is None:
        _INDICE, vistos = [], set()
        for d in _dirs():
            for a in sorted(d.glob("*.desktop")) if d.is_dir() else []:
                if a.name in vistos:
                    continue
                vistos.add(a.name)
                cp = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
                cp.optionxform = str
                try:
                    cp.read(a, encoding="utf-8")
                    e = cp["Desktop Entry"]
                except (configparser.Error, KeyError, UnicodeDecodeError):
                    continue
                if e.get("Type") != "Application" or e.get("NoDisplay") == "true" or e.get("Hidden") == "true":
                    continue
                nome = e.get("Name[pt_BR]") or e.get("Name") or a.stem
                _INDICE.append({"id": a.name, "nome": nome, "icone": e.get("Icon", ""), "_b": _sem_acento(f"{nome} {e.get('Keywords', '')}"), "_a": str(a)})
    return _INDICE


def buscar(texto, limite=8):
    q = _sem_acento(texto.strip())
    if not q:
        return []
    achados = [a for a in indice() if q in a["_b"]]
    achados.sort(key=lambda a: (not _sem_acento(a["nome"]).startswith(q), a["nome"].casefold()))
    return [{k: a[k] for k in ("id", "nome", "icone")} for a in achados[:limite]]


def abrir_app(ident):
    a = next((x for x in indice() if x["id"] == ident), None)
    if not a or not shutil.which("gio"):
        return False
    return QProcess.startDetached("gio", ["launch", a["_a"]])[0]


def abrir_caminho(alvo):
    return QProcess.startDetached("xdg-open", [alvo])[0]
