#!/usr/bin/env python3
"""DATASHARD: gerenciador de arquivos do CyberKDE (back-end PyQt6 + interface QML).

Especificação e API do QML: docs/interno/arquivos-spec.md (seção 14).
O QML principal fica em app/arquivos/qml/Main.qml; sem ele, abre qml/Teste.qml (teste do back-end).
Os componentes do painel (app/qml: Tema, Chanfro, Modal…) entram no caminho de importação.

Uso: python3 app/arquivos/cyberkde-arquivos.py [pasta] [--visao pilhas|lista|grade] [--qml ARQ.qml]
         [--captura ARQ.png [--espera MS]] [--largura L --altura A]
"""

import argparse
import os
import pwd
import sys
from pathlib import Path

from PyQt6 import sip
from PyQt6.QtCore import QTimer, QUrl
from PyQt6.QtGui import QFontDatabase, QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickWindow  # noqa: F401  (rootObjects()[0] vira QQuickWindow)

AQUI = Path(__file__).resolve().parent
REPO = AQUI.parent.parent
sys.path.insert(0, str(AQUI))

from nucleo.miniaturas import ProvedorIcones, ProvedorMiniaturas  # noqa: E402
from nucleo.principal import Arquivos  # noqa: E402


def carregar_fontes():
    for f in sorted((REPO / "assets" / "fonts").glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))


