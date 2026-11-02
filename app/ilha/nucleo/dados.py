"""O que a própria ilha escreve: nota, gaveta e histórico de foco (~/.config/cyberkde/ilha-dados.json).
Clipboard e avisos NUNCA vêm para cá: memória, nunca disco (regra herdada do Halo)."""

import json
import os

from .config import dir_config

LIMITE_NOTA = 4000
LIMITE_GAVETA = 30
LIMITE_FOCO = 400


def _arquivo():
    return dir_config() / "ilha-dados.json"


def ler():
    d = {"nota": "", "gaveta": [], "foco": []}
    try:
        bruto = json.loads(_arquivo().read_text())
        if isinstance(bruto, dict):
            d["nota"] = str(bruto.get("nota", ""))[:LIMITE_NOTA]
            d["gaveta"] = [str(x) for x in bruto.get("gaveta", []) if isinstance(x, str)][:LIMITE_GAVETA]
            d["foco"] = [x for x in bruto.get("foco", []) if isinstance(x, dict)][-LIMITE_FOCO:]
    except (OSError, ValueError, TypeError):
        pass
    return d


def gravar(d):
    a = _arquivo()
    a.parent.mkdir(parents=True, exist_ok=True)
    tmp = a.with_suffix(f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(d, ensure_ascii=False, indent=1))
    os.chmod(tmp, 0o600)   # a nota é da usuária
    os.replace(tmp, a)
