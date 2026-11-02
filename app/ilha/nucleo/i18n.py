"""Textos do back-end: a chave é a própria frase em português; i18n/en.json a traduz (como no Halo)."""

import json
from pathlib import Path

from PyQt6.QtCore import QLocale

from .config import dir_config

_I18N = Path(__file__).resolve().parent.parent / "i18n"
_en = {}
idioma = "pt_BR"


def iniciar():
    global _en, idioma
    try:
        _en = json.loads((_I18N / "en.json").read_text())
    except (OSError, ValueError):
        _en = {}
    try:
        escolha = json.loads((dir_config() / "painel.json").read_text()).get("idioma") or ""
    except (OSError, ValueError, AttributeError):
        escolha = ""
    escolha = escolha or QLocale.system().name()
    idioma = "en" if escolha.lower().startswith("en") else "pt_BR"


def t(pt, **kw):
    s = _en.get(pt, pt) if idioma == "en" else pt
    return s.format(**kw) if kw else s


def textos():
    return dict(_en) if idioma == "en" else {}


def ler(id_, rotulo, valor, detalhe="", razao=None, nivel="ok", art=None):
    """Uma `Reading` (mesmas chaves de src/shared/island.ts do Halo)."""
    r = {"id": id_, "label": rotulo, "value": str(valor), "detail": str(detalhe), "ratio": razao, "level": nivel}
    if art:
        r["art"] = art
    return r


def modulo(id_, nome, icone, leituras, acoes=(), ok=True, erro=None):
    return {"id": id_, "name": nome, "icon": icone, "readings": list(leituras), "actions": list(acoes), "ok": ok, "error": erro}


def acao(id_, rotulo, icone, ativa=None):
    a = {"id": id_, "label": rotulo, "icon": icone}
    if ativa is not None:
        a["active"] = ativa
    return a


