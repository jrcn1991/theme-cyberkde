"""Fila de operações de arquivo (spec seção 9 e 14.5). Uma operação roda por vez numa thread; a fila
publica o progresso a cada 100 ms. Conflitos pausam o trabalhador até a interface responder.

Regras de segurança: apagar só pela lixeira (QFile.moveToTrash), exceto `apagar`/`esvaziar`, que só
chegam aqui depois da ficha de confirmação (principal.py). Mover entre partições só remove a origem
depois de copiar tudo sem erro nem item pulado."""

import os
import re
import shutil
import stat
import subprocess
import threading
import time
import zipfile

from PyQt6.QtCore import QFile, QObject, QThreadPool, QTimer, pyqtSignal

from . import itens as I
from . import lixeira as L
from .tarefas import rodar

BLOCO = 1024 * 1024
# operações cujos destinos o QML seleciona ao terminar (U3)
_COM_DESTINO = {"copiar", "mover", "duplicar", "link", "compactar", "extrair", "restaurar", "renomearLote"}
ESTADOS_FIM = ("ok", "erro", "cancelada")
_SUFIXOS_TAR = (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tgz", ".tbz2", ".txz", ".tar")
SUFIXOS = _SUFIXOS_TAR + (".zip", ".7z", ".rar", ".gz", ".bz2", ".xz", ".zst", ".iso", ".jar", ".cpio")


class Cancelado(Exception):
    pass


class Operacao:
    _proximo = 1

    def __init__(self, tipo, rotulo, fn, args):
        self.id = Operacao._proximo
        Operacao._proximo += 1
        self.tipo, self.rotulo, self.fn, self.args = tipo, rotulo, fn, args
        self.estado = "fila"
        self.progresso = 0.0
        self.feitos = self.total = 0
        self.bytes_feitos = self.bytes_total = 0
        self.atual = ""
        self.erros = []
        self.registro = []      # o que a operação fez de fato, para o desfazer (desfazer.py)
        self.destinos = []      # todo destino final (inclusive o que substituiu/mesclou): o QML seleciona
        self.mensagem_ok = ""   # texto de sucesso próprio (o desfazer diz o que aconteceu)
        self.conflito = None
        self.inicio = 0.0
        self.mensagem = ""
        self._cancelar = threading.Event()
        self._resposta = threading.Event()
        self._acao = None
        self._acao_todos = None

    # ---- chamadas do trabalhador
    def checar(self):
        if self._cancelar.is_set():
            raise Cancelado()

    def somar(self, nbytes=0, itens=0):
        self.bytes_feitos += nbytes
        self.feitos += itens
        if self.bytes_total > 0:
            self.progresso = min(1.0, self.bytes_feitos / self.bytes_total)
        elif self.total > 0:
            self.progresso = min(1.0, self.feitos / self.total)

    def erro(self, caminho, msg):
        self.erros.append((caminho, str(msg)))

    def registrar(self, para, de=""):
        """Só itens novos (o destino não existia): desfazer nunca pode jogar fora o que já havia."""
        try:
            mt = os.lstat(para).st_mtime_ns
        except OSError:
            return
        self.registro.append({"de": de, "para": para, "mtime": mt})
        self.destinos.append(para)

    def perguntar(self, origem, destino):
        """Pausa até a interface escolher substituir/pular/renomear."""
        if self._acao_todos:
            return self._acao_todos
        self.conflito = _descrever_conflito(origem, destino)
        self._resposta.clear()
        self.estado = "conflito"
        while not self._resposta.wait(0.2):
            self.checar()
        self.checar()
        self.conflito = None
        self.estado = "rodando"
        return self._acao

    # ---- chamadas da interface
    def responder(self, acao, todos):
        if acao not in ("substituir", "pular", "renomear"):
            acao = "pular"
        self._acao = acao
        if todos:
            self._acao_todos = acao
        # a interface já vê a resposta (sem esperar o trabalhador acordar)
        self.conflito = None
        self.estado = "rodando"
        self._resposta.set()

    def cancelar(self):
        self._cancelar.set()
        if self.estado == "conflito":
            self.conflito = None
            self.estado = "rodando"   # até o trabalhador parar e virar "cancelada"
        self._resposta.set()

    def mapa(self, idioma):
        vel = ""
        if self.estado == "rodando" and self.inicio and self.bytes_feitos:
            dt = time.monotonic() - self.inicio
            if dt > 0.3:
                vel = I.tamanho_texto(int(self.bytes_feitos / dt), idioma) + "/s"
        bytes_txt = ""
        if self.bytes_total > 0:
            bytes_txt = f"{I.tamanho_texto(self.bytes_feitos, idioma)} / {I.tamanho_texto(self.bytes_total, idioma)}"
        return {
            "id": self.id, "tipo": self.tipo, "rotulo": self.rotulo, "estado": self.estado,
            "progresso": -1 if self.estado == "contando" else round(self.progresso, 4),
            "feitos": self.feitos, "total": self.total, "bytesTexto": bytes_txt, "velocidade": vel,
            "atual": self.atual, "erro": self.mensagem if self.estado == "erro" else "",
            "conflito": self.conflito or {},
            "desfazivel": bool(self.registro) and self.tipo != "desfazer" and self.estado in ("ok", "erro", "cancelada"),
            "criados": list(self.destinos) if self.tipo in _COM_DESTINO else [],
        }


def _curto(caminho):
    casa = os.path.expanduser("~")
    return "~" + caminho[len(casa):] if caminho == casa or caminho.startswith(casa + "/") else caminho


def _descrever_conflito(origem, destino):
    def info(p):
        try:
            st = os.stat(p)
            return (stat.S_ISDIR(st.st_mode), st.st_size, I.data_texto(st.st_mtime))
        except OSError:
            return (False, 0, "")
    po, pd = info(origem), info(destino)
    return {"origem": _curto(origem), "destino": _curto(destino), "origemCompleta": origem, "destinoCompleto": destino, "nome": os.path.basename(destino), "ehPasta": po[0],
            "destinoEhPasta": pd[0], "tamanhoOrigem": I.tamanho_texto(po[1]) if not po[0] else "",
            "tamanhoDestino": I.tamanho_texto(pd[1]) if not pd[0] else "", "dataOrigem": po[2], "dataDestino": pd[2]}


# ======================================================================= trabalhadores

def _tamanho_arvore(op, caminho):
    """(bytes, itens) sem seguir links."""
    try:
        st = os.lstat(caminho)
    except OSError:
        return 0, 0
    if not stat.S_ISDIR(st.st_mode):
        return st.st_size, 1
    total, n = 0, 1
    for raiz, dirs, arqs in os.walk(caminho):
        op.checar()
        for nome in arqs + [d for d in dirs if os.path.islink(os.path.join(raiz, d))]:
            try:
                total += os.lstat(os.path.join(raiz, nome)).st_size
            except OSError:
                pass
            n += 1
        n += len(dirs)
    return total, n


def _para_lixeira_ou_erro(caminho):
    ok, _ = L.para_lixeira(caminho)
    if not ok:
        raise OSError(f"não foi possível mandar para a lixeira: {caminho}")


def _remover(caminho):
    if os.path.isdir(caminho) and not os.path.islink(caminho):
        shutil.rmtree(caminho)
    else:
        os.unlink(caminho)


def _copiar_arquivo(op, src, alvo):
    tmp = os.path.join(os.path.dirname(alvo), f".{os.path.basename(alvo)}.datashard-{os.getpid()}.part")
    op.atual = os.path.basename(src)
    try:
        with open(src, "rb") as fi, open(tmp, "wb") as fo:
            while True:
                op.checar()
                bloco = fi.read(BLOCO)
                if not bloco:
                    break
                fo.write(bloco)
                op.somar(len(bloco))
        shutil.copystat(src, tmp, follow_symlinks=False)
        if os.path.isdir(alvo) and not os.path.islink(alvo):
            _para_lixeira_ou_erro(alvo)   # pasta substituída por arquivo: a pasta vai para a lixeira
        os.replace(tmp, alvo)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _copiar_item(op, src, alvo, perguntar_dentro=True):
    """Copia src para alvo (alvo pode existir: arquivo é substituído, pasta é mesclada).
    Devolve True se tudo foi copiado (nada pulado nem com erro)."""
    op.checar()
    try:
        st = os.lstat(src)
    except OSError as e:
        op.erro(src, e)
        return False
    try:
        if stat.S_ISLNK(st.st_mode):
            if os.path.lexists(alvo):
                if os.path.isdir(alvo) and not os.path.islink(alvo):
                    _para_lixeira_ou_erro(alvo)
                else:
                    os.unlink(alvo)
            os.symlink(os.readlink(src), alvo)
            op.somar(st.st_size, 1)
            return True
        if stat.S_ISDIR(st.st_mode):
            if os.path.lexists(alvo) and not os.path.isdir(alvo):
                _para_lixeira_ou_erro(alvo)
            os.makedirs(alvo, exist_ok=True)
            op.somar(0, 1)
            tudo = True
            for e in sorted(os.scandir(src), key=lambda x: x.name):
                filho = os.path.join(alvo, e.name)
                if os.path.lexists(filho) and not (e.is_dir(follow_symlinks=False) and os.path.isdir(filho)):
                    acao = op.perguntar(e.path, filho) if perguntar_dentro else "substituir"
                    if acao == "pular":
                        b, _ = _tamanho_arvore(op, e.path)
                        op.somar(b, 1)
                        tudo = False
                        continue
                    if acao == "renomear":
                        filho = os.path.join(alvo, I.nome_livre(alvo, e.name))
                tudo = _copiar_item(op, e.path, filho, perguntar_dentro) and tudo
            shutil.copystat(src, alvo, follow_symlinks=False)
            return tudo
        if stat.S_ISREG(st.st_mode):
            _copiar_arquivo(op, src, alvo)
            op.somar(0, 1)
            return True
        op.erro(src, "tipo especial (fifo/dispositivo/socket) não copiado")
        return False
    except Cancelado:
        raise
    except OSError as e:
        op.erro(src, e)
        return False


def _mesmo_disco(a, b):
    try:
        return os.lstat(a).st_dev == os.stat(b).st_dev
    except OSError:
        return False


def copiar_mover(op, origens, destino, mover):
    op.estado = "contando"
    destino = os.path.normpath(destino)
    if not os.path.isdir(destino):
        raise OSError(f"destino não é uma pasta: {destino}")
    origens = [os.path.normpath(o) for o in origens]
    for o in origens:
        b, n = _tamanho_arvore(op, o)
        op.bytes_total += b
        op.total += n
    op.estado = "rodando"
    op.inicio = time.monotonic()
    for src in origens:
        op.checar()
        nome = os.path.basename(src)
        if not os.path.lexists(src):
            op.erro(src, "não existe mais")
            continue
        if mover and os.path.dirname(src) == destino:
            b, n = _tamanho_arvore(op, src)
            op.somar(b, n)
            continue
        if destino == src or destino.startswith(src.rstrip("/") + "/"):
            op.erro(src, "erro.dentroDeSi")
            continue
        alvo = os.path.join(destino, nome)
        if os.path.lexists(alvo):
            if os.path.dirname(src) == destino:   # colar na mesma pasta: cópia com nome novo
                alvo = os.path.join(destino, I.nome_livre(destino, nome))
            else:
                acao = op.perguntar(src, alvo)
                if acao == "pular":
                    b, n = _tamanho_arvore(op, src)
                    op.somar(b, n)
                    continue
                if acao == "renomear":
                    alvo = os.path.join(destino, I.nome_livre(destino, nome))
        existia = os.path.lexists(alvo)
        if mover and _mesmo_disco(src, destino):
            op.atual = nome
            b, n = _tamanho_arvore(op, src)
            try:
                if not os.path.lexists(alvo):
                    os.rename(src, alvo)
                    op.registrar(alvo, src)
                    op.somar(b, n)
                    continue
                if not os.path.isdir(src) and not os.path.isdir(alvo):
                    os.replace(src, alvo)   # substituir arquivo por arquivo
                    op.destinos.append(alvo)
                    op.somar(b, n)
                    continue
            except OSError as e:
                op.erro(src, e)
                continue
        ok = _copiar_item(op, src, alvo)
        if mover:
            if ok:
                try:
                    _remover(src)
                    if not existia:
                        op.registrar(alvo, src)
                    else:
                        op.destinos.append(alvo)
                except OSError as e:
                    op.erro(src, e)
            else:
                op.erro(src, "erro.origemMantida")
        elif not existia:
            op.registrar(alvo, src)
        elif ok:
            op.destinos.append(alvo)   # substituiu/mesclou: não se desfaz, mas é o resultado


def para_lixeira(op, caminhos):
    op.total = len(caminhos)
    op.estado = "rodando"
    for c in caminhos:
        op.checar()
        op.atual = os.path.basename(c)
        ok, na_lixeira = L.para_lixeira(c)
        if not ok:
            op.erro(c, "erro.semLixeira")
        else:
            op.registrar(na_lixeira, c)
        op.somar(0, 1)


def apagar(op, caminhos):
    op.total = len(caminhos)
    op.estado = "rodando"
    for c in caminhos:
        op.checar()
        op.atual = os.path.basename(c)
        try:
            _remover(c)
        except OSError as e:
            op.erro(c, e)
        op.somar(0, 1)


def restaurar(op, caminhos):
    op.total = len(caminhos)
    op.estado = "rodando"
    for c in caminhos:
        op.checar()
        info, origem = L.info_de(c)
        op.atual = os.path.basename(origem or c)
        if not origem or not os.path.lexists(c):
            op.erro(c, "erro.semInfoLixeira")
            op.somar(0, 1)
            continue
        pasta = os.path.dirname(origem)
        try:
            os.makedirs(pasta, exist_ok=True)
            alvo = origem if not os.path.lexists(origem) else os.path.join(pasta, I.nome_livre(pasta, os.path.basename(origem)))
            try:
                os.rename(c, alvo)
            except OSError:
                if _copiar_item(op, c, alvo):
                    _remover(c)
                else:
                    raise OSError("erro.origemMantida")
            if info and info.exists():
                info.unlink()
            op.registrar(alvo, c)
        except OSError as e:
            op.erro(c, e)
        op.somar(0, 1)


def esvaziar(op):
    entradas = []
    for lx, _ in L.lixeiras():
        for sub in ("files", "info"):
            try:
                entradas += [e.path for e in os.scandir(lx / sub)]
            except OSError:
                pass
        if (lx / "directorysizes").exists():
            entradas.append(str(lx / "directorysizes"))
    op.total = len(entradas)
    op.estado = "rodando"
    for c in entradas:
        op.checar()
        op.atual = os.path.basename(c)
        try:
            _remover(c)
        except OSError as e:
            op.erro(c, e)
        op.somar(0, 1)


def ligar(op, origens, destino):
    op.total = len(origens)
    op.estado = "rodando"
    for src in origens:
        op.checar()
        nome = I.nome_livre(destino, os.path.basename(src.rstrip("/")))
        try:
            os.symlink(src, os.path.join(destino, nome))
            op.registrar(os.path.join(destino, nome), src)
        except OSError as e:
            op.erro(src, e)
        op.somar(0, 1)


def _rodar_processo(op, cmd, cwd=None, apagar_se_falhar=None):
    """Roda 7z/tar lendo a porcentagem (7z -bsp1) da saída. Cancelar mata o processo."""
    op.inicio = time.monotonic()
    proc = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    erro_txt = []

    def ler_err():
        erro_txt.append(proc.stderr.read().decode(errors="replace"))
    th = threading.Thread(target=ler_err, daemon=True)
    th.start()
    fd = proc.stdout.fileno()
    os.set_blocking(fd, False)
    try:
        while True:
            if op._cancelar.is_set():
                proc.terminate()
                try:
                    proc.wait(3)
                except subprocess.TimeoutExpired:
                    proc.kill()
                raise Cancelado()
            try:
                dados = os.read(fd, 4096)
            except BlockingIOError:
                dados = None
            if dados:
                pcts = re.findall(rb"(\d{1,3})%", dados)
                if pcts:
                    op.progresso = min(1.0, int(pcts[-1]) / 100)
            elif dados == b"" and proc.poll() is not None:
                break
            else:
                time.sleep(0.05)
        proc.wait()
        th.join(1)
        if proc.returncode not in (0, 1):   # 7z: 1 = aviso
            raise OSError((erro_txt[0] if erro_txt else "").strip()[-400:] or f"{cmd[0]} saiu com {proc.returncode}")
    except BaseException:
        if apagar_se_falhar and os.path.lexists(apagar_se_falhar):
            try:
                _remover(apagar_se_falhar)
            except OSError:
                pass
        raise


def compactar(op, caminhos, destino, formato):
    op.estado = "rodando"
    op.progresso = -1 if formato == "targz" or not shutil.which("7z") else 0
    pai = os.path.commonpath([os.path.dirname(os.path.normpath(c)) for c in caminhos])
    rel = [os.path.relpath(os.path.normpath(c), pai) for c in caminhos]
    pasta_dest = os.path.dirname(destino)
    destino = os.path.join(pasta_dest, I.nome_livre(pasta_dest, os.path.basename(destino)))
    op.atual = os.path.basename(destino)
    op.total = len(caminhos)
    if formato == "targz":
        _rodar_processo(op, ["tar", "-czf", destino, "-C", pai, "--"] + rel, apagar_se_falhar=destino)
    elif shutil.which("7z"):
        tipo = "-tzip" if formato == "zip" else "-t7z"
        _rodar_processo(op, ["7z", "a", tipo, "-bsp1", "-bb0", "-y", destino, "--"] + rel, cwd=pai,
                        apagar_se_falhar=destino)
    elif formato == "zip":
        _zip_python(op, pai, rel, destino)
    else:
        raise OSError("7z não instalado")
    op.feitos = op.total
    op.progresso = 1.0
    op.registrar(destino)
    return destino


def _zip_python(op, pai, rel, destino):
    arquivos = []
    for r in rel:
        p = os.path.join(pai, r)
        if os.path.isdir(p) and not os.path.islink(p):
            for raiz, dirs, arqs in os.walk(p):
                arquivos.append(raiz)
                arquivos += [os.path.join(raiz, a) for a in arqs]
        else:
            arquivos.append(p)
    try:
        with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED) as z:
            for k, p in enumerate(arquivos):
                op.checar()
                z.write(p, os.path.relpath(p, pai))
                op.progresso = (k + 1) / len(arquivos)
    except BaseException:
        if os.path.exists(destino):
            os.unlink(destino)
        raise


