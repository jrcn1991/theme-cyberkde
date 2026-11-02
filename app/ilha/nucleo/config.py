"""Configuração da ilha: ~/.config/cyberkde/ilha.json, com esquema validado (spec seção 5).
Sem Qt: o `--definir` e o `--esquema` que o CLI chama respondem sem subir nada gráfico."""

import json
import os
import re
from pathlib import Path

MOVIMENTOS = ["gota", "elastico", "desliza", "expandir", "nenhuma"]
ESTILOS = ["preto", "degrade", "vidro"]
VOOS = ["sugado", "foguete", "nenhuma"]
MODULOS = ["sistema", "audio", "midia", "rede", "bluetooth", "kde", "relogio", "clipboard", "avisos", "downloads",
           "capturas", "gaveta", "janelas", "celular", "discos", "teclado", "foco", "api"]

# chave: (tipo, padrão, regra, rótulo PT, rótulo EN)
ESQUEMA = {
    "tela": ("texto", "principal", None, "Tela da ilha", "Island screen"),
    "assento": ("escolha", "sobre", ["sobre", "abaixo"], "Posição em relação à barra", "Position relative to the panel"),
    "abertura": ("escolha", "hover", ["hover", "clique"], "Gesto de abrir", "Opening gesture"),
    "movimento": ("texto", "gota", MOVIMENTOS, "Animação da ilha", "Island animation"),
    "tema": ("texto", "halo", None, "Tema", "Theme"),
    "estilo": ("escolha", "preto", ESTILOS, "Estilo da ilha aberta", "Open island style"),
    "voo": ("escolha", "sugado", VOOS, "Animação do voo", "Flight animation"),
    "alturaPilula": ("inteiro", 36, (24, 48), "Altura da pílula", "Pill height"),
    "opacidadeOciosa": ("inteiro", 55, (0, 100), "Opacidade em repouso", "Idle opacity"),
    "pilula": ("escolha", "simples", ["simples", "satelites"], "Pílula fechada", "Closed pill"),
    "layout": ("escolha", "folha", ["folha", "trilho"], "Layout da ilha aberta", "Open island layout"),
    "alinhamento": ("escolha", "centro", ["esquerda", "centro", "direita"], "Alinhamento na tela", "Screen alignment"),
    "cantos": ("inteiro", -1, (-1, 40), "Raio dos cantos da ilha aberta (-1 = o do tema)", "Open island corner radius (-1 = theme's)"),
    "cor": ("escolha", "tema", ["tema", "destaque", "secundaria", "alerta"], "Cor de destaque da ilha", "Island accent color"),
    "hud": ("bool", True, None, "HUD de volume", "Volume HUD"),
    "avisos": ("bool", True, None, "Anunciar notificações", "Announce notifications"),
    "clipboard": ("bool", True, None, "Histórico da área de transferência (só em memória)", "Clipboard history (memory only)"),
    "espectro": ("bool", True, None, "Espectro de áudio", "Audio spectrum"),
    "api": ("bool", True, None, "API local para scripts", "Local API for scripts"),
    "esconderTelaCheia": ("bool", True, None, "Sumir com janela em tela cheia", "Hide on fullscreen windows"),
    "letras": ("bool", False, None, "Letras sincronizadas (envia título e artista a lrclib.net)",
               "Synced lyrics (sends title and artist to lrclib.net)"),
    "atalhoJanela": ("bool", False, None, "Atalho Meta+Alt+J: guardar a janela ativa", "Meta+Alt+J: stash the active window"),
    "atalhoAbrir": ("tecla", "", None, "Atalho: abrir e fechar a ilha", "Shortcut: open and close the island"),
    "atalhoFoco": ("tecla", "", None, "Atalho: iniciar ou parar 25 min de foco", "Shortcut: start or stop 25 min of focus"),
    "atalhoNota": ("tecla", "", None, "Atalho: abrir a nota", "Shortcut: open the note"),
    "clima": ("bool", False, None, "Clima na ilha (consulta open-meteo.com com as coordenadas do widget)",
              "Weather on the island (queries open-meteo.com with the widget's coordinates)"),
    "conviverComHalo": ("bool", False, None, "Mostrar mesmo com a ilha do Halo ativa", "Show even with Halo's island active"),
    "modulos": ("lista", [], MODULOS, "Módulos ligados (vazio = todos)", "Enabled modules (empty = all)"),
    "relogios": ("lista", [], None, "Relógios de outros fusos", "Other time zones"),
}


