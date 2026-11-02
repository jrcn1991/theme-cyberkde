"""Renomeação em lote (como a do Dolphin, mais buscar/trocar). Primeiro a prévia, depois a operação.

regra (mapa):
  {"modo": "padrao", "padrao": "Foto ###", "inicio": 1, "passo": 1}   # # = número com zeros
  {"modo": "substituir", "buscar": "x", "trocar": "y", "regex": false, "caixaSensivel": false, "extensao": false}
  {"modo": "caixa", "caixa": "maiusculas"|"minusculas"|"titulo", "extensao": false}
  {"modo": "acrescentar", "prefixo": "", "sufixo": ""}                # o sufixo vai antes da extensão
A extensão é mantida, salvo "extensao": true (substituir/caixa)."""

import os
import re

from . import itens as I


def _partes(nome):
    if nome.startswith(".") and nome.count(".") == 1:
        return nome, ""
    base, ext = os.path.splitext(nome)
    if base.endswith(".tar"):
        base, ext = base[:-4], ".tar" + ext
    return base, ext


def novo_nome(nome, regra, k):
    modo = regra.get("modo", "padrao")
    base, ext = _partes(nome)
    if modo == "padrao":
        padrao = str(regra.get("padrao") or "").strip() or base
        if "#" not in padrao:
            padrao += " #"
        n = int(regra.get("inicio", 1)) + k * int(regra.get("passo", 1))
        novo = re.sub(r"#+", lambda m: str(n).zfill(len(m.group(0))), padrao, count=1)
        return novo + ext
    if modo == "substituir":
        alvo = nome if regra.get("extensao") else base
        buscar, trocar = str(regra.get("buscar", "")), str(regra.get("trocar", ""))
        if not buscar:
            return nome
        flags = 0 if regra.get("caixaSensivel") else re.IGNORECASE
        padrao = buscar if regra.get("regex") else re.escape(buscar)
        try:
            feito = re.sub(padrao, trocar if regra.get("regex") else (lambda _m: trocar), alvo, flags=flags)
        except re.error:
            return None
        return feito if regra.get("extensao") else feito + ext
    if modo == "caixa":
        alvo = nome if regra.get("extensao") else base
        caixa = regra.get("caixa", "minusculas")
        feito = alvo.upper() if caixa == "maiusculas" else alvo.lower() if caixa == "minusculas" else alvo.title()
        return feito if regra.get("extensao") else feito + ext
    if modo == "acrescentar":
        return f"{regra.get('prefixo', '')}{base}{regra.get('sufixo', '')}{ext}"
    return None


def previa(caminhos, regra):
    """[{de, nome, novo, conflito}] — conflito: "" | "invalido" | "existe" | "repetido" | "igual"."""
    res = []
    finais = {}
    origens = set(os.path.normpath(c) for c in caminhos)
    for k, c in enumerate(caminhos):
        c = os.path.normpath(c)
        nome = os.path.basename(c)
        novo = novo_nome(nome, regra, k)
        conflito = ""
        if not novo or "/" in novo or novo in (".", "..") or "\0" in novo:
            conflito = "invalido"
        elif novo == nome:
            conflito = "igual"
        else:
            alvo = os.path.join(os.path.dirname(c), novo)
            if alvo in finais:
                conflito = "repetido"
            elif os.path.lexists(alvo) and alvo not in origens:
                conflito = "existe"
            finais.setdefault(alvo, c)
        res.append({"de": c, "nome": nome, "novo": novo or "", "conflito": conflito})
    return res


def aplicar(op, caminhos, regra):
    """Roda na fila. Duas fases (nome temporário, depois o final) para trocas como a→b, b→a."""
    plano = [p for p in previa(caminhos, regra) if not p["conflito"]]
    for p in previa(caminhos, regra):
        if p["conflito"] not in ("", "igual"):
            op.erro(p["de"], f"erro.lote.{p['conflito']}")
    op.total = len(plano)
    op.estado = "rodando"
    temporarios = []
    for k, p in enumerate(plano):
        op.checar()
        tmp = os.path.join(os.path.dirname(p["de"]), f".datashard-lote-{os.getpid()}-{k}")
        try:
            os.rename(p["de"], tmp)
            temporarios.append((tmp, p))
        except OSError as e:
            op.erro(p["de"], e)
    for tmp, p in temporarios:
        alvo = os.path.join(os.path.dirname(p["de"]), p["novo"])
        op.atual = p["novo"]
        try:
            if os.path.lexists(alvo):   # apareceu no meio do caminho: não substitui
                alvo = os.path.join(os.path.dirname(alvo), I.nome_livre(os.path.dirname(alvo), p["novo"]))
            os.rename(tmp, alvo)
            op.registrar(alvo, p["de"])
        except OSError as e:
            try:
                os.rename(tmp, p["de"])   # devolve o nome antigo
            except OSError:
                pass
            op.erro(p["de"], e)
        op.somar(0, 1)
