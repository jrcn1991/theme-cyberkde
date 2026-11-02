"""Roda funções fora da thread da interface e entrega o resultado por sinal na thread principal."""

import subprocess
import sys
import threading
import traceback

from PyQt6.QtCore import QObject, QRunnable, QThreadPool, pyqtSignal

_VIVAS = set()


class _Sinais(QObject):
    pronto = pyqtSignal(object)


class Tarefa(QRunnable):
    def __init__(self, fn, args):
        super().__init__()
        self.setAutoDelete(False)
        self.fn, self.args = fn, args
        self.sinais = _Sinais()
        self.parar = threading.Event()

    def run(self):
        try:
            r = self.fn(*self.args)
        except Exception as e:  # noqa: BLE001 — o erro vira resultado: a leitura diz que falhou
            traceback.print_exc(file=sys.stderr)
            r = e
        try:
            self.sinais.pronto.emit(r)
        except RuntimeError:
            pass   # o app já saiu


def rodar(fn, *args, pronto=None, pool=None):
    t = Tarefa(fn, args)
    _VIVAS.add(t)

    def fim(r):
        _VIVAS.discard(t)
        if pronto:
            pronto(r)
    t.sinais.pronto.connect(fim)
    (pool or QThreadPool.globalInstance()).start(t)
    return t


def cmd(*args, timeout=3, entrada=None):
    """Saída de um comando, ou None se ele não existe, falhou ou demorou. Nunca levanta."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, input=entrada,
                           stdin=None if entrada is not None else subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None
