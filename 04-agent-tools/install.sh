#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instalador das ferramentas de agente da aula:
#              `gitcraque` (cliente Git de desktop, sem Electron) e
#              `surf-skill` (pesquisa web autônoma para agentes de IA).
#
# O que faz (idempotente — pode rodar de novo sem medo):
#   1. Garante Node.js e checa os DOIS pisos de versão:
#        surf-skill exige >= 18 · GitCraque exige >= 22.13 (usa node:sqlite
#        sem flag experimental só a partir dessa versão).
#   2. Garante um prefixo npm global GRAVÁVEL pelo usuário — sem sudo, sem
#      EACCES. Se o prefixo atual não for gravável, cai para ~/.local.
#   3. `npm i -g gitcraque` e `npm i -g surf-skill`.
#   4. ⚠️ PONTE DAS SKILLS: o postinstall do surf-skill só conhece
#      ~/.claude/skills, ~/.agents/skills, ~/.codex/skills e ~/.pi/agent/skills.
#      O `deepclaude` (instalador 03) roda com CLAUDE_CONFIG_DIR=~/.claude-deepseek,
#      então SEM esta ponte as skills existiriam no disco e ficariam INVISÍVEIS
#      no agente principal da aula. Aqui elas são espelhadas para lá.
#   5. Oferece o wizard de chaves do surf (`surf`) — interativo, com validação
#      ao vivo. Pular é seguro: o `surf-free-skill` funciona sem chave nenhuma.
#
# Suporte: Linux, macOS e Windows via Git Bash. Para PowerShell nativo no
# Windows, use o install.ps1 desta mesma pasta.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Diretório de config do deepclaude — MESMO nome de env que o launcher usa,
# para que uma instalação customizada (DEEPCLAUDE_DIR=...) continue coerente.
DC_DIR="${DEEPCLAUDE_DIR:-$HOME/.claude-deepseek}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m⚠️ \033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

# Tudo aqui é por-usuário — rodar com sudo instalaria em /root em silêncio.
# Exceção consciente (container/WSL como root): AULA_PERMITIR_ROOT=1 ./install.sh
if [ "$(id -u)" -eq 0 ] && [ -z "${AULA_PERMITIR_ROOT:-}" ]; then
  fail "Não rode com sudo — o script instala tudo no seu usuário. (Root de verdade? AULA_PERMITIR_ROOT=1)"
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

# ── 1. Node.js: dois pisos de versão ────────────────────────────────────────
command -v node >/dev/null 2>&1 \
  || fail "Node.js não encontrado — rode primeiro o instalador 01-commands (ele instala o Node)."
command -v npm  >/dev/null 2>&1 \
  || fail "npm não encontrado — o pacote 'nodejs' do apt vem sem npm. Rode o instalador 01-commands."

NODE_V="$(node -v | sed 's/^v//')"
NODE_MAJ="${NODE_V%%.*}"
NODE_MIN="$(printf '%s' "$NODE_V" | cut -d. -f2)"

# surf-skill: engines.node >= 18
if [ "$NODE_MAJ" -lt 18 ] 2>/dev/null; then
  fail "Node $NODE_V é antigo demais (surf-skill exige >= 18). Rode o instalador 01-commands."
fi

# GitCraque: engines.node >= 22.13.0 (node:sqlite perde o --experimental-sqlite ali).
# Comparação major/minor: 22.13 passa, 22.12 não.
GITCRAQUE_OK=1
if [ "$NODE_MAJ" -lt 22 ] 2>/dev/null; then
  GITCRAQUE_OK=0
elif [ "$NODE_MAJ" -eq 22 ] && [ "${NODE_MIN:-0}" -lt 13 ] 2>/dev/null; then
  GITCRAQUE_OK=0
fi
ok "Node.js $NODE_V (surf-skill exige >= 18 · GitCraque exige >= 22.13)"
[ "$GITCRAQUE_OK" = "0" ] && warn "Node $NODE_V não atende ao piso do GitCraque (>= 22.13) — ele será PULADO. Suba o Node (nvm install 24) e rode este instalador de novo."

