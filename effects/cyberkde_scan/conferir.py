#!/usr/bin/env python3
"""Confere o catálogo de variantes: variantes.json, a tabela VARIANTES do main.js e o shader.

  python3 effects/cyberkde_scan/conferir.py

A posição de cada variante no JSON é o número dela no shader (uVariante); os tempos padrão do
main.js precisam ser os do JSON (o painel e o CLI mostram os do JSON).
"""
import json, os, re, sys

aqui = os.path.dirname(os.path.abspath(__file__))
cat = json.load(open(os.path.join(aqui, "variantes.json"), encoding="utf-8"))
js = open(os.path.join(aqui, "main.js"), encoding="utf-8").read()
glsl = open(os.path.join(aqui, "shader.glsl"), encoding="utf-8").read()
erros = []
campos = ["id", "nome", "nome_en", "descricao", "descricao_en", "abrir", "fechar", "duracaoAbrir", "duracaoFechar", "referencia"]
tabela = {m[0]: [int(m[1]), int(m[2]), int(m[3])] for m in re.findall(r"^\s+(\w+): \[(\d+), (\d+), (\d+), (?:true|false)\],$", js, re.M)}
ids = [v.get("id") for v in cat]
if len(set(ids)) != len(ids) or "nenhuma" in ids:
    erros.append("ids repetidos ou 'nenhuma' usado como id")
for i, v in enumerate(cat):
    falta = [c for c in campos if c not in v]
    if falta:
        erros.append(f"{v.get('id')}: faltam {falta}")
    # "fade" é a do movimento reduzido (dissolução ≤ 100–150 ms): fica abaixo da faixa das outras.
    curta = v["id"] == "fade"
    if not curta and not (250 <= v["duracaoAbrir"] <= 450 and 150 <= v["duracaoFechar"] <= 300):
        erros.append(f"{v['id']}: durações fora de 250–450 / 150–300 ms")
    if tabela.get(v["id"]) != [i, v["duracaoAbrir"], v["duracaoFechar"]]:
        erros.append(f"{v['id']}: main.js tem {tabela.get(v['id'])}, JSON pede {[i, v['duracaoAbrir'], v['duracaoFechar']]}")
if set(tabela) - set(ids):
    erros.append(f"no main.js e não no JSON: {sorted(set(tabela) - set(ids))}")
ramos = len(re.findall(r"col = v\w+\(p\);", glsl))
if ramos != len(cat):
    erros.append(f"shader tem {ramos} variantes, JSON tem {len(cat)}")
print("\n".join(erros) if erros else f"ok: {len(cat)} variantes")
sys.exit(1 if erros else 0)
