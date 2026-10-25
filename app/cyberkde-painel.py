#!/usr/bin/env python3
"""Painel do CyberKDE: interface gráfica (QML) para ligar, desligar e personalizar o tema.

O painel só fala com o CLI (scripts/cyberkde ou $CYBERKDE_BIN): nunca grava a configuração do tema
por conta própria. As únicas coisas que ele grava são as próprias preferências
(~/.config/cyberkde/painel.json) e o logo que a usuária escolhe para uma corporação
(~/.config/cyberkde/corporacoes/<id>.svg|png), que o CLI lê depois.

Tudo roda com QProcess, sem bloquear a interface. Operações que alteram o sistema (on, off, cor,
corp, papel) entram numa fila e rodam uma de cada vez; leituras (status, fases, lista de
corporações, checar) rodam direto.

Uso: python3 app/cyberkde-painel.py [--sem-boot] [--secao N] [--captura ARQ.png [--espera MS]]
  --captura salva a janela (QQuickWindow.grabWindow) depois de --espera ms e sai; serve para
  conferir o visual sem capturar a tela inteira.
"""

import argparse
import json
import re
import os
import shlex
import shutil
import sys
import time
from pathlib import Path

from PyQt6.QtCore import (QLocale, QObject, QProcess, QProcessEnvironment, QTimer, Qt, QUrl, pyqtProperty,
                          pyqtSignal, pyqtSlot)
from PyQt6.QtGui import QFontDatabase, QGuiApplication, QIcon, QImage
from PyQt6 import sip
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickWindow  # noqa: F401  (rootObjects()[0] vira QQuickWindow)

APP_DIR = Path(__file__).resolve().parent
REPO = APP_DIR.parent
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "cyberkde"
PREFS = CONFIG / "painel.json"
LOGOS_USUARIA = CONFIG / "corporacoes"
LOGOS_TEMA = REPO / "assets" / "corporacoes"
LOGOS_GENERICOS = LOGOS_TEMA / "genericos"   # emblemas genéricos: só se faltar o arquivo oficial

COR_PADRAO = "#F75049"

# Paleta e lema de cada corporação. Ordem de preferência, campo a campo: o "corp --lista --json" do
# CLI, depois tokens/corporacoes.json (a fonte única, que o CLI também lê) e, sem nenhum dos dois,
# estes valores de reserva (os mesmos do tokens na data em que foram escritos).
CAMPOS_PALETA = ("destaque", "secundaria", "alerta", "fundo")
TOKENS_CORPS = REPO / "tokens" / "corporacoes.json"
TOKENS_TEMA = REPO / "tokens" / "cyberkde.json"
CORPS_RESERVA = {
    "arasaka": {"nome": "Arasaka", "lema": "Honra é protocolo. Lealdade é contrato.", "lema_en": "Honor is protocol. Loyalty is contract.",
                "destaque": "#F75049", "secundaria": "#DCDCE4", "alerta": "#FB932E", "fundo": "#0E0E17"},
    "biotechnica": {"nome": "Biotechnica", "lema": "A vida, reescrita em código verde.", "lema_en": "Life, rewritten in green code.",
                    "destaque": "#1DED83", "secundaria": "#5EF6FF", "alerta": "#F0B537", "fundo": "#0A1410"},
    "militech": {"nome": "Militech", "lema": "Força é a única garantia.", "lema_en": "Strength is the only guarantee.",
                 "destaque": "#FCEE0A", "secundaria": "#FB932E", "alerta": "#F75049", "fundo": "#11100A"},
    "netwatch": {"nome": "NetWatch", "lema": "Nada escapa à rede.", "lema_en": "Nothing escapes the net.",
                 "destaque": "#2570D4", "secundaria": "#5EF6FF", "alerta": "#F75049", "fundo": "#0A0E1A"},
    "kangtao": {"nome": "Kang Tao", "lema": "Inteligência em cada disparo.", "lema_en": "Intelligence in every shot.",
                "destaque": "#FF7A1A", "secundaria": "#F0B537", "alerta": "#F75049", "fundo": "#120D0A"},
    "segotari": {"nome": "Segotari", "lema": "O amanhã já tem dono.", "lema_en": "Tomorrow already has an owner.",
                 "destaque": "#2D8CFF", "secundaria": "#F75049", "alerta": "#FB932E", "fundo": "#0A0E18"},
    "zetatech": {"nome": "Zetatech", "lema": "Pense à frente.", "lema_en": "Think ahead.",
                 "destaque": "#D6D0D0", "secundaria": "#5EF6FF", "alerta": "#F75049", "fundo": "#0E0E12"},
}
ORDEM_RESERVA = ("arasaka", "biotechnica", "kangtao", "militech", "netwatch", "segotari", "zetatech")
# Sem corporação: a paleta original do tema (vermelho e ciano). "Personalizada" parte dela.
ESPECIAIS_RESERVA = {
    "nenhuma": {"nome": "Padrão", "lema": "Vermelho de fábrica, sem bandeira.", "lema_en": "Factory red, no flag.",
                "destaque": "#F75049", "secundaria": "#5EF6FF", "alerta": "#FB932E", "fundo": "#0E0E17"},
    "personalizada": {"nome": "Personalizada", "lema": "Sua cor. Sua rede. Suas regras.", "lema_en": "Your color. Your net. Your rules.",
                      "destaque": "#9D2BF5", "secundaria": "#5EF6FF", "alerta": "#FB932E", "fundo": "#0E0E17"},
}


def ler_tokens_corps():
    """tokens/corporacoes.json -> {id: {...}}. Aceita lista em "corps"/"corporacoes", lista pura ou
    objeto indexado pelo id. Sem o arquivo (ou com erro), {}."""
    try:
        dados = json.loads(TOKENS_CORPS.read_text())
    except (OSError, ValueError):
        return {}
    if isinstance(dados, dict):
        lista = dados.get("corps") or dados.get("corporacoes")
        if lista is None:
            return {k: v for k, v in dados.items() if isinstance(v, dict) and not k.startswith("_")}
    else:
        lista = dados
    return {c["id"]: c for c in lista or [] if isinstance(c, dict) and c.get("id")}


def paleta_do_kit():
    """Amostras do seletor de cor: as cores de referência e secundárias de tokens/cyberkde.json."""
    try:
        t = json.loads(TOKENS_TEMA.read_text())
        cores = [t["reference"]["red"], t["reference"]["cyan"]] + list(t["secondary"].values())
        return [c.upper() for c in cores if isinstance(c, str) and c.startswith("#")]
    except (OSError, ValueError, KeyError, TypeError):
        return ["#F75049", "#5EF6FF", "#1DED83", "#2570D4", "#9D2BF5", "#FB932E", "#F0B537", "#D6D0D0"]


_RECORTES = {}


