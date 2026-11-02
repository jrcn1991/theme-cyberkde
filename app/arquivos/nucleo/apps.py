"""Abrir arquivos: app padrão (kioclient exec / xdg-open), "Abrir com…" pela lista de .desktop do
mimeapps.list e do mimeinfo.cache (spec XDG), e terminal na pasta. Tudo destacado (startDetached)."""

import configparser
import os
import shutil
from pathlib import Path

from PyQt6.QtCore import QLocale, QMimeDatabase, QProcess


def _dirs_config():
    casa = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    outros = [Path(p) for p in (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":") if p]
    return [casa] + outros


def _dirs_apps():
    casa = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    outros = [Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p]
    return [d / "applications" for d in [casa] + outros]


def _ini(arq):
    cp = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    cp.optionxform = str
    try:
        cp.read(arq, encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        return None
    return cp


def _lista(valor):
    return [v.strip() for v in (valor or "").split(";") if v.strip()]


def _arquivos_mimeapps():
    desktop = (os.environ.get("XDG_CURRENT_DESKTOP") or "").lower().split(":")
    res = []
    for d in _dirs_config():
        for de in desktop:
            if de:
                res.append(d / f"{de}-mimeapps.list")
        res.append(d / "mimeapps.list")
    for d in _dirs_apps():
        for de in desktop:
            if de:
                res.append(d / f"{de}-mimeapps.list")
        res.append(d / "mimeapps.list")
    return [a for a in res if a.exists()]


_INDICE = None


def _indice_desktop():
    """id -> caminho do .desktop (o primeiro dir vence, como na spec)."""
    global _INDICE
    if _INDICE is None:
        _INDICE = {}
        for d in _dirs_apps():
            if not d.is_dir():
                continue
            for raiz, _, arqs in os.walk(d):
                for a in arqs:
                    if a.endswith(".desktop"):
                        p = Path(raiz) / a
                        ident = str(p.relative_to(d)).replace("/", "-")
                        _INDICE.setdefault(ident, p)
    return _INDICE


def _info_desktop(ident):
    p = _indice_desktop().get(ident)
    if not p:
        return None
    cp = _ini(p)
    if not cp or not cp.has_section("Desktop Entry"):
        return None
    e = cp["Desktop Entry"]
    if e.get("Hidden", "false") == "true" or e.get("Type", "Application") != "Application":
        return None
    loc = QLocale.system().name()
    nome = e.get(f"Name[{loc}]") or e.get(f"Name[{loc.split('_')[0]}]") or e.get("Name") or ident
    return {"id": ident, "nome": nome, "icone": e.get("Icon", "application-x-executable"), "arquivo": str(p),
            "semExibir": e.get("NoDisplay", "false") == "true"}


def apps_para(caminho):
    db = QMimeDatabase()
    mt = db.mimeTypeForFile(caminho)
    mimes = [mt.name()] + list(mt.allAncestors())
    padrao, adicionados, removidos = [], [], set()
    for arq in _arquivos_mimeapps():
        cp = _ini(arq)
        if not cp:
            continue
        for m in mimes:
            if cp.has_section("Default Applications") and m in cp["Default Applications"]:
                padrao += _lista(cp["Default Applications"][m])
            if cp.has_section("Added Associations") and m in cp["Added Associations"]:
                adicionados += _lista(cp["Added Associations"][m])
            if cp.has_section("Removed Associations") and m in cp["Removed Associations"]:
                removidos.update(_lista(cp["Removed Associations"][m]))
    cache = []
    for d in _dirs_apps():
        cp = _ini(d / "mimeinfo.cache")
        if cp and cp.has_section("MIME Cache"):
            for m in mimes:
                cache += _lista(cp["MIME Cache"].get(m))
    res, vistos = [], set()
    primeiro_padrao = True
    for ident in padrao + adicionados + cache:
        if ident in vistos or ident in removidos:
            continue
        vistos.add(ident)
        info = _info_desktop(ident)
        if not info:
            continue
        info["padrao"] = primeiro_padrao and ident in padrao
        if info["padrao"]:
            primeiro_padrao = False
        res.append(info)
    if res and not any(r["padrao"] for r in res):
        res[0]["padrao"] = True
    return res


def abrir(caminho):
    if shutil.which("kioclient"):
        return QProcess.startDetached("kioclient", ["exec", caminho])[0]
    return QProcess.startDetached("xdg-open", [caminho])[0]


def abrir_com(caminho, ident):
    info = _info_desktop(ident)
    if not info:
        return False
    if shutil.which("gio"):
        return QProcess.startDetached("gio", ["launch", info["arquivo"], caminho])[0]
    if shutil.which("kioclient"):
        return QProcess.startDetached("kioclient", ["exec", caminho, info["arquivo"]])[0]
    return False


def comando_terminal():
    for t in ("konsole", "x-terminal-emulator", "gnome-terminal", "xterm"):
        if shutil.which(t):
            return t
    return ""


def abrir_terminal(pasta):
    t = comando_terminal()
    if not t:
        return False
    args = ["--workdir", pasta] if t == "konsole" else []
    return QProcess.startDetached(t, args, pasta)[0]


def todos_apps():
    """Aplicativos que abrem arquivos (para "Abrir com outro aplicativo…"), em ordem de nome."""
    res = []
    for ident in _indice_desktop():
        info = _info_desktop(ident)
        if not info or info["semExibir"]:
            continue
        cp = _ini(_indice_desktop()[ident])
        exe = cp["Desktop Entry"].get("Exec", "") if cp and cp.has_section("Desktop Entry") else ""
        if any(c in exe for c in ("%f", "%F", "%u", "%U")):
            res.append({k: info[k] for k in ("id", "nome", "icone")})
    res.sort(key=lambda a: a["nome"].casefold())
    return res


def definir_padrao(mime, ident):
    """O mesmo que "xdg-mime default <app> <mime>" (grava ~/.config/mimeapps.list)."""
    if not _info_desktop(ident) or not shutil.which("xdg-mime"):
        return False
    proc = QProcess()
    proc.start("xdg-mime", ["default", ident, mime])
    return proc.waitForFinished(5000) and proc.exitCode() == 0


def enviar_email(caminhos):
    if not caminhos or not shutil.which("xdg-email"):
        return False
    args = []
    for c in caminhos:
        args += ["--attach", c]
    return QProcess.startDetached("xdg-email", args)[0]
