"""KWin scripting por D-Bus: o que um cliente Wayland comum não enxerga (tela cheia, janelas dos outros).
Dois usos: o VIGIA residente (só existe enquanto a ilha vive) e trechos de uma vez só. A volta é sempre
um callDBus para org.cyberkde.Ilha.entrega."""

import json
import os
import secrets
import tempfile

from PyQt6.QtCore import QObject, QTimer, pyqtSignal

from . import bus as B
from .tarefas import cmd

SV, CAM_S, IF_S = "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting"
VIGIA = "cyberkde-ilha-vigia"
TIMEOUT_MS = 4000
_BASE = """
function entregar(nonce, valor) {
  callDBus('org.cyberkde.Ilha', '/org/cyberkde/Ilha', 'org.cyberkde.Ilha', 'entrega', nonce, JSON.stringify(valor))
}
function janela(id) {
  var l = workspace.windowList()
  for (var i = 0; i < l.length; i++) if (String(l[i].internalId) === id) return l[i]
  return null
}
function comum(w) { return w.normalWindow && !w.skipTaskbar && !w.specialWindow }
"""
_CODIGO_VIGIA = _BASE + """
function varrer() {
  var l = workspace.windowList(), telas = [], halo = false
  for (var i = 0; i < l.length; i++) {
    var w = l[i]
    if (String(w.caption) === 'Halo \\u00b7 Ilha') halo = true
    if (w.fullScreen && !w.minimized && w.output && (w.onAllDesktops || w.isOnDesktop === undefined || w.desktops.indexOf(workspace.currentDesktop) >= 0)) telas.push(String(w.output.name))
  }
  entregar('vigia', { telaCheia: telas, halo: halo })
}
function ligar(w) {
  w.fullScreenChanged.connect(varrer)
  w.minimizedChanged.connect(varrer)
  w.outputChanged.connect(varrer)
}
var l = workspace.windowList()
for (var i = 0; i < l.length; i++) ligar(l[i])
workspace.windowAdded.connect(function (w) { ligar(w); varrer() })
workspace.windowRemoved.connect(varrer)
workspace.currentDesktopChanged.connect(varrer)
%ATALHO%
varrer()
"""
# id do atalho -> título no KDE (a tecla vem da configuração)
ATALHOS = {"guardar": "CyberKDE Ilha: guardar a janela ativa", "abrir": "CyberKDE Ilha: abrir e fechar",
           "foco": "CyberKDE Ilha: iniciar ou parar o foco", "nota": "CyberKDE Ilha: abrir a nota"}


def codigo_atalhos(teclas):
    """teclas: {id: "Meta+X"}. json.dumps: nada da configuração entra cru no script do compositor."""
    return "\n".join(f"registerShortcut({json.dumps(ATALHOS[i])}, {json.dumps(ATALHOS[i])}, {json.dumps(k)}, "
                     f"function () {{ entregar('vigia', {{ atalho: {json.dumps(i)} }}) }})" for i, k in teclas.items() if k and i in ATALHOS)


