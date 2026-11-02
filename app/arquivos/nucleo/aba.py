"""Uma aba: pasta atual, histórico, leitura assíncrona, observação de mudanças, filtro/ordem,
seleção e busca. API para o QML na spec, seção 14.2."""

import fnmatch
import os
import re
import time
from pathlib import Path

from PyQt6.QtCore import QFileSystemWatcher, QMimeDatabase, QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot

from . import busca as B
from . import itens as I
from . import lixeira as L
from . import locais as LC
from . import subpastas as S
from .modelo import ModeloItens
from .tarefas import rodar

LIXEIRA = "lixeira:"
RECENTES = "recentes:"
VISOES = ("pilhas", "lista", "grade")
ORDENS = ("nome", "tamanho", "data", "tipo")


def _ler_pasta(tarefa, caminho, idioma):
    db = QMimeDatabase()
    if caminho == LIXEIRA:
        return L.listar(db, idioma, tarefa), ""
    if caminho == RECENTES:
        return [it for it in (I.ler_item(c, db, None, idioma) for c in LC.recentes(200)) if it], ""
    try:
        entradas = list(os.scandir(caminho))
    except PermissionError:
        return [], "erro.semPermissao"
    except FileNotFoundError:
        return [], "erro.naoExiste"
    except OSError as e:
        return [], str(e)
    res = []
    for e in entradas:
        if tarefa.cancelada():
            break
        it = I.ler_item(e.path, db, e, idioma)
        if it:
            res.append(it)
    return res, ""


def _contar(tarefa, pastas, ocultos):
    """{caminho: (mtime_ms, n, limite)}: a contagem respeita "mostrar ocultos"."""
    lote = {}
    for p in pastas:
        if tarefa.cancelada():
            return None
        try:
            mt = int(os.stat(p).st_mtime * 1000)
        except OSError:
            mt = 0
        n, lim = I.contar_pasta(p, 999, ocultos)
        lote[p] = (mt, n, lim)
        if len(lote) >= 64:
            tarefa.parcial(lote)
            lote = {}
    if lote:
        tarefa.parcial(lote)
    return True