def dir_config():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "cyberkde"


def arquivo():
    return dir_config() / "ilha.json"


def padroes():
    return {k: (list(v[1]) if isinstance(v[1], list) else v[1]) for k, v in ESQUEMA.items()}


def validar(chave, valor):
    """(valor normalizado, "") ou (None, erro). Arquivo editável à mão precisa sobreviver a lixo."""
    if chave not in ESQUEMA:
        return None, f"chave desconhecida: {chave}"
    tipo, _p, regra, _pt, _en = ESQUEMA[chave]
    if tipo == "bool":
        if isinstance(valor, str) and valor.lower() in ("true", "false", "1", "0", "on", "off"):
            return valor.lower() in ("true", "1", "on"), ""
        return (valor, "") if isinstance(valor, bool) else (None, f"{chave}: esperava verdadeiro ou falso")
    if tipo == "inteiro":
        try:
            n = int(valor)
        except (TypeError, ValueError):
            return None, f"{chave}: esperava um número"
        return max(regra[0], min(regra[1], n)), ""
    if tipo == "escolha":
        return (valor, "") if valor in regra else (None, f"{chave}: use {', '.join(regra)}")
    if tipo == "lista":
        if isinstance(valor, str):
            valor = [v.strip() for v in valor.split(",") if v.strip()]
        if not isinstance(valor, list) or not all(isinstance(v, str) for v in valor):
            return None, f"{chave}: esperava uma lista"
        if regra:
            ruins = [v for v in valor if v not in regra]
            if ruins:
                return None, f"{chave}: desconhecido: {', '.join(ruins)}"
        return valor, ""
    if tipo == "tecla":   # "" = sem atalho
        if valor == "" or (isinstance(valor, str) and re.fullmatch(r"(?:(?:Meta|Ctrl|Alt|Shift)\+)*[A-Za-z0-9]{1,6}", valor)):
            return valor, ""
        return None, f"{chave}: use algo como Meta+Shift+I"
    # texto livre (ids de temas e movimentos da Rachael, nomes de tela)
    if not isinstance(valor, str) or not re.fullmatch(r"[\w.:-]{1,64}", valor):
        return None, f"{chave}: valor inválido"
    return valor, ""


def ler():
    cfg = padroes()
    try:
        bruto = json.loads(arquivo().read_text())
    except (OSError, ValueError):
        return cfg
    if isinstance(bruto, dict):
        for k, v in bruto.items():
            if k in ESQUEMA:
                n, erro = validar(k, v)
                if not erro:
                    cfg[k] = n
    return cfg


def gravar(cfg):
    a = arquivo()
    a.parent.mkdir(parents=True, exist_ok=True)
    tmp = a.with_suffix(f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(cfg, ensure_ascii=False, indent=1))
    os.replace(tmp, a)


def definir(chave, valor):
    """Valida e grava. Devolve "" ou a mensagem de erro."""
    n, erro = validar(chave, valor)
    if erro:
        return erro
    cfg = ler()
    cfg[chave] = n
    gravar(cfg)
    return ""


def esquema_json():
    saida = []
    for k, (tipo, padrao, regra, pt, en) in ESQUEMA.items():
        item = {"chave": k, "tipo": tipo, "padrao": padrao, "nome": pt, "nome_en": en}
        if tipo == "inteiro":
            item.update(min=regra[0], max=regra[1])
        elif regra:
            item["valores"] = regra
        saida.append(item)
    return saida
