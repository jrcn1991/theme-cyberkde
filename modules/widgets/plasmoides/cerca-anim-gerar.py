#!/usr/bin/env python3
"""Animações do Cyber Fence (org.cyberkde.cerca): gera os derivados de contents/animacoes.json.

  cerca-anim-gerar.py gerar     contents/ui/anim/catalogo.js e catalogoIcones.js, as escolhas em metadata.json, os shaders compilados (.qsb)
                                e a cópia para modules/widgets/comum (AnimacaoWidget.qml, catalogoAnim.js, cerca.frag.qsb)

O qsb vem de $QSB ou do PATH (sem ele, o .qsb existente fica). O QML não lê o JSON direto: a leitura de
arquivo por XMLHttpRequest vem desligada no Qt 6, então o catálogo vai também como .js.
"""
import json
import os
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
PCT = os.path.join(AQUI, "org.cyberkde.cerca", "contents")


def gerar():
    cat = json.load(open(os.path.join(PCT, "animacoes.json"), encoding="utf-8"))
    for i, v in enumerate(cat):
        v["modo"] = i          # a ordem do catálogo é a dos ramos de main() em cerca.frag
    js = ["// GERADO por modules/widgets/plasmoides/cerca-anim-gerar.py a partir de contents/animacoes.json: não editar.",
          ".pragma library", "",
          "var LISTA = " + json.dumps(cat, ensure_ascii=False, indent=1) + ";", "",
          "// a variante pelo id; desconhecida cai na padrão",
          "function de(id) {",
          "    var padrao = LISTA[0];",
          "    for (var i = 0; i < LISTA.length; i++) {",
          "        if (LISTA[i].id === id) return LISTA[i];",
          "        if (LISTA[i].padrao) padrao = LISTA[i];",
          "    }",
          "    return padrao;",
          "}",
          "function lista() { return LISTA; }", ""]
    with open(os.path.join(PCT, "ui", "anim", "catalogo.js"), "w", encoding="utf-8") as f:
        f.write("\n".join(js))
    ic = json.load(open(os.path.join(PCT, "animacoes-icones.json"), encoding="utf-8"))
    with open(os.path.join(PCT, "ui", "anim", "catalogoIcones.js"), "w", encoding="utf-8") as f:
        f.write("\n".join(js[:3] + ["var LISTA = " + json.dumps(ic, ensure_ascii=False, indent=1) + ";", ""] + js[5:])
                .replace("contents/animacoes.json", "contents/animacoes-icones.json"))
    q = os.environ.get("QSB") or shutil.which("qsb")
    metadados(ic)
    for nome in ("cerca.frag", "icone.frag", "icone.vert", "camada.frag", "deco.frag"):
        src = os.path.join(PCT, "ui", "anim", nome)
        if q:
            subprocess.run([q, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", src + ".qsb", src], check=True)
        else:
            print("aviso: qsb não encontrado; %s.qsb não foi refeito" % nome, file=sys.stderr)
    comum()
    print("%d variantes" % len(cat))


def metadados(ic):
    """As escolhas da opção animacaoIcones em metadata.json (é o que o CLI e o painel leem) saem do catálogo."""
    f = os.path.join(PCT, "..", "metadata.json")
    texto = open(f, encoding="utf-8").read()
    pos = texto.index('"id": "animacaoIcones"')
    ini = texto.index('"valores": [', pos)
    fim = texto.index("\n                ]", ini)
    linhas = []
    for v in ic:
        c = {"id": v["id"], "nome": v["nome"], "nome_en": v["nome_en"], "previa": "assets/previas/cerca/icones-%s.webp" % v["id"]}
        linhas.append(" " * 20 + "{\n" + ",\n".join(" " * 24 + "%s: %s" % (json.dumps(k), json.dumps(x, ensure_ascii=False)) for k, x in c.items()) + "\n" + " " * 20 + "}")
    novo = texto[:ini] + '"valores": [\n' + ",\n".join(linhas) + texto[fim:]
    json.loads(novo)
    with open(f, "w", encoding="utf-8") as saida:
        saida.write(novo)


def comum():
    """Cópia da animação para modules/widgets/comum: os outros widgets ocultam com as mesmas variantes.
    Fonte única: a do Cyber Fence. O comum/ vai para todos os pacotes (install_widgets e montar.sh, sem
    subpastas), por isso os arquivos ficam soltos ali, com nomes próprios."""
    destino = os.path.join(AQUI, "..", "comum")
    ui = os.path.join(PCT, "ui")
    qml = open(os.path.join(ui, "AnimacaoCerca.qml"), encoding="utf-8").read()
    troca = (('import "comum"\n', ""), ('import "anim/catalogo.js" as Catalogo', 'import "catalogoAnim.js" as Catalogo'),
             ('Qt.resolvedUrl("anim/cerca.frag.qsb")', 'Qt.resolvedUrl("cerca.frag.qsb")'))
    for velho, novo in troca:
        if velho not in qml:
            sys.exit("cerca-anim-gerar: AnimacaoCerca.qml mudou; ajuste a cópia: " + velho)
        qml = qml.replace(velho, novo)
    aviso = "// GERADO por modules/widgets/plasmoides/cerca-anim-gerar.py a partir do AnimacaoCerca.qml do Cyber Fence: não editar.\n"
    with open(os.path.join(destino, "AnimacaoWidget.qml"), "w", encoding="utf-8") as f:
        f.write(aviso + qml)
    shutil.copy2(os.path.join(ui, "anim", "catalogo.js"), os.path.join(destino, "catalogoAnim.js"))
    shutil.copy2(os.path.join(ui, "anim", "cerca.frag.qsb"), os.path.join(destino, "cerca.frag.qsb"))


if __name__ == "__main__":
    gerar()
