"""D-Bus de sessão: instância única e a interface org.freedesktop.FileManager1 ("Mostrar na pasta").

- org.cyberkde.Datashard (/org/cyberkde/Datashard): nome da instância. A segunda execução do
  cyberkde-arquivos.py chama Abrir(caminhos_json, token) na primeira e sai. Estado() devolve, em JSON,
  as abas e a seleção (só leitura; serve aos testes).
- org.freedesktop.FileManager1 (/org/freedesktop/FileManager1): ShowFolders, ShowItems e
  ShowItemProperties (as uris, s startupId), como o Dolphin. O nome só é pedido quando o efeito
  "datashard" está ligado (ou com --servico, a ativação pelo .service): desligado, o Dolphin continua
  respondendo. Nunca toma o nome de quem já o tem (sem substituição).
"""

import configparser
import json

from PyQt6.QtCore import QFileSystemWatcher, QObject, QTimer, pyqtClassInfo, pyqtSlot
from PyQt6.QtDBus import QDBusAbstractAdaptor, QDBusConnection, QDBusConnectionInterface, QDBusMessage

from .tema import dir_config

NOME_PROPRIO = "org.cyberkde.Datashard"
CAMINHO_PROPRIO = "/org/cyberkde/Datashard"
NOME_FM = "org.freedesktop.FileManager1"
CAMINHO_FM = "/org/freedesktop/FileManager1"

_XML_FM = """<interface name="org.freedesktop.FileManager1">
  <method name="ShowFolders"><arg name="URIs" type="as" direction="in"/><arg name="StartupId" type="s" direction="in"/></method>
  <method name="ShowItems"><arg name="URIs" type="as" direction="in"/><arg name="StartupId" type="s" direction="in"/></method>
  <method name="ShowItemProperties"><arg name="URIs" type="as" direction="in"/><arg name="StartupId" type="s" direction="in"/></method>
</interface>"""

_XML_PROPRIO = """<interface name="org.cyberkde.Datashard">
  <method name="Abrir"><arg name="caminhos" type="s" direction="in"/><arg name="token" type="s" direction="in"/></method>
  <method name="Estado"><arg name="estado" type="s" direction="out"/></method>
  <method name="AssumirGerenciador"><arg name="ok" type="b" direction="out"/></method>
</interface>"""


def efeito_ligado():
    ini = configparser.ConfigParser()
    try:
        ini.read(dir_config() / "efeitos")
        return ini.get("datashard", "ligado", fallback="false").strip().lower() == "true"
    except configparser.Error:
        return False


def _pedir_nome(bus, nome):
    r = bus.interface().registerService(nome, QDBusConnectionInterface.ServiceQueueOptions.DontQueueService,
                                        QDBusConnectionInterface.ServiceReplacementOptions.DontAllowReplacement)
    return r.isValid() and r.value() == QDBusConnectionInterface.RegisterServiceReply.ServiceRegistered


def pedir_que_assuma():
    """--servico com outra instância aberta: pede a ela que atenda o FileManager1."""
    bus = QDBusConnection.sessionBus()
    msg = QDBusMessage.createMethodCall(NOME_PROPRIO, CAMINHO_PROPRIO, NOME_PROPRIO, "AssumirGerenciador")
    resp = bus.call(msg, timeout=5000)
    return resp.type() == QDBusMessage.MessageType.ReplyMessage and bool(resp.arguments() and resp.arguments()[0])


def repassar(caminhos, token=""):
    """Manda os caminhos para a instância aberta. True se ela atendeu."""
    bus = QDBusConnection.sessionBus()
    if not bus.isConnected():
        return False
    msg = QDBusMessage.createMethodCall(NOME_PROPRIO, CAMINHO_PROPRIO, NOME_PROPRIO, "Abrir")
    msg.setArguments([json.dumps(list(caminhos)), token or ""])
    resp = bus.call(msg, timeout=5000)
    return resp.type() == QDBusMessage.MessageType.ReplyMessage


@pyqtClassInfo("D-Bus Interface", "org.freedesktop.FileManager1")
@pyqtClassInfo("D-Bus Introspection", _XML_FM)
class _AdaptadorFM(QDBusAbstractAdaptor):
    def __init__(self, pai, servico):
        super().__init__(pai)
        self._s = servico

    @pyqtSlot("QStringList", str)
    def ShowFolders(self, uris, startup):
        self._s.abrir([u for u in uris], startup)

    @pyqtSlot("QStringList", str)
    def ShowItems(self, uris, startup):
        self._s.abrir([u for u in uris], startup)

    @pyqtSlot("QStringList", str)
    def ShowItemProperties(self, uris, startup):
        self._s.abrir([u for u in uris], startup, propriedades=True)


