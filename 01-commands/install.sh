#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instalador dos comandos da aula: `up`, `qwe`, `projects`
#
# O que faz (idempotente — pode rodar de novo sem medo):
#   1. Garante Node.js ≥ 18 (instala se faltar: brew no macOS, nvm no Linux,
#      winget no Git Bash/Windows).
#   2. Instala o projects-picker (TUI Ink/React) em ~/.local/share/projects-picker
#      com `npm ci --omit=dev` (deps EXATAS do lockfile — nunca `npm install`).
#   3. Publica o comando `projects-picker` em ~/.local/bin.
#   4. Instala ~/.config/aula-dev/comandos.sh (up/qwe/projects) e o carrega
#      no ~/.zshrc e/ou ~/.bashrc via bloco marcado.
#
# Suporte: Linux, macOS, Windows via Git Bash (o instalador é .sh de propósito —
# no Windows, rode dentro do Git Bash; PowerShell puro não executa .sh).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"
PICKER_SRC="$PAYLOAD/projects-picker"
PICKER_DEST="$HOME/.local/share/projects-picker"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/aula-dev"

MARK_BEGIN="# >>> aula-dev (comandos da aula) >>>"
MARK_END="# <<< aula-dev (comandos da aula) <<<"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m⚠️ \033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

# Tudo aqui é por-usuário — rodar com sudo instalaria em /root em silêncio.
# Exceção consciente (container/WSL como root): AULA_PERMITIR_ROOT=1 ./install.sh
if [ "$(id -u)" -eq 0 ] && [ -z "${AULA_PERMITIR_ROOT:-}" ]; then
  fail "Não rode com sudo — o script pede sudo só onde precisa. (Root de verdade? AULA_PERMITIR_ROOT=1)"
fi

# Banner MUNDO DEV (desligue com MUNDO_DEV_BANNER=0)
if [ "${MUNDO_DEV_BANNER:-1}" != "0" ]; then
  cat <<'MDB'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
MDB
fi

# ── SO ───────────────────────────────────────────────────────────────────────
OS="desconhecido"
case "$(uname -s)" in
  Linux*)                 OS="linux" ;;
  Darwin*)                OS="macos" ;;
  MINGW*|MSYS*|CYGWIN*)   OS="windows-gitbash" ;;
esac
[ "$OS" = "desconhecido" ] && fail "Sistema não reconhecido: $(uname -s)"
info "Sistema detectado: $OS"

# ── Pré-requisito: git ───────────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  case "$OS" in
    linux)  fail "git não encontrado — instale com o gerenciador da distro (ex.: sudo apt install git)" ;;
    macos)  fail "git não encontrado — rode: xcode-select --install" ;;
    *)      fail "git não encontrado — instale o Git for Windows: winget install --id Git.Git -e" ;;
  esac
fi

# ── Node.js ≥ 18 ─────────────────────────────────────────────────────────────
node_major() { node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1; }

have_node() {
  command -v node >/dev/null 2>&1 || return 1
  # npm junto: o pacote `nodejs` do apt vem SEM npm — sem este check o
  # `npm ci` morreria com 127 no meio da instalação.
  command -v npm >/dev/null 2>&1 || return 1
  [ "$(node_major)" -ge 18 ] 2>/dev/null
}

if have_node; then
  ok "Node.js $(node -v) já presente (mínimo: 18)"
else
  info "Node.js ≥ 18 ausente — instalando…"
  case "$OS" in
    macos)
      command -v brew >/dev/null 2>&1 \
        || fail "Homebrew não encontrado. Instale-o (https://brew.sh) e rode este instalador de novo."
      brew install node
      ;;
    linux)
      # nvm: sem sudo, sem conflito de permissão (mesma receita da aula, §6.1)
      export NVM_DIR="$HOME/.nvm"
      if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
      fi
      # shellcheck disable=SC1091
      \. "$NVM_DIR/nvm.sh"
      nvm install 24
      nvm alias default 24
      ;;
    windows-gitbash)
      if command -v winget.exe >/dev/null 2>&1; then
        winget.exe install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements || true
        warn "Node instalado via winget — FECHE e REABRA o Git Bash e rode este instalador de novo."
        exit 0
      fi
      fail "Node.js ausente e winget indisponível — instale https://nodejs.org (LTS) e rode de novo."
      ;;
  esac
  have_node || fail "Node.js ainda indisponível nesta sessão — abra um terminal novo e rode o instalador de novo."
  ok "Node.js $(node -v) instalado"
