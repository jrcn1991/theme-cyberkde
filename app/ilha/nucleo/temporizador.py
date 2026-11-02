"""O temporizador (um só, com `end` nulo é cronômetro) e o histórico de foco. Uma sessão conta quando um
temporizador de 5 minutos ou mais CHEGA AO FIM: parar no meio não conta, cronômetro também não."""

import time
from datetime import date, datetime, timedelta

from PyQt6.QtCore import QObject, QTimer, pyqtSignal

from .i18n import t

MINIMO_MIN = 5


class Temporizador(QObject):
    mudou = pyqtSignal()
    acabou = pyqtSignal(str, float)   # rótulo, minutos

    def __init__(self, parent=None):
        super().__init__(parent)
        self.vivo = None
        self._rel = QTimer(self, singleShot=True)
        self._rel.timeout.connect(self._fim)

    def iniciar(self, minutos, rotulo=""):
        m = float(minutos)
        if not 0 < m <= 24 * 60:
            raise OSError(t("minutos entre 1 e 1440"))
        agora = int(time.time() * 1000)
        ms = round(m * 60_000)
        self.vivo = {"end": agora + ms, "start": agora, "label": str(rotulo)[:40], "minutes": m}
        self._rel.start(ms)
        self.mudou.emit()

    def cronometro(self, rotulo=""):
        self._rel.stop()
        self.vivo = {"end": None, "start": int(time.time() * 1000), "label": str(rotulo)[:40], "minutes": 0}
        self.mudou.emit()

    def parar(self):
        self._rel.stop()
        self.vivo = None
        self.mudou.emit()

    def _fim(self):
        v, self.vivo = self.vivo, None
        self.mudou.emit()
        if v:
            self.acabou.emit(v["label"], v["minutes"])


def _dia(ms):
    return datetime.fromtimestamp(ms / 1000).date()


def registrar(sessoes, minutos, agora_ms=None):
    """Devolve a lista nova (a mesma, se a sessão foi curta demais para contar)."""
    if minutos < MINIMO_MIN:
        return sessoes
    return (sessoes + [{"at": agora_ms or int(time.time() * 1000), "minutes": round(minutos)}])[-400:]


def resumo(sessoes, hoje=None):
    """{hoje, semana: minutos por dia (há 6 dias → hoje), sequencia}"""
    hoje = hoje or date.today()
    por_dia = {}
    for s in sessoes:
        try:
            d = _dia(s["at"])
            por_dia[d] = por_dia.get(d, 0) + int(s["minutes"])
        except (KeyError, TypeError, ValueError, OSError):
            continue
    semana = [por_dia.get(hoje - timedelta(days=k), 0) for k in range(6, -1, -1)]
    d = hoje if hoje in por_dia else hoje - timedelta(days=1)   # conta hoje ou ontem
    seq = 0
    while d in por_dia:
        seq += 1
        d -= timedelta(days=1)
    return {"hoje": semana[-1], "semana": semana, "sequencia": seq}
