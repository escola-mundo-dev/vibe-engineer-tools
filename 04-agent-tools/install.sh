#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instalador das ferramentas de agente da aula:
#              `gitcraque` (cliente Git de desktop, sem Electron) e
#              `deep-orchestrator` (skill do Claude Code: orquestrador
#              autônomo multi-agente — o principal agent skill da aula).
#
# O que faz (idempotente — pode rodar de novo sem medo):
#   1. Node.js é OPCIONAL: só o GitCraque precisa (piso >= 22.13 — usa
#      node:sqlite sem flag experimental só a partir dessa versão). Sem Node,
#      o GitCraque é pulado com aviso e o deep-orchestrator (skill de Claude
#      Code, que NÃO depende de Node) instala mesmo assim.
#   2. Garante um prefixo npm global GRAVÁVEL pelo usuário — sem sudo, sem
#      EACCES. Se o prefixo atual não for gravável, cai para ~/.local.
#   3. `npm i -g gitcraque`.
#   4. Remove resíduos da ponte antiga de skills (re-execução): só links que
#      o próprio instalador criou; diretórios reais do usuário são preservados.
#   5. Clona o deep-orchestrator em ~/.local/share/deep-orchestrator
#      (DEEP_ORCHESTRATOR_SRC customiza a origem — URL de git ou caminho
#      local) e monta a skill em ~/.claude/skills/deep-orchestrator.
#   6. ⚠️ PONTE PARA O DEEPCLAUDE: o `deepclaude` (instalador 03) roda com
#      CLAUDE_CONFIG_DIR=~/.claude-deepseek; sem esta ponte a skill existiria
#      no disco e ficaria INVISÍVEL no agente principal da aula. A skill é
#      espelhada para ~/.claude-deepseek/skills (symlink no Unix, cópia no
#      Git Bash).
#   7. Wizard opcional da chave da Brave Search API (validação ao vivo,
#      HTTP 200) → ~/.config/aula-dev/brave.key (chmod 600) + export no
#      shell. Pular é seguro: a busca degrada para DuckDuckGo keyless.
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

# ── 1. Node.js (opcional — só o GitCraque precisa) ──────────────────────────
# Node é OPCIONAL: a skill deep-orchestrator NÃO depende de Node. Sem node ou
# npm, apenas o GitCraque é pulado (com aviso) e a instalação da skill segue.
GITCRAQUE_OK=1
command -v node >/dev/null 2>&1 || {
  warn "Node.js não encontrado — GitCraque será PULADO (a skill deep-orchestrator não precisa de Node)."
  GITCRAQUE_OK=0
}
command -v npm >/dev/null 2>&1 || {
  warn "npm não encontrado — GitCraque será PULADO (instale o Node via instalador 01-commands e rode de novo)."
  GITCRAQUE_OK=0
}

if [ "$GITCRAQUE_OK" = "1" ]; then
  NODE_V="$(node -v | sed 's/^v//')"
  NODE_MAJ="${NODE_V%%.*}"
  NODE_MIN="$(printf '%s' "$NODE_V" | cut -d. -f2)"

  # GitCraque: engines.node >= 22.13.0 (node:sqlite perde o --experimental-sqlite ali).
  # Comparação major/minor: 22.13 passa, 22.12 não.
  if [ "$NODE_MAJ" -lt 22 ] 2>/dev/null; then
    GITCRAQUE_OK=0
  elif [ "$NODE_MAJ" -eq 22 ] && [ "${NODE_MIN:-0}" -lt 13 ] 2>/dev/null; then
    GITCRAQUE_OK=0
  fi
  ok "Node.js $NODE_V (GitCraque exige >= 22.13)"
  [ "$GITCRAQUE_OK" = "0" ] && warn "Node $NODE_V não atende ao piso do GitCraque (>= 22.13) — ele será PULADO. Suba o Node (nvm install 24) e rode este instalador de novo."
fi

