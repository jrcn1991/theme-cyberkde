"""Volume, saídas e microfone por pactl. `pactl subscribe` avisa cada mudança: só a MUDANÇA vira HUD
(o sink também "muda" quando um fluxo começa, e anunciar isso seria ruído)."""

import re

from PyQt6.QtCore import QObject, QProcess, QTimer, pyqtSignal

from .tarefas import cmd, rodar


def ler_volume():
    v, m = cmd("pactl", "get-sink-volume", "@DEFAULT_SINK@"), cmd("pactl", "get-sink-mute", "@DEFAULT_SINK@")
    if v is None or m is None:
        return None
    n = re.search(r"(\d+)%", v)
    return {"nivel": int(n.group(1)) if n else 0, "mudo": "yes" in m or "sim" in m}


def saidas():
    s = cmd("pactl", "-f", "json", "list", "sinks")
    if s is None:
        return []
    import json
    try:
        return [{"nome": x.get("name", ""), "descricao": x.get("description", "")} for x in json.loads(s)]
    except ValueError:
        return []


def saida_padrao():
    return (cmd("pactl", "get-default-sink") or "").strip()


def mic_mudo():
    s = cmd("pactl", "get-source-mute", "@DEFAULT_SOURCE@")
    return None if s is None else ("yes" in s or "sim" in s)


def _do_tema(pid, raiz=None):
    """O PID é a própria ilha ou um filho dela (o parec do espectro)?"""
    import os
    raiz = raiz or os.getpid()
    for _ in range(64):
        if pid == raiz:
            return True
        try:
            with open("/proc/%d/stat" % pid) as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])   # o campo depois do nome é o PPID
        except (OSError, ValueError, IndexError):
            return False
        if pid <= 1:
            return False
    return False


def quem_grava():
    """Quem está com o MICROFONE aberto: a ilha mostra, para não ser surpresa. Não contam a captura de um
    monitor (o som que sai, não um microfone: é o que o espectro da própria ilha lê) nem os processos dela."""
    import json
    try:
        saidas_ = json.loads(cmd("pactl", "-f", "json", "list", "source-outputs") or "[]")
    except ValueError:
        return []
    monitores, sinks = set(), set()
    try:
        for f in json.loads(cmd("pactl", "-f", "json", "list", "sources") or "[]"):
            if f.get("monitor_source") is None and (f.get("monitor_of_sink") not in (None, "", "n/a") or str(f.get("name", "")).endswith(".monitor")):
                monitores.add(f.get("index"))
        sinks = {x.get("name") for x in json.loads(cmd("pactl", "-f", "json", "list", "sinks") or "[]")}
    except ValueError:
        pass
    nomes = []
    for x in saidas_:
        p = x.get("properties") or {}
        alvo = str(p.get("target.object") or "")
        if x.get("source") in monitores or alvo in sinks or alvo.endswith(".monitor") or alvo == "@DEFAULT_MONITOR@":
            continue
        try:
            if _do_tema(int(p.get("application.process.id") or 0)):
                continue
        except ValueError:
            pass
        nomes.append(p.get("application.name", "?"))
    return nomes


def definir_volume(pct):
    return cmd("pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{max(0, min(150, int(pct)))}%") is not None


def alternar_mudo():
    return cmd("pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle") is not None


def alternar_mic():
    return cmd("pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle") is not None


def definir_saida(nome):
    return cmd("pactl", "set-default-sink", nome) is not None


def trocar_saida():
    """A próxima saída da lista, em círculo. Devolve a descrição dela."""
    lista = saidas()
    if not lista:
        raise OSError("sem saídas de áudio")
    atual = saida_padrao()
    k = next((i for i, s in enumerate(lista) if s["nome"] == atual), -1)
    alvo = lista[(k + 1) % len(lista)]
    if not definir_saida(alvo["nome"]):
        raise OSError("pactl não respondeu")
    return alvo["descricao"]


class Volume(QObject):
    """HUD: vigia o `pactl subscribe` e lê o volume numa thread, agrupando rajadas."""
    mudou = pyqtSignal(int, bool)   # nível, mudo
    tocou = pyqtSignal()            # algo no sink mudou (invalida a memória do módulo)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.visto = None
        self._proc = None
        self._lendo = False
        self._atraso = QTimer(self, singleShot=True, interval=60)
        self._atraso.timeout.connect(self._ler)

    def ligar(self, sim):
        if sim and not self._proc:
            self._proc = QProcess(self)
            self._proc.readyReadStandardOutput.connect(self._dados)
            self._proc.start("pactl", ["subscribe"])
            self._ler()
        elif not sim and self._proc:
            p, self._proc = self._proc, None
            p.readyReadStandardOutput.disconnect()
            p.kill()
            p.waitForFinished(500)
            p.deleteLater()

    def _dados(self):
        s = bytes(self._proc.readAllStandardOutput()).decode("utf-8", "replace")
        if "sink" in s or "server" in s or "source" in s:   # source: microfone mudo ou em uso
            self.tocou.emit()
            self._atraso.start()

    def _ler(self):
        if not self._lendo:
            self._lendo = True
            rodar(ler_volume, pronto=self._lido)

    def _lido(self, r):
        self._lendo = False
        if not isinstance(r, dict):
            return
        novo = (r["nivel"], r["mudo"])
        if self.visto is not None and novo != self.visto:
            self.mudou.emit(*novo)
        self.visto = novo
