#!/usr/bin/env python3
"""Espectro real do widget CyberKDE · Mídia (opção "Espectro real", desligada por padrão).

Lê o monitor da saída de som padrão (o que está tocando) pelo PipeWire (pw-record, captura da saída) ou,
na falta dele, pelo parec (@DEFAULT_MONITOR@); faz uma FFT (numpy) e escreve 12 níveis de 0 a 1, um por
banda do equalizador (40 Hz … 18 kHz), ~30 vezes por segundo, numa linha do arquivo --saida (troca
atômica). Só lê áudio: não grava nada além desse arquivo, não abre porta, não toca som.

Encerra sozinho quando o "aluguel" (--aluguel, um arquivo que o widget toca a cada 2 s) passa de 4 s sem
ser renovado (widget pausado, removido ou com o movimento mínimo), ou quando a captura acaba.
Uso:  espectro.py --saida ARQ --aluguel ARQ [--entrada -] [--fps 30]
  --entrada -   lê PCM s16le mono 44,1 kHz da entrada padrão (testes), sem abrir captura nenhuma.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

import numpy as np

TAXA = 44100
CENTROS = [40, 100, 300, 600, 1000, 2000, 4000, 6000, 9000, 12000, 16000, 18000]
JANELA = 2048


def bordas():
    """Limites de cada banda: média geométrica entre centros vizinhos."""
    c = CENTROS
    b = [c[0] / 1.6]
    for i in range(len(c) - 1):
        b.append((c[i] * c[i + 1]) ** 0.5)
    b.append(min(TAXA / 2 - 1, c[-1] * 1.12))
    return b


def abrir_captura():
    if shutil.which("pw-record"):
        cmd = ["pw-record", "-P", "{ stream.capture.sink = true }", "--rate", str(TAXA),
               "--channels", "1", "--format", "s16", "-"]
    elif shutil.which("parec"):
        cmd = ["parec", "--device=@DEFAULT_MONITOR@", "--format=s16le", "--rate=%d" % TAXA,
               "--channels=1", "--raw"]
    else:
        sys.exit(3)
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", required=True)
    ap.add_argument("--aluguel", required=True)
    ap.add_argument("--entrada", default="")
    ap.add_argument("--fps", type=int, default=30)
    a = ap.parse_args()

    proc = None
    if a.entrada == "-":
        fonte = sys.stdin.buffer
    else:
        proc = abrir_captura()
        fonte = proc.stdout
    passo = TAXA // max(5, min(60, a.fps))
    freqs = np.fft.rfftfreq(JANELA, 1 / TAXA)
    b = bordas()
    faixas = [(np.searchsorted(freqs, b[i]), max(np.searchsorted(freqs, b[i]) + 1, np.searchsorted(freqs, b[i + 1])))
              for i in range(len(CENTROS))]
    # agudos têm menos energia: compensação de ~3 dB por oitava acima de 1 kHz
    inclinacao = np.array([3.0 * np.log2(max(c, 1000) / 1000) for c in CENTROS])
    hann = np.hanning(JANELA)
    buf = np.zeros(JANELA, dtype=np.float32)
    teto = 1e-3                     # ganho automático: o máximo recente
    suave = np.zeros(len(CENTROS))
    tmp = a.saida + ".tmp"
    try:
        while True:
            try:
                if time.time() - os.path.getmtime(a.aluguel) > 4:
                    break
            except OSError:
                break
            bruto = fonte.read(passo * 2)
            if not bruto or len(bruto) < 2:
                break
            novo = np.frombuffer(bruto[: len(bruto) // 2 * 2], dtype="<i2").astype(np.float32) / 32768.0
            buf = np.concatenate([buf, novo])[-JANELA:]
            esp = np.abs(np.fft.rfft(buf * hann))
            db = np.array([20 * np.log10(np.sqrt(np.mean(esp[i:j] ** 2)) + 1e-9) for i, j in faixas]) + inclinacao
            # -60 dB abaixo do teto → 0; o teto acompanha a música (sobe rápido, desce devagar)
            pico = float(db.max())
            teto = max(pico, teto - 0.15) if teto > -200 else pico
            niveis = np.clip((db - (teto - 60)) / 60, 0, 1)
            if np.sqrt(np.mean(novo ** 2)) < 1e-4:
                niveis[:] = 0       # silêncio de verdade: barras no chão
            suave = np.where(niveis > suave, niveis, suave * 0.82 + niveis * 0.18)
            with open(tmp, "w") as f:
                f.write(" ".join("%.3f" % v for v in suave) + "\n")
            os.replace(tmp, a.saida)
    finally:
        if proc:
            proc.terminate()
        for f in (tmp, a.saida):
            try:
                os.remove(f)
            except OSError:
                pass


if __name__ == "__main__":
    main()