def eh_compactado(caminho):
    n = caminho.lower()
    return n.endswith(_SUFIXOS_TAR + (".zip", ".7z", ".rar", ".gz", ".bz2", ".xz", ".zst", ".iso", ".jar", ".cpio"))


def extrair(op, arquivo, destino):
    op.estado = "rodando"
    nome = os.path.basename(arquivo)
    eh_tar = nome.lower().endswith(_SUFIXOS_TAR)
    if not destino:
        pai = os.path.dirname(arquivo)
        base = nome
        for suf in _SUFIXOS_TAR + (".zip", ".7z", ".rar", ".gz", ".bz2", ".xz", ".zst", ".iso", ".jar", ".cpio"):
            if base.lower().endswith(suf):
                base = base[: -len(suf)]
                break
        destino = os.path.join(pai, I.nome_livre(pai, base or nome + ".d"))
    novo = not os.path.exists(destino)
    os.makedirs(destino, exist_ok=True)
    op.atual = nome
    lixo = destino if novo else None
    if eh_tar:
        op.progresso = -1
        _rodar_processo(op, ["tar", "-xf", arquivo, "-C", destino], apagar_se_falhar=lixo)
    elif shutil.which("7z"):
        _rodar_processo(op, ["7z", "x", f"-o{destino}", "-aou", "-bsp1", "-bb0", "-y", "--", arquivo],
                        apagar_se_falhar=lixo)
    elif nome.lower().endswith(".zip"):
        try:
            with zipfile.ZipFile(arquivo) as z:
                z.extractall(destino)   # zipfile já descarta caminhos absolutos e ".."
        except BaseException:
            if lixo:
                shutil.rmtree(lixo, ignore_errors=True)
            raise
    else:
        raise OSError("7z não instalado")
    op.progresso = 1.0
    if novo:
        op.registrar(destino)
    return destino


