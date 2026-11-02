#!/usr/bin/env python3
"""Gera os widgets avulsos do Painel FUI: um pacote org.cyberkde.fui-<módulo> por módulo.

Cada pacote tem o metadata.json próprio (nome, descrição e o bloco X-CyberKDE, para o CLI registrar o
efeito widget-fui-<módulo>) e uma CÓPIA dos arquivos do org.cyberkde.painelfui (QML, script de coleta e
configuração). A fonte é uma só: edite sempre o painelfui e rode este script de novo; as cópias nunca se
editam (o arquivo GERADO de cada pacote avisa). O main.qml descobre o módulo pelo nome do plugin.
Por que cópia e não link: o KPackage recusa arquivo que aponte para fora do pacote ("Path traversal
attempt detected"), e isso é uma proteção que não se contorna.

Uso: python3 modules/widgets/plasmoides/fui-gerar.py              refaz todos os pacotes
     python3 modules/widgets/plasmoides/fui-gerar.py --conferir   só confere (saída 1 se algum divergir)
"""
import filecmp
import json
import math
import pathlib
import re
import shutil
import sys

AQUI = pathlib.Path(__file__).resolve().parent
FONTE = AQUI / "org.cyberkde.painelfui"

# id: (nome, nome_en, descrição, descrição_en, largura-base, ícone). A largura e as partes de dados estão
# também em contents/ui/Catalogo.js (o QML lê de lá); mantenha os dois iguais.
MODULOS = {
    "cpu": ("CPU", "CPU", "Carga total da CPU no arco, com a temperatura.", "Total CPU load on the arc, with the temperature.", 116, "cpu"),
    "nucleos": ("Núcleos", "Cores", "A CPU em 6 grupos de núcleos, com o % de cada um; o mais carregado fica destacado.",
                "The CPU in 6 groups of cores, with each one's %; the busiest is highlighted.", 349, "cpu"),
    "sensores": ("Sensores", "Sensors", "Oito medidores: temperatura da CPU e da GPU, uso da GPU, VRAM, RAM, swap, disco do sistema e rede.",
                 "Eight gauges: CPU and GPU temperature, GPU load, VRAM, RAM, swap, system disk and network.", 270, "temperature-normal"),
    "memoria": ("Memória", "Memory", "RAM e swap usadas, em barra hachurada, com os valores e o total.",
                "RAM and swap in use, in a hatched bar, with the values and the total.", 273, "memory"),
    "gpu": ("GPU", "GPU", "Temperatura da placa de vídeo no anel, com o uso e a VRAM.", "Graphics card temperature on the ring, with load and VRAM.", 116, "video-display"),
    "discos": ("Discos", "Drives", "Ocupação das unidades mais cheias; clique abre a pasta.", "Usage of the fullest drives; click opens the folder.", 239, "drive-harddisk"),
    "es": ("E/S de disco", "Disk I/O", "Leitura e escrita de cada disco agora.", "Read and write rate of each disk right now.", 240, "drive-harddisk"),
    "rede": ("Rede", "Network", "Até onde a conexão chega: LAN, gateway e internet, com as latências.",
             "How far the connection gets: LAN, gateway and internet, with latencies.", 358, "network-wired"),
    "trafego": ("Tráfego", "Traffic", "Tráfego de rede dos últimos 26 s, com descida e subida.", "Network traffic for the last 26 s, with download and upload.", 140, "network-wired"),
    "processos": ("Processos", "Processes", "Os 6 processos que mais usam CPU, com CPU% e MEM%.", "The 6 processes using the most CPU, with CPU% and MEM%.", 239, "view-process-system"),
    "log": ("Log", "Log", "Os últimos eventos do journal do seu usuário.", "The latest events from your user journal.", 240, "view-history"),
    "sistema": ("Sistema", "System", "Ligado há, carga média, atualizações, Docker, falhas e baterias de periféricos.",
                "Uptime, load average, updates, Docker, failed units and peripheral batteries.", 200, "computer"),
    "hora": ("Hora", "Time", "A hora grande da referência, com o dia e o tempo ligado.", "The big reference clock, with the day and uptime.", 349, "clock"),
    "clima": ("Clima", "Weather", "O tempo agora na cidade escolhida.", "The weather now in the chosen city.", 181, "weather-few-clouds"),
    "estados": ("Estados", "Status", "Rede, som, microfone, energia, GPU e latência em ladrilhos.", "Network, sound, microphone, power, GPU and latency as tiles.", 132, "dialog-information"),
}
# Tamanho de inserção (X-CyberKDE "tamanho") = o preset que o widget aplica ao aparecer: o do "modo" padrão
# do main.xml, nos mesmos fatores do main.qml (tamModulo), arredondado PARA CIMA à grade da área de
# trabalho (16 px), como o Cores.redimensionar faz. Assim o widget não cresce depois de inserido.
FATORES = {"pequeno": 1, "medio": 1.35, "grande": 1.75}
PAINEL = {"pequeno": (240, 96), "medio": (776, 656), "grande": (960, 816)}   # o painel inteiro (main.qml)
GRADE = 16


def modo_padrao():
    xml = (FONTE / "contents" / "config" / "main.xml").read_text()
    return re.search(r'<entry name="modo"[^>]*><default>(\w+)</default>', xml).group(1)


