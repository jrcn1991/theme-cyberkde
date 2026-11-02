"""Objeto principal exposto ao QML como `arquivos` (spec 14.1): abas, locais, fila de operações,
área de transferência, detalhes, prévia, propriedades, abrir/abrir com, paleta e idioma."""

import grp
import json
import os
import pwd
import secrets
import shutil
import stat
import sys
import time
from pathlib import Path

from PyQt6.QtCore import (QFileSystemWatcher, QMimeData, QMimeDatabase, QObject, QProcess, Qt, QTimer, QUrl,
                          pyqtProperty, pyqtSignal, pyqtSlot)
from PyQt6.QtGui import QGuiApplication

from . import apps as A
from . import desfazer as D
from . import lote as LT
from . import modelos as MD
from . import servicos as SV
from . import tags as T
from . import itens as I
from . import lixeira as L
from . import locais as LC
from . import operacoes as O
from .aba import LIXEIRA, RECENTES, Aba
from .tarefas import rodar
from .tema import Tema, carregar_catalogos, dir_config, idioma_padrao

PREFS = "arquivos.json"
VALIDADE_FICHA = 60.0
LIMITE_TEXTO = 256 * 1024
_LINGUAGENS = {".py": "python", ".js": "javascript", ".ts": "typescript", ".qml": "qml", ".sh": "bash",
               ".json": "json", ".rs": "rust", ".c": "c", ".h": "c", ".cpp": "cpp", ".hpp": "cpp", ".go": "go",
               ".java": "java", ".kt": "kotlin", ".html": "html", ".css": "css", ".md": "markdown",
               ".yml": "yaml", ".yaml": "yaml", ".toml": "toml", ".xml": "xml", ".sql": "sql", ".gd": "gdscript",
               ".lua": "lua", ".rb": "ruby", ".php": "php", ".cs": "csharp", ".ini": "ini", ".conf": "ini"}


def _uris(lista):
    return [QUrl.fromLocalFile(c) for c in lista]


def _local(uri):
    if isinstance(uri, QUrl):
        return uri.toLocalFile() if uri.isLocalFile() else ""
    uri = str(uri).strip()
    if uri.startswith("file:"):
        return QUrl(uri).toLocalFile()
    return uri if uri.startswith("/") else ""


def _bonito(caminho):
    home = str(Path.home())
    return "~" + caminho[len(home):] if caminho == home or caminho.startswith(home + "/") else caminho


def _dono_grupo(st):
    try:
        u = pwd.getpwuid(st.st_uid).pw_name
    except KeyError:
        u = str(st.st_uid)
    try:
        g = grp.getgrgid(st.st_gid).gr_name
    except KeyError:
        g = str(st.st_gid)
    return u, g


def _propriedades(_tarefa, caminho, idioma, modelo_conteudo="{arquivos} · {pastas}"):
    """Roda numa thread: inclui o tamanho recursivo das pastas."""
    st = os.lstat(caminho)
    alvo = os.stat(caminho) if os.path.exists(caminho) else st
    u, g = _dono_grupo(alvo)
    mt = QMimeDatabase().mimeTypeForFile(caminho)
    eh_pasta = stat.S_ISDIR(alvo.st_mode)
    res = {
        "grupo": I.grupo_de("inode/directory" if eh_pasta else mt.name(), eh_pasta, bool(alvo.st_mode & 0o111)),
        "nome": os.path.basename(caminho) or caminho, "caminho": caminho, "pasta": os.path.dirname(caminho),
        "mime": mt.name(), "tipo": mt.comment(), "ehPasta": stat.S_ISDIR(alvo.st_mode),
        "ehLink": stat.S_ISLNK(st.st_mode), "alvoLink": os.readlink(caminho) if stat.S_ISLNK(st.st_mode) else "",
        "dono": u, "grupoDono": g, "modo": f"{stat.S_IMODE(alvo.st_mode):03o}", "permissoes": I.permissoes(alvo.st_mode),
        "modificado": I.data_texto(alvo.st_mtime), "acessado": I.data_texto(alvo.st_atime),
        "alterado": I.data_texto(alvo.st_ctime), "modificadoTexto": I.data_texto(alvo.st_mtime),
        "acessadoTexto": I.data_texto(alvo.st_atime), "pastaPai": os.path.dirname(caminho),
        "local": _bonito(os.path.dirname(caminho)), "codigo": I.codigo(st.st_ino, st.st_dev),
        "inode": st.st_ino, "gravavel": os.access(caminho, os.W_OK),
    }
    try:
        res["criado"] = I.data_texto(os.stat(caminho).st_birthtime)   # Python 3.12+ com statx
    except (AttributeError, OSError):
        res["criado"] = ""
    res["criadoTexto"] = res["criado"] or res["alterado"]   # sem data de criação: a da última mudança de inode
    if res["ehPasta"]:
        total = arqs = pastas = 0
        for raiz, dirs, nomes in os.walk(caminho):
            if _tarefa.cancelada():
                break
            pastas += len(dirs)
            for n in nomes:
                try:
                    total += os.lstat(os.path.join(raiz, n)).st_size
                except OSError:
                    pass
            arqs += len(nomes)
        res.update(tamanho=total, arquivos=arqs, pastas=pastas)
    else:
        res.update(tamanho=st.st_size, arquivos=1, pastas=0)
    res["tamanhoTexto"] = I.tamanho_texto(res["tamanho"], idioma)
    res["tamanhoRecursivoTexto"] = res["tamanhoTexto"]
    res["conteudo"] = modelo_conteudo.format(arquivos=res["arquivos"], pastas=res["pastas"]) if res["ehPasta"] else ""
    # disco
    try:
        sv = os.statvfs(caminho if res["ehPasta"] else os.path.dirname(caminho))
        tot, livre = sv.f_blocks * sv.f_frsize, sv.f_bavail * sv.f_frsize
        res.update(totalTexto=I.tamanho_texto(tot, idioma), livreTexto=I.tamanho_texto(livre, idioma),
                   uso=round(1 - livre / tot, 3) if tot else 0)
    except OSError:
        res.update(totalTexto="", livreTexto="", uso=0)
    res.update(discoTotal=res["totalTexto"], discoLivre=res["livreTexto"], discoUso=res["uso"])   # nomes antigos
    mnt = os.path.realpath(caminho)
    while not os.path.ismount(mnt) and mnt != "/":
        mnt = os.path.dirname(mnt)
    res["montagem"] = mnt
    return res


ATALHOS_PADRAO = {
    "desfazer": "Ctrl+Z", "duplicar": "Ctrl+D", "copiar": "Ctrl+C", "recortar": "Ctrl+X", "colar": "Ctrl+V",
    "selecionarTudo": "Ctrl+A", "inverterSelecao": "Ctrl+Shift+A", "selecionarPorPadrao": "Ctrl+S",
    "renomear": "F2", "lixeira": "Del", "apagar": "Shift+Del", "novaPasta": "Ctrl+Shift+N", "novoArquivo": "Ctrl+Alt+N",
    "propriedades": "Alt+Return", "busca": "Ctrl+F", "filtro": "Ctrl+I", "caminho": "Ctrl+L", "novaAba": "Ctrl+T",
    "fecharAba": "Ctrl+W", "proximaAba": "Ctrl+Tab", "abaAnterior": "Ctrl+Shift+Tab", "novaJanela": "Ctrl+N",
    "dividir": "F3", "terminal": "F4", "recarregar": "F5", "copiarOutroLado": "Shift+F5", "moverOutroLado": "Shift+F6",
    "locais": "F9", "painelLog": "F11", "ocultos": "Ctrl+H", "visaoPilhas": "Ctrl+1", "visaoLista": "Ctrl+2",
    "visaoGrade": "Ctrl+3", "zoomMais": "Ctrl++", "zoomMenos": "Ctrl+-", "zoomPadrao": "Ctrl+0", "voltar": "Alt+Left",
    "avancar": "Alt+Right", "subir": "Alt+Up", "home": "Alt+Home", "previa": "Space", "copiarCaminho": "Ctrl+Alt+C",
    "agruparTipos": "Ctrl+G",
}


