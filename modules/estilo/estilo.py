#!/usr/bin/env python3
"""Opções de estilo da interface (docs/interno/catalogo-interface.md) para "cyberkde efeito estilo-*".

A escolha fica em ~/.config/cyberkde/estilo (JSON plano), que generator/cyberlib.py lê (ESTILO). Os
valores válidos e o padrão de cada chave vêm de cyberlib.ESTILO_VALORES (fonte única); aqui ficam os
nomes, as descrições, os presets e quais geradores cada chave afeta.

Uso (chamado por modules/estilo/phase.sh):
  estilo.py ids                         ids dos efeitos, um por linha
  estilo.py json <efeito>               item de "cyberkde efeito --lista --json"
  estilo.py estado <efeito>             só o objeto "estado"
  estilo.py estados                     todos os estados: "id<TAB>objeto" por linha (status em lote)
  estilo.py aplicar <efeito> [on|off] [--variante v | v] [--<opção> valor ...]
                                        grava a escolha; imprime os alvos a regenerar (kvantum aurorae
                                        konsole plasma), um por linha. Saída 2 = uso inválido.
                                        "on" sem variante religa a última escolhida (ou, sem nenhuma, a
                                        primeira que não é o padrão); "off" volta ao padrão e lembra a de antes.
"""
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "generator"))
from cyberlib import ESTILO_VALORES, PREFS  # noqa: E402

ARQ = PREFS / "estilo"
PREVIAS = ROOT / "assets" / "previas" / "estilo"
EN = os.environ.get("CYBERKDE_LANG", "pt").startswith("en")

# Geradores que cada chave muda (o que o phase.sh regenera e recarrega).
ALVOS = {
    "selecao": "kvantum plasma", "brilho": "aurorae plasma", "corte": "kvantum aurorae plasma",
    "tamanho": "kvantum aurorae plasma", "densidade": "kvantum aurorae plasma konsole",
    "abas": "kvantum plasma", "progresso": "kvantum plasma", "marcador": "aurorae plasma",
    "moldura": "kvantum plasma", "foco": "kvantum plasma", "pecas": "plasma",
    "textura": "konsole plasma", "textura_onde": "konsole plasma", "konsole_abas": "konsole",
    "dica": "kvantum plasma", "campos": "kvantum plasma",
    "atencao": "kvantum aurorae plasma", "sucesso": "kvantum aurorae plasma", "perigo": "kvantum aurorae plasma",
}

# Nomes dos valores (pt, en).
NOMES = {
    "marcador": ("Marcador lateral", "Side marker"), "bloco": ("Bloco sólido", "Solid block"),
    "colchetes": ("Colchetes", "Brackets"), "sublinhado": ("Sublinhado", "Underline"),
    "off": ("Desligado", "Off"), "suave": ("Suave", "Soft"), "neon": ("Neon", "Neon"),
    "canto": ("Canto", "Corner"), "oposto": ("Cantos opostos", "Opposite corners"), "topo": ("Topo", "Top"),
    "octogono": ("Octógono", "Octagon"), "reto": ("Reto", "Square"),
    "padrao": ("Padrão", "Default"), "pequeno": ("Pequeno", "Small"), "largo": ("Largo", "Wide"),
    "compacto": ("Compacto", "Compact"), "espacoso": ("Espaçoso", "Spacious"),
    "moldura": ("Moldura", "Frame"), "sublinhada": ("Sublinhada", "Underlined"), "cartao": ("Cartão", "Card"),
    "segmentada": ("Segmentada", "Segmented"), "hachurada": ("Hachurada", "Hatched"),
    "pontos": ("Pontos", "Dots"), "lisa": ("Lisa", "Plain"),
    "cheio": ("Cheio", "Full"), "parcial": ("Parcial", "Partial"), "nenhum": ("Nenhum", "None"),
    "contorno": ("Contorno", "Outline"), "cantoneira": ("Cantoneiras", "Corner brackets"),
    "misto": ("Misto", "Mixed"), "anel": ("Anel", "Ring"), "grosso": ("Grosso", "Thick"),
    "breeze": ("Do Breeze", "From Breeze"), "cyberkde": ("CyberKDE", "CyberKDE"),
    "grade": ("Grade", "Grid"), "scanline": ("Scanline", "Scanline"),
    "ambos": ("Konsole e popups", "Konsole and popups"), "konsole": ("Só o Konsole", "Konsole only"),
    "popups": ("Só os popups", "Popups only"), "tecnico": ("Técnico", "Technical"),
    "chanfro": ("Chanfro", "Chamfer"), "faixa": ("Faixa no alto", "Top strip"),
    "caixa": ("Caixa", "Box"), "dourado": ("Dourado", "Gold"), "laranja": ("Laranja", "Orange"),
    "verde": ("Verde", "Green"), "ciano": ("Secundária (ciano)", "Secondary (cyan)"),
    "alerta": ("Alerta da corporação", "Corporation alert"), "magenta": ("Magenta", "Magenta"),
    "vermelho": ("Vermelho vivo", "Bright red"),
}

