#!/usr/bin/env python3
"""Ilha dinâmica do CyberKDE: porte em PyQt6 + QML da ilha do Halo, sem depender dele.

Especificação e API do QML: docs/interno/ilha-spec.md. A janela é uma superfície layer-shell (Plasma
Wayland), do tamanho da ilha aberta; só a pílula aceita o mouse (setMask).

Uso: cyberkde-ilha.py [--daemon] [--checar] [--esquema|--estado --json] [--definir chave=valor] [--sair]
         [--qml ARQ.qml] [--captura ARQ.png --espera MS] [--roteiro ARQ.js]
"""

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
REPO = AQUI.parent.parent
sys.path.insert(0, str(AQUI))

from nucleo import config as C  # noqa: E402  (sem Qt: --esquema e --definir respondem na hora)


def _qml_dir():
    from PyQt6.QtCore import QLibraryInfo
    return Path(QLibraryInfo.path(QLibraryInfo.LibraryPath.QmlImportsPath))


def checar():
    """(obrigatórios que faltam, opcionais que faltam: pacote → para quê)."""
    falta = []
    try:
        q = _qml_dir()
        if not (q / "org/kde/layershell/qmldir").exists():
            falta.append("qml6-module-org-kde-layershell")
    except ImportError:
        falta.append("python3-pyqt6")
    opc = {}
    for prog, pac, para in (("pactl", "pulseaudio-utils", "volume e espectro"), ("dbus-monitor", "dbus-bin", "anunciar notificações"),
                            ("tesseract", "tesseract-ocr", "ler texto de imagens"), ("spectacle", "kde-spectacle", "capturas e OCR da tela"),
                            ("udisksctl", "udisks2", "ejetar discos"), ("nmcli", "network-manager", "leituras de rede")):
        if not shutil.which(prog):
            opc[pac] = para
    return falta, opc


def consultar(metodo, *args):
    """Pergunta à instância aberta. None se não há."""
    from PyQt6.QtCore import QCoreApplication
    from nucleo import bus as B
    from nucleo.barramento import CAM, NOME
    QCoreApplication.instance() or QCoreApplication(sys.argv[:1])
    if not B.tem_dono(NOME):
        return None
    r = B.bloquear(B.msg(NOME, CAM, NOME, metodo, *args), 3000)
    return r if r is not None else None


def comandos(a):
    """Modos de linha de comando, sem janela. Devolve o código de saída, ou None para seguir."""
    if a.esquema:
        print(json.dumps(C.esquema_json(), ensure_ascii=False))
        return 0
    if a.definir:
        k, _, v = a.definir.partition("=")
        try:
            v = json.loads(v)
        except ValueError:
            pass
        e = C.definir(k, v)
        if e:
            print(e, file=sys.stderr)
            return 2
        return 0
    if a.checar:
        f, o = checar()
        if a.json:
            print(json.dumps({"faltam": f, "opcionais": o}, ensure_ascii=False))
        else:
            for p, para in o.items():
                print(f"Opcional ({para}): sudo apt install {p}", file=sys.stderr)
            if f:
                print("sudo apt install " + " ".join(f))
        return 1 if f else 0
    if a.estado:
        r = consultar("Estado")
        e = json.loads(r[0]) if r else {"rodando": False}
        e["config"] = C.ler()
        # A paleta que o tema pede agora; "paleta" (com a ilha aberta) é a que ela está mostrando.
        from nucleo.tema import ler_paleta
        e["paletaTema"] = ler_paleta()
        print(json.dumps(e, ensure_ascii=False))
        return 0
    if a.sair:
        return 0 if consultar("Sair") is not None else 1
    return None