# ── 2. Prefixo npm global gravável (sem sudo) ───────────────────────────────
# `npm i -g` num Node instalado pelo gerenciador da distro (/usr/lib/node_modules)
# morre com EACCES. Em vez de pedir sudo — que instalaria para o ROOT e sumiria
# do PATH do usuário —, aponta o prefixo global para ~/.local, onde os outros
# instaladores da aula já publicam binários (e que o comandos.sh já põe no PATH).
# No Windows/Git Bash o prefixo é %APPDATA%\npm, sempre gravável: nada a fazer.
if [ "$OS" != "windows-gitbash" ]; then
  NPM_PREFIX="$(npm prefix -g 2>/dev/null || true)"
  if [ -n "$NPM_PREFIX" ] && ! mkdir -p "$NPM_PREFIX/lib/node_modules" 2>/dev/null; then
    warn "Prefixo npm global ($NPM_PREFIX) não é gravável pelo seu usuário."
    warn "Movendo o prefixo para ~/.local — instalações globais futuras do npm irão para lá."
    npm config set prefix "$HOME/.local"
    NPM_PREFIX="$HOME/.local"
    ok "Prefixo npm global agora é ~/.local (sem sudo, junto dos bins da aula)"
  fi

  NPM_BIN="$NPM_PREFIX/bin"
  case ":$PATH:" in
    *":$NPM_BIN:"*) ;;
    *)
      PATH="$NPM_BIN:$PATH"
      # Só persiste se ainda não estiver coberto: o bloco do 01-commands já põe
      # ~/.local/bin no PATH, e o nvm já cobre o seu próprio bin. Um terceiro
      # bloco de rc só se justifica quando o diretório é realmente outro.
      if [ "$NPM_BIN" != "$HOME/.local/bin" ]; then
        MARK_BEGIN="# >>> aula-dev (PATH npm global) >>>"
        _persistir_path() {  # $1 = arquivo rc
          local rc="$1"
          touch "$rc"
          grep -qF "$MARK_BEGIN" "$rc" && return 0
          {
            printf '\n%s\n' "$MARK_BEGIN"
            # shellcheck disable=SC2016  # $PATH tem de ficar literal no arquivo rc
            printf 'case ":$PATH:" in *":%s:"*) ;; *) PATH="%s:$PATH" ;; esac\n' "$NPM_BIN" "$NPM_BIN"
            printf '# <<< aula-dev (PATH npm global) <<<\n'
          } >> "$rc"
          ok "PATH do npm global persistido em $rc"
        }
        case "$(basename "${SHELL:-}")" in
          zsh)  _persistir_path "$HOME/.zshrc" ;;
          *)    _persistir_path "$HOME/.bashrc"
                command -v zsh >/dev/null 2>&1 && _persistir_path "$HOME/.zshrc" ;;
        esac
      fi
      ;;
  esac
fi

# ── 3. GitCraque ─────────────────────────────────────────────────────────────
if [ "$GITCRAQUE_OK" = "1" ]; then
  info "Instalando o GitCraque (npm i -g gitcraque)…"
  npm install -g gitcraque --no-audit --no-fund
  ok "GitCraque instalado: $(gitcraque --version 2>/dev/null || npm view gitcraque version)"
else
  warn "GitCraque pulado (Node < 22.13)."
fi

# ── 4. surf-skill ────────────────────────────────────────────────────────────
info "Instalando o surf-skill (npm i -g surf-skill)…"
# O postinstall do pacote é quem cria os symlinks das 3 skills nas 4 pastas de
# harness conhecidas e o ~/.config/surf/keys.json (chmod 600).
npm install -g surf-skill --no-audit --no-fund
ok "surf-skill instalado: $(npm view surf-skill version 2>/dev/null || echo ok)"

# ── 5. Ponte das skills para o deepclaude ───────────────────────────────────
# O `deepclaude` sobe o Claude Code com CLAUDE_CONFIG_DIR=~/.claude-deepseek.
# As skills pessoais são lidas de <CLAUDE_CONFIG_DIR>/skills — que o postinstall
# do surf-skill NÃO conhece. Sem esta ponte, `surf-search-normal` existe no PATH
# mas as skills não aparecem para o agente da aula.
info "Ligando as skills do surf ao deepclaude ($DC_DIR/skills)…"
SURF_ROOT="$(npm root -g)/surf-skill"
if [ ! -d "$SURF_ROOT" ]; then
  warn "Não achei o pacote em $SURF_ROOT — pulando a ponte de skills."