def _propriedades_varias(tarefa, lista, idioma):
    """Propriedades de vários itens: totais recursivos e o que é comum (modo, dono, grupo, tipo)."""
    tot = arqs = pastas = 0
    modos, donos, grupos, tipos = set(), set(), set(), set()
    db = QMimeDatabase()
    for c in lista:
        try:
            st = os.lstat(c)
        except OSError:
            continue
        u, g = _dono_grupo(st)
        donos.add(u)
        grupos.add(g)
        modos.add(f"{stat.S_IMODE(st.st_mode):03o}")
        tipos.add("inode/directory" if stat.S_ISDIR(st.st_mode) else db.mimeTypeForFile(c, QMimeDatabase.MatchMode.MatchExtension).name())
        if stat.S_ISDIR(st.st_mode):
            pastas += 1
            for raiz, dirs, nomes in os.walk(c):
                if tarefa.cancelada():
                    break
                pastas += len(dirs)
                arqs += len(nomes)
                for n in nomes:
                    try:
                        tot += os.lstat(os.path.join(raiz, n)).st_size
                    except OSError:
                        pass
        else:
            arqs += 1
            tot += st.st_size
    um = lambda conj: next(iter(conj)) if len(conj) == 1 else ""   # noqa: E731 — "" = misto
    return {"quantidade": len(lista), "arquivos": arqs, "pastas": pastas, "tamanho": tot,
            "tamanhoTexto": I.tamanho_texto(tot, idioma), "modo": um(modos), "dono": um(donos),
            "grupoDono": um(grupos), "mime": um(tipos), "misto": {"modo": len(modos) > 1, "dono": len(donos) > 1,
                                                                  "grupoDono": len(grupos) > 1, "mime": len(tipos) > 1}}


