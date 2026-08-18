# deepclaude.ps1 — Claude Code (binário OFICIAL) com o cérebro do DeepSeek,
# versão Windows/PowerShell do launcher `deepclaude` da aula.
#
#   deepclaude [args do claude]
#   deepclaude --pro [args]       sobe esta sessão no V4 Pro
#   deepclaude --setup-key        pede + valida + grava a chave DeepSeek (global)
#
# Mesmos pins de modelo do launcher .sh — os SEIS pins são obrigatórios:
# o endpoint mapeia claude-* por prefixo e um pin faltando cai no v4-flash
# em silêncio (claude-sonnet-* -> deepseek-v4-flash).
$ErrorActionPreference = 'Stop'

# Banner MUNDO DEV — abre toda invocação. Desligue com MUNDO_DEV_BANNER=0.
if ($env:MUNDO_DEV_BANNER -ne '0') {
    Write-Host @'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
'@
}

$Dir     = if ($env:DEEPCLAUDE_DIR)     { $env:DEEPCLAUDE_DIR }     else { Join-Path $env:USERPROFILE '.claude-deepseek' }
$Model   = if ($env:DEEPCLAUDE_MODEL)   { $env:DEEPCLAUDE_MODEL }   else { 'deepseek-v4-flash[1m]' }
$Flash   = if ($env:DEEPCLAUDE_HAIKU_MODEL) { $env:DEEPCLAUDE_HAIKU_MODEL } else { $Model }
$Fable   = if ($env:DEEPCLAUDE_FABLE_MODEL) { $env:DEEPCLAUDE_FABLE_MODEL } else { 'deepseek-v4-pro[1m]' }
$BaseUrl = if ($env:DEEPCLAUDE_BASE_URL) { $env:DEEPCLAUDE_BASE_URL } else { 'https://api.deepseek.com/anthropic' }
$Ctx     = if ($env:DEEPCLAUDE_MAX_CONTEXT_TOKENS) { $env:DEEPCLAUDE_MAX_CONTEXT_TOKENS } else { '1048576' }
# Gatilho do auto-compact: 786432 = 75% de 1M, valor prescrito pela PRÓPRIA
# DeepSeek no guia oficial de Claude Code — declarar só a janela não basta,
# porque a saída pode chegar a 384K e precisa caber no que sobrou.
$Compact = if ($env:DEEPCLAUDE_AUTO_COMPACT_WINDOW) { $env:DEEPCLAUDE_AUTO_COMPACT_WINDOW } else { '786432' }
$KeyFile = Join-Path $Dir 'deepseek.key'