class KWin(QObject):
    telaCheia = pyqtSignal(list)   # nomes das telas com janela em tela cheia
    haloVisto = pyqtSignal(bool)
    atalho = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._esperas = {}
        self.vigia = False
        self.guardadas = []
        self._arq_vigia = None

    def disponivel(self):
        return B.tem_dono(SV)

    def entrega(self, nonce, texto):
        try:
            v = json.loads(texto)
        except ValueError:
            return
        if nonce == "vigia":
            if "telaCheia" in v:
                self.telaCheia.emit(list(v["telaCheia"]))
                self.haloVisto.emit(bool(v.get("halo")))
            if v.get("atalho"):
                self.atalho.emit(str(v["atalho"]))
            return
        e = self._esperas.pop(nonce, None)
        if e:
            e[1].stop()
            e[0](v)

    def _script(self, codigo):
        fd, a = tempfile.mkstemp(prefix="cyberkde-ilha-", suffix=".js", dir=os.environ.get("XDG_RUNTIME_DIR") or None)
        with os.fdopen(fd, "w") as f:
            f.write(codigo)
        return a

    def iniciar_vigia(self, teclas=None):
        if self.vigia or not self.disponivel():
            return False
        self._arq_vigia = self._script(_CODIGO_VIGIA.replace("%ATALHO%", codigo_atalhos(teclas or {})))
        B.bloquear(B.msg(SV, CAM_S, IF_S, "unloadScript", VIGIA), 1000)   # sobra de uma saída brusca
        if B.bloquear(B.msg(SV, CAM_S, IF_S, "loadScript", self._arq_vigia, VIGIA), 2000) is None:
            return False
        B.chamar(B.msg(SV, CAM_S, IF_S, "start"))
        self.vigia = True
        return True

    def parar_vigia(self):
        if self.vigia:
            B.bloquear(B.msg(SV, CAM_S, IF_S, "unloadScript", VIGIA), 1000)
            self.vigia = False
        if self._arq_vigia:
            try:
                os.unlink(self._arq_vigia)
            except OSError:
                pass
            self._arq_vigia = None

    def esquecer_atalhos(self, ids=None):
        """Solta a tecla e tira a linha: o kglobalaccel guarda na memória e reescreve o arquivo por cima,
        então só apagar do kglobalshortcutsrc não basta (medido no Halo)."""
        for i in ids if ids is not None else ATALHOS:
            B.chamar(B.msg("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "unregister", "kwin", ATALHOS[i]))
            cmd("kwriteconfig6", "--file", "kglobalshortcutsrc", "--group", "kwin", "--key", ATALHOS[i], "--delete")

    def rodar(self, trecho, pronto, falhou=None):
        """Um trecho de uma vez: `entregar(NONCE, valor)` manda o resultado. Script órfão no compositor não fica."""
        nonce = secrets.token_hex(8)
        plugin = f"cyberkde-ilha-{nonce}"
        arq = self._script(_BASE + trecho.replace("NONCE", json.dumps(nonce)))

        def limpar():
            B.chamar(B.msg(SV, CAM_S, IF_S, "unloadScript", plugin))
            try:
                os.unlink(arq)
            except OSError:
                pass

        def chegou(v):
            limpar()
            pronto(v)

        def estourou():
            self._esperas.pop(nonce, None)
            limpar()
            if falhou:
                falhou("o KWin não respondeu ao script")
        rel = QTimer(self, singleShot=True, interval=TIMEOUT_MS)
        rel.timeout.connect(estourou)
        rel.start()
        self._esperas[nonce] = (chegou, rel)
        B.chamar(B.msg(SV, CAM_S, IF_S, "loadScript", arq, plugin),
                 lambda _a: B.chamar(B.msg(SV, CAM_S, IF_S, "start")), lambda e: falhou and falhou(e))

    # ---- janelas
    def listar(self, pronto, falhou=None):
        self.rodar("""
var l = workspace.stackingOrder, r = []
for (var i = 0; i < l.length; i++) { var w = l[i]; if (!comum(w)) continue
  r.push({ id: String(w.internalId), title: String(w.caption), appClass: String(w.resourceClass), minimized: w.minimized,
           active: w === workspace.activeWindow, geometry: { x: w.x, y: w.y, width: w.width, height: w.height } }) }
entregar(NONCE, r)""", pronto, falhou)

    def guardar(self, ident, pronto, falhou=None):
        """Minimiza e tira da barra. `ident` vazio = a janela ativa."""
        alvo = f"janela({json.dumps(ident)})" if ident else "workspace.activeWindow"

        def fim(v):
            if v:
                self.guardadas = [g for g in self.guardadas if g["id"] != v["id"]] + [v]
            pronto(v)
        self.rodar(f"""
var w = {alvo}, v = null
if (w && comum(w)) {{ v = {{ id: String(w.internalId), title: String(w.caption), appClass: String(w.resourceClass), minimized: true, active: false,
  geometry: {{ x: w.x, y: w.y, width: w.width, height: w.height }} }}
  w.skipTaskbar = true; w.skipSwitcher = true; w.minimized = true }}
entregar(NONCE, v)""", fim, falhou)

    def restaurar(self, ident, pronto=None, falhou=None):
        self.guardadas = [g for g in self.guardadas if g["id"] != ident]
        self.rodar(f"""
var w = janela({json.dumps(ident)})
if (w) {{ w.skipTaskbar = false; w.skipSwitcher = false; w.minimized = false; workspace.activeWindow = w }}
entregar(NONCE, !!w)""", pronto or (lambda _v: None), falhou)

    def soltar_guardadas(self):
        """Ao sair: nenhuma janela pode ficar escondida para sempre."""
        for g in list(self.guardadas):
            self.restaurar(g["id"])

    def encaixar(self, ident, lado, pronto, falhou=None):
        """esquerda, direita ou maximizar, na área útil da tela da janela."""
        if lado not in ("esquerda", "direita", "maximizar"):
            raise OSError("lado inválido")
        self.rodar(f"""
var alvo = janela({json.dumps(ident)})
if (!alvo) entregar(NONCE, false)
else {{
  alvo.minimized = false
  var lado = {json.dumps(lado)}
  if (lado === 'maximizar') alvo.setMaximize(true, true)
  else {{
    alvo.setMaximize(false, false)
    var area = workspace.clientArea(KWin.MaximizeArea, alvo), w = Math.round(area.width / 2)
    alvo.frameGeometry = {{ x: lado === 'esquerda' ? area.x : area.x + area.width - w, y: area.y, width: w, height: area.height }}
  }}
  workspace.activeWindow = alvo
  entregar(NONCE, true)
}}""", pronto, falhou)

    def focar(self, ident, pronto=None, falhou=None):
        self.rodar(f"""
var w = janela({json.dumps(ident)})
if (w) {{ w.minimized = false; workspace.activeWindow = w }}
entregar(NONCE, !!w)""", pronto or (lambda _v: None), falhou)
