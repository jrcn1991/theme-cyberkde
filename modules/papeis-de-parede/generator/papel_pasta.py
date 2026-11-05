#!/usr/bin/env python3
"""Pasta de papéis de parede da pessoa ("cyberkde efeito papel-pasta"): lista, miniaturas e quadro do bloqueio.

Os arquivos da pessoa só são lidos: o tema guarda o caminho e, em ~/.cache/cyberkde/papel-pasta, as miniaturas
(480x270, WebP) e o quadro de cada vídeo para a tela de bloqueio (JPEG, no tamanho do vídeo). O cache vale enquanto
o arquivo de origem não mudar (mtime); miniaturas de arquivos que saíram da pasta são apagadas na listagem.

  papel_pasta.py listar PASTA [--atual ID]   -> JSON [{id, nome, tipo, caminho, miniatura, atual}] (pasta ausente: [])
  papel_pasta.py item PASTA ID               -> "tipo<TAB>caminho" do item (sai 1 se não existe ou não é suportado)
  papel_pasta.py quadro VIDEO                -> caminho do quadro do vídeo (aos ~2 s), para o bloqueio

Só o primeiro nível da pasta, sem ocultos, em ordem alfabética (sem diferença de maiúsculas e acentos).
Miniaturas: ffmpeg nos vídeos (quadro aos ~2 s, ou o primeiro em vídeos curtos), ImageMagick nas imagens.
"""

import concurrent.futures
import hashlib
import json
import os
import shutil
import subprocess
import sys
import unicodedata

IMAGENS = {".jpg", ".jpeg", ".png", ".webp"}
VIDEOS = {".mp4", ".webm", ".mkv", ".mov"}
MINI = (480, 270)


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "cyberkde", "papel-pasta")


def tipo_de(nome):
    ext = os.path.splitext(nome)[1].lower()
    return "imagem" if ext in IMAGENS else "video" if ext in VIDEOS else None


def chave_ordem(nome):
    sem = "".join(c for c in unicodedata.normalize("NFKD", nome) if not unicodedata.combining(c))
    return (sem.casefold(), nome)


def itens(pasta):
    """[(id, tipo, caminho)] do primeiro nível; pasta ausente ou ilegível: []."""
    try:
        nomes = os.listdir(pasta)
    except OSError:
        return []
    r = []
    for n in sorted(nomes, key=chave_ordem):
        if n.startswith("."):
            continue
        t = tipo_de(n)
        c = os.path.join(pasta, n)
        if t and os.path.isfile(c):
            r.append((n, t, os.path.abspath(c)))
    return r


def _nome_cache(caminho, sufixo):
    return os.path.join(cache_dir(), hashlib.sha1(caminho.encode("utf-8", "surrogateescape")).hexdigest()[:20] + sufixo)


def _valido(saida, origem):
    try:
        return os.path.getsize(saida) > 0 and os.path.getmtime(saida) >= os.path.getmtime(origem)
    except OSError:
        return False


def _rodar(cmd):
    try:
        return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def _quadro_video(video, saida, filtro=None):
    """Quadro aos 2 s (ou o primeiro, se o vídeo for mais curto) -> saida."""
    if not shutil.which("ffmpeg"):
        return False
    vf = ["-vf", filtro] if filtro else []
    for ss in ("2", "0"):
        try:
            os.unlink(saida)
        except OSError:
            pass
        ok = _rodar(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", ss, "-i", video, "-frames:v", "1",
                     *vf, "-q:v", "2", saida])
        if ok and os.path.exists(saida) and os.path.getsize(saida) > 0:
            return True
    return False


def miniatura(caminho, tipo):
    """Miniatura 480x270 (preenche e recorta) em cache; None se não deu para gerar."""
    saida = _nome_cache(caminho, ".webp")
    if _valido(saida, caminho):
        return saida
    os.makedirs(cache_dir(), exist_ok=True)
    tmp = saida + ".novo.webp"
    w, h = MINI
    if tipo == "video":
        ok = _quadro_video(caminho, tmp, f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}")
    else:
        im = shutil.which("magick") or shutil.which("convert")
        # [0]: só o primeiro quadro (WebP animado); -auto-orient segue o EXIF das fotos.
        ok = bool(im) and _rodar([im, caminho + "[0]", "-auto-orient", "-thumbnail", f"{w}x{h}^", "-gravity", "center",
                                  "-extent", f"{w}x{h}", "-quality", "85", tmp])
    if not ok:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return None
    os.replace(tmp, saida)
    return saida


def quadro(video):
    """Quadro do vídeo no tamanho dele, para a tela de bloqueio; None se não deu."""
    saida = _nome_cache(video, "-quadro.jpg")
    if _valido(saida, video):
        return saida
    os.makedirs(cache_dir(), exist_ok=True)
    tmp = saida + ".novo.jpg"
    if not _quadro_video(video, tmp):
        return None
    os.replace(tmp, saida)
    # Só o quadro do vídeo em uso fica (o bloqueio aponta para ele).
    for f in os.listdir(cache_dir()):
        p = os.path.join(cache_dir(), f)
        if f.endswith("-quadro.jpg") and p != saida:
            try:
                os.unlink(p)
            except OSError:
                pass
    return saida


def listar(pasta, atual=""):
    lst = itens(pasta) if pasta else []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, os.cpu_count() or 1)) as ex:
        minis = list(ex.map(lambda it: miniatura(it[2], it[1]), lst))
    # Miniaturas de arquivos que não estão mais na pasta.
    if lst and os.path.isdir(cache_dir()):
        manter = {os.path.basename(m) for m in minis if m}
        for f in os.listdir(cache_dir()):
            if f.endswith(".webp") and f not in manter:
                try:
                    os.unlink(os.path.join(cache_dir(), f))
                except OSError:
                    pass
    return [{"id": i, "nome": os.path.splitext(i)[0], "tipo": t, "caminho": c, "miniatura": m, "atual": i == atual}
            for (i, t, c), m in zip(lst, minis)]


def main(a):
    if len(a) >= 2 and a[0] == "listar":
        atual = a[a.index("--atual") + 1] if "--atual" in a[2:-1] else ""
        print(json.dumps(listar(a[1], atual), ensure_ascii=False))
        return 0
    if len(a) == 3 and a[0] == "item":
        if "/" in a[2] or a[2].startswith("."):
            return 1
        for i, t, c in itens(a[1]):
            if i == a[2]:
                print(f"{t}\t{c}")
                return 0
        return 1
    if len(a) == 2 and a[0] == "quadro":
        q = quadro(os.path.abspath(a[1]))
        if not q:
            return 1
        print(q)
        return 0
    print(__doc__.strip().split("\n\n")[2], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
