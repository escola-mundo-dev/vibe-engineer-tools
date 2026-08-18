#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh — instalador do Ghostty + configuração da aula (idêntica à do
# professor: Dracula, JetBrainsMono Nerd Font, keybinds de abas/splits,
# scrollback de 100 MB para streaming de agente).
#
# O que faz (idempotente):
#   1. Instala o Ghostty (brew no macOS; PPA/pacman/dnf/zypper/snap no Linux).
#   2. Instala a fonte JetBrainsMono Nerd Font se faltar.
#   3. Faz BACKUP de qualquer config existente e escreve
#      ~/.config/ghostty/config.ghostty + ~/.config/ghostty/themes/dracula.
#   4. Ajusta `shell-integration` para o shell de login da máquina.
#   5. Valida a config contra o binário e recarrega a instância ativa (Linux).
#
# Windows: o Ghostty OFICIAL não tem build nativo (ago/2026). O instalador
# detecta e orienta: WSL2 (recomendado — este mesmo script roda lá dentro) ou
# o port comunitário winghostty (https://winghostty.com/).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"
CFG_DIR="$HOME/.config/ghostty"
CFG_FILE="$CFG_DIR/config.ghostty"
STAMP="$(date +%Y%m%d-%H%M%S)"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✅\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m⚠️ \033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m❌\033[0m %s\n' "$*" >&2; exit 1; }

# Tudo aqui é por-usuário — rodar com sudo instalaria a config em /root.
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
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

# ── Windows: sem build oficial — orientar e sair sem erro ────────────────────
if [ "$OS" = "windows" ]; then
  cat <<'EOF'
⚠️  O Ghostty oficial não tem build nativo para Windows (agosto/2026).
    Duas rotas, em ordem de recomendação:

    1. WSL2 (recomendada — comportamento idêntico ao da aula):
         wsl --install -d Ubuntu
       Depois, DENTRO do Ubuntu/WSL, rode este mesmo install.sh.

    2. winghostty — port comunitário nativo (núcleo do Ghostty, releases
       assinadas x64/ARM64): https://winghostty.com/
       É um projeto independente; a config desta aula (config.ghostty)
       não é garantida nele — trate como alternativa, não como equivalente.
EOF
  exit 0
fi

# ── 1. Ghostty ───────────────────────────────────────────────────────────────
if command -v ghostty >/dev/null 2>&1; then
  ok "Ghostty já instalado: $(ghostty +version 2>/dev/null | head -n1 || echo ok)"
else
  info "Instalando o Ghostty…"
  if [ "$OS" = "macos" ]; then
    command -v brew >/dev/null 2>&1 \
      || fail "Homebrew não encontrado. Instale-o (https://brew.sh) e rode de novo."
    brew install --cask ghostty
  else
    # Linux: detecta a distro
    ID_DISTRO=""; ID_LIKE_DISTRO=""
    if [ -r /etc/os-release ]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      ID_DISTRO="${ID:-}"; ID_LIKE_DISTRO="${ID_LIKE:-}"
    fi
    case "$ID_DISTRO $ID_LIKE_DISTRO" in
      *ubuntu*|*pop*|*mint*)
        # PPA da aula (mesmo da máquina do professor): mkasberg/ghostty-ubuntu
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
        sudo apt-get update -y
        sudo apt-get install -y ghostty
        ;;
      *arch*)
        sudo pacman -S --noconfirm ghostty
        ;;
      *fedora*|*rhel*)
        # `dnf copr` é plugin — Fedora Server/minimal/containers vêm sem ele.
        sudo dnf install -y dnf-plugins-core
        sudo dnf copr enable -y pgdev/ghostty
        sudo dnf install -y ghostty
        ;;
      *suse*)
        sudo zypper --non-interactive install ghostty
        ;;
      *)
        if command -v snap >/dev/null 2>&1; then
          sudo snap install ghostty --classic
        else
          fail "Distro sem receita automática — instale pelo guia oficial: https://ghostty.org/docs/install/binary e rode este script de novo (ele só configura na 2ª passada)."
        fi
        ;;
    esac
  fi
  command -v ghostty >/dev/null 2>&1 || fail "Instalação do Ghostty não concluiu."
  ok "Ghostty instalado"
fi

# ── 2. Fonte JetBrainsMono Nerd Font ─────────────────────────────────────────
info "Verificando a fonte JetBrainsMono Nerd Font…"
if [ "$OS" = "macos" ]; then
  if command -v brew >/dev/null 2>&1; then
    brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1 \
      || brew install --cask font-jetbrains-mono-nerd-font
    ok "Fonte ok (Homebrew cask)"
  else
    warn "Sem Homebrew — instale a fonte manualmente: https://www.nerdfonts.com (JetBrainsMono). Seguindo com a config."
  fi