# Efeitos: id -> (chave principal, {opção: chave}, nome, nome_en, descrição, descrição_en)
EFEITOS = {
    "estilo-selecao": ("selecao", {}, "Estilo de seleção", "Selection style",
                       "Como aparece o item escolhido em listas e menus (Dolphin, menus, menu iniciar).",
                       "How the chosen item looks in lists and menus (Dolphin, menus, launcher)."),
    "estilo-brilho": ("brilho", {}, "Brilho neon", "Neon glow",
                      "A sombra da janela ativa e dos popups vira um halo na cor de destaque.",
                      "The shadow of the active window and popups becomes a halo in the accent color."),
    "estilo-corte": ("corte", {"tamanho": "tamanho"}, "Corte da moldura", "Frame cut",
                     "Quais cantos de botões, menus, popups e janelas são chanfrados, e o tamanho do chanfro.",
                     "Which corners of buttons, menus, popups and windows are chamfered, and how big."),
    "estilo-densidade": ("densidade", {}, "Densidade", "Density",
                         "Margens e espaçamentos dos apps, popups, barra de título e Konsole.",
                         "Margins and spacing in apps, popups, the title bar and Konsole."),
    "estilo-abas": ("abas", {}, "Abas", "Tabs",
                    "Desenho das abas (Konsole, Dolphin, Kate e popups do Plasma).",
                    "Tab design (Konsole, Dolphin, Kate and Plasma popups)."),
    "estilo-progresso": ("progresso", {}, "Barra de progresso", "Progress bar",
                         "O mesmo padrão nos apps e no Plasma (cópias, bateria, volume).",
                         "The same pattern in apps and in Plasma (copies, battery, volume)."),
    "estilo-marcador": ("marcador", {}, "Marcador lateral", "Side marker",
                        "A faixa de identidade da janela ativa e dos popups: cheia, parcial, no alto ou nenhuma.",
                        "The identity strip of the active window and popups: full, partial, on top or none."),
    "estilo-moldura": ("moldura", {}, "Cantoneiras", "Corner brackets",
                       "Popups, dicas e grupos com contorno inteiro, só os cantos em L, ou os dois.",
                       "Popups, tooltips and groups with a full outline, only L-shaped corners, or both."),
    "estilo-foco": ("foco", {}, "Anel de foco", "Focus ring",
                    "Como aparece o controle com o foco do teclado.",
                    "How the control with keyboard focus looks."),
    "estilo-pecas": ("pecas", {}, "Controles do Plasma", "Plasma controls",
                     "Chave, slider, caixas de seleção, rádio e indicador de ocupado com o desenho do tema, em vez do Breeze.",
                     "Switch, slider, checkboxes, radio and busy indicator drawn by the theme instead of Breeze."),
    "estilo-textura": ("textura", {"onde": "textura_onde"}, "Textura de fundo", "Background texture",
                       "Grade ou scanline bem fracas (4%) no fundo do Konsole e dos popups. Desligada por padrão.",
                       "Very faint grid or scanlines (4%) behind Konsole and popups. Off by default."),
    "estilo-konsole-abas": ("konsole_abas", {}, "Abas técnicas do Konsole", "Technical Konsole tabs",
                            "O título das abas do Konsole vira um código de terminal (TTY-1 │ pasta).",
                            "Konsole tab titles become a terminal code (TTY-1 │ folder)."),
    "estilo-dica": ("dica", {}, "Estilo da dica", "Tooltip style",
                    "As dicas (tooltips) com chanfro, faixa no alto, marcador lateral ou cantoneiras.",
                    "Tooltips with a chamfer, a top strip, a side marker or corner brackets."),
    "estilo-campos": ("campos", {}, "Campos de texto", "Text fields",
                      "Campos com caixa, só a linha de baixo, ou fundo sem contorno.",
                      "Fields with a box, only the bottom line, or a borderless block."),
    "estilo-estados": ("perigo", {"atencao": "atencao", "sucesso": "sucesso"}, "Cores de estado", "State colors",
                       "Cores de erro, atenção e sucesso, separadas da cor de destaque.",
                       "Error, warning and success colors, apart from the accent color."),
}