def larguras():
    """As larguras-base do Catalogo.js (a mesma fonte que o QML lê)."""
    js = (FONTE / "contents" / "ui" / "Catalogo.js").read_text()
    return {m: int(l) for m, l in re.findall(r'"(\w+)":\s*\{[^}]*largura:\s*(\d+)', js)}


def na_grade(v):
    return int(math.ceil(v / GRADE) * GRADE)


def tamanho_inicial(mid):
    modo = modo_padrao()
    if mid is None:
        return [na_grade(v) for v in PAINEL[modo]]
    f = FATORES[modo]
    return [na_grade(round(larguras()[mid] * f) + 8), na_grade(round(172 * f) + 8)]


COMPARTILHADOS = ["contents/code/coleta.sh", "contents/config/main.xml", "contents/config/config.qml"]


def arquivos():
    ui = sorted(p.name for p in (FONTE / "contents" / "ui").iterdir() if p.suffix in (".qml", ".js") and p.is_file())
    return COMPARTILHADOS + [f"contents/ui/{f}" for f in ui]


def conferir():
    ruins = []
    larg = larguras()
    for mid, dados in MODULOS.items():
        if larg.get(mid) != dados[4]:
            ruins.append(f"largura de {mid}: Catalogo.js {larg.get(mid)} x fui-gerar.py {dados[4]}")
    alvos = {None: FONTE / "metadata.json"}
    alvos.update({mid: AQUI / f"org.cyberkde.fui-{mid}" / "metadata.json" for mid in MODULOS})
    for mid, meta in alvos.items():
        declarado = json.loads(meta.read_text()).get("X-CyberKDE", {}).get("tamanho")
        if declarado != tamanho_inicial(mid):
            ruins.append(f"{meta.parent.name}: tamanho {declarado} x preset inicial {tamanho_inicial(mid)}")
    for mid in MODULOS:
        pkg = AQUI / f"org.cyberkde.fui-{mid}"
        for rel in arquivos():
            if not (pkg / rel).is_file() or not filecmp.cmp(FONTE / rel, pkg / rel, shallow=False):
                ruins.append(f"{pkg.name}/{rel}")
    print("\n".join(ruins) if ruins else "fui: todas as cópias iguais ao painelfui")
    return 1 if ruins else 0


def main():
    if "--conferir" in sys.argv:
        sys.exit(conferir())
    # o painel inteiro: só o "tamanho" do metadata.json é acertado aqui (o resto é escrito à mão)
    meta = json.loads((FONTE / "metadata.json").read_text())
    meta["X-CyberKDE"]["tamanho"] = tamanho_inicial(None)
    (FONTE / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=4) + "\n")
    for velho in AQUI.glob("org.cyberkde.fui-*"):
        if velho.name[len("org.cyberkde.fui-"):] not in MODULOS:
            shutil.rmtree(velho)
    for ordem, (mid, (nome, nome_en, desc, desc_en, larg, icone)) in enumerate(MODULOS.items()):
        pkg = AQUI / f"org.cyberkde.fui-{mid}"
        if pkg.exists():
            shutil.rmtree(pkg)
        for rel in arquivos():
            destino = pkg / rel
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(FONTE / rel, destino)
        (pkg / "GERADO").write_text("Pacote gerado por modules/widgets/plasmoides/fui-gerar.py a partir do org.cyberkde.painelfui.\n"
                                    "Não edite aqui: edite o painelfui e rode o script de novo.\n")
        meta = {
            "KPlugin": {
                "Id": f"org.cyberkde.fui-{mid}",
                "Name": f"CyberKDE · FUI {nome}", "Name[pt_BR]": f"CyberKDE · FUI {nome}", "Name[en]": f"CyberKDE · FUI {nome_en}",
                "Description": desc, "Description[pt_BR]": desc, "Description[en]": desc_en,
                "Icon": icone, "Category": "System Information",
                "Authors": [{"Name": "CyberKDE"}], "License": "GPL-3.0-or-later", "Version": "1.0",
                "Website": "https://github.com/jrcn1991/theme-cyberkde",
                "FormFactors": ["desktop", "panel"],
            },
            "KPackageStructure": "Plasma/Applet",
            "X-Plasma-API-Minimum-Version": "6.0",
            "X-CyberKDE": {
                "nome": f"FUI · {nome}", "nome_en": f"FUI · {nome_en}",
                "descricao": desc + " Um módulo do Painel FUI, sozinho.",
                "descricao_en": desc_en + " One module of the FUI dashboard, on its own.",
                "tamanho": tamanho_inicial(mid),
                "ordem": 200 + ordem,
            },
        }
        if mid == "clima":
            meta["X-CyberKDE"]["opcoes"] = [{"id": "cidade", "chave": "cidade", "tipo": "texto", "padrao": "",
                                             "nome": "Cidade", "nome_en": "City",
                                             "dica": "Vazia: São Paulo, ou a última resolvida", "dica_en": "Empty: São Paulo, or the last one resolved"}]
        if mid in ("cpu", "nucleos", "sensores", "memoria", "discos", "processos"):
            meta["X-CyberKDE"]["opcoes"] = [{"id": "limiar", "chave": "limiar", "tipo": "inteiro", "min": 50, "max": 99, "padrao": 85,
                                             "unidade": "%", "nome": "Alerta acima de", "nome_en": "Alert above"}]
        (pkg / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=4) + "\n")
        print(pkg.name)


if __name__ == "__main__":
    main()
