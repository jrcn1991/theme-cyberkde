"""ServiceMenus do KDE (as ações extras do menu de contexto do Dolphin): .desktop em
<XDG_DATA_DIRS>/kio/servicemenus e ~/.local/share/kio/servicemenus (e o antigo kservices5/ServiceMenus).

Como o KIO: os da pasta do usuário só valem se o arquivo for executável (regra de segurança do KDE
desde o KF 5.85); respeita MimeType (com curingas e herança), X-KDE-Protocols (só "file"),
X-KDE-MinNumberOfUrls/MaxNumberOfUrls/RequiredNumberOfUrls, TryExec, Hidden/NoDisplay e X-KDE-Submenu.
Exec: %f %F %u %U %n %N %d %D %i %c %k, com aspas como a spec Desktop Entry."""

import configparser
import os
import shlex
import shutil
from pathlib import Path

from PyQt6.QtCore import QLocale, QMimeDatabase, QProcess, QUrl

_TIPOS_OK = ("KonqPopupMenu/Plugin",)


def _dirs():
    casa = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    outros = [Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p]
    res = []
    for base, do_usuario in [(casa, True)] + [(d, False) for d in outros]:
        for sub in ("kio/servicemenus", "kservices5/ServiceMenus"):
            res.append((base / sub, do_usuario))
    return res


def _texto(sec, chave, loc):
    for k in (f"{chave}[{loc}]", f"{chave}[{loc.split('_')[0]}]", chave):
        if k in sec:
            return sec[k]
    return ""


def carregar():
    """Lista de ações: {id, nome, icone, submenu, mimes, min, max, exec, arquivo}."""
    loc = QLocale.system().name()
    vistos, acoes = set(), []
    for pasta, do_usuario in _dirs():
        if not pasta.is_dir():
            continue
        for arq in sorted(pasta.glob("*.desktop")):
            if arq.name in vistos:
                continue   # o do usuário (primeiro na lista) vence o do sistema
            vistos.add(arq.name)
            if do_usuario and not os.access(arq, os.X_OK):
                continue
            cp = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
            cp.optionxform = str
            try:
                cp.read(arq, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if not cp.has_section("Desktop Entry"):
                continue
            e = cp["Desktop Entry"]
            tipos = e.get("X-KDE-ServiceTypes", "") + ";" + e.get("ServiceTypes", "")
            if e.get("Type", "Service") != "Service" or not any(t in tipos for t in _TIPOS_OK):
                continue
            if e.get("Hidden", "false") == "true":
                continue
            protocolos = [p.strip() for p in e.get("X-KDE-Protocols", "").split(",") if p.strip()]
            if protocolos and "file" not in protocolos and "KIO::Local" not in protocolos:
                continue
            mimes = [m.strip() for m in e.get("MimeType", "all/all").replace(",", ";").split(";") if m.strip()]
            req = e.get("X-KDE-RequiredNumberOfUrls", "")
            minimo = int(e.get("X-KDE-MinNumberOfUrls", "0") or 0)
            maximo = int(e.get("X-KDE-MaxNumberOfUrls", "0") or 0)
            submenu = _texto(e, "X-KDE-Submenu", loc)
            for nome_acao in [a.strip() for a in e.get("Actions", "").split(";") if a.strip()]:
                sec_nome = f"Desktop Action {nome_acao}"
                if not cp.has_section(sec_nome):
                    continue
                a = cp[sec_nome]
                exe = a.get("Exec", "")
                if not exe or a.get("NoDisplay", "false") == "true":
                    continue
                tente = a.get("TryExec", "")
                if tente and not shutil.which(tente) and not os.access(tente, os.X_OK):
                    continue
                acoes.append({
                    "id": f"{arq.name}#{nome_acao}", "nome": _texto(a, "Name", loc) or nome_acao,
                    "icone": a.get("Icon", e.get("Icon", "")), "submenu": submenu, "mimes": mimes,
                    "min": minimo, "max": maximo, "requeridos": [int(x) for x in req.replace(",", " ").split() if x.isdigit()],
                    "exec": exe, "arquivo": str(arq),
                })
    return acoes


def _casa_mime(padroes, mime_item):
    """mime_item: (nome, ancestrais, eh_pasta)."""
    nome, ancestrais, eh_pasta = mime_item
    todos = [nome] + ancestrais
    for p in padroes:
        if p in ("all/all", "*", "*/*"):
            return True
        if p == "all/allfiles":
            if not eh_pasta:
                return True
            continue
        if p.endswith("/*"):
            if any(m.startswith(p[:-1]) for m in todos):
                return True
        elif p in todos:
            return True
    return False


def para(caminhos, acoes=None):
    """Ações que servem para TODOS os caminhos, sem o campo exec (para o QML)."""
    caminhos = [c for c in caminhos if c]
    if not caminhos:
        return []
    acoes = carregar() if acoes is None else acoes
    db = QMimeDatabase()
    infos = []
    for c in caminhos:
        mt = db.mimeTypeForFile(c)
        infos.append((mt.name(), list(mt.allAncestors()), os.path.isdir(c)))
    n = len(caminhos)
    res = []
    for a in acoes:
        if a["min"] and n < a["min"] or a["max"] and n > a["max"]:
            continue
        if a["requeridos"] and n not in a["requeridos"]:
            continue
        if all(_casa_mime(a["mimes"], i) for i in infos):
            res.append({k: a[k] for k in ("id", "nome", "icone", "submenu")})
    res.sort(key=lambda a: (a["submenu"].casefold(), a["nome"].casefold()))
    return res


def montar_comando(exe, caminhos, nome_acao="", arquivo_desktop=""):
    """Lista de argumentos com os códigos de campo trocados (spec Desktop Entry)."""
    try:
        partes = shlex.split(exe)
    except ValueError:
        return []
    urls = [QUrl.fromLocalFile(c).toString() for c in caminhos]
    args = []
    for p in partes:
        if p in ("%F", "%U", "%N", "%D"):
            args += {"%F": caminhos, "%U": urls, "%N": caminhos,
                     "%D": [os.path.dirname(c) for c in caminhos]}[p]
            continue
        if p == "%i":
            continue   # sem ícone
        troca = {"%f": caminhos[0] if caminhos else "", "%u": urls[0] if urls else "",
                 "%n": caminhos[0] if caminhos else "", "%d": os.path.dirname(caminhos[0]) if caminhos else "",
                 "%c": nome_acao, "%k": arquivo_desktop, "%%": "%"}
        for k, v in troca.items():
            p = p.replace(k, v)
        if p:
            args.append(p)
    return args


def executar(ident, caminhos):
    """Roda a ação destacada. Os %f/%u de um item só: uma execução por item (como o KIO)."""
    acao = next((a for a in carregar() if a["id"] == ident), None)
    if not acao or not caminhos:
        return False
    um_por_vez = any(c in acao["exec"] for c in ("%f", "%u", "%n", "%d")) and not any(
        c in acao["exec"] for c in ("%F", "%U", "%N", "%D"))
    lotes = [[c] for c in caminhos] if um_por_vez else [caminhos]
    ok = True
    for lote in lotes:
        args = montar_comando(acao["exec"], lote, acao["nome"], acao["arquivo"])
        if not args:
            return False
        ok = QProcess.startDetached(args[0], args[1:], os.path.dirname(lote[0]))[0] and ok
    return ok
