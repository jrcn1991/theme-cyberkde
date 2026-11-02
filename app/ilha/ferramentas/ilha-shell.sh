# Comandos longos do shell viram atividade na pílula. A usuária carrega à mão (o tema NUNCA escreve no .zshrc):
#   source <tema>/app/ilha/ferramentas/ilha-shell.sh
_ilha_dir="${${(%):-%x}:A:h}"
_ilha_id=""
_ilha_antes() { _ilha_id="sh-$$-$EPOCHSECONDS"; _ilha_cmd="$1"; "$_ilha_dir/ilha-avisar.sh" --atividade "$_ilha_id" "${1[1,80]}" &!; }
_ilha_depois() {
  local r=$?
  [ -n "$_ilha_id" ] || return
  "$_ilha_dir/ilha-avisar.sh" --atividade "$_ilha_id" "${_ilha_cmd[1,80]}" "$([ $r = 0 ] && echo ok || echo erro)" "código $r" &!
  _ilha_id=""
}
autoload -Uz add-zsh-hook && zmodload zsh/datetime && add-zsh-hook preexec _ilha_antes && add-zsh-hook precmd _ilha_depois