# ======================================================================= fila

class Fila(QObject):
    mudou = pyqtSignal()
    terminou = pyqtSignal(int, str, str)       # id, estado, texto
    terminouOp = pyqtSignal(object)            # a Operacao (criados, desfazível)
    concluida = pyqtSignal(int, str, object)   # id, tipo, resultado (para recarregar o que mudou)
    registrada = pyqtSignal(object)            # a Operacao terminada (registro para o desfazer)

    def __init__(self, traduzir, idioma, parent=None):
        super().__init__(parent)
        self._t = traduzir
        self._idioma = idioma
        self._ops = []
        self._rodando = None
        self._pool = QThreadPool(self)
        self._pool.setMaxThreadCount(1)
        self._relogio = QTimer(self, interval=100)
        self._relogio.timeout.connect(self.mudou.emit)

    def enfileirar(self, tipo, rotulo, fn, *args):
        op = Operacao(tipo, rotulo, fn, args)
        self._ops.append(op)
        self._aparar()
        self.mudou.emit()
        self._proxima()
        return op.id

    def _aparar(self):
        fim = [o for o in self._ops if o.estado in ESTADOS_FIM]
        for o in fim[:-20]:
            self._ops.remove(o)

    def _proxima(self):
        if self._rodando:
            return
        op = next((o for o in self._ops if o.estado == "fila"), None)
        if not op:
            self._relogio.stop()
            return
        self._rodando = op
        op.estado = "rodando"
        op.inicio = time.monotonic()
        self._relogio.start()
        rodar(self._trabalhar, op, pronto=lambda r: self._fim(op, r), pool=self._pool)

    @staticmethod
    def _trabalhar(_tarefa, op):
        return op.fn(op, *op.args)

    def _fim(self, op, r):
        self._rodando = None
        if isinstance(r, Cancelado) or op._cancelar.is_set():
            op.estado = "cancelada"
            op.mensagem = op.rotulo
        elif isinstance(r, Exception):
            op.estado = "erro"
            op.mensagem = self._msg(str(r))
        elif op.erros:
            op.estado = "erro"
            c, m = op.erros[0]
            op.mensagem = f"{os.path.basename(c)}: {self._msg(m)}"
            if len(op.erros) > 1:
                op.mensagem += " " + self._t("op.maisErros", n=len(op.erros) - 1)
        else:
            op.estado = "ok"
            op.progresso = 1.0
            op.mensagem = op.mensagem_ok or op.rotulo   # a interface acrescenta o estado ("· CONCLUÍDO")
        op.conflito = None
        self.mudou.emit()
        self.terminouOp.emit(op)
        self.terminou.emit(op.id, op.estado, op.mensagem)
        self.concluida.emit(op.id, op.tipo, r)
        if op.registro:
            self.registrada.emit(op)
        self._proxima()

    def _msg(self, m):
        return self._t(m) if m.startswith("erro.") else m

    # ---- interface
    def lista(self):
        idioma = self._idioma()
        return [o.mapa(idioma) for o in self._ops]

    def ocupado(self):
        return self._rodando is not None

    def cancelar(self, oid):
        for o in self._ops:
            if o.id == oid:
                if o.estado == "fila":
                    o.estado = "cancelada"
                    o.mensagem = o.rotulo
                    self.terminouOp.emit(o)
                    self.terminou.emit(o.id, o.estado, o.mensagem)
                o.cancelar()
        self.mudou.emit()

    def resolver(self, oid, acao, todos):
        for o in self._ops:
            if o.id == oid and o.estado == "conflito":
                o.responder(acao, todos)

    def encerrar(self, ms=3000):
        """Saída do app: cancela tudo (inclusive quem espera resposta de conflito) e espera o
        trabalhador parar; sem isso o QThreadPool segura o fim do processo."""
        for o in self._ops:
            if o.estado not in ESTADOS_FIM:
                o.cancelar()
        self._pool.waitForDone(ms)

    def limpar(self):
        self._ops = [o for o in self._ops if o.estado not in ESTADOS_FIM]
        self.mudou.emit()

    def esperar(self, ms=30000):
        """Para testes e para sair: espera a fila esvaziar processando eventos."""
        from PyQt6.QtCore import QCoreApplication, QElapsedTimer
        rel = QElapsedTimer()
        rel.start()
        while (self._rodando or any(o.estado == "fila" for o in self._ops)) and rel.elapsed() < ms:
            QCoreApplication.processEvents()
            time.sleep(0.01)