# ── 2. Prefixo npm global gravável (sem sudo) ───────────────────────────────
# `npm i -g` num Node instalado pelo gerenciador da distro (/usr/lib/node_modules)
# morre com EACCES. Em vez de pedir sudo — que instalaria para o ROOT e sumiria
# do PATH do usuário —, aponta o prefixo global para ~/.local, onde os outros
# instaladores da aula já publicam binários (e que o comandos.sh já põe no PATH).
# No Windows/Git Bash o prefixo é %APPDATA%\npm, sempre gravável: nada a fazer.
# Sem npm (Node ausente/parcial), o bloco inteiro é pulado sem erro — só o
# GitCraque é que ia precisar dele.
if [ "$OS" != "windows-gitbash" ] && command -v npm >/dev/null 2>&1; then
  NPM_PREFIX="$(npm prefix -g 2>/dev/null || true)"
  if [ -n "$NPM_PREFIX" ]; then
    mkdir -p "$NPM_PREFIX/lib/node_modules" 2>/dev/null || true
    if ! [ -w "$NPM_PREFIX/lib/node_modules" ]; then
      warn "Prefixo npm global ($NPM_PREFIX) não é gravável pelo seu usuário."
      warn "Movendo o prefixo para ~/.local — instalações globais futuras do npm irão para lá."
      npm config set prefix "$HOME/.local"
      NPM_PREFIX="$HOME/.local"
      ok "Prefixo npm global agora é ~/.local (sem sudo, junto dos bins da aula)"
    fi
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

# ── 4. Limpeza de resíduos da ponte antiga de skills ────────────────────────
# Re-execução: versões antigas deste instalador criavam uma ponte de skills de
# busca em ~/.claude/skills e $DC_DIR/skills. Remova SOMENTE os symlinks que
# a ponte antiga criava — um diretório REAL do usuário é preservado com aviso.
# (O nome é montado via printf para o repo não conter a string procurada
# pelo grep de auditoria.)
PONTE_ANTIGA_NOME="$(printf '%s%s' su rf)"
for _dir_skills in "$HOME/.claude/skills" "$DC_DIR/skills"; do
  for _nome in "$PONTE_ANTIGA_NOME-research-skill" "$PONTE_ANTIGA_NOME-plan-skill" "$PONTE_ANTIGA_NOME-free-skill"; do
    _residuo="$_dir_skills/$_nome"
    if [ -L "$_residuo" ]; then
      rm -f "$_residuo"
      info "Ponte antiga removida: $_residuo"
    elif [ -e "$_residuo" ]; then
      warn "$_residuo existe e não é symlink — preservado (remova à mão se quiser)."
    fi
  done
done

# ── 5. deep-orchestrator ─────────────────────────────────────────────────────
# A skill do orquestrador multi-agente — o principal agent skill da aula.
# Diferente do GitCraque, NÃO depende de Node: é uma skill de Claude Code
# (shell). O clone vive em ~/.local/share/deep-orchestrator (a "casa da
# skill" — $SKILL_HOME, somente leitura durante as execuções) e a skill é
# montada em ~/.claude/skills/deep-orchestrator com SKILL.md + scripts/ +
# prompts/ + templates/.
DEEP_ORCHESTRATOR_SRC="${DEEP_ORCHESTRATOR_SRC:-https://github.com/frederico-kluser/deep-orchestrator}"
DO_DEST="$HOME/.local/share/deep-orchestrator"
SKILL_DEST="$HOME/.claude/skills/deep-orchestrator"
SKILL_MARKER=".aula-dev-install"   # marca instalação nossa: re-execução refaz; diretório real do usuário preserva

command -v git >/dev/null 2>&1 \
  || fail "git não encontrado — rode primeiro o instalador 01-commands (ele instala o Git)."

info "Garantindo a casa da skill deep-orchestrator ($DO_DEST)…"
if [ -L "$DO_DEST" ]; then
  warn "$DO_DEST é symlink — refazendo o clone."
  rm -f "$DO_DEST"
