"""O objeto `ilha` exposto ao QML (spec seção 4). Formas de dados com os nomes de src/shared/island.ts do
Halo e ids de ação do catálogo dele, para o IslandApp.tsx servir de mapa direto."""

import json
import os
from pathlib import Path
import re
import shutil
import sys
import time

from PyQt6.QtCore import QFileSystemWatcher, QMetaType, QObject, QProcess, QRect, QThreadPool, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtDBus import QDBusArgument
from PyQt6.QtGui import QGuiApplication, QRegion

from . import apps as AP
from . import audio as AU
from . import bus as B
from . import celular as CL
from . import config as C
from . import dados as D
from . import discos as DS
from . import extras as EX
from . import gaveta as GV
from . import i18n as I
from . import letras as LE
from . import rede as RD
from . import sistema as SI
from . import temporizador as TP
from .api import Api, caminho as caminho_api
from .audio import Volume
from .avisos import Avisos
from .barramento import Servico, halo_pelo_socket
from .clipboard import Clipboard
from .espectro import Espectro
from .inibir import Inibir
from .kwin import KWin
from .midia import Midia
from .tarefas import cmd, rodar
from .tema import Tema
from .teclado import Teclado

t = I.t
ler, modulo, acao = I.ler, I.modulo, I.acao
PULSO_ABERTA, PULSO_FECHADA = 2000, 6000
_ASSINCRONA = object()
CAROS = {"sistema": 4.0, "rede": 8.0, "bluetooth": 20.0, "discos": 6.0, "celular": 30.0, "audio": 20.0, "kde": 6.0}
AUDIO_FECHADA = 60.0   # recolhida, o `pactl subscribe` invalida o áudio a cada mudança; a leitura periódica é só uma rede de segurança


def _nome_da_mesa(ident):
    """`current` é um UUID no Plasma 6; o nome está em `desktops` (a(uss)), que o PyQt não desempacota: busctl."""
    s = cmd("busctl", "--user", "--json=short", "get-property", "org.kde.KWin", "/VirtualDesktopManager",
            "org.kde.KWin.VirtualDesktopManager", "desktops", timeout=2)
    try:
        return next((str(m[2]) for m in json.loads(s or "{}").get("data", []) if m[1] == ident), None)
    except (ValueError, IndexError, TypeError):
        return None


def mmss(s):
    return "—" if s is None else f"{int(s // 60)}:{int(s % 60):02d}"


