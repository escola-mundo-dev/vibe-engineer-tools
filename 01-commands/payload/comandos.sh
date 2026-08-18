# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# comandos.sh — comandos da aula: `up`, `qwe`, `projects`
# Instalado em: ~/.config/aula-dev/comandos.sh   (fonte: 01-commands/payload)
# Carregado pelo ~/.zshrc e/ou ~/.bashrc via bloco "aula-dev".
#
# Compatível com zsh E bash (Linux, macOS e Git Bash no Windows): nada de
# sintaxe exclusiva de um shell — prompt de leitura é `printf` + `read -r`,
# sem arrays, sem `read "var?prompt"`.
# ─────────────────────────────────────────────────────────────────────────────

# ~/.local/bin no PATH (onde moram projects-picker, deepclaude, deepeco)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# Banner MUNDO DEV (estilo "future" do toilet) — abre todos os comandos da
# aula. Vai para o STDERR para nunca sujar stdout (o `projects`, por exemplo,
# captura stdout do picker). Desligue com MUNDO_DEV_BANNER=0.
_mundo_dev_banner() {
  [ "${MUNDO_DEV_BANNER:-1}" = "0" ] && return 0
  cat >&2 <<'MDB'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
MDB
}

# projects: seletor TUI (Ink/React) dos projetos em ~/Projects — mais recente
# modificado primeiro, filtro por digitação, ↑↓ navega. Enter abre o projeto
# sob o cursor; Enter com a lista vazia (filtro sem match) cai em ~/Projects;
# Esc/Ctrl+C cancelam sem cd. O picker imprime o caminho e esta função cd.
# Projetos em outro lugar? `export PROJECTS_DIR=/caminho` resolve sem tocar código.
projects() {
  _mundo_dev_banner
  local d
  d="$(projects-picker)" || return $?
  cd -- "$d" || return 1
}

# up: sai da worktree e volta pro repo principal.
#   Dentro de uma worktree (qwe/gwt)        → cd na raiz do repo PRINCIPAL.
#   Dentro do repo principal, em subpasta   → cd na raiz do repo.
#   Já na raiz do principal, ou fora de git → cd .. (sobe um nível).
# O principal é sempre a 1ª entrada de `git worktree list --porcelain` (garantia
# do git), e não `--git-common-dir`, que devolve caminho RELATIVO em subpasta.
up() {
  _mundo_dev_banner
  local main
  main="$(git worktree list --porcelain 2>/dev/null \
          | awk '/^worktree /{print substr($0, 10); exit}')"
  # Normaliza os dois lados antes de comparar: no Git Bash o git imprime
  # C:/Users/... e o $PWD é /c/Users/... (nunca seriam iguais); no macOS um
  # cwd com symlink (/tmp → /private/tmp) diverge do caminho físico do git.
  # `cd` + `pwd -P` resolve os dois casos.
  [ -n "$main" ] && main="$(cd "$main" 2>/dev/null && pwd -P)"
  if [ -n "$main" ] && [ "$(pwd -P)" != "$main" ]; then
    cd "$main" || return 1
    return 0
  fi
  cd .. || return 1
}

# qwe: cria uma worktree do repo atual, entra nela e sobe um agente —
#      SÓ SE você passar `-a <conta>`. Sem conta, é "cria e entra".
#        qwe                          → pergunta a branch, cria e entra
#        qwe minha-branch             → cria direto e entra (o nome é a flag)
#        qwe minha-branch -a deepclaude → idem + sobe o Claude Code com DeepSeek
#        qwe -a claude                → pergunta a branch + sobe o Claude oficial
#        CLAUDE_CONTA=deepclaude qwe  → idem ao -a, via env
# Contas nesta versão de aula: `deepclaude` (instalador 03) e `claude` (oficial).
qwe() {
  _mundo_dev_banner
  local conta="" branch="" repo_root parent_branch worktrees_dir worktree_path default_branch
  while [ $# -gt 0 ]; do
    case "$1" in
      -a|--conta|--account)
        if [ $# -lt 2 ]; then echo "qwe: a flag $1 exige um valor" >&2; return 1; fi
        conta="$2"; shift 2 ;;
      --conta=*|--account=*) conta="${1#*=}"; shift ;;
      *) [ -z "$branch" ] && branch="$1"; shift ;;
    esac
  done
  [ -z "$conta" ] && [ -n "${CLAUDE_CONTA:-}" ] && conta="$CLAUDE_CONTA"

  # Resolve a conta ANTES de criar a worktree: conta inválida (ou launcher
  # ausente) falha aqui, sem deixar branch nem diretório órfão para trás.
  case "$conta" in
    "") : ;;
    deepclaude)
      if ! command -v deepclaude >/dev/null 2>&1; then
        echo "qwe: 'deepclaude' não encontrado — rode o instalador 03-deepclaude" >&2
        return 1
      fi ;;
    claude)
      if ! command -v claude >/dev/null 2>&1; then
        echo "qwe: 'claude' não encontrado — instale o Claude Code" >&2
        return 1
      fi ;;
    *)
      echo "qwe: conta desconhecida '$conta' — nesta versão use 'deepclaude' ou 'claude'" >&2
      return 1 ;;
  esac

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$repo_root" ]; then
    echo "Erro: você não está dentro de um repositório Git." >&2
    return 1
  fi

  default_branch="ai-task-$(date +%s)"
  if [ -z "$branch" ]; then
    # Sem argumento: pergunta interativamente. Enter vazio usa o default.
    while true; do
      printf 'Nome da branch [%s]: ' "$default_branch" >&2
      read -r branch || return 1
      [ -z "$branch" ] && branch="$default_branch"
      if git check-ref-format "refs/heads/$branch" >/dev/null 2>&1; then
        break
      fi
      echo "Nome de branch inválido: '$branch'. Tente de novo." >&2
      branch=""
    done
  else
    if ! git check-ref-format "refs/heads/$branch" >/dev/null 2>&1; then
      echo "Nome de branch inválido: '$branch'." >&2
      return 1
    fi
  fi

  if [ -n "$conta" ]; then
    echo "Criando worktree: $branch   (conta: $conta)"
  else
    echo "Criando worktree: $branch   (sem agente)"
  fi

  parent_branch="$(git branch --show-current)"
  worktrees_dir="$(dirname "$repo_root")/$(basename "$repo_root").worktrees"
  worktree_path="$worktrees_dir/$branch"

  mkdir -p "$worktrees_dir" || return 1
  git worktree add -b "$branch" "$worktree_path" || return 1

  # Rastro para o fechamento manual depois: de onde a branch veio.
  git config branch."$branch".origdir "$repo_root"
  git config branch."$branch".origbranch "$parent_branch"

  cd "$worktree_path" || return 1

  # Sem conta: missão cumprida — já está dentro da worktree (sem agente).
  [ -n "$conta" ] || return 0

  case "$conta" in
    deepclaude)
      # Toda a env (endpoint, chave, pins de modelo) mora no launcher
      # `deepclaude` — fonte única. Não recrie os pins aqui.
      deepclaude ;;
    claude)
      claude --dangerously-skip-permissions --effort max ;;
  esac
}