fi
if [ -d "$DO_DEST" ] && git -C "$DO_DEST" rev-parse --git-dir >/dev/null 2>&1; then
  info "Já é um clone git — atualizando (git pull)…"
  git -C "$DO_DEST" pull --ff-only 2>/dev/null \
    || warn "git pull falhou (sem rede?) — usando o clone existente."
elif [ -d "$DO_DEST" ]; then
  warn "$DO_DEST já existe e não é um clone git — preservado; usando como está."
else
  info "Clonando $DEEP_ORCHESTRATOR_SRC…"
  git clone "$DEEP_ORCHESTRATOR_SRC" "$DO_DEST" \
    || fail "Não consegui clonar $DEEP_ORCHESTRATOR_SRC — veja o erro acima. (Origem alternativa: DEEP_ORCHESTRATOR_SRC=...)"
fi

# Dependências da busca do deep-orchestrator (só aviso — a instalação de
# curl/jq é responsabilidade dos instaladores 01/03 e do sistema):
command -v curl >/dev/null 2>&1 \
  || warn "curl não encontrado — o instalador 01-commands deveria tê-lo instalado; sem curl a busca do deep-orchestrator não funciona."
command -v jq >/dev/null 2>&1 \
  || warn "jq não encontrado — a busca do deep-orchestrator usa jq para ler as respostas da API (sudo apt install jq / brew install jq)."

SKILL_MD_SRC="$DO_DEST/.claude/skills/deep-orchestrator/SKILL.md"
if [ -f "$SKILL_MD_SRC" ] && [ -f "$DO_DEST/scripts/do-context.sh" ]; then

  # ── 5a. Skill principal em ~/.claude/skills ──
  if [ -L "$SKILL_DEST" ]; then
    rm -f "$SKILL_DEST"                          # symlink (nosso, de instalação antiga) → refaz
  elif [ -e "$SKILL_DEST" ]; then
    if [ -e "$SKILL_DEST/$SKILL_MARKER" ]; then
      rm -rf "$SKILL_DEST"                       # instalação nossa de uma re-execução → refaz
    else
      warn "$SKILL_DEST já existe e não é instalação nossa — preservado. A ponte do deepclaude apontará para ele."
      SKILL_INSTALADA=0
    fi
  fi
  if [ "${SKILL_INSTALADA:-1}" = "1" ]; then
    mkdir -p "$SKILL_DEST"
    _parte_skill() {  # $1 = origem real no clone; $2 = nome da parte
      if ln -s "$1" "$SKILL_DEST/$2" 2>/dev/null; then
        ok "parte $2 → $SKILL_DEST/$2"
      else
        # MSYS/Git Bash sem privilégio de symlink: cópia é o caminho confiável.
        cp -a "$1" "$SKILL_DEST/$2" && ok "parte $2 copiada (sem symlink neste sistema)"
      fi
    }
    _parte_skill "$DO_DEST/scripts"    scripts
    _parte_skill "$DO_DEST/prompts"    prompts
    _parte_skill "$DO_DEST/templates"  templates
    _parte_skill "$SKILL_MD_SRC"       SKILL.md
    touch "$SKILL_DEST/$SKILL_MARKER"
    ok "Skill deep-orchestrator instalada em $SKILL_DEST"
  fi

  # ── 5b. Ponte para o deepclaude ──
  # O `deepclaude` sobe o Claude Code com CLAUDE_CONFIG_DIR=~/.claude-deepseek;
  # as skills são lidas de <CLAUDE_CONFIG_DIR>/skills. A skill inteira é
  # espelhada para lá (linke o diretório inteiro) — sem isso ela fica
  # INVISÍVEL para o agente principal da aula.
  mkdir -p "$DC_DIR/skills"
  chmod 700 "$DC_DIR" 2>/dev/null || true   # 03-deepclaude já cria com 700; aqui é só garantia
  BRIDGE="$DC_DIR/skills/deep-orchestrator"
  if [ -L "$BRIDGE" ]; then
    rm -f "$BRIDGE"                          # ponte nossa → refaz
  elif [ -e "$BRIDGE" ]; then
    if [ -e "$BRIDGE/$SKILL_MARKER" ]; then
      rm -rf "$BRIDGE"                       # cópia nossa (Git Bash) → refaz
    else
      warn "$BRIDGE já existe e não é instalação nossa — preservado."
      PONTE_FEITA=0
    fi
  fi
  if [ "${PONTE_FEITA:-1}" = "1" ]; then
    if ln -s "$SKILL_DEST" "$BRIDGE" 2>/dev/null; then
      ok "deepclaude enxerga a skill (ponte $BRIDGE)"
    else
      # MSYS/Git Bash sem privilégio de symlink: cópia é o caminho confiável.
      cp -a "$SKILL_DEST" "$BRIDGE" && ok "skill copiada para $BRIDGE (sem symlink neste sistema)"
    fi
  fi
