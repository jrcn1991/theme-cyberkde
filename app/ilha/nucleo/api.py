"""API local: scripts publicam atividades e avisos na pílula por um socket Unix 0600 em
$XDG_RUNTIME_DIR/cyberkde-ilha.sock. Só o próprio usuário alcança; nada entra pela rede.
Protocolo (o do Halo): uma linha JSON por mensagem, resposta `ok` ou `erro: motivo`.

  {"tipo":"atividade","id":"build-1","titulo":"npm run build"}
  {"tipo":"atividade","id":"build-1","estado":"ok","detalhe":"12s"}
  {"tipo":"aviso","titulo":"Deploy pronto","detalhe":"produção","nivel":"ok"}
"""

import json
import os
import sys
import time

from PyQt6.QtCore import QObject, QTimer, pyqtSignal
from PyQt6.QtNetwork import QLocalServer

NOME = "cyberkde-ilha.sock"
MAXIMO = 20
RESQUICIO_S = 60
CURTO_S = 8
LINHA_MAX = 8192


def caminho():
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", NOME)


def _texto(v, n):
    return v.strip()[:n] if isinstance(v, str) else ""


class Api(QObject):
    mudou = pyqtSignal()
    anuncio = pyqtSignal("QVariantMap")

    def __init__(self, parent=None):
        super().__init__(parent)
        self.atividades = {}
        self._srv = None
        self._clientes = {}
        self._lim = QTimer(self, interval=15000)
        self._lim.timeout.connect(self._aparar)

    @property
    def ouvindo(self):
        return self._srv is not None and self._srv.isListening()

    def ligar(self, sim):
        if sim and not self._srv:
            a = caminho()
            QLocalServer.removeServer(a)
            s = QLocalServer(self)
            s.setSocketOptions(QLocalServer.SocketOption.UserAccessOption)
            ok = s.listen(a)   # UserAccessOption: nasce só do usuário, sem janela até o chmod abaixo
            if not ok:
                print(f"aviso: API local indisponível: {s.errorString()}", file=sys.stderr)
                s.deleteLater()
                return False
            os.chmod(a, 0o600)
            s.newConnection.connect(self._nova)
            self._srv = s
            self._lim.start()
        elif not sim and self._srv:
            self._srv.close()
            self._srv.deleteLater()
            self._srv = None
            self._lim.stop()
            try:
                os.unlink(caminho())
            except OSError:
                pass
        return True

    def _nova(self):
        while self._srv and self._srv.hasPendingConnections():
            c = self._srv.nextPendingConnection()
            self._clientes[c] = b""
            c.readyRead.connect(lambda c=c: self._ler(c))
            c.disconnected.connect(lambda c=c: self._saiu(c))

    def _saiu(self, c):
        self._clientes.pop(c, None)
        c.deleteLater()

    def _ler(self, c):
        buf = self._clientes.get(c, b"") + bytes(c.readAll())
        while b"\n" in buf:
            ln, buf = buf.split(b"\n", 1)
            if ln.strip():
                c.write(self._responder(ln))
        if len(buf) > LINHA_MAX:
            c.write(b"erro: linha longa demais\n")
            buf = b""
        self._clientes[c] = buf

    def _responder(self, ln):
        try:
            m = json.loads(ln)
            if not isinstance(m, dict):
                raise ValueError("esperava um objeto")
            self.tratar(m)
            return b"ok\n"
        except ValueError as e:
            return f"erro: {e}\n".encode()

    def tratar(self, m):
        if m.get("tipo") == "aviso":
            titulo = _texto(m.get("titulo"), 120)
            if not titulo:
                raise ValueError("aviso sem título")
            nivel = m.get("nivel") if m.get("nivel") in ("alerta", "erro") else "ok"
            self.anuncio.emit({"icon": _texto(m.get("icone"), 40) or ("WarningCircle" if nivel == "erro" else "Broadcast"),
                               "text": titulo, "detail": _texto(m.get("detalhe"), 120), "level": nivel, "kind": "aviso", "ttlMs": 4500})
            return
        if m.get("tipo") != "atividade":
            raise ValueError("tipo desconhecido (atividade ou aviso)")
        ident = _texto(m.get("id"), 80)
        if not ident:
            raise ValueError("atividade sem id")
        agora = time.time()
        antes = self.atividades.get(ident)
        estado = m["estado"] if m.get("estado") in ("ok", "erro", "andamento") else (antes["state"] if antes else "andamento")
        p = m.get("progresso")
        prog = max(0.0, min(1.0, float(p))) if isinstance(p, (int, float)) and not isinstance(p, bool) else (antes["progress"] if antes else None)
        a = {"id": ident, "title": _texto(m.get("titulo"), 120) or (antes["title"] if antes else ident),
             "detail": _texto(m.get("detalhe"), 160) or (antes["detail"] if antes else ""), "state": estado, "progress": prog,
             "source": _texto(m.get("origem"), 40) or (antes["source"] if antes else "script"),
             "startedAt": antes["startedAt"] if antes else int(agora * 1000), "updatedAt": int(agora * 1000)}
        self.atividades[ident] = a
        while len(self.atividades) > MAXIMO:
            self.atividades.pop(next(iter(self.atividades)))
        if estado != "andamento" and antes and antes["state"] == "andamento" and (agora - a["startedAt"] / 1000 >= CURTO_S or estado == "erro"):
            self.anuncio.emit({"icon": "Check" if estado == "ok" else "WarningCircle", "text": a["title"],
                               "detail": a["detail"], "level": "ok" if estado == "ok" else "erro", "kind": "aviso", "ttlMs": 4500})
        self.mudou.emit()

    def _aparar(self):
        limite = (time.time() - RESQUICIO_S) * 1000
        velhas = [k for k, a in self.atividades.items() if a["state"] != "andamento" and a["updatedAt"] < limite]
        for k in velhas:
            del self.atividades[k]
        if velhas:
            self.mudou.emit()

    def lista(self):
        return sorted(self.atividades.values(), key=lambda a: -a["updatedAt"])

    def remover(self, ident):
        if self.atividades.pop(ident, None):
            self.mudou.emit()
