"""Paleta da corporação, nível de movimento e idioma, lidos da configuração do tema (a mesma que o
painel usa) e observados: trocar de corporação no painel muda o DATASHARD ao vivo. Só leitura."""

import configparser
import json
import os
from pathlib import Path

from PyQt6.QtCore import QFileSystemWatcher, QLocale, QObject, QTimer, pyqtSignal

APP_DIR = Path(__file__).resolve().parent.parent
REPO = APP_DIR.parent.parent
TOKENS_CORPS = REPO / "tokens" / "corporacoes.json"
I18N = APP_DIR / "i18n"

PALETA_PADRAO = {"destaque": "#F75049", "secundaria": "#5EF6FF", "alerta": "#FB932E", "fundo": "#0E0E17"}


def dir_config():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "cyberkde"


def dir_cache():
    return Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "cyberkde-arquivos"


def _ler(arq):
    try:
        return arq.read_text().strip()
    except OSError:
        return ""


def _corps_tokens():
    try:
        dados = json.loads(TOKENS_CORPS.read_text())
    except (OSError, ValueError):
        return {}
    if isinstance(dados, dict):
        lista = dados.get("corps") or dados.get("corporacoes")
        if lista is None:
            return {k: v for k, v in dados.items() if isinstance(v, dict) and not k.startswith("_")}
    else:
        lista = dados
    return {c["id"]: c for c in lista or [] if isinstance(c, dict) and c.get("id")}


def ler_paleta():
    cfg = dir_config()
    corp = _ler(cfg / "corp") or "nenhuma"
    tokens = _corps_tokens().get(corp, {})
    paleta = {k: tokens.get(k, v) for k, v in PALETA_PADRAO.items()}
    try:
        extra = json.loads(_ler(cfg / "paleta") or "{}")
        paleta.update({k: v for k, v in extra.items() if k in PALETA_PADRAO and isinstance(v, str)})
    except ValueError:
        pass
    cor = _ler(cfg / "cor")
    if cor.startswith("#"):
        paleta["destaque"] = cor
    paleta["corp"] = corp
    paleta["nome"] = tokens.get("nome", corp.capitalize() if corp != "nenhuma" else "CyberKDE")
    return paleta


def ler_movimento():
    ini = configparser.ConfigParser()
    try:
        ini.read(dir_config() / "efeitos")
        nivel = ini.get("movimento", "nivel", fallback="completo")
    except configparser.Error:
        nivel = "completo"
    return nivel if nivel in ("completo", "reduzido", "minimo") else "completo"


def idioma_padrao():
    try:
        escolha = json.loads((dir_config() / "painel.json").read_text()).get("idioma") or ""
    except (OSError, ValueError, AttributeError):
        escolha = ""
    escolha = escolha or QLocale.system().name()
    return "en" if escolha.lower().startswith("en") else "pt_BR"


def carregar_catalogos():
    cats = {}
    for idioma in ("pt_BR", "en"):
        try:
            cats[idioma] = json.loads((I18N / f"{idioma}.json").read_text())
        except (OSError, ValueError):
            cats[idioma] = {}
    return cats


class Tema(QObject):
    """Observa ~/.config/cyberkde e avisa quando paleta ou movimento mudam."""

    mudou = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.paleta = ler_paleta()
        self.movimento = ler_movimento()
        self._obs = QFileSystemWatcher(self)
        self._atraso = QTimer(self, singleShot=True, interval=250)
        self._atraso.timeout.connect(self._reler)
        self._obs.directoryChanged.connect(self._atraso.start)
        self._obs.fileChanged.connect(self._atraso.start)
        self._vigiar()

    def _vigiar(self):
        cfg = dir_config()
        alvos = [str(cfg)] + [str(cfg / f) for f in ("cor", "corp", "paleta", "efeitos") if (cfg / f).exists()]
        atuais = set(self._obs.files() + self._obs.directories())
        novos = [a for a in alvos if a not in atuais and os.path.exists(a)]
        if novos:
            self._obs.addPaths(novos)

    def _reler(self):
        self._vigiar()  # arquivos regravados por rename saem da lista do observador
        paleta, movimento = ler_paleta(), ler_movimento()
        if paleta != self.paleta or movimento != self.movimento:
            self.paleta, self.movimento = paleta, movimento
            self.mudou.emit()