fi

# ── projects-picker ──────────────────────────────────────────────────────────
info "Instalando projects-picker em $PICKER_DEST…"
mkdir -p "$PICKER_DEST/dist"
cp "$PICKER_SRC/package.json"      "$PICKER_DEST/package.json"
cp "$PICKER_SRC/package-lock.json" "$PICKER_DEST/package-lock.json"
cp "$PICKER_SRC/dist/index.js"     "$PICKER_DEST/dist/index.js"

# Regra de ouro: pins do package-lock.json são a fonte da verdade → `npm ci`.
# (react FICA no 18.3.1: o ink 5.2.1 usa react-reconciler com ABI do React 18 —
#  com React 19 o app quebra em runtime. Não "modernizar" um sem o outro.)
( cd "$PICKER_DEST" && npm ci --omit=dev --no-audit --no-fund )
ok "Dependências exatas do lockfile instaladas (npm ci)"

mkdir -p "$BIN_DIR"
if [ "$OS" = "windows-gitbash" ]; then
  # No MSYS, `ln -s` vira cópia silenciosa — wrapper é o caminho confiável.
  cat > "$BIN_DIR/projects-picker" <<'EOF'
#!/usr/bin/env bash
exec node "$HOME/.local/share/projects-picker/dist/index.js" "$@"
EOF
  chmod +x "$BIN_DIR/projects-picker"
else
  ln -sfn "$PICKER_DEST/dist/index.js" "$BIN_DIR/projects-picker"
  chmod +x "$PICKER_DEST/dist/index.js"
fi
ok "Comando projects-picker publicado em $BIN_DIR"

# NÃO criamos nenhuma pasta de projetos aqui de propósito. Qual é a sua pasta
# é uma PERGUNTA (feita mais abaixo, depois que o comandos.sh estiver no lugar),
# não um palpite — criar um ~/Projects na home de quem instala é exatamente o
# comportamento que este instalador evita.

# ── comandos.sh (up / qwe / projects) ────────────────────────────────────────
info "Instalando comandos em $CONF_DIR/comandos.sh…"
mkdir -p "$CONF_DIR"
cp "$PAYLOAD/comandos.sh" "$CONF_DIR/comandos.sh"

add_block() {  # $1 = arquivo rc
  local rc="$1"
  touch "$rc"
  if grep -qF "$MARK_BEGIN" "$rc"; then
    ok "Bloco aula-dev já presente em $rc"
    return 0
  fi
  {
    printf '\n%s\n' "$MARK_BEGIN"
    printf '[ -f "$HOME/.config/aula-dev/comandos.sh" ] && . "$HOME/.config/aula-dev/comandos.sh"\n'
    printf '%s\n' "$MARK_END"
  } >> "$rc"
  ok "Bloco aula-dev adicionado a $rc"
}

login_shell="$(basename "${SHELL:-}")"
case "$login_shell" in
  zsh)  add_block "$HOME/.zshrc" ;;
  bash) add_block "$HOME/.bashrc" ;;
  *)    add_block "$HOME/.bashrc"
        command -v zsh >/dev/null 2>&1 && add_block "$HOME/.zshrc" ;;
esac
# Cobre o outro shell se ele também existir na máquina (custo zero).
[ "$login_shell" = "zsh" ]  && [ -f "$HOME/.bashrc" ] && add_block "$HOME/.bashrc"
[ "$login_shell" = "bash" ] && command -v zsh >/dev/null 2>&1 && add_block "$HOME/.zshrc"

