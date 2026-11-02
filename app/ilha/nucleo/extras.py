"""Downloads em andamento, capturas do Spectacle, OCR e conta-gotas."""

import os
import re
import shutil
import tempfile
import time
from pathlib import Path

from PyQt6.QtCore import QStandardPaths

from . import bus as B
from .i18n import t
from .tarefas import cmd

PARCIAL = re.compile(r"\.(part|crdownload|download|opdownload)$", re.I)
IMAGEM = re.compile(r"\.(png|jpe?g|webp|bmp|tiff?)$", re.I)
OCR_MAX = 64 * 1024 * 1024
_idiomas = None


def selo_downloads():
    """Muda quando entra, sai ou troca de nome algo em ~/Downloads: com a ilha recolhida, poupa varrer a pasta."""
    try:
        return os.stat(QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DownloadLocation)).st_mtime_ns
    except OSError:
        return None


def baixando():
    pasta = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DownloadLocation)
    res = []
    agora = time.time()
    try:
        with os.scandir(pasta) as it:
            for e in it:
                if PARCIAL.search(e.name):
                    st = e.stat()
                    res.append({"nome": PARCIAL.sub("", e.name), "bytes": st.st_size, "parado": agora - st.st_mtime > 60})
    except OSError:
        pass
    return res


def baixados():
    """(quantos, nome do mais novo) em ~/Downloads, sem os parciais."""
    pasta = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.DownloadLocation)
    novos = []
    try:
        with os.scandir(pasta) as it:
            for e in it:
                if not PARCIAL.search(e.name) and not e.name.startswith("."):
                    novos.append((e.stat().st_mtime, e.name))
    except OSError:
        pass
    return len(novos), max(novos)[1] if novos else ""


def pasta_capturas():
    rc = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "spectaclerc"
    dentro = "Screenshots"
    try:
        s = rc.read_text()
        m = re.search(r"^imageSaveLocation=file://(.+)$", s, re.M)
        if m:
            return m.group(1).strip()
        m = re.search(r"^translatedScreenshotsFolder=(.+)$", s, re.M)
        if m:
            dentro = m.group(1).strip()
    except OSError:
        pass
    return os.path.join(QStandardPaths.writableLocation(QStandardPaths.StandardLocation.PicturesLocation), dentro)


def selo_capturas():
    try:
        p = pasta_capturas()
        return p, os.stat(p).st_mtime_ns
    except OSError:
        return None


def capturas_desde(ts):
    res = []
    try:
        with os.scandir(pasta_capturas()) as it:
            for e in it:
                if IMAGEM.search(e.name) and e.stat().st_mtime > ts:
                    res.append((e.stat().st_mtime, e.path))
    except OSError:
        pass
    return [p for _, p in sorted(res, reverse=True)]


def idiomas():
    global _idiomas
    if _idiomas is None:
        s = cmd("tesseract", "--list-langs", timeout=5) or ""
        tem = set(s.split())
        _idiomas = "+".join(x for x in ("por", "eng") if x in tem) or "eng"
    return _idiomas


def ler_imagem(caminho):
    if not shutil.which("tesseract"):
        raise OSError(t("tesseract não está instalado"))
    if os.path.getsize(caminho) > OCR_MAX:
        raise OSError(t("imagem grande demais"))
    s = cmd("tesseract", caminho, "stdout", "-l", idiomas(), timeout=60)
    if s is None:
        raise OSError(t("o tesseract não leu a imagem"))
    return s.strip()


def ler_tela():
    """Uma região desenhada no Spectacle, lida e descartada, em pasta própria 0700."""
    if not shutil.which("spectacle"):
        raise OSError(t("spectacle não está instalado"))
    with tempfile.TemporaryDirectory(prefix="cyberkde-ilha-ocr-") as d:
        a = os.path.join(d, "regiao.png")
        if cmd("spectacle", "-b", "-n", "-r", "-o", a, timeout=120) is None or not os.path.exists(a):
            raise OSError(t("captura cancelada"))
        return ler_imagem(a)


def pegar_cor():
    """O seletor do próprio KWin. Thread: a usuária pode demorar a mirar; Esc = erro, sem inventar cor."""
    r = B.bloquear(B.msg("org.kde.KWin", "/ColorPicker", "org.kde.kwin.ColorPicker", "pick"), 60_000)
    if not r:
        raise OSError(t("nenhuma cor escolhida"))
    v = r[0]
    n = v[0] if isinstance(v, (list, tuple)) else v
    return f"#{int(n) & 0xffffff:06x}"
