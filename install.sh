#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — roda os quatro instaladores na ordem recomendada.
#
#   ./install.sh              todos, na ordem 01 → 02 → 03 → 04
#   ./install.sh 01 03        só os que você listar (na ordem que você listar)
#   ./install.sh --list       mostra o que existe e sai
#
# Cada instalador é independente e idempotente — este script só evita o
# `cd pasta && ./install.sh && cd ..` quatro vezes. Se um falhar, os
# anteriores continuam valendo e o roteiro para ali (nada é desfeito).
#
# Windows: rode dentro do Git Bash. Para PowerShell nativo, chame
# 03-deepclaude\install.ps1 e 04-agent-tools\install.ps1 direto.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

# Ordem recomendada. 01 vem primeiro porque instala o Node — de que o 04 depende.
ALL="01-commands 02-ghostty 03-deepclaude 04-agent-tools"

if [ "${1:-}" = "--list" ]; then
  # `-f`, não `-x`: um clone que perdeu o bit de execução (download em zip,
  # Windows, `core.fileMode false`) ainda instala — este script chama
  # `bash "$script"`. Filtrar por -x aqui esconderia todos eles.
  for d in $ALL; do
    [ -f "$SCRIPT_DIR/$d/install.sh" ] && printf '%s\n' "$d"
  done
  exit 0
fi

# Sem argumentos = todos. Com argumentos, aceita o prefixo numérico (`01`)
# ou o nome completo da pasta (`01-commands`).
SELECAO=""
if [ $# -eq 0 ]; then
  SELECAO="$ALL"
else
  for arg in "$@"; do
    encontrado=""
    for d in $ALL; do
      case "$d" in
        "$arg"|"$arg"-*) encontrado="$d"; break ;;
      esac
    done
    [ -n "$encontrado" ] || fail "Instalador desconhecido: '$arg' (veja: ./install.sh --list)"
    SELECAO="$SELECAO $encontrado"
  done
fi

# Banner MUNDO DEV uma vez só; os filhos herdam o desligamento.
if [ "${MUNDO_DEV_BANNER:-1}" != "0" ]; then
  cat <<'MDB'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
MDB
fi
export MUNDO_DEV_BANNER=0

for d in $SELECAO; do
  script="$SCRIPT_DIR/$d/install.sh"
  [ -f "$script" ] || fail "Não encontrei $script"
  printf '\n\033[1;35m━━━ %s ━━━\033[0m\n' "$d"
  # `bash "$script"` em vez de `./install.sh`: funciona mesmo num clone que
  # perdeu o bit de execução (zip, Windows, `git config core.fileMode false`).
  ( cd "$SCRIPT_DIR/$d" && bash "$script" ) || fail "$d falhou — corrija e rode de novo: ./install.sh $d"
  ok "$d concluído"
done

echo
ok "Tudo pronto. Abra um terminal NOVO e teste:"
cat <<'EOF'
  projects                 seletor TUI dos seus projetos
  qwe minha-tarefa         worktree isolada (com -a deepclaude sobe o agente)
  up                       volta da worktree pro repo principal
  deepeco                  a janela de economia da DeepSeek está aberta agora?
  gitcraque                cliente Git de desktop no navegador
EOF