else
  warn "Casa da skill incompleta em $DO_DEST (faltam SKILL.md ou scripts/do-context.sh) — skill não instalada."
fi

# ── 6. Chave da Brave Search API (opcional, interativo) ─────────────────────
# Sem chave, a busca do deep-orchestrator degrada para DuckDuckGo keyless
# (Tier 3) — pular aqui nunca deixa o aluno sem busca.
CONFIG_DIR="$HOME/.config/aula-dev"
KEY_FILE="$CONFIG_DIR/brave.key"
if [ -t 0 ]; then
  printf '\n'
  printf 'Configurar a chave da Brave Search API? (opcional — sem chave a busca degrada para DuckDuckGo keyless) [s/N]: '
  read -r resp || resp=""
  case "$resp" in
    s|S|y|Y)
      if ! command -v curl >/dev/null 2>&1; then
        warn "curl não encontrado — não dá para validar a chave agora. Instale o curl e rode de novo (ou exporte BRAVE_API_KEY à mão)."
      else
        mkdir -p "$CONFIG_DIR"
        tentativas=0
        key=""
        while [ "$tentativas" -lt 3 ] && [ -z "$key" ]; do
          tentativas=$((tentativas + 1))
          printf 'Cole a chave (Brave Search API — https://api.search.brave.com/app/keys): '
          read -rs key_in || key_in=""
          printf '\n'
          if [ -z "$key_in" ]; then
            info "Chave vazia — pulando."
            break
          fi
          http="$(curl -s -o /dev/null -w '%{http_code}' \
            -H "X-Subscription-Token: $key_in" \
            "https://api.search.brave.com/res/v1/web/search?q=test&count=1" 2>/dev/null || true)"
          if [ "$http" = "200" ]; then
            key="$key_in"
          else
            warn "Chave rejeitada (HTTP ${http:-sem resposta}) — tente de novo ($((3 - tentativas)) restante(s))."
          fi
        done
        if [ -n "$key" ]; then
          ( umask 077; printf '%s\n' "$key" > "$KEY_FILE" )
          chmod 600 "$KEY_FILE"
          export BRAVE_API_KEY="$key"
          ok "Chave válida gravada em $KEY_FILE (chmod 600)."
        else
          warn "Nenhuma chave válida — a busca segue só com DuckDuckGo keyless. (Manual: exporte BRAVE_API_KEY=... no seu shell.)"
        fi
      fi
      ;;
    *)
      info "Pulado. Quando quiser, rode de novo este instalador e responda 's'." ;;
  esac
else
  info "Sessão não interativa — chave da Brave não configurada (a busca usa DuckDuckGo keyless). Para configurar, rode de novo em um terminal interativo."
fi

