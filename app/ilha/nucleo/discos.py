"""Discos removíveis por lsblk; montar e ejetar por udisksctl sem interação (o polkit decide). Nada aqui
toca arquivo do usuário. CYBERKDE_ILHA_DISCOS=<arquivo.json> (só testes) troca a saída do lsblk."""

import json
import os
import re

from .tarefas import cmd


def removiveis():
    falso = os.environ.get("CYBERKDE_ILHA_DISCOS")
    if falso:
        try:
            with open(falso) as f:
                arvore = json.load(f)["blockdevices"]
        except (OSError, ValueError, KeyError):
            return []
    else:
        s = cmd("lsblk", "-J", "-b", "-o", "NAME,PATH,RM,HOTPLUG,TRAN,MOUNTPOINT,LABEL,SIZE,TYPE,VENDOR,MODEL,FSTYPE,FSAVAIL", timeout=5)
        try:
            arvore = json.loads(s or "{}").get("blockdevices", [])
        except ValueError:
            return []
    res = []
    for b in arvore:
        if b.get("type") != "disk" or not (b.get("rm") or b.get("hotplug") or b.get("tran") == "usb"):
            continue
        res.append({"device": b.get("path"), "name": " ".join(filter(None, [(b.get("vendor") or "").strip(), (b.get("model") or "").strip()])) or b.get("name"),
                    "size": int(b.get("size") or 0),
                    "volumes": [{"device": c.get("path"), "label": c.get("label") or c.get("name"), "fstype": c.get("fstype") or "",
                                 "mountpoint": c.get("mountpoint"), "size": int(c.get("size") or 0),
                                 "avail": None if c.get("fsavail") is None else int(c["fsavail"])}
                                for c in b.get("children") or [] if c.get("type") == "part" and c.get("fstype")]})
    return res


def _udisks(*args):
    return cmd("udisksctl", *args, "--no-user-interaction", timeout=30)


def _conhecido(device):
    return any(device == d["device"] or any(device == v["device"] for v in d["volumes"]) for d in removiveis())


def montar(device):
    """Só dispositivos removíveis: a ilha nunca mexe no disco do sistema."""
    if not _conhecido(device):
        raise OSError("dispositivo não é removível")
    s = _udisks("mount", "-b", device)
    if s is None:
        raise OSError("não deu para montar")
    m = re.search(r"\s(/\S+)\.?\s*$", s.strip())
    return m.group(1) if m else ""


def ejetar(device):
    d = next((x for x in removiveis() if x["device"] == device), None)
    if not d:
        raise OSError("dispositivo não é removível")
    for v in d["volumes"]:
        if v["mountpoint"] and _udisks("unmount", "-b", v["device"]) is None:
            raise OSError(f"{v['label']} está em uso")
    if _udisks("power-off", "-b", device) is None:
        raise OSError("não deu para desligar o dispositivo")
