#!/usr/bin/env python3
"""Prévias das opções de estilo: assets/previas/estilo/<chave>-<valor>.png e preset-<nome>.png.

Tudo fora da tela e sem tocar na configuração real nem em themes/: para cada valor, os geradores rodam
com um XDG_CONFIG_HOME temporário (o JSON de estilo ali) e escrevem num diretório temporário; um app
Qt de teste com o estilo Kvantum (QT_QPA_PLATFORM=offscreen) desenha os controles dos apps, e uma cena
QML com KSvg e PlasmaComponents 3 desenha o tema do Plasma e a moldura do Aurorae a partir dos SVGs
gerados. Cada prévia é um recorte só com as peças que a opção muda.

Uso: python3 modules/estilo/previas.py [--so chave[,chave...]] [--prancha /tmp/arquivo.png] [--jobs N]
"""
import argparse
import concurrent.futures
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

MOD = pathlib.Path(__file__).resolve().parent
ROOT = MOD.parent.parent
sys.path.insert(0, str(MOD))
sys.path.insert(0, str(ROOT / "generator"))
import estilo  # noqa: E402
from cyberlib import ESTILO_VALORES  # noqa: E402

OUT = ROOT / "assets" / "previas" / "estilo"
FONT = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_B = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
BG = (20, 20, 31)
LARGURA = 420  # prévia pequena: o painel mostra lado a lado

# ---------------------------------------------------------------- 1. gerar os temas num diretório temporário
GERAR = r'''
import json, os, pathlib, sys
root, tmp = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
sys.path.insert(0, str(root / "generator")); sys.path.insert(0, str(root / "modules" / "plasma" / "generator"))
import gen_kvantum, gen_aurorae, gen_konsole, gen_plasma, cyberlib
kv = tmp / "config" / "Kvantum" / "CyberKDE"; kv.mkdir(parents=True)
(kv / "CyberKDE.svg").write_text(gen_kvantum.C.svg()); (kv / "CyberKDE.kvconfig").write_text(gen_kvantum.KV)
(kv.parent / "kvantum.kvconfig").write_text("[General]\ntheme=CyberKDE\n")
cfg = tmp / "config"
(cfg / "kdeglobals").write_text(gen_kvantum.COLORS + "\n[General]\nfont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\n[Icons]\nTheme=breeze-dark\n")
(cfg / "plasmarc").write_text("[Theme]\nname=CyberKDE\n")
th = tmp / "data" / "plasma" / "desktoptheme" / "CyberKDE"
for rel, text in gen_plasma.files().items():
    (th / rel).parent.mkdir(parents=True, exist_ok=True); (th / rel).write_text(text)
(th / "metadata.json").write_text(json.dumps(gen_plasma.METADATA)); (th / "plasmarc").write_text(gen_plasma.PLASMARC)
(th / "colors").write_text(gen_plasma.colors())
au = tmp / "aurorae"; au.mkdir()
(au / "decoration.svg").write_text(gen_aurorae.decoration_svg())
for n in gen_aurorae.GLYPHS: (au / f"{n}.svg").write_text(gen_aurorae.button_svg(n))
ko = tmp / "konsole"; ko.mkdir()
if gen_konsole.TEXTURA != "lisa": (ko / "textura.png").write_bytes(gen_konsole.textura_png())
g = gen_aurorae
info = {"pad": g.PAD, "bl": g.BORDER_L, "br": g.BORDER_R, "bb": g.BORDER_B, "title": g.TITLE, "titleH": g.TITLE_H,
        "edgeT": g.EDGE_T, "btnW": g.BTN_W, "btnH": g.BTN_H, "txt1": cyberlib.TXT1, "txt2": cyberlib.TXT2,
        "panel": cyberlib.PANEL, "base": cyberlib.BASE, "neg": cyberlib.NEGATIVO, "neu": cyberlib.NEUTRO,
        "pos": cyberlib.POSITIVO, "red": cyberlib.RED, "raised": cyberlib.RAISED,
        "abas": cyberlib.ESTILO["konsole_abas"], "densidade": cyberlib.ESTILO["densidade"],
        "lineSpacing": {"compacto": 0, "espacoso": 3}.get(cyberlib.ESTILO["densidade"], 1),
        "margem": cyberlib.dens(10)}
(tmp / "info.json").write_text(json.dumps(info))
'''