else
  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
    ok "Fonte já registrada no fontconfig"
  elif [ -n "$(ls -A "$FONT_DIR" 2>/dev/null)" ]; then
    ok "Fonte já baixada em $FONT_DIR (o fontconfig registra no próximo terminal)"
  else
    info "Baixando JetBrainsMono Nerd Font (nerd-fonts, release oficial)…"
    TMP_FONT="$(mktemp -d)"
    mkdir -p "$FONT_DIR"
    if command -v unzip >/dev/null 2>&1; then
      curl -fL -o "$TMP_FONT/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
      unzip -o -q "$TMP_FONT/JetBrainsMono.zip" -d "$FONT_DIR"
    else
      curl -fL -o "$TMP_FONT/JetBrainsMono.tar.xz" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
      tar -xJf "$TMP_FONT/JetBrainsMono.tar.xz" -C "$FONT_DIR"
    fi
    rm -rf "$TMP_FONT"
    fc-cache -f "$FONT_DIR" >/dev/null
    fc-list | grep -qi "JetBrainsMono Nerd" && ok "Fonte instalada e registrada" \
      || warn "Fonte baixada mas o fontconfig ainda não a lista — abra um terminal novo e confira: fc-list | grep -i jetbrains"
  fi
fi

# ── 3. Config (com backup) ───────────────────────────────────────────────────
info "Aplicando a configuração da aula…"
mkdir -p "$CFG_DIR/themes"

# Backup do config.ghostty atual, se houver (mesma convenção .bak-<timestamp>).
if [ -f "$CFG_FILE" ]; then
  cp "$CFG_FILE" "$CFG_FILE.bak-$STAMP"
  ok "Backup do config anterior: $CFG_FILE.bak-$STAMP"
fi

# Arquivo LEGADO `config` (pré-1.2.3): o Ghostty lê os DOIS e, em conflito, o
# `config` VENCE — deixá-lo lá anularia chaves da aula em silêncio.
if [ -f "$CFG_DIR/config" ]; then
  mv "$CFG_DIR/config" "$CFG_DIR/config.pre-aula-bak-$STAMP"
  warn "Encontrei um ~/.config/ghostty/config legado — movido para config.pre-aula-bak-$STAMP (ele venceria o config.ghostty em conflito). Nada foi apagado."
fi

cp "$PAYLOAD/config.ghostty" "$CFG_FILE"
cp "$PAYLOAD/themes/dracula" "$CFG_DIR/themes/dracula"

# shell-integration acompanha o shell de login da máquina (zsh na do professor).
login_shell="$(basename "${SHELL:-zsh}")"
case "$login_shell" in
  bash|fish)
    sed "s/^shell-integration = zsh/shell-integration = $login_shell/" "$CFG_FILE" > "$CFG_FILE.tmp" \
      && mv "$CFG_FILE.tmp" "$CFG_FILE"
    ok "shell-integration ajustado para: $login_shell"
    ;;
  *) : ;;  # zsh (ou desconhecido): fica como na aula
esac
ok "config.ghostty + tema dracula (port oficial dracula/ghostty) aplicados"

# ── 4. Validação contra o binário ────────────────────────────────────────────
# ⚠️ Sintaxe exata importa: `--config-file=` COM "=" e caminho ABSOLUTO
# (com espaço ou com ~ o comando sai exit 1 mudo).
info "Validando a config no binário…"
if ghostty +validate-config --config-file="$CFG_FILE"; then
  ok "Config válida (exit 0, sem avisos = ok)"
else
  fail "Config inválida — o Ghostty aponta a linha do erro acima (unknown field?)."
fi

# ── 5. Reload da instância ativa (sem fechar nada) ───────────────────────────
# -U "$(id -u)": só as instâncias DESTE usuário (sem o filtro, o primeiro PID
# pode ser de outro usuário → EPERM silencioso e a sua instância não recarrega).
if [ "$OS" = "linux" ] && pgrep -x -U "$(id -u)" ghostty >/dev/null 2>&1; then
  pkill -USR2 -x -U "$(id -u)" ghostty 2>/dev/null \
    && ok "Instância ativa recarregada via SIGUSR2 (sem fechar janelas)" \
    || warn "Não consegui sinalizar a instância — use Ctrl+Shift+, dentro do Ghostty"
fi

echo
ok "Ghostty configurado como na aula."
cat <<'EOF'

Cola de teclas (as da aula):
  Ctrl+T            nova aba          Ctrl+R          renomear aba
  Ctrl+←→↑↓         novo split        Ctrl+Alt+←→↑↓   navegar entre splits
  Ctrl+8/4/2/6      redimensionar split (cima/esq/baixo/dir)
  Ctrl+W            fechar terminal (pede confirmação se algo roda)
  Ctrl+Shift+,      recarregar config

Próximo passo (30 s): abra uma janela NOVA do Ghostty — `gtk-titlebar-style`
e `window-theme` só valem em janela criada depois do reload. Nunca mate o
processo para "aplicar config": o caminho é sempre o reload.
EOF
