"""org.cyberkde.Ilha: instância única, controle pelo CLI/painel e a volta dos scripts do KWin.
Também descobre se a ilha do Halo está de pé, sem nunca mexer nela."""

import json
import os
import socket

from PyQt6.QtCore import QObject, pyqtClassInfo, pyqtSlot
from PyQt6.QtDBus import QDBusAbstractAdaptor, QDBusConnection, QDBusConnectionInterface

from . import bus as B

NOME = "org.cyberkde.Ilha"
CAM = "/org/cyberkde/Ilha"

_XML = """<interface name="org.cyberkde.Ilha">
  <method name="Estado"><arg name="estado" type="s" direction="out"/></method>
  <method name="Definir"><arg name="chave" type="s" direction="in"/><arg name="json" type="s" direction="in"/><arg name="erro" type="s" direction="out"/></method>
  <method name="Demonstrar"><arg name="tipo" type="s" direction="in"/></method>
  <method name="Avisar"><arg name="titulo" type="s" direction="in"/><arg name="detalhe" type="s" direction="in"/><arg name="nivel" type="s" direction="in"/></method>
  <method name="Sair"/>
  <method name="entrega"><arg name="nonce" type="s" direction="in"/><arg name="json" type="s" direction="in"/></method>
</interface>"""


def halo_pelo_socket():
    """O socket da API do Halo responde? Arquivo sobrando de uma queda não conta."""
    a = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "halo-ilha.sock")
    if not os.path.exists(a):
        return False
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.2)
    try:
        s.connect(a)
        return True
    except OSError:
        return False
    finally:
        s.close()


@pyqtClassInfo("D-Bus Interface", NOME)
@pyqtClassInfo("D-Bus Introspection", _XML)
class _Adaptador(QDBusAbstractAdaptor):
    def __init__(self, pai, ilha):
        super().__init__(pai)
        self._i = ilha

    @pyqtSlot(result=str)
    def Estado(self):
        return json.dumps(self._i.estado_cli(), ensure_ascii=False)

    @pyqtSlot(str, str, result=str)
    def Definir(self, chave, valor):
        try:
            return self._i.definir(chave, json.loads(valor))
        except ValueError:
            return "json inválido"

    @pyqtSlot(str)
    def Demonstrar(self, tipo):
        self._i.demonstrar.emit(tipo)

    @pyqtSlot(str, str, str)
    def Avisar(self, titulo, detalhe, nivel):
        self._i.anunciar({"icon": "Broadcast", "text": titulo[:120], "detail": detalhe[:120],
                          "level": nivel if nivel in ("alerta", "erro") else "ok", "kind": "aviso", "ttlMs": 4500})

    @pyqtSlot()
    def Sair(self):
        self._i.sair()

    @pyqtSlot(str, str)
    def entrega(self, nonce, valor):
        self._i.kwin.entrega(nonce, valor)


class Servico(QObject):
    def __init__(self, ilha):
        super().__init__(ilha)
        self._obj = QObject(self)
        self._ad = _Adaptador(self._obj, ilha)

    def registrar(self):
        b = QDBusConnection.sessionBus()
        if not b.isConnected():
            return False
        r = b.interface().registerService(NOME, QDBusConnectionInterface.ServiceQueueOptions.DontQueueService,
                                          QDBusConnectionInterface.ServiceReplacementOptions.DontAllowReplacement)
        if not (r.isValid() and r.value() == QDBusConnectionInterface.RegisterServiceReply.ServiceRegistered):
            return False
        b.registerObject(CAM, self._obj, QDBusConnection.RegisterOption.ExportAdaptors)
        return True

    def liberar(self):
        b = B.sessao()
        if b.isConnected():
            b.unregisterObject(CAM)
            b.unregisterService(NOME)
