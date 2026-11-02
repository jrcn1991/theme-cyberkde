"""Busca recursiva por nome (e, se pedido, por conteúdo de arquivos de texto) numa thread. Os
resultados saem em lotes por `tarefa.parcial`, para a interface ir mostrando."""

import os
import time

from PyQt6.QtCore import QMimeDatabase

from . import itens as I

LIMITE_RESULTADOS = 5000
LIMITE_CONTEUDO = 4 * 1024 * 1024   # não lê arquivos maiores que isso na busca por conteúdo
_PULAR = {".git", "node_modules", "__pycache__", ".cache", ".venv", "venv"}


def _tem_no_conteudo(caminho, alvo_bytes):
    try:
        if os.path.getsize(caminho) > LIMITE_CONTEUDO:
            return False
        with open(caminho, "rb") as f:
            dados = f.read()
    except OSError:
        return False
    if b"\0" in dados[:2048]:
        return False   # binário
    return alvo_bytes in dados.lower()


def _passa(it, filtros):
    """Filtros da busca (como os do Dolphin): etiqueta, tipo (grupo), modificado nos últimos N dias,
    faixa de tamanho e avaliação mínima."""
    if "tag" in filtros and filtros["tag"] not in it["tags"]:
        return False
    if "grupo" in filtros and it["grupo"] != filtros["grupo"]:
        return False
    if "desdeDias" in filtros and it["modificado"] / 1000 < time.time() - float(filtros["desdeDias"]) * 86400:
        return False
    if "tamanhoMin" in filtros and (it["ehPasta"] or it["tamanho"] < int(filtros["tamanhoMin"])):
        return False
    if "tamanhoMax" in filtros and (it["ehPasta"] or it["tamanho"] > int(filtros["tamanhoMax"])):
        return False
    if "avaliacaoMin" in filtros and it["avaliacao"] < int(filtros["avaliacaoMin"]):
        return False
    return True


def buscar(tarefa, raiz, texto, conteudo=False, ocultos=False, idioma="pt_BR", filtros=None):
    db = QMimeDatabase()
    filtros = filtros or {}
    alvo = I.sem_acento(texto.strip())
    alvo_bytes = texto.strip().lower().encode("utf-8", "ignore")
    if not alvo and not filtros:
        return 0
    lote, total, ultimo = [], 0, time.monotonic()
    pilha = [raiz]
    while pilha:
        if tarefa.cancelada():
            break
        pasta = pilha.pop()
        try:
            entradas = sorted(os.scandir(pasta), key=lambda e: e.name)
        except OSError:
            continue
        for e in entradas:
            if tarefa.cancelada():
                break
            if not ocultos and e.name.startswith("."):
                continue
            try:
                eh_dir = e.is_dir(follow_symlinks=False)
            except OSError:
                eh_dir = False
            if eh_dir and e.name not in _PULAR:
                pilha.append(e.path)
            achou = alvo in I.sem_acento(e.name)   # texto vazio: "" está em tudo (só os filtros decidem)
            if not achou and alvo and conteudo and not eh_dir and e.is_file():
                achou = _tem_no_conteudo(e.path, alvo_bytes)
            if achou:
                it = I.ler_item(e.path, db, e, idioma)
                if it and _passa(it, filtros):
                    lote.append(it)
                    total += 1
            if lote and (len(lote) >= 200 or time.monotonic() - ultimo > 0.15):
                tarefa.parcial(lote)
                lote, ultimo = [], time.monotonic()
            if total >= LIMITE_RESULTADOS:
                tarefa.cancelar()
                break
    if lote:
        tarefa.parcial(lote)
    return total
