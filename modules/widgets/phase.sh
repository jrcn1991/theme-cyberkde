# modules/widgets/phase.sh — widgets do tema na área de trabalho (clima, notas, relógio...). Os
# plasmoides são dos outros agentes (modules/widgets/plasmoides/org.cyberkde.<nome>); este arquivo
# instala, liga e desliga. Cada pacote da pasta vira o efeito widget-<nome>, sem lista fixa: nome,
# descrição, tamanho de inserção e opções extras saem do bloco "X-CyberKDE" do metadata.json (formato
# no modules/widgets/CONTRATO-CLI.md). Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# Instalação (install_widgets, a cada install/on/cor): cada pacote vai para
# ~/.local/share/plasma/plasmoids/<id>, com os componentes comuns (modules/widgets/comum) copiados para
# contents/ui/comum e um Paleta.qml gerado ali: um singleton com a paleta JÁ APLICADA (destaque,
# secundária, alerta, superfícies e texto, do cyberlib). Os widgets usam com 'import "comum"' e
# Paleta.destaque etc. O "cor"/"corp" regenera o arquivo no install_files, e o reinício do plasmashell que
# eles já fazem no fim carrega a cor nova: nenhum reinício a mais. Instalados, aparecem em "Adicionar
# widgets" mesmo sem estar na área de trabalho. Ficam fora do registro (são arquivos do tema, como o
# Kvantum); o uninstall os remove.
#
# Na área de trabalho (efeitos widget-<nome>, fase "widgets"): o tema acrescenta o applet pelo script
# do plasmashell (evaluateScript) e anota em $state/widgets.tsv a tela, o contêiner e o id DO APPLET QUE
# ELE CRIOU. Desligar remove só esses ids: um widget que a pessoa pôs à mão nunca é tocado.
#   - Antes de remover, toda a configuração do applet (as notas, a cidade, o que a pessoa ajustou) é
#     copiada para ~/.config/cyberkde/widgets-dados/<efeito>-tela<N>.json, e volta quando o widget é
#     religado: desligar não perde as notas. O uninstall preserva essa pasta.
#   - A pessoa removeu à mão um widget que o tema criou: vale como "desligar" (a escolha passa a off),
#     e o tema não o põe de volta sozinho num próximo "on".
#   - "off" (geral ou da fase): remove todos os criados pelo tema, mantendo as escolhas; o "on" os
#     devolve, com os dados.
# A fase roda depois da barra e da dock (ordem no scripts/cyberkde): a barra guarda o appletsrc
# original na primeira aplicação, e ele não deve conter widgets do tema.

CYBERKDE_PHASES+=(widgets)
CYBERKDE_PRE_OFF_HOOKS+=(pre_off_widgets)  # com o plasmashell ainda no ar (a barra o para depois)
CYBERKDE_INSTALLS+=(install_widgets)
descreve_fase widgets "Widgets" sistema nao "Widgets do tema na área de trabalho: clima, notas, relógio e outros." \
  "Widgets" "Theme widgets on the desktop: weather, notes, clock and more."

widgets_src="$project/modules/widgets"
widgets_reg="$state/widgets.tsv"                 # efeito  tela  contêiner  applet
widgets_dados="$config/cyberkde/widgets-dados"   # cópia da configuração de cada applet removido
widgets_cantos=(superior-direito inferior-direito superior-esquerdo inferior-esquerdo)

# Catálogo dos plasmoides da pasta, uma linha por widget, separada por TAB:
#   efeito  plugin  largura  altura  nome  nome_en  descrição  descrição_en  opções-json  opções-spec
#   categoria  modo-padrão  opacidade-padrão  opacidade-min  opacidade-max  layout-fui  instâncias(1)
#   presets ("pequeno=240x96 medio=… grande=…", os literais do main.qml: o tamanho que o widget terá)
# Os padrões de modo e opacidade vêm do contents/config/main.xml de cada widget (o painelfui é
# grande e 55, de 0 a 100); layout-fui: "coluna:faixa:faixas:módulo-que-esconde" (ou vazio).
# opções-spec: "id:chave:tipo:min:max:val1,val2 ..." (para validar sem Python). Lido dos metadata.json
# numa chamada só e guardado em cache pela data dos arquivos: o status --json lê isto a toda hora.
widgets_catalogo() {
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/cyberkde/widgets-catalogo" chave
  chave=$(stat -c '%n %Y %s' -- "$widgets_src"/plasmoides/org.cyberkde.*/metadata.json "${BASH_SOURCE[0]}" 2>/dev/null | md5sum)
  if [[ -s $cache && $(head -1 "$cache") == "$chave" ]]; then tail -n +2 "$cache"; return 0; fi
  local v
  v=$(python3 - "$widgets_src/plasmoides" <<'PY'
import glob, json, os, re, sys
# Os quatro primeiros, de antes do bloco X-CyberKDE: valem enquanto o metadata.json deles não o tiver.
LEGADO = {
  "clima": {"ordem": 10, "tamanho": [360, 420], "nome": "Clima", "nome_en": "Weather",
            "descricao": "Tempo agora e previsão curta, na cidade escolhida.", "descricao_en": "Current weather and a short forecast for the chosen city.",
            "opcoes": [{"id": "cidade", "nome": "Cidade", "nome_en": "City", "tipo": "texto", "padrao": ""}]},
  "desempenho": {"ordem": 20, "tamanho": [340, 420], "nome": "Desempenho", "nome_en": "Performance",
            "descricao": "Processador, memória, disco e rede em barras segmentadas.", "descricao_en": "CPU, memory, disk and network in segmented bars."},
  "midia": {"ordem": 30, "tamanho": [400, 190], "nome": "Mídia", "nome_en": "Media",
            "descricao": "O que está tocando (Spotify e outros players MPRIS), com os controles.", "descricao_en": "What is playing (Spotify and other MPRIS players), with controls."},
  "notas": {"ordem": 40, "tamanho": [400, 340], "nome": "Notas", "nome_en": "Notes",
            "descricao": "Post-its na área de trabalho. As notas ficam guardadas mesmo ao desligar.", "descricao_en": "Sticky notes on the desktop. The notes are kept even when switched off."},
}
# Categoria no painel: a do bloco X-CyberKDE; sem ela, esta tabela; fora dela, "outros".
CATEGORIAS = {"sistema", "informacao", "produtividade"}
CATEGORIA = {"desempenho": "sistema", "discos": "sistema", "rede": "sistema", "docker": "sistema",
             "clima": "informacao", "cambio": "informacao", "rss": "informacao", "relogio": "informacao",
             "notas": "produtividade", "tarefas": "produtividade", "midia": "produtividade"}
# Lugar no layout FUI (modules/widgets/LAYOUT-FUI.md): X-CyberKDE.layoutFui {coluna, faixa, faixas,
# oculta} ou esta tabela. "oculta": o módulo do Painel FUI que some quando o widget está ao lado.
LAYOUT = {"relogio": ("esquerda", 0, 1, "relogio"), "clima": ("esquerda", 1, 2, "clima"),
          "cambio": ("esquerda", 3, 1, ""), "desempenho": ("direita", 0, 2, ""),
          "discos": ("direita", 2, 1, "discos"), "notas": ("direita", 3, 1, "")}
import xml.etree.ElementTree as ET
def padroes_xml(pasta):
    """modo e opacidade (padrão, mín., máx.) do main.xml do widget; o que faltar, os do CLI."""
    r = {"modo": "pequeno", "opacidade": 95, "min": 30, "max": 100}
    try:
        raiz = ET.parse(os.path.join(pasta, "contents", "config", "main.xml")).getroot()
    except (OSError, ET.ParseError):
        return r
    for ent in raiz.iter():
        if not ent.tag.endswith("entry"):
            continue
        filhos = {c.tag.split("}")[-1]: (c.text or "").strip() for c in ent}
        if ent.get("name") == "modo" and filhos.get("default") in ("pequeno", "medio", "grande", "compacto", "completo"):
            r["modo"] = {"compacto": "pequeno", "completo": "grande"}.get(filhos["default"], filhos["default"])
        elif ent.get("name") == "opacidade":
            for k, ch in (("opacidade", "default"), ("min", "min"), ("max", "max")):
                try:
                    r[k] = int(filhos[ch])
                except (KeyError, ValueError):
                    pass
    return r
# Widgets com várias instâncias: X-CyberKDE.instancias=true ou esta tabela.
VARIAS = {"cerca"}
# Opções que o widget tem no main.xml e o metadata.json ainda não declara (o do pacote vem primeiro).
OPCOES_RESERVA = {"cerca": [{"id": "soltar", "chave": "soltar", "tipo": "escolha", "padrao": "mover",
    "nome": "Ao soltar arquivos", "nome_en": "When dropping files",
    "valores": [{"id": "mover", "nome": "Mover", "nome_en": "Move"}, {"id": "perguntar", "nome": "Perguntar", "nome_en": "Ask"}]}]}
RAIZ = os.path.abspath(os.path.join(sys.argv[1], "..", "..", ".."))
def presets_qml(pasta):
    try:
        t = open(os.path.join(pasta, "contents", "ui", "main.qml"), encoding="utf-8").read()
    except OSError:
        return ""
    r = re.findall(r"tamanho(Pequeno|Medio|Grande):\s*Qt\.size\((\d+),\s*(\d+)\)", t)
    return " ".join("%s=%sx%s" % (n.lower(), w, h) for n, w, h in r)
RESERVADAS = {"tela", "posicao", "modo", "opacidade", "json", "lang", "on", "off"}
NOME = re.compile(r"^[a-z0-9][a-z0-9-]*$")
def limpo(v):
    return re.sub(r"\s+", " ", str(v or "")).strip()
def sem_prefixo(n):
    return re.sub(r"^CyberKDE\s*[·:-]\s*", "", limpo(n))
def opcao(o):
    if not isinstance(o, dict):
        return None
    oid, tipo = str(o.get("id", "")), o.get("tipo", "texto")
    chave = str(o.get("chave", oid))
    if not re.match(r"^[A-Za-z0-9][A-Za-z0-9-]*$", oid) or oid in RESERVADAS or not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", chave):
        return None
    r = {"id": oid, "nome": limpo(o.get("nome", oid)), "nome_en": limpo(o.get("nome_en", o.get("nome", oid))), "tipo": tipo}
    for k in ("dica", "dica_en"):
        if o.get(k):
            r[k] = limpo(o[k])
    spec = [oid, chave, tipo, "", "", ""]
    if tipo == "texto":
        r["padrao"] = str(o.get("padrao", ""))
    elif tipo == "escolha":
        vals = [v for v in o.get("valores", []) if isinstance(v, dict) and re.match(r"^[A-Za-z0-9_.-]+$", str(v.get("id", "")))]
        if not vals:
            return None
        r["valores"] = [{"id": str(v["id"]), "nome": limpo(v.get("nome", v["id"])), "nome_en": limpo(v.get("nome_en", v.get("nome", v["id"])))} for v in vals]
        for v, q in zip(vals, r["valores"]):  # prévia: relativa à raiz do projeto, só se o arquivo existir
            f = os.path.join(RAIZ, str(v.get("previa") or ""))
            if v.get("previa") and ".." not in str(v["previa"]) and os.path.isfile(f):
                q["previa"] = f
        r["padrao"] = str(o.get("padrao", vals[0]["id"]))
        spec[5] = ",".join(v["id"] for v in r["valores"])
        spec.append(r["padrao"] if re.match(r"^[A-Za-z0-9_.-]+$", r["padrao"]) else "")
    elif tipo == "inteiro":
        try:
            mn, mx = int(o["min"]), int(o["max"])
        except (KeyError, TypeError, ValueError):
            return None
        r.update({"min": mn, "max": mx, "padrao": int(o.get("padrao", mn))})
        if o.get("unidade"):
            r["unidade"] = limpo(o["unidade"])
        spec[3], spec[4] = str(mn), str(mx)
    else:
        return None
    if o.get("global"):  # vale para todas as instâncias (widget_cmd)
        r["global"] = True
        spec += [""] * (7 - len(spec)) + ["1"]
    return r, ":".join(spec)
lista = []
for meta in glob.glob(os.path.join(sys.argv[1], "org.cyberkde.*", "metadata.json")):
    try:
        m = json.load(open(meta, encoding="utf-8"))
    except (OSError, ValueError):
        continue
    kp = m.get("KPlugin", {})
    plugin = kp.get("Id") or os.path.basename(os.path.dirname(meta))
    nome = plugin[len("org.cyberkde."):] if plugin.startswith("org.cyberkde.") else ""
    if not NOME.match(nome):
        continue
    x = dict(LEGADO.get(nome, {}))
    x.update(m.get("X-CyberKDE") or {})
    try:
        w, h = (int(v) for v in x.get("tamanho", [360, 300]))
    except (TypeError, ValueError):
        w, h = 360, 300
    n = limpo(x.get("nome")) or sem_prefixo(kp.get("Name[pt_BR]") or kp.get("Name")) or nome
    n_en = limpo(x.get("nome_en")) or sem_prefixo(kp.get("Name[en]") or kp.get("Name")) or n
    d = limpo(x.get("descricao")) or limpo(kp.get("Description[pt_BR]") or kp.get("Description"))
    d_en = limpo(x.get("descricao_en")) or limpo(kp.get("Description[en]") or kp.get("Description")) or d
    ops, specs, vistos = [], [], set()
    for o in list(x.get("opcoes") or []) + OPCOES_RESERVA.get(nome, []):
        r = opcao(o)
        if r and r[0]["id"] not in vistos:
            vistos.add(r[0]["id"]); ops.append(r[0]); specs.append(r[1])
    cat = x.get("categoria") if x.get("categoria") in CATEGORIAS else CATEGORIA.get(nome, "outros")
    pd = padroes_xml(os.path.dirname(meta))
    lf = x.get("layoutFui")
    if isinstance(lf, dict) and lf.get("coluna") in ("esquerda", "direita"):
        try:
            lf = (lf["coluna"], max(0, min(3, int(lf.get("faixa", 0)))), max(1, min(4, int(lf.get("faixas", 1)))), str(lf.get("oculta", "")))
        except (TypeError, ValueError):
            lf = None
    else:
        lf = LAYOUT.get(nome)
    lf = ":".join(str(v) for v in lf) if lf and lf[1] + lf[2] <= 4 and re.match(r"^[a-z0-9]*$", lf[3]) else ""
    ordem = x.get("ordem", 100)
    lista.append((ordem if isinstance(ordem, int) else 100, n.lower(), "\t".join(
        [nome, plugin, str(max(w, 80)), str(max(h, 60)), n, n_en, d, d_en,
         json.dumps(ops, ensure_ascii=False, separators=(",", ":")), " ".join(specs), cat,
         pd["modo"], str(pd["opacidade"]), str(pd["min"]), str(pd["max"]), lf,
         "1" if x.get("instancias") is True or nome in VARIAS else "", presets_qml(os.path.dirname(meta))])))
for _, _, l in sorted(lista):
    print(l)
PY
) || return 0
  { mkdir -p -- "$(dirname -- "$cache")" && printf '%s\n%s\n' "$chave" "$v" >"$cache"; } 2>/dev/null || true
  [[ -z $v ]] || printf '%s\n' "$v"
}
mapfile -t widgets_tabela < <(widgets_catalogo)

