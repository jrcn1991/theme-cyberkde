"""A gaveta: arquivo = REFERÊNCIA (nunca cópia; se sumir do disco, o item diz); texto solto = arquivo na
pasta do app; URL = endereço. Tirar da gaveta só apaga o que é do app, nunca arquivo da usuária."""

import os
import re
import time
from pathlib import Path
from urllib.parse import unquote, urlparse

from . import dados as D

LIMITE_TEXTO = 1024 * 1024


def pasta_textos():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "cyberkde" / "ilha-gaveta"


def eh_url(p):
    return bool(re.match(r"https?://", p))


def _do_app(p):
    try:
        return Path(p).resolve().is_relative_to(pasta_textos().resolve())
    except OSError:
        return False


def nome_de(p):
    if eh_url(p):
        u = urlparse(p)
        return f"{u.netloc}{'' if u.path == '/' else u.path}"[:60]
    return os.path.basename(p.rstrip("/")) or p


def itens(caminhos):
    res = []
    for p in caminhos:
        url = eh_url(p)
        res.append({"path": p, "name": nome_de(p), "exists": url or os.path.exists(p),
                    "kind": "url" if url else ("texto" if _do_app(p) else "arquivo")})
    return res


def _normal(entrada):
    e = str(entrada).strip()
    if e.startswith("file://"):
        return unquote(urlparse(e).path)
    return e


def guardar(lista, entradas):
    """Acrescenta (sem repetir) e devolve (lista nova, quantos entraram)."""
    novos = 0
    for e in entradas:
        p = _normal(e)
        if not p or p in lista or not (eh_url(p) or os.path.isabs(p)):
            continue
        lista = lista + [p]
        novos += 1
    return lista[-D.LIMITE_GAVETA:], novos


def guardar_texto(lista, texto):
    t = texto.strip()
    if not t:
        return lista, 0
    if eh_url(t) and " " not in t:
        return guardar(lista, [t])
    if len(t.encode()) > LIMITE_TEXTO:
        raise OSError("texto grande demais para a gaveta")
    pasta = pasta_textos()
    pasta.mkdir(parents=True, exist_ok=True)
    os.chmod(pasta, 0o700)
    base = re.sub(r"[^\w -]", "", t[:32], flags=re.U).strip() or "trecho"
    arq = pasta / f"{base} {time.strftime('%Y%m%d-%H%M%S')}.txt"
    k = 2
    while arq.exists():
        arq = pasta / f"{base} {time.strftime('%Y%m%d-%H%M%S')} {k}.txt"
        k += 1
    arq.write_text(t)
    return guardar(lista, [str(arq)])


def remover(lista, caminho):
    if _do_app(caminho):
        try:
            os.unlink(caminho)
        except OSError:
            pass
    return [p for p in lista if p != caminho]


def limpar(lista):
    for p in lista:
        if _do_app(p):
            try:
                os.unlink(p)
            except OSError:
                pass
    return []
