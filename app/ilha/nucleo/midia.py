"""O que está tocando, pelo MPRIS: uma conexão que fica, com sinais (lição P0-1 do Halo). ListNames uma
vez, NameOwnerChanged para players entrando e saindo; GetAll uma vez por player e PropertiesChanged
para o resto. O estado mora em memória; só a posição, que não tem sinal, é extrapolada."""

import time

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot
from PyQt6.QtDBus import QDBusMessage

from . import bus as B

P = "org.mpris.MediaPlayer2.Player"
R = "org.mpris.MediaPlayer2"
PROP = "org.freedesktop.DBus.Properties"
CAM = "/org/mpris/MediaPlayer2"
PREFIXO = "org.mpris.MediaPlayer2."
ORDEM_LOOP = ["None", "Playlist", "Track"]


def _texto_lista(v):
    return ", ".join(str(x) for x in v) if isinstance(v, (list, tuple)) else str(v or "")


class Midia(QObject):
    mudou = pyqtSignal()
    faixaNova = pyqtSignal(str, str, str)   # título, artista, capa

    def __init__(self, parent=None):
        super().__init__(parent)
        self._players = {}       # nome -> estado
        self._donos = {}         # dono único -> nome
        self._faixa_vista = ""
        b = B.sessao()
        if not b.isConnected():
            return
        b.connect("", CAM, PROP, "PropertiesChanged", self._propriedades)
        b.connect("", CAM, P, "Seeked", self._buscou)
        b.connect("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameOwnerChanged", self._dono)
        B.chamar(B.msg("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames"), self._nomes)

    def _nomes(self, args):
        for n in args[0] if args else []:
            if str(n).startswith(PREFIXO):
                self._adicionar(str(n))

    def _adicionar(self, nome):
        st = self._players.setdefault(nome, {"nome": nome, "status": "Stopped", "meta": {}, "pos": 0.0, "em": time.monotonic(),
                                             "identidade": nome[len(PREFIXO):], "loop": "None", "shuffle": False, "ordem": time.monotonic()})
        B.chamar(B.msg("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", nome),
                 lambda a, n=nome: self._donos.__setitem__(str(a[0]), n))
        B.chamar(B.msg(nome, CAM, PROP, "GetAll", P), lambda a, n=nome: self._aplicar(n, a[0] if a else {}))
        B.chamar(B.msg(nome, CAM, PROP, "GetAll", R),
                 lambda a, n=nome: self._raiz(n, a[0] if a else {}))
        return st

    def _raiz(self, nome, d):
        st = self._players.get(nome)
        if st and isinstance(d, dict):
            st["identidade"] = str(d.get("Identity") or st["identidade"])
            st["desktop"] = str(d.get("DesktopEntry") or "")
            self.mudou.emit()

    def _aplicar(self, nome, d):
        st = self._players.get(nome)
        if st is None or not isinstance(d, dict):
            return
        if "PlaybackStatus" in d:
            self._acertar_pos(st)
            st["status"] = str(d["PlaybackStatus"])
            if st["status"] == "Playing":
                st["ordem"] = time.monotonic()
        if "Metadata" in d and isinstance(d["Metadata"], dict):
            st["meta"] = d["Metadata"]
            if "Position" not in d:
                st["pos"], st["em"] = 0.0, time.monotonic()
        if "Position" in d:
            st["pos"], st["em"] = float(d["Position"]) / 1e6, time.monotonic()
        if "LoopStatus" in d:
            st["loop"] = str(d["LoopStatus"])
        if "Shuffle" in d:
            st["shuffle"] = bool(d["Shuffle"])
        self._conferir_faixa()
        self.mudou.emit()

    @staticmethod
    def _acertar_pos(st):
        if st["status"] == "Playing":
            agora = time.monotonic()
            st["pos"] += agora - st["em"]
            st["em"] = agora

    def _conferir_faixa(self):
        a = self.atual()
        if not a or not a["title"]:
            return
        chave = f"{a['title']}\0{a['artist']}"
        if chave != self._faixa_vista:
            primeira = not self._faixa_vista
            self._faixa_vista = chave
            if not primeira and a["status"] == "playing":
                self.faixaNova.emit(a["title"], a["artist"], a["artUrl"])

    @pyqtSlot(QDBusMessage)
    def _propriedades(self, m):
        a = m.arguments()
        nome = self._donos.get(m.service())
        if nome and len(a) >= 2 and a[0] == P:
            self._aplicar(nome, a[1])

    @pyqtSlot(QDBusMessage)
    def _buscou(self, m):
        st = self._players.get(self._donos.get(m.service()))
        a = m.arguments()
        if st and a:
            st["pos"], st["em"] = float(a[0]) / 1e6, time.monotonic()
            self.mudou.emit()

    @pyqtSlot(QDBusMessage)
    def _dono(self, m):
        a = m.arguments()
        if len(a) != 3 or not str(a[0]).startswith(PREFIXO):
            return
        nome, velho, novo = (str(x) for x in a)
        if novo:
            self._adicionar(nome)
        else:
            self._players.pop(nome, None)
            self._donos.pop(velho, None)
            self.mudou.emit()

    def _escolhido(self):
        """O que toca, senão o último que tocou, senão o que tem faixa. Pausa esquecida não ganha de quem toca."""
        vivos = list(self._players.values())
        if not vivos:
            return None
        peso = {"Playing": 2, "Paused": 1}
        return max(vivos, key=lambda s: (peso.get(s["status"], 0), bool(s["meta"].get("xesam:title")), s["ordem"]))

    def atual(self):
        st = self._escolhido()
        if not st:
            return None
        m = st["meta"]
        dur = m.get("mpris:length")
        dur = float(dur) / 1e6 if isinstance(dur, (int, float)) and dur > 0 else None
        pos = st["pos"] + (time.monotonic() - st["em"] if st["status"] == "Playing" else 0)
        if dur:
            pos = min(pos, dur)
        return {"title": str(m.get("xesam:title") or ""), "artist": _texto_lista(m.get("xesam:artist")),
                "album": str(m.get("xesam:album") or ""), "artUrl": str(m.get("mpris:artUrl") or ""),
                "url": str(m.get("xesam:url") or ""), "trackId": str(m.get("mpris:trackid") or ""),
                "status": st["status"].lower(), "player": st["identidade"], "servico": st["nome"],
                "positionSec": pos, "durationSec": dur, "shuffle": st["shuffle"], "loop": st["loop"]}

    # ---- ações
    def _no_player(self, metodo, *args):
        st = self._escolhido()
        if not st:
            raise OSError("nenhum player aberto")
        B.chamar(B.msg(st["nome"], CAM, P, metodo, *args))

    def alternar(self):
        self._no_player("PlayPause")

    def proxima(self):
        self._no_player("Next")

    def anterior(self):
        self._no_player("Previous")

    def buscar(self, segundos):
        a = self.atual()
        if not a or not a["trackId"]:
            raise OSError("nada para buscar")
        from PyQt6.QtDBus import QDBusObjectPath
        self._no_player("SetPosition", QDBusObjectPath(a["trackId"]), int(float(segundos) * 1e6))

    def _definir(self, prop, valor):
        from PyQt6.QtDBus import QDBusVariant
        st = self._escolhido()
        if not st:
            raise OSError("nenhum player aberto")
        B.chamar(B.msg(st["nome"], CAM, PROP, "Set", P, prop, QDBusVariant(valor)))

    def embaralhar(self):
        st = self._escolhido()
        self._definir("Shuffle", not (st and st["shuffle"]))

    def repetir(self):
        st = self._escolhido()
        atual = st["loop"] if st else "None"
        self._definir("LoopStatus", ORDEM_LOOP[(ORDEM_LOOP.index(atual) + 1) % 3] if atual in ORDEM_LOOP else "None")

    def abrir(self):
        st = self._escolhido()
        if not st:
            raise OSError("nenhum player aberto")
        B.chamar(B.msg(st["nome"], CAM, R, "Raise"))
