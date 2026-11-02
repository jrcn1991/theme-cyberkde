"""Letras sincronizadas pelo LRCLIB. Rede só com a opção `letras` ligada (padrão: desligada;
o outro ponto de rede é o clima, em sistema.py, com a mesma regra). Cache por faixa, inclusive do "não tem": perguntar a cada pulso seria abuso."""

import json
import re

BASE = "https://lrclib.net/api"
UA = "cyberkde-ilha (https://github.com/jrcn1991/theme-cyberkde)"
CACHE_MAX = 200
_cache = {}


def interpretar_lrc(lrc):
    linhas = []
    for bruta in re.split(r"\r?\n", lrc or ""):
        m = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$", bruta)
        if m:
            linhas.append({"at": int(m.group(1)) * 60 + float(m.group(2)), "text": m.group(3).strip()})
    return sorted(linhas, key=lambda x: x["at"])


def _pedir(caminho):
    import urllib.error, urllib.request   # noqa: E401  (só com a opção ligada: puxam http, ssl e email)
    req = urllib.request.Request(BASE + caminho, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def buscar(titulo, artista, duracao):
    """Roda numa thread. [linhas], ou None. Falha de rede não entra no cache."""
    from urllib.parse import urlencode
    if not titulo:
        return None
    k = (titulo, artista, round(duracao or 0))
    if k in _cache:
        return _cache[k]
    linhas = None
    try:
        q = {"track_name": titulo, "artist_name": artista}
        if duracao:
            q["duration"] = str(round(duracao))
        d = _pedir("/get?" + urlencode(q))
        if d and d.get("syncedLyrics"):
            linhas = interpretar_lrc(d["syncedLyrics"])
        else:
            q = {"track_name": titulo}
            if artista:
                q["artist_name"] = artista
            lista = _pedir("/search?" + urlencode(q)) or []
            com = next((r for r in lista if r.get("syncedLyrics")), None)
            if com:
                linhas = interpretar_lrc(com["syncedLyrics"])
    except (OSError, ValueError):
        return None
    if len(_cache) >= CACHE_MAX:
        _cache.pop(next(iter(_cache)))
    _cache[k] = linhas or None
    return _cache[k]