else
  mkdir -p "$DC_DIR/skills"
  chmod 700 "$DC_DIR" 2>/dev/null || true   # 03-deepclaude já cria com 700; aqui é só garantia
  _ligar_skill() {  # $1 = nome da skill; $2 = caminho alvo
    local nome="$1" alvo="$2" link="$DC_DIR/skills/$1"
    [ -d "$alvo" ] || { warn "skill '$nome' não encontrada em $alvo — pulada"; return 0; }
    # Só mexe no que é nosso: um diretório de verdade (cópia do usuário) fica intacto.
    if [ -L "$link" ]; then
      rm -f "$link"
    elif [ -e "$link" ]; then
      warn "$link já existe e não é symlink — preservado (remova à mão se quiser a versão do npm)"
      return 0
    fi
    if ln -s "$alvo" "$link" 2>/dev/null; then
      ok "skill $nome → $link"
    else
      # MSYS/Git Bash sem privilégio de symlink: cópia é o caminho confiável.
      cp -a "$alvo" "$link" && ok "skill $nome copiada para $link (sem symlink neste sistema)"
    fi
  }
  _ligar_skill surf-research-skill "$SURF_ROOT"
  _ligar_skill surf-plan-skill     "$SURF_ROOT/skills/surf-plan-skill"
  _ligar_skill surf-free-skill     "$SURF_ROOT/skills/surf-free-skill"
fi

# ── 6. Chaves do surf (opcional, interativo) ────────────────────────────────
# `surf-free-skill` (Wikipedia + DuckDuckGo) funciona SEM chave — por isso
# pular aqui nunca deixa o aluno sem pesquisa.
if [ -t 0 ]; then
  printf '\n'
  printf 'Configurar agora as chaves de pesquisa do surf? (Tavily / Parallel / Brave / OpenRouter)\n'
  printf 'Pular é seguro: o `surf-free-skill` pesquisa sem chave nenhuma. [s/N]: '
  read -r resp || resp=""
  case "$resp" in
    s|S|y|Y)
      # `|| warn`: sob set -e, um wizard abortado (Ctrl+C) não pode derrubar o
      # instalador depois de tudo já instalado.
      surf || warn "Wizard não concluiu — rode depois: surf" ;;
    *)
      info "Pulado. Quando quiser: \`surf\` (chaves de busca) e \`surf-research-skill ai-setup\` (chave OpenRouter do surf-ai)." ;;
  esac
else
  info "Sessão não interativa — rode depois: surf (chaves de busca) e surf-research-skill ai-setup (OpenRouter)."
fi

# ── 7. Smoke tests ───────────────────────────────────────────────────────────
info "Testando…"
command -v surf-search-normal >/dev/null 2>&1 && ok "surf-search-normal está no PATH" \
  || warn "surf-search-normal fora do PATH nesta sessão — abra um terminal novo"
surf-free-skill --help >/dev/null 2>&1 && ok "surf-free-skill responde (pesquisa sem chave)" \
  || warn "surf-free-skill não respondeu ao --help"
if [ "$GITCRAQUE_OK" = "1" ]; then
  command -v gitcraque >/dev/null 2>&1 && ok "gitcraque está no PATH" \
    || warn "gitcraque fora do PATH nesta sessão — abra um terminal novo"
fi
for s in surf-research-skill surf-plan-skill surf-free-skill; do
  [ -e "$DC_DIR/skills/$s" ] && ok "deepclaude enxerga a skill $s" \
    || warn "skill $s não está em $DC_DIR/skills"
done

echo
ok "Instalação concluída."
cat <<'EOF'

Como usar (2 min) — em um terminal NOVO:
  1. cd <um repo git> && gitcraque
       · abre o navegador no grafo; trocar de worktree é process.chdir(),
         não `git checkout` — combina com as worktrees que o `qwe` cria
  2. surf-free-skill "sua pergunta"        → pesquisa sem chave nenhuma
  3. surf                                  → adiciona chaves (validadas ao vivo)
     surf-research-skill ai-setup          → chave OpenRouter que move o surf-ai
  4. Dentro de um projeto, uma vez por projeto:
       surf-research-skill project-config  → sobe o timeout do Bash do harness
  5. Dentro do deepclaude, peça: "pesquise na web sobre X" ou "faça um plano para Y"
EOF
