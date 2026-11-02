"""Ajudantes de D-Bus (QtDBus: sem dependência nova). O PyQt6 entrega a{sv} como dict e sinais com
QDBusMessage, então o MPRIS e o Klipper dispensam busctl e pulso (o custo medido no Halo, P0-1)."""

from PyQt6.QtDBus import QDBusConnection, QDBusMessage, QDBusPendingCallWatcher, QDBusPendingReply

_VIGIAS = set()


def sessao():
    return QDBusConnection.sessionBus()


def msg(servico, caminho, interface, metodo, *args, autostart=False):
    """autostart=False por padrão: a ilha só fala com quem já está de pé (nunca ativa kdeconnectd etc.)."""
    m = QDBusMessage.createMethodCall(servico, caminho, interface, metodo)
    if args:
        m.setArguments(list(args))
    m.setAutoStartService(autostart)
    return m


def tem_dono(nome):
    b = sessao()
    if not b.isConnected():
        return False
    r = b.interface().isServiceRegistered(nome)
    return r.isValid() and bool(r.value())


def chamar(m, ok=None, erro=None, timeout=2000):
    """Assíncrono: um player travado nunca segura a interface."""
    pendente = sessao().asyncCall(m, timeout)
    w = QDBusPendingCallWatcher(pendente)
    _VIGIAS.add(w)

    def fim(watcher):
        _VIGIAS.discard(w)
        r = QDBusPendingReply(watcher).reply()
        if r.type() == QDBusMessage.MessageType.ReplyMessage:
            if ok:
                ok(r.arguments())
        elif erro:
            erro(r.errorMessage())
        watcher.deleteLater()
    w.finished.connect(fim)
    return w


def bloquear(m, timeout=2000):
    """Síncrono, para threads de leitura e para a saída. [args] ou None."""
    from PyQt6.QtDBus import QDBus
    r = sessao().call(m, QDBus.CallMode.Block, timeout)
    return r.arguments() if r.type() == QDBusMessage.MessageType.ReplyMessage else None