def recorte_opaco(caminho):
    """Caixa da área opaca (alfa > 10%) de uma imagem, em frações do quadro, mais a proporção do
    quadro: {"x","y","w","h","a"}. Serve para os ícones terem o mesmo tamanho visual, seja qual for a
    margem transparente de cada arquivo. Guardado por caminho e data de modificação."""
    try:
        chave = (str(caminho), os.path.getmtime(caminho))
    except OSError:
        return None
    if chave in _RECORTES:
        return _RECORTES[chave]
    img = QImage(str(caminho))
    resultado = None
    if not img.isNull():
        # trabalha numa cópia de até 256 px: precisão de sobra para dimensionar ícone
        if max(img.width(), img.height()) > 256:
            img = img.scaled(256, 256, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
        img = img.convertToFormat(QImage.Format.Format_ARGB32)
        W, H = img.width(), img.height()
        x0, y0, x1, y1 = W, H, -1, -1
        for y in range(H):
            for x in range(W):
                if (img.pixel(x, y) >> 24) & 0xFF > 25:
                    if x < x0: x0 = x
                    if x > x1: x1 = x
                    if y < y0: y0 = y
                    if y > y1: y1 = y
        if x1 >= x0 and y1 >= y0:
            resultado = {"x": x0 / W, "y": y0 / H, "w": (x1 - x0 + 1) / W, "h": (y1 - y0 + 1) / H, "a": W / H}
    _RECORTES[chave] = resultado
    return resultado


CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "cyberkde-painel"


def gerar_contorno(caminho):
    """"Circuito" de um logo (a variação em wireframe da referência "Efeito de logo2"): bordas da área
    opaca, hachuras diagonais paralelas dentro da forma e pequenos nós quadrados nas bordas. Branco
    sobre transparente (o QML tinge). Guardado em ~/.cache/cyberkde-painel/contornos; devolve o
    caminho do PNG ou "" se não der."""
    import hashlib
    try:
        chave = hashlib.sha1(f"{caminho}|{os.path.getmtime(caminho)}|v2".encode()).hexdigest()[:16]
    except OSError:
        return ""
    destino = CACHE / "contornos" / f"{chave}.png"
    if destino.is_file():
        return str(destino)
    img = QImage(str(caminho))
    if img.isNull():
        return ""
    W0, H0 = img.width(), img.height()
    escala = 360 / max(W0, H0)
    W, H = max(1, round(W0 * escala)), max(1, round(H0 * escala))
    img = img.scaled(W, H, Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
    img = img.convertToFormat(QImage.Format.Format_ARGB32)
    ptr = img.constBits()
    ptr.setsize(img.sizeInBytes())
    bruto = bytes(ptr)
    linha = img.bytesPerLine()
    try:
        import numpy as np
        a = np.frombuffer(bruto, dtype=np.uint8).reshape(H, linha)[:, :W * 4].reshape(H, W, 4)[:, :, 3] > 90
        viz = np.zeros_like(a)
        viz[1:, :] |= ~a[:-1, :]; viz[:-1, :] |= ~a[1:, :]; viz[:, 1:] |= ~a[:, :-1]; viz[:, :-1] |= ~a[:, 1:]
        borda = a & viz
        yy, xx = np.mgrid[0:H, 0:W]
        hachura = a & (((xx + yy) % 7) == 0)
        saida = np.zeros((H, W, 4), dtype=np.uint8)
        saida[borda] = (255, 255, 255, 255)
        saida[hachura & ~borda] = (255, 255, 255, 110)
        # nós: quadradinhos de 5 px em pontos da borda (1 a cada ~180 pontos)
        ys, xs = np.nonzero(borda)
        for y, x in list(zip(ys, xs))[::180]:
            y0, x0 = max(0, y - 2), max(0, x - 2)
            saida[y0:y + 3, x0:x + 3] = (255, 255, 255, 255)
            saida[y0 + 1:y + 2, x0 + 1:x + 2] = (0, 0, 0, 0)
        dados = saida.tobytes()
    except ImportError:
        alfa = [[bruto[y * linha + x * 4 + 3] > 90 for x in range(W)] for y in range(H)]
        out = bytearray(W * H * 4)
        for y in range(H):
            for x in range(W):
                if not alfa[y][x]:
                    continue
                aresta = (x == 0 or y == 0 or x == W - 1 or y == H - 1 or not alfa[y - 1][x] or not alfa[y + 1][x]
                          or not alfa[y][x - 1] or not alfa[y][x + 1])
                if aresta or (x + y) % 7 == 0:
                    i = (y * W + x) * 4
                    out[i:i + 4] = bytes((255, 255, 255, 255 if aresta else 110))
        dados = bytes(out)
    res = QImage(dados, W, H, W * 4, QImage.Format.Format_ARGB32).copy()
    destino.parent.mkdir(parents=True, exist_ok=True)
    return str(destino) if res.save(str(destino), "PNG") else ""


def hexa(valor, reserva):
    v = (valor or "").strip() if isinstance(valor, str) else ""
    return v.upper() if len(v) == 7 and v.startswith("#") else reserva


# Fases de reserva (CLI sem "fases --json"): id e grupo; nomes e descrições vêm do catálogo
# (app/i18n: "fase.<id>.nome", "fase.<id>.descricao", "grupo.<id>").
FASES_EXEMPLO = [
    ("dolphin", "apps"), ("apps", "apps"), ("carregamento", "apps"), ("konsole", "apps"),
    ("konsole-anim", "apps"), ("janelas", "janelas"), ("plasma", "sistema"), ("barra-e-dock", "sistema"),
    ("icones", "apps"), ("icones-sistema", "sistema"), ("papeis-de-parede", "sistema"), ("login", "login"),
]

# ---- efeitos de janela (Rachael: effects/cyberkde_scan/variantes.json; prévias em
# assets/previas/janelas/<id>-abrir.webp e -fechar.webp). Sem o CLI nem o arquivo, este catálogo de
# exemplo deixa a galeria montada; "estilo" escolhe a prévia desenhada em QML quando falta o webp.
VARIANTES_ARQUIVO = REPO / "effects" / "cyberkde_scan" / "variantes.json"
PREVIAS_JANELAS = REPO / "assets" / "previas" / "janelas"
VARIANTES_EXEMPLO = [
    ("varredura", "Varredura", "Scan", "Uma linha clara desce e revela a janela.", "A bright line sweeps down and reveals the window.", 260, 180),
    ("montagem", "Montagem", "Assembly", "A moldura se traça a partir do canto e o conteúdo acende com flicker.", "The frame traces from the corner and the content flickers on.", 340, 200),
    ("glitch", "Glitch em fatias", "Slice glitch", "A janela chega em fatias horizontais deslocadas.", "The window arrives in offset horizontal slices.", 280, 200),
    ("aberracao", "Aberração cromática", "Chromatic aberration", "Duas cópias coloridas convergem para a imagem.", "Two colored copies converge into the image.", 260, 180),
    ("crt", "Tubo CRT", "CRT tube", "Abre de uma linha no centro; fecha numa linha e depois num ponto.", "Opens from a line in the middle; closes to a line, then a dot.", 300, 240),
    ("pixel", "Digitalizar", "Digitize", "Blocos grandes que se refinam até a imagem nítida.", "Coarse blocks refining into the sharp image.", 320, 220),
    ("cortina", "Comporta", "Blast doors", "Duas metades se abrem a partir do centro.", "Two halves slide open from the center.", 280, 200),
    ("holograma", "Holograma", "Hologram", "Linhas de varredura e tremulação até estabilizar.", "Scanlines and jitter until it settles.", 360, 220),
    ("dados", "Chuva de dados", "Data rain", "Colunas de dados descem e deixam a janela no lugar.", "Data columns fall and leave the window behind.", 380, 260),
    ("linhas", "Linhas de terminal", "Terminal lines", "A janela se monta linha a linha, de cima para baixo.", "The window builds line by line, top to bottom.", 320, 200),
    ("zoom", "Zoom chanfrado", "Chamfered zoom", "Cresce do centro com os cantos cortados do tema.", "Grows from the center with the theme's cut corners.", 220, 160),
    ("interferencia", "Interferência", "Interference", "Ruído de sinal que se dissolve na imagem.", "Signal noise dissolving into the image.", 300, 200),
    ("desintegrar", "Desintegrar", "Disintegrate", "Lascas que se juntam (abrir) ou se espalham (fechar).", "Shards gathering (open) or scattering (close).", 360, 300),
    ("braindance", "Braindance", "Braindance", "Moldura vermelha de edição, com marcas de tempo, que se abre em camadas.", "Red editing frame with timecodes opening in layers.", 400, 240),
]


# Prévia desenhada (quando falta o webp) para os ids do catálogo da Rachael: o estilo mais parecido.
ESTILO_PREVIA = {
    "scan": "varredura", "moldura": "montagem", "decodificar": "pixel", "chanfro": "varredura",
    "cacos": "desintegrar", "convergir": "aberracao", "terminal": "linhas", "neon": "holograma",
    "modal": "montagem", "pulso": "linhas", "persiana": "cortina", "portas": "cortina", "radar": "varredura",
}


# ---- idioma
I18N = APP_DIR / "i18n"
IDIOMAS = ("pt_BR", "en")


def carregar_catalogos():
    cat = {}
    for idioma in IDIOMAS:
        try:
            cat[idioma] = json.loads((I18N / f"{idioma}.json").read_text())
        except (OSError, ValueError) as e:
            print(f"aviso: catálogo {idioma} ilegível: {e}", file=sys.stderr)
            cat[idioma] = {}
    return cat


def idioma_do_sistema():
    """Segue o locale do sistema; o que não for inglês fica em PT-BR (a reserva)."""
    return "en" if QLocale.system().name().lower().startswith("en") else "pt_BR"


def agora():
    return time.strftime("%H:%M:%S")


def url_local(caminho, versao=0):
    """URL de arquivo para o QML; a versão força o Image a recarregar quando o arquivo muda."""
    if not caminho:
        return ""
    url = QUrl.fromLocalFile(str(caminho)).toString()
    return f"{url}?v={versao}" if versao else url


def json_da_saida(texto):
    """Última linha da saída que é um objeto JSON (o CLI imprime uma linha JSON no fim)."""
    for linha in reversed(texto.splitlines()):
        linha = linha.strip()
        if linha.startswith("{"):
            try:
                return json.loads(linha)
            except ValueError:
                continue
    return None


def ler_prefs():
    """Só o que a usuária escolheu no painel; o que não está no arquivo segue o padrão."""
    try:
        prefs = json.loads(PREFS.read_text())
        return prefs if isinstance(prefs, dict) else {}
    except (OSError, ValueError):
        return {}


def fator_animacao_kde():
    try:
        for linha in (Path.home() / ".config" / "kdeglobals").read_text().splitlines():
            if linha.startswith("AnimationDurationFactor="):
                return float(linha.split("=", 1)[1])
    except (OSError, ValueError):
        pass
    return 1.0


class Painel(QObject):
    statusMudou = pyqtSignal()
    fasesMudou = pyqtSignal()
    corpsMudou = pyqtSignal()
    filaMudou = pyqtSignal()
    progressoMudou = pyqtSignal()
    prefsMudou = pyqtSignal()
    papelMudou = pyqtSignal()
    diagnosticoMudou = pyqtSignal()
    registroMudou = pyqtSignal()
    paletaMudou = pyqtSignal()
    idiomaMudou = pyqtSignal()
    cascataMudou = pyqtSignal()
    efeitosMudou = pyqtSignal()
    somMudou = pyqtSignal()
    desfazerMudou = pyqtSignal()

    # nivel: info | ok | aviso | erro ; texto curto para a notificação flutuante
    notificar = pyqtSignal(str, str)
    # comando a rodar no terminal e frases do CLI explicando o que ficou pendente
    sudoPendente = pyqtSignal(str, "QVariantList")
    # nome da operação, código de saída
    operacaoTerminou = pyqtSignal(str, int)

    def __init__(self, binario):
        super().__init__()
        self._bin = binario
        self._status = {}
        self._statusOk = False
        self._fases = []
        self._temaLigado = False
        self._suporteFases = False
        self._corps = []
        self._corpAtual = "nenhuma"
        self._corpAtualCli = None
        self._doCli = {}
        self._tokens = ler_tokens_corps()
        self._especiais = {}
        self._registroPorFase = True
        self._suporteSecundaria = False
        self._suporteCorp = False
        self._fila = []
        self._atual = None  # operação em andamento: dict(rotulo, alvo, ...)
        self._progresso = {"etapa": "", "fase": "", "feitas": 0, "total": 0}
        self._prefs = ler_prefs()
        self._catalogos = carregar_catalogos()
        self._idioma = self._prefs.get("idioma") if self._prefs.get("idioma") in IDIOMAS else idioma_do_sistema()
        self._fasesCli = None   # resposta crua do "fases --json" (para recompor ao trocar de idioma)
        self._desfazer = self._prefs.get("desfazer") or {}
        self._papel = ""
        # efeitos de janela (galeria) e demais efeitos configuráveis (efeito --lista)
        self._fxJanelas = {"suporte": False, "fonte": "exemplo", "variantes": [], "abrir": "", "fechar": "",
                           "duracaoAbrir": 0, "duracaoFechar": 0, "intensidade": 60, "disponivel": None}
        self._fxJanelasCli = None
        self._fxLista = []
        self._fxListaCli = None
        self._fxListaGrupos = None
        self._enviados = {}       # efeito -> {opção: valor} já mandados ao CLI, à espera do estado novo
        self._fimOpEfeito = {}    # efeito -> monotonic() do fim da última operação dele
        self._fxGrupos = []
        self._fxMovimento = None
        self._suporteFxLista = False
        # efeito "cascata de dados" do Konsole (konsole/PEDIDO-CLI.md); suporte: o CLI informa o estado
        self._cascata = {"suporte": False, "ligado": False, "linhas": 5, "cores": "video", "disponivel": None,
                         "disponivelAoReligar": False}
        self._diag = {"rodando": False, "codigo": -1, "itens": [], "hora": ""}
        self._registro = []
        self._versaoLogo = int(time.time()) % 100000
        self._log("info", "log.cli", bin=self._bin)
        if not os.access(self._bin, os.X_OK):
            self._log("erro", "log.cliAusente")

    # ---------------------------------------------------------------- execução de processos
    def _processo(self, args, ao_terminar, progresso=False):
        """Roda o CLI com args. ao_terminar(codigo, saida, erro). Linhas PROGRESSO viram progresso."""
        p = QProcess(self)
        # Idioma das mensagens do CLI: CYBERKDE_LANG (ver PEDIDOS-AO-CLI.md). Um CLI que não conhece a
        # variável a ignora; não se passa "--lang", que um CLI antigo recusaria com código 2.
        env = QProcessEnvironment.systemEnvironment()
        env.insert("CYBERKDE_LANG", "en" if self._idioma == "en" else "pt_BR")
        env.insert("CYBERKDE_SEM_SUDO", "1")   # o painel nunca pede senha: o que precisar de sudo fica pendente
        p.setProcessEnvironment(env)
        buf = {"out": b"", "err": b"", "resto": b""}

        def ler_erro():
            try:
                dados = buf["resto"] + bytes(p.readAllStandardError())
            except RuntimeError:   # processo já destruído (painel fechando)
                return
            *linhas, buf["resto"] = dados.split(b"\n")
            for bruta in linhas:
                linha = bruta.decode("utf-8", "replace").rstrip()
                buf["err"] += bruta + b"\n"
                if linha.startswith("PROGRESSO "):
                    if progresso:
                        try:
                            self._progresso = json.loads(linha[len("PROGRESSO "):])
                            self.progressoMudou.emit()
                        except ValueError:
                            pass
                elif linha and self._atual is not None and progresso:
                    self._log("info", None, texto=linha)   # saída do CLI: fica no idioma dele

        def ler_saida():
            try:
                buf["out"] += bytes(p.readAllStandardOutput())
            except RuntimeError:
                pass

        def terminou(codigo, estado):
            ler_saida()
            ler_erro()
            if buf["resto"]:
                buf["err"] += buf["resto"]
            if estado != QProcess.ExitStatus.NormalExit:
                codigo = -1
            p.deleteLater()
            ao_terminar(codigo, buf["out"].decode("utf-8", "replace"), buf["err"].decode("utf-8", "replace"))

        def falhou(erro):
            if erro == QProcess.ProcessError.FailedToStart:
                p.deleteLater()
                ao_terminar(-1, "", self._t("erro.executar", bin=self._bin))

        p.readyReadStandardError.connect(ler_erro)
        p.readyReadStandardOutput.connect(ler_saida)
        p.finished.connect(terminou)
        p.errorOccurred.connect(falhou)
        p.start(self._bin, args)
        return p

    def _enfileirar(self, rotulo, args, alvo="", progresso=True, depois=None, sudo=None):
        """Operação que altera o sistema: entra na fila e roda quando a anterior terminar.
        sudo: comando para o terminal se o CLI responder 4 (pendente de sudo)."""
        self._fila.append({"rotulo": rotulo, "args": args, "alvo": alvo, "progresso": progresso,
                           "depois": depois, "sudo": sudo})
        self.filaMudou.emit()
        self._proxima()

    def _proxima(self):
        if self._atual is not None or not self._fila:
            return
        op = self._fila.pop(0)
        self._atual = op
        self._progresso = {"etapa": "inicio", "fase": "", "feitas": 0, "total": 0}
        self.progressoMudou.emit()
        self.filaMudou.emit()
        self._log("info", "op.inicio", nome=op["rotulo"], args=" ".join(op["args"]))
        self._processo(op["args"], lambda c, o, e: self._fimOperacao(op, c, o, e), progresso=op["progresso"])

    def _fimOperacao(self, op, codigo, saida, erro):
        resultado = json_da_saida(saida) or {}
        rot = op["rotulo"]
        nome = self._t(*rot)
        if codigo == 0 and (resultado.get("pendentesSudo") or resultado.get("retomar")):
            # aplicado, mas a parte que precisa de senha ficou para o terminal (ex.: tela de login)
            codigo = 4
        if codigo == 0:
            self._log("ok", "op.ok", nome=rot)
            for aviso in resultado.get("avisos") or []:
                self._log("aviso", None, texto="  " + aviso)
            self.notificar.emit("ok", self._t("notif.ok", nome=nome))
        elif codigo == 4:
            comando = resultado.get("retomar") or op["sudo"] or "cyberkde " + " ".join(a for a in op["args"] if not a.startswith("--"))
            avisos = resultado.get("avisos") or []
            self._log("aviso", "op.sudo", nome=rot, comando=comando)
            self.sudoPendente.emit(comando, avisos)
        elif codigo == 3:
            self._log("aviso", "op.ocupado", nome=rot)
            self.notificar.emit("aviso", self._t("notif.ocupado"))
        else:
            motivo = resultado.get("erro") or next(
                (l for l in reversed(erro.splitlines()) if l.strip() and not l.startswith("PROGRESSO")), "")
            self._log("erro", "op.falhou", nome=rot, codigo=codigo, motivo=motivo)
            self.notificar.emit("erro", self._t("notif.falhou", nome=nome, motivo=motivo).strip())
        if str(op.get("alvo", "")).startswith("fx:"):
            eid = op["alvo"][3:]
            self._fimOpEfeito[eid] = time.monotonic()
            if codigo not in (0, 4):
                self._enviados.pop(eid, None)   # falhou: vale o estado que o CLI tem
        if op["depois"]:
            op["depois"](codigo, resultado)
        self._atual = None
        self._progresso = dict(self._progresso, etapa="fim" if codigo in (0, 4) else "erro")
        self.progressoMudou.emit()
        self.filaMudou.emit()
        self.operacaoTerminou.emit(nome, codigo)
        if not self._fila:
            self.atualizar()
        self._proxima()

    # ---------------------------------------------------------------- registro
    def _log(self, nivel, chave, **args):
        """Guarda a chave do catálogo e os argumentos; o texto é montado na hora de mostrar, no idioma
        do momento. chave None + texto=...: texto pronto (saída do CLI)."""
        self._registro.append({"hora": agora(), "nivel": nivel, "chave": chave, "args": args})
        del self._registro[:-500]
        self.registroMudou.emit()

    def _textoLog(self, r):
        return r["args"].get("texto", "") if r["chave"] is None else self._t(r["chave"], **r["args"])

    @pyqtProperty("QVariantList", notify=registroMudou)
    def registro(self):
        return [{"hora": r["hora"], "nivel": r["nivel"], "texto": self._textoLog(r)} for r in self._registro]

    # ---------------------------------------------------------------- idioma
    def _t(self, chave, _mapa=None, /, **kw):
        """Texto do catálogo no idioma atual (reserva: PT-BR, depois a própria chave). Argumentos
        que sejam (chave, args) — rótulos de operação — também são traduzidos."""
        if _mapa:
            kw = {**_mapa, **kw}
        texto = self._catalogos.get(self._idioma, {}).get(chave)
        if texto is None:
            texto = self._catalogos.get("pt_BR", {}).get(chave, chave)
        valores = {k: (self._t(*v) if isinstance(v, tuple) else v) for k, v in kw.items()}
        try:
            return texto.format(**valores)
        except (KeyError, IndexError, ValueError):
            return texto

    def _tem(self, chave):
        return chave in self._catalogos.get(self._idioma, {})

    @pyqtProperty(str, notify=idiomaMudou)
    def idioma(self):
        return self._idioma

    @idioma.setter
    def idioma(self, valor):
        if valor not in IDIOMAS or valor == self._idioma:
            return
        self._idioma = valor
        self._prefs["idioma"] = valor
        self._salvarPrefs()
        # tudo que tem texto é recomposto: corporações, fases, registro, rótulos
        self._recomporCorps()
        self._recomporFases()
        self._recomporEfeitos()
        self.idiomaMudou.emit()
        self.registroMudou.emit()
        self.filaMudou.emit()
        self.diagnosticoMudou.emit()
        # o que veio do CLI (diagnóstico) foi escrito no idioma antigo: lê de novo
        if self._diag.get("hora") and not self._diag.get("rodando"):
            self.checar()

    @pyqtProperty("QVariantMap", notify=idiomaMudou)
    def textos(self):
        """Catálogo do idioma atual, com o PT-BR por baixo (chave faltando no inglês sai em PT-BR)."""
        return {**self._catalogos.get("pt_BR", {}), **self._catalogos.get(self._idioma, {})}

    @pyqtSlot()
    def limparRegistro(self):
        self._registro = []
        self.registroMudou.emit()

    @pyqtSlot(str)
    def copiar(self, texto):
        QGuiApplication.clipboard().setText(texto)

    @pyqtSlot(result=str)
    def registroComoTexto(self):
        return "\n".join(f"{r['hora']}  {self._textoLog(r)}" for r in self._registro)

    # ---------------------------------------------------------------- leitura
    @pyqtSlot()
    def atualizar(self):
        self._lerSuporte()
        self._lerEfeitos()
        self._lerStatus()
        self._lerFases()
        self._lerCorps()
        self._lerPapel()

    def _lerSuporte(self):
        """Recursos que só dá para descobrir pelo texto de uso (só leitura: o "cor --help" sai com
        código 2 antes de tomar a trava)."""
        if getattr(self, "_suporteLido", False):
            return
        self._suporteLido = True

        def fim(codigo, saida, erro):
            novo = "--secundaria" in (saida + erro)
            if novo != self._suporteSecundaria:
                self._suporteSecundaria = novo
                self.corpsMudou.emit()
        self._processo(["cor", "--help"], fim)

    def _lerStatus(self):
        def fim(codigo, saida, erro):
            dados = json_da_saida(saida)
            if codigo == 0 and dados is not None:
                self._status = dados
                self._statusOk = True
                self._lerCascata(dados)
                self._temaLigado = bool(dados.get("ligado"))
            else:
                self._statusOk = False
                self._log("erro", "log.statusFalhou", codigo=codigo)
            self._deduzirCorp()
            self.statusMudou.emit()
            self.paletaMudou.emit()
        self._processo(["status", "--json"], fim)

    def _lerFases(self):
        def fim(codigo, saida, erro):
            dados = json_da_saida(saida)
            if codigo == 0 and dados and isinstance(dados.get("fases"), list):
                self._suporteFases = True
                self._fasesCli = dados["fases"]
                if "temaLigado" in dados:
                    self._temaLigado = bool(dados["temaLigado"])
                # Registro de uma versão antiga do tema: o CLI não sabe de qual fase veio cada
                # chave, então "ligada" não é confiável e "off <fase>" é recusado.
                self._registroPorFase = dados.get("registroPorFase") is not False
                self._lerCascata(dados)
            else:
                if self._suporteFases or self._fasesCli is None:
                    self._log("aviso", "log.fasesSemSuporte")
                self._suporteFases = False
                self._registroPorFase = True
                self._fasesCli = [{"id": i, "grupo": g, "ligada": None, "precisaSudo": i == "login",
                                   "disponivel": True, "opcional": False} for i, g in FASES_EXEMPLO]
            self._recomporFases()
        self._processo(["fases", "--json"], fim)

    # ---------------------------------------------------------------- efeitos (seção Efeitos)
    def _lerEfeitos(self):
        def fimJanelas(codigo, saida, erro):
            dados = json_da_saida(saida)
            ok = codigo == 0 and isinstance(dados, dict) and isinstance(dados.get("variantes"), list)
            self._fxJanelasCli = dados if ok else None
            self._recomporEfeitos()

        inicio = time.monotonic()

        def fimLista(codigo, saida, erro):
            dados = json_da_saida(saida)
            ok = codigo == 0 and isinstance(dados, dict) and isinstance(dados.get("efeitos"), list)
            self._leituraInicio = inicio
            self._suporteFxLista = ok
            self._fxListaCli = dados["efeitos"] if ok else None
            self._fxListaGrupos = dados.get("grupos") if ok else None
            self._recomporEfeitos()
        self._processo(["efeito", "janelas", "--lista", "--json"], fimJanelas)
        self._processo(["efeito", "--lista", "--json"], fimLista)

    def _texto(self, d, campo):
        """d[campo] no idioma atual (campo_en no inglês, com o PT-BR de reserva)."""
        if self._idioma == "en" and d.get(campo + "_en"):
            return d[campo + "_en"]
        return d.get(campo) or d.get(campo + "_en") or ""

    def _recomporEfeitos(self):
        # ---- janelas: catálogo do CLI → arquivo da Rachael → exemplo; estado só do CLI
        cli = self._fxJanelasCli
        fonte, cat = "exemplo", None
        if cli:
            fonte, cat = "cli", cli["variantes"]
        else:
            try:
                bruto = json.loads(VARIANTES_ARQUIVO.read_text())
                cat = bruto.get("variantes") if isinstance(bruto, dict) else bruto
                if isinstance(cat, list) and cat:
                    fonte = "arquivo"
                else:
                    cat = None
            except (OSError, ValueError):
                cat = None
        if cat is None:
            cat = [{"id": i, "nome": n, "nome_en": ne, "descricao": d, "descricao_en": de, "abrir": True,
                    "fechar": True, "duracaoAbrir": da, "duracaoFechar": df, "estilo": i}
                   for i, n, ne, d, de, da, df in VARIANTES_EXEMPLO]
        variantes = []
        for v in cat:
            if not isinstance(v, dict) or not v.get("id"):
                continue
            vid = str(v["id"])

            def previa(lado):
                for nome in (f"{vid}-{lado}.webp", f"{vid}-{lado}.gif", f"{vid}.webp"):
                    f = PREVIAS_JANELAS / nome
                    if f.is_file():
                        return url_local(f)
                return ""
            variantes.append({
                "id": vid, "nome": self._texto(v, "nome") or vid, "descricao": self._texto(v, "descricao"),
                "abrir": v.get("abrir", True) is not False, "fechar": v.get("fechar", True) is not False,
                "duracaoAbrir": int(v.get("duracaoAbrir") or 280), "duracaoFechar": int(v.get("duracaoFechar") or 200),
                "previaAbrir": previa("abrir"), "previaFechar": previa("fechar"),
                "estilo": v.get("estilo") or ESTILO_PREVIA.get(vid, vid), "referencia": v.get("referencia") or "",
            })
        atual = {}
        if cli:
            atual = next((cli[k] for k in ("estado", "atual") if isinstance(cli.get(k), dict)), cli)

        def inteiro(chave, padrao):
            try:
                return int(atual.get(chave, padrao))
            except (TypeError, ValueError):
                return padrao
        # "nenhuma" ao abrir: o efeito aceita (PEDIDO.md da Rachael), mas só é oferecido quando o CLI
        # o anuncia em efeito --lista (opção "abrir", "valores"); sem CLI, a galeria de exemplo o mostra
        abrirNenhuma = not cli
        for e in self._fxListaCli or []:
            if isinstance(e, dict) and e.get("id") == "janelas":
                for o in e.get("opcoes") or []:
                    if isinstance(o, dict) and o.get("id") == "abrir" and "nenhuma" in (o.get("valores") or []):
                        abrirNenhuma = True
        self._fxJanelas = {
            "suporte": bool(cli), "fonte": fonte, "variantes": variantes, "abrirNenhuma": abrirNenhuma,
            "abrir": str(atual.get("abrir") or ""), "fechar": str(atual.get("fechar") or ""),
            "duracaoAbrir": inteiro("duracaoAbrir", 0), "duracaoFechar": inteiro("duracaoFechar", 0),
            "intensidade": inteiro("intensidade", 60),   # padrão do efeito (PEDIDO.md da Rachael)
            "primeiraVez": str(atual.get("primeiraVez") or ""),
            "duracaoPrimeiraVez": inteiro("duracaoPrimeiraVez", 0),
            "primeiraVezDisponivel": atual.get("primeiraVezDisponivel") is True,
            "suportePrimeiraVez": any(isinstance(o, dict) and o.get("id") == "primeira-vez"
                                      for e in self._fxListaCli or [] if isinstance(e, dict) and e.get("id") == "janelas"
                                      for o in e.get("opcoes") or []),
            "disponivel": atual.get("disponivel") if isinstance(atual.get("disponivel"), bool) else None,
        }
        # ---- demais efeitos (SYS.CONFIG): normalizados para o QML montar cada um pelo tipo
        # Valores enviados saem só quando chega uma leitura que COMEÇOU depois do fim da última operação
        # daquele efeito (uma leitura antiga, atrasada, não confirma nada).
        pendentes = {op["alvo"] for op in self._fila} | ({self._atual["alvo"]} if self._atual else set())
        inicio = getattr(self, "_leituraInicio", 0)
        for eid in list(self._enviados):
            fim = self._fimOpEfeito.get(eid)
            if "fx:" + eid not in pendentes and fim is not None and inicio > fim:
                del self._enviados[eid]
        lista = [self._normalizarEfeito(e) for e in self._fxListaCli or [] if isinstance(e, dict) and e.get("id")]
        self._fxGrupos = self._montarGrupos(lista)
        self._fxMovimento = next((e for e in lista if e["id"] == "movimento"), None)
        self._seguirMovimento()
        self._fxLista = lista
        self.efeitosMudou.emit()

    # Grupos da SYS.CONFIG, na ordem da tela. Os nomes vêm do CLI ("grupos" do efeito --lista); o grupo
    # "estilo" (opções de interface) e os de reserva têm nome no catálogo do painel.
    ORDEM_GRUPOS = ("janelas", "terminal", "interface", "estilo", "area-de-trabalho", "login", "sistema")

    def _montarGrupos(self, lista):
        nomes = {}
        for g in (self._fxListaGrupos or []):
            if isinstance(g, dict) and g.get("id"):
                nomes[g["id"]] = self._texto(g, "nome")
        ids = list(self.ORDEM_GRUPOS) + [e["grupo"] for e in lista if e["grupo"] not in self.ORDEM_GRUPOS]
        grupos = []
        for gid in dict.fromkeys(ids):
            membros = [e for e in lista if e["grupo"] == gid and e["id"] != "movimento"]
            if not membros:
                continue
            nome = nomes.get(gid) or (self._t(f"cfg.grupo.{gid}") if self._tem(f"cfg.grupo.{gid}") else gid.replace("-", " ").capitalize())
            grupos.append({"id": gid, "nome": nome, "total": len(membros),
                           "personalizados": sum(1 for e in membros if e["mudado"])})
        return grupos

    def _url(self, caminho):
        if not caminho or not isinstance(caminho, str):
            return ""
        f = Path(caminho) if os.path.isabs(caminho) else REPO / caminho
        return url_local(f) if f.is_file() else ""

    def _valoresOpcao(self, o):
        vals = []
        brutos = []
        for v in o.get("valores") or o.get("escolhas") or []:
            # lista dentro da lista ([["cair","subir"]], F5 de docs/interno/validacao.md): achata
            brutos.extend(v) if isinstance(v, list) else brutos.append(v)
        for v in brutos:
            if isinstance(v, dict) and v.get("id") is not None:
                sons = [{"evento": x.get("evento") or "", "nome": self._nomeSom(x.get("evento") or ""),
                         "arquivo": self._arquivoSom(x.get("previaSom"))}
                        for x in v.get("sons") or [] if isinstance(x, dict)]
                vals.append({"id": str(v["id"]), "nome": self._texto(v, "nome") or str(v["id"]),
                             "descricao": self._texto(v, "descricao"), "previa": self._url(v.get("previa")),
                             "som": self._arquivoSom(v.get("previaSom")), "sons": [x for x in sons if x["arquivo"]]})
            elif isinstance(v, (str, int)):
                vid = str(v)
                nome = self._t("comum.ligado") if vid == "on" else self._t("comum.desligado") if vid == "off" else vid
                vals.append({"id": vid, "nome": nome, "descricao": "", "previa": ""})
        return vals

    # ---------------------------------------------------------------- prévia de sons
    SONS_EXT = (".ogg", ".oga", ".wav", ".flac")

    def _arquivoSom(self, caminho):
        """Caminho de um som de prévia, só se for um arquivo de áudio dentro do projeto (o painel não
        toca arquivo arbitrário vindo de fora)."""
        if not caminho or not isinstance(caminho, str):
            return ""
        f = Path(caminho) if os.path.isabs(caminho) else REPO / caminho
        try:
            f = f.resolve()
            f.relative_to(REPO.resolve())
        except (OSError, ValueError):
            return ""
        return str(f) if f.is_file() and f.suffix.lower() in self.SONS_EXT else ""

    def _nomeSom(self, evento):
        chave = f"som.evento.{evento}"
        return self._t(chave) if self._tem(chave) else evento.replace("-", " ")

    @pyqtSlot(str)
    def tocarSom(self, arquivo):
        """Toca uma prévia em volume baixo (30%), só por clique. Sem QtMultimedia no PyQt6 daqui:
        pw-play (PipeWire) ou, sem ele, paplay. Um som novo interrompe o anterior."""
        arquivo = self._arquivoSom(arquivo)
        if not arquivo:
            return
        self.pararSom()
        if shutil.which("pw-play"):
            prog, args = "pw-play", ["--volume", "0.3", arquivo]
        elif shutil.which("paplay"):
            prog, args = "paplay", ["--volume=19661", arquivo]     # 65536 × 0,3
        else:
            self.notificar.emit("aviso", self._t("som.semPlayer"))
            return
        p = QProcess(self)
        p.finished.connect(lambda *_: self._somAcabou(p))
        p.start(prog, args)
        self._somProc = p
        self._somAtual = arquivo
        self.somMudou.emit()

    def _somAcabou(self, p):
        if getattr(self, "_somProc", None) is p:
            self._somProc = None
            self._somAtual = ""
            self.somMudou.emit()
        p.deleteLater()

    @pyqtSlot()
    def pararSom(self):
        p = getattr(self, "_somProc", None)
        if p is not None and p.state() != QProcess.ProcessState.NotRunning:
            p.kill()

    @pyqtProperty(str, notify=somMudou)
    def somTocando(self):
        return getattr(self, "_somAtual", "")

    def _normalizarEfeito(self, e):
        """Um efeito do "efeito --lista --json" no formato que os cartões da SYS.CONFIG entendem.
        Aceita as variações reais: estado em "estado" (valores, "opcoes" ou "grupos" dentro dele),
        variantes no nível do efeito (estilo-*) ou em opções, valores como objetos ou strings."""
        eid = e["id"]
        est = e.get("estado") if isinstance(e.get("estado"), dict) else {}
        estOpc = est.get("opcoes") if isinstance(est.get("opcoes"), dict) else {}
        estGrp = est.get("grupos") if isinstance(est.get("grupos"), dict) else {}
        opcoes, mudado = [], False
        for o in e.get("opcoes") or []:
            if not isinstance(o, dict) or not o.get("id"):
                continue
            oid = o["id"]
            tipo = o.get("tipo")
            vals = self._valoresOpcao(o)
            if tipo == "inteiro":
                forma = "inteiro"
            elif tipo == "liga" or (len(vals) == 2 and {v["id"] for v in vals} in ({"on", "off"}, {"true", "false"})):
                forma = "liga"
            else:
                forma = "previas" if any(v["previa"] for v in vals) else "escolha"
            chave_estado = {"primeira-vez": "primeiraVez", "duracao-abrir": "duracaoAbrir",
                            "duracao-fechar": "duracaoFechar"}.get(oid, oid)
            atual = est.get(chave_estado, estOpc.get(oid, estGrp.get(oid, o.get("valor"))))
            if oid in self._enviados.get(eid, {}):
                atual = self._enviados[eid][oid]     # enviado e ainda não confirmado por leitura nova
            if forma == "liga" and isinstance(atual, bool):
                atual = "on" if atual else "off"
            if atual is not None and vals and str(atual) not in {v["id"] for v in vals}:
                # estado em outra forma (ex.: areas.numero 0 = "off")
                if str(atual) in ("0", "false", "False") and "off" in {v["id"] for v in vals}:
                    atual = "off"
            padrao = o.get("padrao")
            if forma == "liga" and isinstance(padrao, bool):
                padrao = "on" if padrao else "off"
            if atual is not None and padrao is not None and str(atual) != str(padrao):
                mudado = True
            opcoes.append({"id": oid, "nome": self._texto(o, "nome") or oid, "forma": forma, "valores": vals,
                           "valor": "" if atual is None else str(atual), "padrao": "" if padrao is None else str(padrao),
                           "min": o.get("min", 0), "max": o.get("max", 100), "passo": o.get("passo", 1),
                           "unidade": o.get("unidade") or ""})
        variantes = []
        for v in e.get("variantes") or []:
            if isinstance(v, dict) and v.get("id"):
                variantes.append({"id": str(v["id"]), "nome": self._texto(v, "nome") or v["id"],
                                  "descricao": self._texto(v, "descricao"), "previa": self._url(v.get("previa")),
                                  "corp": v.get("corp") or ""})
        variante = str(est.get("variante", e.get("variante")) or "")
        padraoVar = str(est.get("padrao") or "")
        if variantes and variante and padraoVar and variante != padraoVar:
            mudado = True
        tipo = "liga" if e.get("tipo") == "liga" else "variante"
        ligado = est.get("ligado", e.get("ligado"))
        if tipo == "liga" and isinstance(est.get("escolhido"), bool):
            mudado = mudado or est.get("escolhido")
        sudo = bool(e.get("precisaSudo")) or eid == "login"
        texto = (self._texto(e, "nome") + " " + self._texto(e, "descricao") + " " +
                 " ".join(o["nome"] + " " + " ".join(v["nome"] for v in o["valores"]) for o in opcoes) + " " +
                 " ".join(v["nome"] for v in variantes))
        return {
            "id": eid, "grupo": e.get("grupo") or "sistema", "nome": self._texto(e, "nome") or eid,
            "descricao": self._texto(e, "descricao"), "tipo": tipo, "ligado": ligado is True,
            "previa": self._url(e.get("previa")), "opcoes": opcoes, "variantes": variantes,
            "variante": variante, "padraoVariante": padraoVar, "definido": est.get("definido") is True,
            "sudo": sudo, "mudado": bool(mudado),
            "disponivel": est.get("disponivel") if isinstance(est.get("disponivel"), bool) else (
                e.get("disponivel") if isinstance(e.get("disponivel"), bool) else None),
            "aviso": self._texto(e, "aviso"),
            "especial": eid if eid in ("janelas", "konsole-cascata") else "",
            # sintaxe vinda do CLI (PEDIDOS-AO-CLI.md, 12): modelo de comando ou forma por opção
            "cliComando": e.get("comando") if isinstance(e.get("comando"), (str, list)) else "",
            "cliForma": e.get("forma") if isinstance(e.get("forma"), dict) else {},
            "retomar": e.get("retomar") or est.get("retomar") or "",
            "busca": self.normalizar(texto),
        }

    @pyqtProperty("QVariantList", notify=efeitosMudou)
    def fxGrupos(self):
        return self._fxGrupos

    @pyqtProperty("QVariantMap", notify=efeitosMudou)
    def fxMovimento(self):
        return self._fxMovimento or {}

    def _seguirMovimento(self):
        """Sem escolha própria no painel, o "reduzir animações" segue o movimento do tema."""
        if self._prefs.get("reduzirAnimacoes") is not None or not self._fxMovimento:
            return
        nivel = next((o["valor"] for o in self._fxMovimento["opcoes"] if o["id"] == "nivel"), "")
        if nivel:
            self.prefsMudou.emit()

    def _nivelMovimento(self):
        m = self._fxMovimento
        return next((o["valor"] for o in m["opcoes"] if o["id"] == "nivel"), "") if m else ""

    # Como cada efeito recebe as escolhas no CLI. Sem o campo "comando" do CLI (PEDIDOS-AO-CLI.md, 12),
    # vale esta regra: liga → on|off; uma opção só → valor posicional; "icones" → grupo=valor;
    # "areas" → número posicional e o resto em --flag; estilo-* → --variante e --<opção>; demais → --flag.
    POSICIONAL_PRIMEIRA = ("areas",)

    @pyqtSlot(str, "QVariantMap")
    @pyqtSlot(str, "QVariantMap", "QVariantMap")
    def aplicarOpcoes(self, eid, mudancas, atuais=None):
        """mudancas: {"ligado": bool} | {"variante": id} | {"<opção>": valor} (só o que mudou).
        atuais: os valores que a interface mostra agora (o cartão manda), para as opções que vão no
        comando sem ter mudado (posicional obrigatório). Sem eles, valem os já enviados ao CLI e ainda
        não confirmados pelo estado; por último, o estado lido."""
        e = next((x for x in self._fxLista if x["id"] == eid), None)
        if not e or not mudancas:
            return
        enviados = self._enviados.setdefault(eid, {})

        def valor_atual(o):
            if atuais and atuais.get(o["id"]) not in (None, ""):
                return str(atuais[o["id"]])
            if o["id"] in enviados:
                return enviados[o["id"]]
            return o["valor"]
        args = ["efeito", eid]
        m = dict(mudancas)
        resumo = []
        if "ligado" in m:
            args.append("on" if m.pop("ligado") else "off")
            resumo.append(self._t("comum.ligar") if args[-1] == "on" else self._t("comum.desligar"))
        if "variante" in m and e["variantes"]:      # variante do efeito (estilo-*), não uma opção "variante"
            v = m.pop("variante")
            if v == "__padrao__":
                args.append("off")
                resumo.append(self._t("cfg.padrao"))
            else:
                args += ["--variante", v]
                resumo.append(next((x["nome"] for x in e["variantes"] if x["id"] == v), v))
        ops = [o for o in e["opcoes"] if o["id"] in m]
        forma = e.get("cliForma") or {}
        if isinstance(forma.get("opcoes"), dict):
            # forma vinda do CLI: {"liga": bool, "opcoes": {id: "posicional"|"flag"|"igual"}}.
            # Posicionais vêm primeiro, na ordem das opções; um posicional obrigatório no "comando"
            # (fora de [ ]) vai com o valor atual mesmo sem mudar.
            fo = forma["opcoes"]
            modelo = e.get("cliComando") if isinstance(e.get("cliComando"), str) else ""
            opcionais = " ".join(re.findall(r"\[[^\]]*\]", modelo))
            for o in e["opcoes"]:
                if fo.get(o["id"]) != "posicional":
                    continue
                obrig = ("{" + o["id"] + "}") in modelo and ("{" + o["id"] + "}") not in opcionais
                if o["id"] in m:
                    args.append(str(m[o["id"]]))
                elif obrig and valor_atual(o) != "":
                    args.append(valor_atual(o))
            for o in ops:
                f = fo.get(o["id"], "flag")
                if f == "posicional":
                    continue
                val = str(m[o["id"]])
                args += [f"{o['id']}={val}"] if f in ("igual", "par") else [f"--{o['id']}", val]
        elif eid == "icones":
            args += [f"{o['id']}={m[o['id']]}" for o in ops]
        else:
            unica = len(e["opcoes"]) == 1 and not e["variantes"]
            for o in ops:
                val = str(m[o["id"]])
                if unica or (eid in self.POSICIONAL_PRIMEIRA and o["id"] == e["opcoes"][0]["id"]):
                    args.append(val)
                else:
                    args += [f"--{o['id']}", val]
        for o in ops:
            v = str(m[o["id"]])
            nome_v = next((x["nome"] for x in o["valores"] if x["id"] == v), None)
            if nome_v is None:
                nome_v = self._t("comum.ligado") if v in ("on", "true") else self._t("comum.desligado") if v in ("off", "false") else v
            resumo.append(f"{o['nome']}: {nome_v}")
        for o in e["opcoes"]:
            if o["id"] in m:
                enviados[o["id"]] = str(m[o["id"]])
        sudo = (e.get("retomar") or self._cmdTerminal("on", "login")) if e["sudo"] else None
        self._enfileirar(("rot.cfg", {"nome": e["nome"], "resumo": ", ".join(resumo)}), args + ["--json"],
                         alvo="fx:" + eid, progresso=False, sudo=sudo)
        self._recomporEfeitos()     # a lista já mostra o valor enviado (até a leitura nova confirmar)
        if eid == "movimento" and "nivel" in mudancas:
            # o movimento do tema também comanda o "reduzir animações" do painel
            self.reduzirAnimacoes = str(mudancas["nivel"]) != "completo"

    @pyqtProperty("QVariantMap", notify=efeitosMudou)
    def fxJanelas(self):
        return self._fxJanelas

    @pyqtProperty("QVariantList", notify=efeitosMudou)
    def fxLista(self):
        return self._fxLista

    @pyqtProperty(bool, notify=efeitosMudou)
    def suporteFxLista(self):
        return self._suporteFxLista

    @pyqtSlot(str, str, int, int, int)
    @pyqtSlot(str, str, int, int, int, str, int)
    def aplicarJanelas(self, abrir, fechar, durAbrir, durFechar, intensidade, primeira="", durPrimeira=0):
        """cyberkde efeito janelas --abrir id --fechar id|nenhuma --duracao-abrir ms --duracao-fechar ms
        --intensidade N --json (o KWin recarrega o efeito; vale para as próximas janelas)."""
        if not self._fxJanelas["suporte"]:
            self.notificar.emit("aviso", self._t("fx.janelas.semSuporte"))
            return
        args = ["efeito", "janelas"]
        if abrir:
            args += ["--abrir", abrir]   # id ou "nenhuma"
        if fechar:
            args += ["--fechar", fechar]
        # 0 = a duração da própria variante ("padrao" no CLI)
        if abrir != "nenhuma":
            args += ["--duracao-abrir", str(durAbrir) if durAbrir > 0 else "padrao"]
        if fechar != "nenhuma":
            args += ["--duracao-fechar", str(durFechar) if durFechar > 0 else "padrao"]
        if primeira and self._fxJanelas.get("suportePrimeiraVez"):
            args += ["--primeira-vez", primeira]
            if primeira != "nenhuma":
                args += ["--duracao-primeira-vez", str(durPrimeira) if durPrimeira > 0 else "padrao"]
        args += ["--intensidade", str(max(0, min(100, intensidade))), "--json"]
        nomes = {v["id"]: v["nome"] for v in self._fxJanelas["variantes"]}
        nomes["nenhuma"] = self._t("fx.nenhuma")
        rotulo = ("rot.fxJanelas", {"abrir": nomes.get(abrir, abrir or "—"),
                                    "fechar": self._t("fx.nenhuma") if fechar == "nenhuma" else nomes.get(fechar, fechar or "—")})
        self._enfileirar(rotulo, args, alvo="janelas", progresso=False)

    @pyqtSlot(str, result=str)
    def normalizar(self, texto):
        """Minúsculas e sem acentos (a busca da SYS.CONFIG compara assim)."""
        import unicodedata
        return "".join(c for c in unicodedata.normalize("NFD", texto.lower()) if unicodedata.category(c) != "Mn")

    def _lerCascata(self, dados):
        """Estado do efeito em "efeitos": {"konsoleCascata": {...}} (status ou fases --json)."""
        ef = dados.get("efeitos") if isinstance(dados, dict) else None
        c = ef.get("konsoleCascata") or ef.get("konsole-cascata") if isinstance(ef, dict) else None
        if not isinstance(c, dict):
            return
        try:
            linhas = max(2, min(20, int(c.get("linhas", 5))))
        except (TypeError, ValueError):
            linhas = 5
        novo = {"suporte": True, "ligado": bool(c.get("ligado")), "linhas": linhas,
                "cores": "tema" if c.get("cores") == "tema" else "video",
                "disponivel": c.get("disponivel") if isinstance(c.get("disponivel"), bool) else None,
                # o Konsole que o próximo "on konsole-anim" escolheria já tem o efeito
                "disponivelAoReligar": c.get("disponivelAoReligar") is True}
        if novo != self._cascata:
            self._cascata = novo
            self.cascataMudou.emit()

    @pyqtProperty("QVariantMap", notify=cascataMudou)
    def cascata(self):
        return self._cascata

    @pyqtSlot(bool, int, str)
    def ajustarCascata(self, ligar, linhas, cores):
        """cyberkde efeito konsole-cascata on|off --linhas N --cores video|tema --json. Só grava as
        chaves do konsolerc (sem trava, sem sudo); o Konsole animado aplica sozinho."""
        if not self._cascata["suporte"]:
            self.notificar.emit("aviso", self._t("cascata.semSuporte"))
            return
        linhas = max(2, min(20, int(linhas)))
        cores = "tema" if cores == "tema" else "video"

        def depois(codigo, resultado):
            if codigo == 0:
                self._lerCascata({"efeitos": {"konsoleCascata": dict(self._cascata, **{
                    k: resultado[k] for k in ("ligado", "linhas", "cores", "disponivel", "disponivelAoReligar") if k in resultado})}})
                if resultado.get("disponivel") is False and ligar:
                    self.notificar.emit("aviso", self._t("cascata.indisponivelAviso"))
        rotulo = ("rot.cascataOn" if ligar else "rot.cascataOff", {"linhas": linhas, "cores": self._t(f"cascata.cores.{cores}")})
        self._enfileirar(rotulo, ["efeito", "konsole-cascata", "on" if ligar else "off",
                                  "--linhas", str(linhas), "--cores", cores, "--json"],
                         alvo="konsole-cascata", progresso=False, depois=depois)

    def _recomporFases(self):
        """Fases no idioma atual: campos *_en do CLI no inglês; faltando, o catálogo pelo id; no
        PT-BR, o que o CLI manda (ou o catálogo, para os dados de exemplo)."""
        en = self._idioma == "en"
        fases = []
        for f in self._fasesCli or []:
            fid, gid = f.get("id", ""), f.get("grupo") or ""

            def campo(nome, chave):
                if en and f.get(nome + "_en"):
                    return f[nome + "_en"]
                if (en or not f.get(nome)) and self._tem(chave):
                    return self._t(chave)
                return f.get(nome) or self._t(chave)
            fases.append(dict(
                f,
                nome=campo("nome", f"fase.{fid}.nome") if (f.get("nome") or self._tem(f"fase.{fid}.nome")) else fid,
                descricao=campo("descricao", f"fase.{fid}.descricao") if (f.get("descricao") or self._tem(f"fase.{fid}.descricao")) else "",
                grupo=(f.get("grupoNome_en") if en else f.get("grupoNome")) or (
                    self._t(f"grupo.{gid}") if self._tem(f"grupo.{gid}") or gid in ("apps", "janelas", "sistema", "login") else (gid or self._t("grupo.outras")).capitalize()),
                ligada=f.get("ligada") if self._registroPorFase else None,
            ))
        self._fases = fases
        self.fasesMudou.emit()

    def _recomporCorps(self):
        if not self._corps and not self._doCli and not self._tokens:
            return
        self._corps = [self._completarCorp(c["id"]) for c in self._corps]
        self._especiais = {cid: self._completarCorp(cid) for cid in ESPECIAIS_RESERVA}
        self.corpsMudou.emit()

    def _lerCorps(self):
        def fim(codigo, saida, erro):
            dados = json_da_saida(saida)
            self._tokens = ler_tokens_corps()
            if codigo == 0 and dados and isinstance(dados.get("corps"), list):
                self._suporteCorp = True
                doCli = {c.get("id"): c for c in dados["corps"] if isinstance(c, dict)}
                self._corpAtualCli = dados.get("atual")
            else:
                if self._suporteCorp or not self._corps:
                    self._log("aviso", "log.corpsSemSuporte")
                self._suporteCorp = False
                doCli = {}
                self._corpAtualCli = None
            self._doCli = doCli
            # Quais corporações existem: as do CLI (é ele quem aplica); sem ele, as do tokens; sem
            # nenhum dos dois, a reserva.
            if doCli:
                ids = [i for i in doCli if i and i not in ESPECIAIS_RESERVA]
            elif self._tokens:
                ids = [i for i in self._tokens if i not in ESPECIAIS_RESERVA]
            else:
                ids = list(ORDEM_RESERVA)
            self._corps = [self._completarCorp(cid) for cid in ids]
            # "nenhuma" vem na lista do CLI; no painel ela é o cartão "Padrão", à parte.
            self._especiais = {cid: self._completarCorp(cid) for cid in ESPECIAIS_RESERVA}
            self._deduzirCorp()
            self.corpsMudou.emit()
        self._processo(["corp", "--lista", "--json"], fim)

    def _completarCorp(self, cid):
        """Junta, campo a campo, o que vem do CLI, do tokens/corporacoes.json e da reserva."""
        c = self._doCli.get(cid) or {}
        t = self._tokens.get(cid) or {}
        r = CORPS_RESERVA.get(cid) or ESPECIAIS_RESERVA.get(cid) or {
            "nome": cid.title(), "lema": "", **{k: ESPECIAIS_RESERVA["nenhuma"][k] for k in CAMPOS_PALETA}}
        paleta = {}
        for k in CAMPOS_PALETA:
            cli = c.get(k) or (c.get("cor") if k == "destaque" else None)
            tok = t.get(k) or (t.get("cor") if k == "destaque" else None)
            paleta[k] = hexa(cli, hexa(tok, r[k]))
        largo = icone = ""
        especial = cid in ESPECIAIS_RESERVA
        if not especial:
            largo, icone = self._logos(cid, c, t)
        en = self._idioma == "en"

        def texto(campo):
            """lema/descricao no idioma atual: CLI, tokens, reserva; no inglês, sem tradução, o PT-BR."""
            if en:
                v = c.get(campo + "_en") or t.get(campo + "_en") or r.get(campo + "_en")
                if v:
                    return v
            if cid == "personalizada" and campo == "lema":
                return self._t("lema.personalizada")
            return c.get(campo) or t.get(campo) or r.get(campo, "")
        return {
            "id": cid,
            # "Padrão" e "Personalizada" são nomes de cartão do painel (o CLI chama de "Nenhuma")
            "nome": self._t(f"nome.{cid}") if cid in ESPECIAIS_RESERVA else (c.get("nome") or t.get("nome") or r["nome"]),
            "cor": paleta["destaque"],
            "paleta": paleta,
            "lema": texto("lema"),
            "descricao": texto("descricao"),
            "logo": url_local(largo, self._versaoLogo) if largo else "",     # largo (cartões)
            "icone": url_local(icone, self._versaoLogo) if icone else "",    # quadrado (cabeçalho, miniaturas)
            "iconeRecorte": recorte_opaco(icone) if icone else None,
            "logoDaUsuaria": not especial and (bool(self._logoDaUsuaria(cid)) or c.get("logoDoUsuario") is True),
        }

    def _logos(self, cid, c, t):
        """(largo, ícone) de uma corporação, só caminhos que existem.
        Logo escolhido pela usuária (~/.config/cyberkde/corporacoes) vale para os dois. Largo:
        <id>-logo-escuro.png (versão para fundo escuro), <id>-logo.png; ícone: <id>.svg, <id>-icone.png,
        o logo que o CLI ou o tokens indicarem. Faltando o oficial, o emblema genérico; faltando o
        largo, o ícone."""
        def existe(caminho):
            if not caminho:
                return ""
            f = Path(caminho) if os.path.isabs(caminho) else REPO / caminho
            return str(f) if f.is_file() else ""

        doUsuario = self._logoDaUsuaria(cid)
        if doUsuario:
            return str(doUsuario), str(doUsuario)
        # campos explícitos do CLI/tokens ("icone", "logoLargo"); o "logo" antigo pode ser um ou
        # outro: classifica pelo nome
        indicados = [existe(c.get("logo")), existe(t.get("logo"))]
        explicitos_icone = [existe(c.get("icone")), existe(t.get("icone"))]
        explicitos_largo = [existe(c.get("logoLargo")), existe(t.get("logoLargo"))]
        largos = [f for f in indicados if f and "-logo" in Path(f).name]
        quadrados = [f for f in indicados if f and f not in largos]
        icone = next(filter(None, [
            existe(LOGOS_TEMA / f"{cid}.svg"), existe(LOGOS_TEMA / f"{cid}-icone.svg"),
            existe(LOGOS_TEMA / f"{cid}-icone.png"), existe(LOGOS_TEMA / f"{cid}.png"), *explicitos_icone, *quadrados,
            existe(LOGOS_GENERICOS / f"{cid}.svg"), existe(LOGOS_GENERICOS / f"{cid}.png")]), "")
        largo = next(filter(None, [
            existe(LOGOS_TEMA / f"{cid}-logo-escuro.png"), existe(LOGOS_TEMA / f"{cid}-logo-escuro.svg"),
            existe(LOGOS_TEMA / f"{cid}-logo.png"), existe(LOGOS_TEMA / f"{cid}-logo.svg"),
            *explicitos_largo, *largos]), "") or icone
        return largo, icone

    def _logoDaUsuaria(self, cid):
        for ext in (".svg", ".png"):
            f = LOGOS_USUARIA / f"{cid}{ext}"
            if f.is_file():
                return f
        return None

    def _deduzirCorp(self):
        """Corporação atual: a do CLI quando ele sabe; sem suporte, pela cor."""
        atual = self._status.get("corp") or self._corpAtualCli
        if not atual:
            cor = (self._status.get("cor") or "").upper()
            if not cor or self._status.get("padrao"):
                atual = "nenhuma"
            else:
                atual = next((c["id"] for c in self._corps if c["cor"] == cor), "personalizada")
        if atual != self._corpAtual:
            self._corpAtual = atual
            self.corpsMudou.emit()
        self.paletaMudou.emit()

    def _lerPapel(self):
        def fim(codigo, saida, erro):
            papel = ""
            for linha in saida.splitlines():
                if linha.startswith("Papel de parede:"):
                    valor = linha.split(":", 1)[1].strip()
                    if valor.startswith("/"):
                        papel = valor
            self._papel = papel
            self.papelMudou.emit()
        self._processo(["papel"], fim)

    # ---------------------------------------------------------------- propriedades
    @pyqtProperty("QVariantMap", notify=statusMudou)
    def status(self):
        return self._status

    @pyqtProperty(bool, notify=statusMudou)
    def statusOk(self):
        return self._statusOk

    @pyqtProperty(bool, notify=statusMudou)
    def temaLigado(self):
        return self._temaLigado

    @pyqtProperty(str, notify=statusMudou)
    def corSistema(self):
        """Cor de destaque como aparece no sistema (a aplicada, clareada para leitura)."""
        return self._status.get("corAplicada") or self._status.get("cor") or COR_PADRAO

    @pyqtProperty("QVariantMap", notify=paletaMudou)
    def paleta(self):
        """Paleta em uso no sistema: a da corporação atual, com o que o status trouxer por cima."""
        cid = self._corpAtual
        corp = next((c for c in self._corps if c["id"] == cid), None)
        padrao = self._especiais.get("nenhuma") or {"paleta": {k: ESPECIAIS_RESERVA["nenhuma"][k] for k in CAMPOS_PALETA}}
        p = dict((corp or padrao)["paleta"])
        st = self._status
        doStatus = st.get("paleta") if isinstance(st.get("paleta"), dict) else st
        p["destaque"] = hexa(st.get("cor"), hexa(doStatus.get("destaque"), p["destaque"]))
        for k in ("secundaria", "alerta", "fundo"):
            p[k] = hexa(doStatus.get(k), p[k])
        return p

    @pyqtProperty("QVariantMap", notify=corpsMudou)
    def especiais(self):
        """Cartões "personalizada" e "nenhuma" (Padrão): nome, lema e paleta."""
        return self._especiais

    @pyqtProperty(bool, notify=corpsMudou)
    def suporteSecundaria(self):
        return self._suporteSecundaria

    @pyqtProperty("QVariantList", constant=True)
    def paletaKit(self):
        return paleta_do_kit()

    @pyqtProperty(bool, notify=fasesMudou)
    def registroPorFase(self):
        return self._registroPorFase

    @pyqtProperty("QVariantMap", notify=desfazerMudou)
    def desfazer(self):
        """Estado de antes da última troca de corporação/cor aplicada pelo painel ({} se nenhuma)."""
        return self._desfazer

    @pyqtProperty("QVariantList", notify=fasesMudou)
    def fases(self):
        return self._fases

    @pyqtProperty(bool, notify=fasesMudou)
    def suporteFases(self):
        return self._suporteFases

    @pyqtProperty("QVariantList", notify=corpsMudou)
    def corps(self):
        return self._corps

    @pyqtProperty(str, notify=corpsMudou)
    def corpAtual(self):
        return self._corpAtual

    @pyqtProperty(bool, notify=corpsMudou)
    def suporteCorp(self):
        return self._suporteCorp

    @pyqtProperty(str, notify=corpsMudou)
    def logoAtual(self):
        """Logo da corporação em uso (o status do CLI manda; sem ele, o da lista)."""
        if self._status.get("corpLogo") and os.path.isfile(self._status["corpLogo"]):
            return url_local(self._status["corpLogo"], self._versaoLogo)
        c = next((c for c in self._corps if c["id"] == self._corpAtual), None)
        return c["icone"] if c else ""

    @pyqtSlot(str, result=str)
    def contorno(self, url):
        """URL do "circuito" (wireframe) de um logo, gerado sob demanda e guardado em cache."""
        if not url:
            return ""
        caminho = QUrl(url).toLocalFile() if url.startswith("file:") else url
        gerado = gerar_contorno(caminho)
        return url_local(gerado) if gerado else ""

    @pyqtProperty("QVariant", notify=corpsMudou)
    def recorteAtual(self):
        """Área opaca do logo em uso (ver recorte_opaco); None se não houver."""
        if self._status.get("corpLogo") and os.path.isfile(self._status["corpLogo"]):
            return recorte_opaco(self._status["corpLogo"])
        c = next((c for c in self._corps if c["id"] == self._corpAtual), None)
        return c.get("iconeRecorte") if c else None

    @pyqtProperty(bool, notify=filaMudou)
    def ocupado(self):
        return self._atual is not None

    @pyqtProperty(str, notify=filaMudou)
    def operacao(self):
        return self._t(*self._atual["rotulo"]) if self._atual else ""

    @pyqtProperty(str, notify=filaMudou)
    def alvo(self):
        """Fase ou corporação da operação em andamento (para a interface marcar o cartão)."""
        return self._atual["alvo"] if self._atual else ""

    @pyqtProperty("QVariantList", notify=filaMudou)
    def alvosNaFila(self):
        return [op["alvo"] for op in self._fila if op["alvo"]]

    @pyqtProperty("QVariantMap", notify=progressoMudou)
    def progresso(self):
        return self._progresso

    @pyqtProperty(str, notify=papelMudou)
    def papel(self):
        return url_local(self._papel) if self._papel else ""

    @pyqtProperty(str, notify=papelMudou)
    def papelCaminho(self):
        return self._papel

    @pyqtProperty("QVariantList", notify=idiomaMudou)
    def papeisDoTema(self):
        pasta = REPO / "assets" / "wallpapers"
        return [{"nome": self._t(f"papel.{f.stem}") if self._tem(f"papel.{f.stem}") else f.stem, "url": url_local(f)}
                for f in sorted(pasta.glob("*.png"))]

    @pyqtProperty("QVariantMap", notify=diagnosticoMudou)
    def diagnostico(self):
        return self._diag

    @pyqtProperty(bool, notify=prefsMudou)
    def reduzirAnimacoes(self):
        escolha = self._prefs.get("reduzirAnimacoes")
        if escolha is None and self._nivelMovimento():
            return self._nivelMovimento() != "completo"
        if escolha is None:
            # Sem escolha no painel, segue o KDE: AnimationDurationFactor 0 desliga as animações.
            return fator_animacao_kde() == 0
        return bool(escolha)

    @reduzirAnimacoes.setter
    def reduzirAnimacoes(self, valor):
        if bool(valor) == self.reduzirAnimacoes:
            return
        self._prefs["reduzirAnimacoes"] = bool(valor)
        self._salvarPrefs()
        self.prefsMudou.emit()

    def _salvarPrefs(self):
        try:
            CONFIG.mkdir(parents=True, exist_ok=True)
            tmp = PREFS.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._prefs, indent=2, ensure_ascii=False) + "\n")
            tmp.replace(PREFS)
        except OSError as e:
            self._log("erro", "log.erroPrefs", arquivo=str(PREFS), erro=str(e))

    @pyqtProperty(str, constant=True)
    def binario(self):
        return self._bin

    @pyqtProperty(str, constant=True)
    def logoReserva(self):
        """Marca do painel, usada sem corporação (Personalizada ou Padrão); o QML tinge na cor de destaque."""
        return url_local(APP_DIR / "cyberkde-painel.svg")

    # ---------------------------------------------------------------- ações
    def _cmdTerminal(self, *args):
        """Comando que a usuária roda no terminal para completar a parte com sudo."""
        no_path = shutil.which("cyberkde")
        mesmo = no_path and os.path.realpath(no_path) == os.path.realpath(self._bin)
        return " ".join([("cyberkde" if mesmo else shlex.quote(self._bin)), *args])

    @pyqtSlot()
    def ligarTema(self):
        self._enfileirar(("rot.ligarTema", {}), ["on", "--json", "--progresso", "--sem-sudo"], alvo="tema",
                         sudo=self._cmdTerminal("on"))

    @pyqtSlot()
    def desligarTema(self):
        # CLIs antigos ignoram as opções do "off" completo (e desligam do mesmo jeito); os novos
        # respondem com PROGRESSO e uma linha JSON.
        self._enfileirar(("rot.desligarTema", {}), ["off", "--json", "--progresso"], alvo="tema")

    @pyqtSlot(str, bool)
    def alternarFase(self, fase, ligar):
        if ligar:
            self._enfileirar(("rot.ligarFase", {"fase": fase}), ["on", fase, "--json", "--progresso", "--sem-sudo"],
                             alvo=fase, sudo=self._cmdTerminal("on", fase))
        elif self._suporteFases and not self._registroPorFase:
            self._log("aviso", "log.registroAntigoFase", fase=fase)
            self.notificar.emit("aviso", self._t("notif.registroAntigo"))
        elif self._suporteFases:
            self._enfileirar(("rot.desligarFase", {"fase": fase}), ["off", fase, "--json", "--progresso", "--sem-sudo"],
                             alvo=fase, sudo=self._cmdTerminal("off", fase))
        else:
            # Sem suporte, "cyberkde off <fase>" ignora a fase e desliga o tema INTEIRO: não chamar.
            self._log("aviso", "log.semSuporteOffFase", fase=fase)
            self.notificar.emit("aviso", self._t("notif.semSuporteOffFase"))

    def _instantaneo(self):
        """Estado atual de corporação/cor, para o "desfazer"."""
        cid = self._corpAtual
        p = self.paleta
        if any(c["id"] == cid for c in self._corps):
            nome = next((c["nome"] for c in self._corps if c["id"] == cid), cid)
            return {"tipo": "corp", "id": cid, "nome": nome, "cor": p["destaque"], "secundaria": "",
                    "paleta": p, "logo": self.logoAtual}
        if cid == "personalizada":
            return {"tipo": "cor", "id": "personalizada", "nome": self._t("nome.personalizada"), "cor": p["destaque"],
                    "secundaria": p["secundaria"], "paleta": p, "logo": ""}
        return {"tipo": "corp", "id": "nenhuma", "nome": self._t("nome.nenhuma"), "cor": p["destaque"], "secundaria": "",
                "paleta": p, "logo": ""}

    def _aoConcluirTroca(self, antes):
        def depois(codigo, resultado):
            if codigo in (0, 4) and antes:
                self._desfazer = antes
                self._prefs["desfazer"] = antes
                self._salvarPrefs()
                self.desfazerMudou.emit()
        return depois

    @pyqtSlot(str)
    def aplicarCorp(self, corp):
        antes = self._instantaneo()
        nome = next((c["nome"] for c in self._corps if c["id"] == corp), corp)
        if self._suporteCorp:
            self._enfileirar(("rot.corp", {"nome": nome}), ["corp", corp, "--json", "--progresso", "--sem-sudo"],
                             alvo=corp, sudo=self._cmdTerminal("corp", corp), depois=self._aoConcluirTroca(antes))
            return
        # Sem o "corp" no CLI: aplica só a cor, pelo "cor" que já existe. O logo do menu fica para depois.
        if corp == "nenhuma":
            self._aplicarCor("padrao", "nenhuma", "", antes)
            return
        cor = next((c["cor"] for c in self._corps if c["id"] == corp), None)
        if cor:
            self._log("aviso", "log.corpSoCor", nome=nome, cor=cor)
            self._aplicarCor(cor, corp, "", antes)

    @pyqtSlot(str, str)
    @pyqtSlot(str, str, str)
    def aplicarCor(self, cor, alvo="personalizada", secundaria=""):
        self._aplicarCor(cor, alvo, secundaria, self._instantaneo())

    def _aplicarCor(self, cor, alvo, secundaria, antes):
        rotulo = ("rot.corPadrao", {}) if cor == "padrao" else ("rot.cor", {"cor": cor.upper()})
        args = ["cor", cor]
        termo = ["cor", f"'{cor}'" if cor != "padrao" else "padrao"]
        if secundaria and self._suporteSecundaria and cor != "padrao":
            args += ["--secundaria", secundaria]
            termo += ["--secundaria", f"'{secundaria}'"]
            rotulo = ("rot.corSec", {"cor": cor.upper(), "sec": secundaria.upper()})
        self._enfileirar(rotulo, args + ["--json", "--progresso", "--sem-sudo"], alvo=alvo,
                         sudo=self._cmdTerminal(*termo), depois=self._aoConcluirTroca(antes))

    @pyqtSlot()
    def desfazerTroca(self):
        d = self._desfazer
        if not d:
            return
        self._log("info", "log.desfazer", nome=d.get("nome", ""))
        if d.get("tipo") == "cor":
            self.aplicarCor(d.get("cor", ""), "personalizada", d.get("secundaria") or "")
        else:
            self.aplicarCorp(d.get("id", "nenhuma"))

    @pyqtSlot(str)
    def escolherPapel(self, url):
        caminho = QUrl(url).toLocalFile() if url.startswith("file:") else url
        self._papelComando(caminho)

    @pyqtSlot()
    def papelPadrao(self):
        self._papelComando("padrao")

    def _papelComando(self, valor):
        def depois(codigo, resultado):
            if codigo == 0 and self._temaLigado:
                self._enfileirar(("rot.aplicarPapel", {}),
                                 ["on", "papeis-de-parede", "--json", "--progresso", "--sem-sudo"],
                                 alvo="papeis-de-parede", sudo=self._cmdTerminal("on", "papeis-de-parede"))
        rotulo = ("rot.papelTema", {}) if valor == "padrao" else ("rot.papel", {"arquivo": Path(valor).name})
        self._enfileirar(rotulo, ["papel", valor], alvo="papel", progresso=False, depois=depois)

    @pyqtSlot()
    def checar(self):
        if self._diag["rodando"]:
            return
        self._diag = {"rodando": True, "codigo": -1, "itens": self._diag["itens"], "hora": ""}
        self.diagnosticoMudou.emit()
        self._log("info", "log.diagInicio")

        def fim(codigo, saida, erro):
            itens = self._itensChecarJson(json_da_saida(saida))
            if itens is not None:
                self._diag = {"rodando": False, "codigo": codigo, "itens": itens, "hora": agora()}
                self._log("ok" if codigo == 0 else "aviso", "log.diagFim", codigo=codigo, linhas=len(itens))
                self.diagnosticoMudou.emit()
                return
            itens = []
            for linha in (saida + "\n" + erro).splitlines():
                limpa = linha.strip()
                if not limpa or limpa.startswith("PROGRESSO"):
                    continue
                nivel = {"✗": "impede", "!": "corrigir", "·": "aviso", "✓": "ok"}.get(limpa[0])
                if nivel and limpa[1:2] == " ":
                    itens.append({"nivel": nivel, "texto": limpa[2:], "correcao": []})
                elif linha.startswith("      ") and itens:
                    itens[-1]["correcao"].append(limpa)
                else:
                    itens.append({"nivel": "texto", "texto": limpa, "correcao": []})
            self._diag = {"rodando": False, "codigo": codigo, "itens": itens, "hora": agora()}
            self._log("ok" if codigo == 0 else "aviso", "log.diagFim", codigo=codigo, linhas=len(itens))
            self.diagnosticoMudou.emit()
        # "--json" é ignorado por um CLI antigo (que responde em texto, lido acima)
        self._processo(["checar", "--json"], fim)

    def _itensChecarJson(self, dados):
        """checar --json -> itens do Diagnóstico, ou None se a resposta não for JSON. Aceita
        {"itens":[...]} ou {"problemas":[...]}, com nivel (impede|corrigir|aviso|ok), texto (ou
        texto_en no inglês) e correcao (lista ou texto)."""
        if not isinstance(dados, dict):
            return None
        lista = dados.get("itens", dados.get("problemas"))
        if not isinstance(lista, list):
            return None
        en = self._idioma == "en"
        itens = []
        for i in lista:
            if not isinstance(i, dict):
                continue
            texto = (en and i.get("texto_en")) or i.get("texto") or i.get("mensagem") or ""
            corr = (en and i.get("correcao_en")) or i.get("correcao") or i.get("comandos") or []
            if isinstance(corr, str):
                corr = [corr]
            nivel = i.get("nivel") if i.get("nivel") in ("impede", "corrigir", "aviso", "ok") else "aviso"
            itens.append({"nivel": nivel, "texto": texto, "correcao": [str(c) for c in corr]})
        return itens

    @pyqtSlot(str, str)
    def escolherLogo(self, corp, url):
        """Copia a imagem escolhida para ~/.config/cyberkde/corporacoes/<corp>.svg|png."""
        origem = Path(QUrl(url).toLocalFile() if url.startswith("file:") else url)
        if not any(c["id"] == corp for c in self._corps) or not origem.is_file():
            self.notificar.emit("erro", self._t("notif.imagemNaoEncontrada"))
            return
        try:
            LOGOS_USUARIA.mkdir(parents=True, exist_ok=True)
            ext = origem.suffix.lower()
            if ext == ".svg":
                destino = LOGOS_USUARIA / f"{corp}.svg"
                shutil.copyfile(origem, destino)
            else:
                img = QImage(str(origem))
                if img.isNull():
                    self.notificar.emit("erro", self._t("notif.formatoImagem"))
                    return
                destino = LOGOS_USUARIA / f"{corp}.png"
                if ext == ".png":
                    shutil.copyfile(origem, destino)
                elif not img.save(str(destino), "PNG"):
                    raise OSError("falha ao converter para PNG")
            # Um só arquivo por corporação, para não haver dúvida de qual vale.
            for outro in (LOGOS_USUARIA / f"{corp}.svg", LOGOS_USUARIA / f"{corp}.png"):
                if outro != destino and outro.exists():
                    outro.unlink()
        except OSError as e:
            self.notificar.emit("erro", self._t("notif.erroCopiarLogo", erro=str(e)))
            return
        self._log("ok", "log.logoCopiado", corp=corp, origem=str(origem), destino=str(destino))
        self._logoTrocado(corp)

    @pyqtSlot(str)
    def removerLogo(self, corp):
        if not any(c["id"] == corp for c in self._corps):
            return
        for f in (LOGOS_USUARIA / f"{corp}.svg", LOGOS_USUARIA / f"{corp}.png"):
            if f.exists():
                f.unlink()
        self._log("ok", "log.logoRemovido", corp=corp)
        self._logoTrocado(corp)

    def _logoTrocado(self, corp):
        self._versaoLogo += 1
        self._corps = [self._completarCorp(c["id"]) for c in self._corps]
        self.corpsMudou.emit()
        if corp == self._corpAtual:
            self.notificar.emit("info", self._t("notif.logoTrocadoAtual"))
        else:
            self.notificar.emit("ok", self._t("notif.logoTrocado"))