# Presets (catálogo, seção 10). O que não aparece fica no padrão. "corp" = corporação sugerida no painel
# (o preset não troca a paleta).
PRESETS = {
    "neomilitar": ("Neomilitar", "Neo-military", "O tema de sempre.", "The usual theme.", None, {}),
    "militar-denso": ("Militar denso", "Dense military", "Compacto, seleção e abas em bloco, chanfro pequeno.",
                      "Compact, block selection and tabs, small chamfer.", "militech",
                      {"corte": "canto", "tamanho": "pequeno", "densidade": "compacto", "abas": "bloco",
                       "selecao": "bloco", "progresso": "segmentada", "dica": "marcador",
                       "konsole_abas": "tecnico", "pecas": "cyberkde"}),
    "netwatch-limpo": ("NetWatch limpo", "Clean NetWatch", "Espaçoso, fio com cantoneiras, faixa no alto e grade fraca nos popups.",
                       "Spacious, thin line with corner brackets, top strip and a faint grid in popups.", "netwatch",
                       {"corte": "topo", "moldura": "misto", "marcador": "topo", "brilho": "suave",
                        "abas": "sublinhada", "campos": "sublinhado", "selecao": "colchetes", "progresso": "lisa",
                        "dica": "faixa", "textura": "grade", "textura_onde": "popups", "densidade": "espacoso",
                        "foco": "cantoneira", "konsole_abas": "tecnico", "pecas": "cyberkde"}),
    "arasaka-luxo": ("Arasaka luxo", "Arasaka luxury", "Octógono pequeno, marcador parcial, brilho suave, espaçoso.",
                     "Small octagon, partial marker, soft glow, spacious.", "arasaka",
                     {"corte": "octogono", "tamanho": "pequeno", "marcador": "parcial", "brilho": "suave",
                      "abas": "sublinhada", "campos": "sublinhado", "progresso": "lisa", "dica": "faixa",
                      "densidade": "espacoso", "pecas": "cyberkde"}),
    "terminal-gasto": ("Terminal gasto", "Worn terminal", "Reto, sem marcador, pontos e scanline no Konsole.",
                       "Square, no marker, dots and scanlines in Konsole.", "ambar",
                       {"corte": "reto", "marcador": "nenhum", "abas": "bloco", "selecao": "bloco",
                        "progresso": "pontos", "textura": "scanline", "textura_onde": "konsole",
                        "densidade": "compacto", "konsole_abas": "tecnico", "pecas": "cyberkde"}),
    "kitsch-neon": ("Kitsch neon", "Neon kitsch", "Cantos opostos largos, brilho neon, hachura e cantoneiras no foco.",
                    "Wide opposite corners, neon glow, hatching and bracket focus.", "kiroshi",
                    {"corte": "oposto", "tamanho": "largo", "brilho": "neon", "abas": "bloco", "selecao": "bloco",
                     "progresso": "hachurada", "dica": "faixa", "foco": "cantoneira", "pecas": "cyberkde"}),
    "leitura": ("Leitura", "Reading", "Para sessões longas: espaçoso, liso, sem brilho e foco grosso.",
                "For long sessions: spacious, plain, no glow and a thick focus ring.", None,
                {"abas": "sublinhada", "progresso": "lisa", "densidade": "espacoso", "foco": "grosso",
                 "pecas": "cyberkde"}),
}


def nome(v):
    pt, en = NOMES.get(v, (v, v))
    return pt, en


def ler():
    try:
        d = json.loads(ARQ.read_text())
    except (OSError, ValueError):
        return {}
    return d if isinstance(d, dict) else {}


