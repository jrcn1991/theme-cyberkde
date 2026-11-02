#!/usr/bin/env python3
"""Auxiliar do Cyber Fence: criar e renomear a pasta da cerca, e mover ou copiar o que foi solto nela.

Nunca sobrescreve: nome repetido devolve uma proposta ("Nome 2") ou, ao soltar, entra com sufixo. Responde
uma linha de JSON. Uso:
  cerca.py criar <base> <nome>
  cerca.py renomear <pasta> <nome>
  cerca.py soltar mover|copiar <destino> <url>...
  cerca.py desfazer <diario>
  cerca.py lista                        a pasta oculta de uma cerca "lista"
  cerca.py ligar <pasta> <url>...       entra na lista: link, cópia do .desktop ou atalho web
  cerca.py remover-vazia <pasta>        cerca cancelada: só apaga a pasta se ela estiver vazia
"""
import glob
import json
import os
import shutil
import sys
import stat
import tempfile
import time
import unicodedata
import uuid
from urllib.parse import unquote, urlsplit


def limpar(nome):
    """O nome de uma pasta: sem barra nem controle, sem ponto na frente, e cabendo no sistema de arquivos."""
    n = "".join(" " if c in "/\\" or unicodedata.category(c) == "Cc" else c for c in nome)
    n = " ".join(n.split()).lstrip(".").rstrip(". ").strip()
    while len(n.encode()) > 240:
        n = n[:-1]
    return n.rstrip(". ")


def livre(pasta, nome):
    """O primeiro de nome, "nome 2", "nome 3"... que ainda não existe (a extensão fica no fim)."""
    if not os.path.lexists(os.path.join(pasta, nome)):
        return nome
    base, ext = os.path.splitext(nome)
    if base.endswith(".tar"):
        base, ext = base[:-4], ".tar" + ext
    n = 2
    while os.path.lexists(os.path.join(pasta, f"{base} {n}{ext}")):
        n += 1
    return f"{base} {n}{ext}"


def criar(base, nome):
    nome = limpar(nome)
    if not nome:
        return {"ok": False, "erro": "nome"}
    base = os.path.expanduser(base)
    os.makedirs(base, exist_ok=True)
    caminho = os.path.join(base, nome)
    try:
        os.mkdir(caminho)
    except FileExistsError:
        return {"ok": False, "erro": "conflito", "proposta": livre(base, nome)}
    return {"ok": True, "caminho": caminho, "nome": nome}


def renomear(pasta, nome):
    nome = limpar(nome)
    pasta = os.path.expanduser(pasta).rstrip("/")
    if not nome:
        return {"ok": False, "erro": "nome"}
    if not os.path.isdir(pasta):
        return {"ok": False, "erro": "sumiu"}
    pai = os.path.dirname(pasta)
    novo = os.path.join(pai, nome)
    if novo == pasta:
        return {"ok": True, "caminho": pasta, "nome": nome}
    # só a caixa mudou num sistema que não diferencia: é a mesma pasta, não um conflito
    if os.path.lexists(novo) and not os.path.samefile(pasta, novo):
        return {"ok": False, "erro": "conflito", "proposta": livre(pai, nome)}
    os.rename(pasta, novo)
    return {"ok": True, "caminho": novo, "nome": nome}


def caminho_de(url):
    if url.startswith("/"):
        return url
    u = urlsplit(url)
    return unquote(u.path) if u.scheme == "file" and u.netloc in ("", "localhost") else None


def transferir(acao, origem, destino):
    if acao == "mover":
        shutil.move(origem, destino)            # entre discos, copia e apaga
    elif os.path.isdir(origem) and not os.path.islink(origem):
        shutil.copytree(origem, destino, symlinks=True)
    else:
        shutil.copy2(origem, destino, follow_symlinks=False)


def novo_diario():
    pasta = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    for velho in glob.glob(os.path.join(pasta, "cyberkde-cerca-*.json")):
        try:
            if time.time() - os.path.getmtime(velho) > 3600:     # o toast de desfazer já acabou
                os.unlink(velho)
        except OSError:
            pass
    fd, nome = tempfile.mkstemp(prefix="cyberkde-cerca-", suffix=".json", dir=pasta)
    return fd, nome