def tema_de_icones():
    """Tema de ícones: CyberKDE, com reserva breeze-dark. No Plasma a plataforma já escolhe o tema do
    sistema; fora dele (offscreen, Xvfb, HOME de teste) o Qt fica no "hicolor" e os ícones somem.
    Procura também na pasta de ícones da conta (pelo passwd, não pelo $HOME), só para leitura."""
    casa_real = Path(pwd.getpwuid(os.getuid()).pw_dir)
    dados = [os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")]
    dados += (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    caminhos = [str(Path(d) / "icons") for d in dados if d] + [str(Path.home() / ".icons"),
                                                               str(casa_real / ".local/share/icons"), "/usr/share/icons"]
    caminhos += [p for p in QIcon.themeSearchPaths() if p not in caminhos]
    caminhos = [c for i, c in enumerate(caminhos) if c not in caminhos[:i] and os.path.isdir(c)]
    QIcon.setThemeSearchPaths(caminhos)
    QIcon.setFallbackThemeName("breeze-dark")
    if QIcon.themeName() in ("", "hicolor") or QGuiApplication.platformName() in ("offscreen", "minimal"):
        for nome in ("CyberKDE", "breeze-dark", "breeze"):
            if any((Path(c) / nome / "index.theme").exists() for c in caminhos):
                QIcon.setThemeName(nome)
                break


def montar(argv=None):
    ap = argparse.ArgumentParser(description="DATASHARD, gerenciador de arquivos do CyberKDE")
    ap.add_argument("caminhos", nargs="*", default=[],
                    help="pastas a abrir (uma aba cada) e/ou arquivos a mostrar selecionados; aceita file:// (padrão: HOME)")
    ap.add_argument("--visao", choices=("pilhas", "lista", "grade"), default="")
    ap.add_argument("--qml", default="", help="QML alternativo (testes)")
    ap.add_argument("--captura", help="salva a janela neste PNG e sai")
    ap.add_argument("--espera", type=int, default=2500)
    ap.add_argument("--largura", type=int, default=0)
    ap.add_argument("--altura", type=int, default=0)
    ap.add_argument("--servico", action="store_true",
                    help="iniciado pelo D-Bus (.service de org.freedesktop.FileManager1): atende a interface mesmo sem o efeito")
    ap.add_argument("--sem-dbus", action="store_true", help="sem instância única nem FileManager1")
    ap.add_argument("--roteiro", help="(testes) JS avaliado no QML depois de carregar (propriedade roteiroJs)")
    args = ap.parse_args(argv)

    sys.path.insert(0, str(REPO / "app"))
    from gpu_leve import preparar
    preparar()
    QGuiApplication.setApplicationName("cyberkde-arquivos")
    QGuiApplication.setApplicationDisplayName("DATASHARD")
    QGuiApplication.setDesktopFileName("cyberkde-arquivos")
    app = QGuiApplication(sys.argv[:1])
    carregar_fontes()
    tema_de_icones()

    caminhos = [c if c.startswith("file:") else os.path.abspath(os.path.expanduser(c)) for c in args.caminhos]
    # repassado à instância aberta (o Qt desta usa o mesmo token para ativar a própria janela)
    token = os.environ.get("XDG_ACTIVATION_TOKEN", "") or os.environ.get("DESKTOP_STARTUP_ID", "")

    # instância única: se já há um DATASHARD aberto, ele recebe os caminhos e este processo sai
    servico = None
    if not args.sem_dbus:
        from nucleo.barramento import Servico, efeito_ligado, pedir_que_assuma, repassar
        servico = Servico(None, lambda _t: None, reusar_primeira=args.servico and not caminhos)
        if not servico.registrar_proprio():
            if args.servico and pedir_que_assuma():
                sys.exit(0)   # a instância aberta pegou o FileManager1 e recebe a chamada pendente
            if repassar(caminhos, token):
                sys.exit(0)
            servico = None   # sem D-Bus de sessão (ou a outra instância não respondeu): segue sozinho

    arquivos = Arquivos("")
    app.aboutToQuit.connect(arquivos.encerrar)
    if caminhos:
        arquivos.mostrar(caminhos, reusar=True)
    if args.visao:
        arquivos.aba.visao = args.visao

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(AQUI / "qml"))
    engine.addImportPath(str(REPO / "app"))
    provedor = ProvedorMiniaturas(lambda: arquivos.paleta)
    provedor.avisos.falhou.connect(arquivos.miniaturaFalhou)
    app._avisosMiniatura = provedor.avisos   # o engine fica com o provedor; os avisos, com o app
    engine.addImageProvider("miniatura", provedor)
    engine.addImageProvider("icone", ProvedorIcones())
    ctx = engine.rootContext()
    ctx.setContextProperty("arquivos", arquivos)
    ctx.setContextProperty("opcoes", {"visao": args.visao, "captura": bool(args.captura),
                                      "largura": args.largura, "altura": args.altura,
                                      "qmlPainel": QUrl.fromLocalFile(str(REPO / "app" / "qml")).toString()})
    qml = Path(args.qml) if args.qml else AQUI / "qml" / "Main.qml"
    if not qml.exists():
        qml = AQUI / "qml" / "Teste.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        sys.exit(1)
    janela = engine.rootObjects()[0]
    if servico is not None:
        def ativar(tok):
            if tok:   # Wayland: o token de ativação de quem pediu ("Mostrar na pasta")
                os.environ["XDG_ACTIVATION_TOKEN"] = tok
            if janela.visibility() == janela.Visibility.Minimized:
                janela.showNormal()
            janela.show()
            janela.raise_()
            janela.requestActivate()
        servico.arquivos = arquivos
        servico._ativar = ativar
        if args.servico or efeito_ligado():
            if not servico.registrar_fm():
                print("aviso: org.freedesktop.FileManager1 já tem dono (Dolphin?); \"Mostrar na pasta\" segue com ele",
                      file=sys.stderr)
        servico.acompanhar_efeito(fixo=args.servico)
        app.aboutToQuit.connect(servico.liberar)
    app._servicoDbus = servico   # segura a referência enquanto o app viver
    return app, engine, janela, arquivos, args


def main():
    app, engine, janela, arquivos, args = montar()
    if args.captura:
        def capturar():
            try:
                janela.grabWindow().save(args.captura)
                print(args.captura)
            finally:
                app.quit()
        QTimer.singleShot(args.espera, capturar)
    if args.roteiro:
        js = Path(args.roteiro).read_text()
        QTimer.singleShot(1200, lambda: janela.setProperty("roteiroJs", js))
    codigo = app.exec()
    del janela
    sip.delete(engine)   # fecha o QML antes do back-end
    sys.exit(codigo)


if __name__ == "__main__":
    main()
