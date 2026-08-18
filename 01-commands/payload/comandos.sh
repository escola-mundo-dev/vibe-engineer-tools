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

# ── projects ────────────────────────────────────────────────────────────────
# Seletor TUI (Ink/React) dos SEUS projetos — mais recente modificado primeiro,
# filtro por digitação, ↑↓ navega. Enter abre o projeto sob o cursor; Esc/Ctrl+C
# cancelam sem cd. O picker imprime o caminho no stdout e esta função faz o cd.
#
#   projects            abre o seletor
#   projects --setup    (re)configura QUAL pasta é a sua pasta de projetos
#   projects --help     ajuda
#
# ⚠️ NÃO existe pasta padrão. Onde ficam os seus projetos é CONFIGURAÇÃO, não
# palpite: o instalador pergunta o caminho absoluto e grava no projects.conf.
# Sem config, o `projects` chama o setup em vez de inventar uma pasta na sua home.
#
# Precedência: $PROJECTS_DIR (override pontual) > projects.conf.
#
# O conf é um arquivo SEPARADO de propósito — o instalador sobrescreve este
# comandos.sh a cada execução, e a sua configuração não pode morrer nisso.
_projects_conf() { printf '%s\n' "${PROJECTS_CONF:-$HOME/.config/aula-dev/projects.conf}"; }

# Lê o valor SEM dar `source`: o conf é config do usuário, não script — um
# source executaria o que estivesse lá e vazaria variáveis para o shell.
# `tr -d '\r'`: um clone no Windows com core.autocrlf=true entrega CRLF.
_projects_conf_read() {
  local conf
  conf="$(_projects_conf)"
  [ -r "$conf" ] || return 1
  sed -n 's/^[[:space:]]*PROJECTS_DIR[[:space:]]*=[[:space:]]*//p' "$conf" \
    | tr -d '\r' | tail -n 1 | sed "s/^[\"']//; s/[\"']\$//"
}

_projects_dir() {
  local d
  if [ -n "${PROJECTS_DIR:-}" ]; then printf '%s\n' "$PROJECTS_DIR"; return 0; fi
  d="$(_projects_conf_read)" || return 1
  [ -n "$d" ] || return 1
  printf '%s\n' "$d"
}

# Setup interativo — usado pelo `projects --setup` E pelo instalador.
_projects_setup() {
  local conf dir tentativa
  conf="$(_projects_conf)"

  # Sem terminal (script, cron, agente), perguntar é impossível — falha curta
  # em vez de despejar o prompt inteiro num `read` que já nasce morto.
  if [ ! -t 0 ]; then
    echo "projects: sem terminal para perguntar a pasta." >&2
    echo "          Rode \`projects --setup\` num terminal, ou use PROJECTS_DIR=/caminho." >&2
    return 1
  fi

  cat >&2 <<'EOF'
── Qual é a SUA pasta de projetos? ──

Informe o CAMINHO ABSOLUTO da pasta onde VOCÊ guarda seus repositórios.
Ela não é criada por padrão e não é adivinhada: é escolha sua.

Como descobrir o caminho, se não souber de cabeça:
  · abra outro terminal, entre na pasta (cd ...) e rode:  pwd
  · ou arraste a pasta para dentro da janela do terminal — ele cola o caminho
  · Git Bash no Windows: use a forma que o `pwd` mostra (/c/Users/voce/...),
    não a forma C:\Users\voce\...

Se errar agora, sem problema: rode `projects --setup` depois para reconfigurar.

EOF

  for tentativa in 1 2 3; do
    printf 'Caminho absoluto da sua pasta de projetos: ' >&2
    IFS= read -r dir || return 1

    # Aspas/espaços do drag-and-drop e do autocomplete do terminal.
    dir="${dir%\"}"; dir="${dir#\"}"
    dir="${dir%\'}"; dir="${dir#\'}"
    dir="${dir%/}"                       # barra final não muda a pasta
    [ -z "$dir" ] && { echo "vazio — tente de novo" >&2; continue; }

    # `~` e `~/x` não expandem quando vêm de um `read` — o til chega literal.
    # shellcheck disable=SC2088  # é exatamente esse literal que queremos casar
    case "$dir" in
      "~")   dir="$HOME" ;;
      "~/"*) dir="$HOME/${dir#\~/}" ;;
    esac

    case "$dir" in
      [A-Za-z]:\\*|[A-Za-z]:/*)
        echo "Isso é um caminho do Windows. No Git Bash use a forma do \`pwd\`: /c/Users/... " >&2
        continue ;;
      /*) : ;;
      *)  echo "O caminho precisa ser ABSOLUTO (começar com /). Rode \`pwd\` dentro da pasta." >&2
          echo "(tentativa $tentativa de 3)" >&2
          continue ;;
    esac

    if [ ! -d "$dir" ]; then
      printf 'A pasta %s não existe. Criar agora? [s/N]: ' "$dir" >&2
      local resp; IFS= read -r resp || return 1
      case "$resp" in
        s|S|y|Y) mkdir -p "$dir" || { echo "não consegui criar $dir" >&2; continue; } ;;
        *)       echo "ok, então informe outra pasta." >&2; continue ;;
      esac
    fi

    # Grava o caminho FÍSICO: se o usuário digitou um symlink, o picker e o
    # `cd` concordam depois (mesma normalização que o `up` faz).
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || { echo "não consegui entrar em $dir" >&2; continue; }

    mkdir -p "$(dirname "$conf")" || return 1
    {
      printf '# projects.conf — a SUA pasta de projetos (lido por `projects`)\n'
      printf '# Reconfigure a qualquer momento com: projects --setup\n'
      printf 'PROJECTS_DIR="%s"\n' "$dir"
    } > "$conf" || return 1

    echo "✅ pasta de projetos: $dir" >&2
    echo "   gravado em $conf (mude com: projects --setup)" >&2
    return 0
  done

  echo "projects: não consegui um caminho válido — nada foi gravado." >&2
  echo "          Rode \`projects --setup\` quando quiser configurar." >&2
  return 1
}

projects() {
  case "${1:-}" in
    --setup|-s)
      _mundo_dev_banner
      _projects_setup
      return $? ;;
    -h|--help)
      cat >&2 <<'EOF'
projects — seletor TUI dos seus projetos

  projects           abre o seletor (↑↓ navega · digite para filtrar ·
                     Enter abre · Esc cancela)
  projects --setup   (re)configura qual pasta é a sua pasta de projetos
  projects --help    esta ajuda

A pasta fica em ~/.config/aula-dev/projects.conf.
Override pontual, sem gravar nada:  PROJECTS_DIR=/outro/caminho projects
EOF
      return 0 ;;
  esac

  _mundo_dev_banner
  local dir d
  if ! dir="$(_projects_dir)"; then
    echo "projects: nenhuma pasta de projetos configurada ainda." >&2
    _projects_setup || return 1
    dir="$(_projects_dir)" || return 1
  fi
  if [ ! -d "$dir" ]; then
    echo "projects: a pasta configurada não existe mais: $dir" >&2
    echo "          Reconfigure com: projects --setup" >&2
    return 1
  fi
  d="$(PROJECTS_DIR="$dir" projects-picker)" || return $?
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