# ---------------------------------------------------------------- 2. renderizar (Kvantum + QML)
RENDER = r'''
import json, pathlib, sys
from PyQt6.QtCore import Qt, QTimer, QUrl, QRect, QPoint
from PyQt6.QtGui import QPainter, QPixmap, QColor, QFont
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, QTabBar, QListWidget, QLineEdit,
                             QPushButton, QProgressBar, QGroupBox, QCheckBox, QRadioButton, QMenu, QLabel,
                             QStyle, QStyleOptionFocusRect, QStyleOptionFrame)
from PyQt6.QtQuick import QQuickView
tmp = pathlib.Path(sys.argv[1]); qml = sys.argv[2]
info = json.loads((tmp / "info.json").read_text())
app = QApplication(sys.argv[:1])
app.setStyle("kvantum")
app.setFont(QFont("Noto Sans", 10))
out = tmp / "png"; out.mkdir(exist_ok=True)

def esperar(ms=150):
    """Deixa a ativação e o foco chegarem (sob carga, a janela fora da tela demora a ficar ativa)."""
    from PyQt6.QtCore import QEventLoop
    loop = QEventLoop(); QTimer.singleShot(ms, loop.quit); loop.exec()

def grab(w, nome):
    w.grab().save(str(out / f"{nome}.png"))

# janela de app (Kvantum)
win = QWidget(); win.setWindowTitle("x"); lay = QVBoxLayout(win)
tabs = QTabBar(); tabs.setDocumentMode(True)
rot = "TTY-1 │ ~/projetos" if info["abas"] == "tecnico" else "projetos : bash"
for t in ("Arquivos", rot, "Notas"): tabs.addTab(t)
tabs.setCurrentIndex(1); lay.addWidget(tabs)
lst = QListWidget(); lst.addItems(["Documentos", "Imagens", "Projetos", "Música"]); lst.setCurrentRow(1)
lst.setFixedHeight(4 * 30); lay.addWidget(lst)
row = QHBoxLayout(); edit = QLineEdit("cyberkde efeito"); btn = QPushButton("Aplicar"); row.addWidget(edit); row.addWidget(btn)
lay.addLayout(row)
prog = QProgressBar(); prog.setValue(62); prog.setTextVisible(False); prog.setFixedHeight(12); lay.addWidget(prog)
grp = QGroupBox("Grupo"); gl = QHBoxLayout(grp); cb = QCheckBox("Opção"); cb.setChecked(True); rb = QRadioButton("Rádio"); rb.setChecked(True)
gl.addWidget(cb); gl.addWidget(rb); lay.addWidget(grp)
win.resize(360, win.sizeHint().height()); win.show(); app.processEvents()
win.activateWindow(); lst.setFocus(Qt.FocusReason.TabFocusReason); esperar(250)
grab(win, "kv-janela"); grab(tabs, "kv-abas"); grab(lst, "kv-lista"); grab(prog, "kv-progresso"); grab(grp, "kv-grupo")
edit.setFocus(Qt.FocusReason.TabFocusReason); edit.deselect(); esperar()
# campo: um sem foco e um com foco, lado a lado
com_foco = edit.grab()
e2 = QLineEdit("sem foco"); e2.resize(edit.size()); e2.show(); app.processEvents()
pc = QPixmap(edit.width() * 2 + 18, edit.height() + 12); pc.fill(QColor(info["panel"]))
p = QPainter(pc); p.drawPixmap(6, 6, e2.grab()); p.drawPixmap(edit.width() + 12, 6, com_foco); p.end()
pc.save(str(out / "kv-campo.png")); e2.hide(); win.activateWindow(); app.processEvents()
# botão com foco de teclado: o estilo desenha o anel por cima (PE_FrameFocusRect)
bp = QPixmap(btn.size() + win.size() * 0); bp = btn.grab()
pm = QPixmap(bp.width() + 12, bp.height() + 12); pm.fill(QColor(info["panel"]))
p = QPainter(pm); p.drawPixmap(6, 6, bp)
o = QStyleOptionFocusRect(); o.rect = QRect(6, 6, bp.width(), bp.height())
o.state = QStyle.StateFlag.State_Enabled | QStyle.StateFlag.State_HasFocus | QStyle.StateFlag.State_KeyboardFocusChange
app.style().drawPrimitive(QStyle.PrimitiveElement.PE_FrameFocusRect, o, p, btn); p.end(); pm.save(str(out / "kv-foco.png"))
menu = QMenu(win); acts = [menu.addAction(t) for t in ("Abrir", "Copiar caminho", "Renomear")]; menu.addSeparator(); menu.addAction("Propriedades")
menu.popup(win.mapToGlobal(win.rect().center())); esperar(); menu.setActiveAction(acts[1]); esperar()
grab(menu, "kv-menu"); menu.hide()
# dica: o painel da dica do próprio estilo (PE_PanelTipLabel) e o texto por cima
tp = QPixmap(150, 44); tp.fill(QColor(info["panel"])); p = QPainter(tp)
o = QStyleOptionFrame(); o.rect = QRect(6, 6, 138, 32); o.state = QStyle.StateFlag.State_Enabled
app.style().drawPrimitive(QStyle.PrimitiveElement.PE_PanelTipLabel, o, p, None)
p.setPen(QColor(info["txt1"])); p.drawText(o.rect, Qt.AlignmentFlag.AlignCenter, "Abre o terminal"); p.end()
tp.save(str(out / "kv-dica.png"))

# cena do Plasma/Aurorae (QML)
view = QQuickView(); view.engine().quit.connect(app.quit); view.setSource(QUrl.fromLocalFile(qml))
for e in view.errors(): print("QML:", e.toString(), file=sys.stderr)
view.resize(600, 420); view.show()
QTimer.singleShot(20000, app.quit)
app.exec()
'''

