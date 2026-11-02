"""O celular pelo KDE Connect, SÓ se o kdeconnectd já estiver de pé: autostart desligado, porque ativar o
daemon abriria porta na máquina. Quem fala com o aparelho é o daemon; a ilha só pede a ele."""

from . import bus as B

SV = "org.kde.kdeconnect"
RAIZ = "/modules/kdeconnect"
DAEMON = "org.kde.kdeconnect.daemon"
DEV = "org.kde.kdeconnect.device"
PROP = "org.freedesktop.DBus.Properties"


def ativo():
    return B.tem_dono(SV)


def _prop(caminho, iface, nome):
    r = B.bloquear(B.msg(SV, caminho, PROP, "Get", iface, nome), 1200)
    return r[0] if r else None


def dispositivos():
    if not ativo():
        return []
    r = B.bloquear(B.msg(SV, RAIZ, DAEMON, "devices", True, True), 1500)   # só alcançáveis e pareados
    res = []
    for i in (r[0] if r else []):
        c = f"{RAIZ}/devices/{i}"
        carga = _prop(f"{c}/battery", f"{DEV}.battery", "charge")
        res.append({"id": str(i), "name": str(_prop(c, DEV, "name") or i),
                    "battery": int(carga) if isinstance(carga, int) and carga >= 0 else None,
                    "charging": bool(_prop(f"{c}/battery", f"{DEV}.battery", "isCharging"))})
    return res


def _primeiro():
    d = dispositivos()
    if not d:
        raise OSError("nenhum celular ao alcance (KDE Connect)")
    return d[0]["id"]


def tocar():
    B.chamar(B.msg(SV, f"{RAIZ}/devices/{_primeiro()}/findmyphone", f"{DEV}.findmyphone", "ring"))


def ping():
    B.chamar(B.msg(SV, f"{RAIZ}/devices/{_primeiro()}/ping", f"{DEV}.ping", "sendPing"))


def enviar_texto(texto):
    """Só com o kdeconnectd já de pé: `_primeiro()` recusa sem ele, e nada aqui o ativa (autostart desligado)."""
    limpo = texto.strip()
    if not limpo:
        raise OSError("nada para enviar")
    B.chamar(B.msg(SV, f"{RAIZ}/devices/{_primeiro()}/share", f"{DEV}.share", "shareText", limpo[:20000]))


def enviar(caminho):
    from PyQt6.QtCore import QUrl
    B.chamar(B.msg(SV, f"{RAIZ}/devices/{_primeiro()}/share", f"{DEV}.share", "shareUrl", QUrl.fromLocalFile(caminho).toString()))