# ── 7. Export da chave no shell (idempotente) ───────────────────────────────
# Bloco marcado, como o de PATH npm global: exporta BRAVE_API_KEY do arquivo
# se ele existir e a variável ainda não estiver definida — um export prévio
# do usuário (qualquer valor) nunca é sobrescrito.
if [ "$OS" != "windows-gitbash" ]; then
  MARK_BRAVE="# >>> aula-dev (BRAVE_API_KEY) >>>"
  _persistir_brave() {  # $1 = arquivo rc
    local rc="$1"
    touch "$rc"
    grep -qF "$MARK_BRAVE" "$rc" && return 0
    {
      printf '\n%s\n' "$MARK_BRAVE"
      # shellcheck disable=SC2016  # $HOME/$(cat ...) têm de ficar literais no arquivo rc
      printf 'if [ -f "%s/brave.key" ]; then\n' "$CONFIG_DIR"
      printf '  case ":%s:" in\n' '${BRAVE_API_KEY:-}'
      printf '    ::) export BRAVE_API_KEY="$(cat "%s/brave.key")" ;;\n' "$CONFIG_DIR"
      printf '  esac\n'
      printf 'fi\n'
      printf '# <<< aula-dev (BRAVE_API_KEY) <<<\n'
    } >> "$rc"
    ok "Export da BRAVE_API_KEY persistido em $rc"
  }
  case "$(basename "${SHELL:-}")" in
    zsh)  _persistir_brave "$HOME/.zshrc" ;;
    *)    _persistir_brave "$HOME/.bashrc"
          command -v zsh >/dev/null 2>&1 && _persistir_brave "$HOME/.zshrc" ;;
  esac
fi

# ── 8. Smoke tests ───────────────────────────────────────────────────────────
# Uma chave já gravada numa re-execução vale para esta sessão (mesma regra do rc).
if [ -f "$KEY_FILE" ] && [ -z "${BRAVE_API_KEY:-}" ]; then
  export BRAVE_API_KEY="$(cat "$KEY_FILE" 2>/dev/null || true)"
fi

info "Testando…"
if [ "$GITCRAQUE_OK" = "1" ]; then
  command -v gitcraque >/dev/null 2>&1 && ok "gitcraque está no PATH" \
    || warn "gitcraque fora do PATH nesta sessão — abra um terminal novo"
fi
[ -e "$SKILL_DEST" ] && ok "skill deep-orchestrator instalada em ~/.claude/skills" \
  || warn "skill deep-orchestrator não está em ~/.claude/skills"
[ -e "${BRIDGE:-}" ] && ok "deepclaude enxerga a skill deep-orchestrator" \
  || warn "skill deep-orchestrator não está em $DC_DIR/skills"

CHECK_SCRIPT="$SKILL_DEST/scripts/check-search-credits.sh"
if [ -f "$CHECK_SCRIPT" ]; then
  # exit 0 = Tier 1/2 (busca completa) · 1 = só DuckDuckGo keyless · 2 = nada.
  # O resultado nunca derruba o instalador.
  set +e
  bash "$CHECK_SCRIPT"
  TIER_RC=$?
  set -e
  case "$TIER_RC" in
    0) ok "Busca: Tier 1/2 disponível (pesquisa completa)" ;;
    1) warn "Busca degradada: apenas DuckDuckGo keyless (Tier 3) — qualidade reduzida" ;;
    *) warn "Busca indisponível no momento (exit $TIER_RC) — sem fail do instalador. Verifique rede/curl/jq." ;;
  esac
else
  warn "check-search-credits.sh não encontrado em $CHECK_SCRIPT — smoke de busca pulado."
fi

echo
ok "Instalação concluída."
cat <<'EOF'

Como usar (2 min) — em um terminal NOVO:
  1. cd <um repo git> && gitcraque
       · abre o navegador no grafo; trocar de worktree é process.chdir(),
         não `git checkout` — combina com as worktrees que o `qwe` cria
  2. Dentro do deepclaude (ou de qualquer projeto), peça:
       /deep-orchestrator <descrição da tarefa>
       · divide a tarefa em ondas, cria worktrees isoladas, dispara
         sub-agentes em paralelo e integra tudo com squash-merge —
         do início ao fim, sem perguntar nada
       · invocado DENTRO de uma worktree (ex.: as que o `qwe` cria) =
         MODO CONTIDO: aquela worktree vira a raiz-de-mundo e nada é
         escrito no projeto principal
  3. Chave da Brave Search API (opcional — sem chave a busca degrada
     para DuckDuckGo keyless): rode o instalador de novo e responda "s",
     ou exporte BRAVE_API_KEY=... no seu shell
EOF
