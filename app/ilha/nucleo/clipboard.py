"""Histórico da área de transferência, pelo Klipper (D-Bus). Duas regras do Halo: **memória, nunca
disco**, e gerenciador de senhas manda (o Klipper não guarda o que vem marcado com
x-kde-passwordManagerHint). Sinal `clipboardHistoryUpdated` no lugar do pulso de 1 s."""

import re
import time

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot

from . import bus as B

PREVIA = 160
MAXIMO = 30
TETO = 200_000
SV, CAM, IF = "org.kde.klipper", "/klipper", "org.kde.klipper.klipper"


def especie(t):
    if re.fullmatch(r"https?://\S+", t):
        return "url"
    if re.fullmatch(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(?:rgb|hsl)a?\([^)]*\)", t):
        return "cor"
    if re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", t):
        return "email"
    return "texto"


class Clipboard(QObject):
    mudou = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.itens = []
        self._seq = 0
        self._ultimo = ""
        self._ligado = False

    def ligar(self, sim):
        if sim == self._ligado:
            return
        self._ligado = sim
        b = B.sessao()
        if not b.isConnected():
            return
        if sim:
            b.connect(SV, CAM, IF, "clipboardHistoryUpdated", self._atualizou)
            self._olhar()
        else:
            b.disconnect(SV, CAM, IF, "clipboardHistoryUpdated", self._atualizou)
            self.itens = []   # desligar apaga: nada fica guardado
            self._ultimo = ""
            self.mudou.emit()

    @pyqtSlot()
    def _atualizou(self):
        self._olhar()

    def _olhar(self):
        B.chamar(B.msg(SV, CAM, IF, "getClipboardContents"), self._chegou)

    def _chegou(self, a):
        t = str(a[0]) if a else ""
        if not t or t == self._ultimo or len(t) > TETO:
            return
        self._ultimo = t
        if not t.strip():
            return
        i = next((k for k, x in enumerate(self.itens) if x["texto"] == t), -1)
        if i >= 0:
            x = self.itens.pop(i)
            x["at"] = int(time.time() * 1000)
            self.itens.insert(0, x)
        else:
            self._seq += 1
            self.itens.insert(0, {"id": self._seq, "at": int(time.time() * 1000), "preview": t.strip()[:PREVIA],
                                  "length": len(t), "kind": especie(t.strip()), "pinned": False, "texto": t})
            soltos = [x for x in self.itens if not x["pinned"]]
            for x in soltos[MAXIMO:]:
                self.itens.remove(x)
        self.mudou.emit()

    def publicos(self):
        """O que viaja para a tela: a prévia, nunca o texto inteiro."""
        return [{k: v for k, v in x.items() if k != "texto"} for x in sorted(self.itens, key=lambda c: not c["pinned"])]

    def _item(self, ident):
        return next((x for x in self.itens if x["id"] == int(ident)), None)

    def copiar(self, ident):
        x = self._item(ident)
        if not x:
            raise OSError("item não existe mais")
        self._ultimo = x["texto"]
        B.chamar(B.msg(SV, CAM, IF, "setClipboardContents", x["texto"]))

    def fixar(self, ident):
        x = self._item(ident)
        if x:
            x["pinned"] = not x["pinned"]
            self.mudou.emit()

    def remover(self, ident):
        self.itens = [x for x in self.itens if x["id"] != int(ident)]
        self.mudou.emit()

    def limpar(self):
        self.itens = [x for x in self.itens if x["pinned"]]
        self.mudou.emit()