class Ilha(QObject):
    instantaneoMudou = pyqtSignal()
    evento = pyqtSignal("QVariantMap", arguments=["dado"])
    espectro = pyqtSignal("QVariantList", arguments=["niveis"])
    acaoTerminou = pyqtSignal(str, bool, str, arguments=["id", "ok", "texto"])
    configMudou = pyqtSignal()
    paletaMudou = pyqtSignal()
    gavetaMudou = pyqtSignal()
    focoMudou = pyqtSignal()
    ocultaMudou = pyqtSignal()
    telasMudou = pyqtSignal()
    janelasMudou = pyqtSignal()
    resultadoLancador = pyqtSignal("QVariantList", arguments=["itens"])
    voo = pyqtSignal("QVariantMap", arguments=["dado"])
    demonstrar = pyqtSignal(str, arguments=["tipo"])
    atalhoAcionado = pyqtSignal(str, arguments=["acao"])   # "abrir" | "nota" (o foco o back-end resolve)

    def __init__(self, parent=None):
        super().__init__(parent)
        I.iniciar()
        self._cfg = C.ler()
        self._dados = D.ler()
        self._tema = Tema(self)
        self._tema.mudou.connect(self.paletaMudou.emit)
        self._aberta = False
        self._saindo = False
        self._janelas = []
        self._janelas_em = -1e9
        self._snap = {}
        self._memo = {}           # módulo → (quando, leituras)
        self._lendo = False
        self._pool = QThreadPool(self)
        self._pool.setMaxThreadCount(1)
        self._tela_cheia = []
        self._halo_ativo = False
        self._barras = {}
        self._barra_cores = {}
        self._barra_lida = False
        # trocar de corporação troca as cores da barra, mas o tema do Plasma é regravado DEPOIS da paleta (o CLI
        # gera o SVG em seguida): vigia a pasta do tema e o plasmarc, e ainda relê umas vezes depois da troca
        self.paletaMudou.connect(self._barra_depois_da_paleta)
        self._obs_barra = QFileSystemWatcher(self)
        self._atraso_barra = QTimer(self, singleShot=True, interval=400)
        self._atraso_barra.timeout.connect(self._reler_barra)
        self._obs_barra.directoryChanged.connect(self._atraso_barra.start)
        self._obs_barra.fileChanged.connect(self._atraso_barra.start)
        self._releituras = []
        self._vigiar_barra()
        self._halo_kwin = False
        self._letra = None
        self._letra_chave = None
        self._capturas_desde = time.time()
        self._discos_vistos = None
        self._mesa = (None, None)   # (id, nome) da área de trabalho: o nome só se pede de novo se ela mudar ou com a ilha aberta
        self._selo_baixados = None
        self._selo_capturas = None
        self._chave_oculta = None

        self.midia = Midia(self)
        self.avisos = Avisos(self)
        self.volume = Volume(self)
        self.clipboard = Clipboard(self)
        self.inibir = Inibir(self)
        self.teclado = Teclado(self)
        self.tempo = TP.Temporizador(self)
        self.api = Api(self)
        self.espectro_ = Espectro(self)
        self.kwin = KWin(self)
        self.servico = Servico(self)

        self.midia.mudou.connect(self._midia_mudou)
        self.midia.faixaNova.connect(self._faixa_nova)
        self.avisos.chegou.connect(self._aviso)
        self.avisos.mudou.connect(self._pedir)
        self.volume.mudou.connect(self._hud_volume)
        self.volume.tocou.connect(lambda: self._invalidar("audio"))
        self.clipboard.mudou.connect(self._pedir)
        self.inibir.mudou.connect(self._kde_mudou)
        self.teclado.mudou.connect(self._hud_tecla)
        self.tempo.mudou.connect(self._pedir)
        self.tempo.acabou.connect(self._timer_acabou)
        self.api.mudou.connect(self._pedir)
        self.api.anuncio.connect(self.anunciar)
        self.espectro_.niveis.connect(self.espectro.emit)
        self.kwin.telaCheia.connect(self._telas_cheias)
        self.kwin.haloVisto.connect(self._halo_visto)
        self.kwin.atalho.connect(self._atalho)

        self._rel = QTimer(self, interval=PULSO_FECHADA)
        self._rel.timeout.connect(self._pulso)
        self._rel_halo = QTimer(self, interval=10000)
        self._rel_halo.timeout.connect(self._olhar_halo)
        self._rel_capturas = QTimer(self, interval=5000)
        self._rel_capturas.timeout.connect(self._olhar_capturas)
        self._obs = QFileSystemWatcher(self)
        self._atraso = QTimer(self, singleShot=True, interval=200)
        self._atraso.timeout.connect(self._cfg_externa)
        self._obs.directoryChanged.connect(self._atraso.start)
        self._obs.fileChanged.connect(self._atraso.start)
        C.dir_config().mkdir(parents=True, exist_ok=True)
        self._obs.addPath(str(C.dir_config()))
        self._adiar = QTimer(self, singleShot=True, interval=30)   # agrupa rajadas de mudança num só instantâneo
        self._adiar.timeout.connect(self._montar)
        app = QGuiApplication.instance()
        if app:
            app.screenAdded.connect(self.telasMudou.emit)
            app.screenRemoved.connect(self.telasMudou.emit)

    def iniciar(self):
        self._aplicar_cfg()
        self._olhar_halo()
        self._rel.start()
        self._rel_halo.start()
        self._rel_capturas.start()
        self.kwin.iniciar_vigia(self._teclas())
        self._pulso()

    def encerrar(self):
        for r in (self._rel, self._rel_halo, self._rel_capturas):
            r.stop()
        if self._saindo:          # Sair = a usuária desligou: nada do que a ilha pôs no KDE fica para trás
            self.kwin.esquecer_atalhos()
        self.kwin.soltar_guardadas()   # janela alguma fica escondida depois de a ilha sair
        self.kwin.parar_vigia()
        self.inibir.soltar_tudo()
        self.avisos.ligar(False)
        self.volume.ligar(False)
        self.espectro_.ligar(False)
        self.teclado.ligar(False)
        self.api.ligar(False)
        self.clipboard.ligar(False)
        self._pool.waitForDone(2000)
        self.servico.liberar()

    @pyqtSlot()
    def sair(self):
        self._saindo = True
        QTimer.singleShot(0, QGuiApplication.quit)

    # ---- config
    def _aplicar_cfg(self):
        c = self._cfg
        self.avisos.ligar(c["avisos"] and self._mod("avisos"))
        self.volume.ligar(True)
        self.clipboard.ligar(c["clipboard"] and self._mod("clipboard"))
        self.espectro_.ligar(c["espectro"])
        self.teclado.ligar(self._mod("teclado"))
        self.api.ligar(c["api"] and self._mod("api"))
        self._reavaliar()

    def _teclas(self, cfg=None):
        c = cfg or self._cfg
        return {"guardar": "Meta+Alt+J" if c["atalhoJanela"] else "", "abrir": c["atalhoAbrir"], "foco": c["atalhoFoco"], "nota": c["atalhoNota"]}

    def _atalho(self, qual):
        if qual == "guardar":
            self.agir("janela-guardar", "")
        elif qual == "foco":
            self.agir("timer-parar") if self.tempo.vivo else self.agir("timer-iniciar", "25|" + t("Foco"))
        else:
            self.atalhoAcionado.emit(qual)

    def _mod(self, m):
        return not self._cfg["modulos"] or m in self._cfg["modulos"]

    def _cfg_externa(self):
        n = C.ler()
        if n != self._cfg:
            antes, depois = self._teclas(), self._teclas(n)
            self._cfg = n
            self._aplicar_cfg()
            self.configMudou.emit()
            self.telasMudou.emit()
            if antes != depois and self.kwin.vigia:
                self.kwin.esquecer_atalhos([i for i in antes if antes[i] and not depois[i]])
                self.kwin.parar_vigia()
                self.kwin.iniciar_vigia(depois)

    @pyqtSlot(str, "QVariant", result=str)
    def definir(self, chave, valor):
        e = C.definir(chave, valor)
        if not e:
            self._cfg_externa()
        return e

    @pyqtProperty("QVariantMap", notify=configMudou)
    def config(self):
        c = dict(self._cfg)
        if c["cantos"] < 0:
            del c["cantos"]   # ausente = o raio do tema (Gota.qml)
        return c

    @pyqtProperty("QVariantMap", notify=paletaMudou)
    def paleta(self):
        return dict(self._tema.paleta)

    @pyqtProperty(str, notify=paletaMudou)
    def movimento(self):
        return self._tema.movimento

    @pyqtProperty(bool, notify=paletaMudou)
    def reduzir(self):
        return self._tema.movimento != "completo"

    @pyqtProperty(str, constant=True)
    def idioma(self):
        return I.idioma

    @pyqtProperty("QVariantMap", constant=True)
    def textos(self):
        return I.textos()

    @pyqtSlot(str, result=str)
    def t(self, chave):
        return t(chave)

    # ---- telas e janela
    @pyqtProperty("QVariantList", notify=telasMudou)
    def telas(self):
        app = QGuiApplication.instance()
        todas = app.screens() if app else []
        princ = app.primaryScreen() if app else None
        esc = self._cfg["tela"]
        if esc == "todas":
            sel = todas
        else:
            sel = [s for s in todas if s.name() == esc] or ([princ] if princ else [])
        return [{"nome": s.name(), "principal": s is princ or s == princ, "x": s.geometry().x(), "y": s.geometry().y(),
                 "largura": s.geometry().width(), "altura": s.geometry().height()} for s in sel]

    # ---- a barra de cima do Plasma: altura por tela e as cores do tema (a fusão e o assento "abaixo").
    # Painel flutuante ou que se esconde não conta: não há borda contínua para fundir.
    @pyqtProperty(int, notify=telasMudou)
    def alturaBarra(self):
        if not self._barra_lida:
            self._barra_lida = True
            self._medir_barra()
        return max(self._barras.values(), default=0)

    @pyqtSlot(str, result="QVariantMap")
    def barraEm(self, nome):
        app = QGuiApplication.instance()
        s = next((t for t in app.screens() if t.name() == nome), None) if app else None
        h = self._barras.get((s.geometry().x(), s.geometry().y()), 0) if s else 0
        return dict(self._barra_cores, altura=h)

    def _ler_cores_barra(self):
        """Fundo e filete de widgets/panel-background do tema de área de trabalho em uso."""
        dados = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        conf = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "plasmarc"
        try:
            m = re.search(r"^name=(.+)$", conf.read_text(encoding="utf-8", errors="replace"), re.M)
            bruto = (dados / "plasma/desktoptheme" / (m.group(1).strip() if m else "CyberKDE") / "widgets/panel-background.svg").read_bytes()
            g = re.search(r'id="(?:north-)?bottom">(.*?)</g>', bruto.decode("utf-8", "replace"), re.S)
            cores = [c for c, a in re.findall(r'fill="(#[0-9A-Fa-f]{6})"(?: fill-opacity="([\d.]+)")?', g.group(1)) if a != "0"]
            return {"fundo": cores[0], "cor": cores[-1]}
        except (OSError, AttributeError, IndexError):
            return {}

    def _pastas_barra(self):
        dados = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        conf = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        try:
            m = re.search(r"^name=(.+)$", (conf / "plasmarc").read_text(encoding="utf-8", errors="replace"), re.M)
        except OSError:
            m = None
        tema = dados / "plasma/desktoptheme" / (m.group(1).strip() if m else "CyberKDE")
        # pastas, não arquivos: a escrita atômica troca o inode e o observador perderia o arquivo
        return [str(x) for x in (conf, tema, tema / "widgets") if x.is_dir()]

    def _vigiar_barra(self):
        atuais = set(self._obs_barra.directories())
        alvos = self._pastas_barra()
        velhas = [d for d in atuais if d not in alvos]
        if velhas:
            self._obs_barra.removePaths(velhas)
        novas = [d for d in alvos if d not in atuais]
        if novas:
            self._obs_barra.addPaths(novas)

    def _reler_barra(self):
        self._vigiar_barra()            # o plasmarc pode ter trocado de tema
        if not self._barra_lida:
            return
        cores = self._ler_cores_barra()
        if cores != self._barra_cores:
            self._barra_cores = cores
            self.telasMudou.emit()

    def _barra_depois_da_paleta(self):
        self._medir_barra()
        for t in self._releituras:
            t.stop()
        self._releituras = []
        for ms in (1500, 4000, 9000):     # o tema do Plasma termina de ser gerado alguns segundos depois
            t = QTimer(self, singleShot=True, interval=ms)
            t.timeout.connect(self._reler_barra)
            t.start()
            self._releituras.append(t)

    def _medir_barra(self):
        js = ("var o='';panels().forEach(function(p){if(p.location=='top'&&!p.floating&&p.hiding=='none'){"
              "var g=screenGeometry(p.screen);o+=g.x+','+g.y+','+p.height+';'}});print(o)")
        self._barra_cores = self._ler_cores_barra()
        p = QProcess(self)

        def fim(*_a):
            s = bytes(p.readAllStandardOutput()).decode("utf-8", "replace")
            p.deleteLater()
            n = {(int(a), int(b)): int(c) for a, b, c in re.findall(r"(-?\d+),(-?\d+),(\d+);", s)}
            self._barras = n
            self.telasMudou.emit()
        p.finished.connect(fim)
        p.start("qdbus6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js])

    @pyqtSlot(str, result=QObject)
    def telaQt(self, nome):
        """O QScreen da saída: LS.Window.screen só aceita o objeto real."""
        app = QGuiApplication.instance()
        return next((s for s in app.screens() if s.name() == nome), app.primaryScreen())

    @pyqtProperty("QVariantList", notify=telasMudou)
    def telasDisponiveis(self):
        app = QGuiApplication.instance()
        return [s.name() for s in app.screens()] if app else []

    @pyqtSlot(QObject, "QVariantList")
    def definirRegiao(self, janela, rects):
        r = QRegion()
        for q in rects:
            r = r.united(QRect(int(q["x"]), int(q["y"]), int(q["width"]), int(q["height"])))
        janela.setMask(r)

    @pyqtSlot(bool)
    def aberta(self, sim):
        if bool(sim) != self._aberta:
            self._aberta = bool(sim)
            self._rel.setInterval(PULSO_ABERTA if sim else PULSO_FECHADA)
            if sim:
                self._pulso()

    # ---- ocultar (tela cheia e Halo)
    def _telas_cheias(self, lista):
        if lista != self._tela_cheia:
            self._tela_cheia = lista
            self.ocultaMudou.emit()

    def _halo_visto(self, sim):
        self._halo_kwin = sim
        self._reavaliar()

    def _olhar_halo(self):
        self._reavaliar()

    def _reavaliar(self):
        h = self._halo_kwin or halo_pelo_socket()
        if h != self._halo_ativo:
            self._halo_ativo = h
            if h:
                print("aviso: a ilha do Halo está ativa; a do tema fica escondida (nada foi fechado)", file=sys.stderr)
        chave = (h, self._cfg["conviverComHalo"], self._cfg["esconderTelaCheia"])
        if chave != self._chave_oculta:   # este caminho roda a cada 10 s: sem mudança, nenhum binding precisa acordar
            self._chave_oculta = chave
            self.ocultaMudou.emit()

    @pyqtSlot(str, result=bool)
    def ocultaNa(self, tela):
        """Por tela: tela cheia numa tela não esconde a ilha da outra."""
        return bool(self.motivoOculta) or (self._cfg["esconderTelaCheia"] and tela in self._tela_cheia)

    @pyqtProperty(str, notify=ocultaMudou)
    def motivoOculta(self):
        return "halo" if self._halo_ativo and not self._cfg["conviverComHalo"] else ""

    @pyqtProperty(bool, notify=ocultaMudou)
    def oculta(self):
        return bool(self.motivoOculta)

    @pyqtProperty("QVariantList", notify=ocultaMudou)
    def telasEmTelaCheia(self):
        return list(self._tela_cheia) if self._cfg["esconderTelaCheia"] else []

    @pyqtProperty("QVariantMap", notify=ocultaMudou)
    def halo(self):
        return {"ativo": self._halo_ativo}

    def estado_cli(self):
        return {"rodando": True, "pid": os.getpid(), "telas": [x["nome"] for x in self.telas], "oculta": self.oculta,
                "motivoOculta": self.motivoOculta, "halo": self._halo_ativo, "telaCheia": self._tela_cheia,
                "api": caminho_api() if self.api.ouvindo else "", "vigiaKwin": self.kwin.vigia,
                "avisosOuvindo": self.avisos.ouvindo, "espectroOuvindo": self.espectro_.ouvindo,
                # a paleta EM USO na instância aberta (a que ela leu por último de cor/corp/paleta)
                "paleta": dict(self._tema.paleta)}

    # ---- eventos
    @pyqtSlot("QVariantMap")
    def anunciar(self, ev):
        if not self._halo_ativo or self._cfg["conviverComHalo"]:
            self.evento.emit(dict(ev))

    def _midia_mudou(self):
        a = self.midia.atual()
        self.espectro_.tocando(bool(a and a["status"] == "playing"))
        self._pedir()

    def _faixa_nova(self, titulo, artista, capa):
        self.anunciar({"icon": "MusicNote", "text": titulo, "detail": artista, "level": "ok", "art": capa})
        if self._cfg["letras"]:
            self._buscar_letra()

    def _aviso(self, a):
        self.anunciar({"icon": "WarningCircle" if a["urgent"] else "BellRinging", "text": a["title"] or a["body"], "detail": a["app"],
                       "level": "alerta" if a["urgent"] else "ok", "kind": "aviso", "ttlMs": 4500})

    def _hud_volume(self, nivel, mudo):
        self._invalidar("audio")
        if self._cfg["hud"]:
            self.anunciar({"icon": "SpeakerSlash" if mudo else "SpeakerHigh", "text": t("Volume"), "detail": t("mudo") if mudo else f"{nivel}%",
                           "level": "ok", "kind": "hud", "ratio": 0 if mudo else min(1.0, nivel / 100), "key": "volume", "ttlMs": 1500})

    def _hud_tecla(self, qual, aceso):
        nome = "Caps Lock" if qual == "caps" else "Num Lock"
        self.anunciar({"icon": "Keyboard", "text": nome, "detail": t("ligado") if aceso else t("desligado"), "level": "ok",
                       "kind": "hud", "key": qual, "ttlMs": 1500})

    def _timer_acabou(self, rotulo, minutos):
        self._dados["foco"] = TP.registrar(self._dados["foco"], minutos)
        D.gravar(self._dados)
        self.focoMudou.emit()
        self.anunciar({"icon": "Timer", "text": t("Tempo!"), "detail": rotulo, "level": "ok", "kind": "aviso", "ttlMs": 8000})
        self._notificar(t("Tempo!"), rotulo or t("O temporizador acabou"))

    def _notificar(self, titulo, corpo):
        B.chamar(B.msg("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify",
                       "CyberKDE Ilha", QDBusArgument(0, QMetaType.Type.UInt.value), "cyberkde-painel", titulo, corpo,
                       QDBusArgument([], QMetaType.Type.QStringList.value), {}, -1))

    def _olhar_capturas(self):
        if not self._mod("capturas"):
            return
        selo = EX.selo_capturas()
        if selo is None or selo == self._selo_capturas:
            return
        self._selo_capturas = selo
        novas = EX.capturas_desde(self._capturas_desde)
        if novas:
            self._capturas_desde = time.time()
            self._dados["gaveta"], _ = GV.guardar(self._dados["gaveta"], novas[:5])
            D.gravar(self._dados)
            self.gavetaMudou.emit()
            self.anunciar({"icon": "Camera", "text": t("Captura guardada"), "detail": os.path.basename(novas[0]), "level": "ok"})

    # ---- instantâneo
    @pyqtProperty("QVariantMap", notify=instantaneoMudou)
    def instantaneo(self):
        return self._snap

    @pyqtProperty("QVariantList", notify=gavetaMudou)
    def gaveta(self):
        return GV.itens(self._dados["gaveta"])

    @pyqtProperty("QVariantMap", notify=focoMudou)
    def foco(self):
        return TP.resumo(self._dados["foco"])

    @pyqtProperty("QVariantList", notify=janelasMudou)
    def janelas(self):
        return list(self._janelas)

    @pyqtProperty("QVariantList", notify=janelasMudou)
    def janelasGuardadas(self):
        return list(self.kwin.guardadas)

    def _invalidar(self, m):
        """Vence a memória sem apagar o valor: o módulo não pode sair vazio até a leitura nova chegar."""
        if m in self._memo:
            self._memo[m] = (-1e9, self._memo[m][1])

    def _pedir(self):
        if not self._adiar.isActive():
            self._adiar.start()

    def _kde_mudou(self):
        self._invalidar("kde")
        self._pulso()

    def _pulso(self):
        if self._lendo:
            return
        agora = time.monotonic()
        quer = [m for m, ttl in CAROS.items() if self._mod(m) and (m in ("audio", "kde") or self._aberta)
                and agora - self._memo.get(m, (-1e9,))[0] >= (AUDIO_FECHADA if m == "audio" and not self._aberta else ttl)]
        self._lendo = True
        rodar(self._ler_caros, quer, list(self._cfg["relogios"]), self._cfg["clima"], pronto=self._lidos, pool=self._pool)
        if self._aberta and self._mod("janelas") and agora - self._janelas_em >= 4 and self.kwin.vigia:
            self._janelas_em = agora
            self.kwin.listar(self._janelas_lidas)

    def _janelas_lidas(self, v):
        if isinstance(v, list) and v != self._janelas:
            self._janelas = v
            self.janelasMudou.emit()
            self._pedir()

    def _ler_caros(self, quais, fusos, clima):
        """Numa thread: comandos e /proc. Módulo que falha diz que falhou; não derruba os outros."""
        res = {}
        for m in quais:
            try:
                res[m] = getattr(self, f"_fonte_{m}")()
            except Exception as e:  # noqa: BLE001
                res[m] = e
        try:
            if not self._mod("downloads"):
                res["_baixando"], res["_baixados"] = [], (0, "")
            else:
                # recolhida e sem parciais, nada muda enquanto a pasta não mudar (com parcial, o tamanho anda)
                selo = EX.selo_downloads()
                if self._aberta or getattr(self, "_baixando", None) or selo is None or selo != self._selo_baixados:
                    self._selo_baixados = selo
                    res["_baixando"] = EX.baixando()
                    res["_baixados"] = EX.baixados()
            res["_relogio"] = SI.relogios(fusos) + SI.clima(clima)
        except Exception as e:  # noqa: BLE001
            print(f"aviso: {e}", file=sys.stderr)
        return res

    def _fonte_sistema(self):
        return SI.leituras()

    def _fonte_rede(self):
        return RD.conexao() + RD.wifi() + RD.ip() + RD.vazao()

    def _fonte_bluetooth(self):
        return RD.bluetooth() + RD.bluetooth_bateria()

    def _fonte_discos(self):
        return DS.removiveis()

    def _fonte_celular(self):
        return CL.dispositivos()

    def _fonte_audio(self):
        v = AU.ler_volume()
        return {"volume": v, "padrao": AU.saida_padrao(), "saidas": AU.saidas(), "mic": AU.mic_mudo(), "gravando": AU.quem_grava()}

    def _fonte_kde(self):
        r = B.bloquear(B.msg("org.kde.KWin", "/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "GetAll", "org.kde.KWin.VirtualDesktopManager"), 800)
        d = r[0] if r and isinstance(r[0], dict) else {}
        ident = d.get("current")
        if self._aberta or ident != self._mesa[0] or self._mesa[1] is None:
            self._mesa = (ident, _nome_da_mesa(ident))
        return {"desktops": d.get("count"), "atual": self._mesa[1], "silencio": self.inibir.em_silencio()}

    def _lidos(self, r):
        self._lendo = False
        if not isinstance(r, dict):
            return
        agora = time.monotonic()
        self._baixando = r.pop("_baixando", getattr(self, "_baixando", []))
        self._baixados = r.pop("_baixados", getattr(self, "_baixados", (0, "")))
        self._relogio = r.pop("_relogio", getattr(self, "_relogio", []))
        for m, v in r.items():
            self._memo[m] = (agora, v)
        if "discos" in r and not isinstance(r["discos"], Exception):
            self._conferir_discos(r["discos"])
        self._montar()

    def _conferir_discos(self, lista):
        ids = {d["device"]: d["name"] for d in lista}
        if self._discos_vistos is not None:
            for dev, nome in ids.items():
                if dev not in self._discos_vistos:
                    self.anunciar({"icon": "HardDrive", "text": nome, "detail": t("conectado"), "level": "ok"})
        self._discos_vistos = ids

    def _modulo_memo(self, m, nome, icone, montar, acoes=()):
        v = self._memo.get(m, (0, None))[1]
        if isinstance(v, Exception):
            return modulo(m, nome, icone, [], acoes, False, str(v))
        if v is None:
            return modulo(m, nome, icone, [], acoes)
        return modulo(m, nome, icone, montar(v), acoes)

    def _mod_midia(self):
        a = self.midia.atual()
        ac = [acao("midia-anterior", t("Anterior"), "SkipBack"), acao("midia-alternar", t("Tocar ou pausar"), "Play"), acao("midia-proxima", t("Próxima"), "SkipForward")]
        if not a or (a["status"] == "stopped" and not a["title"]):
            det = t("{player} parado, sem faixa", player=a["player"]) if a else t("nenhum player aberto")
            return modulo("midia", t("Mídia"), "MusicNotes", [ler("midia-tocando", t("Tocando"), t("nada"), det),
                          ler("midia-estado", t("Estado"), t("parado")), ler("midia-progresso", t("Progresso"), "—", t("sem faixa")),
                          ler("midia-player", t("Player"), a["player"] if a else t("nenhum"))], ac)
        razao = a["positionSec"] / a["durationSec"] if a["durationSec"] else None
        ac[1]["active"] = a["status"] == "playing"
        modos = (t("embaralhando") if a["shuffle"] else t("em ordem"),
                 {"Track": t("repete a faixa"), "Playlist": t("repete a lista")}.get(a["loop"], t("sem repetir")))
        return modulo("midia", t("Mídia"), "MusicNotes", [
            ler("midia-tocando", t("Tocando"), a["title"] or "—", a["artist"], razao, art=a["artUrl"] or None),
            ler("midia-estado", t("Estado"), t("tocando") if a["status"] == "playing" else t("pausado")),
            ler("midia-progresso", t("Progresso"), mmss(a["positionSec"]), t("de {total}", total=mmss(a["durationSec"])), razao),
            ler("midia-player", t("Player"), a["player"]), ler("midia-modos", t("Embaralhar e repetir"), *modos)], ac)

    def _mod_audio(self):
        def montar(v):
            vol = v["volume"]
            if vol is None:
                raise_ = ler("volume", t("Volume"), "—", t("pactl não respondeu"), None, "alerta")
                return [raise_]
            desc = next((s["descricao"] for s in v["saidas"] if s["nome"] == v["padrao"]), v["padrao"])
            return [ler("volume", t("Volume"), t("mudo") if vol["mudo"] else f"{vol['nivel']}%", "", min(1.0, vol["nivel"] / 100)),
                    ler("saida-audio", t("Saída"), desc), ler("saidas-audio", t("Saídas"), json.dumps(v["saidas"], ensure_ascii=False)),
                    ler("mic-mudo", t("Microfone"), "—" if v["mic"] is None else (t("mudo") if v["mic"] else t("aberto"))),
                    ler("mic-em-uso", t("Microfone em uso"), str(len(v["gravando"])), ", ".join(v["gravando"]), None, "alerta" if v["gravando"] else "ok")]
        return self._modulo_memo("audio", t("Áudio"), "SpeakerHigh", montar,
                                 [acao("volume-mudo", t("Mudo"), "SpeakerSlash"), acao("mic-mudo-alternar", t("Microfone"), "Microphone")])

    def _mod_kde(self):
        v = self._memo.get("kde", (0, {}))[1]
        v = v if isinstance(v, dict) else {}
        i = self.inibir
        caf = i.cookie_tela is not None
        dest = t("até {h}", h=time.strftime("%H:%M", time.localtime(i.ate))) if i.ate else ""
        return modulo("kde", t("Área de trabalho"), "Desktop", [
            ler("kde-desktop", t("Área de trabalho"), v.get("atual") or "—", t("de {total}", total=v.get("desktops") or "—")),
            ler("cafeina", t("Cafeína"), t("ligada") if caf else t("desligada"), dest),
            ler("silencio", t("Não perturbe"), t("ligado") if v.get("silencio") else t("desligado"))],
            [acao("cafeina-alternar", t("Cafeína"), "Coffee", caf), acao("silencio-alternar", t("Não perturbe"), "BellSlash", bool(v.get("silencio"))),
             acao("kde-mostrar-desktop", t("Mostrar a área de trabalho"), "Desktop"), acao("kde-captura", t("Capturar a tela"), "Camera"),
             acao("cor-capturar", t("Conta-gotas"), "Eyedropper"), acao("kde-bloquear", t("Bloquear"), "Lock")])

    def _mod_discos(self):
        def montar(v):
            montados = sum(1 for d in v for x in d["volumes"] if x["mountpoint"])
            return [ler("discos-removiveis", t("Removíveis"), str(len(v))), ler("discos-montados", t("Montados"), str(montados)),
                    ler("discos-lista", t("Volumes"), json.dumps(v, ensure_ascii=False))]
        return self._modulo_memo("discos", t("Discos"), "HardDrive", montar)

    def _mod_celular(self):
        def montar(v):
            if not v:
                return [ler("celular-dispositivo", t("Celular"), "—", t("nenhum ao alcance"))]
            d = v[0]
            return [ler("celular-dispositivo", t("Celular"), d["name"]),
                    ler("celular-bateria", t("Bateria"), "—" if d["battery"] is None else f"{d['battery']}%",
                        t("carregando") if d["charging"] else "", None if d["battery"] is None else d["battery"] / 100)]
        return self._modulo_memo("celular", t("Celular"), "DeviceMobile", montar,
                                 [acao("celular-tocar", t("Tocar"), "BellRinging"), acao("celular-ping", t("Ping"), "Broadcast")])

    def _mod_teclado(self):
        f = lambda x: "—" if x is None else (t("ligado") if x else t("desligado"))   # noqa: E731
        return modulo("teclado", t("Teclado"), "Keyboard", [ler("teclado-capslock", "Caps Lock", f(self.teclado.caps)), ler("teclado-numlock", "Num Lock", f(self.teclado.num))])

    def _mod_foco(self):
        r = TP.resumo(self._dados["foco"])
        return modulo("foco", t("Foco"), "Target", [ler("foco-hoje", t("Hoje"), f"{r['hoje']} min"), ler("foco-sequencia", t("Sequência"), t("{n} dias", n=r["sequencia"]))])

    def _montar(self):
        m = []
        if self._mod("midia"):
            m.append(self._mod_midia())
        if self._mod("audio"):
            m.append(self._mod_audio())
        if self._mod("kde"):
            m.append(self._mod_kde())
        if self._mod("sistema"):
            m.append(self._modulo_memo("sistema", t("Sistema"), "Cpu", lambda v: v))
        if self._mod("rede"):
            m.append(self._modulo_memo("rede", t("Rede"), "WifiHigh", lambda v: v, [acao("wifi-alternar", "Wi-Fi", "WifiHigh")]))
        if self._mod("bluetooth"):
            m.append(self._modulo_memo("bluetooth", "Bluetooth", "Bluetooth", lambda v: v, [acao("bluetooth-alternar", "Bluetooth", "Bluetooth")]))
        if self._mod("discos"):
            m.append(self._mod_discos())
        if self._mod("celular"):
            m.append(self._mod_celular())
        if self._mod("teclado"):
            m.append(self._mod_teclado())
        if self._mod("foco"):
            m.append(self._mod_foco())
        if self._mod("relogio"):
            m.append(modulo("relogio", t("Relógio"), "Clock", getattr(self, "_relogio", [])))
        if self._mod("downloads"):
            n, ultimo = getattr(self, "_baixados", (0, ""))
            m.append(modulo("downloads", t("Downloads"), "DownloadSimple", [ler("downloads-recentes", t("Baixados"), str(n), ultimo[:28] or t("pasta vazia"))]))
        if self._mod("janelas"):
            m.append(modulo("janelas", t("Janelas"), "AppWindow", [ler("janelas-abertas", t("Abertas"), str(len(self._janelas))),
                                                                   ler("janelas-guardadas", t("Guardadas"), str(len(self.kwin.guardadas)))]))
        novo = {"modules": m, "timer": self.tempo.vivo, "notices": list(self.avisos.itens), "downloads": getattr(self, "_baixando", []),
                "clips": self.clipboard.publicos(), "note": self._dados["nota"], "lyrics": self._letra, "activities": self.api.lista()}
        if novo != {k: v for k, v in self._snap.items() if k != "at"}:
            novo["at"] = int(time.time() * 1000)
            self._snap = novo
            self.instantaneoMudou.emit()

    def _buscar_letra(self):
        a = self.midia.atual()
        if not self._cfg["letras"] or not a or not a["title"]:
            return
        k = (a["title"], a["artist"])
        if k == self._letra_chave:
            return
        self._letra_chave = k
        self._letra = None

        def pronto(r):
            if k == self._letra_chave and isinstance(r, (list, type(None))):
                self._letra = r
                self._pedir()
        rodar(LE.buscar, a["title"], a["artist"], a["durationSec"], pronto=pronto)

    # ---- ações (ids do catálogo do Halo)
    def _gaveta_gravar(self):
        D.gravar(self._dados)
        self.gavetaMudou.emit()

    @pyqtSlot("QVariantList", str, result=int)
    def soltar(self, uris, texto):
        antes = len(self._dados["gaveta"])
        n = 0
        if uris:
            self._dados["gaveta"], n = GV.guardar(self._dados["gaveta"], [str(u) for u in uris])
        elif texto:
            self._dados["gaveta"], n = GV.guardar_texto(self._dados["gaveta"], texto)
        if n:
            self._gaveta_gravar()
            self.anunciar({"icon": "Tray", "text": t("Guardado na gaveta"), "detail": t("{n} itens", n=len(self._dados["gaveta"])), "level": "ok"})
        return len(self._dados["gaveta"]) - antes

    @pyqtSlot("QVariantList", result=str)
    def urisDaGaveta(self, lista):
        return "\r\n".join(QUrl.fromLocalFile(str(c)).toString() for c in lista if not GV.eh_url(str(c))) + "\r\n"

    @pyqtSlot(str)
    def buscarApps(self, texto):
        self.resultadoLancador.emit(AP.buscar(texto))

    @pyqtSlot(str)
    @pyqtSlot(str, str)
    def agir(self, ident, arg=""):
        fn = self._acoes().get(ident)
        if fn is None:
            self.acaoTerminou.emit(ident, False, t("ação desconhecida: {id}", id=ident))
            return
        try:
            r = fn(arg)
            if r is not _ASSINCRONA:   # as assíncronas avisam ao terminar de verdade
                self.acaoTerminou.emit(ident, True, r if isinstance(r, str) else "")
        except (OSError, ValueError, TypeError) as e:
            self.acaoTerminou.emit(ident, False, str(e))
        self._invalidar("audio")
        self._pedir()

    def _em_thread(self, ident, fn, *args, depois=None):
        def pronto(r):
            if isinstance(r, Exception):
                self.acaoTerminou.emit(ident, False, str(r))
                return
            texto = depois(r) if depois else r
            self.acaoTerminou.emit(ident, True, texto if isinstance(texto, str) else "")
        rodar(fn, *args, pronto=pronto)
        return _ASSINCRONA

    def _copiar_texto(self, s):
        B.chamar(B.msg("org.kde.klipper", "/klipper", "org.kde.klipper.klipper", "setClipboardContents", s))
        return s

    def _pegou_cor(self, cor):
        self._copiar_texto(cor)
        self.anunciar({"icon": "Eyedropper", "text": cor, "detail": t("copiada"), "level": "ok", "color": cor, "ttlMs": 4500})
        return cor

    def _leu_texto(self, s):
        self._copiar_texto(s)
        self.anunciar({"icon": "TextT", "text": t("Texto copiado"), "detail": s[:80], "level": "ok"})
        return s

    def _nota(self, s):
        self._dados["nota"] = s[:D.LIMITE_NOTA]
        D.gravar(self._dados)
        self._pedir()

    def _gaveta_mexer(self, nova):
        self._dados["gaveta"] = nova
        self._gaveta_gravar()

    def _foco_limpar(self):
        self._dados["foco"] = []
        D.gravar(self._dados)
        self.focoMudou.emit()
        self._pedir()

    def _ejetou(self, _r):
        self.anunciar({"icon": "Check", "text": t("Pode tirar"), "detail": "", "level": "ok"})

    def _guardar_janela(self, ident):
        def pronto(v):
            if not v:
                self.acaoTerminou.emit("janela-guardar", False, t("nenhuma janela para guardar"))
                return
            self.voo.emit({"sentido": "ida", "from": v["geometry"], "title": v["title"], "appClass": v["appClass"], "estilo": self._cfg["voo"]})
            self.janelasMudou.emit()
            self.acaoTerminou.emit("janela-guardar", True, "")
        self.kwin.guardar(ident, pronto, lambda e: self.acaoTerminou.emit("janela-guardar", False, str(e)))
        return _ASSINCRONA

    def _encaixar_janela(self, arg):
        ident, _, lado = str(arg).partition("|")

        def pronto(v):
            self.acaoTerminou.emit("janela-encaixar", bool(v), "" if v else t("a janela não existe mais"))
        self.kwin.encaixar(ident, lado, pronto, lambda e: self.acaoTerminou.emit("janela-encaixar", False, str(e)))
        return _ASSINCRONA

    def _restaurar_janela(self, ident):
        self.kwin.restaurar(ident)
        self.janelasMudou.emit()

    def _listar_janelas(self):
        self.kwin.listar(lambda v: self.acaoTerminou.emit("janelas-abertas", True, json.dumps(v, ensure_ascii=False)),
                         lambda e: self.acaoTerminou.emit("janelas-abertas", False, str(e)))
        return _ASSINCRONA

    def _kwin(self, metodo, *args, caminho="/KWin", iface="org.kde.KWin"):
        B.chamar(B.msg("org.kde.KWin", caminho, iface, metodo, *args))

    def _exigir(self, ok, msg):
        if not ok:
            raise OSError(msg)

    def _acoes(self):
        m, c, g = self.midia, self.clipboard, self._dados
        q = lambda *a: self._exigir(*a)   # noqa: E731
        return {
            # mídia
            "midia-alternar": lambda a: m.alternar(), "midia-proxima": lambda a: m.proxima(), "midia-anterior": lambda a: m.anterior(),
            "midia-buscar": lambda a: m.buscar(a), "midia-embaralhar": lambda a: m.embaralhar(), "midia-repetir": lambda a: m.repetir(),
            "midia-abrir": lambda a: m.abrir(),
            "midia-copiar-link": lambda a: self._copiar_texto((m.atual() or {}).get("url", "")),
            # áudio
            "volume-mudo": lambda a: q(AU.alternar_mudo(), t("pactl não respondeu")), "volume-definir": lambda a: q(AU.definir_volume(a), t("pactl não respondeu")),
            "volume-subir": lambda a: q(AU.definir_volume((self.volume.visto or (50,))[0] + 5), t("pactl não respondeu")),
            "volume-baixar": lambda a: q(AU.definir_volume((self.volume.visto or (50,))[0] - 5), t("pactl não respondeu")),
            "audio-trocar-saida": lambda a: self._em_thread("audio-trocar-saida", AU.trocar_saida),
            "mic-mudo-alternar": lambda a: q(AU.alternar_mic(), t("pactl não respondeu")), "audio-definir-saida": lambda a: q(AU.definir_saida(a), t("pactl não respondeu")),
            # rede
            "wifi-alternar": lambda a: self._em_thread("wifi-alternar", RD.alternar_wifi), "bluetooth-alternar": lambda a: self._em_thread("bluetooth-alternar", RD.alternar_bluetooth),
            # KDE
            "cafeina-alternar": lambda a: self.inibir.alternar_cafeina(a or 0), "silencio-alternar": lambda a: self.inibir.alternar_silencio(),
            "kde-desktop-proxima": lambda a: self._kwin("nextDesktop"), "kde-desktop-anterior": lambda a: self._kwin("previousDesktop"),
            "kde-mostrar-desktop": lambda a: self._kwin("showDesktop", True),
            "kde-bloquear": lambda a: B.chamar(B.msg("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock")),
            "kde-captura": lambda a: q(shutil.which("spectacle") and QProcess.startDetached("spectacle", ["-r"])[0], t("spectacle não está instalado")),
            "kde-notificar": lambda a: self._notificar("CyberKDE", a or t("Aviso da ilha")),
            "cor-capturar": lambda a: self._em_thread("cor-capturar", EX.pegar_cor, depois=self._pegou_cor),
            # temporizador e foco
            "timer-iniciar": lambda a: self.tempo.iniciar(*(str(a).split("|", 1))), "timer-cronometro": lambda a: self.tempo.cronometro(a), "timer-parar": lambda a: self.tempo.parar(),
            "foco-limpar": lambda a: self._foco_limpar(),
            # clipboard e nota
            "clip-copiar": lambda a: c.copiar(a), "clip-fixar": lambda a: c.fixar(a), "clip-remover": lambda a: c.remover(a), "clip-limpar": lambda a: c.limpar(),
            "nota-salvar": lambda a: self._nota(a),
            # avisos
            "avisos-remover": lambda a: self.avisos.remover(int(a)), "avisos-limpar": lambda a: self.avisos.limpar(),
            "avisos-abrir-app": lambda a: q(AP.abrir_app(a if a.endswith(".desktop") else f"{a}.desktop"), t("aplicativo não encontrado")),
            # gaveta
            "gaveta-guardar": lambda a: self.soltar([a], ""), "gaveta-guardar-texto": lambda a: self.soltar([], a),
            "gaveta-remover": lambda a: self._gaveta_mexer(GV.remover(g["gaveta"], a)), "gaveta-limpar": lambda a: self._gaveta_mexer(GV.limpar(g["gaveta"])),
            "gaveta-abrir": lambda a: q(a in g["gaveta"] and AP.abrir_caminho(a), t("não está na gaveta")),
            "gaveta-enviar": lambda a: CL.enviar(a),
            # texto de imagem
            "texto-da-imagem": lambda a: self._em_thread("texto-da-imagem", EX.ler_imagem, a, depois=self._leu_texto),
            "texto-da-tela": lambda a: self._em_thread("texto-da-tela", EX.ler_tela, depois=self._leu_texto),
            # apps
            "apps-abrir": lambda a: q(AP.abrir_app(a), t("aplicativo não encontrado")), "abrir-caminho": lambda a: q(AP.abrir_caminho(a), t("não deu para abrir")),
            # janelas
            "janela-encaixar": lambda a: self._encaixar_janela(a), "janelas-abertas": lambda a: self._listar_janelas(), "janela-guardar": lambda a: self._guardar_janela(a),
            "janela-restaurar": lambda a: self._restaurar_janela(a), "janela-trazer": lambda a: self._restaurar_janela(a), "janela-focar": lambda a: self.kwin.focar(a),
            # celular e discos
            "celular-tocar": lambda a: CL.tocar(), "celular-ping": lambda a: CL.ping(), "celular-enviar": lambda a: CL.enviar(a), "celular-enviar-texto": lambda a: CL.enviar_texto(a),
            "disco-montar": lambda a: self._em_thread("disco-montar", DS.montar, a), "disco-ejetar": lambda a: self._em_thread("disco-ejetar", DS.ejetar, a, depois=self._ejetou),
            "disco-abrir": lambda a: q(AP.abrir_caminho(a), t("não deu para abrir")),
            # api
            "api-atividade-limpar": lambda a: self.api.remover(a),
        }
