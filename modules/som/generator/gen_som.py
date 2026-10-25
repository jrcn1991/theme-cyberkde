#!/usr/bin/env python3
"""Gerador do tema de sons CyberKDE: tudo sintetizado aqui (numpy + wave), sem material de terceiros.

Estilo de interface do Cyberpunk 2077: bipes digitais curtos, varreduras e glitches discretos.
Duas variantes: "padrao" (CyberKDE) e "discreto" (CyberKDE-discreto: mais suave, curta e baixa).

Uso:
  gen_som.py [--saida DIR] [--variante padrao|discreto] [--instalar DIR_SOUNDS] [--carimbo] [--lista]

Saída: DIR/<variante>/theme/{index.theme,stereo/<evento>.ogg}. O OGG vem do ffmpeg (libvorbis) ou do
oggenc; sem nenhum dos dois, fica WAV (o index.theme continua valendo, o canberra aceita .wav).
Nomes de eventos: tema de som freedesktop que o KDE usa (message-new-instant, desktop-login...).
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
AQUI = os.path.dirname(os.path.abspath(__file__))
PADRAO_SAIDA = os.path.join(os.path.dirname(AQUI), "build")

VARIANTES = {
    # nível: RMS alvo (dBFS) e teto de pico; escala: multiplica as durações; pureza: 1 = só seno
    "padrao": dict(nome="CyberKDE", comentario="Sons de interface cyberpunk sintetizados (bipes, varreduras e glitches discretos)",
                   comentario_en="Synthesized cyberpunk interface sounds (beeps, sweeps and subtle glitches)",
                   rms_db=-27.0, pico=0.45, escala=1.0, glitch=1.0, harm=1.0),
    "discreto": dict(nome="CyberKDE (discreto)", comentario="Versão suave e curta dos sons do CyberKDE",
                     comentario_en="Softer, shorter version of the CyberKDE sounds",
                     rms_db=-32.0, pico=0.28, escala=0.7, glitch=0.0, harm=0.25),
}
PASTA = {"padrao": "CyberKDE", "discreto": "CyberKDE-discreto"}

# evento -> (função, limites de duração em ms). Aliases abaixo reaproveitam o mesmo arquivo.
LIMITE = (80, 600)
LIMITE_LOGIN = (80, 1200)
ALIASES = {
    "message-new-instant": ["message-new-instant", "message", "message-new-email"],
    "dialog-information": ["dialog-information"],
    "dialog-warning": ["dialog-warning", "dialog-warning-auto"],
    "dialog-error": ["dialog-error", "dialog-error-serious", "dialog-error-critical"],
    "desktop-login": ["desktop-login"],
    "desktop-logout": ["desktop-logout"],
    "device-added": ["device-added"],
    "device-removed": ["device-removed"],
    "trash-empty": ["trash-empty"],
    "complete": ["complete", "completion-success"],
    "bell": ["bell", "bell-window-system"],
    "audio-volume-change": ["audio-volume-change"],
}

# ------------------------------------------------------------------ síntese


def n(ms):
    return int(round(SR * ms / 1000.0))


def env(num, ataque_ms=2.0, queda=6.0, fim_ms=4.0):
    """Ataque linear curto, decaimento exponencial (queda maior = mais seco) e fade final."""
    t = np.linspace(0.0, 1.0, num, endpoint=False)
    a = np.minimum(1.0, np.arange(num) / max(1, n(ataque_ms)))
    e = a * np.exp(-queda * t)
    f = min(num, n(fim_ms))
    if f:
        e[-f:] *= np.linspace(1.0, 0.0, f)
    return e


def varredura(f0, f1, ms, expo=True):
    """Fase de uma varredura de f0 a f1 (Hz)."""
    num = n(ms)
    t = np.linspace(0.0, 1.0, num, endpoint=False)
    if expo:
        f = f0 * (f1 / f0) ** t
    else:
        f = f0 + (f1 - f0) * t
    return 2 * np.pi * np.cumsum(f) / SR


def onda(fase, harm=1.0):
    """Seno com harmônicos ímpares leves (timbre 'digital'); harm=0 é seno puro."""
    s = np.sin(fase)
    if harm > 0:
        s = s + harm * (0.28 * np.sin(3 * fase) + 0.12 * np.sin(5 * fase))
    return s


def crush(x, bits):
    """Quantização: o grão digital. bits=16 praticamente não altera."""
    if bits >= 16:
        return x
    q = 2.0 ** (bits - 1)
    return np.round(x * q) / q


def bipe(f, ms, harm, queda=7.0, bits=16, ataque=1.5, f1=None):
    fase = varredura(f, f1 or f, ms)
    return crush(onda(fase, harm), bits) * env(n(ms), ataque, queda)


def toque(f, ms, queda=14.0):
    """Sino/tique: seno com decaimento rápido e parcial inarmônico."""
    num = n(ms)
    t = np.arange(num) / SR
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.76 * t)
    return s * env(num, 0.8, queda)


def ruido_filtrado(ms, f0, f1, rng, q=0.92):
    """Ruído passa-faixa com centro em varredura (efeito 'poeira digital')."""
    num = n(ms)
    r = rng.standard_normal(num)
    fc = f0 * (f1 / f0) ** np.linspace(0, 1, num, endpoint=False)
    out = np.zeros(num)
    y1 = y2 = 0.0
    for i in range(num):  # ressonador de 2 polos
        w = 2 * np.pi * fc[i] / SR
        b1 = 2 * q * np.cos(w)
        b2 = -q * q
        y = (1 - q) * r[i] + b1 * y1 + b2 * y2
        out[i] = y
        y2, y1 = y1, y
    m = np.max(np.abs(out)) or 1.0
    return out / m


def glitch(ms, rng, bits=4, retencao=6):
    """Rajada curta de ruído com amostragem retida e poucos bits: o 'pixel' do som."""
    num = n(ms)
    r = rng.uniform(-1, 1, num // retencao + 1)
    x = np.repeat(r, retencao)[:num]
    return crush(x, bits) * env(num, 0.5, 5.0, 2.0)


def colocar(base, trecho, ms, ganho=1.0):
    i = n(ms)
    fim = i + len(trecho)
    if fim > len(base):
        base = np.concatenate([base, np.zeros(fim - len(base))])
    base[i:fim] += trecho * ganho
    return base


def eco(x, atraso_ms, mix, vezes=3):
    """Cauda curta e escura (ecos filtrados), só para dar espaço."""
    d = n(atraso_ms)
    out = np.concatenate([x, np.zeros(d * vezes)])
    for k in range(1, vezes + 1):
        ec = x * (mix ** k)
        ec = np.convolve(ec, np.ones(3) / 3.0, mode="same")
        out[k * d:k * d + len(x)] += ec
    return out


# ------------------------------------------------------------------ os sons
# Cada função devolve um vetor mono; v = parâmetros da variante. Durações já multiplicadas por v["escala"]
# nos sons que podem encurtar; as notas ficam nas alturas do tema (A5..E7, nada estridente).


def som_mensagem(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    x = colocar(x, bipe(1318.5, 55 * s, h, 8, 8 if h > 0.5 else 16), 0)
    x = colocar(x, bipe(1760.0, 75 * s, h, 7, 8 if h > 0.5 else 16), 85 * s, 0.85)
    if v["glitch"]:
        x = colocar(x, glitch(14, rng, 3), 160, 0.08)
    return eco(x, 38, 0.22, 2)


def som_informacao(v, rng):
    s, h = v["escala"], v["harm"]
    x = bipe(990.0, 130 * s, h, 6, 16, f1=1320.0)
    return eco(x, 45, 0.2, 2)


def som_aviso(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    x = colocar(x, bipe(740.0, 85 * s, h, 5, 8 if h > 0.5 else 16), 0)
    x = colocar(x, bipe(740.0, 85 * s, h, 5, 8 if h > 0.5 else 16), 125 * s, 0.9)
    x = colocar(x, bipe(554.4, 110 * s, h, 6, 16), 250 * s, 0.7)
    return x


def som_erro(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    # queda de tom com serrilhado (dente de serra suave) + rachadura digital
    fase = varredura(520.0, 190.0, 190 * s)
    serra = 2 * ((fase / (2 * np.pi)) % 1.0) - 1
    corpo = (0.55 * np.sin(fase) + 0.2 * serra * (0.3 + 0.7 * h)) * env(n(190 * s), 1.5, 3.5)
    x = colocar(x, corpo, 0)
    x = colocar(x, bipe(247.0, 120 * s, h * 0.5, 6, 8 if h > 0.5 else 16), 200 * s, 0.8)
    if v["glitch"]:
        x = colocar(x, glitch(35, rng, 3, 5), 20, 0.22)
        x = colocar(x, glitch(25, rng, 3, 7), 230, 0.14)
    return x


def som_login(v, rng):
    s, h = v["escala"], v["harm"]
    total = 1050 * s if v["glitch"] else 560
    x = np.zeros(n(total))
    # varredura ascendente de fundo (o sistema 'sobe') com ruído passa-faixa fino
    sw = np.sin(varredura(140.0, 620.0, total * 0.6)) * env(n(total * 0.6), 80 * s, 2.0, 40)
    x = colocar(x, sw, 0, 0.35 if v["glitch"] else 0.2)
    if v["glitch"]:
        x = colocar(x, ruido_filtrado(260, 400, 4200, rng) * env(n(260), 40, 3.0, 20), 40, 0.12)
        x = colocar(x, glitch(16, rng, 3, 5), 260, 0.12)
        x = colocar(x, glitch(12, rng, 3, 4), 520, 0.1)
    # arpejo de confirmação
    passo = 150 * s if v["glitch"] else 110
    base = total * 0.28
    for k, f in enumerate((659.3, 987.8, 1318.5, 1975.5)):
        x = colocar(x, bipe(f, 190 * s, h, 5, 16, 1.5), base + k * passo, 0.7 - k * 0.04)
    return eco(x, 60, 0.25, 2)


def som_logout(v, rng):
    s, h = v["escala"], v["harm"]
    total = 700 * s if v["glitch"] else 420
    x = np.zeros(n(total))
    passo = 105 * s
    for k, f in enumerate((1318.5, 987.8, 659.3, 440.0)):
        x = colocar(x, bipe(f, 150 * s, h, 6, 16), k * passo, 0.75 - k * 0.05)
    sw = np.sin(varredura(700.0, 110.0, total * 0.75)) * env(n(total * 0.75), 10, 3.0, 40)
    x = colocar(x, sw, total * 0.1, 0.25 if v["glitch"] else 0.15)
    if v["glitch"]:
        x = colocar(x, glitch(14, rng, 3, 6), total * 0.7, 0.1)
    return x


def som_dispositivo_conectado(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    x = colocar(x, bipe(700.0, 105 * s, h, 3, 16, 1.5, f1=1400.0), 0, 0.7)
    x = colocar(x, bipe(1400.0, 70 * s, h, 7, 16), 110 * s, 0.9)
    return x


def som_dispositivo_removido(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    x = colocar(x, bipe(1400.0, 70 * s, h, 5, 16), 0, 0.8)
    x = colocar(x, bipe(1400.0, 110 * s, h, 3, 16, 1.5, f1=620.0), 85 * s, 0.7)
    return x


def som_lixeira(v, rng):
    s = v["escala"]
    dur = 380 * s if v["glitch"] else 240
    x = np.zeros(n(dur))
    r = ruido_filtrado(dur * 0.8, 5200.0, 420.0, rng, 0.95)
    x = colocar(x, r * env(n(dur * 0.8), 3, 4.0, 15), 0, 0.5 if v["glitch"] else 0.3)
    x = colocar(x, toque(180.0, dur * 0.5, 9.0), 0, 0.5)
    if v["glitch"]:
        x = colocar(x, glitch(30, rng, 3, 8), dur * 0.35, 0.2)
        x = colocar(x, glitch(24, rng, 3, 6), dur * 0.62, 0.14)
    return x


def som_completar(v, rng):
    s, h = v["escala"], v["harm"]
    x = np.zeros(1)
    for k, (f, g) in enumerate(((880.0, 0.7), (1108.7, 0.8), (1480.0, 1.0))):
        x = colocar(x, bipe(f, 95 * s if k < 2 else 150 * s, h, 6, 16), k * 85 * s, g)
    return eco(x, 42, 0.2, 2)


def som_campainha(v, rng):
    s = v["escala"]
    x = toque(1500.0, 260 * s, 10.0)
    return eco(x, 55, 0.22, 2)[:n(300 * s)]


def som_volume(v, rng):
    s, h = v["escala"], v["harm"]
    return bipe(1046.5, 88, h * 0.5, 14, 16, 1.0) + 0.0


SONS = {
    "message-new-instant": som_mensagem,
    "dialog-information": som_informacao,
    "dialog-warning": som_aviso,
    "dialog-error": som_erro,
    "desktop-login": som_login,
    "desktop-logout": som_logout,
    "device-added": som_dispositivo_conectado,
    "device-removed": som_dispositivo_removido,
    "trash-empty": som_lixeira,
    "complete": som_completar,
    "bell": som_campainha,
    "audio-volume-change": som_volume,
}


def acabar(x, v):
    """Tira o DC, apara o silêncio do fim, normaliza pelo RMS (com teto de pico) e dá fade."""
    x = x - np.mean(x)
    ativo = np.where(np.abs(x) > 0.002 * (np.max(np.abs(x)) or 1.0))[0]
    if len(ativo):
        x = x[: min(len(x), ativo[-1] + n(8))]
    rms = np.sqrt(np.mean(x ** 2)) or 1.0
    alvo = 10 ** (v["rms_db"] / 20.0)
    x = x * (alvo / rms)
    pico = np.max(np.abs(x))
    if pico > v["pico"]:
        x = x * (v["pico"] / pico)
    f = n(6)
    x[:min(len(x), 24)] *= np.linspace(0.0, 1.0, min(len(x), 24))
    x[-f:] *= np.linspace(1.0, 0.0, f)
    # duração mínima de 80 ms (o volume e o bipe seco chegam perto)
    if len(x) < n(LIMITE[0]):
        x = np.concatenate([x, np.zeros(n(LIMITE[0]) - len(x) + 1)])
    return x


def renderizar(variante, evento):
    # semente fixa por (variante, evento): a mesma saída em toda geração
    semente = int(hashlib.sha256(f"{variante}/{evento}".encode()).hexdigest()[:8], 16)
    rng = np.random.default_rng(semente)
    v = VARIANTES[variante]
    x = SONS[evento](v, rng)
    return acabar(np.asarray(x, dtype=np.float64), v)


# ------------------------------------------------------------------ gravação


def gravar_wav(caminho, x):
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    est = np.repeat(pcm[:, None], 2, axis=1)  # tema 'stereo': mesmo sinal nos dois canais
    with wave.open(caminho, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(est.tobytes())


def codificador():
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    if shutil.which("oggenc"):
        return "oggenc"
    return None


def para_ogg(wav, ogg, cod):
    if cod == "ffmpeg":
        cmd = ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", wav, "-map_metadata", "-1",
               "-c:a", "libvorbis", "-q:a", "4", "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg]
    else:
        cmd = ["oggenc", "-Q", "-q", "4", "-o", ogg, wav]
    subprocess.run(cmd, check=True)


def index_theme(variante):
    v = VARIANTES[variante]
    return (
        "[Sound Theme]\n"
        f"Name={v['nome']}\n"
        f"Comment={v['comentario']}\n"
        f"Comment[en]={v['comentario_en']}\n"
        "Inherits=ocean\n"  # eventos que o tema não cobre caem no Ocean, o padrão do KDE
        "Directories=stereo\n"
        "\n"
        "[stereo]\n"
        "OutputProfile=stereo\n"
    )


def gerar(variante, saida):
    cod = codificador()
    ext = "ogg" if cod else "wav"
    tema = os.path.join(saida, variante, "theme")
    est = os.path.join(tema, "stereo")
    if os.path.isdir(os.path.join(saida, variante)):
        shutil.rmtree(os.path.join(saida, variante))
    os.makedirs(est)
    with open(os.path.join(tema, "index.theme"), "w", encoding="utf-8") as f:
        f.write(index_theme(variante))
    relatorio = []
    with tempfile.TemporaryDirectory() as tmp:
        for evento in SONS:
            x = renderizar(variante, evento)
            ms = 1000.0 * len(x) / SR
            lo, hi = LIMITE_LOGIN if evento == "desktop-login" else LIMITE
            if not lo <= ms <= hi:
                raise SystemExit(f"{variante}/{evento}: {ms:.0f} ms fora de {lo}-{hi} ms")
            wav = os.path.join(tmp, evento + ".wav")
            gravar_wav(wav, x)
            destino = os.path.join(est, f"{evento}.{ext}")
            if cod:
                para_ogg(wav, destino, cod)
            else:
                shutil.copyfile(wav, destino)
            for alias in ALIASES[evento]:
                if alias != evento:
                    shutil.copyfile(destino, os.path.join(est, f"{alias}.{ext}"))
            pico = float(np.max(np.abs(x)))
            rms = float(np.sqrt(np.mean(x ** 2)))
            relatorio.append(dict(evento=evento, ms=round(ms), pico_db=round(20 * np.log10(pico), 1),
                                  rms_db=round(20 * np.log10(rms), 1), arquivo=destino))
    return relatorio


def carimbo():
    h = hashlib.sha256()
    with open(os.path.abspath(__file__), "rb") as f:
        h.update(f.read())
    h.update((codificador() or "wav").encode())
    return h.hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--saida", default=PADRAO_SAIDA)
    ap.add_argument("--variante", choices=list(VARIANTES))
    ap.add_argument("--instalar", metavar="DIR_SOUNDS", help="copia para DIR_SOUNDS/CyberKDE[-discreto]")
    ap.add_argument("--carimbo", action="store_true", help="imprime a impressão digital do gerador e sai")
    ap.add_argument("--lista", action="store_true", help="imprime o relatório em JSON")
    a = ap.parse_args()
    if a.carimbo:
        print(carimbo())
        return
    todos = []
    for var in ([a.variante] if a.variante else list(VARIANTES)):
        rel = gerar(var, a.saida)
        todos.append(dict(variante=var, sons=rel))
        with open(os.path.join(a.saida, var, ".carimbo"), "w") as f:
            f.write(carimbo())
        if a.instalar:
            dest = os.path.join(a.instalar, PASTA[var])
            if os.path.isdir(dest):
                shutil.rmtree(dest)
            shutil.copytree(os.path.join(a.saida, var, "theme"), dest)
    with open(os.path.join(a.saida, ".carimbo"), "w") as f:
        f.write(carimbo())
    if a.lista:
        json.dump(todos, sys.stdout, ensure_ascii=False, indent=1)
        print()
    else:
        for t in todos:
            print(f"[{t['variante']}]")
            for s in t["sons"]:
                print(f"  {s['evento']:22s} {s['ms']:5d} ms  pico {s['pico_db']:6.1f} dB  rms {s['rms_db']:6.1f} dB")


if __name__ == "__main__":
    main()
