"""Notificações: ouve o `Notify` que os apps mandam ao servidor do Plasma com dbus-monitor. A ilha NÃO
substitui o servidor, o popup do KDE continua. A lista fica em memória e morre com o app."""

import re
import time

from PyQt6.QtCore import QObject, QProcess, QProcessEnvironment, pyqtSignal

MAXIMO = 30
# O dbus-monitor não escapa aspas nem quebras de linha: uma string termina onde começa o próximo argumento.
_STRING = re.compile(r'^ {3}string "(.*?)"\n(?= {3}(?:string|uint32|array|int32) )', re.M | re.S)
_URG = re.compile(r'"urgency"\s*\n\s*variant\s+byte (\d)')
_DESK = re.compile(r'"desktop-entry"\s*\n\s*variant\s+string "([^"]+)"')


def sem_marcacao(t):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", t)).strip()


def interpretar(bloco, ident):
    """Um bloco `method call` do dbus-monitor → IslandNotice, ou None."""
    s = [m.replace('\\"', '"').replace("\\n", "\n") for m in _STRING.findall(bloco)]
    app = s[0] if s else ""
    titulo = s[2] if len(s) > 2 else ""
    corpo = s[3] if len(s) > 3 else ""
    if not titulo and not corpo:
        return None
    u = _URG.search(bloco)
    d = _DESK.search(bloco)
    return {"id": ident, "at": int(time.time() * 1000), "app": app[:40], "title": sem_marcacao(titulo)[:120],
            "body": sem_marcacao(corpo)[:240], "urgent": bool(u and int(u.group(1)) >= 2),
            "desktopEntry": d.group(1)[:80] if d else ""}


class Avisos(QObject):
    chegou = pyqtSignal(dict)
    mudou = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.itens = []
        self._seq = 0
        self._acum = ""
        self._proc = None

    @property
    def ouvindo(self):
        return self._proc is not None and self._proc.state() != QProcess.ProcessState.NotRunning

    def ligar(self, sim):
        if sim and not self._proc:
            p = QProcess(self)
            env = QProcessEnvironment.systemEnvironment()
            env.insert("LC_ALL", "C")
            p.setProcessEnvironment(env)
            p.setProcessChannelMode(QProcess.ProcessChannelMode.SeparateChannels)
            p.readyReadStandardOutput.connect(self._dados)
            p.errorOccurred.connect(self._morreu)
            p.finished.connect(self._morreu)
            p.start("dbus-monitor", ["interface='org.freedesktop.Notifications',member='Notify'"])
            self._proc = p
        elif not sim and self._proc:
            p, self._proc = self._proc, None
            p.readyReadStandardOutput.disconnect()
            p.finished.disconnect()
            p.errorOccurred.disconnect()
            p.kill()
            p.waitForFinished(500)
            p.deleteLater()

    def _morreu(self, *_):
        p, self._proc = self._proc, None
        if p:
            p.deleteLater()

    def _dados(self):
        self._acum += bytes(self._proc.readAllStandardOutput()).decode("utf-8", "replace")
        partes = re.split(r"^(?=method call )", self._acum, flags=re.M)
        self._acum = partes.pop() if partes else ""
        # o último bloco só fecha quando vem o próximo cabeçalho; sem ele o aviso esperaria a notificação seguinte
        if self._acum.startswith("method call ") and re.search(r'"?\s*\n\s*int32 -?\d+\s*$', self._acum):
            partes.append(self._acum)
            self._acum = ""
        for b in partes:
            if b.startswith("method call ") and "member=Notify" in b:
                self._seq += 1
                a = interpretar(b, self._seq)
                if a:
                    self.itens.insert(0, a)
                    del self.itens[MAXIMO:]
                    self.mudou.emit()
                    self.chegou.emit(a)

    def remover(self, ident):
        self.itens = [a for a in self.itens if a["id"] != ident]
        self.mudou.emit()

    def limpar(self):
        self.itens = []
        self.mudou.emit()
