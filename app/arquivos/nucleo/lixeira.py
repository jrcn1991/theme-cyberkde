"""Lixeira freedesktop (spec Trash 1.0): a da HOME e as `.Trash-<uid>` / `.Trash/<uid>` na raiz dos
discos montados. Mover PARA a lixeira é com QFile.moveToTrash (em operacoes.py); aqui ficam listar,
achar o .trashinfo e calcular o que restaurar."""

import os
from pathlib import Path
from urllib.parse import unquote

from . import itens as I

UID = os.getuid()


def lixeira_home():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "Trash"


def para_lixeira(caminho):
    """QFile.moveToTrash, garantindo antes o XDG_DATA_HOME (sem ele o Qt não cria ~/.local/share/Trash
    e falha, como numa conta nova). Devolve (ok, caminho_na_lixeira)."""
    from PyQt6.QtCore import QFile
    try:
        lixeira_home().parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    except OSError:
        pass
    return QFile.moveToTrash(caminho)


def pontos_montagem():
    """Pontos de montagem de discos reais (sem /proc, /sys, tmpfs...)."""
    pts = []
    try:
        with open("/proc/mounts") as f:
            for ln in f:
                p = ln.split()
                if len(p) >= 3 and p[0].startswith("/dev/") and not p[0].startswith("/dev/loop"):
                    pts.append(p[1].replace("\\040", " "))
    except OSError:
        pass
    return pts


def so_home():
    """CYBERKDE_ARQUIVOS_LIXEIRAS=home: só a lixeira da HOME (testes com HOME falso não podem ver nem
    esvaziar as .Trash-<uid> dos discos de verdade)."""
    return os.environ.get("CYBERKDE_ARQUIVOS_LIXEIRAS", "") == "home"


def lixeiras():
    """[(pasta_da_lixeira, topo)] existentes. `topo` = None para a da HOME (Path absoluto no .trashinfo)."""
    res = []
    h = lixeira_home()
    if (h / "files").is_dir():
        res.append((h, None))
    for mnt in ([] if so_home() else pontos_montagem()):
        for cand in (Path(mnt) / f".Trash-{UID}", Path(mnt) / ".Trash" / str(UID)):
            try:
                if (cand / "files").is_dir() and cand.resolve() != h.resolve():
                    res.append((cand, Path(mnt)))
            except OSError:
                pass
    return res


def ler_info(arq_info, topo):
    origem, data = "", ""
    try:
        for ln in Path(arq_info).read_text(errors="replace").splitlines():
            if ln.startswith("Path="):
                origem = unquote(ln[5:])
            elif ln.startswith("DeletionDate="):
                data = ln[13:].replace("T", " ")[:16]
    except OSError:
        return "", ""
    if origem and not origem.startswith("/") and topo is not None:
        origem = str(topo / origem)
    return origem, data


def info_de(caminho):
    """Para um caminho dentro de .../Trash/files: (arquivo .trashinfo, origem). (None, "") se não for."""
    p = Path(caminho)
    if p.parent.name != "files":
        return None, ""
    base = p.parent.parent
    topo = None
    for lx, tp in lixeiras():
        if lx == base:
            topo = tp
            break
    info = base / "info" / (p.name + ".trashinfo")
    origem, _ = ler_info(info, topo)
    return info, origem


def eh_da_lixeira(caminho):
    p = Path(caminho)
    return p.parent.name == "files" and any(p.parent == lx / "files" for lx, _ in lixeiras())


def listar(db=None, idioma="pt_BR", tarefa=None):
    saida = []
    for lx, topo in lixeiras():
        try:
            entradas = list(os.scandir(lx / "files"))
        except OSError:
            continue
        for e in entradas:
            if tarefa is not None and tarefa.cancelada():
                return saida
            it = I.ler_item(e.path, db, e, idioma)
            if it is None:
                continue
            origem, data = ler_info(lx / "info" / (e.name + ".trashinfo"), topo)
            if origem:
                it["nome"] = os.path.basename(origem) or it["nome"]
                it["origem"] = origem
                it["pastaPai"] = os.path.dirname(origem)
                it["local"] = I.abreviar(it["pastaPai"])
            it["apagadoEm"] = data
            it["oculto"] = False   # na lixeira tudo aparece
            saida.append(it)
    return saida


def quantidade():
    n = 0
    for lx, _ in lixeiras():
        try:
            n += sum(1 for _ in os.scandir(lx / "files"))
        except OSError:
            pass
    return n
