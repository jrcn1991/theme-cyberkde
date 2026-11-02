"""Provedores de imagem para o QML (spec 14.6).

image://miniatura/<caminho%codificado>?m=<mtime>[&tom=mono]  assíncrono, com cache em disco
image://icone/<nome>[?g=<genérico>]                           ícone do tema do sistema

Miniaturas: imagens pelo Pillow (orientação EXIF), SVG e o que o Pillow não abre pelo QImageReader,
vídeo por ffmpegthumbnailer ou ffmpeg, PDF por pdftoppm. Cache PNG em ~/.cache/cyberkde-arquivos."""

import hashlib
import os
import shutil
import subprocess
import tempfile
from urllib.parse import parse_qs, unquote

from PyQt6.QtCore import QMimeDatabase, QObject, QRunnable, QSize, QThreadPool, Qt, pyqtSignal
from PyQt6.QtGui import QIcon, QImage, QImageReader, QPixmap
from PyQt6.QtQuick import QQuickAsyncImageProvider, QQuickImageProvider, QQuickImageResponse, QQuickTextureFactory

from . import itens as I
from .tema import dir_cache

LIMITE_IMAGEM = 80 * 1024 * 1024
TAMANHOS = (128, 256, 512)
_TEM_FFMPEGTHUMB = bool(shutil.which("ffmpegthumbnailer"))
_TEM_FFMPEG = bool(shutil.which("ffmpeg"))
_TEM_PDFTOPPM = bool(shutil.which("pdftoppm"))


def _balde(lado):
    for t in TAMANHOS:
        if lado <= t:
            return t
    return TAMANHOS[-1]


def _pasta_cache():
    p = dir_cache() / "miniaturas"
    p.mkdir(parents=True, exist_ok=True)
    return p


def _hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _de_pillow(caminho, lado):
    from PIL import Image, ImageOps
    with Image.open(caminho) as im:
        im.draft("RGB", (lado, lado))   # JPEG: decodifica já reduzido
        im = ImageOps.exif_transpose(im)
        im.thumbnail((lado, lado))
        im = im.convert("RGBA")
        dados = im.tobytes("raw", "RGBA")
        return QImage(dados, im.width, im.height, im.width * 4, QImage.Format.Format_RGBA8888).copy()


def _de_qt(caminho, lado):
    leitor = QImageReader(caminho)
    leitor.setAutoTransform(True)
    tam = leitor.size()
    if tam.isValid() and max(tam.width(), tam.height()) > lado:
        leitor.setScaledSize(tam.scaled(lado, lado, Qt.AspectRatioMode.KeepAspectRatio))
    img = leitor.read()
    return img if not img.isNull() else None


def _de_comando(cmd, saida):
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                       timeout=15, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    img = QImage(saida)
    return img if not img.isNull() else None


def gerar(caminho, lado, mime):
    """QImage da miniatura (sem cache), ou None."""
    with tempfile.TemporaryDirectory(prefix="datashard-") as tmp:
        if mime.startswith("video/"):
            out = os.path.join(tmp, "v.png")
            if _TEM_FFMPEGTHUMB:
                return _de_comando(["ffmpegthumbnailer", "-i", caminho, "-o", out, "-s", str(lado), "-c", "png"], out)
            if _TEM_FFMPEG:
                for pos in ("00:00:03", "00:00:00"):
                    img = _de_comando(["ffmpeg", "-v", "error", "-nostdin", "-ss", pos, "-i", caminho, "-frames:v", "1",
                                       "-vf", f"scale={lado}:{lado}:force_original_aspect_ratio=decrease", "-y", out], out)
                    if img:
                        return img
            return None
        if mime == "application/pdf":
            if not _TEM_PDFTOPPM:
                return None
            base = os.path.join(tmp, "p")
            return _de_comando(["pdftoppm", "-png", "-singlefile", "-f", "1", "-l", "1", "-scale-to", str(lado),
                                caminho, base], base + ".png")
    if mime.startswith("image/"):
        try:
            if os.path.getsize(caminho) > LIMITE_IMAGEM:
                return None
        except OSError:
            return None
        if mime not in ("image/svg+xml", "image/svg+xml-compressed"):
            try:
                return _de_pillow(caminho, lado)
            except Exception:  # noqa: BLE001 — formato que o Pillow não lê: tenta o Qt
                pass
        return _de_qt(caminho, lado)
    return None


def duotom(img, fundo, destaque):
    """Luminância -> degradê fundo→destaque, mantendo o alfa (miniatura monocromática da corporação)."""
    import numpy as np
    img = img.convertToFormat(QImage.Format.Format_RGBA8888)
    w, h = img.width(), img.height()
    ptr = img.constBits()
    ptr.setsize(img.sizeInBytes())
    arr = np.frombuffer(ptr, np.uint8).reshape(h, img.bytesPerLine())[:, : w * 4].reshape(h, w, 4).astype(np.float32)
    lum = (arr[..., 0] * 0.2126 + arr[..., 1] * 0.7152 + arr[..., 2] * 0.0722) / 255.0
    f, d = np.array(_hex_rgb(fundo), np.float32), np.array(_hex_rgb(destaque), np.float32)
    rgb = f + (d - f) * lum[..., None]
    out = np.dstack([rgb, arr[..., 3:4]]).clip(0, 255).astype(np.uint8)
    return QImage(out.tobytes(), w, h, w * 4, QImage.Format.Format_RGBA8888).copy()


