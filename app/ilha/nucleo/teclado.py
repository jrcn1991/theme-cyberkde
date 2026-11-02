"""Caps Lock e Num Lock pelos LEDs do sysfs: no Wayland ninguém lê o teclado dos outros, mas o kernel
publica cada LED. Sysfs não avisa, então um relógio de 200 ms (microssegundos por leitura), e só fala quando muda."""

import glob
import os

from PyQt6.QtCore import QObject, QTimer, pyqtSignal

LEDS = os.environ.get("CYBERKDE_ILHA_LEDS", "/sys/class/leds")


def caminhos():
    return (glob.glob(f"{LEDS}/*::capslock/brightness"), glob.glob(f"{LEDS}/*::numlock/brightness"))


def aceso(lista):
    if not lista:
        return None
    for a in lista:
        try:
            with open(a) as f:
                if f.read().strip() not in ("", "0"):
                    return True
        except OSError:
            pass
    return False


class Teclado(QObject):
    mudou = pyqtSignal(str, bool)   # "caps"|"num", aceso

    def __init__(self, parent=None):
        super().__init__(parent)
        self._rel = QTimer(self, interval=200)
        self._rel.timeout.connect(self._olhar)
        self._c = ([], [])
        self.caps = self.num = None

    def ligar(self, sim):
        if sim:
            self._c = caminhos()
            self.caps, self.num = aceso(self._c[0]), aceso(self._c[1])
            if self._c[0] or self._c[1]:
                self._rel.start()
        else:
            self._rel.stop()

    def _olhar(self):
        c, n = aceso(self._c[0]), aceso(self._c[1])
        if c != self.caps:
            self.caps = c
            self.mudou.emit("caps", bool(c))
        if n != self.num:
            self.num = n
            self.mudou.emit("num", bool(n))
