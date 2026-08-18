# ─────────────────────────────────────────────────────────────────────────────
# install.ps1 — instalador Windows (PowerShell nativo) do `deepclaude`
#               + `deepeco` + slash command /eco
#
# Uso:  clique-direito > Executar com PowerShell,  ou no terminal:
#       powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# O que faz (idempotente):
#   1. Garante o Claude Code (instalador nativo oficial da Anthropic).
#   2. Instala deepclaude.ps1/deepeco.ps1 (+ shims .cmd) em %USERPROFILE%\.local\bin
#      e adiciona a pasta ao PATH do usuário.
#   3. Instala o /eco em ~\.claude-deepseek\commands\eco.md e a janela de
#      economia em ~\.config\aula-dev\deepeco.conf.
#   4. Pede a chave DeepSeek, VALIDA na API e grava em ~\.claude-deepseek\deepseek.key.
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'

# Banner MUNDO DEV (desligue com MUNDO_DEV_BANNER=0)
if ($env:MUNDO_DEV_BANNER -ne '0') {
    Write-Host @'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
'@
}

$Payload = Join-Path $PSScriptRoot 'payload'
$BinDir  = Join-Path $env:USERPROFILE '.local\bin'
$DcDir   = Join-Path $env:USERPROFILE '.claude-deepseek'
$ConfDir = Join-Path $env:USERPROFILE '.config\aula-dev'

function Info($m) { Write-Host "==> $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host "✅ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "⚠️  $m" -ForegroundColor Yellow }

# ── 1. Claude Code ───────────────────────────────────────────────────────────
if (Get-Command claude -ErrorAction SilentlyContinue) {
    # try/catch: no PS 5.1, redirecionar stderr de comando nativo sob
    # $ErrorActionPreference='Stop' pode virar NativeCommandError terminante.
    $claudeVer = try { @(& claude --version 2>&1)[0] } catch { 'instalado' }
    Ok "Claude Code já instalado: $claudeVer"
} else {
    Info 'Instalando o Claude Code (instalador nativo oficial)…'
    irm https://claude.ai/install.ps1 | iex
    # o instalador coloca o binário no PATH do usuário; garante nesta sessão:
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User') + ';' + $env:PATH
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Warn 'claude ainda fora do PATH desta sessão — feche e reabra o terminal e rode o install.ps1 de novo.'
        exit 1
    }
    Ok 'Claude Code instalado'
}

# ── 2. deepclaude + deepeco no PATH ──────────────────────────────────────────
Info "Instalando deepclaude e deepeco em $BinDir…"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item (Join-Path $Payload 'deepclaude.ps1') (Join-Path $BinDir 'deepclaude.ps1') -Force
Copy-Item (Join-Path $Payload 'deepeco.ps1')    (Join-Path $BinDir 'deepeco.ps1')    -Force

# Shims .cmd: fazem `deepclaude`/`deepeco` funcionarem também no cmd.exe.
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.local\bin\deepclaude.ps1" %*
"@ | Set-Content -Path (Join-Path $BinDir 'deepclaude.cmd') -Encoding ascii
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.local\bin\deepeco.ps1" %*
"@ | Set-Content -Path (Join-Path $BinDir 'deepeco.cmd') -Encoding ascii

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$BinDir;$userPath", 'User')
    $env:PATH = "$BinDir;$env:PATH"
    Ok "Pasta $BinDir adicionada ao PATH do usuário"
} else {
    $env:PATH = "$BinDir;$env:PATH"
    Ok 'Pasta já estava no PATH do usuário'
}

# Wrappers bash SEM extensão (com LF, não CRLF): o /eco dentro do Claude Code
# roda `deepeco` no Git Bash, que não resolve .cmd/.ps1 — sem isto o slash
# command ficaria morto na instalação Windows nativa.
$lf = "`n"
$wrapEco    = '#!/usr/bin/env bash' + $lf + 'exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HOME")\.local\bin\deepeco.ps1" "$@"' + $lf
$wrapClaude = '#!/usr/bin/env bash' + $lf + 'exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HOME")\.local\bin\deepclaude.ps1" "$@"' + $lf
[IO.File]::WriteAllText((Join-Path $BinDir 'deepeco'),    $wrapEco,    [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $BinDir 'deepclaude'), $wrapClaude, [Text.UTF8Encoding]::new($false))
Ok 'Wrappers bash publicados (deepeco/deepclaude também funcionam no Git Bash e no /eco)'

# ── 3. /eco + deepeco.conf ───────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path (Join-Path $DcDir 'commands') | Out-Null
Copy-Item (Join-Path $Payload 'eco.md') (Join-Path $DcDir 'commands\eco.md') -Force
Ok 'Slash command /eco instalado (use DENTRO do deepclaude)'

New-Item -ItemType Directory -Force -Path $ConfDir | Out-Null
$confDest = Join-Path $ConfDir 'deepeco.conf'
if ((Test-Path $confDest) -and ((Get-FileHash $confDest).Hash -ne (Get-FileHash (Join-Path $Payload 'deepeco.conf')).Hash)) {
    Copy-Item $confDest "$confDest.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Warn 'deepeco.conf existente era diferente — backup criado'
}
Copy-Item (Join-Path $Payload 'deepeco.conf') $confDest -Force
Ok "Janela de economia configurada em $confDest"

# ── 4. Chave DeepSeek ────────────────────────────────────────────────────────
$keyFile = Join-Path $DcDir 'deepseek.key'
$precisaSetup = $true
if (Test-Path $keyFile) {
    Info 'Chave já gravada — validando na API…'
    try {
        $k = (Get-Content $keyFile -First 1).Trim()
        Invoke-RestMethod -Uri 'https://api.deepseek.com/user/balance' `
            -Headers @{ Authorization = "Bearer $k" } -TimeoutSec 15 | Out-Null
        Ok 'Chave existente é válida — mantida'
        $precisaSetup = $false
    } catch {
        Warn 'A chave gravada NÃO validou — refazendo o setup.'
    }
}
if ($precisaSetup) {
    # Processo FILHO: `& script.ps1` roda no mesmo processo e um `exit 1` do
    # payload derrubaria o instalador inteiro; como filho, o contrato de
    # $LASTEXITCODE vale — e o try/catch cobre qualquer exceção residual.
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $BinDir 'deepclaude.ps1') --setup-key
        if ($LASTEXITCODE -ne 0) { Warn 'Setup da chave não concluiu — rode depois: deepclaude --setup-key' }
    } catch {
        Warn 'Setup da chave não concluiu — rode depois: deepclaude --setup-key'
    }
}

# ── 5. Smoke test ────────────────────────────────────────────────────────────
& (Join-Path $BinDir 'deepeco.ps1') | Out-Null
Ok 'deepeco responde'

Write-Host ''
Ok 'Instalação concluída.'
Write-Host @'

Como usar (2 min) — em um terminal NOVO (para o PATH valer):
  1. deepeco                → a janela de economia está aberta agora?
  2. cd <um projeto> ; deepclaude
       · /status mostra o endpoint DeepSeek mapeado
       · /eco   mostra a janela de economia sem sair da sessão
       · /model fable ⇆ /model sonnet troca V4 Pro ⇆ V4 Flash
  3. deepclaude --pro       → sessão inteira no V4 Pro

A chave fica em %USERPROFILE%\.claude-deepseek\deepseek.key.
Para trocá-la: deepclaude --setup-key
'@
