"""Paleta da corporação e nível de movimento, lidos da configuração do tema e observados ao vivo."""

import configparser
import json
from pathlib import Path

from PyQt6.QtCore import QFileSystemWatcher, QObject, QTimer, pyqtSignal

from .config import dir_config

REPO = Path(__file__).resolve().parent.parent.parent.parent
TOKENS = REPO / "tokens" / "corporacoes.json"
PADRAO = {"destaque": "#F75049", "secundaria": "#5EF6FF", "alerta": "#FB932E", "fundo": "#0E0E17"}


def _ler(a):
    try:
        return a.read_text().strip()
    except OSError:
        return ""


def _corps():
    try:
        d = json.loads(TOKENS.read_text())
    except (OSError, ValueError):
        return {}
    lista = (d.get("corps") or d.get("corporacoes")) if isinstance(d, dict) else d
    if lista is None:
        return {k: v for k, v in d.items() if isinstance(v, dict) and not k.startswith("_")}
    return {c["id"]: c for c in lista if isinstance(c, dict) and c.get("id")}


def ler_paleta():
    cfg = dir_config()
    corp = _ler(cfg / "corp") or "nenhuma"
    t = _corps().get(corp, {})
    p = {k: t.get(k, v) for k, v in PADRAO.items()}
    try:
        extra = json.loads(_ler(cfg / "paleta") or "{}")
        p.update({k: v for k, v in extra.items() if k in PADRAO and isinstance(v, str)})
    except ValueError:
        pass
    cor = _ler(cfg / "cor")
    if cor.startswith("#"):
        p["destaque"] = cor
    p.update(corp=corp, nome=t.get("nome", corp.capitalize() if corp != "nenhuma" else "CyberKDE"))
    return p


def ler_efeitos():
    ini = configparser.ConfigParser()
    try:
        ini.read(dir_config() / "efeitos")
        nivel = ini.get("movimento", "nivel", fallback="completo")
        ligado = ini.get("ilha", "ligado", fallback="false").strip().lower() == "true"
    except configparser.Error:
        nivel, ligado = "completo", False
    return (nivel if nivel in ("completo", "reduzido", "minimo") else "completo"), ligado


class Tema(QObject):
    mudou = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.paleta = ler_paleta()
        self.movimento = ler_efeitos()[0]
        self._obs = QFileSystemWatcher(self)
        self._atraso = QTimer(self, singleShot=True, interval=250)
        self._atraso.timeout.connect(self._reler)
        self._obs.directoryChanged.connect(self._atraso.start)
        self._obs.fileChanged.connect(self._atraso.start)
        self._vigiar()

    def _vigiar(self):
        cfg = dir_config()
        cfg.mkdir(parents=True, exist_ok=True)
        alvos = [str(cfg)] + [str(cfg / f) for f in ("cor", "corp", "paleta", "efeitos") if (cfg / f).exists()]
        novos = [a for a in alvos if a not in self._obs.files() + self._obs.directories()]
        if novos:
            self._obs.addPaths(novos)

    def _reler(self):
        self._vigiar()   # arquivo regravado por rename sai da lista do observador
        p, m = ler_paleta(), ler_efeitos()[0]
        if p != self.paleta or m != self.movimento:
            self.paleta, self.movimento = p, m
            self.mudou.emit()
