"""Cafeína (ScreenSaver.Inhibit) e não perturbe (Notifications.Inhibit). As duas inibições valem ENQUANTO
A CONEXÃO QUE PEDIU ESTIVER VIVA (medido no Halo: pelo busctl somem na hora); a conexão do QtDBus fica."""

import time

from PyQt6.QtCore import QMetaType, QObject, QTimer, pyqtSignal
from PyQt6.QtDBus import QDBusArgument

from . import bus as B
from .i18n import t

SS, SS_C, SS_I = "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver"
NT, NT_C, NT_I = "org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications"
PROP = "org.freedesktop.DBus.Properties"


def _u32(n):
    """O cookie é `u`: um int do Python iria como int32 e o servidor recusaria, sem aviso nenhum."""
    return QDBusArgument(int(n), QMetaType.Type.UInt.value)


class Inibir(QObject):
    mudou = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.cookie_tela = None
        self.ate = None
        self.cookie_avisos = None
        self._soltar = QTimer(self, singleShot=True)
        self._soltar.timeout.connect(self._acabou)

    # ---- cafeína
    def alternar_cafeina(self, minutos=0):
        minutos = float(minutos or 0)
        self._soltar.stop()
        if self.cookie_tela is not None and not minutos:
            B.chamar(B.msg(SS, SS_C, SS_I, "UnInhibit", _u32(self.cookie_tela)))
            self.cookie_tela, self.ate = None, None
            self.mudou.emit()
            return
        if self.cookie_tela is None:
            r = B.bloquear(B.msg(SS, SS_C, SS_I, "Inhibit", "cyberkde-ilha", t("Cafeína pedida na ilha")))
            if not r:
                raise OSError(t("o serviço de proteção de tela não respondeu"))
            self.cookie_tela = int(r[0])
        if minutos > 0:
            self.ate = time.time() + minutos * 60
            self._soltar.start(int(minutos * 60_000))
        else:
            self.ate = None
        self.mudou.emit()

    def _acabou(self):
        if self.cookie_tela is not None:
            self.alternar_cafeina()

    # ---- não perturbe
    def em_silencio(self):
        r = B.bloquear(B.msg(NT, NT_C, PROP, "Get", NT_I, "Inhibited"), 800)
        return bool(r and r[0])

    def alternar_silencio(self):
        if self.cookie_avisos is not None:
            B.chamar(B.msg(NT, NT_C, NT_I, "UnInhibit", _u32(self.cookie_avisos)))
            self.cookie_avisos = None
        else:
            r = B.bloquear(B.msg(NT, NT_C, NT_I, "Inhibit", "cyberkde-ilha", t("Não perturbe pedido na ilha"), {}))
            if not r:
                raise OSError(t("o servidor de notificações não respondeu"))
            self.cookie_avisos = int(r[0])
        self.mudou.emit()

    def soltar_tudo(self):
        self._soltar.stop()
        if self.cookie_tela is not None:
            B.bloquear(B.msg(SS, SS_C, SS_I, "UnInhibit", _u32(self.cookie_tela)), 500)
        if self.cookie_avisos is not None:
            B.bloquear(B.msg(NT, NT_C, NT_I, "UnInhibit", _u32(self.cookie_avisos)), 500)
        self.cookie_tela = self.cookie_avisos = None
