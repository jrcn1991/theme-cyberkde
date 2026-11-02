#!/usr/bin/env python3
"""Janelinha do atalho "nova cerca": pede o nome e mostra a pasta que vai nascer.

A cerca na área de trabalho não recebe o teclado se outra janela estiver em foco (Wayland); esta janela
recebe, porque nasce do atalho. Enter cria a pasta e chama "cyberkde cerca nova --titulo N --pasta P";
Esc fecha sem criar nada. Teste: --captura arq.png.
"""
import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

APP_DIR = Path(__file__).resolve().parent
REPO = APP_DIR.parent
AUXILIAR = REPO / "modules/widgets/plasmoides/org.cyberkde.cerca/contents/code/cerca.py"


def carregar_auxiliar():
    spec = importlib.util.spec_from_file_location("cerca_auxiliar", AUXILIAR)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def cli():
    return os.environ.get("CYBERKDE_CLI") or shutil.which("cyberkde") or str(REPO / "scripts/cyberkde")


def ler(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def erro_do_cli(s):
    """A frase do erro: com --json ela vem em {"erro":...} no stdout."""
    try:
        return json.loads(s.stdout.strip().splitlines()[-1])["erro"]
    except (IndexError, ValueError, KeyError, TypeError):
        return s.stderr.strip().splitlines()[-1] if s.stderr.strip() else "cyberkde cerca nova: %d" % s.returncode


def pasta_base():
    """A mesma regra do cerca_base do CLI: a preferência; senão, Documentos/Cercas."""
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    b = ler(["kreadconfig6", "--file", os.path.join(config, "cyberkde/efeitos"), "--group", "cerca", "--key", "base"])
    if b:
        return os.path.expanduser(b)
    d = ler(["xdg-user-dir", "DOCUMENTS"])
    if not d or d.rstrip("/") == os.path.expanduser("~"):
        d = os.path.expanduser("~/Documentos")
    return os.path.join(d.rstrip("/"), "Cercas")


def paleta():
    """Os papéis da paleta aplicada: os do Paleta.qml que a fase widgets gera; senão, o vermelho padrão."""
    cores = {"destaque": "#F75049", "secundaria": "#5EF6FF", "fundo": "#0E0E17"}
    dados = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    try:
        texto = Path(dados, "plasma/plasmoids/org.cyberkde.cerca/contents/ui/comum/Paleta.qml").read_text()
    except OSError:
        return cores
    for k in cores:
        m = re.search(k + r':\s*"(#[0-9A-Fa-f]{6})"', texto)
        if m:
            cores[k] = m.group(1)
    return cores


class Nome(QObject):
    fechar = pyqtSignal()
    erroMudou = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._aux = carregar_auxiliar()
        self._base = pasta_base()
        self._erro = ""
        self._cores = paleta()

    @pyqtProperty("QVariantMap", constant=True)
    def cores(self):
        return self._cores

    @pyqtProperty(bool, constant=True)
    def en(self):
        return not (os.environ.get("LANG", "") or "pt").lower().startswith("pt")

    @pyqtProperty(str, notify=erroMudou)
    def erro(self):
        return self._erro

    @pyqtSlot(str, result=str)
    def pastaDe(self, nome):
        """O que aparece na linha PASTA, já com o nome livre ("Nome 2")."""
        limpo = self._aux.limpar(nome) or "…"
        if os.path.isdir(self._base):
            limpo = self._aux.livre(self._base, limpo)
        caminho = os.path.join(self._base, limpo)
        casa = os.path.expanduser("~")
        return "~" + caminho[len(casa):] if caminho.startswith(casa + "/") else caminho

    def _falhar(self, texto):
        self._erro = texto
        self.erroMudou.emit()

    @pyqtSlot(str)
    def criar(self, nome):
        nome = self._aux.limpar(nome)
        if not nome:
            return
        os.makedirs(self._base, exist_ok=True)
        r = self._aux.criar(self._base, self._aux.livre(self._base, nome))
        if not r.get("ok"):
            self._falhar(r.get("detalhe") or r.get("erro", ""))
            return
        try:
            s = subprocess.run([cli(), "cerca", "nova", "--titulo", nome, "--pasta", r["caminho"], "--json"],
                               capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as e:
            s, detalhe = None, str(e)
        if s is None or s.returncode != 0:
            self._aux.remover_vazia(r["caminho"])
            self._falhar(detalhe if s is None else erro_do_cli(s))
            return
        self.fechar.emit()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captura")
    a = p.parse_args()
    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName("cyberkde-cerca-nome")
    app.setDesktopFileName("cyberkde-painel")
    nome = Nome()
    motor = QQmlApplicationEngine()
    motor.rootContext().setContextProperty("cerca", nome)
    motor.load(QUrl.fromLocalFile(str(APP_DIR / "qml/CercaNome.qml")))
    if not motor.rootObjects():
        return 1
    nome.fechar.connect(app.quit)
    if a.captura:
        janela = motor.rootObjects()[0]
        QTimer.singleShot(1200, lambda: (janela.grabWindow().save(a.captura), app.quit()))
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
