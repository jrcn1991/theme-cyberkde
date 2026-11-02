"""Desfazer (Ctrl+Z) da última operação, como o KIO do Dolphin. Cada entrada vem do `registro` da
operação (só o que ela criou ou moveu) ou de uma ação imediata (renomear, tags, permissões).

Regras de segurança:
- desfazer uma CRIAÇÃO (copiar, duplicar, link, nova pasta/arquivo, compactar, extrair) manda o item
  criado para a LIXEIRA (dá para recuperar), e só se ele não mudou desde a operação (mtime);
- desfazer um MOVER/RENOMEAR devolve o item ao lugar antigo; se o lugar antigo foi ocupado, usa um nome
  livre ao lado ("nome (2)") em vez de substituir;
- desfazer "mover para a lixeira" restaura; apagar permanentemente não tem desfazer.
"""

import os

from PyQt6.QtCore import QFile

from . import itens as I
from . import lixeira as L
from . import operacoes as O
from . import tags as T

LIMITE = 30

# tipo da operação -> como desfazer
CRIACAO = {"copiar", "duplicar", "link", "compactar", "extrair", "novaPasta", "novoArquivo", "modelo"}
MOVIMENTO = {"mover", "renomear", "renomearLote"}


def tipo_desfazer(tipo_op):
    if tipo_op in CRIACAO:
        return "criados"
    if tipo_op in MOVIMENTO:
        return "movidos"
    if tipo_op == "lixeira":
        return "lixeira"
    if tipo_op == "restaurar":
        return "restaurados"
    if tipo_op in ("permissoes", "tags"):
        return tipo_op
    return None


_TEXTO_OK = {"criados": "desfazer.criados", "movidos": "desfazer.movidos", "lixeira": "desfazer.lixeira",
             "restaurados": "desfazer.restaurados", "permissoes": "desfazer.permissoes", "tags": "desfazer.tags"}


def executar(op, tipo, itens, traduzir=None, rotulo=""):
    """Roda na fila (thread). `itens` na ordem da operação; desfaz de trás para a frente.
    Com `traduzir`, deixa em op.mensagem_ok o que aconteceu ("Cópia desfeita: 1 item foi para a lixeira")."""
    _executar(op, tipo, itens)
    if traduzir:
        n = len(itens) - len(op.erros)
        chave = _TEXTO_OK.get(tipo, "op.desfazer") + (".um" if n == 1 else ".varios")
        op.mensagem_ok = traduzir(chave, rotulo=rotulo, n=n)


def _executar(op, tipo, itens):
    op.total = len(itens)
    op.estado = "rodando"
    if tipo == "movidos":
        _desfazer_movidos(op, itens)
        return
    for it in reversed(itens):
        op.checar()
        try:
            if tipo == "criados":
                _desfazer_criado(op, it)
            elif tipo == "lixeira":
                op.atual = os.path.basename(it["de"])
                O.restaurar(op, [it["para"]])
                op.total = len(itens)
                continue   # restaurar já soma
            elif tipo == "restaurados":
                _para_lixeira(op, it["para"])
            elif tipo == "permissoes":
                os.chmod(it["caminho"], it["modo"])
            elif tipo == "tags":
                T.gravar(it["caminho"], it["antes"])
        except O.Cancelado:
            raise
        except OSError as e:
            op.erro(it.get("para") or it.get("caminho", ""), e)
        op.somar(0, 1)


def _mudou(it):
    try:
        return os.lstat(it["para"]).st_mtime_ns != it["mtime"]
    except OSError:
        return True


def _para_lixeira(op, caminho):
    op.atual = os.path.basename(caminho)
    ok, _ = L.para_lixeira(caminho)
    if not ok:
        raise OSError("erro.semLixeira")


def _desfazer_criado(op, it):
    if not os.path.lexists(it["para"]):
        return   # já não existe: nada a desfazer
    if _mudou(it):
        raise OSError("erro.desfazerModificado")
    _para_lixeira(op, it["para"])


def _desfazer_movidos(op, itens):
    """Duas fases, como a renomeação em lote: tudo para nomes temporários, depois para o lugar
    antigo. Assim cadeias (foto1→foto2, foto2→foto3) voltam certinho."""
    temporarios = []
    for k, it in enumerate(itens):
        op.checar()
        if not os.path.lexists(it["para"]):
            op.erro(it["para"], "erro.desfazerSumiu")
            op.somar(0, 1)
            continue
        tmp = os.path.join(os.path.dirname(it["para"]), f".datashard-desfazer-{os.getpid()}-{k}")
        try:
            os.rename(it["para"], tmp)
            temporarios.append((tmp, it))
        except OSError as e:
            op.erro(it["para"], e)
            op.somar(0, 1)
    for tmp, it in temporarios:
        try:
            _desfazer_movido(op, {"de": it["de"], "para": tmp})
        except OSError as e:
            try:
                os.rename(tmp, it["para"])   # não deu: volta para onde estava
            except OSError:
                pass
            op.erro(it["para"], e)
        op.somar(0, 1)


def _desfazer_movido(op, it):
    de, para = it["de"], it["para"]
    op.atual = os.path.basename(para)
    if not os.path.lexists(para):
        raise OSError("erro.desfazerSumiu")
    pasta = os.path.dirname(de)
    os.makedirs(pasta, exist_ok=True)
    alvo = de if not os.path.lexists(de) else os.path.join(pasta, I.nome_livre(pasta, os.path.basename(de)))
    try:
        os.rename(para, alvo)
    except OSError:
        if O._copiar_item(op, para, alvo):    # outra partição
            O._remover(para)
        else:
            raise OSError("erro.origemMantida")


class Pilha:
    def __init__(self):
        self._entradas = []

    def empilhar(self, tipo, rotulo, itens):
        if tipo and itens:
            self._entradas.append({"tipo": tipo, "rotulo": rotulo, "itens": list(itens)})
            del self._entradas[:-LIMITE]

    def tirar(self):
        return self._entradas.pop() if self._entradas else None

    def topo(self):
        return self._entradas[-1] if self._entradas else None

    def limpar(self):
        self._entradas.clear()
