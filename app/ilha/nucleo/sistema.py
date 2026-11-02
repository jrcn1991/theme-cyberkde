"""Leituras do sistema (`/proc` e comandos). Funções puras, chamadas numa thread do pulso."""

import json
import os
import re
import shutil
import time

from .i18n import ler, t
from .tarefas import cmd

_cpu_antes = None


def tamanho(n):
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1000 or u == "TB":
            return f"{n:.0f} {u}" if u == "B" else f"{n:.1f} {u}"
        n /= 1000


def cpu():
    global _cpu_antes
    with open("/proc/stat") as f:
        c = [int(x) for x in f.readline().split()[1:9]]
    ocioso, total = c[3] + c[4], sum(c)
    a, _cpu_antes = _cpu_antes, (ocioso, total)
    if not a or total == a[1]:
        return ler("cpu", t("Processador"), "—")
    p = 1 - (ocioso - a[0]) / (total - a[1])
    return ler("cpu", t("Processador"), f"{p * 100:.0f}%", "", round(p, 3), "alerta" if p > 0.9 else "ok")


def memoria():
    m = {}
    with open("/proc/meminfo") as f:
        for ln in f:
            k, v = ln.split(":", 1)
            m[k] = int(v.split()[0]) * 1024
    usado = m["MemTotal"] - m.get("MemAvailable", 0)
    r = usado / m["MemTotal"]
    return ler("memoria", t("Memória"), tamanho(usado), t("de {total}", total=tamanho(m["MemTotal"])), round(r, 3),
               "alerta" if r > 0.9 else "ok")


def carga():
    a, b, c = os.getloadavg()
    return ler("carga", t("Carga"), f"{a:.2f}", f"{b:.2f} · {c:.2f}")


def uptime():
    with open("/proc/uptime") as f:
        s = float(f.read().split()[0])
    return ler("uptime", t("Ligado há"), f"{int(s // 3600)} h {int(s % 3600 // 60)} min")


def disco_raiz():
    u = shutil.disk_usage("/")
    r = u.used / u.total
    return ler("disco-raiz", t("Disco"), t("{livre} livres", livre=tamanho(u.free)), "/", round(r, 3), "alerta" if r > 0.9 else "ok")


def temperatura():
    melhor = None
    for z in sorted(os.listdir("/sys/class/hwmon")) if os.path.isdir("/sys/class/hwmon") else []:
        base = f"/sys/class/hwmon/{z}"
        try:
            with open(f"{base}/name") as f:
                nome = f.read().strip()
            if nome not in ("coretemp", "k10temp", "zenpower", "cpu_thermal"):
                continue
            with open(f"{base}/temp1_input") as f:
                melhor = int(f.read()) / 1000
            break
        except OSError:
            continue
    if melhor is None:
        return ler("temp-cpu", t("Temperatura"), "—", t("sem sensor"))
    return ler("temp-cpu", t("Temperatura"), f"{melhor:.0f} °C", "", None, "alerta" if melhor >= 85 else "ok")


def gpu():
    s = cmd("nvidia-smi", "--query-gpu=temperature.gpu,memory.used,memory.total,utilization.gpu", "--format=csv,noheader,nounits", timeout=2)
    if not s:
        return []
    try:
        temp, usado, total, uso = (float(x) for x in s.splitlines()[0].split(","))
    except ValueError:
        return []
    return [ler("gpu-uso", t("GPU"), f"{uso:.0f}%", "", round(uso / 100, 3)), ler("gpu-temp", t("Temperatura da GPU"), f"{temp:.0f} °C", "", None, "alerta" if temp >= 85 else "ok"),
            ler("gpu-memoria", t("Memória da GPU"), f"{usado / 1024:.1f} GB", t("de {total}", total=f"{total / 1024:.1f} GB"), round(usado / total, 3))]


def processo_topo():
    s = cmd("ps", "-eo", "comm,%cpu", "--sort=-%cpu", "--no-headers")
    if not s:
        return ler("processo-topo", t("Mais pesado"), "—")
    p = s.splitlines()[0].rsplit(None, 1)
    return ler("processo-topo", t("Mais pesado"), p[0], f"{p[1]}%")


