# modules/cursor/phase.sh — tema de cursor CyberKDE: seta chanfrada, mão, I-beam, espera animada,
# redimensionar, proibido, cruz, ajuda, link... com cantoneiras e o destaque do tema, em 3 variantes
# (padrao, neon, minimo e mira). Gerado por generator/gen_cursor.py (xcursorgen; 24, 32, 48 e 64 px).
# Carregado com "source" pelo scripts/cyberkde: só define funções e registra nomes.
#
# Fase OPCIONAL (fora do "cyberkde on" de tudo): "cyberkde on cursor" liga, "cyberkde off cursor" devolve
# o cursor de antes. A variante é uma preferência, em ~/.config/cyberkde/efeitos:
#   [cursor]
#   variante=padrao|neon|minimo|mira
# Instala as quatro variantes (padrao, neon, minimo e mira; a mira troca o ponteiro por uma mira fina
# e a mão ganha colchetes que fecham em 80 ms) em ~/.local/share/icons/CyberKDE-cursor[-neon|-minimo|-mira] (todas, para a troca
# de variante ser só gravar a chave e aplicar) e aplica a escolhida com o plasma-apply-cursortheme.

CYBERKDE_FASES_OPCIONAIS+=(cursor)
descreve_fase cursor "Cursor" sistema nao "Cursores cyberpunk com cantoneiras e o destaque do tema, em 4 variantes (padrão, neon, mínimo, mira)." \
  "Cursor" "Cyberpunk cursors with corner brackets and the theme accent, in 4 variants (default, neon, minimal, crosshair)."
CYBERKDE_INSTALLS+=(install_cursor)
CYBERKDE_OFF_HOOKS+=(off_cursor)

cursor_efeitos_file="$config/cyberkde/efeitos"
cursor_build="$project/modules/cursor/build"
cursor_variantes=(padrao neon minimo mira)

# Variante escolhida (padrao se a chave não existe ou não é uma das três).
cursor_variante() {
  local v
  v=$(kreadconfig6 --file "$cursor_efeitos_file" --group cursor --key variante --default padrao 2>/dev/null)
  case $v in padrao | neon | minimo | mira) printf '%s\n' "$v" ;; *) echo padrao ;; esac
}

# Nome do tema (e da pasta em ~/.local/share/icons) de uma variante.
cursor_tema_nome() {  # variante
  if [[ $1 == padrao ]]; then echo CyberKDE-cursor; else echo "CyberKDE-cursor-$1"; fi
}

# Gera de novo só quando a paleta (cyberkde cor/corp) ou o gerador mudou.
cursor_gerar() {
  local gen="$project/modules/cursor/generator/gen_cursor.py" v
  if [[ -s $cursor_build/.carimbo && $(cat "$cursor_build/.carimbo") == "$(python3 "$gen" --carimbo)" ]]; then
    for v in "${cursor_variantes[@]}"; do [[ -d $cursor_build/$v/theme/cursors ]] || { python3 "$gen" --saida "$cursor_build" >/dev/null; return; }; done
    return 0
  fi
  python3 "$gen" --saida "$cursor_build" >/dev/null
}

# Com a fase ligada, um "cyberkde on"/"cor" que reinstala os arquivos atualiza também os cursores
# (a paleta pode ter mudado). Desligada, não gasta os ~20 s da geração.
install_cursor() {
  fase_ligada cursor || return 0
  cursor_gerar
  local v
  for v in "${cursor_variantes[@]}"; do
    rm -rf -- "${data:?}/icons/$(cursor_tema_nome "$v")"
    mkdir -p -- "$data/icons"
    cp -r --preserve=mode,timestamps -- "$cursor_build/$v/theme" "$data/icons/$(cursor_tema_nome "$v")"
  done
}

# Grava e aplica a variante escolhida (rodando como a fase "cursor"): o set_key anota o valor de antes
# para o "off". Serve também ao "cyberkde efeito cursor <variante>" quando a fase já está ligada.
efeito_cursor_aplicar() {
  local nome
  nome=$(cursor_tema_nome "$(cursor_variante)")
  [[ -d $data/icons/$nome/cursors ]] || return 0  # variante ainda não instalada: o próximo "on cursor" instala
  set_key kcminputrc Mouse cursorTheme "$nome"
  command -v plasma-apply-cursortheme >/dev/null 2>&1 && plasma-apply-cursortheme "$nome" >/dev/null 2>&1 || true
}

phase_cursor() {
  cursor_gerar
  local v
  for v in "${cursor_variantes[@]}"; do
    put_dir "$cursor_build/$v/theme" "$data/icons/$(cursor_tema_nome "$v")"
  done
  mkdir -p -- "$state" && touch "$state/cursor-aplicado"
  efeito_cursor_aplicar
}

# O registro já devolveu o kcminputrc e removeu as pastas; falta o Plasma trocar o cursor em uso.
off_cursor() {
  [[ -e $state/cursor-aplicado ]] || return 0  # a fase nunca rodou: não mexe no cursor
  rm -f -- "$state/cursor-aplicado"
  command -v plasma-apply-cursortheme >/dev/null 2>&1 || return 0
  plasma-apply-cursortheme "$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme --default breeze_cursors)" >/dev/null 2>&1 || true
}