def miniatura(caminho, lado=256, tom="", paleta=None):
    """Com cache. Devolve QImage (vazia se não houver)."""
    try:
        st = os.stat(caminho)
    except OSError:
        return QImage()
    lado = _balde(lado)
    paleta = paleta or {}
    chave_tom = f"{tom}:{paleta.get('fundo')}:{paleta.get('destaque')}" if tom == "mono" else ""
    chave = hashlib.sha1(f"{caminho}\0{st.st_mtime_ns}\0{st.st_size}\0{lado}\0{chave_tom}".encode()).hexdigest()
    arq = _pasta_cache() / f"{chave}.png"
    if arq.exists():
        img = QImage(str(arq))
        if not img.isNull():
            return img
    falha = arq.with_suffix(".falhou")   # cache negativo: o mesmo arquivo (mtime/tamanho) não é tentado de novo
    if falha.exists():
        return QImage()
    mime = QMimeDatabase().mimeTypeForFile(caminho).name()
    img = gerar(caminho, lado, mime)
    if img is None or img.isNull():
        try:
            falha.touch()
        except OSError:
            pass
        return QImage()
    if tom == "mono" and paleta:
        img = duotom(img, paleta.get("fundo", "#0E0E17"), paleta.get("destaque", "#F75049"))
    tmp = arq.with_suffix(".tmp.png")
    if img.save(str(tmp), "PNG"):
        os.replace(tmp, arq)
    return img


def separar_id(ident):
    caminho, _, consulta = ident.partition("?")
    return unquote(caminho), {k: v[0] for k, v in parse_qs(consulta).items()}


class Avisos(QObject):
    """Avisa (na thread principal) as miniaturas que falharam: o back-end zera o papel `miniatura`
    desses itens e o QML cai no ícone do tipo (U16)."""
    falhou = pyqtSignal(str)


class _Resposta(QQuickImageResponse):
    def __init__(self):
        super().__init__()
        self.imagem = QImage()
        self.erro = ""

    def errorString(self):
        return self.erro   # não vazio: o Image do QML fica em Image.Error

    def textureFactory(self):
        return QQuickTextureFactory.textureFactoryForImage(self.imagem)


class _Trabalho(QRunnable):
    def __init__(self, resposta, caminho, lado, tom, paleta, avisos):
        super().__init__()
        self.resposta, self.caminho, self.lado, self.tom, self.paleta = resposta, caminho, lado, tom, paleta
        self.avisos = avisos

    def run(self):
        try:
            self.resposta.imagem = miniatura(self.caminho, self.lado, self.tom, self.paleta)
        except Exception:  # noqa: BLE001
            self.resposta.imagem = QImage()
        if self.resposta.imagem.isNull():
            self.resposta.erro = "sem miniatura"
            try:
                st = os.stat(self.caminho)
                I.FALHAS_MINIATURA[self.caminho] = int(st.st_mtime)
            except OSError:
                pass
            try:
                self.avisos.falhou.emit(self.caminho)
            except RuntimeError:
                pass
        self.resposta.finished.emit()


class ProvedorMiniaturas(QQuickAsyncImageProvider):
    def __init__(self, paleta_fn):
        super().__init__()
        self._paleta = paleta_fn
        self.avisos = Avisos()
        self._pool = QThreadPool()
        self._pool.setMaxThreadCount(max(2, min(4, (os.cpu_count() or 4) // 2)))

    def requestImageResponse(self, ident, requested):
        caminho, q = separar_id(ident)
        lado = max(requested.width(), requested.height()) if requested.isValid() else 256
        resp = _Resposta()
        self._pool.start(_Trabalho(resp, caminho, lado if lado > 0 else 256, q.get("tom", ""), dict(self._paleta()), self.avisos))
        return resp


class ProvedorIcones(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)

    def requestPixmap(self, ident, requested):
        nome, q = separar_id(ident)
        lado = max(requested.width(), requested.height()) if requested.isValid() else 64
        lado = lado if lado > 0 else 64
        icone = QIcon.fromTheme(nome)
        if icone.isNull() and q.get("g"):
            icone = QIcon.fromTheme(q["g"])
        if icone.isNull():
            icone = QIcon.fromTheme("text-x-generic")
        pm = icone.pixmap(QSize(lado, lado)) if not icone.isNull() else QPixmap(lado, lado)
        if icone.isNull():
            pm.fill(Qt.GlobalColor.transparent)
        return pm, pm.size()
