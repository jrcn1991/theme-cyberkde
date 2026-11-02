#!/usr/bin/env python3
"""A ilha sem o back-end: um objeto "ilha" falso, para ver o QML e testar temas.

    QT_WAYLAND_SHELL_INTEGRATION=layer-shell python3 app/ilha/qml/dev/ilha_falsa.py [--tema id] [--estilo e]
Num Wayland ISOLADO. Sem layer-shell (--janela) abre como janela comum, para olhar o desenho.
Comandos pela entrada padrão: abrir, hud, aviso, comum, midia, config chave valor, sair. As ações vão para stderr.
"""
import argparse, json, os, sys, time
from pathlib import Path
a = argparse.ArgumentParser()
a.add_argument("--tema", default="halo"); a.add_argument("--estilo", default="preto"); a.add_argument("--en", action="store_true")
a.add_argument("--movimento", default="gota"); a.add_argument("--reduzir", action="store_true"); a.add_argument("--midia", action="store_true")
o = a.parse_args()
if not os.environ.get("QT_WAYLAND_SHELL_INTEGRATION") and os.environ.get("WAYLAND_DISPLAY"):
    os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"
from PyQt6.QtCore import QObject, QSocketNotifier, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QRegion
from PyQt6.QtQml import QQmlApplicationEngine

Q = Path(__file__).resolve().parent.parent
def L(i, l, v, d="", r=None, n="ok", **k): return dict(id=i, label=l, value=v, detail=d, ratio=r, level=n, **k)
def M(i, n, ic, rs, ac=()): return dict(id=i, name=n, icon=ic, readings=rs, actions=list(ac), ok=True, error=None)