def carregar_fontes():
    pasta = REPO / "assets" / "fonts"
    for f in sorted(pasta.glob("*.ttf")):
        if QFontDatabase.addApplicationFont(str(f)) < 0:
            print(f"aviso: fonte não carregada: {f}", file=sys.stderr)


def montar(argv=None):
    """Cria app, backend e janela (separado do main para roteiros de teste)."""
    ap = argparse.ArgumentParser(description="Painel do CyberKDE")
    ap.add_argument("--sem-boot", action="store_true", help="pula a abertura")
    ap.add_argument("--secao", type=int, default=0, help="seção inicial (0 a 5: status, corporação, config, papel, diagnóstico, registro)")
    ap.add_argument("--captura", help="salva a janela neste PNG e sai (para testes)")
    ap.add_argument("--espera", type=int, default=2500, help="ms antes da captura")
    ap.add_argument("--largura", type=int, default=0)
    ap.add_argument("--altura", type=int, default=0)
    ap.add_argument("--previa", default="", help="(testes) corporação em prévia, como se o mouse estivesse no cartão")
    args = ap.parse_args(argv)

    QGuiApplication.setApplicationName("cyberkde-painel")
    QGuiApplication.setApplicationDisplayName("Painel do CyberKDE")
    QGuiApplication.setDesktopFileName("cyberkde-painel")
    app = QGuiApplication(sys.argv)
    carregar_fontes()

    binario = os.environ.get("CYBERKDE_BIN") or str(REPO / "scripts" / "cyberkde")
    painel = Painel(binario)
    app.setWindowIcon(QIcon(str(APP_DIR / "cyberkde-painel.svg")))

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("painel", painel)
    ctx.setContextProperty("opcoes", {
        "semBoot": args.sem_boot or bool(args.captura and args.secao),
        "secao": args.secao,
        "largura": args.largura,
        "altura": args.altura,
        "previa": args.previa,
    })
    engine.load(QUrl.fromLocalFile(str(APP_DIR / "qml" / "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    janela = engine.rootObjects()[0]
    painel.atualizar()
    return app, engine, janela, painel, args


def main():
    app, engine, janela, painel, args = montar()
    if args.captura:
        def capturar():
            try:
                janela.grabWindow().save(args.captura)
                print(args.captura)
            finally:
                app.quit()
        QTimer.singleShot(args.espera, capturar)

    codigo = app.exec()
    # Fecha o QML antes do backend: sem isso, as ligações leem "painel" já destruído na saída.
    del janela
    sip.delete(engine)
    sys.exit(codigo)


if __name__ == "__main__":
    main()
