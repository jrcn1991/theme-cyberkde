"""Rede e Bluetooth: só leitura local (NetworkManager, /proc, BlueZ), mais ligar e desligar rádios."""

import json
import re
import time

from .i18n import ler, t
from .sistema import tamanho
from .tarefas import cmd

_vazao_antes = None


def conexao():
    s = cmd("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active")
    if s is None:
        return [ler("rede-conexao", t("Rede"), "—", t("NetworkManager não respondeu"), None, "alerta")]
    linhas = [ln.split(":") for ln in s.strip().splitlines() if ln and ":loopback:" not in ln]
    if not linhas:
        return [ler("rede-conexao", t("Rede"), t("desconectada"), "", None, "alerta")]
    nome = linhas[0][0].replace("\\:", ":")
    return [ler("rede-conexao", t("Rede"), nome, linhas[0][1].rsplit("-", 1)[-1] if len(linhas[0]) > 1 else "")]


def wifi():
    s = cmd("nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list", "--rescan", "no")
    if not s:
        return []
    for ln in s.splitlines():
        p = ln.split(":")
        if p[0] in ("yes", "sim") and len(p) >= 3 and p[1].isdigit():
            return [ler("wifi-sinal", t("Wi-Fi"), f"{p[1]}%", p[2], int(p[1]) / 100)]
    return []


def ip():
    s = cmd("ip", "-4", "-o", "addr", "show", "scope", "global")
    m = re.search(r"^\d+:\s+(?!docker|veth|br-|virbr)(\S+)\s+inet (\d+\.\d+\.\d+\.\d+)", s or "", re.M)
    return [ler("rede-ip", t("IP"), m.group(2), m.group(1))] if m else [ler("rede-ip", t("IP"), "—")]


def vazao():
    global _vazao_antes
    rx = tx = 0
    with open("/proc/net/dev") as f:
        for ln in f.readlines()[2:]:
            nome, resto = ln.split(":", 1)
            if nome.strip() == "lo" or re.match(r"(docker|veth|br-|virbr)", nome.strip()):
                continue
            c = resto.split()
            rx += int(c[0])
            tx += int(c[8])
    agora = time.monotonic()
    a, _vazao_antes = _vazao_antes, (agora, rx, tx)
    if not a or agora == a[0]:
        return [ler("rede-baixando", t("Baixando"), "—"), ler("rede-enviando", t("Enviando"), "—")]
    dt = agora - a[0]
    return [ler("rede-baixando", t("Baixando"), f"{tamanho((rx - a[1]) / dt)}/s"),
            ler("rede-enviando", t("Enviando"), f"{tamanho((tx - a[2]) / dt)}/s")]


def bluetooth():
    s = cmd("bluetoothctl", "show", timeout=2)
    if s is None:
        return [ler("bluetooth", t("Bluetooth"), "—", t("sem adaptador"))]
    ligado = "Powered: yes" in s
    d = cmd("bluetoothctl", "devices", "Connected", timeout=2) or ""
    nomes = [ln.split(" ", 2)[2] for ln in d.splitlines() if ln.count(" ") >= 2]
    return [ler("bluetooth", t("Bluetooth"), t("ligado") if ligado else t("desligado"), ", ".join(nomes)[:60])]


def bluetooth_bateria():
    """A bateria dos aparelhos, pelo BlueZ (só leitura, no barramento do sistema). A mais baixa primeiro."""
    s = cmd("busctl", "--system", "--json=short", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", timeout=2)
    try:
        objetos = (json.loads(s or "{}").get("data") or [{}])[0]
    except ValueError:
        objetos = {}
    lista = []
    for ifs in objetos.values():
        b, d = ifs.get("org.bluez.Battery1"), ifs.get("org.bluez.Device1")
        if b and d and "Percentage" in b:
            lista.append((int(b["Percentage"]["data"]), str((d.get("Alias") or d.get("Name") or {}).get("data", "?"))))
    lista.sort()
    if not lista:
        return [ler("bluetooth-bateria", t("Bateria Bluetooth"), "—", t("nenhum aparelho informa"))]
    return [ler("bluetooth-bateria", t("Bateria Bluetooth"), f"{lista[0][0]}%", " · ".join(f"{n} {c}%" for c, n in lista)[:60], lista[0][0] / 100, "alerta" if lista[0][0] <= 15 else "ok")]


def alternar_wifi():
    s = (cmd("nmcli", "radio", "wifi") or "").strip()
    if cmd("nmcli", "radio", "wifi", "off" if s in ("enabled", "habilitado") else "on") is None:
        raise OSError(t("não deu para mudar o Wi-Fi"))


def alternar_bluetooth():
    s = cmd("bluetoothctl", "show", timeout=2) or ""
    if cmd("bluetoothctl", "power", "off" if "Powered: yes" in s else "on", timeout=4) is None:
        raise OSError(t("não deu para mudar o Bluetooth"))