def gravar(d):
    ARQ.parent.mkdir(parents=True, exist_ok=True)
    tmp = ARQ.with_name(f".estilo.{os.getpid()}")
    tmp.write_text(json.dumps(d, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    tmp.replace(ARQ)


def valor(d, chave):
    v = d.get(chave)
    return v if v in ESTILO_VALORES[chave] else ESTILO_VALORES[chave][0]


def previa(chave, v):
    f = PREVIAS / f"{chave.replace('_', '-')}-{v}.png"
    return str(f) if f.is_file() else None


def preset_atual(d):
    """O preset gravado, se nada mudou depois dele; "personalizado" se mudou; "neomilitar" sem nada."""
    p = d.get("preset")
    escolhas = {k: v for k, v in d.items() if k in ESTILO_VALORES and v != ESTILO_VALORES[k][0]}
    if p in PRESETS:
        alvo = {k: v for k, v in PRESETS[p][5].items() if v != ESTILO_VALORES[k][0]}
        if alvo == escolhas:
            return p
    return "neomilitar" if not escolhas else "personalizado"


def estado(eid):
    d = ler()
    if eid == "estilo-preset":
        p = preset_atual(d)
        return {"variante": p, "padrao": "neomilitar", "ligado": p != "neomilitar",
                "valores": {k: valor(d, k) for k in ESTILO_VALORES}}
    chave, ops, *_ = EFEITOS[eid]
    v = valor(d, chave)
    return {"variante": v, "padrao": ESTILO_VALORES[chave][0], "ligado": v != ESTILO_VALORES[chave][0],
            "definido": chave in d, "opcoes": {o: valor(d, k) for o, k in ops.items()}}


def item(eid):
    if eid == "estilo-preset":
        variantes = [{"id": p, "nome": n, "nome_en": ne, "descricao": de, "descricao_en": den, "corp": c,
                      "valores": {k: v for k, v in vals.items()}, "previa": previa("preset", p)}
                     for p, (n, ne, de, den, c, vals) in PRESETS.items()]
        est = estado(eid)
        return {"id": eid, "nome": "Preset de interface", "nome_en": "Interface preset",
                "descricao": "Grava vários parâmetros de estilo de uma vez. Não troca a cor nem a corporação; o painel pode sugerir uma.",
                "descricao_en": "Sets several style options at once. It does not change the color or the corporation; the panel may suggest one.",
                "tipo": "variante", "grupo": "estilo", "ligado": est["ligado"], "variante": est["variante"],
                "variantes": variantes, "opcoes": [], "estado": est}
    chave, ops, n, ne, de, den = EFEITOS[eid]
    est = estado(eid)

    def lista(k):
        return [{"id": v, "nome": nome(v)[0], "nome_en": nome(v)[1], "previa": previa(k, v)} for v in ESTILO_VALORES[k]]
    opcoes = []
    for o, k in ops.items():
        rot = {"tamanho": ("Tamanho", "Size"), "onde": ("Onde", "Where"), "atencao": ("Atenção", "Warning"),
               "sucesso": ("Sucesso", "Success")}[o]
        opcoes.append({"id": o, "nome": rot[0], "nome_en": rot[1], "tipo": "escolha", "padrao": ESTILO_VALORES[k][0],
                       "valor": est["opcoes"][o], "escolhas": lista(k)})
    return {"id": eid, "nome": n, "nome_en": ne, "descricao": de, "descricao_en": den, "tipo": "variante",
            "grupo": "estilo", "ligado": est["ligado"], "variante": est["variante"], "variantes": lista(chave),
            "opcoes": opcoes, "estado": est}


def erro(pt, en):
    print(en if EN else pt, file=sys.stderr)
    sys.exit(2)


def lembrar(d, chave, v):
    """Guarda em d["_ultimo"] a última escolha não padrão de uma chave (ou do preset), para o "on" sozinho."""
    padrao = "neomilitar" if chave == "preset" else ESTILO_VALORES[chave][0]
    if v and v != padrao:
        ult = d.get("_ultimo") if isinstance(d.get("_ultimo"), dict) else {}
        d["_ultimo"] = dict(ult, **{chave: v})


def ultimo(d, chave):
    """A variante que o "on" sozinho liga: a última escolhida, ou a primeira que não é o padrão."""
    ult = d.get("_ultimo") if isinstance(d.get("_ultimo"), dict) else {}
    if chave == "preset":
        return ult.get("preset") if ult.get("preset") in PRESETS else next(p for p in PRESETS if p != "neomilitar")
    return ult.get(chave) if ult.get(chave) in ESTILO_VALORES[chave][1:] else ESTILO_VALORES[chave][1]


def aplicar(eid, args):
    acao, variante, extras = None, None, {}
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("on", "off"):
            acao = a
        elif a == "--variante" and i + 1 < len(args):
            variante, i = args[i + 1], i + 1
        elif a.startswith("--") and i + 1 < len(args):
            extras[a[2:]], i = args[i + 1], i + 1
        elif not a.startswith("-") and variante is None:
            variante = a
        else:
            erro(f"argumento inválido: {a}", f"invalid argument: {a}")
        i += 1
    d = ler()
    antes = dict(d)
    if eid == "estilo-preset":
        if extras:
            erro("o preset não tem opções", "the preset has no options")
        if acao == "on" and variante is None and preset_atual(d) in ("neomilitar", "personalizado"):
            variante = ultimo(d, "preset")
        if acao == "off" or variante == "neomilitar":
            lembrar(d, "preset", preset_atual(d))
            d = {"_ultimo": d["_ultimo"]} if "_ultimo" in d else {}
        elif variante is not None:
            if variante not in PRESETS:
                erro(f"preset desconhecido: {variante} (há: {', '.join(PRESETS)})",
                     f"unknown preset: {variante} (available: {', '.join(PRESETS)})")
            d = dict(PRESETS[variante][5], preset=variante, **({"_ultimo": d["_ultimo"]} if "_ultimo" in d else {}))
            lembrar(d, "preset", variante)
    else:
        chave, ops, *_ = EFEITOS[eid]
        for o in extras:
            if o not in ops:
                erro(f"opção desconhecida: --{o}", f"unknown option: --{o}")
        if acao == "on" and variante is None and valor(d, chave) == ESTILO_VALORES[chave][0]:
            variante = ultimo(d, chave)
            ult = d.get("_ultimo") if isinstance(d.get("_ultimo"), dict) else {}
            for o, k in ops.items():  # as opções lembradas (ex.: --tamanho) voltam junto, se não vieram agora
                if o not in extras and ult.get(k) in ESTILO_VALORES[k]:
                    extras[o] = ult[k]
        if acao == "off":
            for k in (chave, *ops.values()):
                lembrar(d, k, d.get(k))
            d.pop(chave, None)
            for k in ops.values():
                d.pop(k, None)
        if variante is not None:
            if variante not in ESTILO_VALORES[chave]:
                erro(f"valor inválido para {eid}: {variante} (há: {', '.join(ESTILO_VALORES[chave])})",
                     f"invalid value for {eid}: {variante} (available: {', '.join(ESTILO_VALORES[chave])})")
            d[chave] = variante
            lembrar(d, chave, variante)
        for o, v in extras.items():
            k = ops[o]
            if v not in ESTILO_VALORES[k]:
                erro(f"valor inválido para --{o}: {v} (há: {', '.join(ESTILO_VALORES[k])})",
                     f"invalid value for --{o}: {v} (available: {', '.join(ESTILO_VALORES[k])})")
            d[k] = v
            lembrar(d, k, v)
        # Valor igual ao padrão não precisa ficar gravado, salvo o progresso: escolhido, o Plasma
        # passa a usar o mesmo padrão dos apps (sem a chave, a barra do Plasma continua lisa).
        # A chave "preset" fica: o preset_atual diz "personalizado" quando algo mudou depois dele.
        for k in list(d):
            if k in ESTILO_VALORES and k != "progresso" and d[k] == ESTILO_VALORES[k][0]:
                del d[k]
    if d != antes:
        if d:
            gravar(d)
        else:
            ARQ.unlink(missing_ok=True)
    mudou = {k for k in set(d) | set(antes) if k in ESTILO_VALORES and d.get(k) != antes.get(k)}
    alvos = sorted({a for k in mudou for a in ALVOS[k].split()})
    print("\n".join(alvos))


def main():
    if len(sys.argv) < 2:
        erro(__doc__, __doc__)
    cmd, resto = sys.argv[1], sys.argv[2:]
    ids = list(EFEITOS) + ["estilo-preset"]
    if cmd == "ids":
        print("\n".join(ids))
        return
    if cmd == "estados":
        for eid in ids:
            print(f"{eid}\t{json.dumps(estado(eid), ensure_ascii=False)}")
        return
    if not resto or resto[0] not in ids:
        erro("efeito de estilo desconhecido", "unknown style effect")
    eid = resto[0]
    if cmd == "json":
        print(json.dumps(item(eid), ensure_ascii=False))
    elif cmd == "estado":
        print(json.dumps(estado(eid), ensure_ascii=False))
    elif cmd == "aplicar":
        aplicar(eid, resto[1:])
    else:
        erro(__doc__, __doc__)


if __name__ == "__main__":
    main()
