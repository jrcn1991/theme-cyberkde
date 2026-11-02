"""O espectro de verdade: `parec` no monitor da saída (mono, 8 kHz: 16 kB/s) e energia em 5 faixas (DFT
nessas frequências), ~15 vezes por segundo. Só roda com a opção ligada E algo tocando; parado, o processo morre.

Sem numpy: as tabelas abaixo dão o mesmo resultado, e o numpy traria o OpenBLAS (uma thread parada por núcleo e
dezenas de MB) para um app residente, mesmo com o espectro desligado."""

import array
import math
from operator import mul

from PyQt6.QtCore import QObject, QProcess, QTimer, pyqtSignal

FAIXAS = (70, 200, 500, 1200, 3000)
TAXA = 8000
JANELA = 256
RITMO_MS = 66
PISO = 1e4
DECAIMENTO = 0.985


_HANN = [0.5 - 0.5 * math.cos(2 * math.pi * n / (JANELA - 1)) for n in range(JANELA)]
# uma linha de DFT por faixa (o que o Goertzel calcula), já com a janela de Hann: parte real e imaginária
_BASES = [([_HANN[n] * math.cos(2 * math.pi * f * n / TAXA) for n in range(JANELA)],
           [_HANN[n] * math.sin(2 * math.pi * f * n / TAXA) for n in range(JANELA)]) for f in FAIXAS]
_produto = getattr(math, "sumprod", lambda a, b: sum(map(mul, a, b)))   # math.sumprod: Python 3.12+


def niveis(amostras, tetos):
    """Raiz para as barras baixas mexerem; teto por faixa sobe na hora e decai devagar (AGC)."""
    janela = amostras[-JANELA:]
    saida = []
    for n in range(len(FAIXAS)):
        re, im = _produto(janela, _BASES[n][0]), _produto(janela, _BASES[n][1])
        e = float(re * re + im * im) / JANELA
        tetos[n] = max(e, tetos[n] * DECAIMENTO, PISO)
        saida.append(float(max(0.08, min(1.0, (e / tetos[n]) ** 0.5))))
    return saida


class Espectro(QObject):
    niveis = pyqtSignal(list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._ligado = self._tocando = False
        self._proc = None
        self._buf = array.array("h")
        self._tetos = [PISO] * len(FAIXAS)
        self._rel = QTimer(self, interval=RITMO_MS)
        self._rel.timeout.connect(self._medir)

    @property
    def ouvindo(self):
        return self._proc is not None

    def ligar(self, sim):
        self._ligado = bool(sim)
        self._conciliar()

    def tocando(self, sim):
        if bool(sim) != self._tocando:
            self._tocando = bool(sim)
            self._conciliar()

    def _conciliar(self):
        if self._ligado and self._tocando:
            self._subir()
        else:
            self._descer()

    def _subir(self):
        if self._proc:
            return
        self._tetos = [PISO] * len(FAIXAS)
        p = QProcess(self)
        p.readyReadStandardOutput.connect(self._dados)
        p.finished.connect(self._morreu)
        p.errorOccurred.connect(self._morreu)
        p.start("parec", ["--raw", "--format=s16le", f"--rate={TAXA}", "--channels=1", "--latency-msec=40", "-d", "@DEFAULT_MONITOR@"])
        self._proc = p
        self._rel.start()

    def _morreu(self, *_):
        if self._proc:
            self._descer()

    def _descer(self):
        self._rel.stop()
        p, self._proc = self._proc, None
        if p:
            p.readyReadStandardOutput.disconnect()
            p.finished.disconnect()
            p.errorOccurred.disconnect()
            p.kill()
            p.waitForFinished(300)
            p.deleteLater()
            self._buf = array.array("h")
            self.niveis.emit([])   # barras de volta ao repouso na hora

    def _dados(self):
        b = bytes(self._proc.readAllStandardOutput())
        self._buf.frombytes(b[: len(b) // 2 * 2])
        del self._buf[:-JANELA * 2]

    def _medir(self):
        if len(self._buf) >= JANELA:
            self.niveis.emit(niveis(self._buf, self._tetos))
