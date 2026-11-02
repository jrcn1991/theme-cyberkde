"""Etiquetas, avaliação e comentário em atributos estendidos, compatíveis com o Baloo/Dolphin:
user.xdg.tags (lista separada por vírgula), user.baloo.rating (0 a 10, meia estrela = 1) e
user.xdg.comment. Sistemas de arquivos sem xattr (vfat, alguns de rede) simplesmente não têm nada."""

import os

TAGS = "user.xdg.tags"
AVALIACAO = "user.baloo.rating"
COMENTARIO = "user.xdg.comment"


def _ler(caminho, nome):
    try:
        return os.getxattr(caminho, nome).decode("utf-8", "replace")
    except OSError:
        return ""


def ler(caminho):
    """{"tags": [...], "avaliacao": int, "comentario": str}"""
    tags = [t.strip() for t in _ler(caminho, TAGS).split(",") if t.strip()]
    try:
        av = max(0, min(10, int(_ler(caminho, AVALIACAO) or 0)))
    except ValueError:
        av = 0
    return {"tags": tags, "avaliacao": av, "comentario": _ler(caminho, COMENTARIO)}


def _gravar_attr(caminho, nome, valor):
    if valor:
        os.setxattr(caminho, nome, valor.encode("utf-8"))
    else:
        try:
            os.removexattr(caminho, nome)
        except OSError as e:
            if e.errno not in (61, 95):   # ENODATA (não havia), EOPNOTSUPP
                raise


def gravar(caminho, dados):
    """dados: o mesmo formato de ler(); só grava as chaves presentes."""
    if "tags" in dados:
        vistos = []
        for t in dados["tags"]:
            t = str(t).strip().replace(",", " ")
            if t and t not in vistos:
                vistos.append(t)
        _gravar_attr(caminho, TAGS, ",".join(vistos))
    if "avaliacao" in dados:
        n = max(0, min(10, int(dados["avaliacao"] or 0)))
        _gravar_attr(caminho, AVALIACAO, str(n) if n else "")
    if "comentario" in dados:
        _gravar_attr(caminho, COMENTARIO, str(dados["comentario"] or ""))