widget_linha() { local l; for l in "${widgets_tabela[@]}"; do [[ ${l%%$'\t'*} == "$1" ]] && { printf '%s\n' "$l"; return 0; }; done; return 1; }
# Campos do catálogo em memória (widgets_f[efeito:nº]): o --lista e o status leem dezenas por widget, e
# um "cut" por leitura custava centenas de processos.
declare -gA widgets_f=()
widgets_campos_carregar() {
  local l e resto n
  widgets_f=()
  for l in "${widgets_tabela[@]}"; do
    e=${l%%$'\t'*}; resto=$l; n=1
    while :; do
      widgets_f[$e:$n]=${resto%%$'\t'*}
      [[ $resto == *$'\t'* ]] || break
      resto=${resto#*$'\t'}; n=$((n + 1))
    done
  done
}
widgets_campos_carregar
widget_campo() { local b=${1%%@*}; [[ -v widgets_f[$b:1] ]] || return 1; printf '%s\n' "${widgets_f[$b:$2]-}"; }  # efeito nº-do-campo

# Várias instâncias (a cerca; basta declarar no catálogo). Cada instância do tema é uma CHAVE: "cerca" é a
# de id 1 e "cerca@2", "cerca@3"... as outras. A chave vale no widgets.tsv, no grupo [widget-<chave>] das
# escolhas e no widgets-dados/<chave>-tela<N>.json, então criar, remover, copiar e devolver são os de
# sempre. Applet posto à mão ("Adicionar widgets"): id "a<applet>", fora do registro; só muda com
# --instancia, e é adotado (vira chave) quando o pedido precisa do ciclo de vida (off, --tela, --posicao).
widget_instanciavel() { [[ ${widgets_f[${1%%@*}:17]-} == 1 ]]; }
widget_chave_id() { if [[ $1 == *@* ]]; then printf '%s\n' "${1#*@}"; else echo 1; fi; }
widget_instancias_chaves() {  # base -> chaves, da primeira para a última
  local b=$1
  { grep -oE "^\[widget-$b(@[0-9]+)?\]\$" "$efeitos_file" 2>/dev/null | tr -d '[]' | sed 's/^widget-//' || true
    awk -F'\t' -v b="$b" '$1 == b || index($1, b "@") == 1 {print $1}' "$widgets_reg" 2>/dev/null || true
  } | awk '!v[$0]++' | sort -t@ -k2n | while IFS= read -r k; do
    # Sem applet, sem cópia e sem "ligado": um grupo que só tem opções não é uma instância.
    if grep -qs "^$k"$'\t' "$widgets_reg" || compgen -G "$widgets_dados/$k-tela*.json" >/dev/null ||
      [[ $(awk -v g="[widget-$k]" 'substr($0, 1, 1) == "[" {f = ($0 == g)} f && /^ligado=true$/ {print 1; exit}' "$efeitos_file" 2>/dev/null) == 1 ]]; then
      printf '%s\n' "$k"
    fi
  done
}
widget_instancia_primeira() { local k; k=$(widget_instancias_chaves "$1" | head -1); printf '%s\n' "${k:-$1}"; }
widget_instancia_nova() {  # base -> chave nova (sem nenhuma: a própria base)
  local u
  u=$(widget_instancias_chaves "$1" | tail -1)
  if [[ -z $u ]]; then printf '%s\n' "$1"; else printf '%s@%d\n' "$1" "$(( $(widget_chave_id "$u") + 1 ))"; fi
}
widget_prefs_apagar() {  # chave
  [[ -f $efeitos_file ]] || return 0
  awk -v g="[widget-$1]" 'substr($0, 1, 1) == "[" {f = ($0 == g)} !f' "$efeitos_file" >"$efeitos_file.novo"
  mv -f -- "$efeitos_file.novo" "$efeitos_file"
}
# Efeitos a percorrer: os do catálogo e os que ainda têm applet no registro (pacote que saiu da pasta).
widgets_todos() {
  local l
  for l in "${widgets_tabela[@]}"; do printf '%s\n' "${l%%$'\t'*}"; done
  awk -F'\t' '{print $1}' "$widgets_reg" 2>/dev/null || true  # sem registro (depois de um off), as instâncias ainda vêm das escolhas
  grep -oE '^\[widget-[a-z0-9-]+@[0-9]+\]$' "$efeitos_file" 2>/dev/null | tr -d '[]' | sed 's/^widget-//' || true
}
widgets_lista() { widgets_todos | awk 'NF && !v[$0]++'; }
widget_pref() {  # efeito chave [padrão]
  if (( efeitos_lote_ativo )); then efeitos_lote_ler "widget-$1" "$2" "${3:-}"; return 0; fi
  if (( widget_prefs_lote_ativo )); then
    local k="widget-$1"$'\x1f'"$2"
    if [[ -v widget_prefs_lote[$k] ]]; then printf '%s\n' "${widget_prefs_lote[$k]}"; else printf '%s\n' "${3:-}"; fi
    return 0
  fi
  kreadconfig6 --file "$efeitos_file" --group "widget-$1" --key "$2" --default "${3:-}" 2>/dev/null
}
# Para o status: as escolhas de todos os widgets numa leitura só (o kreadconfig6 custa ~6 ms por chave).
widget_prefs_lote_ativo=0
declare -gA widget_prefs_lote=()
widgets_prefs_carregar() {
  local g k v
  widget_prefs_lote=()
  while IFS=$'\x1f' read -r -d '' g k v; do widget_prefs_lote["$g"$'\x1f'"$k"]=$v; done < <(python3 -c '
import re, sys
g = None
try:
    linhas = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError:
    linhas = []
def des(v):  # escapes do KConfig
    return re.sub(r"\\(.)", lambda m: {"s": " ", "t": "\t", "n": "\n", "r": "\r", "\\": "\\"}.get(m.group(1), m.group(0)), v)
for l in linhas:
    if l.startswith("["):
        g = l[1:l.index("]")] if "]" in l else None
    elif g and g.startswith("widget-") and "=" in l:
        k, v = l.split("=", 1)
        k = re.sub(r"\[\$[a-z]+\]$", "", k.strip())
        sys.stdout.write(g + "\x1f" + k + "\x1f" + des(v.strip()) + "\0")
' "$efeitos_file" 2>/dev/null)
  widget_prefs_lote_ativo=1
}
widgets_estados() {  # para o CYBERKDE_EFEITOS_LOTE: "widget-<nome><TAB>estado" por linha
  local l
  widgets_prefs_carregar
  widgets_cfg_carregar
  for l in "${widgets_tabela[@]}"; do printf 'widget-%s\t%s\n' "${l%%$'\t'*}" "$(widget_estado "${l%%$'\t'*}")"; done
  widget_prefs_lote_ativo=0
}
CYBERKDE_EFEITOS_LOTE+=(widgets_estados)
widgets_jsons() {  # para o CYBERKDE_EFEITOS_JSON_LOTE: "widget-<nome><TAB>item" por linha
  local l
  widgets_prefs_carregar
  widgets_cfg_carregar
  for l in "${widgets_tabela[@]}"; do printf 'widget-%s\t%s\n' "${l%%$'\t'*}" "$(widget_json "${l%%$'\t'*}")"; done
  widget_prefs_lote_ativo=0
}
CYBERKDE_EFEITOS_JSON_LOTE+=('widgets_jsons:widget-*')  # o widget-layout não vem dele: sai pelo efeito_json, depois
widget_js() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" 2>/dev/null; }
widget_instalado() { [[ -f $data/plasma/plasmoids/org.cyberkde.${1%%@*}/metadata.json ]]; }
widget_no_projeto() { [[ -f $widgets_src/plasmoides/org.cyberkde.${1%%@*}/metadata.json ]]; }
widget_applets() {  # efeito -> ids (em memória nas leituras em lote: um awk por pergunta somava centenas)
  if (( widgets_cfg_ok )); then
    [[ -z ${widgets_reg_mem[$1]-} ]] || printf '%s\n' ${widgets_reg_mem[$1]}
    return 0
  fi
  awk -F'\t' -v e="$1" '$1 == e {print $4}' "$widgets_reg" 2>/dev/null
}

# ------------------------------------------------------------------ instalação e paleta
widgets_paleta_qml() {  # -> conteúdo do Paleta.qml (paleta aplicada agora)
  local cid logo="" emblema=""
  cid=$(corp_atual 2>/dev/null || echo nenhuma)
  if declare -F corp_logo_largo >/dev/null; then logo=$(corp_logo_largo "$cid" 2>/dev/null || true); fi
  if declare -F corp_logo >/dev/null; then emblema=$(corp_logo "$cid" 2>/dev/null || true); fi
  python3 - "$project/generator" "$cid" "$logo" "$emblema" <<'PY'
import json, sys, urllib.parse
sys.path.insert(0, sys.argv[1])
from cyberlib import RED, CYAN, ALERTA, BASE, PANEL, RAISED, TXT1, TXT2, TXTD, LINE, ONRED, TOK
cores = {"destaque": RED, "secundaria": CYAN, "alerta": ALERTA, "fundo": TOK["reference"]["darkestBlue"],
         "superficie": BASE, "painel": PANEL, "elevado": RAISED, "texto": TXT1, "textoSecundario": TXT2,
         "textoDesativado": TXTD, "linha": LINE, "textoSobreDestaque": ONRED}
print("// GERADO pelo modules/widgets/phase.sh (install_widgets): a paleta do tema aplicada agora.")
print("// Não editar: o 'cyberkde cor' e o 'cyberkde corp' regravam este arquivo.")
print("pragma Singleton\nimport QtQuick\n\nQtObject {")
for k, v in cores.items():
    print(f'    readonly property color {k}: "{v}"')
print(f'    readonly property string corp: "{sys.argv[2]}"')
# Logo largo e emblema da corporação em uso (URL file://, ou "" sem corporação), para quem quiser.
url = lambda c: "file://" + urllib.parse.quote(c) if c else ""
print(f'    readonly property url logo: {json.dumps(url(sys.argv[3]))}')
print(f'    readonly property url emblema: {json.dumps(url(sys.argv[4]))}')
print("}")
PY
}

install_widgets() {
  local pkg id tmp comum paleta
  mkdir -p -- "$config/cyberkde/cercas" "$config/cyberkde/widgets"  # vigiadas pelos widgets (precisam existir antes)
  [[ -d $widgets_src/plasmoides ]] || return 0
  paleta=$(widgets_paleta_qml) || return 1
  for pkg in "$widgets_src"/plasmoides/org.cyberkde.*/; do
    [[ $(basename -- "$pkg") =~ ^org\.cyberkde\.[a-z0-9][a-z0-9-]*$ ]] || continue
    [[ -f $pkg/metadata.json ]] || continue
    id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Id"])' "$pkg/metadata.json" 2>/dev/null) || id=$(basename -- "$pkg")
    tmp=$(mktemp -d)
    cp -a -- "$pkg/." "$tmp/"
    comum="$tmp/contents/ui/comum"
    mkdir -p -- "$comum"
    if [[ -d $widgets_src/comum ]]; then cp -a -- "$widgets_src/comum/." "$comum/"; fi
    printf '%s\n' "$paleta" >"$comum/Paleta.qml"
    grep -qs '^singleton Paleta ' "$comum/qmldir" || printf 'singleton Paleta 1.0 Paleta.qml\n' >>"$comum/qmldir"
    chmod 755 "$tmp"
    swap_dir "$tmp" "$data/plasma/plasmoids/$id"
    rm -rf -- "$tmp"
  done
}

# ------------------------------------------------------------------ área de trabalho
# Remove os applets do tema desse efeito (todos, ou só os ids dados), guardando antes a configuração de
# cada um em widgets-dados. Tira do registro o que foi removido (ou que já não existia).
widgets_remover() {  # efeito
  local efeito=$1 ids js saida
  ids=$(widget_applets "$efeito" | paste -sd, -)
  [[ -n $ids ]] || return 0
  js=$(cat <<'JS'
var alvo = [@@IDS@@], esp = @@ESP@@, copia = {}, ds = desktops();
function ler(w) {
  var r = {};
  function andar(p) {
    w.currentConfigGroup = p;
    var ks = w.configKeys || [];
    for (var i = 0; i < ks.length; i++) r[p.join("/") + "|" + ks[i]] = w.readConfig(ks[i]);
    var gs = w.configGroups || [];
    for (var j = 0; j < gs.length; j++) andar(p.concat([gs[j]]));
  }
  andar([]);
  return r;
}
for (var i = 0; i < ds.length; i++) {
  var ws = ds[i].widgets();
  for (var j = 0; j < ws.length; j++) {
    if (alvo.indexOf(ws[j].id) < 0) continue;
    var c = ler(ws[j]), r = ws[j].geometry;
    // O tamanho é livre (modo de edição) e é da pessoa: vai junto, com a posição. Espremido pelo Plasma, não.
    var ex = esp[ws[j].id];
    if (r && r.width > 0 && r.height > 0 && !(ex && (r.width < ex[0] - 16 || r.height < ex[1] - 16))) c.__geo = {x: r.x, y: r.y, width: r.width, height: r.height};
    copia[String(ds[i].screen)] = c;
    ws[j].remove();
  }
}
print(JSON.stringify(copia));
JS
)
  js=${js//@@ESP@@/$(widgets_espremidos_json)}
  saida=$(widget_js "${js//@@IDS@@/$ids}") || return 1  # ids: só números e vírgulas
  mkdir -p -- "$widgets_dados"
  WD=$widgets_dados E=$efeito python3 -c 'import json, os, sys
d = json.loads(sys.stdin.read() or "{}")
for tela, cfg in d.items():
    if cfg:
        open(os.path.join(os.environ["WD"], "%s-tela%s.json" % (os.environ["E"], tela)), "w").write(json.dumps(cfg, ensure_ascii=False))' <<<"$saida" 2>/dev/null || true
  awk -F'\t' -v e="$efeito" '$1 != e' "$widgets_reg" >"$widgets_reg.novo" 2>/dev/null || true
  mv -f -- "$widgets_reg.novo" "$widgets_reg"
  [[ -s $widgets_reg ]] || rm -f -- "$widgets_reg"
}

# Modo do widget; os nomes antigos (compacto, completo) valem como pequeno e grande. Inválido: vazio.
widget_modo() {
  case $1 in
    pequeno | compacto) echo pequeno ;;
    medio | médio) echo medio ;;
    grande | completo) echo grande ;;
  esac
}

# Chaves do grupo General que o CLI grava no applet, das escolhas feitas (só as definidas; sem
# escolha, vale o padrão do widget): objeto JSON {"<chave>":"…","modo":"…","opacidade":N}.
widget_config_escolhida() {  # efeito -> JSON
  local e=$1 v r="" sp oid chave tipo
  for sp in $(widget_campo "$e" 10); do
    IFS=: read -r oid chave tipo _ <<<"$sp"
    v=$(widget_pref "$e" "$oid")
    [[ -n $v ]] || continue
    if [[ $tipo == inteiro ]]; then [[ $v =~ ^-?[0-9]+$ ]] && r+=",\"$chave\":$v"; else r+=",\"$chave\":$(json_str "$v")"; fi
  done
  v=$(widget_modo "$(widget_pref "$e" modo)"); [[ -z $v ]] || r+=",\"modo\":$(json_str "$v")"
  v=$(widget_pref "$e" opacidade); [[ ! $v =~ ^[0-9]+$ ]] || r+=",\"opacidade\":$v"
  printf '{%s}' "${r#,}"
}

# Grava chaves do General ao vivo nos applets do tema que já estão na área de trabalho.
widget_config_ao_vivo() {  # efeito objeto-json
  widget_config_ao_vivo_ids "$(widget_applets "$1" | paste -sd, -)" "$2"
}
widget_config_ao_vivo_ids() {  # ids-separados-por-vírgula objeto-json
  local ids=$1
  [[ -n $ids && $2 != '{}' ]] || return 0
  widget_js "var alvo = [$ids], novo = $2, ds = desktops();
for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (alvo.indexOf(ws[j].id) >= 0) { ws[j].currentConfigGroup = ['General']; for (var k in novo) ws[j].writeConfig(k, novo[k]); if (ws[j].reloadConfig) ws[j].reloadConfig(); } }" >/dev/null || true
}

# Escolha feita com o widget fora da área de trabalho: vai para a cópia guardada, que é o que volta ao
# religar. Modo novo: o widget aplica o preset ao aparecer (ajustado=false, sem o tamanho guardado);
# tela ou canto novos: o tamanho fica, a posição sai.
widget_copia_ajustar() {  # efeito objeto-json-do-General modo-novo(0|1) lugar-novo(0|1)
  compgen -G "$widgets_dados/$1-tela*.json" >/dev/null || return 0
  WD=$widgets_dados E=$1 NOVO=$2 MODO=$3 LUGAR=$4 python3 -c 'import glob, json, os
novo = json.loads(os.environ["NOVO"])
for f in glob.glob(os.path.join(os.environ["WD"], os.environ["E"] + "-tela*.json")):
    c = json.load(open(f))
    for k, v in novo.items():
        c["General|" + k] = str(v)
    if os.environ["MODO"] == "1":
        c["General|ajustado"] = "false"
        c.pop("__geo", None)
    elif os.environ["LUGAR"] == "1" and isinstance(c.get("__geo"), dict):
        c["__geo"].pop("x", None); c["__geo"].pop("y", None)
    json.dump(c, open(f, "w"), ensure_ascii=False)' 2>/dev/null || true
}

