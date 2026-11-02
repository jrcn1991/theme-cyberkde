"""Roda funções Python fora da thread da interface (QThreadPool) e entrega o resultado por sinal na
thread principal. A função recebe a própria tarefa como 1º argumento: `t.cancelada()` para parar
cedo e `t.parcial(x)` para mandar resultados aos poucos."""

import sys
import threading
import traceback

from PyQt6.QtCore import QObject, QRunnable, QThreadPool, pyqtSignal

_VIVAS = set()   # o Python precisa segurar as tarefas até o resultado chegar


class _Sinais(QObject):
    pronto = pyqtSignal(object)
    parcial = pyqtSignal(object)


class Tarefa(QRunnable):
    def __init__(self, fn, *args):
        super().__init__()
        self.setAutoDelete(False)
        self.fn, self.args = fn, args
        self.sinais = _Sinais()
        self._parar = threading.Event()

    def cancelar(self):
        self._parar.set()

    def cancelada(self):
        return self._parar.is_set()

    def parcial(self, valor):
        try:
            self.sinais.parcial.emit(valor)
        except RuntimeError:
            self.cancelar()

    def run(self):
        try:
            r = self.fn(self, *self.args)
        except Exception as e:  # noqa: BLE001 — erro vira resultado, a interface decide
            if type(e).__name__ != "Cancelado":
                traceback.print_exc(file=sys.stderr)
            r = e
        try:
            self.sinais.pronto.emit(r)
        except RuntimeError:
            pass   # o app já saiu e levou o QObject dos sinais: não há mais quem receba


def rodar(fn, *args, pronto=None, parcial=None, pool=None):
    t = Tarefa(fn, *args)
    _VIVAS.add(t)

    def _fim(r):
        _VIVAS.discard(t)
        if pronto:
            pronto(r)
    t.sinais.pronto.connect(_fim)
    if parcial:
        t.sinais.parcial.connect(parcial)
    (pool or QThreadPool.globalInstance()).start(t)
    return t