# ======================================================================= permissões (chmod em lote)

_SIMB = re.compile(r"^[ugoa]*[-+=][rwxXst]*$")


def modo_valido(m):
    m = (m or "").strip()
    if re.fullmatch(r"[0-7]{3,4}", m):
        return True
    return bool(m) and all(_SIMB.match(p) for p in m.split(","))


def aplicar_modo(atual, mudanca, eh_pasta):
    """Novo modo a partir do atual: octal ("644") ou simbólico como o chmod ("u+x,go-w,a+X")."""
    mudanca = mudanca.strip()
    if re.fullmatch(r"[0-7]{3,4}", mudanca):
        return int(mudanca, 8)
    modo = stat.S_IMODE(atual)
    for parte in mudanca.split(","):
        m = re.match(r"^([ugoa]*)([-+=])([rwxXst]*)$", parte)
        quem, opr, bits = m.groups()
        quem = quem or "a"
        if "a" in quem:
            quem = "ugo"
        mascara = 0
        for q in quem:
            desloc = {"u": 6, "g": 3, "o": 0}[q]
            for b in bits:
                if b == "r":
                    mascara |= 4 << desloc
                elif b == "w":
                    mascara |= 2 << desloc
                elif b == "x" or (b == "X" and (eh_pasta or modo & 0o111)):
                    mascara |= 1 << desloc
                elif b == "s" and q in "ug":
                    mascara |= stat.S_ISUID if q == "u" else stat.S_ISGID
                elif b == "t" and q == "o":
                    mascara |= stat.S_ISVTX
        if opr == "+":
            modo |= mascara
        elif opr == "-":
            modo &= ~mascara
        else:
            limpar = 0
            for q in quem:
                limpar |= 0o7 << {"u": 6, "g": 3, "o": 0}[q]
            modo = (modo & ~limpar) | mascara
    return modo


def permissoes(op, caminhos, mudanca, recursivo):
    alvos = []
    for c in caminhos:
        alvos.append(c)
        if recursivo and os.path.isdir(c) and not os.path.islink(c):
            for raiz, dirs, arqs in os.walk(c):
                op.checar()
                alvos += [os.path.join(raiz, n) for n in dirs + arqs]
    op.total = len(alvos)
    op.estado = "rodando"
    for c in alvos:
        op.checar()
        op.atual = os.path.basename(c)
        try:
            st = os.lstat(c)
            if stat.S_ISLNK(st.st_mode):   # chmod de link mexeria no alvo: pula
                op.somar(0, 1)
                continue
            novo = aplicar_modo(st.st_mode, mudanca, stat.S_ISDIR(st.st_mode))
            if novo != stat.S_IMODE(st.st_mode):
                os.chmod(c, novo)
                op.registro.append({"caminho": c, "modo": stat.S_IMODE(st.st_mode)})
        except OSError as e:
            op.erro(c, e)
        op.somar(0, 1)