class Aba(QObject):
    caminhoMudou = pyqtSignal()
    estadoMudou = pyqtSignal()       # carregando, erro, busca
    opcoesMudou = pyqtSignal()       # visão, ordem, ocultos, filtro
    selecaoMudou = pyqtSignal()
    atualMudou = pyqtSignal()
    gruposMudou = pyqtSignal()
    carregou = pyqtSignal()
    navegou = pyqtSignal(str, arguments=["direcao"])

    def __init__(self, dono, caminho, prefs, parent=None):
        super().__init__(parent)
        self._dono = dono
        self._caminho = ""
        self._sel = set()
        self._modelo = ModeloItens(self._sel, self)
        self._emSecoes = bool(prefs.get("agrupar", False))
        self._modelo.secao = self._secaoDe if self._emSecoes else None
        self._todos = []
        self._filhos = {}
        self._grupos = []
        self._hist, self._futuro = [], []
        self._geracao = 0
        self._leitura = self._contagem = self._busca = None
        self._carregando = False
        self._erro = ""
        self._visao = prefs.get("visao", "pilhas")
        self._ordem = prefs.get("ordem", "nome")
        self._decrescente = bool(prefs.get("decrescente", False))
        self._ocultos = bool(prefs.get("mostrarOcultos", False))
        self._agruparTipos = bool(prefs.get("agruparTipos", False))   # PILHAS: arquivos em pilhas por tipo
        self._filtro = ""
        self._atual = -1
        self._ancora = -1
        self._modoBusca = self._buscando = False
        self._textoBusca = ""
        self._focar = None    # caminho a virar "atual" quando a leitura terminar
        self._subPedidas = set()   # pastas cujas subpastas a interface pediu (spec 19)
        self._subEmVoo = {}        # (caminho, ocultos) -> tarefa
        self._obs = QFileSystemWatcher(self)
        self._obs.directoryChanged.connect(self._mudouNoDisco)
        self._obs.fileChanged.connect(self._mudouNoDisco)
        self._atraso = QTimer(self, singleShot=True, interval=200)
        self._atraso.timeout.connect(self._recarregarAtrasado)   # método, não lambda (ver fechar())
        self._fechada = False
        self._navegar(self._resolver(caminho) or str(Path.home()), "ir", historico=False)

    # ---------------------------------------------------------------- navegação
    def _resolver(self, texto):
        texto = (texto or "").strip()
        if not texto:
            return None
        if texto in (LIXEIRA, "trash:", "trash:/", "lixeira:/"):
            return LIXEIRA
        if texto in (RECENTES, "recentes:/", "recentdocuments:/"):
            return RECENTES
        if texto.startswith("file://"):
            texto = QUrl(texto).toLocalFile()
        texto = os.path.expanduser(texto)
        if not os.path.isabs(texto):
            base = self._caminho if self._caminho not in (LIXEIRA, RECENTES, "") else str(Path.home())
            texto = os.path.join(base, texto)
        return os.path.normpath(texto)

    def _navegar(self, caminho, direcao, historico=True):
        if self._busca:
            self._busca.cancelar()
            self._busca = None
        self._modoBusca = self._buscando = False
        self._textoBusca = ""
        if historico and self._caminho and caminho != self._caminho:
            self._hist.append(self._caminho)
            if direcao != "avancar":
                self._futuro.clear()
        self._caminho = caminho
        propria = self._dono.visaoDaPasta(caminho) if hasattr(self._dono, "visaoDaPasta") else None
        if propria:
            self._visao = propria.get("visao", self._visao)
            self._ordem = propria.get("ordem", self._ordem)
            self._decrescente = bool(propria.get("decrescente", self._decrescente))
            self._ocultos = bool(propria.get("mostrarOcultos", self._ocultos))
            self._agruparTipos = bool(propria.get("agruparTipos", self._agruparTipos))
        self._filtro = ""
        self._subPedidas.clear()
        self._sel.clear()
        self._atual = self._ancora = -1
        self._todos = []
        self._vigiar()
        self.caminhoMudou.emit()
        self.opcoesMudou.emit()
        self.selecaoMudou.emit()
        self.atualMudou.emit()
        self.navegou.emit(direcao)
        self._carregar(atualizar=False)

    def _vigiar(self):
        velhos = self._obs.files() + self._obs.directories()
        if velhos:
            self._obs.removePaths(velhos)
        if self._caminho == LIXEIRA:
            alvos = [str(lx / "files") for lx, _ in L.lixeiras()]
        elif self._caminho == RECENTES:
            alvos = [str(LC.dir_dados() / "recently-used.xbel")]
        else:
            alvos = [self._caminho]
        alvos = [a for a in alvos if os.path.exists(a)]
        if alvos:
            self._obs.addPaths(alvos)

    def _recarregarAtrasado(self):
        if not self._fechada:
            self._carregar(atualizar=True)

    def fechar(self):
        """Antes do deleteLater: para observador, temporizador e tarefas. Sem isso, um sinal de um filho
        (o QTimer de atraso) pode disparar no meio da destruição e o PyQt chama um lambda já liberado
        (falha de segmentação ao fechar uma aba logo depois de uma operação mexer na pasta dela)."""
        self._fechada = True
        self._atraso.stop()
        try:
            self._atraso.timeout.disconnect()
            self._obs.directoryChanged.disconnect()
            self._obs.fileChanged.disconnect()
        except TypeError:
            pass
        vigiados = self._obs.files() + self._obs.directories()
        if vigiados:
            self._obs.removePaths(vigiados)
        for t in (self._leitura, self._contagem, self._busca):
            if t:
                t.cancelar()
        for t in self._subEmVoo.values():
            t.cancelar()

    def _mudouNoDisco(self, *_):
        if not self._modoBusca:
            if self._caminho == RECENTES:
                self._vigiar()   # o xbel é regravado por rename
            self._atraso.start()

    @pyqtSlot(str, result=str)
    def irPara(self, texto):
        alvo = self._resolver(texto)
        if not alvo:
            return ""
        if alvo in (LIXEIRA, RECENTES):
            self._navegar(alvo, "ir")
            return ""
        if os.path.isdir(alvo):
            if not os.access(alvo, os.R_OK | os.X_OK):
                return self._dono.t("erro.semPermissao")
            self._navegar(alvo, "ir")
            return ""
        if os.path.exists(alvo):  # arquivo: vai para a pasta e deixa ele selecionado
            self._focar = alvo
            self._navegar(os.path.dirname(alvo), "ir")
            return ""
        return self._dono.t("erro.naoExiste")

    def focar(self, pasta, itens=()):
        """Vai para `pasta` (ou recarrega, se já estiver nela) e seleciona `itens` quando a leitura
        chegar. Para o "Mostrar na pasta" (D-Bus FileManager1.ShowItems) e a linha de comando."""
        itens = [os.path.normpath(c) for c in itens]
        if any(os.path.basename(c).startswith(".") for c in itens) and not self._ocultos:
            self._ocultos = True          # o item pedido é oculto: mostra (sem gravar como preferência)
            self.opcoesMudou.emit()
            self._subPedidas.clear()
        self._focar = itens or None
        if self._modoBusca:
            self.sairBusca()
        if os.path.normpath(pasta) == self._caminho:
            self._carregar(atualizar=True)
        else:
            self._navegar(os.path.normpath(pasta), "ir")

    @pyqtSlot(int)
    def abrirIndice(self, i):
        it = self._modelo.item(i)
        if it and it["ehPasta"]:
            if not os.access(it["caminho"], os.R_OK | os.X_OK):
                self._dono.notificar.emit("erro", self._dono.t("erro.semPermissao"))
                return
            self._navegar(it["caminho"], "entrar")

    @pyqtSlot(int)
    def ativar(self, i):
        it = self._modelo.item(i)
        if not it:
            return
        if it["ehPasta"]:
            self.abrirIndice(i)
        elif self._caminho != LIXEIRA:
            self._dono.abrir(it["caminho"])

    @pyqtSlot()
    def voltar(self):
        if self._hist:
            self._futuro.append(self._caminho)
            destino = self._hist.pop()
            self._focar = None
            self._navegar(destino, "voltar", historico=False)

    @pyqtSlot()
    def avancar(self):
        if self._futuro:
            self._hist.append(self._caminho)
            self._navegar(self._futuro.pop(), "avancar", historico=False)

    @pyqtSlot()
    def subir(self):
        if self._caminho in (LIXEIRA, RECENTES):
            self._navegar(str(Path.home()), "subir")
            return
        pai = os.path.dirname(self._caminho)
        if pai and pai != self._caminho:
            self._focar = self._caminho
            self._navegar(pai, "subir")

    @pyqtSlot()
    def recarregar(self):
        if self._modoBusca:
            self.buscar(self._textoBusca, {})
        else:
            self._carregar(atualizar=True)

    # ---------------------------------------------------------------- leitura
    def _carregar(self, atualizar):
        if self._leitura:
            self._leitura.cancelar()
        if self._contagem:
            self._contagem.cancelar()
            self._contagem = None
        self._geracao += 1
        g = self._geracao
        self._carregando = True
        self.estadoMudou.emit()
        self._leitura = rodar(_ler_pasta, self._caminho, self._dono.idioma,
                              pronto=lambda r: self._lido(g, r, atualizar))

    def _lido(self, g, r, atualizar):
        if self._fechada:
            return
        if g != self._geracao or isinstance(r, Exception) and not isinstance(r, tuple):
            if g == self._geracao:
                self._carregando = False
                self._erro = str(r)
                self.estadoMudou.emit()
            return
        self._leitura = None
        itens, erro = r
        self._erro = self._dono.t(erro) if erro.startswith("erro.") else erro
        for it in itens:
            if it["ehPasta"]:
                guardado = self._filhos.get((it["caminho"], self._ocultos))
                if guardado and guardado[0] == it["modificado"]:
                    it["filhos"], it["filhosLimite"] = guardado[1], guardado[2]
            if it["ehPasta"]:
                guardado = S.do_cache(it["caminho"], self._ocultos, it["modificado"])
                if guardado:
                    it.update(guardado)
        self._todos = itens
        self._carregando = False
        self._publicar(atualizar)
        if self._focar:
            alvos = [self._focar] if isinstance(self._focar, str) else list(self._focar)
            self._focar = None
            linhas = [ln for ln in (self._modelo.linha_de(c) for c in alvos) if ln >= 0]
            if linhas:
                self._trocarSelecao({self._modelo.itens()[ln]["caminho"] for ln in linhas})
                self._ancora = linhas[0]
                self._atual = linhas[0]
                self.atualMudou.emit()
        self.estadoMudou.emit()
        self.carregou.emit()
        if self._visao == "pilhas":
            self._pedirAuto()
        elif self._subPedidas:   # recarga com a visão em outra: refaz só o que já tinha sido pedido
            self._pedirCaminhos(self._subPedidas)
        pastas = [it["caminho"] for it in itens if it["ehPasta"] and it["filhos"] < 0]
        if pastas:
            self._contagem = rodar(_contar, pastas, self._ocultos, parcial=lambda lote, o=self._ocultos: self._contados(g, lote, o))

    def _contados(self, g, lote, ocultos):
        if self._fechada:
            return
        if g != self._geracao or ocultos != self._ocultos:
            return
        for c, v in lote.items():
            self._filhos[(c, ocultos)] = v
        # o modelo primeiro: os dicionários são os mesmos de _todos, e ele só avisa o que mudou
        self._modelo.atualizar_campos({c: {"filhos": n, "filhosLimite": lim} for c, (_mt, n, lim) in lote.items()})
        for it in self._todos:
            if it["caminho"] in lote:
                it["filhos"], it["filhosLimite"] = lote[it["caminho"]][1], lote[it["caminho"]][2]

    def _recontar(self, pastas):
        """Conta de novo (ocultos trocados, ou a pasta mudou por dentro)."""
        if not pastas:
            return
        if self._contagem:
            self._contagem.cancelar()
        g = self._geracao
        self._contagem = rodar(_contar, list(pastas), self._ocultos,
                               parcial=lambda lote, o=self._ocultos: self._contados(g, lote, o))

    def revalidarPastas(self):
        if self._fechada:
            return
        """Depois de uma operação: as pastas desta aba que mudaram POR DENTRO (mover para dentro delas,
        colar nelas…) não disparam o observador desta pasta; aqui o mtime delas é conferido numa thread
        e o que mudou ganha data, contagem e subpastas novas."""
        if self._modoBusca or self._carregando:
            return
        pastas = {it["caminho"]: it["modificado"] for it in self._modelo.itens() if it["ehPasta"]}
        if not pastas:
            return
        g, ocultos = self._geracao, self._ocultos

        def conferir(tarefa):
            mudou = {}
            for c, mt_velho in pastas.items():
                if tarefa.cancelada():
                    break
                try:
                    mt = int(os.stat(c).st_mtime * 1000)
                except OSError:
                    continue
                if mt != mt_velho:
                    n, lim = I.contar_pasta(c, 999, ocultos)
                    mudou[c] = (mt, n, lim)
            return mudou

        def pronto(mudou):
            if self._fechada or g != self._geracao or ocultos != self._ocultos or not isinstance(mudou, dict) or not mudou:
                return
            for c, v in mudou.items():
                self._filhos[(c, ocultos)] = v
            self._modelo.atualizar_campos({c: {"modificado": mt, "modificadoTexto": I.data_texto(mt / 1000),
                                               "filhos": n, "filhosLimite": lim} for c, (mt, n, lim) in mudou.items()})
            refazer = [c for c in mudou if c in self._subPedidas]
            if refazer:
                self._pedirCaminhos(refazer)
        rodar(conferir, pronto=pronto)

    def _filtrar(self):
        itens = self._todos
        if not self._ocultos and self._caminho != LIXEIRA:
            itens = [it for it in itens if not it["oculto"]]
        if self._filtro:
            f = I.sem_acento(self._filtro)
            itens = [it for it in itens if f in I.sem_acento(it["nome"])]
        if self._caminho == RECENTES:
            return itens
        return I.ordenar(itens, self._ordem, self._decrescente)

    def _publicar(self, atualizar):
        lista = self._filtrar()
        atual_caminho = self._caminhoAtual()
        if atualizar:
            self._modelo.aplicar(lista)
        else:
            self._modelo.redefinir(lista)
        # a seleção só guarda o que continua visível
        visiveis = {it["caminho"] for it in lista}
        fora = self._sel - visiveis
        if fora:
            self._sel.difference_update(fora)
            self.selecaoMudou.emit()
        novo = self._modelo.linha_de(atual_caminho) if atual_caminho else -1
        if novo != self._atual:
            self._atual = novo
            self.atualMudou.emit()
        self._agrupar()

    def _caminhoAtual(self):
        it = self._modelo.item(self._atual)
        return it["caminho"] if it else None

    def _agrupar(self):
        por = {}
        for i, it in enumerate(self._modelo.itens()):
            por.setdefault(it["grupo"], []).append(i)
        grupos = []
        for n, gid in enumerate(I.GRUPOS):
            if gid not in por:
                continue
            idx = por[gid]
            tam = sum(max(self._modelo.itens()[i]["tamanho"], 0) for i in idx)
            grupos.append({"id": gid, "rotulo": self._dono.t(f"grupo.{gid}"), "codigo": f"GRP_0x{n + 1:02X}",
                           "quantidade": len(idx), "tamanhoTexto": I.tamanho_texto(tam, self._dono.idioma) if gid != "pastas" else "",
                           "indices": idx})
        self._grupos = grupos
        self.gruposMudou.emit()

    # ---------------------------------------------------------------- subpastas (visão PILHAS, spec 19)
    @pyqtSlot("QVariantList")
    def pedirSubpastas(self, indices):
        itens = self._modelo.itens()
        caminhos = []
        for k in indices or []:
            try:
                k = int(k)
            except (TypeError, ValueError):
                continue
            if 0 <= k < len(itens) and itens[k]["ehPasta"]:
                caminhos.append(itens[k]["caminho"])
        self._pedirCaminhos(caminhos)

    def _pedirAuto(self, n=48):
        self._pedirCaminhos([it["caminho"] for it in self._modelo.itens() if it["ehPasta"]][:n])

    def _pedirCaminhos(self, caminhos):
        ocultos = self._ocultos
        aplicar = {}
        for c in list(caminhos):
            ln = self._modelo.linha_de(c)
            if ln < 0:
                continue
            it = self._modelo.itens()[ln]
            self._subPedidas.add(c)
            guardado = S.do_cache(c, ocultos, it["modificado"])
            if guardado:
                aplicar[c] = guardado
                continue
            if S.eh_rede(c):
                aplicar[c] = dict(S.VAZIO, subpastasEstado="remoto")
                continue
            if (c, ocultos) in self._subEmVoo:
                continue
            if it.get("subpastasEstado") != "lendo":
                aplicar[c] = {"subpastasEstado": "lendo"}   # o que já havia (mtime velho) fica até chegar o novo
            self._subEmVoo[(c, ocultos)] = rodar(lambda _t, c=c, o=ocultos: S.ler(c, o),
                                                 pronto=lambda r, c=c, o=ocultos: self._subChegou(c, o, r),
                                                 pool=S.pool())
            QTimer.singleShot(S.TEMPO_LIMITE_MS, lambda c=c, o=ocultos: self._subTempo(c, o))
        if aplicar:
            self._modelo.atualizar_campos(aplicar)

    def _subChegou(self, c, ocultos, r):
        if self._fechada:
            return
        self._subEmVoo.pop((c, ocultos), None)
        if isinstance(r, Exception):
            r = (0, {"subpastas": [], "subpastasTotal": 0, "arquivosTotal": 0, "subpastasEstado": "erro"})
        modificado, res = r
        S.guardar(c, ocultos, modificado, res)
        if ocultos == self._ocultos:
            self._modelo.atualizar_campos({c: res})

    def _subTempo(self, c, ocultos):
        if self._fechada:
            return
        if (c, ocultos) in self._subEmVoo and ocultos == self._ocultos:
            self._modelo.atualizar_campos({c: dict(S.VAZIO, subpastasEstado="tempo")})

    def _subpastasDeNovo(self):
        """Trocou "mostrar ocultos": o que estava calculado não vale mais."""
        novos = {}
        for it in self._modelo.itens():
            if it["ehPasta"]:
                novos[it["caminho"]] = S.do_cache(it["caminho"], self._ocultos, it["modificado"]) or dict(S.VAZIO)
        self._modelo.atualizar_campos(novos)
        pedidas = [c for c in self._subPedidas if self._modelo.linha_de(c) >= 0]
        if self._visao == "pilhas":
            self._pedirAuto()
        self._pedirCaminhos(pedidas)

    # ---------------------------------------------------------------- seleção por padrão, histórico, grupos
    @pyqtSlot(str, bool, result=int)
    def selecionarPorPadrao(self, padrao, adicionar):
        """Curinga sem caixa ("*.jpg", "foto??.*"; vários separados por espaço ou ";") ou expressão
        regular com o prefixo "re:". Devolve quantos ficaram selecionados."""
        padrao = (padrao or "").strip()
        if not padrao:
            return 0
        itens = self._modelo.itens()
        if padrao.startswith("re:"):
            try:
                rx = re.compile(padrao[3:], re.IGNORECASE)
            except re.error:
                return -1
            casa = lambda n: bool(rx.search(n))   # noqa: E731
        else:
            curingas = [c.casefold() for c in re.split(r"[;\s]+", padrao) if c]
            casa = lambda n: any(fnmatch.fnmatchcase(n.casefold(), c) for c in curingas)   # noqa: E731
        achados = {it["caminho"] for it in itens if casa(it["nome"])}
        self._trocarSelecao((set(self._sel) | achados) if adicionar else achados)
        return len(self._sel)

    @pyqtSlot()
    def inverterSelecao(self):
        self._trocarSelecao({it["caminho"] for it in self._modelo.itens()} - self._sel)

    @pyqtProperty("QVariantList", notify=caminhoMudou)
    def historico(self):
        """[{caminho, titulo, atual, k}] do mais antigo ao mais novo; k vai para irHistorico()."""
        seq = self._hist + [self._caminho] + list(reversed(self._futuro))
        n = len(self._hist)
        return [{"caminho": c, "titulo": os.path.basename(c) or c, "atual": k == n, "k": k - n}
                for k, c in enumerate(seq)]

    @pyqtSlot(int)
    def irHistorico(self, k):
        """k < 0 volta k passos; k > 0 avança."""
        for _ in range(abs(int(k))):
            (self.voltar if k < 0 else self.avancar)()

    @pyqtProperty(bool, notify=opcoesMudou)
    def agrupar(self):
        return self._emSecoes

    @agrupar.setter
    def agrupar(self, v):
        if bool(v) != self._emSecoes:
            self._emSecoes = bool(v)
            self._modelo.secao = self._secaoDe if self._emSecoes else None
            self._dono.lembrarPrefs({"agrupar": self._emSecoes})
            self.opcoesMudou.emit()
            self._modelo.secoes_mudaram()

    def _secaoDe(self, it):
        t = self._dono.t
        if it["ehPasta"]:
            return t("grupo.pastas")
        if self._ordem == "tamanho":
            n = it["tamanho"]
            chave = "vazio" if n <= 0 else "pequeno" if n < 1 << 20 else "medio" if n < 100 << 20 else \
                "grande" if n < 1 << 30 else "enorme"
            return t(f"secao.{chave}")
        if self._ordem == "data":
            idade = time.time() - it["modificado"] / 1000
            hoje = time.localtime()
            meia_noite = time.mktime((hoje.tm_year, hoje.tm_mon, hoje.tm_mday, 0, 0, 0, 0, 0, -1))
            ts = it["modificado"] / 1000
            chave = "hoje" if ts >= meia_noite else "ontem" if ts >= meia_noite - 86400 else \
                "semana" if idade < 7 * 86400 else "mes" if idade < 31 * 86400 else \
                "ano" if idade < 365 * 86400 else "antigos"
            return t(f"secao.{chave}")
        if self._ordem == "tipo":
            return it["tipo"]
        letra = I.sem_acento(it["nome"].lstrip("."))[:1].upper()
        return letra if letra.isalpha() else ("0–9" if letra.isdigit() else "#")

    # ---------------------------------------------------------------- busca
    @pyqtSlot(str, "QVariantMap")
    def buscar(self, texto, opcoes):
        tem_filtro = any(opcoes.get(k) not in ("", None) for k in ("tag", "grupo", "desdeDias", "tamanhoMin", "tamanhoMax", "avaliacaoMin"))
        if (not texto.strip() and not tem_filtro) or self._caminho in (LIXEIRA, RECENTES):
            return
        if self._busca:
            self._busca.cancelar()
        self._modoBusca = self._buscando = True
        self._textoBusca = texto
        self._sel.clear()
        self._atual = -1
        self._modelo.redefinir([])
        self._grupos = []
        self.gruposMudou.emit()
        self.estadoMudou.emit()
        self.selecaoMudou.emit()
        self.atualMudou.emit()
        self._geracao += 1
        g = self._geracao
        conteudo = bool(opcoes.get("conteudo", False))
        ocultos = bool(opcoes.get("ocultos", self._ocultos))
        filtros = {k: opcoes[k] for k in ("tag", "grupo", "desdeDias", "tamanhoMin", "tamanhoMax", "avaliacaoMin")
                   if k in opcoes and opcoes[k] not in ("", None)}

        def parcial(lote):
            if not self._fechada and g == self._geracao:
                self._modelo.acrescentar(lote)

        def pronto(_):
            if not self._fechada and g == self._geracao:
                self._buscando = False
                self._busca = None
                self._agrupar()
                self.estadoMudou.emit()
        self._busca = rodar(B.buscar, self._caminho, texto, conteudo, ocultos, self._dono.idioma, filtros,
                            pronto=pronto, parcial=parcial)

    @pyqtSlot()
    def pararBusca(self):
        if self._busca:
            self._busca.cancelar()

    @pyqtSlot()
    def sairBusca(self):
        if not self._modoBusca:
            return
        self.pararBusca()
        self._busca = None
        self._modoBusca = self._buscando = False
        self._textoBusca = ""
        self._sel.clear()
        self._atual = -1
        self.estadoMudou.emit()
        self.selecaoMudou.emit()
        self._carregar(atualizar=False)

    # ---------------------------------------------------------------- seleção
    def _trocarSelecao(self, nova):
        mudou = self._sel.symmetric_difference(nova)
        if not mudou:
            return
        self._sel.clear()
        self._sel.update(nova)
        self._modelo.selecao_mudou(list(mudou))
        self.selecaoMudou.emit()

    @pyqtSlot(int, str)
    def selecionar(self, i, modo="unico"):
        itens = self._modelo.itens()
        if not 0 <= i < len(itens):
            return
        c = itens[i]["caminho"]
        if modo == "alternar":
            nova = set(self._sel) ^ {c}
            self._ancora = i
        elif modo == "adicionar":
            nova = set(self._sel) | {c}
            self._ancora = i
        elif modo == "intervalo":
            a = self._ancora if 0 <= self._ancora < len(itens) else i
            lo, hi = sorted((a, i))
            nova = {itens[k]["caminho"] for k in range(lo, hi + 1)}
        else:
            nova = {c}
            self._ancora = i
        self._trocarSelecao(nova)
        self.atual = i

    @pyqtSlot("QVariantList", bool)
    def selecionarIndices(self, indices, adicionar=False):
        itens = self._modelo.itens()
        nova = set(self._sel) if adicionar else set()
        nova.update(itens[int(k)]["caminho"] for k in indices if 0 <= int(k) < len(itens))
        self._trocarSelecao(nova)

    @pyqtSlot()
    def selecionarTudo(self):
        self._trocarSelecao({it["caminho"] for it in self._modelo.itens()})

    @pyqtSlot()
    def limparSelecao(self):
        self._trocarSelecao(set())

    @pyqtSlot(str, result=int)
    def indiceDe(self, caminho):
        return self._modelo.linha_de(caminho)

    @pyqtSlot(int, result="QVariantMap")
    def item(self, i):
        return self._modelo.item(i) or {}

    @pyqtSlot(str, result=int)
    def pularPara(self, prefixo):
        p = I.sem_acento(prefixo)
        if not p:
            return -1
        itens = self._modelo.itens()
        n = len(itens)
        ini = self._atual + 1 if len(prefixo) == 1 else max(self._atual, 0)   # mesma letra de novo: próximo
        for k in range(n):
            j = (ini + k) % n
            if I.sem_acento(itens[j]["nome"]).startswith(p):
                return j
        return -1

    # ---------------------------------------------------------------- propriedades
    @pyqtProperty(QObject, constant=True)
    def modelo(self):
        return self._modelo

    @pyqtProperty(str, notify=caminhoMudou)
    def caminho(self):
        return self._caminho

    @pyqtProperty(bool, notify=caminhoMudou)
    def ehLixeira(self):
        return self._caminho == LIXEIRA

    @pyqtProperty(bool, notify=caminhoMudou)
    def ehRecentes(self):
        return self._caminho == RECENTES

    @pyqtProperty(str, notify=caminhoMudou)
    def titulo(self):
        if self._caminho == LIXEIRA:
            return self._dono.t("locais.lixeira")
        if self._caminho == RECENTES:
            return self._dono.t("locais.recentes")
        if self._caminho == str(Path.home()):
            return "HOME"
        return os.path.basename(self._caminho) or "/"

    @pyqtProperty(str, notify=caminhoMudou)
    def codigo(self):
        if self._caminho in (LIXEIRA, RECENTES):
            return "0x7RA5H0" if self._caminho == LIXEIRA else "0xREC000"
        return I.codigo_caminho(self._caminho)

    @pyqtProperty("QVariantList", notify=caminhoMudou)
    def migalhas(self):
        if self._caminho == LIXEIRA:
            return [{"nome": self._dono.t("locais.lixeira"), "caminho": LIXEIRA, "codigo": "00"}]
        if self._caminho == RECENTES:
            return [{"nome": self._dono.t("locais.recentes"), "caminho": RECENTES, "codigo": "00"}]
        home = str(Path.home())
        p = self._caminho
        if p == home or p.startswith(home + "/"):
            res = [{"nome": "HOME", "caminho": home, "codigo": I.codigo_caminho(home)[-2:]}]
            resto = p[len(home):].strip("/")
            base = home
        else:
            res = [{"nome": "/", "caminho": "/", "codigo": I.codigo_caminho("/")[-2:]}]
            resto = p.strip("/")
            base = "/"
        for parte in [x for x in resto.split("/") if x]:
            base = os.path.join(base, parte)
            res.append({"nome": parte, "caminho": base, "codigo": I.codigo_caminho(base)[-2:]})   # 2 dígitos hex; o QML põe o "0x"
        return res

    @pyqtProperty(bool, notify=estadoMudou)
    def carregando(self):
        return self._carregando

    @pyqtProperty(str, notify=estadoMudou)
    def erro(self):
        return self._erro

    @pyqtProperty("QVariantList", notify=gruposMudou)
    def grupos(self):
        return self._grupos

    def _salvarPrefs(self):
        if getattr(self._dono, "lembrarVisaoPorPasta", False) and self._caminho:
            self._dono.guardarVisaoDaPasta(self._caminho, {"visao": self._visao, "ordem": self._ordem,
                                                           "decrescente": self._decrescente, "mostrarOcultos": self._ocultos,
                                 "agruparTipos": self._agruparTipos})
            return
        self._dono.lembrarPrefs({"visao": self._visao, "ordem": self._ordem, "decrescente": self._decrescente,
                                 "mostrarOcultos": self._ocultos,
                                 "agruparTipos": self._agruparTipos})

    @pyqtProperty(str, notify=opcoesMudou)
    def visao(self):
        return self._visao

    @visao.setter
    def visao(self, v):
        if v in VISOES and v != self._visao:
            self._visao = v
            if v == "pilhas":
                self._pedirAuto()
            self._salvarPrefs()
            self.opcoesMudou.emit()

    @pyqtProperty(str, notify=opcoesMudou)
    def ordem(self):
        return self._ordem

    @ordem.setter
    def ordem(self, v):
        if v in ORDENS and v != self._ordem:
            self._ordem = v
            self._salvarPrefs()
            self.opcoesMudou.emit()
            self._republicar()
            self._modelo.secoes_mudaram()

    @pyqtProperty(bool, notify=opcoesMudou)
    def decrescente(self):
        return self._decrescente

    @decrescente.setter
    def decrescente(self, v):
        if bool(v) != self._decrescente:
            self._decrescente = bool(v)
            self._salvarPrefs()
            self.opcoesMudou.emit()
            self._republicar()

    @pyqtProperty(bool, notify=opcoesMudou)
    def mostrarOcultos(self):
        return self._ocultos

    @mostrarOcultos.setter
    def mostrarOcultos(self, v):
        if bool(v) != self._ocultos:
            self._ocultos = bool(v)
            self._salvarPrefs()
            self.opcoesMudou.emit()
            self._republicar()
            self._subpastasDeNovo()
            pastas = []
            valores = {}
            for it in self._modelo.itens():
                if it["ehPasta"]:
                    guardado = self._filhos.get((it["caminho"], self._ocultos))
                    if guardado and guardado[0] == it["modificado"]:
                        valores[it["caminho"]] = {"filhos": guardado[1], "filhosLimite": guardado[2]}
                    else:
                        pastas.append(it["caminho"])
            self._modelo.atualizar_campos(valores)
            self._recontar(pastas)

    @pyqtProperty(bool, notify=opcoesMudou)
    def agruparTipos(self):
        return self._agruparTipos

    @agruparTipos.setter
    def agruparTipos(self, v):
        if bool(v) != self._agruparTipos:
            self._agruparTipos = bool(v)
            self._salvarPrefs()
            self.opcoesMudou.emit()

    @pyqtProperty(str, notify=opcoesMudou)
    def filtro(self):
        return self._filtro

    @filtro.setter
    def filtro(self, v):
        if v != self._filtro:
            self._filtro = v
            self.opcoesMudou.emit()
            self._republicar()

    def _republicar(self):
        if not self._modoBusca:
            self._publicar(atualizar=True)
            self.estadoMudou.emit()

    @pyqtProperty(int, notify=atualMudou)
    def atual(self):
        return self._atual

    @atual.setter
    def atual(self, v):
        v = int(v)
        if not -1 <= v < self._modelo.rowCount():
            v = -1
        if v != self._atual:
            self._atual = v
            self.atualMudou.emit()

    @pyqtProperty("QVariantList", notify=selecaoMudou)
    def selecionados(self):
        ordem = self._modelo.linha_de
        return sorted(self._sel, key=lambda c: ordem(c))

    @pyqtProperty(int, notify=selecaoMudou)
    def qtdSelecionados(self):
        return len(self._sel)

    @pyqtProperty(str, notify=selecaoMudou)
    def tamanhoSelecao(self):
        tot = 0
        for c in self._sel:
            it = self._modelo.item(self._modelo.linha_de(c))
            if it and it["tamanho"] > 0:
                tot += it["tamanho"]
        return I.tamanho_texto(tot, self._dono.idioma) if self._sel else ""

    @pyqtProperty(bool, notify=caminhoMudou)
    def podeVoltar(self):
        return bool(self._hist)

    @pyqtProperty(bool, notify=caminhoMudou)
    def podeAvancar(self):
        return bool(self._futuro)

    @pyqtProperty(bool, notify=estadoMudou)
    def buscando(self):
        return self._buscando

    @pyqtProperty(bool, notify=estadoMudou)
    def modoBusca(self):
        return self._modoBusca

    @pyqtProperty(str, notify=estadoMudou)
    def textoBusca(self):
        return self._textoBusca

    @pyqtProperty(str, notify=estadoMudou)
    def contagem(self):
        itens = self._modelo.itens()
        pastas = sum(1 for it in itens if it["ehPasta"])
        return self._dono.t("rodape.contagem", n=len(itens), pastas=pastas)

    @pyqtProperty(str, notify=caminhoMudou)
    def livre(self):
        alvo = str(L.lixeira_home()) if self._caminho in (LIXEIRA, RECENTES) else self._caminho
        try:
            sv = os.statvfs(alvo)
            return I.tamanho_texto(sv.f_bavail * sv.f_frsize, self._dono.idioma)
        except OSError:
            return ""

    # usado pelo objeto principal
    def pasta_real(self):
        return None if self._caminho in (LIXEIRA, RECENTES) else self._caminho

    def idioma_mudou(self):
        self.caminhoMudou.emit()
        self._carregar(atualizar=True)