class Ilha(QObject):
    resultadoLancador = pyqtSignal("QVariantList", arguments=["itens"]); voo = pyqtSignal("QVariantMap", arguments=["dado"]); ocultaMudou = pyqtSignal(); atalhoAcionado = pyqtSignal(str, arguments=["acao"])
    instantaneoMudou = pyqtSignal(); configMudou = pyqtSignal(); paletaMudou = pyqtSignal(); evento = pyqtSignal("QVariantMap")
    espectro = pyqtSignal("QVariantList"); acaoTerminou = pyqtSignal(str, bool, str); demonstrar = pyqtSignal(str)
    def __init__(s):
        super().__init__()
        s.midia = o.midia; s._cfg = dict(tema=o.tema, estilo=o.estilo, movimento=o.movimento, abertura="hover", alturaPilula=36, opacidadeOciosa=55, assento="sobre", modulos=[])
        s._gaveta = [dict(path="/x/relatorio.pdf", name="relatorio.pdf", exists=True, kind="arquivo"), dict(path="https://kde.org", name="kde.org", exists=True, kind="url")]
    def snap(s):
        m = [M("relogio", "Relógio", "Clock", [L("relogio-hora", "Hora", time.strftime("%H:%M")), L("relogio-data", "Data", "segunda-feira, 02 de novembro"), L("clima-temp", "Clima", "24°"), L("relogio-mundo", "Tokyo", "20:48"), L("relogio-mundo", "Lisbon", "11:48")]),
             M("sistema", "Sistema", "Cpu", [L("cpu", "CPU", "12%", "8 núcleos", .12), L("memoria", "Memória", "41%", "13 GB", .41), L("temp-cpu", "Temperatura", "52°", "", .5)]),
             M("audio", "Áudio", "SpeakerHigh", [L("volume", "Volume", "62%", "", .62)], [dict(id="volume-mudo", label="Mudo", icon="SpeakerSlash")]),
             M("rede", "Rede", "WifiHigh", [L("rede-conexao", "Conexão", "CASA"), L("wifi-sinal", "Sinal", "80%", "", .8), L("rede-baixando", "Baixando", "1,2 MB/s")]),
             M("discos", "Discos", "HardDrive", [L("discos-removiveis", "Removíveis", "1"), L("discos-lista", "Volumes", json.dumps([dict(device="/dev/sdb", name="SanDisk", size=8, volumes=[dict(device="/dev/sdb1", label="PENDRIVE", mountpoint="/media/x/PENDRIVE")])]))]),
             M("foco", "Foco", "Target", [L("foco-hoje", "Hoje", "25 min")]), M("kde", "Área", "Desktop", [L("silencio", "Silêncio", "desligado"), L("cafeina", "Cafeína", "desligada")])]
        if s.midia:
            m.append(M("midia", "Mídia", "MusicNotes", [L("midia-tocando", "Tocando", "Chippin' In", "Samurai", art=""), L("midia-estado", "Estado", "tocando"), L("midia-progresso", "Progresso", "1:24 / 3:45", "", .37), L("midia-player", "Player", "spotify")]))
            m[2]["readings"] += [L("saida-audio", "Saída", "Fones"), L("saidas-audio", "Saídas", json.dumps([dict(nome="a", descricao="Fones"), dict(nome="b.hdmi", descricao="HDMI ext")]))]
        return dict(at=int(time.time() * 1000), modules=m, timer=None, notices=[dict(id=1, at=int(time.time() * 1000), app="Konsole", title="Build terminou", body="npm run build", urgent=False, desktopEntry="")], downloads=[], clips=[dict(id=1, at=0, preview="https://kde.org", length=15, kind="url", pinned=False), dict(id=2, at=0, preview="#F75049", length=7, kind="cor", pinned=True)], note="", lyrics=[dict(at=0, text="Primeira linha"), dict(at=80000, text="Linha da hora"), dict(at=120000, text="Depois")] if s.midia else None, activities=[])
    @pyqtProperty("QVariantMap", notify=instantaneoMudou)
    def instantaneo(s): return s.snap()
    @pyqtProperty("QVariantList", constant=True)
    def gaveta(s): return s._gaveta
    @pyqtProperty("QVariantList", constant=True)
    def janelasGuardadas(s): return [dict(id="g1", title="Guardada", appClass="kate")]
    @pyqtProperty("QVariantMap", constant=True)
    def foco(s): return dict(hoje=25, semana=[0, 25, 50, 0, 75, 10, 25], sequencia=3)
    @pyqtSlot(str, result=bool)
    def ocultaNa(s, t): return False
    @pyqtSlot(str, result=QObject)
    def telaQt(s, nome): return next((t for t in QGuiApplication.screens() if t.name() == nome), QGuiApplication.primaryScreen())
    @pyqtProperty(int, constant=True)
    def alturaBarra(s): return 44
    @pyqtSlot(str, result="QVariantMap")
    def barraEm(s, n): return dict(altura=int(os.environ.get("BARRA", "33")), fundo="#0E1815", cor="#1AC26D")
    @pyqtSlot(str)
    def buscarApps(s, q): s.resultadoLancador.emit([dict(id="kate.desktop", nome="Kate", icone="kate")] if q else [])
    @pyqtProperty("QVariantList", constant=True)
    def telasEmTelaCheia(s): return []
    @pyqtProperty("QVariantList", constant=True)
    def telas(s):
        p = QGuiApplication.primaryScreen(); return [dict(nome=p.name(), principal=True, x=0, y=0, largura=p.size().width(), altura=p.size().height())]
    @pyqtProperty("QVariantMap", notify=configMudou)
    def config(s): return s._cfg
    @pyqtProperty("QVariantMap", notify=paletaMudou)
    def paleta(s): return dict(destaque="#F75049", secundaria="#5EF6FF", alerta="#FB932E", fundo="#0E0E17", corp="nenhuma", nome="CyberKDE")
    @pyqtProperty(bool, constant=True)
    def reduzir(s): return o.reduzir
    @pyqtProperty(str, constant=True)
    def movimento(s): return "minimo" if o.reduzir else "completo"
    @pyqtProperty(bool, constant=True)
    def oculta(s): return False
    @pyqtProperty(str, constant=True)
    def motivoOculta(s): return ""
    @pyqtProperty("QVariantMap", constant=True)
    def halo(s): return dict(ativo=False, como="")
    @pyqtProperty(str, constant=True)
    def idioma(s): return "en" if o.en else "pt_BR"
    @pyqtSlot(str)
    @pyqtSlot(str, str)
    def agir(s, i, arg=""):
        print("AGIR", i, arg, file=sys.stderr, flush=True)
        r = json.dumps([dict(id="a1", title="Konsole", appClass="konsole", active=True), dict(id="a2", title="Dolphin", appClass="dolphin", active=False)]) if i == "janelas-abertas" else ""
        if i == "janela-guardar": s.voo.emit({"sentido": "ida", "from": dict(x=300, y=250, width=700, height=480), "title": "Konsole", "appClass": "konsole", "estilo": s._cfg.get("voo", "sugado")})
        QTimer.singleShot(150, lambda: s.acaoTerminou.emit(i, True, r))
    @pyqtSlot(QObject, "QVariantList")
    def definirRegiao(s, j, rs):
        reg = QRegion()
        for r in rs: reg = reg.united(QRegion(int(r["x"]), int(r["y"]), int(r["width"]), int(r["height"])))
        print("REGIAO", rs, file=sys.stderr, flush=True)
        if j is not None: j.setMask(reg)
    @pyqtSlot(bool)
    def aberta(s, sim): print("ABERTA", sim, file=sys.stderr, flush=True)
    @pyqtSlot("QVariantList", str, result=int)
    def soltar(s, u, t): print("SOLTAR", u, t, file=sys.stderr, flush=True); return len(u)
    @pyqtSlot(str, result=str)
    def t(s, c): return c

app = QGuiApplication(sys.argv[:1]); il = Ilha()
m = QQmlApplicationEngine(); m.rootContext().setContextProperty("ilha", il); m.rootContext().setContextProperty("opcoes", dict(largura=532, altura=470, captura=""))
m.load(QUrl.fromLocalFile(str(Q / "Main.qml")))
if not m.rootObjects(): sys.exit(1)
QTimer(il, timeout=il.instantaneoMudou.emit).start(2000)
def cmd():
    p = sys.stdin.readline().split()
    if not p: return
    if p[0] == "sair": app.quit()
    elif p[0] in ("abrir", "hud", "aviso", "comum"): il.demonstrar.emit(p[0])
    elif p[0] == "atalho": il.atalhoAcionado.emit(p[1])
    elif p[0] == "midia": il.midia = not il.midia; il.instantaneoMudou.emit()
    elif p[0] == "config": il._cfg = dict(il._cfg, **{p[1]: json.loads(p[2]) if p[2][:1] in "0123456789[" else p[2]}); il.configMudou.emit()
n = QSocketNotifier(0, QSocketNotifier.Type.Read); n.activated.connect(cmd)
sys.exit(app.exec())