def falhas():
    s = cmd("systemctl", "--user", "--failed", "--no-legend", "--plain")
    n = len(s.strip().splitlines()) if s and s.strip() else 0
    return ler("systemd-falhas", t("Serviços com falha"), str(n), "", None, "alerta" if n else "ok")


def portas():
    """Só leitura. O `ss` só dá o dono das portas do próprio usuário; as do sistema vêm sem nome."""
    s = cmd("ss", "-ltnpH")
    if s is None:
        return ler("portas-escuta", t("Portas em escuta"), "—")
    vistas = {}
    for ln in s.splitlines():
        m = re.search(r":(\d+)\s+\S+:\*", ln)
        if m:
            q = re.search(r'users:\(\("([^"]+)"', ln)
            vistas.setdefault(int(m.group(1)), q.group(1) if q else "")
    resumo = " · ".join(f"{p} {q}".strip() for p, q in sorted(vistas.items())[:4])
    return ler("portas-escuta", t("Portas em escuta"), str(len(vistas)), resumo)


def leituras():
    r = [cpu(), memoria(), carga(), uptime(), disco_raiz(), temperatura(), processo_topo(), falhas(), portas()]
    return r + gpu()


def relogios(fusos):
    from datetime import datetime
    from zoneinfo import ZoneInfo
    agora = time.localtime()
    r = [ler("relogio-hora", t("Hora"), time.strftime("%H:%M", agora)), ler("relogio-data", t("Data"), time.strftime("%d/%m/%Y", agora))]
    for z in fusos:
        try:
            r.append(ler("relogio-mundo", z.rsplit("/", 1)[-1].replace("_", " "), datetime.now(ZoneInfo(z)).strftime("%H:%M"), z))
        except (KeyError, ValueError, OSError):
            r.append(ler("relogio-mundo", z, "—", t("fuso desconhecido"), None, "alerta"))
    return r


# códigos WMO do Open-Meteo, por faixa
_WMO = ((0, "céu limpo"), (3, "nublado"), (48, "neblina"), (67, "chuva"), (77, "neve"), (82, "pancadas de chuva"), (86, "neve"), (99, "tempestade"))
_clima = {"em": -1e9, "chave": None, "dados": None}
CLIMA_TTL = 1800


def condicao(codigo):
    return next((n for lim, n in _WMO if codigo <= lim), "—")


def coordenadas():
    """As do widget de clima do tema; ele não guarda a temperatura, só onde consultar."""
    from .config import dir_config
    for a in sorted((dir_config() / "widgets-dados").glob("clima-*.json")):
        try:
            d = json.loads(a.read_text())
            return float(d["General|latitude"]), float(d["General|longitude"]), str(d.get("General|cidadeResolvida") or d.get("General|cidade") or "")
        except (OSError, ValueError, KeyError):
            continue
    return None


def _consultar(lat, lon):
    import urllib.request   # só com a opção clima: puxa http, ssl e email, e a ilha fica residente
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code"
    req = urllib.request.Request(url, headers={"User-Agent": "cyberkde-ilha"})
    with urllib.request.urlopen(req, timeout=6) as r:
        c = json.load(r)["current"]
    return round(c["temperature_2m"]), int(c["weather_code"])


def clima(ligado):
    """Rede só com a opção `clima` (padrão: desligada). Cache de 30 min; falha de rede não apaga o último valor."""
    if not ligado:
        return [ler("clima-temp", t("Clima"), "—", t("desligado"))]
    c = coordenadas()
    if not c:
        return [ler("clima-temp", t("Clima"), "—", t("defina a cidade no widget de clima"))]
    agora = time.monotonic()
    if _clima["chave"] != c[:2] or agora - _clima["em"] >= CLIMA_TTL:
        _clima.update(em=agora, chave=c[:2])
        try:
            _clima["dados"] = _consultar(c[0], c[1])
        except (OSError, ValueError, KeyError):
            pass
    if not _clima["dados"]:
        return [ler("clima-temp", t("Clima"), "—", t("sem resposta"))]
    temp, cod = _clima["dados"]
    return [ler("clima-temp", t("Clima"), f"{temp}°", c[2]), ler("clima-condicao", t("Condição"), t(condicao(cod)))]