def montar(a):
    if not a.teste:
        os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"   # antes do QGuiApplication
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    sys.path.insert(0, str(REPO / "app"))
    from gpu_leve import preparar
    preparar()
    from PyQt6.QtCore import QTimer, QUrl
    from PyQt6.QtGui import QFontDatabase, QGuiApplication
    from PyQt6.QtQml import QQmlApplicationEngine
    from PyQt6.QtQuick import QQuickWindow  # noqa: F401
    QGuiApplication.setApplicationName("cyberkde-ilha")
    QGuiApplication.setApplicationDisplayName("Ilha")
    QGuiApplication.setDesktopFileName("cyberkde-ilha")
    QGuiApplication.setQuitOnLastWindowClosed(False)   # a ilha oculta não pode encerrar o app
    app = QGuiApplication(sys.argv[:1])
    # Já lida pelo Qt (medido: janela criada depois continua camada). Se ficasse no ambiente, todo processo
    # filho a herdaria e os apps abertos pela ilha virariam camadas sem moldura.
    os.environ.pop("QT_WAYLAND_SHELL_INTEGRATION", None)
    if app.platformName() not in ("wayland", "offscreen", "minimal") and not a.teste:
        print("A ilha precisa do Plasma em Wayland (layer-shell).", file=sys.stderr)
        sys.exit(1)
    for f in sorted((REPO / "assets" / "fonts").glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))

    from nucleo.principal import Ilha
    ilha = Ilha()
    if not ilha.servico.registrar():
        from PyQt6.QtDBus import QDBusConnection
        if QDBusConnection.sessionBus().isConnected():
            print("A ilha já está aberta.", file=sys.stderr)
            sys.exit(0)
    app.aboutToQuit.connect(ilha.encerrar)
    ilha.iniciar()

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(AQUI / "qml"))
    engine.addImportPath(str(REPO / "app"))
    ctx = engine.rootContext()
    ctx.setContextProperty("ilha", ilha)
    ctx.setContextProperty("opcoes", {"largura": a.largura, "altura": a.altura, "captura": bool(a.captura), "teste": a.teste})
    qml = Path(a.qml) if a.qml else AQUI / "qml" / "Main.qml"
    if not qml.exists():
        qml = AQUI / "qml" / "Teste.qml"
    if qml.exists():
        engine.load(QUrl.fromLocalFile(str(qml)))
        if not engine.rootObjects():
            sys.exit(1)
    else:
        print("aviso: sem QML; só o back-end de pé", file=sys.stderr)
    # a raiz pode ser um Instantiator (uma janela por tela): quem interessa são as janelas de topo
    janelas = app.topLevelWindows
    if a.roteiro:
        js = Path(a.roteiro).read_text()
        QTimer.singleShot(1000, lambda: [w.setProperty("roteiroJs", js) for w in janelas()[:1]])
    if a.captura:
        def capturar():
            for w in janelas()[:1]:
                w.grabWindow().save(a.captura)
                print(a.captura)
            app.quit()
        QTimer.singleShot(a.espera, capturar)
    return app, engine, ilha


def main():
    ap = argparse.ArgumentParser(description="Ilha dinâmica do CyberKDE")
    ap.add_argument("--daemon", action="store_true", help="autostart: só sobe com o efeito ilha ligado")
    ap.add_argument("--checar", action="store_true")
    ap.add_argument("--esquema", action="store_true", help="as opções do painel, em JSON")
    ap.add_argument("--estado", action="store_true")
    ap.add_argument("--definir", metavar="CHAVE=VALOR")
    ap.add_argument("--sair", action="store_true", help="fecha a instância aberta")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--qml", default="")
    ap.add_argument("--teste", action="store_true", help="(testes) sem layer-shell")
    ap.add_argument("--captura")
    ap.add_argument("--espera", type=int, default=2500)
    ap.add_argument("--largura", type=int, default=0)
    ap.add_argument("--altura", type=int, default=0)
    ap.add_argument("--roteiro")
    a = ap.parse_args()
    r = comandos(a)
    if r is not None:
        sys.exit(r)
    if a.daemon:
        from nucleo.tema import ler_efeitos
        if not ler_efeitos()[1]:
            sys.exit(0)
    app, engine, ilha = montar(a)
    codigo = app.exec()
    from PyQt6 import sip
    sip.delete(engine)
    sys.exit(codigo)


if __name__ == "__main__":
    main()