QML = r'''
import QtQuick
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PC3

Rectangle {
    id: root
    width: 600; height: 420; color: "#26263A"
    property string td: "@TD@"; property string au: "@AU@"; property string out: "@OUT@"
    property var i: @INFO@
    function p(f) { return td + "/" + f + ".svg" }
    component Lbl: Text { color: root.i.txt1; font.family: "Noto Sans"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
    component Raw: Item {   // peças cruas de um FrameSvg em camadas (estados que não se forçam num controle real)
        property string file; property var layers; property string label
        width: 120; height: 30
        Repeater {
            model: parent.layers
            KSvg.FrameSvgItem {
                imagePath: root.p(parent.file); prefix: modelData
                anchors { fill: parent; leftMargin: -margins.left; topMargin: -margins.top; rightMargin: -margins.right; bottomMargin: -margins.bottom }
                Component.onCompleted: if (index === 0) anchors.leftMargin = anchors.topMargin = anchors.rightMargin = anchors.bottomMargin = 0
            }
        }
        Lbl { anchors.centerIn: parent; text: parent.label }
    }

    // ---- janela com moldura Aurorae (ativa)
    Item {
        id: janela
        x: 6; y: 6; width: 270; height: 170
        KSvg.FrameSvgItem { anchors.fill: parent; imagePath: root.au + "/decoration.svg"; prefix: "decoration" }
        Rectangle {
            x: root.i.pad + root.i.bl; y: root.i.pad + root.i.title
            width: parent.width - 2 * root.i.pad - root.i.bl - root.i.br
            height: parent.height - 2 * root.i.pad - root.i.title - root.i.bb
            color: root.i.panel
            Lbl { x: 10; y: 8; text: "Conteúdo da janela"; color: root.i.txt2 }
        }
        Lbl { x: root.i.pad + root.i.bl + 8; y: root.i.pad + root.i.edgeT; height: root.i.titleH; text: "Dolphin — Projetos" }
        Row {
            anchors.right: parent.right; anchors.rightMargin: root.i.pad + root.i.br + 2; y: root.i.pad + root.i.edgeT
            Repeater {
                model: ["minimize", "maximize", "close"]
                KSvg.SvgItem { width: root.i.btnW; height: root.i.btnH; imagePath: root.au + "/" + modelData + ".svg"
                               elementId: modelData === "close" ? "hover-center" : "active-center" }
            }
        }
    }

    // ---- dica do Plasma
    Item {
        id: dica
        x: 22; y: 190; width: 190; height: 34
        KSvg.FrameSvgItem { imagePath: root.p("widgets/tooltip"); prefix: "shadow"
            anchors { fill: parent; leftMargin: -margins.left; topMargin: -margins.top; rightMargin: -margins.right; bottomMargin: -margins.bottom } }
        KSvg.FrameSvgItem { anchors.fill: parent; imagePath: root.p("widgets/tooltip") }
        Lbl { anchors.centerIn: parent; text: "Abre o terminal" }
    }

    // ---- terminal (textura do Konsole)
    Rectangle {
        id: terminal
        x: 12; y: 244; width: 260; height: 112; color: root.i.base
        Image { anchors.fill: parent; source: "@KO@"; fillMode: Image.Tile; visible: source != "" }
        Column {
            x: root.i.margem; y: root.i.margem; spacing: root.i.lineSpacing
            Repeater {
                model: ["$ cyberkde status", "Tema ligado · CyberKDE", "$ ls projetos", "cyberkde  notas  painel"]
                Text { text: modelData; color: index % 2 ? root.i.txt2 : root.i.txt1; font.family: "JetBrains Mono"; font.pixelSize: 12 }
            }
        }
    }

    // ---- popup do Plasma (bandeja)
    Item {
        id: popup
        x: 300; y: 14; width: 286; height: 392
        KSvg.FrameSvgItem { imagePath: root.p("dialogs/background"); prefix: "shadow"
            anchors { fill: parent; leftMargin: -margins.left; topMargin: -margins.top; rightMargin: -margins.right; bottomMargin: -margins.bottom } }
        KSvg.FrameSvgItem { id: dlg; anchors.fill: parent; imagePath: root.p("dialogs/background") }
        KSvg.FrameSvgItem {
            id: head; width: parent.width; height: 40
            imagePath: root.p("widgets/plasmoidheading"); prefix: "header"
            Lbl { x: 16; height: parent.height; text: "Bandeja do sistema"; font.bold: true }
        }
        Item {
            id: abas
            x: dlg.margins.left; y: 46; width: 200; height: 28
            KSvg.FrameSvgItem { x: 0; width: 96; height: parent.height; imagePath: root.p("widgets/tabbar"); prefix: "north-active-tab"
                Lbl { anchors.centerIn: parent; text: "Rede" } }
            Lbl { x: 112; height: parent.height; text: "Áudio"; color: root.i.txt2 }
        }
        Column {
            id: itens
            x: dlg.margins.left; y: 80; spacing: 2
            Repeater {
                model: [["Wi-Fi: CasaNet", "selected+hover"], ["Bluetooth", "hover"], ["Som", "normal"]]
                KSvg.FrameSvgItem {
                    width: 260; height: 30; imagePath: root.p("widgets/viewitem"); prefix: modelData[1]
                    Lbl { x: 12; height: parent.height; text: modelData[0] }
                }
            }
        }
        Row {
            id: controles
            x: dlg.margins.left + 4; y: 182; spacing: 14
            PC3.Switch { checked: true }
            PC3.CheckBox { checked: true; text: "Auto" }
            PC3.RadioButton { checked: true; text: "Fixo" }
            PC3.BusyIndicator { width: 26; height: 26; running: false }
        }
        PC3.Slider { id: slider; x: dlg.margins.left + 4; y: 222; width: 250; value: 0.6 }
        PC3.ProgressBar { id: barra; x: dlg.margins.left + 4; y: 258; width: 250; value: 0.62 }
        Item {   // folga em volta: o anel de foco fica do lado de fora do controle
            id: campos
            x: dlg.margins.left - 2; y: 278; width: 262; height: 42
            Row {
                x: 6; y: 6; spacing: 12
                Raw { file: "widgets/lineedit"; layers: ["base", "focus"]; label: "Pesquisar…"; width: 126 }
                Raw { file: "widgets/button"; layers: ["normal", "focus"]; label: "Conectar"; width: 104 }
            }
        }
        KSvg.FrameSvgItem {
            y: parent.height - 44; width: parent.width; height: 44
            imagePath: root.p("widgets/plasmoidheading"); prefix: "footer"
            Lbl { x: 16; height: parent.height; text: "Configurar…"; color: root.i.txt2 }
        }
    }

    Timer {
        interval: 1500; running: true
        onTriggered: {
            const itens_ = [[janela, "pl-janela"], [dica, "pl-dica"], [terminal, "pl-terminal"], [popup, "pl-popup"],
                            [abas, "pl-abas"], [itens, "pl-itens"], [controles, "pl-controles"], [slider, "pl-slider"],
                            [barra, "pl-progresso"], [campos, "pl-campos"]]
            for (const [it, n] of itens_) it.grabToImage(r => r.saveToFile(root.out + "/" + n + ".png"))
            root.grabToImage(r => { r.saveToFile(root.out + "/pl-cena.png"); Qt.callLater(Qt.quit) })
        }
    }
}
'''