@pyqtClassInfo("D-Bus Interface", "org.cyberkde.Datashard")
@pyqtClassInfo("D-Bus Introspection", _XML_PROPRIO)
class _AdaptadorProprio(QDBusAbstractAdaptor):
    def __init__(self, pai, servico):
        super().__init__(pai)
        self._s = servico

    @pyqtSlot(str, str)
    def Abrir(self, caminhos, token):
        try:
            lista = [str(c) for c in json.loads(caminhos)]
        except (ValueError, TypeError):
            lista = []
        self._s.abrir(lista, token)

    @pyqtSlot(result=bool)
    def AssumirGerenciador(self):
        """Chamado pelo processo que o .service ativou quando já havia uma instância: ela pega o nome
        org.freedesktop.FileManager1 e o daemon entrega a ela a chamada pendente."""
        return self._s.fm or self._s.registrar_fm()

    @pyqtSlot(result=str)
    def Estado(self):
        return json.dumps(self._s.arquivos.estado(), ensure_ascii=False)


class Servico(QObject):
    """Liga as interfaces ao objeto `arquivos`. `ativar(token)` traz a janela para a frente."""

    def __init__(self, arquivos, ativar, reusar_primeira=False, parent=None):
        super().__init__(parent)
        self.arquivos = arquivos
        self._ativar = ativar
        self._reusar = reusar_primeira   # ativado pelo .service sem caminhos: a 1ª chamada usa a aba aberta
        self.fm = False
        self._objFM = QObject(self)
        self._adFM = _AdaptadorFM(self._objFM, self)
        self._objProprio = QObject(self)
        self._adProprio = _AdaptadorProprio(self._objProprio, self)

    def registrar_proprio(self):
        """Pede o nome da instância. False: já há outra (ou não há D-Bus de sessão)."""
        bus = QDBusConnection.sessionBus()
        if not bus.isConnected() or not _pedir_nome(bus, NOME_PROPRIO):
            return False
        bus.registerObject(CAMINHO_PROPRIO, self._objProprio, QDBusConnection.RegisterOption.ExportAdaptors)
        return True

    def registrar_fm(self):
        """Pede org.freedesktop.FileManager1. False se outro (o Dolphin) já o tem."""
        bus = QDBusConnection.sessionBus()
        if not bus.isConnected():
            return False
        bus.registerObject(CAMINHO_FM, self._objFM, QDBusConnection.RegisterOption.ExportAdaptors)
        self.fm = _pedir_nome(bus, NOME_FM)
        if not self.fm:
            bus.unregisterObject(CAMINHO_FM)
        return self.fm

    def acompanhar_efeito(self, fixo=False):
        """Liga/desliga o FileManager1 quando a usuária muda o efeito "datashard" com o app aberto.
        `fixo` (--servico): ativado pelo .service, não solta o nome."""
        self._fixo = fixo
        cfg = dir_config()
        self._obs = QFileSystemWatcher(self)
        self._atraso = QTimer(self, singleShot=True, interval=300)
        self._atraso.timeout.connect(self._reler_efeito)
        self._obs.directoryChanged.connect(self._atraso.start)
        self._obs.fileChanged.connect(self._atraso.start)
        for alvo in (cfg, cfg / "efeitos"):
            if alvo.exists():
                self._obs.addPath(str(alvo))

    def _reler_efeito(self):
        arq = dir_config() / "efeitos"
        if arq.exists() and str(arq) not in self._obs.files():
            self._obs.addPath(str(arq))   # regravado por rename
        ligado = efeito_ligado()
        if ligado and not self.fm:
            self.registrar_fm()
        elif not ligado and self.fm and not self._fixo:
            bus = QDBusConnection.sessionBus()
            bus.unregisterService(NOME_FM)
            bus.unregisterObject(CAMINHO_FM)
            self.fm = False

    def liberar(self):
        bus = QDBusConnection.sessionBus()
        if not bus.isConnected():
            return
        if self.fm:
            bus.unregisterService(NOME_FM)
            bus.unregisterObject(CAMINHO_FM)
        bus.unregisterService(NOME_PROPRIO)
        bus.unregisterObject(CAMINHO_PROPRIO)

    def abrir(self, caminhos, token="", propriedades=False):
        reusar = self._reusar
        self._reusar = False
        if caminhos:
            self.arquivos.mostrar(caminhos, reusar=reusar)
            if propriedades:
                from .principal import _local
                alvo = _local(caminhos[0])
                if alvo:
                    self.arquivos.pedirPropriedades.emit(alvo)
        self._ativar(token)