class Arquivos(QObject):
    notificar = pyqtSignal(str, str, arguments=["nivel", "texto"])
    propriedadesProntas = pyqtSignal(str, "QVariantMap", arguments=["caminho", "mapa"])
    operacaoTerminou = pyqtSignal(int, str, str, "QVariantList", arguments=["id", "estado", "texto", "criados"])
    itemCriado = pyqtSignal(str, arguments=["caminho"])
    pedirPropriedades = pyqtSignal(str, arguments=["caminho"])   # D-Bus ShowItemProperties: o QML abre o modal
    pastaEscolhida = pyqtSignal(str, str, arguments=["proposito", "caminho"])
    desfazerMudou = pyqtSignal()
    propriedadesVariasProntas = pyqtSignal("QVariantMap", arguments=["mapa"])
    confirmacaoNecessaria = pyqtSignal(str, "QVariantMap", arguments=["acao", "mapa"])
    preferenciasMudou = pyqtSignal()
    abasMudou = pyqtSignal()
    locaisMudou = pyqtSignal()
    operacoesMudou = pyqtSignal()
    areaMudou = pyqtSignal()
    paletaMudou = pyqtSignal()
    idiomaMudou = pyqtSignal()

    def __init__(self, caminho_inicial="", parent=None):
        super().__init__(parent)
        self._prefs = self._lerPrefs()
        self._catalogos = carregar_catalogos()
        self._idioma = self._prefs.get("idioma") or idioma_padrao()
        self._tema = Tema(self)
        self._tema.mudou.connect(self.paletaMudou.emit)
        self._fichas = {}
        self._props = None
        self._extrairPendente = ""
        self.pastaEscolhida.connect(self._pastaParaExtrair)
        self.pastaEscolhida.connect(self._pastaParaCopiar)
        self._dispositivos = []
        self._qtdLixeira = L.quantidade()
        self._assinatura = None
        self._falsos = LC.dispositivos_falsos()
        self._registrarIconesXdg()

        self._fila = O.Fila(self.t, lambda: self._idioma, self)
        self._fila.mudou.connect(self.operacoesMudou.emit)
        self._fila.terminouOp.connect(self._opTerminou)
        self._fila.registrada.connect(self._registrarDesfazer)
        self._desfazer = D.Pilha()
        self._pares = {}          # id(aba principal) -> Aba do lado direito (divisão F3)
        self._ladoDireito = {}    # id(aba principal) -> bool (lado ativo)
        self._servicosCache = None

        self._abas = []
        self._abaAtual = 0
        self.novaAba(caminho_inicial or str(Path.home()))

        clip = QGuiApplication.clipboard()
        if clip is not None:
            clip.dataChanged.connect(self.areaMudou.emit)

        # locais: lixeira e recentes por observador; discos por verificação barata a cada 3 s
        self._obs = QFileSystemWatcher(self)
        self._obs.directoryChanged.connect(self._lixeiraMudou)
        self._obs.fileChanged.connect(self._recentesMudou)
        self._vigiarLocais()
        self._relogioDiscos = QTimer(self, interval=3000)
        self._relogioDiscos.timeout.connect(self._verificarDiscos)
        self._relogioDiscos.start()
        self._verificarDiscos()

    # ================================================================== utilidades
    def t(self, chave, **kw):
        texto = self._catalogos.get(self._idioma, {}).get(chave)
        if texto is None:
            texto = self._catalogos.get("pt_BR", {}).get(chave, chave)
        if kw:
            try:
                texto = texto.format(**kw)
            except (KeyError, IndexError, ValueError):
                pass
        return texto

    @pyqtSlot(str, result=str)
    def tr(self, chave):   # alias de t() para o QML
        return self.t(chave)

    def _lerPrefs(self):
        try:
            return json.loads((dir_config() / PREFS).read_text())
        except (OSError, ValueError):
            return {}

    def _gravarPrefs(self):
        arq = dir_config() / PREFS
        try:
            arq.parent.mkdir(parents=True, exist_ok=True)
            tmp = arq.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._prefs, ensure_ascii=False, indent=1))
            os.replace(tmp, arq)
        except OSError:
            pass

    def lembrarPrefs(self, valores):
        aba = self._prefs.setdefault("aba", {})
        if any(aba.get(k) != v for k, v in valores.items()):
            aba.update(valores)
            self._gravarPrefs()

    def _registrarIconesXdg(self):
        I.registrar_icones_xdg({c: ic for c, ic in LC.pastas_xdg()})

    def _pastaAtual(self):
        return self.aba.pasta_real() if self.aba else None

    # ================================================================== abas
    @pyqtProperty("QVariantList", notify=abasMudou)
    def abas(self):
        return list(self._abas)

    @pyqtProperty(QObject, notify=abasMudou)
    def aba(self):
        """A aba do painel ATIVO (com a tela dividida, o lado em foco)."""
        if not self._abas:
            return None
        prim = self._abas[self._abaAtual]
        par = self._pares.get(id(prim))
        return par if par is not None and self._ladoDireito.get(id(prim)) else prim

    @pyqtProperty(int, notify=abasMudou)
    def abaAtual(self):
        return self._abaAtual

    @abaAtual.setter
    def abaAtual(self, i):
        i = int(i)
        if 0 <= i < len(self._abas) and i != self._abaAtual:
            self._abaAtual = i
            self.abasMudou.emit()

    @pyqtSlot(result=int)
    @pyqtSlot(str, result=int)
    def novaAba(self, caminho=""):
        if not caminho:
            caminho = self.aba.caminho if self._abas else str(Path.home())
        aba = Aba(self, caminho, self._prefs.get("aba", {}), self)
        self._abas.append(aba)
        self._abaAtual = len(self._abas) - 1
        self.abasMudou.emit()
        return self._abaAtual

    def mostrar(self, caminhos, reusar=False):
        """Abre pastas e itens vindos de fora (linha de comando, D-Bus): cada pasta numa aba (a que já
        mostra a pasta é reaproveitada); arquivos abrem a pasta deles com eles selecionados. `reusar`:
        o primeiro grupo vai para a aba atual. Devolve o número de pastas abertas."""
        grupos = {}
        for c in caminhos:
            c = _local(c) or ""
            if not c or not os.path.lexists(c):
                continue
            c = os.path.normpath(os.path.abspath(c))
            if os.path.isdir(c) and not os.path.islink(c):
                grupos.setdefault(c, [])
            else:
                grupos.setdefault(os.path.dirname(c), []).append(c)
        for k, (pasta, itens) in enumerate(grupos.items()):
            i = next((n for n, a in enumerate(self._abas) if a.caminho == pasta), -1)
            if i < 0:
                i = self._abaAtual if (reusar and k == 0) else self.novaAba(pasta)
            self._abas[i].focar(pasta, itens)
            if i != self._abaAtual:
                self._abaAtual = i
                self.abasMudou.emit()
        return len(grupos)

    def estado(self):
        return {"abas": [a.caminho for a in self._abas], "atual": self._abaAtual,
                "selecionados": self.aba.selecionados if self.aba else []}

    @pyqtSlot(int)
    def fecharAba(self, i):
        if not 0 <= i < len(self._abas):
            return
        if len(self._abas) == 1:
            self._abas[0].irPara(str(Path.home()))
            return
        aba = self._abas.pop(i)
        if self._abaAtual >= len(self._abas) or self._abaAtual > i:
            self._abaAtual = max(0, self._abaAtual - 1)
        par = self._pares.pop(id(aba), None)
        self._ladoDireito.pop(id(aba), None)
        self.abasMudou.emit()
        for a in (aba, par):
            if a is not None:
                a.fechar()
                a.deleteLater()

    # ================================================================== tema e idioma
    @pyqtProperty("QVariantMap", notify=paletaMudou)
    def paleta(self):
        return dict(self._tema.paleta)

    @pyqtProperty(str, notify=paletaMudou)
    def movimento(self):
        return self._tema.movimento

    @pyqtProperty(bool, notify=paletaMudou)
    def reduzir(self):
        return self._tema.movimento != "completo"

    def _setIdioma(self, v):
        v = "en" if str(v).lower().startswith("en") else "pt_BR"
        if v != self._idioma:
            self._idioma = v
            self._prefs["idioma"] = v
            self._gravarPrefs()
            self.idiomaMudou.emit()
            self.locaisMudou.emit()
            for a in self._abas:
                a.idioma_mudou()

    idioma = pyqtProperty(str, fget=lambda self: self._idioma, fset=_setIdioma, notify=idiomaMudou)

    @pyqtProperty("QVariantMap", notify=idiomaMudou)
    def textos(self):
        base = dict(self._catalogos.get("pt_BR", {}))
        base.update(self._catalogos.get(self._idioma, {}))
        return base

    @pyqtProperty("QVariantMap", constant=True)
    def compactadores(self):
        tem7z = bool(shutil.which("7z"))
        return {"zip": True, "7z": tem7z, "targz": bool(shutil.which("tar")), "extrair": tem7z or bool(shutil.which("tar"))}

    @pyqtProperty(str, constant=True)
    def terminal(self):
        return A.comando_terminal()

    # ================================================================== locais
    def _vigiarLocais(self):
        alvos = [str(lx / "files") for lx, _ in L.lixeiras()]
        rec = LC.dir_dados() / "recently-used.xbel"
        if rec.exists():
            alvos.append(str(rec))
        atuais = set(self._obs.files() + self._obs.directories())
        novos = [a for a in alvos if a not in atuais]
        if novos:
            self._obs.addPaths(novos)

    def _lixeiraMudou(self, *_):
        n = L.quantidade()
        if n != self._qtdLixeira:
            self._qtdLixeira = n
            self.locaisMudou.emit()

    def _recentesMudou(self, *_):
        self._vigiarLocais()
        self.locaisMudou.emit()

    def _verificarDiscos(self, forcar=False):
        if self._falsos is not None:   # testes (U29): a lista fictícia, nunca o lsblk real
            if self._dispositivos != self._falsos:
                self._dispositivos = [dict(d) for d in self._falsos]
                self.locaisMudou.emit()
            return
        a = LC.assinatura_montagens()
        if a == self._assinatura and not forcar:
            return
        self._assinatura = a

        def pronto(r):
            if isinstance(r, list) and r != self._dispositivos:
                self._dispositivos = r
                self._vigiarLocais()
                self._lixeiraMudou()
                self.locaisMudou.emit()
        rodar(LC.ler_dispositivos, pronto=pronto)

    @pyqtProperty("QVariantList", notify=locaisMudou)
    def locais(self):
        itens = []
        vistos = set()
        for c, ic in LC.pastas_xdg():
            nome = "HOME" if c == str(Path.home()) else os.path.basename(c)
            itens.append({"nome": nome, "caminho": c, "icone": ic, "codigo": I.codigo_caminho(c), "tipo": "xdg"})
            vistos.add(c)
        favs = []
        for c, titulo, ic in LC.favoritos_dolphin():
            if c not in vistos:
                vistos.add(c)
                favs.append({"nome": titulo, "caminho": c, "icone": ic, "codigo": I.codigo_caminho(c), "tipo": "dolphin"})
        for c in self._prefs.get("locais", []):
            if c not in vistos and os.path.isdir(c):
                vistos.add(c)
                favs.append({"nome": os.path.basename(c) or c, "caminho": c, "icone": "folder-favorites",
                             "codigo": I.codigo_caminho(c), "tipo": "favorito"})
        itens += sorted(favs, key=lambda f: I.chave_natural(f["nome"]))
        discos = []
        for d in self._dispositivos:
            d = dict(d)
            d["tamanhoTexto"] = I.tamanho_texto(d["tamanho"], self._idioma)
            d["livreTexto"] = I.tamanho_texto(d["livre"], self._idioma) if d["livre"] >= 0 else ""
            if d["raiz"]:
                d["nome"] = self.t("locais.sistema")
            discos.append(d)
        rec = []
        for c in LC.recentes(12):
            ehp = os.path.isdir(c)
            rec.append({"nome": os.path.basename(c) or c, "caminho": c, "ehPasta": ehp,
                        "icone": "folder" if ehp else QMimeDatabase().mimeTypeForFile(c, QMimeDatabase.MatchMode.MatchExtension).iconName(),
                        "codigo": I.codigo_caminho(c)})
        return [
            {"secao": "locais", "titulo": self.t("locais.locais"), "itens": itens},
            {"secao": "dispositivos", "titulo": self.t("locais.dispositivos"), "itens": discos},
            {"secao": "recentes", "titulo": self.t("locais.recentes"), "caminho": RECENTES, "itens": rec},
            {"secao": "lixeira", "titulo": self.t("locais.lixeira"), "caminho": LIXEIRA, "itens": [],
             "quantidade": self._qtdLixeira, "cheia": self._qtdLixeira > 0},
        ]

    @pyqtSlot(str)
    def adicionarLocal(self, caminho):
        lst = self._prefs.setdefault("locais", [])
        if os.path.isdir(caminho) and caminho not in lst:
            lst.append(caminho)
            self._gravarPrefs()
            self.locaisMudou.emit()

    @pyqtSlot(str)
    def removerLocal(self, caminho):
        lst = self._prefs.get("locais", [])
        if caminho in lst:
            lst.remove(caminho)
            self._gravarPrefs()
            self.locaisMudou.emit()

    def _udisks(self, verbo, dispositivo, depois=None):
        if self._falsos is not None:
            self._udisksSimulado(verbo, dispositivo, depois)
            return
        if not shutil.which("udisksctl"):
            self.notificar.emit("erro", self.t("erro.semUdisks"))
            return
        if not any(d["dispositivo"] == dispositivo for d in self._dispositivos):
            self.notificar.emit("erro", self.t("erro.dispositivo"))
            return
        proc = QProcess(self)
        self._procsDisco = getattr(self, "_procsDisco", set())
        self._procsDisco.add(proc)

        def fim(codigo, _status):
            self._procsDisco.discard(proc)
            try:
                saida = bytes(proc.readAllStandardOutput()).decode(errors="replace").strip()
                err = bytes(proc.readAllStandardError()).decode(errors="replace").strip()
            except RuntimeError:
                return   # o app está saindo

            if codigo == 0 and depois:
                proc.deleteLater()
                self._udisks(depois, dispositivo)
                return
            if codigo == 0:
                self.notificar.emit("ok", saida or self.t(f"locais.{verbo.replace('-', '')}Ok"))
            else:
                self.notificar.emit("erro", err or saida or self.t("erro.dispositivo"))
            proc.deleteLater()
            self._verificarDiscos(forcar=True)
        proc.finished.connect(fim)
        proc.start("udisksctl", [verbo, "-b", dispositivo])

    def _udisksSimulado(self, verbo, dispositivo, depois=None):
        """Discos fictícios (U29): muda o estado na lista em memória, como se o udisks tivesse feito."""
        d = next((x for x in self._falsos if x["dispositivo"] == dispositivo), None)
        if not d:
            self.notificar.emit("erro", self.t("erro.dispositivo"))
            return
        if verbo == "mount":
            d["caminho"], d["montado"] = d.get("pontoFalso", ""), True
        elif verbo == "unmount":
            d["caminho"], d["montado"] = "", False
        elif verbo == "power-off":
            self._falsos.remove(d)
        self._dispositivos = []
        self._verificarDiscos()
        if depois:
            self._udisksSimulado(depois, dispositivo)
            return
        self.notificar.emit("ok", self.t(f"locais.{verbo.replace('-', '')}Ok"))

    @pyqtSlot(str)
    def montar(self, dispositivo):
        self._udisks("mount", dispositivo)

    @pyqtSlot(str, result=bool)
    def desmontar(self, ficha_ou_dispositivo):
        """Com a ficha de prepararDesmontar(): desmonta. Com o caminho do dispositivo (chamada antiga):
        não desmonta; emite confirmacaoNecessaria("desmontar", mapa) para a interface perguntar."""
        if self._confirmarDisco(ficha_ou_dispositivo, "desmontar"):
            return True
        info = self.prepararDesmontar(ficha_ou_dispositivo)
        if info:
            self.confirmacaoNecessaria.emit("desmontar", info)
        return False

    # ================================================================== detalhes, prévia, propriedades
    def _itemDe(self, caminho):
        if self.aba:
            i = self.aba.indiceDe(caminho)
            if i >= 0:
                return self.aba.item(i)
        return I.ler_item(caminho, None, None, self._idioma)

    @pyqtSlot(str, result="QVariantMap")
    def detalhes(self, caminho):
        it = self._itemDe(caminho)
        if not it:
            return {"nome": os.path.basename(caminho), "caminho": caminho, "codigo": "0x000000", "ehPasta": False,
                    "mime": "", "tipo": "", "icone": "dialog-error", "iconeUrl": I.icone_url("dialog-error"),
                    "miniatura": "", "tamanho": -1, "tamanhoTexto": "", "modificadoTexto": "", "grupo": "outro",
                    "linhas": [{"rotulo": self.t("det.nome"), "valor": self.t("erro.naoExiste")}]}
        try:
            st = os.lstat(caminho)
            dono, grupo = _dono_grupo(st)
        except OSError:
            dono = grupo = "?"
        t = self.t
        linhas = [
            {"rotulo": "SHARD_ID", "valor": it["codigo"]},
            {"rotulo": t("det.nome"), "valor": it["nome"]},
            {"rotulo": t("det.tipo"), "valor": f"{it['mime']} · {it['tipo']}"},
        ]
        if it["ehPasta"]:
            if it["filhos"] >= 0:
                linhas.append({"rotulo": t("det.itens"), "valor": "999+" if it["filhos"] >= 999 else str(it["filhos"])})
        else:
            linhas.append({"rotulo": t("det.tamanho"), "valor": it["tamanhoTexto"] + " (" + f"{it['tamanho']:,}".replace(",", " ") + " B)"})
        linhas.append({"rotulo": t("det.modificado"), "valor": it["modificadoTexto"]})
        linhas.append({"rotulo": t("det.permissoes"), "valor": f"{it['permissoes']} · {dono}:{grupo}"})
        if it["ehLink"]:
            linhas.append({"rotulo": t("det.link"), "valor": it["alvoLink"]})
        if it.get("origem"):
            linhas.append({"rotulo": t("det.origem"), "valor": _bonito(it["origem"])})
            linhas.append({"rotulo": t("det.apagadoEm"), "valor": it["apagadoEm"]})
        else:
            linhas.append({"rotulo": t("det.local"), "valor": _bonito(it["pastaPai"])})
        res = {k: it[k] for k in ("nome", "caminho", "codigo", "ehPasta", "mime", "tipo", "icone", "iconeUrl",
                                  "miniatura", "tamanho", "tamanhoTexto", "modificadoTexto", "grupo")}
        res["linhas"] = linhas
        return res

    @pyqtSlot("QVariantList", result="QVariantMap")
    def detalhesSelecao(self, lista):
        pastas = arqs = tot = 0
        for c in lista:
            it = self._itemDe(c)
            if not it:
                continue
            if it["ehPasta"]:
                pastas += 1
            else:
                arqs += 1
                tot += max(it["tamanho"], 0)
        tt = I.tamanho_texto(tot, self._idioma)
        return {"quantidade": len(lista), "pastas": pastas, "arquivos": arqs, "tamanhoTexto": tt,
                "linhas": [{"rotulo": self.t("det.selecao"), "valor": str(len(lista))},
                           {"rotulo": self.t("det.pastas"), "valor": str(pastas)},
                           {"rotulo": self.t("det.arquivos"), "valor": str(arqs)},
                           {"rotulo": self.t("det.tamanho"), "valor": tt}]}

    @pyqtSlot(str)
    def propriedades(self, caminho):
        if self._props:
            self._props.cancelar()

        def pronto(r):
            if isinstance(r, dict):
                self.propriedadesProntas.emit(caminho, r)
            else:
                self.notificar.emit("erro", str(r))
        self._props = rodar(_propriedades, caminho, self._idioma, self.t("prop.modeloConteudo"), pronto=pronto)

    @pyqtSlot(str, result="QVariantMap")
    def previa(self, caminho):
        it = self._itemDe(caminho)
        if not it:
            return {"tipo": "outro"}
        mime = it["mime"]
        res = {"tipo": "outro", "url": it["url"], "miniatura": it["miniatura"], "texto": "", "linguagem": "",
               "truncado": False, "hex": [], "amostra": [], "largura": 0, "altura": 0, "linhas": 0,
               "nome": it["nome"], "mime": mime}
        if it["ehPasta"]:
            res["tipo"] = "pasta"
            try:
                nomes = sorted(os.listdir(caminho), key=I.chave_natural)[:12]
            except OSError:
                nomes = []
            db = QMimeDatabase()
            for n in nomes:
                sub = I.ler_item(os.path.join(caminho, n), db, None, self._idioma)
                if sub:
                    res["amostra"].append({k: sub[k] for k in ("nome", "iconeUrl", "ehPasta", "codigo")})
            return res
        if mime.startswith("image/"):
            from PyQt6.QtGui import QImageReader
            tam = QImageReader(caminho).size()
            res.update(tipo="imagem", largura=tam.width(), altura=tam.height())
            return res
        if mime.startswith("video/"):
            res["tipo"] = "video"
            return res
        if mime.startswith("audio/"):
            res["tipo"] = "audio"
            return res
        if mime == "application/pdf":
            res["tipo"] = "pdf"
            return res
        try:
            with open(caminho, "rb") as f:
                dados = f.read(LIMITE_TEXTO + 1)
        except OSError as e:
            res["erro"] = str(e)
            return res
        mt = QMimeDatabase().mimeTypeForName(mime)
        eh_texto = mime.startswith("text/") or mt.inherits("text/plain") or it["grupo"] == "codigo"
        if eh_texto or (dados and b"\0" not in dados[:4096] and _parece_texto(dados[:4096])):
            res["truncado"] = len(dados) > LIMITE_TEXTO
            texto = dados[:LIMITE_TEXTO].decode("utf-8", errors="replace")
            ext = os.path.splitext(caminho)[1].lower()
            res.update(tipo="codigo" if it["grupo"] == "codigo" or ext in _LINGUAGENS else "texto", texto=texto,
                       linguagem=_LINGUAGENS.get(ext, ""), linhas=texto.count("\n") + 1)
            return res
        res["tipo"] = "hex"
        res["hex"] = [{"offset": f"{o:08X}", "bytes": [f"{b:02X}" for b in dados[o:o + 16]],
                       "ascii": "".join(chr(b) if 32 <= b < 127 else "·" for b in dados[o:o + 16])}
                      for o in range(0, min(len(dados), 512), 16)]
        return res

    # ================================================================== abrir
    @pyqtSlot(str)
    def abrir(self, caminho):
        if not A.abrir(caminho):
            self.notificar.emit("erro", self.t("erro.abrir"))

    @pyqtSlot(str, result="QVariantList")
    def appsPara(self, caminho):
        return A.apps_para(caminho)

    @pyqtSlot(str, str)
    def abrirCom(self, caminho, ident):
        if not A.abrir_com(caminho, ident):
            self.notificar.emit("erro", self.t("erro.abrir"))

    @pyqtSlot(str)
    def abrirTerminal(self, pasta):
        pasta = pasta or self._pastaAtual() or str(Path.home())
        if not A.abrir_terminal(pasta):
            self.notificar.emit("erro", self.t("erro.terminal"))

    # ================================================================== seletor de pasta
    @pyqtSlot(str, str)
    def escolherPasta(self, inicial, proposito):
        """Abre o seletor de pasta do sistema (kdialog, senão zenity) sem travar a janela; a resposta
        chega em pastaEscolhida(proposito, caminho), com caminho "" se a usuária cancelar."""
        inicial = inicial or self._pastaAtual() or str(Path.home())
        titulo = self.t("pasta.escolher")
        if shutil.which("kdialog"):
            prog, args = "kdialog", ["--title", titulo, "--getexistingdirectory", inicial]
        elif shutil.which("zenity"):
            prog, args = "zenity", ["--file-selection", "--directory", "--title", titulo, "--filename", inicial + "/"]
        else:
            self.notificar.emit("erro", self.t("erro.semSeletor"))
            self.pastaEscolhida.emit(proposito, "")
            return
        proc = QProcess(self)

        def fim(codigo, _status):
            saida = bytes(proc.readAllStandardOutput()).decode(errors="replace").strip()
            proc.deleteLater()
            self.pastaEscolhida.emit(proposito, saida if codigo == 0 and os.path.isdir(saida) else "")
        proc.finished.connect(fim)
        proc.start(prog, args)

    @pyqtSlot(str)
    def extrairPara(self, arquivo):
        """"Extrair para…": pergunta a pasta e enfileira a extração (numa subpasta nova dentro dela)."""
        if not O.eh_compactado(arquivo):
            return
        self._extrairPendente = arquivo
        self.escolherPasta(os.path.dirname(arquivo), "extrair")

    def _pastaParaExtrair(self, proposito, caminho):
        if proposito != "extrair" or not getattr(self, "_extrairPendente", ""):
            return
        arquivo, self._extrairPendente = self._extrairPendente, ""
        if caminho:
            base = os.path.basename(arquivo)
            for suf in sorted(O.SUFIXOS, key=len, reverse=True):
                if base.lower().endswith(suf):
                    base = base[: -len(suf)]
                    break
            destino = os.path.join(caminho, I.nome_livre(caminho, base or "extraido"))
            self.extrair(arquivo, destino)

    # ================================================================== área de transferência
    def _porNaArea(self, lista, recortar):
        lista = [c for c in lista if c and os.path.lexists(c)]
        if not lista:
            return
        md = QMimeData()
        md.setUrls(_uris(lista))
        md.setText("\n".join(lista))
        md.setData("application/x-kde-cutselection", b"1" if recortar else b"0")
        gnome = ("cut" if recortar else "copy") + "\n" + "\n".join(u.toString() for u in _uris(lista))
        md.setData("x-special/gnome-copied-files", gnome.encode())
        QGuiApplication.clipboard().setMimeData(md)
        self.areaMudou.emit()

    @pyqtSlot("QVariantList")
    def copiarArea(self, lista):
        self._porNaArea([str(c) for c in lista], False)

    @pyqtSlot("QVariantList")
    def recortarArea(self, lista):
        self._porNaArea([str(c) for c in lista], True)

    @pyqtSlot("QVariantList")
    def copiarCaminhos(self, lista):
        QGuiApplication.clipboard().setText("\n".join(str(c) for c in lista))

    def _lerArea(self):
        md = QGuiApplication.clipboard().mimeData()
        if md is None:
            return [], False
        caminhos = [u.toLocalFile() for u in md.urls() if u.isLocalFile()]
        recortar = bytes(md.data("application/x-kde-cutselection")).strip() == b"1"
        if not caminhos and md.hasFormat("x-special/gnome-copied-files"):
            linhas = bytes(md.data("x-special/gnome-copied-files")).decode(errors="replace").splitlines()
            if linhas:
                recortar = linhas[0].strip() == "cut"
                caminhos = [QUrl(x).toLocalFile() for x in linhas[1:] if x.startswith("file:")]
        return caminhos, recortar

    @pyqtProperty("QVariantMap", notify=areaMudou)
    def area(self):
        caminhos, recortar = self._lerArea()
        return {"modo": ("recortar" if recortar else "copiar") if caminhos else "", "quantidade": len(caminhos),
                "caminhos": caminhos}

    @pyqtSlot(result=int)
    @pyqtSlot(str, result=int)
    def colar(self, destino=""):
        destino = destino or self._pastaAtual()
        caminhos, recortar = self._lerArea()
        if not caminhos or not destino:
            return -1
        if recortar:
            oid = self.mover(caminhos, destino)
            QGuiApplication.clipboard().clear()   # como o Dolphin: recortar cola uma vez só
            return oid
        return self.copiar(caminhos, destino)

    @pyqtSlot("QVariantList", result=str)
    def urisDe(self, lista):
        return "\r\n".join(u.toString() for u in _uris([str(c) for c in lista])) + "\r\n"

    @pyqtSlot("QVariant", str, str, result=int)
    def soltar(self, uris, destino, acao="auto"):
        if isinstance(uris, str):
            uris = [u for u in uris.replace("\r", "").split("\n") if u and not u.startswith("#")]
        caminhos = [c for c in (_local(u) for u in uris or []) if c]
        if not caminhos or not destino or destino in (LIXEIRA, RECENTES):
            if destino == LIXEIRA and caminhos:
                return self.lixeira(caminhos)
            return -1
        if acao == "auto":
            # o QML não distingue Shift (mover) de "sem modificador": lê o teclado aqui
            mods = QGuiApplication.queryKeyboardModifiers()
            ctrl = bool(mods & Qt.KeyboardModifier.ControlModifier)
            shift = bool(mods & Qt.KeyboardModifier.ShiftModifier)
            if ctrl and shift:
                acao = "link"
            elif shift:
                acao = "mover"
            elif ctrl:
                acao = "copiar"
        if acao == "auto":
            try:
                mesmo = os.lstat(caminhos[0]).st_dev == os.stat(destino).st_dev
            except OSError:
                mesmo = False
            acao = "mover" if mesmo else "copiar"
        if acao == "mover":
            return self.mover(caminhos, destino)
        if acao == "link":
            return self.link(caminhos, destino)
        return self.copiar(caminhos, destino)

    # ================================================================== operações
    def _rotulo(self, chave, lista, destino=""):
        nome = os.path.basename(lista[0].rstrip("/")) if len(lista) == 1 else self.t("op.nItens", n=len(lista))
        return self.t(chave, nome=nome, destino=os.path.basename(destino.rstrip("/")) or destino)

    @pyqtSlot("QVariantList", str, result=int)
    def copiar(self, lista, destino):
        lista = [str(c) for c in lista]
        if not lista:
            return -1
        return self._fila.enfileirar("copiar", self._rotulo("op.copiar", lista, destino), O.copiar_mover, lista, destino, False)

    @pyqtSlot("QVariantList", str, result=int)
    def mover(self, lista, destino):
        lista = [str(c) for c in lista]
        if not lista:
            return -1
        return self._fila.enfileirar("mover", self._rotulo("op.mover", lista, destino), O.copiar_mover, lista, destino, True)

    @pyqtSlot("QVariantList", str, result=int)
    def link(self, lista, destino):
        lista = [str(c) for c in lista]
        return self._fila.enfileirar("link", self._rotulo("op.link", lista, destino), O.ligar, lista, destino) if lista else -1

    @pyqtSlot("QVariantList", result=int)
    def lixeira(self, lista):
        lista = [str(c) for c in lista if not L.eh_da_lixeira(str(c))]
        if not lista:
            return -1
        return self._fila.enfileirar("lixeira", self._rotulo("op.lixeira", lista), O.para_lixeira, lista)

    def _novaFicha(self, tipo, lista):
        agora = time.monotonic()
        self._fichas = {k: v for k, v in self._fichas.items() if v[2] > agora}
        ficha = secrets.token_hex(8)
        self._fichas[ficha] = (tipo, lista, agora + VALIDADE_FICHA)
        return ficha

    def _usarFicha(self, ficha, tipo):
        v = self._fichas.pop(ficha, None)
        if not v or v[0] != tipo or v[2] < time.monotonic():
            return None
        return v[1]

    @pyqtSlot("QVariantList", result="QVariantMap")
    def prepararApagar(self, lista):
        lista = [str(c) for c in lista if os.path.lexists(str(c))]
        if not lista:
            return {}
        tot = 0
        for c in lista:
            tot += os.lstat(c).st_size if not os.path.isdir(c) or os.path.islink(c) else 0
        return {"ficha": self._novaFicha("apagar", lista), "quantidade": len(lista),
                "tamanhoTexto": I.tamanho_texto(tot, self._idioma), "nomes": [os.path.basename(c) for c in lista[:8]]}

    @pyqtSlot(str, result=int)
    def apagarPermanentemente(self, ficha):
        lista = self._usarFicha(ficha, "apagar")
        if not lista:
            self.notificar.emit("aviso", self.t("erro.ficha"))
            return -1
        return self._fila.enfileirar("apagar", self._rotulo("op.apagar", lista), O.apagar, lista)

    @pyqtSlot(result="QVariantMap")
    def prepararEsvaziar(self):
        n = L.quantidade()
        if not n:
            return {}
        return {"ficha": self._novaFicha("esvaziar", []), "quantidade": n, "tamanhoTexto": ""}

    @pyqtSlot(str, result=int)
    def esvaziarLixeira(self, ficha):
        if self._usarFicha(ficha, "esvaziar") is None:
            self.notificar.emit("aviso", self.t("erro.ficha"))
            return -1
        return self._fila.enfileirar("esvaziar", self.t("op.esvaziar"), O.esvaziar)

    @pyqtSlot("QVariantList", result=int)
    def restaurar(self, lista):
        lista = [str(c) for c in lista if L.eh_da_lixeira(str(c))]
        if not lista:
            return -1
        return self._fila.enfileirar("restaurar", self._rotulo("op.restaurar", lista), O.restaurar, lista)

    @pyqtSlot("QVariantList", str, str, result=int)
    def compactar(self, lista, destino, formato):
        lista = [str(c) for c in lista]
        if not lista or formato not in ("zip", "7z", "targz"):
            return -1
        if formato == "7z" and not shutil.which("7z"):
            return -1
        if not destino:
            pai = os.path.dirname(lista[0].rstrip("/"))
            base = os.path.basename(lista[0].rstrip("/")) if len(lista) == 1 else self.t("op.arquivoPadrao")
            destino = os.path.join(pai, base + {"zip": ".zip", "7z": ".7z", "targz": ".tar.gz"}[formato])
        return self._fila.enfileirar("compactar", self._rotulo("op.compactar", lista), O.compactar, lista, destino, formato)

    @pyqtSlot(str, result=int)
    @pyqtSlot(str, str, result=int)
    def extrair(self, arquivo, destino=""):
        if not O.eh_compactado(arquivo):
            return -1
        return self._fila.enfileirar("extrair", self._rotulo("op.extrair", [arquivo]), O.extrair, arquivo, destino)

    @pyqtSlot(str, str, result=str)
    def renomear(self, caminho, novo):
        novo = novo.strip()
        if not novo or "/" in novo or novo in (".", "..") or "\0" in novo:
            return self.t("erro.nomeInvalido")
        alvo = os.path.join(os.path.dirname(caminho), novo)
        if alvo == caminho:
            return ""
        if os.path.lexists(alvo) and not (os.path.normcase(alvo) == os.path.normcase(caminho)):
            return self.t("erro.jaExiste", nome=novo)
        try:
            os.rename(caminho, alvo)
        except OSError as e:
            return e.strerror or str(e)
        self._desfazer.empilhar("movidos", self.t("op.renomear", nome=os.path.basename(caminho)),
                                [{"de": caminho, "para": alvo}])
        self.desfazerMudou.emit()
        self._focarDepois(alvo)
        self.locaisMudou.emit()
        return ""

    def _criar(self, pasta, nome, chave_padrao, criar):
        pasta = pasta or self._pastaAtual()
        if not pasta:
            return ""
        nome = (nome or "").strip() or self.t(chave_padrao)
        if "/" in nome or nome in (".", ".."):
            self.notificar.emit("erro", self.t("erro.nomeInvalido"))
            return ""
        alvo = os.path.join(pasta, I.nome_livre(pasta, nome))
        try:
            criar(alvo)
        except OSError as e:
            self.notificar.emit("erro", e.strerror or str(e))
            return ""
        self._desfazer.empilhar("criados", self.t("op.criar", nome=os.path.basename(alvo)),
                                [{"para": alvo, "mtime": os.lstat(alvo).st_mtime_ns}])
        self.desfazerMudou.emit()
        self._focarDepois(alvo)
        self.itemCriado.emit(alvo)
        return alvo

    @pyqtSlot(result=str)
    @pyqtSlot(str, result=str)
    @pyqtSlot(str, str, result=str)
    def novaPasta(self, pasta="", nome=""):
        return self._criar(pasta, nome, "op.novaPastaNome", lambda p: os.mkdir(p))

    @pyqtSlot(result=str)
    @pyqtSlot(str, result=str)
    @pyqtSlot(str, str, result=str)
    def novoArquivo(self, pasta="", nome=""):
        def criar(p):
            with open(p, "x"):
                pass
        return self._criar(pasta, nome, "op.novoArquivoNome", criar)

    def _todasAbas(self):
        return list(self._abas) + [p for p in self._pares.values() if p is not None]

    def _focarDepois(self, caminho):
        for a in self._todasAbas():
            if a.caminho == os.path.dirname(caminho):
                a._focar = caminho
                a._carregar(atualizar=True)

    @pyqtSlot(str, str, result=str)
    def alterarPermissoes(self, caminho, modo):
        try:
            os.chmod(caminho, int(modo, 8))
        except (OSError, ValueError) as e:
            return str(e)
        return ""

    @pyqtProperty("QVariantList", notify=operacoesMudou)
    def operacoes(self):
        return self._fila.lista()

    @pyqtProperty(bool, notify=operacoesMudou)
    def ocupado(self):
        return self._fila.ocupado()

    @pyqtSlot(int)
    def cancelar(self, oid):
        self._fila.cancelar(oid)

    @pyqtSlot(int, str, bool)
    def resolverConflito(self, oid, acao, todos):
        self._fila.resolver(oid, acao, todos)

    @pyqtSlot()
    def limparConcluidas(self):
        self._fila.limpar()

    def _opTerminou(self, op):
        criados = op.mapa(self._idioma)["criados"]
        self.operacaoTerminou.emit(op.id, op.estado, op.mensagem, criados)   # o QML avisa (não repetir em notificar)
        self._qtdLixeira = L.quantidade()
        self.locaisMudou.emit()   # recentes que sumiram/mudaram de nome, lixeira, espaço livre
        for a in self._todasAbas():
            a.revalidarPastas()   # U10: pastas que mudaram por dentro (contagem, data, subpastas)

    @pyqtSlot()
    def encerrar(self):
        for proc in list(getattr(self, "_procsDisco", ())):
            try:   # udisksctl é só cliente: o udisks termina o que começou; aqui só não queremos o retorno
                proc.finished.disconnect()
                proc.waitForFinished(1500)
            except (RuntimeError, TypeError):
                pass
        for a in self._abas:
            a.pararBusca()
        if self._props:
            self._props.cancelar()
        self._fila.encerrar()
        from . import subpastas as S
        S.pool().waitForDone(1500)   # leituras de subpastas em andamento (pasta lenta: no máximo 1,5 s)

    # ================================================================== paridade com o Dolphin
    # ---- desfazer (Ctrl+Z)
    def _registrarDesfazer(self, op):
        if op.tipo == "desfazer":
            return
        tipo = D.tipo_desfazer(op.tipo)
        if tipo:
            self._desfazer.empilhar(tipo, op.rotulo, op.registro)
            self.desfazerMudou.emit()

    @pyqtProperty("QVariantMap", notify=desfazerMudou)
    def desfazerInfo(self):
        topo = self._desfazer.topo()
        if not topo:
            return {"pode": False, "rotulo": "", "texto": "", "efeito": ""}
        n = len(topo["itens"])
        return {"pode": True, "rotulo": topo["rotulo"], "texto": self.t("op.desfazer", rotulo=topo["rotulo"]),
                "efeito": self.t(f"desfazer.efeito.{topo['tipo']}" + (".um" if n == 1 else ".varios"), n=n)}

    @pyqtSlot(result=int)
    def desfazer(self):
        e = self._desfazer.tirar()
        self.desfazerMudou.emit()
        if not e:
            return -1
        return self._fila.enfileirar("desfazer", self.t("op.desfazer", rotulo=e["rotulo"]), D.executar, e["tipo"], e["itens"],
                                     self.t, e["rotulo"])

    # ---- duplicar (Ctrl+D), criar link, modelos
    @pyqtSlot("QVariantList", result=int)
    def duplicar(self, lista):
        lista = [str(c) for c in lista if os.path.lexists(str(c))]
        if not lista:
            return -1
        por_pasta = {}
        for c in lista:
            por_pasta.setdefault(os.path.dirname(os.path.normpath(c)), []).append(c)
        oid = -1
        for pasta, itens in por_pasta.items():
            oid = self._fila.enfileirar("duplicar", self._rotulo("op.duplicar", itens), O.copiar_mover, itens, pasta, False)
        return oid

    @pyqtSlot(str, result=str)
    @pyqtSlot(str, str, result=str)
    @pyqtSlot(str, str, str, result=str)
    def novoLink(self, alvo, pasta="", nome=""):
        if not alvo:
            return ""
        return self._criar(pasta, nome or os.path.basename(alvo.rstrip("/")), "op.novoArquivoNome",
                           lambda p: os.symlink(alvo, p))

    @pyqtProperty("QVariantList", constant=True)
    def modelos(self):
        return MD.listar()

    @pyqtSlot(str, result=str)
    @pyqtSlot(str, str, result=str)
    @pyqtSlot(str, str, str, result=str)
    def novoDeModelo(self, origem, pasta="", nome=""):
        m = next((x for x in MD.listar() if x["id"] == origem), None)
        if not m:
            self.notificar.emit("erro", self.t("erro.modelo"))
            return ""
        nome = (nome or "").strip() or (m["nome"] + m["extensao"])
        if m["extensao"] and not nome.endswith(m["extensao"]):
            nome += m["extensao"]

        def criar(p):
            with open(m["origem"], "rb") as fi, open(p, "xb") as fo:
                shutil.copyfileobj(fi, fo)
        return self._criar(pasta, nome, "op.novoArquivoNome", criar)

    # ---- renomeação em lote
    @pyqtSlot("QVariantList", "QVariantMap", result="QVariantList")
    def previaRenomearLote(self, lista, regra):
        return LT.previa([str(c) for c in lista], dict(regra))

    @pyqtSlot("QVariantList", "QVariantMap", result=int)
    def renomearLote(self, lista, regra):
        lista = [str(c) for c in lista]
        if not lista:
            return -1
        return self._fila.enfileirar("renomearLote", self._rotulo("op.renomearLote", lista), LT.aplicar, lista, dict(regra))

    # ---- etiquetas, avaliação e comentário (xattr, como o Baloo)
    def _tagsMudaram(self, caminhos):
        valores = {c: T.ler(c) for c in caminhos}
        for a in self._todasAbas():
            a._modelo.atualizar_campos(valores)
        conhecidas = self._prefs.setdefault("tags", [])
        novas = [t for v in valores.values() for t in v["tags"] if t not in conhecidas]
        if novas:
            conhecidas.extend(dict.fromkeys(novas))
            del conhecidas[:-200]
            self._gravarPrefs()
            self.preferenciasMudou.emit()

    def _mudarTags(self, lista, rotulo, mudar):
        antes, erros = [], 0
        for c in [str(x) for x in lista]:
            try:
                atual = T.ler(c)
                novo = mudar(atual)
                T.gravar(c, novo)
                antes.append({"caminho": c, "antes": atual})
            except OSError:
                erros += 1
        if antes:
            self._desfazer.empilhar("tags", rotulo, antes)
            self.desfazerMudou.emit()
            self._tagsMudaram([a["caminho"] for a in antes])
        return self.t("erro.semXattr", n=erros) if erros else ""

    @pyqtSlot("QVariantList", "QVariantList", result=str)
    def definirTags(self, lista, tags):
        tags = [str(t) for t in tags]
        return self._mudarTags(lista, self.t("op.tags"), lambda a: {"tags": tags})

    @pyqtSlot("QVariantList", str, result=str)
    def adicionarTag(self, lista, tag):
        return self._mudarTags(lista, self.t("op.tags"), lambda a: {"tags": a["tags"] + [tag]})

    @pyqtSlot("QVariantList", str, result=str)
    def removerTag(self, lista, tag):
        return self._mudarTags(lista, self.t("op.tags"), lambda a: {"tags": [x for x in a["tags"] if x != tag]})

    @pyqtSlot("QVariantList", int, result=str)
    def definirAvaliacao(self, lista, n):
        return self._mudarTags(lista, self.t("op.avaliacao"), lambda a: {"avaliacao": n})

    @pyqtSlot("QVariantList", str, result=str)
    def definirComentario(self, lista, texto):
        return self._mudarTags(lista, self.t("op.comentario"), lambda a: {"comentario": texto})

    @pyqtProperty("QVariantList", notify=preferenciasMudou)
    def tagsConhecidas(self):
        return sorted(self._prefs.get("tags", []), key=I.chave_natural)

    # ---- divisão de tela (F3)
    @pyqtProperty(bool, notify=abasMudou)
    def dividido(self):
        return bool(self._abas) and self._pares.get(id(self._abas[self._abaAtual])) is not None

    @dividido.setter
    def dividido(self, v):
        if bool(v) != self.dividido:
            self.alternarDivisao()

    @pyqtSlot()
    def alternarDivisao(self):
        if not self._abas:
            return
        prim = self._abas[self._abaAtual]
        par = self._pares.pop(id(prim), None)
        if par is not None:
            self._ladoDireito[id(prim)] = False
            par.fechar()
            par.deleteLater()
        else:
            self._pares[id(prim)] = Aba(self, prim.caminho, self._prefs.get("aba", {}), self)
            self._ladoDireito[id(prim)] = True   # como o Dolphin: o painel novo fica ativo
        self.abasMudou.emit()

    @pyqtProperty(QObject, notify=abasMudou)
    def painelEsquerdo(self):
        return self._abas[self._abaAtual] if self._abas else None

    @pyqtProperty(QObject, notify=abasMudou)
    def painelDireito(self):
        return self._pares.get(id(self._abas[self._abaAtual])) if self._abas else None

    @pyqtProperty(str, notify=abasMudou)
    def ladoAtivo(self):
        return "direito" if self._abas and self._ladoDireito.get(id(self._abas[self._abaAtual])) and self.dividido else "esquerdo"

    @ladoAtivo.setter
    def ladoAtivo(self, v):
        if not self._abas:
            return
        prim = self._abas[self._abaAtual]
        direito = v == "direito" and self._pares.get(id(prim)) is not None
        if direito != bool(self._ladoDireito.get(id(prim))):
            self._ladoDireito[id(prim)] = direito
            self.abasMudou.emit()

    def _outroLado(self):
        if not self.dividido:
            return None
        prim = self._abas[self._abaAtual]
        outro = prim if self._ladoDireito.get(id(prim)) else self._pares[id(prim)]
        return outro.pasta_real()

    @pyqtSlot("QVariantList", result=int)
    def copiarParaOutroLado(self, lista):
        destino = self._outroLado()
        return self.copiar(lista, destino) if destino else -1

    @pyqtSlot("QVariantList", result=int)
    def moverParaOutroLado(self, lista):
        destino = self._outroLado()
        return self.mover(lista, destino) if destino else -1

    @pyqtSlot(int, int)
    def moverAba(self, de, para):
        if 0 <= de < len(self._abas) and 0 <= para < len(self._abas) and de != para:
            atual = self._abas[self._abaAtual]
            self._abas.insert(para, self._abas.pop(de))
            self._abaAtual = self._abas.index(atual)
            self.abasMudou.emit()

    @pyqtSlot(str)
    def novaJanela(self, caminho=""):
        """Outra janela = outro processo (sem a instância única, para não repassar a si mesma)."""
        entrada = str(Path(__file__).resolve().parent.parent / "cyberkde-arquivos.py")
        QProcess.startDetached(sys.executable, [entrada, "--sem-dbus"] + ([caminho] if caminho else []))

    # ---- copiar para / mover para (com seletor de pasta)
    @pyqtSlot("QVariantList")
    def copiarPara(self, lista):
        self._paraPendente = ("copiar", [str(c) for c in lista])
        self.escolherPasta(self._pastaAtual() or "", "copiarPara")

    @pyqtSlot("QVariantList")
    def moverPara(self, lista):
        self._paraPendente = ("mover", [str(c) for c in lista])
        self.escolherPasta(self._pastaAtual() or "", "moverPara")

    def _pastaParaCopiar(self, proposito, caminho):
        pend = getattr(self, "_paraPendente", None)
        if proposito not in ("copiarPara", "moverPara") or not pend:
            return
        self._paraPendente = None
        if caminho:
            (self.copiar if pend[0] == "copiar" else self.mover)(pend[1], caminho)

    # ---- ServiceMenus do KDE
    @pyqtSlot("QVariantList", result="QVariantList")
    def servicosPara(self, lista):
        if self._servicosCache is None:
            self._servicosCache = SV.carregar()
        return SV.para([str(c) for c in lista], self._servicosCache)

    @pyqtSlot(str, "QVariantList")
    def executarServico(self, ident, lista):
        if not SV.executar(ident, [str(c) for c in lista]):
            self.notificar.emit("erro", self.t("erro.servico"))

    @pyqtSlot()
    def recarregarServicos(self):
        self._servicosCache = None

    # ---- propriedades e permissões em lote
    @pyqtSlot("QVariantList")
    def propriedadesVarias(self, lista):
        lista = [str(c) for c in lista]

        def pronto(r):
            if isinstance(r, dict):
                self.propriedadesVariasProntas.emit(r)
        rodar(_propriedades_varias, lista, self._idioma, pronto=pronto)

    @pyqtSlot("QVariantList", str, bool, result=int)
    def alterarPermissoesLote(self, lista, mudanca, recursivo):
        """mudanca: octal ("644") ou simbólica como o chmod ("u+x,go-w", "a+X"). Desfazível."""
        lista = [str(c) for c in lista]
        if not lista or not O.modo_valido(mudanca):
            return -1
        return self._fila.enfileirar("permissoes", self._rotulo("op.permissoes", lista), O.permissoes, lista, mudanca, recursivo)

    @pyqtProperty("QVariantList", constant=True)
    def gruposDisponiveis(self):
        nomes = []
        for g in os.getgroups():
            try:
                nomes.append(grp.getgrgid(g).gr_name)
            except KeyError:
                pass
        return sorted(set(nomes))

    @pyqtSlot("QVariantList", str, result=str)
    def alterarGrupo(self, lista, grupo):
        """Só para grupos da própria usuária (trocar de dono pede root: não fazemos)."""
        try:
            gid = grp.getgrnam(grupo).gr_gid
        except KeyError:
            return self.t("erro.grupo")
        if gid not in os.getgroups() and gid != os.getgid():
            return self.t("erro.grupo")
        erros = 0
        for c in [str(x) for x in lista]:
            try:
                os.chown(c, -1, gid, follow_symlinks=False)
            except OSError:
                erros += 1
        return self.t("erro.algunsItens", n=erros) if erros else ""

    # ---- desmontar / ejetar com confirmação
    @pyqtSlot(str, result="QVariantMap")
    def prepararDesmontar(self, dispositivo, ejetar=False):
        d = next((x for x in self._dispositivos if x["dispositivo"] == dispositivo), None)
        if not d:
            return {}
        mnt = d.get("caminho") or ""
        afetadas = [a.titulo for a in self._todasAbas() if mnt and (a.caminho == mnt or a.caminho.startswith(mnt.rstrip("/") + "/"))]
        rodando = [o["rotulo"] for o in self._fila.lista() if o["estado"] not in O.ESTADOS_FIM]
        return {"ficha": self._novaFicha("ejetar" if ejetar else "desmontar", [dispositivo]), "nome": d["nome"],
                "dispositivo": dispositivo, "montagem": mnt, "abasAfetadas": afetadas, "operacoes": rodando,
                "removivel": d["removivel"], "ejetar": ejetar}

    @pyqtSlot(str, result="QVariantMap")
    def prepararEjetar(self, dispositivo):
        return self.prepararDesmontar(dispositivo, True)

    def _confirmarDisco(self, ficha, tipo):
        lista = self._usarFicha(ficha, tipo)
        if not lista:
            return False
        dev = lista[0]
        mnt = next((x.get("caminho") for x in self._dispositivos if x["dispositivo"] == dev), "")
        for a in self._todasAbas():   # sai do disco antes de desmontar (senão "alvo ocupado")
            if mnt and (a.caminho == mnt or a.caminho.startswith(mnt.rstrip("/") + "/")):
                a.irPara(str(Path.home()))
        self._udisks("unmount", dev, depois=("power-off" if tipo == "ejetar" else None))
        return True

    @pyqtSlot(str, result=bool)
    def ejetar(self, ficha):
        if self._confirmarDisco(ficha, "ejetar"):
            return True
        info = self.prepararEjetar(ficha)
        if info:
            self.confirmacaoNecessaria.emit("ejetar", info)
        return False

    @pyqtSlot(str, result=bool)
    def confirmar(self, ficha):
        """Executa a ação preparada (apagar, esvaziar, desmontar, ejetar) a que a ficha pertence."""
        v = self._fichas.get(ficha)
        if not v:
            self.notificar.emit("aviso", self.t("erro.ficha"))
            return False
        tipo = v[0]
        if tipo == "apagar":
            return self.apagarPermanentemente(ficha) > 0
        if tipo == "esvaziar":
            return self.esvaziarLixeira(ficha) > 0
        if tipo in ("desmontar", "ejetar"):
            return self._confirmarDisco(ficha, tipo)
        return False

    # ---- completar o caminho no Ctrl+L (U23)
    @pyqtSlot(str, result="QVariantList")
    def completarCaminho(self, texto):
        """Até 8 pastas que completam o texto (como o Dolphin): [{nome, caminho, texto}], em que `texto`
        é o que vai para o campo (mantém o "~" se ela digitou "~"). Sem caixa e sem acento; ocultas só
        quando o pedaço começa com ".". Montagens de rede não são listadas."""
        from . import subpastas as S
        bruto = texto or ""
        especiais = [e for e in ("lixeira:", "recentes:") if bruto and e.startswith(bruto.lower()) and bruto.lower() != e]
        if especiais:
            return [{"nome": e, "caminho": e, "texto": e} for e in especiais]
        if bruto.startswith("file://"):
            bruto = QUrl(bruto).toLocalFile()
        casa = str(Path.home())
        til = bruto.startswith("~")
        abs_ = os.path.expanduser(bruto)
        if not os.path.isabs(abs_):
            base = self._pastaAtual() or casa
            abs_ = os.path.join(base, abs_)
        pasta, pedaco = (abs_, "") if bruto.endswith("/") or bruto in ("~", "") else os.path.split(abs_)
        pasta = os.path.normpath(pasta) if pasta else "/"
        if not os.path.isdir(pasta) or S.eh_rede(pasta):
            return []
        alvo = I.sem_acento(pedaco)
        achados = []
        try:
            with os.scandir(pasta) as it:
                for n, e in enumerate(it):
                    if n > 5000:
                        break
                    if e.name.startswith(".") and not pedaco.startswith("."):
                        continue
                    try:
                        if not e.is_dir():
                            continue
                    except OSError:
                        continue
                    if I.sem_acento(e.name).startswith(alvo):
                        achados.append(e.name)
        except OSError:
            return []
        achados.sort(key=I.chave_natural)
        res = []
        for nome in achados[:8]:
            completo = os.path.join(pasta, nome)
            mostrar = completo
            if til and (completo == casa or completo.startswith(casa + "/")):
                mostrar = "~" + completo[len(casa):]
            elif not os.path.isabs(os.path.expanduser(bruto)):
                mostrar = os.path.relpath(completo, self._pastaAtual() or casa)
            res.append({"nome": nome, "caminho": completo, "texto": mostrar + "/"})
        return res

    @pyqtSlot(str, result=str)
    def prefixoComum(self, texto):
        """Para o Tab: o maior começo comum das sugestões (ou o próprio texto)."""
        sug = [s["texto"] for s in self.completarCaminho(texto)]
        if not sug:
            return texto
        if len(sug) == 1:
            return sug[0]
        comum = os.path.commonprefix(sug)
        return comum if len(comum) > len(texto) else texto

    # ---- miniatura que falhou (U16)
    def miniaturaFalhou(self, caminho):
        """O provedor não conseguiu gerar: zera o papel `miniatura` (o QML mostra o ícone do tipo)."""
        for a in self._todasAbas():
            a._modelo.atualizar_campos({caminho: {"miniatura": ""}})

    # ---- teclado no soltar
    @pyqtSlot(result="QVariantMap")
    def modificadores(self):
        """Teclas Ctrl/Shift/Alt seguradas AGORA (o DropEvent do QML não diz se é Shift)."""
        m = QGuiApplication.queryKeyboardModifiers()
        return {"ctrl": bool(m & Qt.KeyboardModifier.ControlModifier),
                "shift": bool(m & Qt.KeyboardModifier.ShiftModifier),
                "alt": bool(m & Qt.KeyboardModifier.AltModifier)}

    # ---- abrir com outro app, app padrão, e-mail
    @pyqtSlot(result="QVariantList")
    def todosApps(self):
        return A.todos_apps()

    @pyqtSlot(str, str, result=str)
    def definirAppPadrao(self, mime, ident):
        if mime == "inode/directory":
            return self.t("erro.padraoPastas")   # é do efeito "datashard" (cyberkde efeito datashard)
        return "" if A.definir_padrao(mime, ident) else self.t("erro.abrir")

    @pyqtSlot("QVariantList")
    def enviarEmail(self, lista):
        if not A.enviar_email([str(c) for c in lista if os.path.isfile(str(c))]):
            self.notificar.emit("erro", self.t("erro.email"))

    # ---- preferências de interface: zoom, atalhos, lembrar visão por pasta
    @pyqtProperty(int, notify=preferenciasMudou)
    def zoom(self):
        return int(self._prefs.get("zoom", 100))

    @zoom.setter
    def zoom(self, v):
        v = max(50, min(300, int(v)))
        if v != self.zoom:
            self._prefs["zoom"] = v
            self._gravarPrefs()
            self.preferenciasMudou.emit()

    @pyqtProperty("QVariantMap", notify=preferenciasMudou)
    def atalhos(self):
        return {**ATALHOS_PADRAO, **self._prefs.get("atalhos", {})}

    @pyqtSlot(str, str)
    def definirAtalho(self, acao, sequencia):
        if acao in ATALHOS_PADRAO:
            self._prefs.setdefault("atalhos", {})[acao] = sequencia
            self._gravarPrefs()
            self.preferenciasMudou.emit()

    @pyqtSlot()
    def restaurarAtalhos(self):
        self._prefs.pop("atalhos", None)
        self._gravarPrefs()
        self.preferenciasMudou.emit()

    @pyqtProperty(bool, notify=preferenciasMudou)
    def lembrarVisaoPorPasta(self):
        return bool(self._prefs.get("lembrarPorPasta", False))

    @lembrarVisaoPorPasta.setter
    def lembrarVisaoPorPasta(self, v):
        self._prefs["lembrarPorPasta"] = bool(v)
        self._gravarPrefs()
        self.preferenciasMudou.emit()

    def visaoDaPasta(self, caminho):
        return self._prefs.get("porPasta", {}).get(caminho) if self.lembrarVisaoPorPasta else None

    def guardarVisaoDaPasta(self, caminho, valores):
        pp = self._prefs.setdefault("porPasta", {})
        pp[caminho] = valores
        while len(pp) > 500:
            pp.pop(next(iter(pp)))
        self._gravarPrefs()

    # para testes
    def fila(self):
        return self._fila


def _parece_texto(amostra):
    try:
        amostra.decode("utf-8")
        return True
    except UnicodeDecodeError as e:
        return e.start > len(amostra) - 4   # cortou um caractere multibyte no fim