# macOS e Git Bash rodam bash como shell de LOGIN: leem ~/.bash_profile (se
# existir), não ~/.bashrc — garante o encadeamento nos dois.
if { [ "$OS" = "macos" ] || [ "$OS" = "windows-gitbash" ]; } && [ "$login_shell" = "bash" ]; then
  if [ -f "$HOME/.bash_profile" ] && ! grep -qs 'bashrc' "$HOME/.bash_profile"; then
    printf '\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> "$HOME/.bash_profile"
    # shellcheck disable=SC2088  # ~ literal numa mensagem para humano
    ok "~/.bash_profile agora carrega o ~/.bashrc (shell de login)"
  fi
fi

# ── Smoke tests ──────────────────────────────────────────────────────────────
info "Testando…"
# 1. Picker em modo --list (sem TUI): valida node + deps + código.
#    Aponta para um diretório TEMPORÁRIO: o teste não pode depender de o usuário
#    já ter configurado a pasta dele, nem tocar nela.
_smoke_dir="$(mktemp -d)"
if PROJECTS_DIR="$_smoke_dir" "$BIN_DIR/projects-picker" --list >/dev/null 2>&1; then
  ok "projects-picker --list respondeu"
else
  rmdir "$_smoke_dir" 2>/dev/null || true
  fail "projects-picker falhou no teste — veja o erro acima (node_modules incompleto?)"
fi
rmdir "$_smoke_dir" 2>/dev/null || true
# 2. comandos.sh carrega limpo em bash (sintaxe portátil).
if bash -c ". '$CONF_DIR/comandos.sh' && type qwe >/dev/null && type up >/dev/null && type projects >/dev/null"; then
  ok "comandos.sh carrega em bash (up/qwe/projects definidos)"
else
  fail "comandos.sh não carregou em bash"
fi
# 3. E em zsh, se existir.
if command -v zsh >/dev/null 2>&1; then
  if zsh -c ". '$CONF_DIR/comandos.sh' && whence -w qwe >/dev/null"; then
    ok "comandos.sh carrega em zsh"
  else
    fail "comandos.sh não carregou em zsh"
  fi
fi

# ── Pasta de projetos: PERGUNTAR, nunca adivinhar ───────────────────────────
# Reaproveita o _projects_setup do comandos.sh recém-instalado — fonte única:
# a mesma função que o `projects --setup` chama depois.
PROJ_CONF="$CONF_DIR/projects.conf"
echo
if [ -r "$PROJ_CONF" ]; then
  _atual="$(sed -n 's/^[[:space:]]*PROJECTS_DIR[[:space:]]*=[[:space:]]*//p' "$PROJ_CONF" \
            | tr -d '\r' | tail -n 1 | sed "s/^[\"']//; s/[\"']$//")"
  ok "Pasta de projetos já configurada: $_atual"
  info "Para trocar depois: projects --setup"
elif [ -t 0 ]; then
  info "Falta um passo: dizer QUAL pasta guarda os seus projetos."
  # `|| warn`: sob set -e, um setup abortado (Ctrl+C, 3 caminhos inválidos) não
  # pode derrubar o instalador depois de tudo já ter sido instalado.
  if bash -c ". '$CONF_DIR/comandos.sh' && _projects_setup"; then
    :
  else
    warn "Pasta de projetos não configurada — rode depois: projects --setup"
  fi
else
  warn "Sessão não interativa — configure a pasta depois com: projects --setup"
fi

echo
ok "Instalação concluída."
echo
echo "Próximo passo (1 min): abra um terminal NOVO (ou rode: source ~/.${login_shell:-bash}rc) e teste:"
echo "  1. projects        → seletor TUI da SUA pasta de projetos"
echo "                       (trocar a pasta: projects --setup)"
echo "  2. cd <um repo git> && qwe teste-aula   → cria worktree e entra"
echo "  3. up              → volta pro repo principal"
echo "Limpeza do teste: git worktree remove ../<repo>.worktrees/teste-aula && git branch -D teste-aula"
