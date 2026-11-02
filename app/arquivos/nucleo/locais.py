"""Barra de Locais: pastas XDG, favoritos (os do Dolphin em user-places.xbel, só leitura, mais os
próprios), dispositivos (lsblk + /proc/mounts, só leitura) e recentes (recently-used.xbel)."""

import json
import os
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlparse

from PyQt6.QtCore import QStandardPaths

from . import itens as I

_XDG = (
    (QStandardPaths.StandardLocation.DesktopLocation, "user-desktop"),
    (QStandardPaths.StandardLocation.DocumentsLocation, "folder-documents"),
    (QStandardPaths.StandardLocation.DownloadLocation, "folder-download"),
    (QStandardPaths.StandardLocation.MusicLocation, "folder-music"),
    (QStandardPaths.StandardLocation.PicturesLocation, "folder-pictures"),
    (QStandardPaths.StandardLocation.MoviesLocation, "folder-videos"),
)


def dir_dados():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")


def pastas_xdg():
    """[(caminho, ícone)] das pastas XDG existentes, começando pela HOME."""
    home = str(Path.home())
    res = [(home, "user-home")]
    for loc, icone in _XDG:
        p = QStandardPaths.writableLocation(loc)
        if p and p != home and os.path.isdir(p) and all(p != r[0] for r in res):
            res.append((p, icone))
    return res


def _url_para_caminho(href):
    u = urlparse(href)
    if u.scheme != "file":
        return None
    return unquote(u.path)


def favoritos_dolphin():
    arq = dir_dados() / "user-places.xbel"
    res = []
    try:
        raiz = ET.parse(arq).getroot()
    except (OSError, ET.ParseError):
        return res
    for bm in raiz.iter("bookmark"):
        caminho = _url_para_caminho(bm.get("href", ""))
        if not caminho or not os.path.isdir(caminho):
            continue
        oculto = any((el.text or "").strip() == "true" for el in bm.iter() if el.tag.endswith("IsHidden"))
        if oculto:
            continue
        titulo = bm.findtext("title") or os.path.basename(caminho) or caminho
        icone = "folder"
        for el in bm.iter():
            if el.tag.endswith("icon") and el.get("name"):
                icone = el.get("name")
        res.append((caminho, titulo, icone))
    return res


def recentes(limite=12):
    """Arquivos e pastas locais de recently-used.xbel que ainda existem, do mais novo ao mais velho."""
    arq = dir_dados() / "recently-used.xbel"
    vistos = []
    try:
        raiz = ET.parse(arq).getroot()
    except (OSError, ET.ParseError):
        return []
    for bm in raiz.iter("bookmark"):
        caminho = _url_para_caminho(bm.get("href", ""))
        if caminho and os.path.exists(caminho):
            vistos.append((bm.get("visited") or bm.get("modified") or "", caminho))
    vistos.sort(reverse=True)
    res, ja = [], set()
    for _, c in vistos:
        if c not in ja:
            ja.add(c)
            res.append(c)
        if len(res) >= limite:
            break
    return res


# ---- dispositivos

_IGNORAR_MONTAGEM = ("/boot", "/boot/efi", "[SWAP]")


def ler_dispositivos(_tarefa=None):
    """Lista de dicionários (spec 14.4, seção dispositivos). Roda numa thread (lsblk pode demorar)."""
    if not shutil.which("lsblk"):
        return []
    try:
        saida = subprocess.run(
            ["lsblk", "-J", "-b", "-o", "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINTS,RM,HOTPLUG,TYPE,MODEL"],
            capture_output=True, text=True, timeout=5).stdout
        arvore = json.loads(saida).get("blockdevices", [])
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    res = []

    def visitar(dev, pai=None):
        for filho in dev.get("children") or []:
            visitar(filho, dev)
        tipo = dev.get("type")
        fs = dev.get("fstype")
        if tipo == "loop" or not fs or fs in ("swap", "crypto_LUKS", "LVM2_member", "linux_raid_member"):
            return
        montagens = [m for m in (dev.get("mountpoints") or []) if m]
        if any(m in _IGNORAR_MONTAGEM or m.startswith("/snap") for m in montagens):
            return
        mnt = montagens[0] if montagens else ""
        removivel = bool(dev.get("rm") or dev.get("hotplug") or (pai or {}).get("rm") or (pai or {}).get("hotplug"))
        tam = dev.get("size") or 0
        livre = uso = None
        if mnt:
            try:
                sv = os.statvfs(mnt)
                total = sv.f_blocks * sv.f_frsize
                livre = sv.f_bavail * sv.f_frsize
                uso = 1 - (livre / total) if total else 0
            except OSError:
                pass
        nome = dev.get("label") or ("/" if mnt == "/" else "") or \
            f"{I.tamanho_texto(tam)} {fs}".strip()
        res.append({
            "nome": nome,
            "caminho": mnt,
            "dispositivo": dev.get("path") or f"/dev/{dev.get('name')}",
            "montado": bool(mnt),
            "removivel": removivel,
            "sistema": fs,
            "tamanho": tam,
            "livre": livre if livre is not None else -1,
            "uso": round(uso, 3) if uso is not None else -1,
            "raiz": mnt == "/",
            "icone": "drive-removable-media-usb" if removivel else ("drive-harddisk-root" if mnt == "/" else "drive-harddisk"),
            "codigo": "DEV_" + (dev.get("name") or "").upper(),
            "modelo": (pai or dev).get("model") or "",
        })

    for d in arvore:
        visitar(d)
    res.sort(key=lambda d: (not d["raiz"], d["removivel"], I.chave_natural(d["nome"])))
    return res


_CAMPOS_DISPOSITIVO = {"nome": "", "caminho": "", "dispositivo": "", "montado": False, "removivel": False,
                       "sistema": "", "tamanho": 0, "livre": -1, "uso": -1, "raiz": False, "icone": "drive-harddisk",
                       "codigo": "", "modelo": ""}


def dispositivos_falsos():
    """SÓ PARA TESTES (U29): CYBERKDE_ARQUIVOS_DISPOSITIVOS=<arquivo.json> troca o lsblk real por uma
    lista fictícia ([{nome, dispositivo, caminho, montado, removivel, sistema, tamanho, ...}]). Com ela,
    montar/desmontar/ejetar são SIMULADOS (nenhum udisksctl roda). None se a variável não existe."""
    arq = os.environ.get("CYBERKDE_ARQUIVOS_DISPOSITIVOS", "")
    if not arq:
        return None
    try:
        lista = json.loads(Path(arq).read_text())
    except (OSError, ValueError):
        return []
    res = []
    for k, d in enumerate(lista if isinstance(lista, list) else []):
        if not isinstance(d, dict):
            continue
        d = {**_CAMPOS_DISPOSITIVO, **d}
        d["dispositivo"] = d["dispositivo"] or f"/dev/falso{k}"
        d["montado"] = bool(d["caminho"]) if "montado" not in lista[k] else bool(d["montado"])
        d["codigo"] = d["codigo"] or "DEV_" + os.path.basename(d["dispositivo"]).upper()
        d["pontoFalso"] = d["caminho"] or d.get("pontoFalso", "")   # para onde "montar" leva
        res.append(d)
    return res


def assinatura_montagens():
    """Algo barato que muda quando monta/desmonta ou pluga um disco."""
    try:
        with open("/proc/mounts") as f:
            m = f.read()
    except OSError:
        m = ""
    try:
        d = ",".join(sorted(os.listdir("/dev/disk/by-uuid")))
    except OSError:
        d = ""
    return hash((m, d))