def renderizar(valores):
    """Gera e renderiza com estes valores de estilo; devolve o diretório com as imagens."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="cyberkde-estilo-"))
    (tmp / "config" / "cyberkde").mkdir(parents=True)
    (tmp / "config" / "cyberkde" / "estilo").write_text(json.dumps(valores))
    env = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERKDE_", "WAYLAND", "DISPLAY"))}
    env.update(XDG_CONFIG_HOME=str(tmp / "config"), XDG_DATA_HOME=str(tmp / "data"), XDG_CACHE_HOME=str(tmp / "cache"),
               XDG_STATE_HOME=str(tmp / "state"), HOME=str(tmp), CYBERKDE_COR="#F75049", QT_QPA_PLATFORM="offscreen",
               QT_QPA_PLATFORMTHEME="kde", XDG_CURRENT_DESKTOP="KDE", KDE_FULL_SESSION="true", KDE_SESSION_VERSION="6")
    subprocess.run([sys.executable, "-c", GERAR, str(ROOT), str(tmp)], env=env, check=True)
    info = (tmp / "info.json").read_text()
    ko = tmp / "konsole" / "textura.png"
    (tmp / "png").mkdir()
    qml = tmp / "cena.qml"
    qml.write_text(QML.replace("@TD@", str(tmp / "data/plasma/desktoptheme/CyberKDE")).replace("@AU@", str(tmp / "aurorae"))
                   .replace("@OUT@", str(tmp / "png")).replace("@INFO@", info)
                   .replace("@KO@", ("file://" + str(ko)) if ko.exists() else ""))
    r = subprocess.run([sys.executable, "-c", RENDER, str(tmp), str(qml)], env=env, capture_output=True, text=True, timeout=90)
    erros = [ln for ln in r.stderr.splitlines() if "QML:" in ln or "Error" in ln]
    if erros or not (tmp / "png" / "pl-cena.png").exists():
        print(f"{valores}: " + "\n".join(erros[:8] or [r.stderr[-800:]]), file=sys.stderr)
    return tmp


# ---------------------------------------------------------------- 3. montar o recorte
# Peças mostradas por chave (prefixo kv- = apps/Kvantum, pl- = Plasma e Aurorae).
PECAS = {
    "selecao": ["kv-lista", "kv-menu", "pl-itens"],
    "brilho": ["pl-janela", "pl-popup"],
    "corte": ["pl-janela", "kv-menu", "pl-popup"],
    "tamanho": ["pl-janela", "kv-menu", "pl-popup"],
    "densidade": ["kv-janela", "pl-janela"],
    "abas": ["kv-abas", "pl-abas"],
    "progresso": ["kv-progresso", "pl-progresso"],
    "marcador": ["pl-janela", "pl-popup"],
    "moldura": ["pl-popup", "pl-dica", "kv-grupo"],
    "foco": ["kv-foco", "pl-campos"],
    "pecas": ["pl-controles", "pl-slider"],
    "textura": ["pl-terminal", "pl-popup"],
    "textura-onde": ["pl-terminal", "pl-popup"],
    "konsole-abas": ["kv-abas", "pl-terminal"],
    "dica": ["kv-dica", "pl-dica"],
    "campos": ["kv-campo", "pl-campos"],
    "atencao": ["estados"], "sucesso": ["estados"], "perigo": ["estados"],
    "preset": ["pl-cena", "kv-janela"],
}


def estados(tmp):
    """Amostra das cores de estado (texto negativo, neutro e positivo sobre o painel)."""
    info = json.loads((tmp / "info.json").read_text())
    img = Image.new("RGB", (300, 96), info["panel"])
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 15)
    for i, (k, t) in enumerate((("neg", "Erro: falha ao copiar"), ("neu", "Atenção: disco quase cheio"), ("pos", "Pronto: 12 arquivos"))):
        d.rectangle((12, 14 + i * 26, 15, 30 + i * 26), fill=info[k])
        d.text((24, 12 + i * 26), t, font=f, fill=info[k])
    return img


def montar(tmp, chave, titulo):
    imgs = []
    for n in PECAS[chave]:
        if n == "estados":
            imgs.append(estados(tmp).convert("RGBA"))
            continue
        f = tmp / "png" / f"{n}.png"
        if f.exists():
            im = Image.open(f).convert("RGBA")
            if n == "pl-cena":
                im = im.resize((im.width * 2 // 3, im.height * 2 // 3), Image.LANCZOS)
            imgs.append(im)
    if not imgs:
        return None
    gap, top = 10, 26
    W = sum(i.width for i in imgs) + gap * (len(imgs) + 1)
    H = max(i.height for i in imgs) + top + gap
    out = Image.new("RGB", (W, H), BG)
    x = gap
    for im in imgs:
        out.paste(im, (x, top), im)
        x += im.width + gap
    ImageDraw.Draw(out).text((gap, 5), titulo, font=ImageFont.truetype(FONT, 14), fill=(169, 169, 186))
    if out.width > LARGURA * 2:  # pequena, mas legível em 2x
        out = out.resize((LARGURA * 2, round(out.height * LARGURA * 2 / out.width)), Image.LANCZOS)
    return out


def trabalho(args):
    chave, valor, valores, titulo, nome_arq = args
    tmp = renderizar(valores)
    try:
        img = montar(tmp, chave, titulo)
        if img:
            img.save(OUT / nome_arq, optimize=True)
            return nome_arq
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--so", default="", help="só estas chaves (ex.: selecao,brilho,preset)")
    ap.add_argument("--prancha", default="/tmp/cyberkde-estilo-prancha.png")
    ap.add_argument("--jobs", type=int, default=3)
    a = ap.parse_args()
    so = set(filter(None, a.so.split(",")))
    OUT.mkdir(parents=True, exist_ok=True)
    tarefas = []
    for chave, vals in ESTILO_VALORES.items():
        if so and chave not in so:
            continue
        for v in vals:
            base = {"progresso": v} if chave == "progresso" else {chave: v}
            if chave == "textura_onde":
                base = {"textura": "grade", "textura_onde": v}
            pt, _ = estilo.nome(v)
            tarefas.append((chave.replace("_", "-"), v, base, f"{chave.replace('_', ' ')}: {pt}",
                            f"{chave.replace('_', '-')}-{v}.png"))
    if not so or "preset" in so:
        for p, (n, *_r, vals) in estilo.PRESETS.items():
            tarefas.append(("preset", p, vals, f"preset: {n}", f"preset-{p}.png"))
    feitos = []
    with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
        for r in ex.map(trabalho, tarefas):
            if r:
                feitos.append(r)
                print(r)
    prancha(sorted(feitos), pathlib.Path(a.prancha))


def prancha(nomes, destino):
    """Todas as prévias numa folha só (fora do repositório), para conferir de uma vez."""
    imgs = [Image.open(OUT / n) for n in nomes]
    if not imgs:
        return
    col = 3
    w = max(i.width for i in imgs) // 2
    linhas = [imgs[i:i + col] for i in range(0, len(imgs), col)]
    hs = [max(i.height * w // i.width for i in ln) for ln in linhas]
    out = Image.new("RGB", (col * (w + 8) + 8, sum(hs) + 8 * (len(hs) + 1)), (10, 10, 16))
    y = 8
    for ln, h in zip(linhas, hs):
        x = 8
        for im in ln:
            im2 = im.resize((w, im.height * w // im.width), Image.LANCZOS)
            out.paste(im2, (x, y))
            x += w + 8
        y += h + 8
    out.save(destino)
    print(f"prancha: {destino} ({len(imgs)} prévias)")


if __name__ == "__main__":
    main()