function Test-DeepSeekKey([string]$Key) {
    # GET /user/balance: não consome tokens; 200 = válida (mostra saldo), 401 = inválida.
    try {
        $r = Invoke-RestMethod -Uri 'https://api.deepseek.com/user/balance' `
             -Headers @{ Authorization = "Bearer $Key" } -TimeoutSec 15
        $b = $r.balance_infos | Select-Object -First 1
        return "$($b.total_balance) $($b.currency)"
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 401) { Write-Host '[X] chave INVÁLIDA (HTTP 401)' -ForegroundColor Red }
        elseif ($null -eq $status) { Write-Host '[X] sem conexão com api.deepseek.com' -ForegroundColor Red }
        else { Write-Host "[X] resposta inesperada da API (HTTP $status)" -ForegroundColor Red }
        return $null
    }
}

function Invoke-SetupKey {
    Write-Host '── Configuração global da chave DeepSeek ──'
    Write-Host 'Crie/copie a sua chave em: https://platform.deepseek.com/api_keys'
    for ($i = 1; $i -le 3; $i++) {
        $sec = Read-Host -Prompt 'Cole a chave (sk-…)' -AsSecureString
        $key = [System.Net.NetworkCredential]::new('', $sec).Password
        if (-not $key) { Write-Host 'vazio — tente de novo'; continue }
        Write-Host 'Validando na API…'
        $saldo = Test-DeepSeekKey $key
        if ($saldo) {
            New-Item -ItemType Directory -Force -Path $Dir | Out-Null
            Set-Content -Path $KeyFile -Value $key -NoNewline -Encoding ascii
            # restringe o arquivo ao usuário atual (equivalente ao chmod 600)
            icacls $KeyFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
            Write-Host "[OK] válida — saldo: $saldo" -ForegroundColor Green
            Write-Host "[OK] gravada em $KeyFile — vale para TODAS as sessões" -ForegroundColor Green
            return $true
        }
        Write-Host "(tentativa $i de 3)"
    }
    # Write-Host, não Write-Error: sob $ErrorActionPreference='Stop' o
    # Write-Error viraria exceção e o `return $false` seria inalcançável.
    Write-Host 'deepclaude: não consegui validar uma chave — nada foi gravado' -ForegroundColor Red
    return $false
}

# ── flags próprias, consumidas antes de repassar ao claude ───────────────────
$claudeArgs = @($args)
if ($claudeArgs.Count -gt 0 -and ($claudeArgs[0] -eq '-h' -or $claudeArgs[0] -eq '--help')) {
    Write-Host @"
deepclaude — Claude Code com cérebro DeepSeek (via api.deepseek.com)

  deepclaude [args do claude]
  deepclaude --pro [args]     sobe esta sessao no V4 Pro
  deepclaude --setup-key      pede + valida + grava a chave DeepSeek (global)

Ambiente (todos opcionais):
  DEEPCLAUDE_DIR         dir de config isolado (default: ~\.claude-deepseek)
  DEEPCLAUDE_API_KEY     chave DeepSeek        (default: <dir>\deepseek.key)
  DEEPCLAUDE_MODEL       modelo principal      (default: deepseek-v4-flash[1m])
  DEEPCLAUDE_HAIKU_MODEL modelo do slot haiku  (default: = o principal)
  DEEPCLAUDE_FABLE_MODEL modelo do slot fable  (default: deepseek-v4-pro[1m])
  DEEPCLAUDE_BASE_URL    endpoint              (default: https://api.deepseek.com/anthropic)
  DEEPCLAUDE_MAX_CONTEXT_TOKENS   janela declarada  (default: 1048576)
  DEEPCLAUDE_AUTO_COMPACT_WINDOW  auto-compact em   (default: 786432)

Trocar de modelo DENTRO da sessao (sem reiniciar):
  /model fable    -> V4 Pro 0813 (GA de 13/08/2026)
  /model sonnet   -> volta pro V4 Flash 0731

Economia off-peak: rode 'deepeco' (ou /eco dentro da sessao).
"@
    exit 0
}
if ($claudeArgs.Count -gt 0 -and $claudeArgs[0] -eq '--setup-key') {
    if (Invoke-SetupKey) { exit 0 } else { exit 1 }
}
if ($claudeArgs.Count -gt 0 -and $claudeArgs[0] -eq '--pro') {
    $claudeArgs = $claudeArgs[1..$claudeArgs.Count]
    $Model = 'deepseek-v4-pro[1m]'
    if (-not $env:DEEPCLAUDE_HAIKU_MODEL) { $Flash = $Model }
    Write-Host 'deepclaude: sessão no deepseek-v4-pro (codegen/refatoração pesada)'
}

# ── chave ────────────────────────────────────────────────────────────────────
# @(...)[0] + guard de nulo: arquivo VAZIO devolve $null e um .Trim() direto
# morreria com 'method on a null-valued expression' — vazio cai no setup,
# como no .sh.
$key = $env:DEEPCLAUDE_API_KEY
if (-not $key -and (Test-Path $KeyFile)) {
    $key = @(Get-Content $KeyFile -First 1)[0]
    if ($key) { $key = $key.Trim() }
}
if (-not $key) {
    Write-Host 'deepclaude: nenhuma chave configurada ainda — iniciando o setup.'
    if (-not (Invoke-SetupKey)) { exit 1 }
    $key = (Get-Content $KeyFile -First 1).Trim()
}

# Banner de economia (nunca pode impedir o launcher de subir)
if (Get-Command deepeco -ErrorAction SilentlyContinue) {
    try { deepeco --short } catch { }
}

# ── env só deste processo (não polui a sessão do PowerShell) ─────────────────
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Write-Host 'deepclaude: Claude Code não encontrado — rode o install.ps1' -ForegroundColor Red
    exit 1
}

$old = @{}
$vars = @{
    ANTHROPIC_API_KEY               = $null   # REMOVE — elimina ambiguidade de chave herdada
    CLAUDE_CONFIG_DIR               = $Dir
    ANTHROPIC_BASE_URL              = $BaseUrl
    ANTHROPIC_AUTH_TOKEN            = $key
    ANTHROPIC_MODEL                 = $Model
    ANTHROPIC_DEFAULT_OPUS_MODEL    = $Model
    ANTHROPIC_DEFAULT_SONNET_MODEL  = $Model
    ANTHROPIC_DEFAULT_HAIKU_MODEL   = $Flash
    ANTHROPIC_DEFAULT_FABLE_MODEL   = $Fable
    CLAUDE_CODE_SUBAGENT_MODEL      = $Model
    CLAUDE_CODE_MAX_CONTEXT_TOKENS  = $Ctx
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = $Compact
}
foreach ($k in $vars.Keys) {
    $old[$k] = [Environment]::GetEnvironmentVariable($k)
    [Environment]::SetEnvironmentVariable($k, $vars[$k])
}
try {
    & $claude.Source --dangerously-skip-permissions --effort max @claudeArgs
    exit $LASTEXITCODE
} finally {
    foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
}
