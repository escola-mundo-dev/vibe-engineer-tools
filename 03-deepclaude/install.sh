#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instalador do `deepclaude` (Claude Code com cérebro DeepSeek)
#              + `deepeco` (janela de economia) + slash command /eco
#
# O que faz (idempotente):
#   1. Garante o Claude Code (instalador nativo oficial; fallback npm).
#   2. Instala `deepclaude` e `deepeco` em ~/.local/bin.
#   3. Instala o /eco (slash command) em ~/.claude-deepseek/commands/eco.md
#      e a config da janela em ~/.config/aula-dev/deepeco.conf.
#   4. Pede a chave DeepSeek, VALIDA na API (GET /user/balance — não gasta
#      tokens) e grava globalmente em ~/.claude-deepseek/deepseek.key (600).
#
# Suporte: Linux, macOS e Windows via Git Bash. Para PowerShell nativo no
# Windows, use o install.ps1 desta mesma pasta.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"
BIN_DIR="$HOME/.local/bin"
DC_DIR="$HOME/.claude-deepseek"
CONF_DIR="$HOME/.config/aula-dev"
STAMP="$(date +%Y%m%d-%H%M%S)"

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

OS="desconhecido"
case "$(uname -s)" in
  Linux*)               OS="linux" ;;
  Darwin*)              OS="macos" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows-gitbash" ;;
esac
[ "$OS" = "desconhecido" ] && fail "Sistema não reconhecido: $(uname -s)"
info "Sistema detectado: $OS"

mkdir -p "$BIN_DIR"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) PATH="$BIN_DIR:$PATH" ;; esac

# Persiste ~/.local/bin no PATH das sessões novas (bloco marcado, idempotente).
# Sem isso, deepclaude/deepeco só existiriam na sessão do instalador.
MARK_PATH_BEGIN="# >>> aula-dev (PATH ~/.local/bin) >>>"
_persistir_path() {  # $1 = arquivo rc
  local rc="$1"
  touch "$rc"
  grep -qF "$MARK_PATH_BEGIN" "$rc" && return 0
  {
    printf '\n%s\n' "$MARK_PATH_BEGIN"
    # shellcheck disable=SC2016
    printf 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac\n'
    printf '# <<< aula-dev (PATH ~/.local/bin) <<<\n'
  } >> "$rc"
  ok "PATH persistido em $rc"
}
case "$(basename "${SHELL:-}")" in
  zsh)  _persistir_path "$HOME/.zshrc" ;;
  *)    _persistir_path "$HOME/.bashrc"
        command -v zsh >/dev/null 2>&1 && _persistir_path "$HOME/.zshrc" ;;
esac

# ── 1. Claude Code ───────────────────────────────────────────────────────────
if command -v claude >/dev/null 2>&1; then
  ok "Claude Code já instalado: $(claude --version 2>/dev/null | head -n1)"
else
  info "Instalando o Claude Code (instalador nativo oficial)…"
  if curl -fsSL https://claude.ai/install.sh | bash; then
    ok "Claude Code instalado (nativo)"
  elif command -v npm >/dev/null 2>&1; then
    warn "Instalador nativo falhou — tentando via npm…"
    npm install -g @anthropic-ai/claude-code
  else
    if [ "$OS" = "windows-gitbash" ]; then
      fail "Não consegui instalar o Claude Code — rode no PowerShell: irm https://claude.ai/install.ps1 | iex   (ou use o install.ps1 desta pasta)"
    fi
    fail "Não consegui instalar o Claude Code — instale Node.js (instalador 01) e rode de novo, ou veja https://code.claude.com/docs"
  fi
  command -v claude >/dev/null 2>&1 \
    || fail "claude ainda fora do PATH nesta sessão — abra um terminal novo e rode o instalador de novo."
fi

# ── 2. deepclaude + deepeco ──────────────────────────────────────────────────
info "Instalando deepclaude e deepeco em $BIN_DIR…"
install -m 755 "$PAYLOAD/deepclaude" "$BIN_DIR/deepclaude"
install -m 755 "$PAYLOAD/deepeco"    "$BIN_DIR/deepeco"
ok "Comandos publicados: deepclaude, deepeco"

# ── 3. /eco + deepeco.conf ───────────────────────────────────────────────────
mkdir -p "$DC_DIR/commands" && chmod 700 "$DC_DIR"
cp "$PAYLOAD/eco.md" "$DC_DIR/commands/eco.md"
ok "Slash command /eco instalado (use DENTRO do deepclaude)"

mkdir -p "$CONF_DIR"
if [ -f "$CONF_DIR/deepeco.conf" ] && ! cmp -s "$PAYLOAD/deepeco.conf" "$CONF_DIR/deepeco.conf"; then
  cp "$CONF_DIR/deepeco.conf" "$CONF_DIR/deepeco.conf.bak-$STAMP"
  warn "deepeco.conf existente era diferente — backup em deepeco.conf.bak-$STAMP"
fi
cp "$PAYLOAD/deepeco.conf" "$CONF_DIR/deepeco.conf"
ok "Janela de economia configurada em $CONF_DIR/deepeco.conf"

# ── 4. Chave DeepSeek: validar a existente ou pedir uma ─────────────────────
_chave_valida() {  # $1 = chave → 0 se a API aceitar
  local http
  http="$(curl -sS -o /dev/null -w '%{http_code}' \
          -H "Authorization: Bearer $1" \
          https://api.deepseek.com/user/balance 2>/dev/null || echo 000)"
  [ "$http" = "200" ]
}

if [ -r "$DC_DIR/deepseek.key" ]; then
  info "Chave já gravada — validando na API…"
  if _chave_valida "$(head -n1 "$DC_DIR/deepseek.key")"; then
    ok "Chave existente é válida — mantida"
  else
    warn "A chave gravada NÃO validou (revogada? sem rede?) — refazendo o setup."
    if [ -t 0 ]; then
      # `|| warn`: sob set -e, um setup abortado (3 chaves erradas, Ctrl+C)
      # não pode derrubar o instalador depois de tudo já instalado.
      "$BIN_DIR/deepclaude" --setup-key || warn "Setup da chave não concluiu — rode depois: deepclaude --setup-key"
    else
      warn "Sessão não interativa — rode depois: deepclaude --setup-key"
    fi
  fi
else
  if [ -t 0 ]; then
    "$BIN_DIR/deepclaude" --setup-key || warn "Setup da chave não concluiu — rode depois: deepclaude --setup-key"
  else
    warn "Sessão não interativa — rode depois: deepclaude --setup-key"
  fi
fi

# ── 5. Smoke tests ───────────────────────────────────────────────────────────
info "Testando…"
"$BIN_DIR/deepeco" >/dev/null && ok "deepeco responde"
"$BIN_DIR/deepclaude" --help >/dev/null && ok "deepclaude --help responde"

echo
ok "Instalação concluída."
cat <<'EOF'

Como usar (2 min):
  1. deepeco                → a janela de economia está aberta agora?
  2. cd <um projeto> && deepclaude
       · o banner do deepeco aparece ao subir
       · /status mostra o endpoint DeepSeek mapeado
       · /eco   mostra a janela de economia sem sair da sessão
       · /model fable ⇆ /model sonnet troca V4 Pro ⇆ V4 Flash sem reiniciar
  3. deepclaude --pro       → sessão inteira no V4 Pro (refatoração pesada)

A chave fica GLOBAL em ~/.claude-deepseek/deepseek.key (chmod 600).
Para trocá-la: deepclaude --setup-key
EOF