# Acrescenta o widget na(s) tela(s) escolhida(s), no canto escolhido, descendo (ou subindo) até não
# sobrepor nenhum widget que já esteja lá. Devolve a configuração guardada, se houver.
# Retângulos pedidos nos últimos segundos: "hora tela x y largura altura" (o restart_plasmashell espera
# a data deste arquivo assentar antes de reiniciar).
widgets_recentes="$state/widgets-recentes"
widgets_espremidos="$state/widgets-espremidos"   # applet largura altura: o pedido que o Plasma não deu
# Objeto JS {applet:[L,A]}, para as cópias não guardarem o tamanho de quem ainda está espremido.
widgets_espremidos_json() {
  [[ -s $widgets_espremidos ]] || { printf '{}'; return 0; }
  awk 'NF == 3 { printf "%s\"%s\":[%s,%s]", s, $1, $2, $3; s = "," } BEGIN { printf "{" } END { printf "}" }' "$widgets_espremidos"
}
widgets_recentes_json() {
  [[ -s $widgets_recentes ]] || { printf '{}'; return 0; }
  awk -v h="$(date +%s)" 'h - $1 < 8 && NF == 6 { l[$2] = l[$2] (l[$2] == "" ? "" : ",") "[" $3 "," $4 "," $5 "," $6 "]" }
    END { printf "{"; for (t in l) { printf "%s\"%s\":[%s]", s, t, l[t]; s = "," } printf "}" }' "$widgets_recentes"
}
widgets_criar_extra=""      # chaves a mais do General na criação ('"novaCerca":true')
widgets_pasta_criada=""     # pasta que o CLI criou para a cerca nova (some se a cerca não nascer)
widgets_resposta_curta=0    # "cyberkde cerca nova": sem o estado inteiro na resposta
widgets_nova_sem_pasta=0    # a instância nasce sem pasta: se sumir (Esc), é órfã e é descartada
widgets_criar_conector=""   # saída de vídeo onde criar (a do mouse); vazio: a escolha do widget
widget_avisos_extra=()      # avisos de quem chama o widget_cmd
widgets_criar() {  # efeito
  local efeito=$1 plugin w h tela canto extra dados js saida reposicionar=${2:-0}
  plugin=$(widget_campo "$efeito" 2) w=$(widget_campo "$efeito" 3) h=$(widget_campo "$efeito" 4)
  # Insere no tamanho do preset, se o main.qml o disser: o widget se ajusta a ele logo depois, e reservar
  # outro tamanho deixava buraco (ou sobreposição) para quem vem em seguida.
  local m p
  m=$(widget_modo "$(widget_pref "$efeito" modo "$(widget_campo "$efeito" 12)")")
  for p in $(widget_campo "$efeito" 18); do
    if [[ $p == "$m="* ]]; then p=${p#*=}; w=${p%x*}; h=${p#*x}; fi
  done
  tela=$(widget_pref "$efeito" tela principal) canto=$(widget_pref "$efeito" posicao superior-direito)
  extra=$(widget_config_escolhida "$efeito")
  if [[ -n $widgets_criar_extra ]]; then
    if [[ $extra == '{}' ]]; then extra="{$widgets_criar_extra}"; else extra="{$widgets_criar_extra,${extra#\{}"; fi
  fi
  dados=$(WD=$widgets_dados E=$efeito python3 -c 'import glob, json, os, re
d = {}
for f in glob.glob(os.path.join(os.environ["WD"], os.environ["E"] + "-tela*.json")):
    d[re.search(r"tela(\d+)\.json$", f).group(1)] = json.load(open(f))
print(json.dumps(d, ensure_ascii=False))' 2>/dev/null || echo '{}')
  js=$(cat <<'JS'
var plugin = "@@PLUGIN@@", W = @@W@@, H = @@H@@, canto = "@@CANTO@@", telas = "@@TELAS@@";
function origem(t) {
  var o = {x: 0, y: 0}, ps = panels();
  for (var i = 0; i < ps.length; i++) { var p = ps[i]; if (p.screen != t) continue;
    if (p.location == "top") o.y += p.height; else if (p.location == "left") o.x += p.height; }
  return o;
}
var RECENTES = @@RECENTES@@, CONECTOR = "@@CONECTOR@@", extra = @@EXTRA@@, reposicionar = @@REPOS@@, W0 = W, H0 = H, dados = @@DADOS@@, DOCK = @@DOCK@@, ds = desktops(), saida = [];
var M = 24, VAO = 16, CEL = 16;
// Área útil de uma tela, nas coordenadas da geometry: menos os painéis do Plasma nela e, com o Latte
// rodando e sem painel embaixo, a reserva do dock.
function area(t) {
  var g = screenGeometry(t), a = {x: 0, y: 0, w: g.width, h: g.height}, baixo = false, ps = panels();
  for (var i = 0; i < ps.length; i++) { var p = ps[i]; if (p.screen != t) continue; var e = p.height;
    if (p.location == "top") { a.y += e; a.h -= e; } else if (p.location == "bottom") { a.h -= e; baixo = true; }
    else if (p.location == "left") { a.x += e; a.w -= e; } else if (p.location == "right") a.w -= e; }
  if (DOCK > 0 && !baixo) a.h -= DOCK;
  return a;
}
// Mais os pedidos há pouco: logo depois do addWidget, a geometry ainda não é a final, e um "Ligar todos"
// punha o próximo por cima.
function ocupados(d) { var r = [], ws = d.widgets(); for (var j = 0; j < ws.length; j++) { var q = ws[j].geometry; if (q) r.push(q); }
  var rc = RECENTES[String(d.screen)] || []; for (var k = 0; k < rc.length; k++) r.push({x: rc[k][0], y: rc[k][1], width: rc[k][2], height: rc[k][3]});
  return r; }
function livre(ocup, x, y, w, h, vao) {
  if (vao === undefined) vao = VAO;
  for (var j = 0; j < ocup.length; j++) { var r = ocup[j];
    if (x < r.x + r.width + vao && x + w + vao > r.x && y < r.y + r.height + vao && y + h + vao > r.y) return false; }
  return true;
}
// Lugar livre na tela inteira, em grade, a partir do canto escolhido: linha por linha, do canto para dentro.
// Por linhas, a sobra fica contínua; por colunas, ela virava faixas estreitas onde um widget largo não
// cabia, com 60% da tela ocupada. Sem lugar: null.
function lugar(d, w, h, vao) {
  var a = area(d.screen), ocup = ocupados(d);
  var cima = canto.indexOf("superior") >= 0, dir = canto.indexOf("direito") >= 0;
  var xmin = a.x + M, xmax = a.x + a.w - M - w, ymin = a.y + M, ymax = a.y + a.h - M - h;
  if (xmax < xmin || ymax < ymin) return null;
  for (var cy = cima ? ymin : ymax; cima ? cy <= ymax : cy >= ymin; cy += cima ? CEL : -CEL)
    for (var cx = dir ? xmax : xmin; dir ? cx >= xmin : cx <= xmax; cx += dir ? -CEL : CEL)
      if (livre(ocup, cx, cy, w, h, vao)) return {x: cx, y: cy};
  return null;
}
// Sem lugar livre: cascata a partir do canto, 32 px por widget, nunca no mesmo ponto de outro.
function cascata(d, w, h) {
  var a = area(d.screen), ocup = ocupados(d), cima = canto.indexOf("superior") >= 0, dir = canto.indexOf("direito") >= 0;
  var x0 = dir ? a.x + a.w - M - w : a.x + M, y0 = cima ? a.y + M : a.y + a.h - M - h;
  for (var n = 0; n < 200; n++) {
    var x = x0 + (dir ? -1 : 1) * 32 * (n % 20), y = y0 + (cima ? 1 : -1) * 32 * (n % 20) + (cima ? 1 : -1) * 8 * Math.floor(n / 20), igual = false;
    for (var j = 0; j < ocup.length; j++) if (Math.abs(ocup[j].x - x) < 16 && Math.abs(ocup[j].y - y) < 16) igual = true;
    if (!igual) return {x: x, y: y};
  }
  return {x: x0, y: y0};
}
// Telas onde criar: a principal (e, se nela não houver lugar, as outras) ou todas.
var alvos = [];
for (var i = 0; i < ds.length; i++) if (ds[i].screen >= 0 && (telas != "principal" || ds[i].screen == 0)) alvos.push(ds[i]);
// "cyberkde cerca nova": a tela sob o mouse, se o KWin a disse.
if (CONECTOR && typeof screenForConnector == "function") {
  var tm = screenForConnector(CONECTOR);
  for (var i = 0; i < ds.length; i++) if (ds[i].screen == tm && tm >= 0) alvos = [ds[i]];
}
for (var i = 0; i < alvos.length; i++) {
  var d = alvos[i];
  // A cópia desta tela; sem ela, a da tela 0 ou qualquer outra (o widget pode ter ficado em outra tela:
  // as notas não podem ficar para trás).
  var cfg = dados[String(d.screen)] || dados["0"];
  if (!cfg) for (var t in dados) { cfg = dados[t]; break; }
  var g = screenGeometry(d.screen), geo = cfg && cfg.__geo;
  // Com cópia guardada: o tamanho dela (cabendo na tela) e, se nada mudou de lugar, a mesma posição.
  W = W0; H = H0;
  if (geo && geo.width <= g.width && geo.height <= g.height) { W = geo.width; H = geo.height; }
  var pos = null;
  if (geo && !reposicionar && geo.x !== undefined && geo.x >= 0 && geo.y >= 0 && geo.x + W <= g.width && geo.y + H <= g.height &&
      livre(ocupados(d), geo.x, geo.y, W, H)) pos = {x: geo.x, y: geo.y};
  if (!pos) pos = lugar(d, W, H);
  if (!pos) pos = lugar(d, W, H, 2);  // apertado, mas sem cobrir nada
  if (!pos && telas == "principal")
    for (var v = 0; v < 2 && !pos; v++)
      for (var o = 0; o < ds.length && !pos; o++) if (ds[o].screen > 0) { pos = lugar(ds[o], W, H, v ? 2 : VAO); if (pos) d = ds[o]; }
  if (!pos) pos = cascata(d, W, H);
  var x = pos.x, y = pos.y;
  // x e y estão nas coordenadas da tela (as da geometry, guardada na cópia); o addWidget conta a partir
  // do espaço útil (abaixo de uma barra em cima, à direita de uma à esquerda): visto no Plasma 6.6.
  var off = origem(d.screen);
  var w = d.addWidget(plugin, x - off.x, y - off.y, W, H);
  if (!w) continue;
  if (cfg) {
    for (var k in cfg) {
      if (k == "__geo") continue;
      var p = k.split("|"), grupo = p[0] ? p[0].split("/") : [];
      w.currentConfigGroup = grupo;
      w.writeConfig(p[1], cfg[k]);
    }
  }
  // Sem cópia guardada: as escolhas do CLI (cidade, modo, opacidade). Com cópia, ela já as tem (o que
  // a pessoa mudou no próprio widget, ou o que o CLI mudou nela com o widget desligado).
  if (!cfg) {
    w.currentConfigGroup = ["General"];
    for (var ch in extra) w.writeConfig(ch, extra[ch]);
  }
  if (w.reloadConfig) w.reloadConfig();
  // Mesa cheia: o Plasma espreme o applet no vão que sobra (640x320 virava 160x320). Anotado, para esse
  // tamanho, que não foi escolha de ninguém, não ir para a cópia guardada.
  var qn = w.geometry, esp = qn && (qn.width < W - 16 || qn.height < H - 16) ? W + " " + H : "";
  saida.push(d.screen + "\t" + d.id + "\t" + w.id + "\t" + [x, y, W, H].join(" ") + "\t" + esp);
}
print(saida.join("\n"));
JS
)
  # No bash 5.2, um "&" no texto de troca do ${//} vira o trecho casado (patsub_replacement): uma nota
  # com "&" sairia corrompida. Desligado só aqui.
  local antes_patsub
  antes_patsub=$(shopt -p patsub_replacement 2>/dev/null || true)
  shopt -u patsub_replacement 2>/dev/null || true
  js=${js//@@PLUGIN@@/$plugin}; js=${js//@@W@@/$w}; js=${js//@@H@@/$h}
  js=${js//@@CANTO@@/$canto}; js=${js//@@TELAS@@/$tela}
  js=${js//@@EXTRA@@/$extra}; js=${js//@@REPOS@@/$reposicionar}; js=${js//@@CONECTOR@@/$widgets_criar_conector}
  js=${js//@@RECENTES@@/$(widgets_recentes_json)}
  js=${js//@@DOCK@@/$( { pgrep -x latte-dock-ng >/dev/null 2>&1 || pgrep -x latte-dock >/dev/null 2>&1; } && echo 104 || echo 0)}
  js=${js//@@DADOS@@/$dados}
  eval "$antes_patsub"
  saida=$(widget_js "$js") || return 1
  [[ -n $saida ]] || return 1
  mkdir -p -- "$state"
  local linha ld lc la lr le
  while IFS=$'\t' read -r ld lc la lr le; do
    [[ -n $la ]] || continue
    printf '%s\t%s\t%s\t%s\n' "$efeito" "$ld" "$lc" "$la" >>"$widgets_reg"
    printf '%s %s %s\n' "$(date +%s)" "$ld" "$lr" >>"$widgets_recentes"
    [[ -z $le ]] || printf '%s %s\n' "$la" "$le" >>"$widgets_espremidos"
  done <<<"$saida"
}

# Applets do registro que ainda existem (a pessoa pode ter removido um à mão).
widgets_presentes() {  # efeito -> ids presentes
  local ids
  ids=$(widget_applets "$1" | paste -sd, -)
  [[ -n $ids ]] || return 0
  # "ok <applets presentes...> | <contêineres que existem...>"; nada se o plasmashell não respondeu.
  widget_js "var alvo = [$ids], ds = desktops(), r = [], c = [];
for (var i = 0; i < ds.length; i++) { c.push(ds[i].id); var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (alvo.indexOf(ws[j].id) >= 0) r.push(ws[j].id); }
print('ok ' + r.join(' ') + ' | ' + c.join(' '));"
}
# Remoções feitas pelo próprio tema fora do widgets_remover (a barra devolvendo os painéis, por exemplo):
# um applet do registro que sumiu depois disso não foi "removido à mão" e volta, com os dados.
widgets_marca_interna="$state/widgets-remocao-interna"

# Copia a configuração (e a geometria) de todos os applets do tema para widgets-dados, sem remover nada:
# antes de qualquer operação que possa tirá-los (a barra mexendo no appletsrc).
widgets_salvar_todos() {
  [[ -s $widgets_reg ]] || return 0
  qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || return 0
  local e ids saida
  mkdir -p -- "$widgets_dados" "$state"
  : >"$widgets_marca_interna"
  for e in $(widgets_lista); do
    ids=$(widget_applets "$e" | paste -sd, -)
    [[ -n $ids ]] || continue
    saida=$(widget_js "var alvo = [$ids], esp = $(widgets_espremidos_json), copia = {}, ds = desktops();
function ler(w) { var r = {};
  function andar(p) { w.currentConfigGroup = p; var ks = w.configKeys || [];
    for (var i = 0; i < ks.length; i++) r[p.join('/') + '|' + ks[i]] = w.readConfig(ks[i]);
    var gs = w.configGroups || []; for (var j = 0; j < gs.length; j++) andar(p.concat([gs[j]])); }
  andar([]); return r; }
for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets();
  for (var j = 0; j < ws.length; j++) { if (alvo.indexOf(ws[j].id) < 0) continue;
    var c = ler(ws[j]), q = ws[j].geometry;
    var ex = esp[ws[j].id];
    if (q && q.width > 0 && !(ex && (q.width < ex[0] - 16 || q.height < ex[1] - 16))) c.__geo = {x: q.x, y: q.y, width: q.width, height: q.height};
    copia[String(ds[i].screen)] = c; } }
print(JSON.stringify(copia));") || continue
    WD=$widgets_dados E=$e python3 -c 'import json, os, sys
d = json.loads(sys.stdin.read() or "{}")
for tela, cfg in d.items():
    if cfg:
        open(os.path.join(os.environ["WD"], "%s-tela%s.json" % (os.environ["E"], tela)), "w").write(json.dumps(cfg, ensure_ascii=False))' <<<"$saida" 2>/dev/null || true
  done
}

# Põe o widget de acordo com a escolha: ligado e sem applet do tema = cria; desligado = remove. Um
# applet do registro que sumiu foi removido à mão: vale como desligar.
widget_aplicar() {  # efeito [refazer|ligar]
  local efeito=$1 registrados presentes conts c interno=0 achou=0 meus
  registrados=$(widget_applets "$efeito" | paste -sd' ' -)
  if [[ -n $registrados ]]; then
    presentes=$(widgets_presentes "$efeito")
    # Plasmashell sem resposta: não dá para saber, e nada muda (antes, isso também valia "removido à mão").
    [[ $presentes == ok* ]] || return 0
    conts=" ${presentes#*|} "; presentes=${presentes#ok}; presentes=${presentes%%|*}
    if [[ -z ${presentes// /} ]]; then
      meus=$(awk -F'\t' -v e="$efeito" '$1 == e {print $3}' "$widgets_reg" 2>/dev/null)
      awk -F'\t' -v e="$efeito" '$1 != e' "$widgets_reg" >"$widgets_reg.novo"; mv -f -- "$widgets_reg.novo" "$widgets_reg"
      # Sumiu por obra do tema (remoção interna marcada, ou a área de trabalho onde ele estava não existe
      # mais) ou a pessoa pediu "on": volta, com os dados guardados. Só a remoção à mão de verdade desliga.
      [[ -e $widgets_marca_interna ]] && interno=1
      for c in $meus; do [[ $conts == *" $c "* ]] && achou=1; done
      (( achou )) || interno=1
      if (( ! interno )) && [[ ${2:-} != ligar ]]; then
        kwriteconfig6 --file "$efeitos_file" --group "widget-$efeito" --key ligado false
        echo "  (widget $efeito removido à mão: fica desligado)" >&2
        return 0
      fi
      registrados=""
    fi
  fi
  if [[ $(widget_pref "$efeito" ligado false) != true ]]; then widgets_remover "$efeito"; return; fi
  if [[ ${2:-} == refazer && -n $registrados ]]; then widgets_remover "$efeito"; registrados=""; fi
  if [[ -z $registrados ]]; then
    widget_instalado "$efeito" || install_widgets
    widget_instalado "$efeito" || { echo "Widget $efeito: o pacote não está no projeto (modules/widgets/plasmoides)." >&2; return 1; }
    widgets_criar "$efeito" "$([[ ${2:-} == refazer ]] && echo 1 || echo 0)"
  fi
}

phase_widgets() {
  local e algum=0
  mkdir -p -- "$state"; : >"$widgets_marca_fase"
  # "cyberkde cor"/"corp": a paleta nova já foi para a Paleta.qml (install_widgets), e o reinício do
  # plasmashell do fim a carrega. Nada se move, nada é recriado.
  [[ ${CYBERKDE_TROCA_COR:-0} != 1 ]] || return 0
  if declare -F cerca_atalhos_aplicar >/dev/null; then cerca_atalhos_aplicar; cerca_unidades_aplicar; cerca_orfas_limpar; fi
  for e in $(widgets_lista); do
    [[ $(widget_pref "$e" ligado false) == true || -n $(widget_applets "$e") ]] && algum=1
  done
  (( algum )) || return 0  # nenhum escolhido: nada a fazer, nem precisa do plasmashell
  plasmashell_garantir || { echo "O plasmashell não respondeu; os widgets ficam para o próximo 'cyberkde on'." >&2; return 1; }
  for e in $(widgets_lista); do widget_aplicar "$e" || true; done
  rm -f -- "$widgets_marca_interna"  # o que o tema tirou já voltou
  widgets_layout_aplicar || echo "widgets: o layout FUI não foi aplicado." >&2
}
# A fase não grava chaves (os applets ficam no widgets.tsv), então "on widgets" sozinho deixa o registro
# do tema vazio: a marca diz que ela está ligada mesmo sem nenhum widget.
widgets_marca_fase="$state/widgets-fase"
ligada_widgets() { [[ -s $widgets_reg || -e $widgets_marca_fase ]]; }
widgets_ativo() { tema_ligado || ligada_widgets; }

# "off" (geral ou da fase): tira os que o tema criou, guardando os dados; as escolhas ficam.
pre_off_widgets() {
  if declare -F cerca_unidades_parar >/dev/null; then cerca_unidades_parar; fi
  plasmashell_assentar  # recém-criado: a cópia guardaria uma geometria ainda sem o tamanho final
  [[ -s $widgets_reg ]] || return 0
  qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || { echo "widgets: o plasmashell não está no ar; os widgets do tema ficam até o próximo off." >&2; return 0; }
  local e
  for e in $(widgets_lista); do widgets_remover "$e" || true; done
}

# ------------------------------------------------------------------ efeitos widget-<nome>
# Geometria dos applets do tema, para o estado: UMA consulta ao plasmashell (só leitura) por execução
# do cyberkde, para todos os widgets. Os estados são montados em subshells ($(...)), então a resposta
# fica num arquivo com o PID do processo principal ($$); arquivos de execuções que já acabaram são
# apagados. Sem plasmashell ou sem applet do tema: vazio (geometria null).
# O arquivo da consulta (uma por execução): primeira linha "ok" quando o plasmashell respondeu; depois,
# "applet x y largura altura L A" de cada applet do registro que está de fato na área de trabalho.
widgets_geo_arq() {
  local dir="${XDG_RUNTIME_DIR:-/tmp}/cyberkde" arq ids f pid
  arq="$dir/widgets-geo.$$"
  if [[ ! -e $arq ]]; then
    mkdir -p -- "$dir" 2>/dev/null || true
    for f in "$dir"/widgets-geo.*; do
      pid=${f##*.}; [[ -e $f && $pid != "$$" ]] && ! kill -0 "$pid" 2>/dev/null && rm -f -- "$f"
    done
    ids=$(awk -F'\t' '$4 ~ /^[0-9]+$/ {print $4}' "$widgets_reg" 2>/dev/null | paste -sd, -)
    # Além da geometria: as opções lidas do applet real ("k applet chave valor-json") e os applets de
    # widgets com instâncias postos à mão ("solto plugin applet x y l a L A tela contêiner").
    local l e sp soltos="" chaves="" lista=""
    for l in "${widgets_tabela[@]}"; do
      e=${l%%$'\t'*}
      widget_instanciavel "$e" && soltos+="${soltos:+,}\"org.cyberkde.$e\":1"
      lista=""
      widget_instanciavel "$e" && lista='"modo","opacidade"'  # por instância, em estado.instancias
      for sp in $(widget_campo "$e" 10); do
        sp=${sp#*:}; lista+="${lista:+,}\"${sp%%:*}\""
      done
      [[ -z $lista ]] || chaves+="${chaves:+,}\"org.cyberkde.$e\":[$lista]"
    done
    if [[ -n $ids$soltos ]]; then
      widget_js "var alvo = [$ids], solto = {$soltos}, chaves = {$chaves}, ds = desktops(), r = ['ok'];
for (var i = 0; i < ds.length; i++) { if (ds[i].screen < 0) continue; var g = screenGeometry(ds[i].screen), ws = ds[i].widgets();
  for (var j = 0; j < ws.length; j++) { var w = ws[j], q = w.geometry, reg = alvo.indexOf(w.id) >= 0;
    if (!q || (!reg && !solto[w.type])) continue;
    var n = [Math.round(q.x), Math.round(q.y), Math.round(q.width), Math.round(q.height), Math.round(g.width), Math.round(g.height)].join(' ');
    r.push(reg ? w.id + ' ' + n : 'solto ' + w.type + ' ' + w.id + ' ' + n + ' ' + ds[i].screen + ' ' + ds[i].id);
    var cs = chaves[w.type] || []; w.currentConfigGroup = ['General'];
    for (var c = 0; c < cs.length; c++) { var v = w.readConfig(cs[c]);
      if (v !== undefined && v !== null && String(v) !== '') r.push('k ' + w.id + ' ' + cs[c] + ' ' + JSON.stringify(String(v))); } } }
print(r.join(String.fromCharCode(10)));" >"$arq.novo" 2>/dev/null || true
      mv -f -- "$arq.novo" "$arq" 2>/dev/null || true
    else
      : >"$arq" 2>/dev/null || true
    fi
  fi
  printf '%s\n' "$arq"
}
# Depois de mudar a área de trabalho: a consulta desta execução ficou velha.
widgets_geo_esquecer() { rm -f -- "${XDG_RUNTIME_DIR:-/tmp}/cyberkde/widgets-geo.$$"; widgets_cfg_ok=0; }
# Valores das opções em lote: do applet real ("a<id>:<chave>") e das cópias guardadas ("<efeito>:<chave>").
declare -gA widgets_cfg=() widgets_reg_mem=() widgets_geo_mem=()
widgets_cfg_ok=0
widgets_geo_tem=0   # o plasmashell respondeu à consulta desta execução
widgets_cfg_carregar() {
  (( ! widgets_cfg_ok )) || return 0
  local arq l sp q k v
  local -a chaves=(modo opacidade)
  arq=$(widgets_geo_arq)
  for l in "${widgets_tabela[@]}"; do
    for sp in $(widget_campo "${l%%$'\t'*}" 10); do sp=${sp#*:}; chaves+=("${sp%%:*}"); done
  done
  widgets_cfg=(); widgets_reg_mem=(); widgets_geo_mem=(); widgets_geo_tem=0
  local a b c d
  if [[ -s $widgets_reg ]]; then
    while IFS=$'\t' read -r a b c d; do widgets_reg_mem[$a]+="${widgets_reg_mem[$a]:+ }$d"; done <"$widgets_reg"
  fi
  while IFS= read -r l; do
    case $l in
      ok) widgets_geo_tem=1 ;;
      [0-9]*) widgets_geo_mem[${l%% *}]=$l ;;
    esac
  done <"$arq"
  while IFS=$'\x1f' read -r -d '' q k v; do widgets_cfg["$q:$k"]=$v; done < <(python3 -c '
import glob, json, os, re, sys
arq, dados, chaves = sys.argv[1], sys.argv[2], set(sys.argv[3:])
def sai(q, k, v):
    sys.stdout.write("%s\x1f%s\x1f%s\0" % (q, k, v))
for f in glob.glob(os.path.join(dados, "*-tela*.json")):
    try:
        d = json.load(open(f, encoding="utf-8"))
    except (OSError, ValueError):
        continue
    e = re.sub(r"-tela\d+\.json$", "", os.path.basename(f))
    sai(e, "__copia", "1")
    for c, v in d.items():
        if c.startswith("General|") and c[8:] in chaves and v not in (None, ""):
            sai(e, c[8:], v)
try:
    linhas = open(arq, encoding="utf-8").read().splitlines()
except OSError:
    linhas = []
for l in linhas:
    p = l.split(" ", 3)
    if p[0] == "k" and len(p) == 4:
        sai("a" + p[1], p[2], json.loads(p[3]))
' "$arq" "$widgets_dados" "${chaves[@]}" 2>/dev/null)
  widgets_cfg_ok=1
}
# Valor de uma opção: o do applet real; sem applet, o da cópia guardada; depois a escolha, depois o padrão.
widget_opc_valor() {  # chave-da-instância spec
  local e=$1 oid chave tipo pad id v=""
  IFS=: read -r oid chave tipo _ _ _ pad _ <<<"$2"
  # Opção global: o que o módulo diz (na cerca, o arquivo comum), antes de qualquer applet.
  if declare -F "widget_global_ler_${e%%@*}" >/dev/null; then
    v=$("widget_global_ler_${e%%@*}" "$chave")
    if [[ -n $v ]]; then printf '%s\n' "$v"; return 0; fi
  fi
  # Com o applet na mesa, ele manda, mesmo vazio (a cerca limpa o título ao renomear): a escolha guardada
  # pode estar velha. O mesmo para a cópia guardada, sem applet.
  for id in $(widget_applets "$e"); do
    if [[ -n ${widgets_geo_mem[$id]-} ]]; then printf '%s\n' "${widgets_cfg[a$id:$chave]-${pad:-}}"; return 0; fi
  done
  if [[ -n ${widgets_cfg[$e:__copia]-} ]]; then printf '%s\n' "${widgets_cfg[$e:$chave]-${pad:-}}"; return 0; fi
  v=$(widget_pref "$e" "$oid")
  printf '%s\n' "${v:-${pad:-}}"
}
widget_esta_ligado() {  # chave-da-instância [presentes]
  local n=${2:-}
  [[ -n $n ]] || n=$(widget_presentes_n "$1")
  [[ $(widget_pref "$1" ligado false) == true ]] || return 1
  (( n > 0 )) || [[ -z $(widget_applets "$1") ]]
}
# estado.instancias: as do tema e as postas à mão; cada uma com id, ligado, geometria, manual e as opções.
widget_instancias_json() {  # base
  local b=$1 k out="" sp oid tipo v o arq l mpad opad m op
  local -a c
  mpad=$(widget_campo "$b" 12); opad=$(widget_campo "$b" 13)
  for k in $(widget_instancias_chaves "$b"); do
    # Órfã (criada sem pasta e desfeita com Esc): sai da lista; o próximo comando a descarta.
    if [[ $(widget_pref "$k" semPasta) == true && -n $(widget_applets "$k") ]] && (( widgets_geo_tem )) && [[ $(widget_presentes_n "$k") == 0 ]]; then continue; fi
    m=$(widget_opc_valor "$k" "modo:modo:texto::::$mpad"); op=$(widget_opc_valor "$k" "opacidade:opacidade:inteiro::::$opad")
    [[ $op =~ ^[0-9]+$ ]] || op=$opad
    o=",\"tela\":\"$(widget_pref "$k" tela principal)\",\"posicao\":\"$(widget_pref "$k" posicao superior-direito)\",\"modo\":\"$(widget_modo "$m")\",\"opacidade\":$op"
    for sp in $(widget_campo "$b" 10); do
      IFS=: read -r oid _ tipo _ <<<"$sp"
      v=$(widget_opc_valor "$k" "$sp")
      if [[ $tipo == inteiro ]]; then [[ $v =~ ^-?[0-9]+$ ]] || v=null; o+=",\"$oid\":$v"; else o+=",\"$oid\":$(json_str "$v")"; fi
    done
    out+="${out:+,}{\"id\":\"$(widget_chave_id "$k")\",\"ligado\":$(widget_esta_ligado "$k" && echo true || echo false),\"manual\":false,\"geometria\":$(widgets_geo "$k")$o}"
  done
  arq=$(widgets_geo_arq)
  while IFS= read -r l; do
    read -ra c <<<"$l"
    (( ${#c[@]} == 11 )) && [[ ${c[1]} == "org.cyberkde.$b" ]] || continue
    # Posta à mão não tem escolha guardada: a posição é o canto mais perto de onde ela está.
    m=${widgets_cfg[a${c[2]}:modo]-$mpad}; op=${widgets_cfg[a${c[2]}:opacidade]-$opad}
    [[ $op =~ ^[0-9]+$ ]] || op=$opad
    o=",\"tela\":\"principal\",\"posicao\":\"$(( c[4] + c[6] / 2 < c[8] / 2 )) $(( c[3] + c[5] / 2 >= c[7] / 2 ))\""
    o=${o/1 1\"/superior-direito\"}; o=${o/1 0\"/superior-esquerdo\"}; o=${o/0 1\"/inferior-direito\"}; o=${o/0 0\"/inferior-esquerdo\"}
    o+=",\"modo\":\"$(widget_modo "$m")\",\"opacidade\":$op"
    for sp in $(widget_campo "$b" 10); do
      IFS=: read -r oid k tipo _ _ _ v _ <<<"$sp"
      l=""
      if declare -F "widget_global_ler_$b" >/dev/null; then l=$("widget_global_ler_$b" "$k"); fi
      v=${l:-${widgets_cfg[a${c[2]}:$k]-${v:-}}}
      if [[ $tipo == inteiro ]]; then [[ $v =~ ^-?[0-9]+$ ]] || v=null; o+=",\"$oid\":$v"; else o+=",\"$oid\":$(json_str "$v")"; fi
    done
    out+="${out:+,}{\"id\":\"a${c[2]}\",\"ligado\":true,\"manual\":true,\"geometria\":{\"x\":${c[3]},\"y\":${c[4]},\"largura\":${c[5]},\"altura\":${c[6]},\"tela\":[${c[7]},${c[8]}]}$o}"
  done < <(grep '^solto ' "$arq" 2>/dev/null || true)
  printf '[%s]' "$out"
}

# Quantos applets do efeito estão de fato na área de trabalho (com o plasmashell fora do ar: os do registro).
widget_presentes_n() {  # efeito
  local arq id n=0
  if (( widgets_cfg_ok )); then
    if (( ! widgets_geo_tem )); then widget_applets "$1" | grep -c . || true; return 0; fi
    for id in $(widget_applets "$1"); do [[ -z ${widgets_geo_mem[$id]-} ]] || n=$((n + 1)); done
    echo "$n"; return 0
  fi
  arq=$(widgets_geo_arq)
  if [[ $(head -1 "$arq" 2>/dev/null) != ok ]]; then widget_applets "$1" | grep -c .; return 0; fi
  for id in $(widget_applets "$1"); do awk -v i="$id" '$1 == i {f = 1} END {exit !f}' "$arq" && n=$((n + 1)); done
  echo "$n"
}
widgets_geo() {  # efeito -> {"x":…,"y":…,"largura":…,"altura":…,"tela":[L,A]} ou null
  local arq="" linha
  (( widgets_cfg_ok )) || arq=$(widgets_geo_arq)
  # O primeiro applet do efeito no registro (com --tela todas, o da tela principal vem primeiro).
  local id a=()
  for id in $(widget_applets "$1"); do
    if (( widgets_cfg_ok )); then linha=${widgets_geo_mem[$id]-}; else linha=$(awk -v i="$id" '$1 == i' "$arq" 2>/dev/null | head -1); fi
    [[ -n $linha ]] && { read -ra a <<<"$linha"; break; }
  done
  if (( ${#a[@]} == 7 )); then
    printf '{"x":%d,"y":%d,"largura":%d,"altura":%d,"tela":[%d,%d]}' "${a[@]:1}"
  else
    printf null
  fi
}

widget_estado() {  # efeito -> JSON (com instâncias: o da primeira, mais "instancias")
  local b=$1 e=$1 n extra="" sp oid tipo v ligado=false instancias=""
  widgets_cfg_carregar
  if widget_instanciavel "$b"; then
    e=$(widget_instancia_primeira "$b")
    instancias=",\"instancias\":$(widget_instancias_json "$b")"
  fi
  if declare -F "widget_estado_extra_$b" >/dev/null; then instancias+=$("widget_estado_extra_$b"); fi
  # Da área de trabalho real: um applet do registro que a pessoa tirou à mão não conta, e o widget aparece
  # desligado (antes o painel mostrava ligado um widget que não existia, e o clique mandava "off").
  n=$(widget_presentes_n "$e")
  if widget_esta_ligado "$e" "$n"; then ligado=true; fi
  for sp in $(widget_campo "$e" 10); do
    IFS=: read -r oid _ tipo _ <<<"$sp"
    v=$(widget_opc_valor "$e" "$sp")
    if [[ $tipo == inteiro ]]; then [[ $v =~ ^-?[0-9]+$ ]] || v=null; extra+=",\"$oid\":$v"
    else extra+=",\"$oid\":$(json_caminho "$v")"; fi
  done
  printf '{"ligado":%s,"tela":"%s","posicao":"%s"%s,"modo":"%s","opacidade":%s,"naAreaDeTrabalho":%d,"instalado":%s,"disponivel":%s,"dadosGuardados":%s,"categoria":"%s","geometria":%s%s}' \
    "$ligado" \
    "$(widget_pref "$e" tela principal)" "$(widget_pref "$e" posicao superior-direito)" \
    "$extra" \
    "$(widget_modo "$(widget_pref "$e" modo "$(widget_campo "$e" 12 || echo pequeno)")")" "$(widget_pref "$e" opacidade "$(widget_campo "$e" 13 || echo 95)")" "$n" \
    "$(widget_instalado "$e" && echo true || echo false)" "$(widget_no_projeto "$e" && echo true || echo false)" \
    "$(compgen -G "$widgets_dados/$e-tela*.json" >/dev/null && echo true || echo false)" \
    "$(widget_campo "$e" 11 || echo outros)" "$(widgets_geo "$e")" "$instancias"
}
widget_json() {  # efeito -> item do efeito --lista
  local e=$1 previa opcoes c cantos="" forma comando
  previa="$project/assets/previas/widgets/$e.webp"; [[ -f $previa ]] || previa="$project/assets/previas/widgets/$e.png"
  [[ -f $previa ]] || previa=""
  for c in "${widgets_cantos[@]}"; do
    case $c in
      superior-direito) cantos+="${cantos:+,}{\"id\":\"$c\",\"nome\":\"Canto superior direito\",\"nome_en\":\"Top right\"}" ;;
      inferior-direito) cantos+="${cantos:+,}{\"id\":\"$c\",\"nome\":\"Canto inferior direito\",\"nome_en\":\"Bottom right\"}" ;;
      superior-esquerdo) cantos+="${cantos:+,}{\"id\":\"$c\",\"nome\":\"Canto superior esquerdo\",\"nome_en\":\"Top left\"}" ;;
      inferior-esquerdo) cantos+="${cantos:+,}{\"id\":\"$c\",\"nome\":\"Canto inferior esquerdo\",\"nome_en\":\"Bottom left\"}" ;;
    esac
  done
  opcoes="{\"id\":\"tela\",\"nome\":\"Tela\",\"nome_en\":\"Screen\",\"tipo\":\"escolha\",\"padrao\":\"principal\",\"valores\":[{\"id\":\"principal\",\"nome\":\"Principal\",\"nome_en\":\"Main\"},{\"id\":\"todas\",\"nome\":\"Todas\",\"nome_en\":\"All\"}]}"
  opcoes+=",{\"id\":\"posicao\",\"nome\":\"Posição\",\"nome_en\":\"Position\",\"tipo\":\"escolha\",\"padrao\":\"superior-direito\",\"valores\":[$cantos]}"
  local mpad omin omax
  mpad=$(widget_campo "$e" 12); omin=$(widget_campo "$e" 14); omax=$(widget_campo "$e" 15)
  opcoes+=',{"id":"modo","nome":"Modo","nome_en":"Mode","tipo":"escolha","padrao":"'"${mpad:-pequeno}"'","valores":[{"id":"pequeno","nome":"Pequeno","nome_en":"Small"},{"id":"medio","nome":"Médio","nome_en":"Medium"},{"id":"grande","nome":"Grande","nome_en":"Large"}]}'
  opcoes+=',{"id":"opacidade","nome":"Opacidade","nome_en":"Opacity","tipo":"inteiro","min":'"${omin:-30}"',"max":'"${omax:-100}"',"padrao":'"$(widget_campo "$e" 13 || echo 95)"',"unidade":"%"}'
  forma='{"liga":true,"opcoes":{"tela":"flag","posicao":"flag","modo":"flag","opacidade":"flag"'
  comando="cyberkde efeito widget-$e [on|off] [--tela {tela}] [--posicao {posicao}] [--modo {modo}] [--opacidade {opacidade}]"
  local extra sp oid
  extra=$(widget_campo "$e" 9); extra=${extra#[}; extra=${extra%]}
  [[ -z $extra ]] || opcoes+=",$extra"
  for sp in $(widget_campo "$e" 10); do
    oid=${sp%%:*}; forma+=",\"$oid\":\"flag\""; comando+=" [--$oid {$oid}]"
  done
  if declare -F "widget_opcoes_extra_$e" >/dev/null; then
    local ex idx
    ex=$("widget_opcoes_extra_$e"); opcoes+=$ex
    for idx in $(grep -oE '\{"id":"[a-z-]+","nome"' <<<"$ex" | cut -d'"' -f4); do
      [[ $idx == off || $idx == on ]] && continue
      forma+=",\"$idx\":\"flag\""; comando+=" [--$idx {$idx}]"
    done
  fi
  forma+='}}'
  local multi=""
  if widget_instanciavel "$e"; then
    comando+=" [--instancia {instancia}]"
    multi=",\"multiInstancia\":true,\"comandoNova\":\"cyberkde efeito widget-$e nova\",\"comandoRemover\":\"cyberkde efeito widget-$e remover {instancia}\""
  fi
  printf '{"id":"widget-%s","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"liga","categoria":"%s","previa":%s,"opcoes":[%s],"forma":%s,"comando":%s%s,"estado":%s}' \
    "$e" "$(json_str "Widget: $(widget_campo "$e" 5)")" "$(json_str "Widget: $(widget_campo "$e" 6)")" \
    "$(json_str "$(widget_campo "$e" 7)")" "$(json_str "$(widget_campo "$e" 8)")" "$(widget_campo "$e" 11)" "$(json_caminho "$previa")" \
    "$opcoes" "$forma" "$(json_str "$comando")" "$multi" "$(widget_estado "$e")"
}

#   cyberkde efeito widget-<nome> [on|off] [--tela principal|todas] [--posicao <canto>] [--modo pequeno|medio|grande]
#     [--opacidade 30-100] [--<opção do widget> valor ...] [--instancia <id>|todas] [--json]
#   Com instâncias: nova [opções] · remover <id> (o id "1" ou "2", ou "a<applet>" de uma posta à mão). Sem
#   --instancia, vale a primeira do tema. "--instancia todas": só on|off, nas do tema.
#   (sem opções: só lê). --json: {"efeito":"widget-<nome>",<estado>,"avisos":[...]}. Saída: 0 · 1 · 2 · 3
widget_cmd() {  # efeito args...
  local e=$1 b=$1 inst="" alvo_rm="" manual="" sem_instancia=0 acao="" tela="" pos="" modo="" opac="" arg sp oid chave tipo mn mx vals uso_extra="" v n omin omax
  omin=$(widget_campo "$e" 14); omax=$(widget_campo "$e" 15)
  local k=""
  local -A opc_valor=() opc_spec=()
  for sp in $(widget_campo "$e" 10); do
    opc_spec[${sp%%:*}]=$sp
    IFS=: read -r oid _ tipo mn mx vals _ <<<"$sp"
    case $tipo in
      escolha) uso_extra+=" [--$oid ${vals//,/|}]" ;;
      inteiro) uso_extra+=" [--$oid $mn-$mx]" ;;
      *) uso_extra+=" [--$oid \"…\"]" ;;
    esac
  done
  shift
  while (( $# )); do
    arg=$1; shift
    case $arg in
      on | off) acao=$arg ;;
      nova) widget_instanciavel "$b" && acao=nova || acao=invalida ;;
      remover) if widget_instanciavel "$b" && (( $# )); then acao=remover; alvo_rm=$1; shift; else acao=invalida; fi ;;
      --instancia) if widget_instanciavel "$b" && (( $# )); then inst=$1; shift; else acao=invalida; fi ;;
      --tela) tela=${1:-}; shift || true; [[ $tela == principal || $tela == todas ]] || acao=invalida ;;
      --posicao) pos=${1:-}; shift || true; [[ " ${widgets_cantos[*]} " == *" $pos "* ]] || acao=invalida ;;
      --modo) modo=$(widget_modo "${1:-}"); shift || true; [[ -n $modo ]] || acao=invalida ;;
      --opacidade) opac=${1:-}; opac=${opac%\%}; shift || true
        [[ $opac =~ ^[0-9]{1,3}$ ]] && (( 10#$opac >= ${omin:-30} && 10#$opac <= ${omax:-100} )) && opac=$((10#$opac)) || acao=invalida ;;
      --*)
        # --animacao-icones também acha a opção animacaoIcones.
        oid=${arg#--}
        if [[ -z ${opc_spec[$oid]:-} ]]; then
          for k in "${!opc_spec[@]}"; do [[ ${k,,} == "${oid//-/}" ]] && oid=$k; done
        fi
        if [[ -n ${opc_spec[$oid]:-} ]]; then
          IFS=: read -r oid chave tipo mn mx vals _ <<<"${opc_spec[$oid]}"
          (( $# )) || { acao=invalida; continue; }
          v=$1; shift
          case $tipo in
            escolha) [[ ",$vals," == *",$v,"* ]] || acao=invalida ;;
            inteiro) v=${v%\%}
              if [[ $v =~ ^-?[0-9]{1,9}$ ]]; then
                n=$((10#${v#-})); [[ $v != -* ]] || n=$((-n)); v=$n
                (( v >= mn && v <= mx )) || acao=invalida
              else acao=invalida; fi ;;
          esac
          opc_valor[$oid]=$v
        else
          acao=invalida
        fi ;;
      *) acao=invalida ;;
    esac
  done
  [[ $acao != invalida ]] || cor_exit 2 "$(t uso usage): cyberkde efeito widget-$e [on|off] [--tela principal|todas] [--posicao $(IFS='|'; echo "${widgets_cantos[*]}")] [--modo pequeno|medio|grande] [--opacidade ${omin:-30}-${omax:-100}]$uso_extra$(widget_instanciavel "$b" && echo ' [--instancia <id>|todas] | nova | remover <id>') [--json]"
  local -a avisos=("${widget_avisos_extra[@]}")
  # Opção global: vale para todas as instâncias, inclusive com nenhuma na mesa, e não entra em nenhuma delas.
  local globais="" gs
  for oid in "${!opc_valor[@]}"; do
    gs=${opc_spec[$oid]}
    [[ ${gs##*:} == 1 && $gs == *:*:*:*:*:*:*:1 ]] || continue
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    IFS=: read -r _ chave _ <<<"$gs"
    if declare -F "widget_global_gravar_$b" >/dev/null; then "widget_global_gravar_$b" "$chave" "${opc_valor[$oid]}"; fi
    globais+="${globais:+,}\"$chave\":$(json_str "${opc_valor[$oid]}")"
    unset "opc_valor[$oid]"
  done
  if [[ -n $globais ]] && qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
    widget_js "var novo = {$globais}, ds = desktops(); for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (ws[j].type == 'org.cyberkde.$b') { ws[j].currentConfigGroup = ['General']; for (var c in novo) ws[j].writeConfig(c, novo[c]); if (ws[j].reloadConfig) ws[j].reloadConfig(); } }" >/dev/null || true
  fi
  # Qual instância: sem --instancia, a primeira do tema (nunca todas).
  if widget_instanciavel "$b"; then
    local chaves arq_s
    chaves=" $(widget_instancias_chaves "$b" | paste -sd' ' -) "
    arq_s=$(widgets_geo_arq)
    local alvo=${inst:-$alvo_rm}
    if [[ $alvo == todas ]]; then
      [[ $acao == on || $acao == off ]] && [[ -z $tela$pos$modo$opac$alvo_rm ]] && (( ! ${#opc_valor[@]} )) ||
        cor_exit 2 "$(t "--instancia todas só aceita on ou off" "--instancia todas only takes on or off")"
    elif [[ $alvo == a[0-9]* ]]; then
      grep -q "^solto org.cyberkde.$b ${alvo#a} " "$arq_s" 2>/dev/null ||
        cor_exit 2 "$(t "instância desconhecida: $alvo" "unknown instance: $alvo")"
      manual=${alvo#a}
    elif [[ -n $alvo ]]; then
      if [[ $alvo == 1 ]]; then e=$b; else e=$b@$alvo; fi
      [[ $alvo =~ ^[0-9]+$ && $chaves == *" $e "* ]] || cor_exit 2 "$(t "instância desconhecida: $alvo" "unknown instance: $alvo")"
    elif [[ $acao != nova ]]; then
      e=$(widget_instancia_primeira "$b")
    fi
    # Nenhuma instância: opção ou off não têm em quem valer, e não criam uma instância fantasma.
    if [[ -z ${chaves// /} && -z $alvo && $acao != on && $acao != nova ]] && [[ -n $acao$tela$pos$modo$opac ]] || { [[ -z ${chaves// /} && -z $alvo && $acao != on && $acao != nova ]] && (( ${#opc_valor[@]} )); }; then
      sem_instancia=1
      avisos+=("$(t "Nenhuma instância ainda: nada mudou. Crie uma com: cyberkde efeito widget-$b nova" "No instance yet: nothing changed. Create one with: cyberkde efeito widget-$b nova")")
    fi
  fi
  if (( sem_instancia )); then
    :
  elif [[ $acao == remover ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    if [[ -n $manual ]]; then
      widget_js "var ds = desktops(); for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (ws[j].id == $manual) ws[j].remove(); }" >/dev/null ||
        cor_exit 1 "$(t "o plasmashell não respondeu" "plasmashell did not respond")"
    else
      if [[ -n $(widget_applets "$e") ]]; then
        widgets_remover "$e" || cor_exit 1 "$(t "o plasmashell não respondeu" "plasmashell did not respond")"
      fi
      rm -f -- "$widgets_dados/$e-tela"*.json
      widget_prefs_apagar "$e"
    fi
    avisos+=("$(t "A cerca saiu da área de trabalho; a pasta e os arquivos não foram tocados." "The instance left the desktop; the folder and its files were not touched.")")
    inst=""
  elif [[ -n $manual ]] && [[ -z $acao$tela$pos || $acao == on && -z $tela$pos ]]; then
    # Posta à mão, só opções: ao vivo nela, sem registro nem escolhas guardadas.
    if [[ -n $modo$opac ]] || (( ${#opc_valor[@]} )); then
      take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
      local novo=""
      for oid in "${!opc_valor[@]}"; do
        IFS=: read -r _ chave tipo _ <<<"${opc_spec[$oid]}"
        if [[ $tipo == inteiro ]]; then novo+=",\"$chave\":${opc_valor[$oid]}"; else novo+=",\"$chave\":$(json_str "${opc_valor[$oid]}")"; fi
      done
      [[ -z $modo ]] || novo+=",\"modo\":\"$modo\""
      [[ -z $opac ]] || novo+=",\"opacidade\":$opac"
      widget_config_ao_vivo_ids "$manual" "{${novo#,}}"
    fi
  elif [[ $inst == todas ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    local k
    local -a lista=()
    mapfile -t lista < <(widget_instancias_chaves "$b")
    (( ${#lista[@]} )) || lista=("$b")
    for k in "${lista[@]}"; do
      kwriteconfig6 --file "$efeitos_file" --group "widget-$k" --key ligado "$([[ $acao == on ]] && echo true || echo false)"
    done
    if widgets_ativo && plasmashell_garantir; then
      for k in "${lista[@]}"; do
        if [[ $acao == on ]]; then widget_aplicar "$k" ligar || true; else widget_aplicar "$k" || true; fi
      done
    else
      avisos+=("$(t "A escolha foi guardada e vale no próximo cyberkde on." "The choice was saved and applies on the next cyberkde on.")")
    fi
  elif [[ -n $acao$tela$pos$modo$opac ]] || (( ${#opc_valor[@]} )); then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    if [[ $acao == nova ]]; then
      e=$(widget_instancia_nova "$b"); acao=on; inst=$(widget_chave_id "$e")
      if (( widgets_nova_sem_pasta )); then kwriteconfig6 --file "$efeitos_file" --group "widget-$e" --key semPasta true; fi
    elif [[ -n $manual ]]; then
      # off, --tela ou --posicao: precisa do ciclo de vida do tema; a posta à mão é adotada, com id novo.
      local sl
      local -a c
      sl=$(grep "^solto org.cyberkde.$b $manual " "$(widgets_geo_arq)" | head -1)
      read -ra c <<<"$sl"
      e=$(widget_instancia_nova "$b"); inst=$(widget_chave_id "$e")
      mkdir -p -- "$state"
      printf '%s\t%s\t%s\t%s\n' "$e" "${c[9]}" "${c[10]}" "$manual" >>"$widgets_reg"
      kwriteconfig6 --file "$efeitos_file" --group "widget-$e" --key ligado true
      manual=""
    fi
    local w=(kwriteconfig6 --file "$efeitos_file" --group "widget-$e")
    [[ -z $acao ]] || "${w[@]}" --key ligado "$([[ $acao == on ]] && echo true || echo false)"
    [[ -z $tela ]] || "${w[@]}" --key tela "$tela"
    [[ -z $pos ]] || "${w[@]}" --key posicao "$pos"
    for oid in "${!opc_valor[@]}"; do "${w[@]}" --key "$oid" "${opc_valor[$oid]}"; done
    [[ -z $modo ]] || "${w[@]}" --key modo "$modo"
    [[ -z $opac ]] || "${w[@]}" --key opacidade "$opac"
    local novo=""
    for oid in "${!opc_valor[@]}"; do
      IFS=: read -r _ chave tipo _ <<<"${opc_spec[$oid]}"
      if [[ $tipo == inteiro ]]; then novo+=",\"$chave\":${opc_valor[$oid]}"; else novo+=",\"$chave\":$(json_str "${opc_valor[$oid]}")"; fi
    done
    [[ -z $modo ]] || novo+=",\"modo\":\"$modo\""
    [[ -z $opac ]] || novo+=",\"opacidade\":$opac"
    [[ -z $novo$tela$pos ]] || widget_copia_ajustar "$e" "{${novo#,}}" "$([[ -n $modo ]] && echo 1 || echo 0)" "$([[ -n $tela$pos ]] && echo 1 || echo 0)"
    if ! widget_no_projeto "$e" && ! widget_instalado "$e"; then
      avisos+=("$(t "O widget ainda não existe nesta versão do tema: a escolha foi guardada." "The widget does not exist in this version of the theme yet: the choice was saved.")")
    elif widgets_ativo && plasmashell_garantir; then
      # Tela ou posição novas com o widget na área de trabalho: tira e põe de novo (com os mesmos dados).
      # "on" pedido liga sempre (mesmo depois de uma remoção à mão, que deixou o registro para trás).
      if [[ -n $tela$pos ]]; then widget_aplicar "$e" refazer || true
      elif [[ $acao == on ]]; then widget_aplicar "$e" ligar || true
      else widget_aplicar "$e" || true; fi
      # Layout FUI: o widget ligado (ou desligado) entra na coluna dele e o painel recalcula o que esconde.
      if [[ -n $acao$tela$pos ]] && ! widget_instanciavel "$e"; then widgets_layout_aplicar || true; fi
      # Opções do widget, modo e opacidade: ao vivo nos que já estão na área de trabalho.
      [[ -z $novo ]] || widget_config_ao_vivo "$e" "{${novo#,}}"
      if [[ $acao == off ]] && compgen -G "$widgets_dados/$e-tela*.json" >/dev/null; then
        avisos+=("$(t "A configuração do widget (as notas, no caso das notas) foi guardada em $widgets_dados e volta quando ele for religado." "The widget settings (the notes, for the notes widget) were saved in $widgets_dados and come back when it is switched on again.")")
      fi
    elif widgets_ativo; then
      avisos+=("$(t "O plasmashell não respondeu: a escolha foi guardada e vale no próximo cyberkde on." "plasmashell did not respond: the choice was saved and applies on the next cyberkde on.")")
    else
      avisos+=("$(t "O tema está desligado: a escolha foi guardada e vale no próximo cyberkde on." "The theme is off: the choice was saved and applies on the next cyberkde on.")")
    fi
  fi
  local estado corpo
  # "cyberkde cerca nova" (o atalho): resposta curta; o estado inteiro custa um terço do tempo.
  if (( widgets_resposta_curta )); then
    # "cerca nova" responde pelo que aconteceu: sem applet, nada fica (nem instância, nem a pasta dele).
    widgets_geo_esquecer
    if [[ -z $(widget_applets "$e") ]]; then
      widget_prefs_apagar "$e"
      if [[ -n $widgets_pasta_criada ]]; then rmdir -- "$widgets_pasta_criada" 2>/dev/null || true; fi
      if ! widgets_ativo; then cor_exit 1 "$(t "O tema está desligado: ligue com cyberkde on para criar cercas." "The theme is off: turn it on with cyberkde on to create fences.")"; fi
      if ! qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then cor_exit 1 "$(t "O plasmashell não respondeu: a cerca não foi criada." "plasmashell did not respond: the fence was not created.")"; fi
      cor_exit 1 "$(t "O Plasma não criou a cerca." "Plasma did not create the fence.")"
    fi
    if (( cor_json )); then printf '{"efeito":"cerca","instancia":%s,"avisos":%s}\n' "$(json_str "$inst")" "$(json_list_str "${avisos[@]}")" >&3
    else echo "$(t "Cerca nova" "New fence"): $inst" >&3; fi
    return 0
  fi
  widgets_geo_esquecer
  estado=$(widget_estado "$b")
  if (( cor_json )); then
    corpo=${estado#\{}
    printf '{"efeito":"widget-%s",%s,%s"avisos":%s}\n' "$b" "${corpo%\}}" "$([[ -z $inst ]] || printf '"instancia":%s,' "$(json_str "$inst")")" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "widget-$b: $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

# ------------------------------------------------------------------ layout FUI (efeito widget-layout)
# modules/widgets/LAYOUT-FUI.md (do Estilo): o Painel FUI no centro da tela e os widgets do tema ligados
# em duas colunas, alinhados às faixas do painel; "livre" devolve as posições de antes.
#   - O script do Plasma 6 não move applet (Widget.setGeometry não faz nada): cada um é tirado e posto
#     de novo no retângulo (addWidget com x, y, largura e altura), com a configuração inteira copiada e
#     General/ajustado=true. O id do applet muda, e o registro (widgets.tsv) acompanha.
#   - Tela: a principal do layout é a que tem mais widgets do tema (a pessoa pode tê-los arrastado para
#     outra tela); sem nenhum, a tela 0.
#   - Área útil: a tela menos os painéis do Plasma nela e, com o Latte rodando, a reserva do dock
#     embaixo (104 px, a mesma do --posicao).
widgets_layout_tsv="$state/layout-fui.tsv"       # efeito  applet  x  y  largura  altura (antes do 1º fui)
layout_pref() { kreadconfig6 --file "$efeitos_file" --group widget-layout --key "$1" --default "$2" 2>/dev/null; }
layout_so_painel() { [[ $(layout_pref soPainel false) == true ]]; }
widgets_layout_auto=""  # "true" quando o último fui caiu sozinho no só-painel (tela estreita)

# Registro: troca o applet antigo pelo novo (tela e contêiner também).
widgets_reg_trocar() {  # antigo novo tela contêiner
  [[ -s $widgets_reg ]] || return 0
  awk -F'\t' -v OFS='\t' -v a="$1" -v n="$2" -v t="$3" -v c="$4" '$4 == a {$2 = t; $3 = c; $4 = n} {print}' \
    "$widgets_reg" >"$widgets_reg.novo" && mv -f -- "$widgets_reg.novo" "$widgets_reg"
}

# Roda o script do layout. modo: fui (aplica) ou livre (devolve as geometrias de "salvas").
widgets_layout_js() {  # fui|livre so(0|1) salvar(0|1) salvas-json
  local itens="" e lf col b n oc ids todos="" mapa="" dock=0 js saida linha a t c
  for e in $(widgets_lista); do
    ids=$(widget_applets "$e" | paste -sd, -)
    [[ -n $ids ]] || continue
    # Cerca: fica onde a pessoa a pôs, a não ser que cruze o layout (como os de fora da tabela). Parada no
    # caminho, o Plasma espremia o Painel FUI (960x380) até o cartão compacto.
    todos+="${todos:+,}$ids"
    local i
    for i in ${ids//,/ }; do mapa+="${mapa:+,}\"$i\":\"$e\""; done
    [[ $e == painelfui ]] && continue
    lf=$(widget_campo "$e" 16)
    if [[ -n $lf ]]; then
      IFS=: read -r col b n oc <<<"$lf"
      itens+="${itens:+,}{\"e\":\"$e\",\"ids\":[$ids],\"col\":\"$col\",\"b\":$b,\"n\":$n,\"oc\":\"$oc\",\"pos\":\"$(widget_pref "$e" posicao superior-direito)\"}"
    else
      itens+="${itens:+,}{\"e\":\"$e\",\"ids\":[$ids],\"col\":\"\",\"pos\":\"$(widget_pref "$e" posicao superior-direito)\"}"
    fi
  done
  if pgrep -x latte-dock-ng >/dev/null 2>&1 || pgrep -x latte-dock >/dev/null 2>&1; then dock=104; fi
  js=$(cat <<'JS'
var MODO = "@@MODO@@", SO = @@SO@@, SALVAR = @@SALVAR@@, DOCK = @@DOCK@@, M = 24, CEL = 16;
var itens = [@@ITENS@@], painel = [@@PAINEL@@], todos = [@@TODOS@@], mapa = {@@MAPA@@}, salvas = @@SALVAS@@;
var ds = desktops(), saida = [];
function acha(id) {
  for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets();
    for (var j = 0; j < ws.length; j++) if (ws[j].id == id) return {w: ws[j], d: ds[i]}; }
  return null;
}
// Tela: a que tem mais applets do tema; sem nenhum, a 0.
var conta = {}, T = 0, melhor = -1;
for (var i = 0; i < todos.length; i++) { var a = acha(todos[i]); if (a && mapa[String(todos[i])] != "painelfui") conta[a.d.screen] = (conta[a.d.screen] || 0) + 1; }
for (var s in conta) if (conta[s] > melhor) { melhor = conta[s]; T = Number(s); }
var D = null;
for (var i = 0; i < ds.length; i++) if (ds[i].screen == T) D = ds[i];
if (!D) { print("erro sem-tela"); } else {
var g = screenGeometry(T), X = 0, Y = 0, W = g.width, H = g.height, baixo = false, ps = panels();
for (var i = 0; i < ps.length; i++) { var p = ps[i]; if (p.screen != T) continue; var t = p.height;
  if (p.location == "top") { Y += t; H -= t; } else if (p.location == "bottom") { H -= t; baixo = true; }
  else if (p.location == "left") { X += t; W -= t; } else if (p.location == "right") { W -= t; } }
if (DOCK > 0 && !baixo) H -= DOCK;
saida.push("tela " + T);
function grade(x, y, w, h) {
  var x0 = Math.ceil(x / CEL) * CEL, y0 = Math.ceil(y / CEL) * CEL;
  return {x: x0, y: y0, width: Math.floor((x + w) / CEL) * CEL - x0, height: Math.floor((y + h) / CEL) * CEL - y0};
}
function cruza(a, b) { return a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y; }
// Cruza de verdade: mais de uma célula da grade nos dois sentidos. O plano e a tela diferem de alguns px
// (a origem do Plasma, que a calibração corrige depois), e um widget encostado não pode contar.
function cruzaMuito(a, b) {
  return Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x) > CEL && Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y) > CEL;
}
function ler(w) {
  var r = {};
  function andar(p) { w.currentConfigGroup = p; var ks = w.configKeys || [];
    for (var i = 0; i < ks.length; i++) r[p.join("/") + "|" + ks[i]] = w.readConfig(ks[i]);
    var gs = w.configGroups || []; for (var j = 0; j < gs.length; j++) andar(p.concat([gs[j]])); }
  andar([]); return r;
}
function geo(w) { var q = w.geometry; return q ? {x: Math.round(q.x), y: Math.round(q.y), width: Math.round(q.width), height: Math.round(q.height)} : null; }
// Põe o applet no retângulo r da área de trabalho d. O setGeometry do script não faz nada, então o
// applet sai e entra de novo, com a configuração inteira. Primeiro se planeja tudo; aqui só saem os
// que mudam (a lista vai na linha "plano"), e o segundo script (widgets_layout_por) os põe de volta.
// Num script só não dá: o applet removido só sai de fato quando o Plasma volta ao laço de eventos, e
// até lá ocupa o lugar, e o Plasma empurraria o novo para o espaço livre mais perto (visto no
// plasmashell isolado: 480,112 960x800 virava 992,112 304x800). Já no lugar: só o ajustado.
var plano = [];
function por(id, d, r) { plano.push({id: id, d: d, r: r}); }
function executar() {
  var sair = [];
  for (var i = 0; i < plano.length; i++) { var pl = plano[i], a = acha(pl.id); if (!a) continue;
    var q = geo(a.w), r = pl.r;
    // Já no lugar (a menos de uma célula da grade: a grade do Plasma conta da origem dele, e o pedido sai
    // 1 px diferente): fica, sem remontar. Antes, todo toque num widget com o layout fui remontava o
    // Painel FUI (id novo, animação de montagem, histórico dos gráficos zerado).
    var perto = function (u, v) { return Math.abs(u - v) < CEL; };
    if (q && a.d.id == pl.d.id && perto(q.x, r.x) && perto(q.y, r.y) && perto(q.width, r.width) && perto(q.height, r.height)) {
      a.w.currentConfigGroup = ["General"]; if (a.w.readConfig("ajustado") != true && a.w.readConfig("ajustado") != "true") a.w.writeConfig("ajustado", true); continue; }
    sair.push({id: pl.id, d: pl.d.id, tela: pl.d.screen, r: r, off: {x: X, y: Y}, cfg: ler(a.w), plugin: a.w.type});
    a.w.remove(); }
  saida.push("plano " + JSON.stringify(sair));
}
if (SALVAR) for (var i = 0; i < todos.length; i++) { var a = acha(todos[i]);
  if (a && a.d.screen == T) { var q = geo(a.w); if (q) saida.push("antes " + mapa[String(todos[i])] + " " + todos[i] + " " + q.x + " " + q.y + " " + q.width + " " + q.height); } }
var ocultos = [];
if (MODO == "fui") {
  var k = Math.min((W - 2 * M) / 1674, (H - 2 * M) / 732);
  if (!SO && k < 0.75) { SO = true; saida.push("auto"); }
  var ocupado = [], area;
  if (SO) {
    k = Math.min((W - 2 * M) / 866, (H - 2 * M) / 732);
    var px = X + (W - 866 * k) / 2, py = Y + (H - 732 * k) / 2, rp = grade(px, py, 866 * k, 732 * k);
    area = rp; ocupado.push(rp);
    for (var i = 0; i < painel.length; i++) por(painel[i], D, rp);
  } else {
    var X0 = X + (W - 1674 * k) / 2, Y0 = Y + (H - 732 * k) / 2;
    var col = {esquerda: X0, direita: X0 + 1294 * k};
    var rp = grade(X0 + 404 * k, Y0, 866 * k, 732 * k);
    area = {x: X0, y: Y0, width: 1674 * k, height: 732 * k}; ocupado.push(area);
    for (var i = 0; i < painel.length; i++) por(painel[i], D, rp);
    for (var i = 0; i < itens.length; i++) { var it = itens[i]; if (!it.col) continue;
      var r = grade(col[it.col], Y0 + 187 * it.b * k, 380 * k, (187 * it.n - 15) * k), posto = false;
      for (var j = 0; j < it.ids.length; j++) { var a = acha(it.ids[j]); if (a && a.d.screen == T) { por(it.ids[j], D, r); posto = true; } }
      if (posto && it.oc) ocultos.push(it.oc); }
  }
  // Os de fora da tabela (ou todos, no só-painel): só saem se cruzarem a área do layout, para o primeiro
  // canto livre fora dela. Sem canto livre fora da área (numa tela de 1920 px as colunas a ocupam quase
  // toda), um canto que não cruze nada do que foi posto (pode cair numa célula vazia): parado, o Plasma
  // empurraria o widget da célula que ele cruza para fora dela.
  var usados = [];
  for (var i = 0; i < plano.length; i++) usados.push(plano[i].r);
  var fora = [];
  for (var i = 0; i < itens.length; i++) { var it = itens[i]; if (it.col && !SO) continue;
    for (var j = 0; j < it.ids.length; j++) { var a = acha(it.ids[j]); if (!a || a.d.screen != T) continue;
      var q = geo(a.w); if (!q) continue;
      // Fora da área, ou dentro dela sem cruzar nada do que foi posto (num canto, numa célula vazia):
      // fica. Mexer só no que precisa (cada remontagem tira o widget e o põe de novo).
      var bate = false;
      for (var u = 0; u < usados.length; u++) if (cruzaMuito(q, usados[u])) bate = true;
      if (!cruza(q, area) || !bate) { ocupado.push(q); usados.push(q); continue; }
      fora.push({id: it.ids[j], q: q, pos: it.pos}); } }
  for (var f = 0; f < fora.length; f++) { var q = fora[f].q, feito = false;
    var cantos = [fora[f].pos, "superior-direito", "inferior-direito", "superior-esquerdo", "inferior-esquerdo"];
    for (var passo = 0; passo < 2 && !feito; passo++) { var contra = passo == 0 ? ocupado : usados;
      for (var c = 0; c < cantos.length && !feito; c++) {
        var dir = cantos[c].indexOf("direito") >= 0, cima = cantos[c].indexOf("superior") >= 0;
        // No canto, com o tamanho dele (sem o arredondamento da grade, que o encolhia a cada vez).
        var r0 = grade(dir ? X + W - q.width - M : X + M, cima ? Y + M : Y + H - q.height - M, q.width, q.height);
        var r = {x: r0.x, y: r0.y, width: q.width, height: q.height}, livre = r0.width > 0;
        for (var o = 0; o < contra.length; o++) if (cruzaMuito(r, contra[o])) livre = false;
        if (livre) { por(fora[f].id, D, r); ocupado.push(r); usados.push(r); feito = true; } } }
    // Sem canto: qualquer vão desta tela e depois das outras. Sem vão nenhum, fica.
    for (var yy = Y + M; !feito && yy + q.height <= Y + H - M; yy += CEL)
      for (var xx = X + M; !feito && xx + q.width <= X + W - M; xx += CEL) {
        var r = {x: xx, y: yy, width: q.width, height: q.height}, livre = true;
        for (var o = 0; o < usados.length; o++) if (cruzaMuito(r, usados[o])) livre = false;
        if (livre) { por(fora[f].id, D, r); usados.push(r); feito = true; } }
    for (var n = 0; !feito && n < ds.length; n++) { var dd = ds[n]; if (dd.screen < 0 || dd.screen == T) continue;
      var gd = screenGeometry(dd.screen), ocup = [], wd = dd.widgets();
      for (var m = 0; m < wd.length; m++) { var qd = wd[m].geometry; if (qd) ocup.push(qd); }
      for (var yy = Y + M; !feito && yy + q.height <= gd.height - M; yy += CEL)
        for (var xx = M; !feito && xx + q.width <= gd.width - M; xx += CEL) {
          var r = {x: xx, y: yy, width: q.width, height: q.height}, livre = true;
          for (var o = 0; o < ocup.length; o++) if (cruzaMuito(r, ocup[o])) livre = false;
          if (livre) { por(fora[f].id, dd, r); feito = true; } } } }
} else {
  for (var i = 0; i < salvas.length; i++) { var sv = salvas[i], id = sv.id;
    if (!acha(id)) { id = null; for (var j = 0; j < itens.length; j++) if (itens[j].e == sv.e) id = itens[j].ids[0];
      if (sv.e == "painelfui" && painel.length) id = painel[0]; }
    var a = id ? acha(id) : null;
    if (a) por(id, a.d, {x: sv.x, y: sv.y, width: sv.w, height: sv.h}); }
}
executar();
saida.push("painel " + JSON.stringify(painel));
saida.push("ocultos " + JSON.stringify(ocultos.join(", ")));
}
print(saida.join("\n"));
JS
)
  local antes_patsub
  antes_patsub=$(shopt -p patsub_replacement 2>/dev/null || true)
  shopt -u patsub_replacement 2>/dev/null || true
  js=${js//@@MODO@@/$1}; js=${js//@@SO@@/$([[ $2 == 1 ]] && echo true || echo false)}
  js=${js//@@SALVAR@@/$([[ $3 == 1 ]] && echo true || echo false)}; js=${js//@@DOCK@@/$dock}
  js=${js//@@ITENS@@/$itens}; js=${js//@@PAINEL@@/$(widget_applets painelfui | paste -sd, -)}
  js=${js//@@TODOS@@/$todos}; js=${js//@@MAPA@@/$mapa}; js=${js//@@SALVAS@@/${4:-[]}}
  eval "$antes_patsub"
  saida=$(widget_js "$js") || return 1
  [[ $saida == *"tela "* ]] || return 1
  widgets_layout_auto=""
  local -a antes=()
  local plano="[]" painel="[]" ocultos='""'
  while IFS= read -r linha; do
    case $linha in
      antes\ *) antes+=("${linha#antes }") ;;
      auto) widgets_layout_auto=true ;;
      plano\ *) plano=${linha#plano } ;;
      painel\ *) painel=${linha#painel } ;;
      ocultos\ *) ocultos=${linha#ocultos } ;;
    esac
  done <<<"$saida"
  # Os removidos saem de fato no laço de eventos do Plasma: só então entram de novo.
  [[ $plano == "[]" ]] || sleep 1
  widgets_plano_por "$plano" "$painel" "$ocultos" || return 1
  if (( ${#antes[@]} )); then
    mkdir -p -- "$state"
    printf '%s\n' "${antes[@]}" | tr ' ' '\t' >"$widgets_layout_tsv"
  fi
}
# Põe de volta os que saíram, atualiza o registro e calibra quem não caiu no lugar.
widgets_plano_por() {  # plano-json painel-ids-json ocultos-json
  local plano=$1 painel=$2 ocultos=$3 saida linha a n t c
  saida=$(widgets_layout_por "$plano" "$painel" "$ocultos") || return 1
  mkdir -p -- "$state"; : >>"$widgets_recentes"; touch -- "$widgets_recentes"
  local -a caidas=()
  while IFS= read -r linha; do
    case $linha in
      novo\ *) read -r _ a n t c <<<"$linha"; widgets_reg_trocar "$a" "$n" "$t" "$c" ;;
      caiu\ *) caidas+=("${linha#caiu }") ;;
    esac
  done <<<"$saida"
  # Calibração: quem não caiu no retângulo pedido sai e entra de novo (uma vez), com o desvio medido.
  if (( ${#caidas[@]} )); then
    local corr
    corr=$(widgets_layout_corrigir "[$(IFS=,; echo "${caidas[*]}")]") || corr=""
    if [[ $corr == plano\ * && $corr != "plano []" ]]; then
      sleep 1
      saida=$(widgets_layout_por "${corr#plano }" "$painel" "$ocultos") || return 1
      while IFS= read -r linha; do
        case $linha in novo\ *) read -r _ a n t c <<<"$linha"; widgets_reg_trocar "$a" "$n" "$t" "$c" ;; esac
      done <<<"$saida"
    fi
  fi
}

# Segundo script do layout: põe de volta os que saíram, cada um no seu retângulo, com a configuração e
# General/ajustado=true (gravado logo depois do addWidget, ele chega antes de o widget decidir aplicar
# o preset), e grava o ocultosLayout do Painel FUI (nunca o "ocultos", que é da pessoa).
widgets_layout_por() {  # plano-json painel-ids-json ocultos-json
  local js
  js=$(cat <<'JS'
var plano = @@PLANO@@, painel = @@PAINEL@@, ocultos = @@OCULTOS@@, ds = desktops(), saida = [], novo = {};
function contem(id) { for (var i = 0; i < ds.length; i++) if (ds[i].id == id) return ds[i]; return null; }
for (var i = 0; i < plano.length; i++) { var s = plano[i], d = contem(s.d); if (!d) continue;
  // r está nas coordenadas da tela; o addWidget conta a partir do espaço útil (off: as barras em cima e à
  // esquerda). Sem isso, um widget sob uma barra de 33 px em cima descia 33 px.
  var o = s.off || {x: 0, y: 0};
  var n = d.addWidget(s.plugin, s.r.x - o.x, s.r.y - o.y, s.r.width, s.r.height);
  if (!n) continue;
  for (var k in s.cfg) { var p = k.split("|"); n.currentConfigGroup = p[0] ? p[0].split("/") : []; n.writeConfig(p[1], s.cfg[k]); }
  n.currentConfigGroup = ["General"]; n.writeConfig("ajustado", true);
  if (n.reloadConfig) n.reloadConfig();
  novo[s.id] = n.id;
  saida.push("novo " + s.id + " " + n.id + " " + d.screen + " " + d.id);
  // Onde ele caiu de fato: a origem do addWidget varia (barra, margens), e a calibração corrige.
  var q = n.geometry;
  if (q) saida.push("caiu " + JSON.stringify({id: n.id, d: s.d, r: s.r, off: o, x: Math.round(q.x), y: Math.round(q.y), plugin: s.plugin})); }
for (var i = 0; i < painel.length; i++) { var id = novo[painel[i]] || painel[i];
  for (var j = 0; j < ds.length; j++) { var ws = ds[j].widgets();
    for (var l = 0; l < ws.length; l++) if (ws[l].id == id) { ws[l].currentConfigGroup = ["General"];
      if (String(ws[l].readConfig("ocultosLayout") || "") != ocultos) {  // só muda se mudou: nada de recarregar à toa
        ws[l].writeConfig("ocultosLayout", ocultos); if (ws[l].reloadConfig) ws[l].reloadConfig(); } } } }
print(saida.join("\n"));
JS
)
  local antes_patsub
  antes_patsub=$(shopt -p patsub_replacement 2>/dev/null || true)
  shopt -u patsub_replacement 2>/dev/null || true
  js=${js//@@PLANO@@/$1}; js=${js//@@PAINEL@@/$2}; js=${js//@@OCULTOS@@/$3}
  eval "$antes_patsub"
  widget_js "$js"
}

# Calibração do layout: entrada = onde cada applet caiu ({id, d, r, off, x, y, plugin}). Quem caiu fora
# do x/y pedido sai (com a configuração), e o plano novo leva a origem corrigida: off + (caiu - pedido).
widgets_layout_corrigir() {  # caidas-json -> "plano <json>"
  local js
  js=$(cat <<'JS'
var caidas = @@CAIDAS@@, ds = desktops(), sair = [];
function ler(w) {
  var r = {};
  function andar(p) { w.currentConfigGroup = p; var ks = w.configKeys || [];
    for (var i = 0; i < ks.length; i++) r[p.join("/") + "|" + ks[i]] = w.readConfig(ks[i]);
    var gs = w.configGroups || []; for (var j = 0; j < gs.length; j++) andar(p.concat([gs[j]])); }
  andar([]); return r;
}
for (var i = 0; i < caidas.length; i++) { var c = caidas[i];
  if (c.x == c.r.x && c.y == c.r.y) continue;
  for (var j = 0; j < ds.length; j++) { var ws = ds[j].widgets();
    for (var l = 0; l < ws.length; l++) if (ws[l].id == c.id) {
      sair.push({id: c.id, d: c.d, r: c.r, off: {x: c.off.x + (c.x - c.r.x), y: c.off.y + (c.y - c.r.y)}, cfg: ler(ws[l]), plugin: c.plugin});
      ws[l].remove(); } } }
print("plano " + JSON.stringify(sair));
JS
)
  local antes_patsub
  antes_patsub=$(shopt -p patsub_replacement 2>/dev/null || true)
  shopt -u patsub_replacement 2>/dev/null || true
  js=${js//@@CAIDAS@@/$1}
  eval "$antes_patsub"
  widget_js "$js"
}

# Aplica o layout escolhido (com a fase widgets, depois de pôr os widgets).
widgets_layout_aplicar() {
  [[ $(layout_pref layout livre) == fui ]] || return 0
  [[ -n $(widget_applets painelfui) ]] || return 0  # sem o Painel FUI na tela, não há layout
  widgets_layout_js fui "$(layout_so_painel && echo 1 || echo 0)" "$([[ -s $widgets_layout_tsv ]] && echo 0 || echo 1)"
}
# Volta às posições guardadas antes do primeiro fui.
widgets_layout_livre() {
  local salvas="" e id x y w h
  if [[ -s $widgets_layout_tsv ]]; then
    while IFS=$'\t' read -r e id x y w h; do
      [[ $id =~ ^[0-9]+$ && $x =~ ^-?[0-9]+$ && $y =~ ^-?[0-9]+$ && $w =~ ^[0-9]+$ && $h =~ ^[0-9]+$ ]] || continue
      salvas+="${salvas:+,}{\"e\":\"$e\",\"id\":$id,\"x\":$x,\"y\":$y,\"w\":$w,\"h\":$h}"
    done <"$widgets_layout_tsv"
  fi
  widgets_layout_js livre 0 0 "[$salvas]" || return 1
  rm -f -- "$widgets_layout_tsv"
}

efeito_estado_widget-layout() {
  printf '{"layout":"%s","soPainel":%s,"soPainelEscolhido":%s,"posicoesGuardadas":%s}' \
    "$(layout_pref layout livre)" \
    "$({ layout_so_painel || [[ -s $state/layout-fui-auto ]]; } && echo true || echo false)" \
    "$(layout_so_painel && echo true || echo false)" \
    "$([[ -s $widgets_layout_tsv ]] && echo true || echo false)"
}
efeito_json_widget-layout() {
  local previa="$project/assets/previas/widgets/painelfui.webp"
  [[ -f $previa ]] || previa=""
  printf '{"id":"widget-layout","grupo":"area-de-trabalho","nome":%s,"nome_en":%s,"descricao":%s,"descricao_en":%s,"tipo":"variante","previa":%s,"opcoes":[{"id":"layout","nome":"Layout","nome_en":"Layout","tipo":"variante","padrao":"livre","valores":[{"id":"fui","nome":"FUI (painel no centro, colunas dos lados)","nome_en":"FUI (dashboard in the middle, side columns)","previa":%s},{"id":"livre","nome":"Livre (onde estavam)","nome_en":"Free (where they were)","previa":null}]},{"id":"so-painel","nome":"Só o painel","nome_en":"Dashboard only","tipo":"escolha","padrao":"off","valores":[{"id":"off","nome":"Painel e colunas","nome_en":"Dashboard and columns"},{"id":"on","nome":"Só o painel","nome_en":"Dashboard only"}]}],"forma":{"liga":false,"opcoes":{"layout":"posicional","so-painel":"flag"}},"comando":"cyberkde efeito widget-layout [{layout}] [--so-painel {so-painel}]","estado":%s}' \
    "$(json_str "Layout dos widgets")" "$(json_str "Widget layout")" \
    "$(json_str "FUI: o Painel FUI no centro da tela e os widgets ligados (relógio, clima, câmbio, desempenho, discos, notas) em colunas dos lados, alinhados às faixas do painel. Livre: cada um onde estava.")" \
    "$(json_str "FUI: the FUI dashboard in the middle of the screen and the widgets that are on (clock, weather, exchange, performance, disks, notes) in side columns, lined up with the dashboard rows. Free: each one where it was.")" \
    "$(json_caminho "$previa")" "$(json_caminho "$previa")" "$(efeito_estado_widget-layout)"
}

#   cyberkde efeito widget-layout [fui|livre] [--so-painel [on|off]] [--json]   (sem nada: só lê)
#   --json: {"efeito":"widget-layout",<estado>,"avisos":[...]}. Saída: 0 · 1 falha · 2 uso · 3 ocupado
efeito_cmd_widget-layout() {
  local layout="" so="" arg
  while (( $# )); do
    arg=$1; shift
    case $arg in
      fui | livre) [[ -z $layout ]] && layout=$arg || layout=invalida ;;
      --so-painel)
        case ${1:-} in
          on | true) so=true; shift ;;
          off | false) so=false; shift ;;
          *) so=true ;;
        esac ;;
      *) layout=invalida ;;
    esac
  done
  [[ $layout != invalida ]] || cor_exit 2 "$(t "uso: cyberkde efeito widget-layout [fui|livre] [--so-painel [on|off]] [--json]" "usage: cyberkde efeito widget-layout [fui|livre] [--so-painel [on|off]] [--json]")"
  local -a avisos=()
  if [[ -n $layout$so ]]; then
    take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
    mkdir -p -- "$(dirname -- "$efeitos_file")"
    local w=(kwriteconfig6 --file "$efeitos_file" --group widget-layout)
    [[ -z $layout ]] || "${w[@]}" --key layout "$layout"
    [[ -z $so ]] || "${w[@]}" --key soPainel "$so"
    layout=$(layout_pref layout livre)
    # fui: o Painel FUI entra (como "efeito widget-painelfui on").
    if [[ $layout == fui ]] && widget_no_projeto painelfui; then
      kwriteconfig6 --file "$efeitos_file" --group widget-painelfui --key ligado true
    fi
    if ! widget_no_projeto painelfui && ! widget_instalado painelfui; then
      avisos+=("$(t "O Painel FUI não está nesta cópia do tema: a escolha foi guardada." "The FUI dashboard is not in this copy of the theme: the choice was saved.")")
    elif widgets_ativo && plasmashell_garantir; then
      if [[ $layout == fui ]]; then
        widget_aplicar painelfui || true
        widgets_layout_aplicar || cor_exit 1 "$(t "não consegui aplicar o layout FUI" "could not apply the FUI layout")"
        rm -f -- "$state/layout-fui-auto"
        if [[ $widgets_layout_auto == true ]]; then
          echo true >"$state/layout-fui-auto"
          avisos+=("$(t "A tela é estreita para as colunas: só o painel foi posicionado." "The screen is too narrow for the columns: only the dashboard was placed.")")
        fi
      else
        widgets_layout_livre || cor_exit 1 "$(t "não consegui devolver as posições dos widgets" "could not restore the widget positions")"
        rm -f -- "$state/layout-fui-auto"
      fi
    elif widgets_ativo; then
      avisos+=("$(t "O plasmashell não respondeu: a escolha foi guardada e vale no próximo cyberkde on." "plasmashell did not respond: the choice was saved and applies on the next cyberkde on.")")
    else
      avisos+=("$(t "O tema está desligado: a escolha foi guardada e vale no próximo cyberkde on." "The theme is off: the choice was saved and applies on the next cyberkde on.")")
    fi
  fi
  local estado
  estado=$(efeito_estado_widget-layout)
  if (( cor_json )); then
    local corpo=${estado#\{}
    printf '{"efeito":"widget-layout",%s,"avisos":%s}\n' "${corpo%\}}" "$(json_list_str "${avisos[@]}")" >&3
  else
    echo "widget-layout: $estado"
    local a
    for a in "${avisos[@]}"; do echo "$(t Aviso Note): $a" >&2; done
  fi
}

for _w in "${widgets_tabela[@]}"; do
  _w=${_w%%$'\t'*}
  CYBERKDE_EFEITOS+=("widget-$_w")
  CYBERKDE_EFEITO_GRUPO+=(["widget-$_w"]=area-de-trabalho)
  eval "efeito_cmd_widget-$_w() { widget_cmd $_w \"\$@\"; }
efeito_json_widget-$_w() { widget_json $_w; }
efeito_estado_widget-$_w() { widget_estado $_w; }"
done
unset _w
CYBERKDE_EFEITOS+=(widget-layout)
CYBERKDE_EFEITO_GRUPO+=([widget-layout]=area-de-trabalho)

# ------------------------------------------------------------------ cerca: atalhos, pasta base e "cyberkde cerca"
# Opções do widget-cerca que são do CLI (não vão para o applet e valem para todas as instâncias), no
# grupo [cerca] das escolhas, à parte do [widget-cerca] que o "remover 1" apaga:
#   --atalhos on|off, --atalho-nova, --atalho-alternar, --base.
# Atalhos: componente de serviço do kglobalaccel. O ~/.local/share/kglobalaccel/cyberkde-cerca.desktop dá
# os comandos, e [services][cyberkde-cerca.desktop] do kglobalshortcutsrc dá as teclas (o daemon só lê
# isso ao iniciar; ao vivo, doRegister + setForeignShortcutKeys, e unRegister para tirar). Arquivo e
# chaves passam pelo registro, com a fase widgets; desligado por padrão.
cerca_pref() {  # chave [padrão]
  if (( efeitos_lote_ativo )); then efeitos_lote_ler cerca "$1" "${2:-}"; return 0; fi
  kreadconfig6 --file "$efeitos_file" --group cerca --key "$1" --default "${2:-}" 2>/dev/null
}
cerca_pref_gravar() { mkdir -p -- "$(dirname -- "$efeitos_file")"; kwriteconfig6 --file "$efeitos_file" --group cerca --key "$1" "$2"; }
cerca_componente=cyberkde-cerca.desktop
cerca_dir="$config/cyberkde/cercas"
cerca_py() { python3 "$widgets_src/cerca_cli.py" "$@"; }
cerca_ocultas_arq="$cerca_dir/ocultas"   # existe = ocultas (o widget vigia)
widgets_estado_dir="$config/cyberkde/widgets"       # ocultos, gesto, junto, animacao.<id> (nomes de arquivo)
widgets_ocultos_arq="$widgets_estado_dir/ocultos"
cerca_candidatos_nova=("Meta+Shift+F" "Meta+Ctrl+Shift+F" "Meta+Alt+F")
cerca_candidatos_alternar=("Meta+Shift+H" "Meta+Ctrl+Shift+H" "Meta+Alt+H")
cerca_candidatos_peek=("Meta+Shift+Space" "Meta+Ctrl+Shift+Space" "Meta+Alt+Space")  # Meta+Space é do sistema
cerca_peek_arq="$config/cyberkde/cercas/peek"   # existe = cercas por cima das janelas (o widget vigia)
cerca_atalho_valido() { [[ $1 =~ ^((Meta|Ctrl|Alt|Shift)\+)*(Meta|Ctrl|Alt)\+((Shift)\+)?([A-Z0-9]|F[0-9]{1,2}|Space)$ ]]; }
cerca_tecla_int() {  # "Meta+Shift+F" -> inteiro do Qt
  local p n=0 t=${1##*+}
  for p in ${1//+/ }; do
    case $p in Meta) n=$(( n | 0x10000000 )) ;; Shift) n=$(( n | 0x02000000 )) ;; Ctrl) n=$(( n | 0x04000000 )) ;; Alt) n=$(( n | 0x08000000 )) ;; esac
  done
  if [[ $t == Space ]]; then echo $(( n | 0x20 ))
  elif [[ $t =~ ^F([0-9]+)$ ]]; then echo $(( n | (0x01000030 + 10#${BASH_REMATCH[1]} - 1) )); else echo $(( n | $(printf %d "'$t") )); fi
}
cerca_gdbus() { gdbus call --session -d org.kde.kglobalaccel -o /kglobalaccel -m "org.kde.KGlobalAccel.$1" "${@:2}" 2>/dev/null; }
# Quem usa a tecla (vazio: livre, ou o daemon fora do ar; a própria cerca não conta).
cerca_dono() {
  local r
  r=$(cerca_gdbus action "$(cerca_tecla_int "$1")") || return 0
  [[ $r == *"'"* && $r != *"$cerca_componente"* ]] || return 0
  r=${r#*\'}; printf '%s\n' "${r%%\'*}"
}
cerca_primeiro_livre() {  # candidatos...
  local k
  for k in "$@"; do [[ -n $(cerca_dono "$k") ]] || { printf '%s\n' "$k"; return 0; }; done
  return 1
}
cerca_ao_vivo() {  # registra no daemon que está no ar (nada se ele não estiver)
  local n=$(cerca_pref atalhoNova) a=$(cerca_pref atalhoAlternar) p=$(cerca_pref atalhoPeek) id1 id2 id3
  # O primeiro item registrado cria o componente e fica sem os padrões do .desktop (defaultKeys vazio), e a
  # tecla dele só vale depois de um login novo: esse lugar é do _launch, sem tecla. As teclas ficam nas
  # Actions (visto no kglobalacceld isolado). Quem veio de uma versão anterior tinha a tecla no _launch.
  cerca_gdbus unRegister "['$cerca_componente','_launch','','']" >/dev/null || return 0
  cerca_gdbus doRegister "['$cerca_componente','_launch','Cyber Fence','Cyber Fence']" >/dev/null || true
  id1="['$cerca_componente','Nova','Cyber Fence','$(t "Nova cerca" "New fence")']"
  id2="['$cerca_componente','Alternar','Cyber Fence','$(t "Mostrar ou ocultar as cercas" "Show or hide the fences")']"
  cerca_gdbus doRegister "$id1" >/dev/null || return 0
  cerca_gdbus doRegister "$id2" >/dev/null || true
  cerca_gdbus setForeignShortcutKeys "$id1" "[([$(cerca_tecla_int "$n"),0,0,0],)]" >/dev/null || true
  cerca_gdbus setForeignShortcutKeys "$id2" "[([$(cerca_tecla_int "$a"),0,0,0],)]" >/dev/null || true
  if [[ -n $p && $p != off ]]; then
    id3="['$cerca_componente','Peek','Cyber Fence','$(t "Cercas por cima das janelas" "Fences above the windows")']"
    cerca_gdbus doRegister "$id3" >/dev/null || true
    cerca_gdbus setForeignShortcutKeys "$id3" "[([$(cerca_tecla_int "$p"),0,0,0],)]" >/dev/null || true
  fi
}
cerca_tirar_ao_vivo() {
  cerca_gdbus unRegister "['$cerca_componente','Nova','','']" >/dev/null || return 0
  cerca_gdbus unRegister "['$cerca_componente','_launch','','']" >/dev/null || true
  cerca_gdbus unRegister "['$cerca_componente','Alternar','','']" >/dev/null || true
  cerca_gdbus unRegister "['$cerca_componente','Peek','','']" >/dev/null || true
}
# Rodando como a fase widgets: set_key e put_file anotam o que devolver no "off".
cerca_atalhos_aplicar() {
  [[ $(cerca_pref atalhos off) == on ]] || return 0
  local n a p dst="$data/kglobalaccel/$cerca_componente"
  n=$(cerca_pref atalhoNova); a=$(cerca_pref atalhoAlternar); p=$(cerca_pref atalhoPeek)
  [[ -n $n && -n $a ]] || return 0
  if [[ -z $p ]]; then  # atalhos ligados antes de o peek existir
    p=$(cerca_primeiro_livre "${cerca_candidatos_peek[@]}") || p=off
    cerca_pref_gravar atalhoPeek "$p"
  fi
  put_file "$dst" <<EOF
[Desktop Entry]
Type=Application
Name=Cyber Fence
Exec="$project/scripts/cyberkde" cerca pedir
NoDisplay=true
Actions=Nova;Alternar;Peek;

[Desktop Action Nova]
Name=$(t "Nova cerca" "New fence")
Exec="$project/scripts/cyberkde" cerca pedir

[Desktop Action Alternar]
Name=$(t "Mostrar ou ocultar as cercas" "Show or hide the fences")
Exec="$project/scripts/cyberkde" cerca alternar

[Desktop Action Peek]
Name=$(t "Cercas por cima das janelas" "Fences above the windows")
Exec="$project/scripts/cyberkde" cerca peek alternar
EOF
  chmod 755 -- "$dst"
  chave_restaurar kglobalshortcutsrc "services][$cerca_componente" _launch  # de versões anteriores
  set_key kglobalshortcutsrc "services][$cerca_componente" Nova "$n"
  set_key kglobalshortcutsrc "services][$cerca_componente" Alternar "$a"
  if [[ $p != off ]]; then set_key kglobalshortcutsrc "services][$cerca_componente" Peek "$p"; fi
  cerca_ao_vivo
}
off_widgets() {
  rm -f -- "${widgets_marca_fase:?}"
  if [[ $(cerca_pref atalhos off) == on ]]; then cerca_tirar_ao_vivo; fi
  # Sem cercas na mesa, o peek não fica pendurado; e widget religado oculto parece widget perdido.
  rm -f -- "${cerca_peek_arq:?}" "${cerca_ocultas_arq:?}" "${widgets_ocultos_arq:?}"
}
CYBERKDE_OFF_HOOKS+=(off_widgets)

cerca_base() {
  local b d
  b=$(cerca_pref base)
  if [[ -n $b ]]; then printf '%s\n' "$b"; return 0; fi
  d=$(xdg-user-dir DOCUMENTS 2>/dev/null || true)
  [[ -n $d && $d != "$HOME" && $d != "$HOME/" ]] || d=$HOME/Documentos
  printf '%s/Cercas\n' "${d%/}"
}
cerca_pasta_nova() {  # -> <base>/Cerca N, criada
  local b n=1
  b=$(cerca_base)
  while [[ -e "$b/Cerca $n" ]]; do n=$((n + 1)); done
  mkdir -p -- "$b/Cerca $n" && printf '%s\n' "$b/Cerca $n"
}

# Pasta nomeada na base (mesmo nome em uso: "Nome 2").
cerca_pasta_titulo() {  # título -> pasta criada
  local b nome n=2 p
  b=$(cerca_base); nome=${1//\//-}
  [[ -n ${nome// /} && $nome != .* ]] || nome="Cerca"
  p="$b/$nome"
  while [[ -e $p ]]; do p="$b/$nome $n"; n=$((n + 1)); done
  mkdir -p -- "$p" && printf '%s\n' "$p"
}

# Para o --lista e o status: descarta sem esperar o próximo comando. Só grava se houver candidata, e com a
# trava (ocupado: fica para a próxima leitura).
cerca_orfas_leitura() {
  grep -qs '^semPasta=true' "$efeitos_file" || return 0
  ( take_lock || exit 0; cerca_orfas_limpar ) || true
}

# Instância criada sem pasta e desfeita com Esc (o widget se remove): descarta. Com a pasta já escolhida
# (url no applet), deixa de ser candidata: dali em diante vale a regra de sempre.
cerca_orfas_limpar() {
  grep -qs '^semPasta=true' "$efeitos_file" || return 0
  local k ids
  qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || return 0
  widgets_geo_esquecer
  widgets_cfg_carregar
  local -a orfas=() prontas=()
  for k in $(widget_instancias_chaves cerca); do
    [[ $(widget_pref "$k" semPasta) == true ]] || continue
    ids=$(widget_applets "$k")
    [[ -n $ids ]] || continue
    if [[ $(widget_presentes_n "$k") == 0 ]]; then orfas+=("$k")
    elif [[ -n ${widgets_cfg[a${ids%%[[:space:]]*}:url]-} ]]; then prontas+=("$k"); fi
  done
  widgets_geo_esquecer
  for k in "${orfas[@]}"; do
    awk -F'\t' -v e="$k" '$1 != e' "$widgets_reg" >"$widgets_reg.novo"; mv -f -- "$widgets_reg.novo" "$widgets_reg"
    [[ -s $widgets_reg ]] || rm -f -- "${widgets_reg:?}"
    widget_prefs_apagar "$k"
  done
  for k in "${prontas[@]}"; do kwriteconfig6 --file "$efeitos_file" --group "widget-$k" --key semPasta --delete; done
}

# Unidades do systemd do usuário (desligadas por padrão): regras vigiando a Área de trabalho e snapshot
# por resolução ao mudar o monitor (o KWin regrava o kwinoutputconfig.json quando as telas mudam).
cerca_sd="$config/systemd/user"
cerca_desktop_dir() { local d; d=$(xdg-user-dir DESKTOP 2>/dev/null || true); [[ -n $d && $d != "$HOME" && $d != "$HOME/" ]] || d=$HOME/Desktop; printf '%s\n' "${d%/}"; }
cerca_unidade_gravar() {  # nome caminho-vigiado atraso argumentos-do-cyberkde
  put_file "$cerca_sd/$1.path" <<EOF
[Unit]
Description=CyberKDE: $1

[Path]
PathChanged=${2//%/%%}
TriggerLimitIntervalSec=10
TriggerLimitBurst=5

[Install]
WantedBy=default.target
EOF
  put_file "$cerca_sd/$1.service" <<EOF
[Unit]
Description=CyberKDE: $1

[Service]
Type=oneshot
ExecStartPre=/bin/sleep $3
ExecStart="$project/scripts/cyberkde" cerca $4
EOF
}
# Rodando como a fase widgets.
cerca_unidades_aplicar() {
  local mudou=0
  if [[ $(cerca_pref vigiar off) == on ]]; then
    cerca_unidade_gravar cyberkde-cerca-regras "$(cerca_desktop_dir)" 2 "regras aplicar --vigia"; mudou=1
  fi
  if [[ $(cerca_pref porResolucao off) == on ]]; then
    cerca_unidade_gravar cyberkde-cerca-telas "$config/kwinoutputconfig.json" 3 "snapshot auto"; mudou=1
  fi
  (( mudou )) || return 0
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  [[ $(cerca_pref vigiar off) != on ]] || systemctl --user enable --now cyberkde-cerca-regras.path >/dev/null 2>&1 || true
  [[ $(cerca_pref porResolucao off) != on ]] || systemctl --user enable --now cyberkde-cerca-telas.path >/dev/null 2>&1 || true
}
cerca_unidade_tirar() {  # nome
  local n=${1:?}
  systemctl --user disable --now "$n.path" >/dev/null 2>&1 || true
  rm -f -- "${cerca_sd:?}/$n.path" "${cerca_sd:?}/$n.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}
# "off": para antes de o registro apagar os arquivos das unidades (as escolhas ficam para o próximo "on").
cerca_unidades_parar() {
  [[ -e $cerca_sd/cyberkde-cerca-regras.path || -e $cerca_sd/cyberkde-cerca-telas.path ]] || return 0
  systemctl --user disable --now cyberkde-cerca-regras.path cyberkde-cerca-telas.path >/dev/null 2>&1 || true
}

# Opções globais (X-CyberKDE: "global"): o arquivo vazio cercas/<prefixo>.<id> é comum a todas as cercas e
# é o que o widget vigia; a chave de cada applet só acompanha.
cerca_global_prefixo() { case $1 in animacao) echo animacao ;; animacaoIcones) echo animicones ;; esac; }
widget_global_ler_cerca() {  # chave -> id em uso, ou nada
  local p f
  p=$(cerca_global_prefixo "$1")
  [[ -n $p ]] || return 0
  for f in "$cerca_dir/$p."*; do
    if [[ -e $f ]]; then printf '%s\n' "${f##*/$p.}"; return 0; fi
  done
}
widget_global_gravar_cerca() {  # chave id
  local p
  p=$(cerca_global_prefixo "$1")
  [[ -n $p ]] || return 0
  mkdir -p -- "$cerca_dir"
  find "$cerca_dir" -maxdepth 1 -name "$p.*" -delete
  : >"$cerca_dir/$p.$2"
}

# Hooks do widget_json e do widget_estado.
widget_opcoes_extra_cerca() {
  printf '%s' ',{"id":"atalhos","nome":"Atalhos globais","nome_en":"Global shortcuts","tipo":"escolha","padrao":"off","valores":[{"id":"off","nome":"Desligados","nome_en":"Off"},{"id":"on","nome":"Ligados","nome_en":"On"}]}'
  printf '%s' ',{"id":"atalho-nova","nome":"Atalho: nova cerca","nome_en":"Shortcut: new fence","tipo":"texto","padrao":"Meta+Shift+F","dica":"Ex.: Meta+Shift+F","dica_en":"E.g. Meta+Shift+F"}'
  printf '%s' ',{"id":"atalho-alternar","nome":"Atalho: mostrar ou ocultar","nome_en":"Shortcut: show or hide","tipo":"texto","padrao":"Meta+Shift+H","dica":"Ex.: Meta+Shift+H","dica_en":"E.g. Meta+Shift+H"}'
  printf '%s' ',{"id":"atalho-peek","nome":"Atalho: cercas por cima das janelas","nome_en":"Shortcut: fences above the windows","tipo":"texto","padrao":"Meta+Shift+Space","dica":"Ex.: Meta+Shift+Space; off: sem atalho","dica_en":"E.g. Meta+Shift+Space; off: no shortcut"}'
  printf ',{"id":"base","nome":"Pasta base","nome_en":"Base folder","tipo":"texto","padrao":%s,"dica":"Onde a nova cerca cria a pasta dela","dica_en":"Where a new fence creates its folder"}' "$(json_str "$(cerca_base)")"
  printf '%s' ',{"id":"vigiar","nome":"Organizar a Área de trabalho sozinho","nome_en":"Organize the desktop automatically","tipo":"escolha","padrao":"off","valores":[{"id":"off","nome":"Desligado","nome_en":"Off"},{"id":"on","nome":"Ligado","nome_en":"On"}]}'
  printf '%s' ',{"id":"por-resolucao","nome":"Restaurar o layout ao trocar de monitor","nome_en":"Restore the layout when the monitor changes","tipo":"escolha","padrao":"off","valores":[{"id":"off","nome":"Desligado","nome_en":"Off"},{"id":"on","nome":"Ligado","nome_en":"On"}]}'
}
widget_estado_extra_cerca() {
  printf ',"atalhos":"%s","atalho-nova":%s,"atalho-alternar":%s,"atalho-peek":%s,"base":%s,"cercasOcultas":%s,"peek":%s,"vigiar":"%s","por-resolucao":"%s"' \
    "$(cerca_pref atalhos off)" "$(json_str "$(cerca_pref atalhoNova "${cerca_candidatos_nova[0]}")")" \
    "$(json_str "$(cerca_pref atalhoAlternar "${cerca_candidatos_alternar[0]}")")" "$(json_str "$(cerca_pref atalhoPeek "${cerca_candidatos_peek[0]}")")" "$(json_str "$(cerca_base)")" \
    "$([[ -e $cerca_ocultas_arq ]] && echo true || echo false)" "$([[ -e $cerca_peek_arq ]] && echo true || echo false)" "$(cerca_pref vigiar off)" "$(cerca_pref porResolucao off)"
  cerca_py estado 2>/dev/null || true
}

# Visibilidade de todas as cercas: o arquivo é a fonte da verdade, e o widget o vigia.
cerca_visibilidade_aplicar() {  # true|false (true = ocultas)
  mkdir -p -- "$cerca_dir"
  if [[ $1 == true ]]; then : >"$cerca_ocultas_arq"; else rm -f -- "${cerca_ocultas_arq:?}"; fi
}

# O que o Plasma diz das cercas agora (JSON do cerca_cli.py).
cerca_ler() {
  widget_js 'var ds = desktops(), ps = panels(), r = {telas: [], cercas: []};
function ler(w) { var c = {};
  function andar(p) { w.currentConfigGroup = p; var ks = w.configKeys || [];
    for (var i = 0; i < ks.length; i++) c[p.join("/") + "|" + ks[i]] = w.readConfig(ks[i]);
    var gs = w.configGroups || []; for (var j = 0; j < gs.length; j++) andar(p.concat([gs[j]])); }
  andar([]); return c; }
for (var i = 0; i < ds.length; i++) { var d = ds[i]; if (d.screen < 0) continue;
  var g = screenGeometry(d.screen), o = {x: 0, y: 0};
  for (var p = 0; p < ps.length; p++) if (ps[p].screen == d.screen) { if (ps[p].location == "top") o.y += ps[p].height; else if (ps[p].location == "left") o.x += ps[p].height; }
  r.telas.push({tela: d.screen, d: d.id, off: o, largura: Math.round(g.width), altura: Math.round(g.height)});
  var ws = d.widgets();
  for (var j = 0; j < ws.length; j++) { var w = ws[j], q = w.geometry; if (w.type != "org.cyberkde.cerca" || !q) continue;
    r.cercas.push({applet: w.id, tela: d.screen, d: d.id, x: Math.round(q.x), y: Math.round(q.y), largura: Math.round(q.width), altura: Math.round(q.height), cfg: ler(w)}); } }
print(JSON.stringify(r));'
}
cerca_chave_telas() { cerca_py chave-telas 2>/dev/null || true; }

# Restaura um snapshot: quem mudou de lugar sai e entra; quem está no lugar só recebe a configuração; quem
# sumiu é recriado. Cerca que não está no snapshot fica como está. Antes, cópia datada do appletsrc.
cerca_restaurar() {  # nome
  local nome=$1 atual saidas plano config ids linha a id k t c appletsrc="$config/plasma-org.kde.plasma.desktop-appletsrc" bk
  [[ -f $cerca_dir/snapshots/$nome.json ]] || cor_exit 2 "$(t "snapshot desconhecido: $nome" "unknown snapshot: $nome")"
  atual=$(cerca_ler) || cor_exit 1 "$(t "o plasmashell não respondeu" "plasmashell did not respond")"
  saidas=$(cerca_py snap-plano "$nome" "$widgets_reg" <<<"$atual") || cor_exit 1 "$(t "snapshot inválido: $nome" "invalid snapshot: $nome")"
  mkdir -p -- "$cerca_dir/backups"
  bk="$cerca_dir/backups/appletsrc-$(date +%Y%m%d-%H%M%S)"
  [[ ! -f $appletsrc ]] || cp -a -- "$appletsrc" "$bk"
  plano=$(sed -n 1p <<<"$saidas"); config=$(sed -n 2p <<<"$saidas")
  while IFS= read -r linha; do
    [[ $linha == criar\ * ]] || continue
    read -r _ a k t c <<<"$linha"
    [[ $k != - ]] || k=$(widget_instancia_nova cerca)
    mkdir -p -- "$state"
    if [[ -s $widgets_reg ]]; then  # a linha velha da cerca que sumiu
      awk -F'\t' -v e="$k" '$1 != e' "$widgets_reg" >"$widgets_reg.novo"; mv -f -- "$widgets_reg.novo" "$widgets_reg"
    fi
    printf '%s\t%s\t%s\t%s\n' "$k" "$t" "$c" "$a" >>"$widgets_reg"
    kwriteconfig6 --file "$efeitos_file" --group "widget-$k" --key ligado true
  done <<<"$saidas"
  ids=$(python3 -c 'import json,sys; print(",".join(str(p["id"]) for p in json.loads(sys.argv[1]) if p.get("sai")))' "$plano")
  if [[ -n $ids ]]; then
    widget_js "var alvo = [$ids], ds = desktops(); for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (alvo.indexOf(ws[j].id) >= 0) ws[j].remove(); }" >/dev/null || true
    sleep 1
  fi
  [[ $plano == '[]' ]] || widgets_plano_por "$plano" '[]' '""' || cor_exit 1 "$(t "não consegui recolocar as cercas" "could not put the fences back")"
  if [[ $config != '{}' ]]; then
    widget_js "var cfg = $config, ds = desktops();
for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) { var c = cfg[String(ws[j].id)]; if (!c) continue;
  for (var k in c) { var p = k.split('|'); ws[j].currentConfigGroup = p[0] ? p[0].split('/') : []; ws[j].writeConfig(p[1], c[k]); }
  if (ws[j].reloadConfig) ws[j].reloadConfig(); } }" >/dev/null || true
  fi
  widgets_geo_esquecer
  bk_final=$bk
}

# "cyberkde widgets": ocultar e exibir todos os widgets do tema (CONTRATO-CLI.md). Sem trava nem registro:
# é preferência e estado de sessão, como "cerca alternar".
#   cyberkde widgets estado | ocultar|mostrar|alternar | gesto on|off | junto on|off | animacao <id>|cercas [--json]
widgets_anim_catalogo() {  # -> ids, um por linha, o padrão primeiro
  python3 -c 'import json, sys
l = json.load(open(sys.argv[1], encoding="utf-8"))
print("\n".join(v["id"] for v in sorted(l, key=lambda v: not v.get("padrao"))))' "$widgets_src/plasmoides/org.cyberkde.cerca/contents/animacoes.json" 2>/dev/null
}
widgets_ocultacao_responder() {
  local anim="cercas" efetiva f
  for f in "$widgets_estado_dir"/animacao.*; do
    if [[ -e $f ]]; then anim=${f##*/animacao.}; break; fi
  done
  efetiva=$anim
  if [[ $anim == cercas ]]; then
    efetiva=$(widget_global_ler_cerca animacao)
    [[ -n $efetiva ]] || efetiva=$(widgets_anim_catalogo | head -1)
  fi
  local j
  j=$(printf '{"ocultos":%s,"gesto":%s,"junto":%s,"animacao":%s,"animacaoEfetiva":%s}' \
    "$([[ -e $widgets_ocultos_arq ]] && echo true || echo false)" \
    "$([[ -e $widgets_estado_dir/gesto ]] && echo true || echo false)" \
    "$([[ -e $widgets_estado_dir/junto ]] && echo true || echo false)" \
    "$(json_str "$anim")" "$(json_str "$efetiva")")
  printf '%s\n' "$j" >&3
}
cmd_widgets() {
  local arg
  local -a a=()
  for arg in "$@"; do
    if [[ $arg == --json ]]; then cor_json=1; else a+=("$arg"); fi
  done
  if (( cor_json )); then exec 3>&1 1>&2; else exec 3>&1; fi
  local uso="cyberkde widgets estado|ocultar|mostrar|alternar | gesto on|off | junto on|off | animacao <id>|cercas [--json]"
  local sub=${a[0]:-estado} val=${a[1]:-} alvo
  (( ${#a[@]} <= 2 )) || cor_exit 2 "$(t uso usage): $uso"
  case $sub in
    estado) [[ -z $val ]] || cor_exit 2 "$(t uso usage): $uso" ;;
    ocultar | mostrar | alternar)
      [[ -z $val ]] || cor_exit 2 "$(t uso usage): $uso"
      mkdir -p -- "$widgets_estado_dir"
      case $sub in
        ocultar) alvo=true ;;
        mostrar) alvo=false ;;
        *)
          # Com "junto", os dois andam juntos a partir das cercas; separados, cada um tem seu estado.
          local ref=$widgets_ocultos_arq
          [[ ! -e $widgets_estado_dir/junto ]] || ref=$cerca_ocultas_arq
          if [[ -e $ref ]]; then alvo=false; else alvo=true; fi ;;
      esac
      if [[ $alvo == true ]]; then : >"$widgets_ocultos_arq"; else rm -f -- "${widgets_ocultos_arq:?}"; fi
      if [[ -e $widgets_estado_dir/junto ]]; then cerca_visibilidade_aplicar "$alvo"; fi ;;
    gesto | junto)
      [[ $val == on || $val == off ]] || cor_exit 2 "$(t uso usage): $uso"
      mkdir -p -- "$widgets_estado_dir"
      if [[ $val == on ]]; then : >"$widgets_estado_dir/$sub"; else rm -f -- "${widgets_estado_dir:?}/$sub"; fi ;;
    animacao)
      if [[ $val != cercas && ! $'\n'$(widgets_anim_catalogo)$'\n' == *$'\n'"$val"$'\n'* ]] || [[ -z $val ]]; then
        cor_exit 2 "$(t "animação desconhecida: $val" "unknown animation: $val")"
      fi
      mkdir -p -- "$widgets_estado_dir"
      find "$widgets_estado_dir" -maxdepth 1 -name 'animacao.*' -delete
      : >"$widgets_estado_dir/animacao.$val" ;;
    *) cor_exit 2 "$(t uso usage): $uso" ;;
  esac
  widgets_ocultacao_responder
}

if [[ -n ${widgets_f[cerca:1]-} ]]; then
  # Tira as opções do CLI e entrega o resto ao widget_cmd.
  efeito_cmd_widget-cerca() {
    local arg at="" an="" aa="" ap="" base="" vg="" pr="" nova=0 tem_pasta=0 titulo="" dono
    local -a resto=()
    cerca_orfas_leitura
    while (( $# )); do
      arg=$1; shift
      case $arg in
        --atalhos) at=${1:-}; shift || true; [[ $at == on || $at == off ]] || cor_exit 2 "$(t "--atalhos: on ou off" "--atalhos: on or off")" ;;
        --atalho-nova | --atalho-alternar)
          [[ $arg == --atalho-nova ]] && an=${1:-} || aa=${1:-}
          cerca_atalho_valido "${1:-}" || cor_exit 2 "$(t "atalho inválido (ex.: Meta+Shift+F): ${1:-}" "invalid shortcut (e.g. Meta+Shift+F): ${1:-}")"
          shift || true ;;
        --atalho-peek)
          ap=${1:-}
          [[ $ap == off ]] || cerca_atalho_valido "$ap" || cor_exit 2 "$(t "atalho inválido (ex.: Meta+Shift+Space, ou off): $ap" "invalid shortcut (e.g. Meta+Shift+Space, or off): $ap")"
          shift || true ;;
        --base) base=${1:-}; shift || true; base=${base/#\~/$HOME}
          [[ $base == /* ]] || cor_exit 2 "$(t "--base: um caminho absoluto ou ~/…" "--base: an absolute path or ~/…")" ;;
        --vigiar | --por-resolucao)
          [[ ${1:-} == on || ${1:-} == off ]] || cor_exit 2 "$(t "$arg: on ou off" "$arg: on or off")"
          if [[ $arg == --vigiar ]]; then vg=$1; else pr=$1; fi
          shift ;;
        --titulo) titulo=${1:-}; resto+=("$arg" "$titulo"); shift || true ;;
        *) [[ $arg == nova ]] && nova=1; [[ $arg == --pasta ]] && tem_pasta=1; resto+=("$arg") ;;
      esac
    done
    if [[ -n $vg$pr ]]; then
      take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
      [[ -z $vg ]] || cerca_pref_gravar vigiar "$vg"
      [[ -z $pr ]] || cerca_pref_gravar porResolucao "$pr"
      [[ $vg != off ]] || cerca_unidade_tirar cyberkde-cerca-regras
      [[ $pr != off ]] || cerca_unidade_tirar cyberkde-cerca-telas
      if [[ $vg == on || $pr == on ]]; then
        if widgets_ativo; then (fase_atual=widgets; cerca_unidades_aplicar)
        else widget_avisos_extra+=("$(t "O tema está desligado: vale no próximo cyberkde on." "The theme is off: it applies on the next cyberkde on.")"); fi
      fi
    fi
    if [[ -n $base ]]; then
      local bj
      bj=$(json_str "$base")
      cerca_pref_gravar base "$base"
      if qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
        widget_js "var ds = desktops(); for (var i = 0; i < ds.length; i++) { var ws = ds[i].widgets(); for (var j = 0; j < ws.length; j++) if (ws[j].type == 'org.cyberkde.cerca') { ws[j].currentConfigGroup = ['General']; ws[j].writeConfig('base', $bj); if (ws[j].reloadConfig) ws[j].reloadConfig(); } }" >/dev/null || true
      fi
    fi
    if [[ -n $at$an$aa$ap ]]; then
      take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
      local fn fa fp
      fn=${an:-$(cerca_pref atalhoNova)}; fa=${aa:-$(cerca_pref atalhoAlternar)}; fp=${ap:-$(cerca_pref atalhoPeek)}
      if [[ -n $ap && $ap != off ]]; then dono=$(cerca_dono "$ap"); [[ -z $dono ]] || cor_exit 2 "$(t "o atalho $ap já é de $dono" "shortcut $ap already belongs to $dono")"; fi
      if [[ -n $an ]]; then dono=$(cerca_dono "$an"); [[ -z $dono ]] || cor_exit 2 "$(t "o atalho $an já é de $dono" "shortcut $an already belongs to $dono")"; fi
      if [[ -n $aa ]]; then dono=$(cerca_dono "$aa"); [[ -z $dono ]] || cor_exit 2 "$(t "o atalho $aa já é de $dono" "shortcut $aa already belongs to $dono")"; fi
      # Sem escolha: o melhor par livre.
      if [[ -z $fn ]]; then
        fn=$(cerca_primeiro_livre "${cerca_candidatos_nova[@]}") || fn=""
      fi
      if [[ -z $fa ]]; then
        fa=$(cerca_primeiro_livre "${cerca_candidatos_alternar[@]}") || fa=""
      fi
      if [[ -z $fp ]]; then
        fp=$(cerca_primeiro_livre "${cerca_candidatos_peek[@]}") || fp=off
      fi
      [[ ( $fn != "$fa" || -z $fn ) && $fp != "$fn" && $fp != "$fa" ]] || cor_exit 2 "$(t "os atalhos não podem ser iguais" "the shortcuts cannot be the same")"
      cerca_pref_gravar atalhoPeek "$fp"
      if [[ $ap == off ]]; then
        cerca_gdbus unRegister "['$cerca_componente','Peek','','']" >/dev/null || true
        chave_restaurar kglobalshortcutsrc "services][$cerca_componente" Peek
      fi
      [[ -z $fn ]] || cerca_pref_gravar atalhoNova "$fn"
      [[ -z $fa ]] || cerca_pref_gravar atalhoAlternar "$fa"
      [[ -z $at ]] || cerca_pref_gravar atalhos "$at"
      if [[ -z $fn || -z $fa ]]; then
        cerca_pref_gravar atalhos off
        widget_avisos_extra+=("$(t "Nenhuma combinação livre para os atalhos: escolha com --atalho-nova e --atalho-alternar." "No free key combination for the shortcuts: pick them with --atalho-nova and --atalho-alternar.")")
      elif [[ $at == on && ( $fn != "${cerca_candidatos_nova[0]}" || $fa != "${cerca_candidatos_alternar[0]}" ) && -z $an$aa ]]; then
        widget_avisos_extra+=("$(t "Atalhos em uso: $fn e $fa." "Shortcuts in use: $fn and $fa.")")
      fi
      if [[ $at == off ]]; then
        cerca_tirar_ao_vivo
        chave_restaurar kglobalshortcutsrc "services][$cerca_componente" _launch
        chave_restaurar kglobalshortcutsrc "services][$cerca_componente" Nova
        chave_restaurar kglobalshortcutsrc "services][$cerca_componente" Alternar
        chave_restaurar kglobalshortcutsrc "services][$cerca_componente" Peek
        rm -f -- "$data/kglobalaccel/$cerca_componente"
      elif [[ $(cerca_pref atalhos off) == on ]]; then
        if widgets_ativo; then (fase_atual=widgets; cerca_atalhos_aplicar)
        else widget_avisos_extra+=("$(t "O tema está desligado: os atalhos valem no próximo cyberkde on." "The theme is off: the shortcuts apply on the next cyberkde on.")"); fi
      fi
    fi
    if (( nova )); then
      # A cerca lê a base do applet (Enter no título cria a pasta lá).
      widgets_criar_extra+="${widgets_criar_extra:+,}\"base\":$(json_str "$(cerca_base)")"
      local cf
      cf=$(arquivos_faltando_cerca | paste -sd' ' -)
      if [[ -n $cf ]]; then
        widget_avisos_extra+=("$(t "A Cyber Fence precisa de pacotes que faltam: sudo apt install $cf" "Cyber Fence needs missing packages: sudo apt install $cf")")
      fi
    fi
    if (( nova && ! tem_pasta && ! widgets_nova_sem_pasta )); then
      local pasta
      if [[ -n $titulo ]]; then pasta=$(cerca_pasta_titulo "$titulo") || pasta=""; else pasta=$(cerca_pasta_nova) || pasta=""; fi
      [[ -n $pasta ]] || cor_exit 1 "$(t "não consegui criar a pasta em $(cerca_base)" "could not create the folder in $(cerca_base)")"
      widgets_pasta_criada=$pasta
      resto+=(--pasta "$pasta")
    fi
    widget_cmd cerca "${resto[@]}"
  }

  arquivos_faltando_cerca() {  # pacotes dos módulos QML que o widget exige
    local m
    for m in Qt/labs/folderlistmodel:qml6-module-qt-labs-folderlistmodel QtQuick/Dialogs:qml6-module-qtquick-dialogs; do
      compgen -G "/usr/lib/*/qt6/qml/${m%%:*}/qmldir" >/dev/null || [[ -f /usr/lib/qt6/qml/${m%%:*}/qmldir ]] || echo "${m#*:}"
    done
  }

  #   cyberkde cerca nova [--titulo T] [--pasta P] [--json]   na tela sob o mouse. Sem título nem pasta: nasce
  #     com novaCerca=true e o widget pede o nome (Esc desfaz, e a instância órfã é descartada). Com
  #     título: cria <base>/<título>.
  #   cyberkde cerca pedir                                    (o atalho) a janela app/cerca-nome.py; sem ela, nova
  #   cyberkde cerca alternar|mostrar|ocultar [--json]        {"cercasOcultas":bool}
  #   cyberkde cerca peek [on|off|alternar] [--json]          {"peek":bool} (cercas por cima das janelas)
  #   cyberkde cerca regras ...                               ver "cyberkde cerca regras ajuda"
  #   cyberkde cerca snapshot salvar|listar|restaurar|apagar <nome> · snapshot auto (a unidade do systemd)
  #   cyberkde cerca backup · exportar <arquivo> · importar <arquivo> [--aplicar]
  cmd_cerca() {
    local sub="" arg
    local -a resto=()
    for arg in "$@"; do
      case $arg in
        --json) cor_json=1 ;;
        *) if [[ -z $sub ]]; then sub=$arg; else resto+=("$arg"); fi ;;
      esac
    done
    if (( cor_json )); then exec 3>&1 1>&2; else exec 3>&1; fi
    local jf=()
    (( ! cor_json )) || jf=(--json)
    case $sub in
      nova)
        local com_nome=0
        for arg in "${resto[@]}"; do [[ $arg == --titulo || $arg == --pasta ]] && com_nome=1; done
        if (( ! com_nome )); then widgets_criar_extra='"novaCerca":true'; widgets_nova_sem_pasta=1; fi
        widgets_resposta_curta=1
        widgets_criar_conector=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.activeOutputName 2>/dev/null || true)
        cerca_visibilidade_aplicar false
        efeito_cmd_widget-cerca nova "${resto[@]}" ;;
      pedir)
        if [[ -f $project/app/cerca-nome.py ]] && [[ -z $(painel_deps_faltando) ]]; then
          sem_travas setsid python3 "$project/app/cerca-nome.py" >/dev/null 2>&1 </dev/null &
        else
          cmd_cerca nova
        fi ;;
      alternar | mostrar | ocultar)
        (( ! ${#resto[@]} )) || cor_exit 2 "$(t "uso: cyberkde cerca nova|alternar|mostrar|ocultar [--json]" "usage: cyberkde cerca nova|alternar|mostrar|ocultar [--json]")"
        local v=true
        case $sub in
          mostrar) v=false ;;
          alternar) [[ -e $cerca_ocultas_arq ]] && v=false ;;
        esac
        cerca_visibilidade_aplicar "$v"
        if (( cor_json )); then printf '{"cercasOcultas":%s}\n' "$v" >&3; else echo "$(t "Cercas ocultas" "Fences hidden"): $v" >&3; fi ;;
      peek)
        local p=${resto[0]:-} agora=false
        [[ -e $cerca_peek_arq ]] && agora=true
        case $p in
          on) agora=true ;;
          off) agora=false ;;
          alternar) if [[ $agora == true ]]; then agora=false; else agora=true; fi ;;
          "") ;;
          *) cor_exit 2 "$(t "uso: cyberkde cerca peek [on|off|alternar] [--json]" "usage: cyberkde cerca peek [on|off|alternar] [--json]")" ;;
        esac
        mkdir -p -- "$cerca_dir"
        if [[ $agora == true ]]; then : >"$cerca_peek_arq"; else rm -f -- "${cerca_peek_arq:?}"; fi
        if (( cor_json )); then printf '{"peek":%s}\n' "$agora" >&3; else echo "Peek: $agora" >&3; fi ;;
      regras)
        # Destinos cerca:<id> saem da pasta de cada instância (lida do applet).
        local cj="{}"
        if [[ " ${resto[*]} " == *" aplicar "* ]] && grep -qsE '"cerca:|"autoCriarCerca": true' "$cerca_dir/regras.json"; then
          cj=$(widget_estado cerca | python3 -c 'import json,sys; print(json.dumps({i["id"]: i.get("pasta") for i in json.load(sys.stdin)["instancias"]}, ensure_ascii=False))')
        fi
        CERCAS_JSON=$cj cerca_py regras "${resto[@]}" "${jf[@]}" >&3
        # autoCriarCerca: uma cerca para o destino que ainda não tem.
        if [[ -s $cerca_dir/criar-cercas ]]; then
          local pc
          widgets_resposta_curta=1
          while IFS= read -r pc; do
            efeito_cmd_widget-cerca nova --pasta "$pc" 3>/dev/null || true
          done <"$cerca_dir/criar-cercas"
          rm -f -- "$cerca_dir/criar-cercas"
        fi ;;
      snapshot)
        local op=${resto[0]:-listar} nome=${resto[1]:-} js_atual
        case $op in
          listar) cerca_py snap-listar "${jf[@]}" >&3 ;;
          apagar) cerca_py snap-apagar "$nome" "${jf[@]}" >&3 ;;
          salvar)
            cerca_py nome-valido "$nome" "${jf[@]}" >&3
            js_atual=$(cerca_ler) || cor_exit 1 "$(t "o plasmashell não respondeu" "plasmashell did not respond")"
            cerca_py snap-gravar "$nome" "$widgets_reg" "$(cerca_chave_telas)" "${jf[@]}" <<<"$js_atual" >&3 ;;
          restaurar)
            cerca_py nome-valido "$nome" "${jf[@]}" >&3
            take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
            local bk_final=""
            cerca_restaurar "$nome"
            if (( cor_json )); then printf '{"restaurado":%s,"backup":%s}\n' "$(json_str "$nome")" "$(json_str "$bk_final")" >&3
            else echo "$(t "Restaurado; cópia do appletsrc em" "Restored; appletsrc copy at"): $bk_final" >&3; fi ;;
          auto)
            # Telas mudaram (a unidade do systemd): o snapshot mais novo desta combinação, se houver.
            local ch anterior="" alvo marca="$cerca_dir/telas-atual"
            ch=$(cerca_chave_telas)
            [[ -n $ch ]] || return 0
            [[ ! -s $marca ]] || anterior=$(<"$marca")
            [[ $ch != "$anterior" ]] || return 0
            printf '%s\n' "$ch" >"$marca"
            alvo=$(cerca_py snap-resolucao "$ch")
            if [[ -n $alvo ]] && take_lock; then local bk_final=""; cerca_restaurar "$alvo"; fi ;;
          *) cor_exit 2 "$(t "uso: cyberkde cerca snapshot salvar|listar|restaurar|apagar <nome>" "usage: cyberkde cerca snapshot salvar|listar|restaurar|apagar <name>")" ;;
        esac ;;
      backup | exportar)
        local arq=${resto[0]:-} js_atual
        if [[ $sub == backup ]]; then mkdir -p -- "$cerca_dir/backups"; arq="$cerca_dir/backups/cercas-$(date +%Y%m%d-%H%M%S).json"; fi
        [[ -n $arq ]] || cor_exit 2 "$(t "uso: cyberkde cerca exportar <arquivo>" "usage: cyberkde cerca exportar <file>")"
        js_atual=$(cerca_ler) || js_atual='{}'
        cerca_py exportar "$arq" "$widgets_reg" "$(cerca_chave_telas)" "${jf[@]}" <<<"$js_atual" >&3 ;;
      importar)
        local arq=${resto[0]:-} aplicar=0 r atual_n
        [[ ${resto[1]:-} != --aplicar ]] || aplicar=1
        [[ -f $arq ]] || cor_exit 2 "$(t "arquivo não encontrado: $arq" "file not found: $arq")"
        r=$(cerca_py importar "$arq" --json) || { printf '%s\n' "$r" >&3; exit 2; }
        if (( aplicar )); then
          atual_n=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("atual",""))' "$r")
          if [[ -n $atual_n ]]; then
            take_lock || cor_exit 3 "$(t "ocupado: outra execução do cyberkde está em andamento" "busy: another cyberkde run is in progress")"
            local bk_final=""
            cerca_restaurar "$atual_n"
          fi
        fi
        printf '%s\n' "$r" >&3 ;;
      *) cor_exit 2 "$(t "uso: cyberkde cerca nova|alternar|mostrar|ocultar|peek|regras|snapshot|backup|exportar|importar [--json]" "usage: cyberkde cerca nova|alternar|mostrar|ocultar|peek|regras|snapshot|backup|exportar|importar [--json]")" ;;
    esac
  }
fi
