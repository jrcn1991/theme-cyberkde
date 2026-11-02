"""Subpastas reais de cada pasta, para a visão PILHAS (spec seção 19): as primeiras 8 em ordem
natural, total de subpastas e de arquivos soltos. Leitura numa fila própria, preguiçosa (só o que a
interface pede), com cache por mtime e sem nunca ler montagens de rede em segundo plano."""

import os
import time
from collections import OrderedDict

from PyQt6.QtCore import QThreadPool

from . import itens as I

LIMITE_LISTA = 8
LIMITE_ENTRADAS = 50000
ORCAMENTO_CONTAGEM = 0.8     # s: depois disso, as contagens das subpastas ficam -1
TEMPO_LIMITE_MS = 3000
_TAM_CACHE = 4000

_FS_REDE = {"nfs", "nfs4", "cifs", "smb3", "smbfs", "sshfs", "fuse.sshfs", "davfs", "fuse.davfs2", "fuse.rclone",
            "9p", "afs", "ceph", "glusterfs", "fuse.glusterfs", "fuse.gvfsd-fuse", "ncpfs", "fuse.s3fs",
            "fuse.curlftpfs", "fuse.smbnetfs", "fuse.onedriver", "fuse.gcsfuse", "lustre", "beegfs", "fuse.juicefs"}

VAZIO = {"subpastas": [], "subpastasTotal": -1, "arquivosTotal": -1, "subpastasEstado": ""}

_cache = OrderedDict()       # (caminho, ocultos) -> (modificado_ms, resultado)
_pool = None
_montagens = {"quando": 0.0, "lista": []}


def pool():
    global _pool
    if _pool is None:
        _pool = QThreadPool()
        _pool.setMaxThreadCount(3)
    return _pool


def _ler_montagens():
    agora = time.monotonic()
    if agora - _montagens["quando"] > 2:
        lst = []
        try:
            with open("/proc/mounts") as f:
                for ln in f:
                    p = ln.split()
                    if len(p) >= 3:
                        lst.append((p[1].replace("\\040", " "), p[2]))
        except OSError:
            pass
        lst.sort(key=lambda m: len(m[0]), reverse=True)
        _montagens.update(quando=agora, lista=lst)
    return _montagens["lista"]


def eh_rede(caminho):
    """Pelo /proc/mounts (sem tocar no caminho, que pode estar pendurado)."""
    for mnt, fs in _ler_montagens():
        if caminho == mnt or caminho.startswith(mnt.rstrip("/") + "/"):
            return fs in _FS_REDE or fs.startswith("fuse.sshfs")
    return False


def do_cache(caminho, ocultos, modificado):
    v = _cache.get((caminho, ocultos))
    if v and v[0] == modificado:
        _cache.move_to_end((caminho, ocultos))
        return v[1]
    return None


def guardar(caminho, ocultos, modificado, resultado):
    if resultado.get("subpastasEstado") in ("ok", "limite", "erro"):
        _cache[(caminho, ocultos)] = (modificado, resultado)
        _cache.move_to_end((caminho, ocultos))
        while len(_cache) > _TAM_CACHE:
            _cache.popitem(last=False)


def ler(caminho, ocultos):
    """Roda numa thread. Devolve (modificado_ms, resultado)."""
    try:
        st = os.stat(caminho)
        modificado, dev = int(st.st_mtime * 1000), st.st_dev
    except OSError:
        return 0, {"subpastas": [], "subpastasTotal": 0, "arquivosTotal": 0, "subpastasEstado": "erro"}
    pastas, arquivos, n, estado = [], 0, 0, "ok"
    try:
        with os.scandir(caminho) as it:
            for e in it:
                n += 1
                if n > LIMITE_ENTRADAS:
                    estado = "limite"
                    break
                if not ocultos and e.name.startswith("."):
                    continue
                try:
                    eh_pasta = e.is_dir()          # segue links: link para pasta conta como pasta
                except OSError:
                    eh_pasta = False
                if eh_pasta:
                    try:
                        ino = e.inode()   # sem stat a mais (vem do readdir)
                    except OSError:
                        ino = 0
                    pastas.append((e.name, e.path, ino))
                else:
                    arquivos += 1
    except OSError:
        return modificado, {"subpastas": [], "subpastasTotal": 0, "arquivosTotal": 0, "subpastasEstado": "erro"}
    pastas.sort(key=lambda p: I.chave_natural(p[0]))
    inicio = time.monotonic()
    lista = []
    for nome, sub, ino in pastas[:LIMITE_LISTA]:
        itens = -1
        if time.monotonic() - inicio < ORCAMENTO_CONTAGEM and not eh_rede(sub):
            itens = I.contar_filhos(sub) if ocultos else _contar_visiveis(sub)
        lista.append({"nome": nome, "caminho": sub, "itens": itens, "codigo": I.codigo(ino, dev)})
    return modificado, {"subpastas": lista, "subpastasTotal": len(pastas), "arquivosTotal": arquivos,
                        "subpastasEstado": estado}


def _contar_visiveis(caminho, limite=999):
    n = 0
    try:
        with os.scandir(caminho) as it:
            for e in it:
                if not e.name.startswith("."):
                    n += 1
                    if n >= limite:
                        break
    except OSError:
        return 0
    return n