def soltar(acao, destino, urls):
    destino = os.path.realpath(os.path.expanduser(destino))
    feitos, falhas, ignorados = [], [], 0
    if not os.path.isdir(destino):
        return {"ok": False, "erro": "sumiu"}
    for url in urls:
        origem = caminho_de(url)
        if not origem or not os.path.lexists(origem):
            falhas.append(url)
            continue
        origem = origem.rstrip("/") or "/"
        real = os.path.realpath(origem)
        if acao == "mover" and os.path.dirname(os.path.abspath(origem)) == destino:
            ignorados += 1                      # já está aqui
            continue
        if os.path.isdir(real) and not os.path.islink(origem) and (destino == real or destino.startswith(real + "/")):
            falhas.append(url)                  # uma pasta para dentro dela mesma
            continue
        final = os.path.join(destino, livre(destino, os.path.basename(origem)))
        try:
            transferir(acao, origem, final)
            feitos.append([origem, final])
        except OSError as erro:
            falhas.append(f"{url}: {erro}")
    r = {"ok": True, "acao": acao, "n": len(feitos), "ignorados": ignorados, "falhas": falhas}
    if feitos and acao == "mover":
        fd, r["diario"] = novo_diario()
        with os.fdopen(fd, "w") as f:
            json.dump(feitos, f)
    return r


def desfazer(diario):
    with open(diario) as f:
        feitos = json.load(f)
    n, falhas = 0, []
    for origem, final in reversed(feitos):
        try:
            if origem is None:                  # entrou na lista: sai só o link
                os.unlink(final)
                n += 1
                continue
            if not os.path.lexists(final) or os.path.lexists(origem):
                raise OSError("o arquivo mudou de lugar")
            os.makedirs(os.path.dirname(origem), exist_ok=True)
            shutil.move(final, origem)
            n += 1
        except OSError as erro:
            falhas.append(f"{final}: {erro}")
    os.unlink(diario)
    return {"ok": True, "acao": "desfazer", "n": n, "falhas": falhas}


def lista():
    dados = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    caminho = os.path.join(dados, "cyberkde", "cercas", uuid.uuid4().hex[:12])
    os.makedirs(caminho, exist_ok=True)
    return {"ok": True, "caminho": caminho}


def ligar(pasta, urls):
    """Na cerca "lista" nada sai do lugar: arquivo vira link; .desktop, cópia executável; site, um Link."""
    pasta = os.path.expanduser(pasta)
    feitos, falhas = [], []
    for url in urls:
        try:
            origem = caminho_de(url)
            if origem is None:
                u = urlsplit(url)
                if u.scheme not in ("http", "https"):
                    raise OSError("tipo de link não aceito")
                nome = limpar(u.netloc) or "link"
                final = os.path.join(pasta, livre(pasta, nome + ".desktop"))
                with open(final, "x") as f:
                    f.write(f"[Desktop Entry]\nType=Link\nName={nome}\nIcon=text-html\nURL={url}\n")
            elif not os.path.lexists(origem):
                raise OSError("não existe")
            elif origem.endswith(".desktop"):
                final = os.path.join(pasta, livre(pasta, os.path.basename(origem)))
                shutil.copy2(origem, final)
                os.chmod(final, os.stat(final).st_mode | stat.S_IXUSR)
            else:
                final = os.path.join(pasta, livre(pasta, os.path.basename(origem.rstrip("/"))))
                os.symlink(origem, final)
            feitos.append([None, final])
        except OSError as erro:
            falhas.append(f"{url}: {erro}")
    r = {"ok": True, "acao": "ligar", "n": len(feitos), "ignorados": 0, "falhas": falhas}
    if feitos:
        fd, r["diario"] = novo_diario()
        with os.fdopen(fd, "w") as f:
            json.dump(feitos, f)
    return r


def remover_vazia(pasta):
    try:
        os.rmdir(os.path.expanduser(pasta))     # rmdir nunca apaga conteúdo
    except OSError:
        return {"ok": False, "erro": "nao-vazia"}
    return {"ok": True}


def principal(a):
    if len(a) == 3 and a[0] == "criar":
        return criar(a[1], a[2])
    if len(a) == 3 and a[0] == "renomear":
        return renomear(a[1], a[2])
    if len(a) >= 4 and a[0] == "soltar" and a[1] in ("mover", "copiar"):
        return soltar(a[1], a[2], a[3:])
    if len(a) == 2 and a[0] == "desfazer":
        return desfazer(a[1])
    if len(a) == 1 and a[0] == "lista":
        return lista()
    if len(a) >= 3 and a[0] == "ligar":
        return ligar(a[1], a[2:])
    if len(a) == 2 and a[0] == "remover-vazia":
        return remover_vazia(a[1])
    return {"ok": False, "erro": "uso"}


if __name__ == "__main__":
    try:
        print(json.dumps(principal(sys.argv[1:]), ensure_ascii=False))
    except OSError as e:
        print(json.dumps({"ok": False, "erro": "sistema", "detalhe": str(e)}, ensure_ascii=False))
