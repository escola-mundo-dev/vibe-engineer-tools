# deepeco.ps1 — estamos na janela de economia da API DeepSeek agora?
# Versão Windows/PowerShell do `deepeco` da aula (PS 5.1 e 7).
#
#   deepeco            banner MUNDO DEV + status + tabela de horários/valores
#   deepeco --short    status + tabela, sem o banner (uso do deepclaude)
#
# Regime (vigente desde 16/08/2026): horários de PICO custam 2x e todo o
# resto do dia (17h) é economia (metade do pico). Picos definidos em UTC
# (relógio do SERVIDOR); conversão para o fuso local é automática.
# Valores em ~/.config/aula-dev/deepeco.conf (compartilhado com o .sh).
$ErrorActionPreference = 'Stop'

function Show-MundoDevBanner {
    if ($env:MUNDO_DEV_BANNER -eq '0') { return }
    Write-Host @'
┏┳┓╻ ╻┏┓╻╺┳┓┏━┓   ╺┳┓┏━╸╻ ╻
┃┃┃┃ ┃┃┗┫ ┃┃┃ ┃    ┃┃┣╸ ┃┏┛
╹ ╹┗━┛╹ ╹╺┻┛┗━┛   ╺┻┛┗━╸┗┛
'@
}

# ── defaults (sobrescritos pelo deepeco.conf) ────────────────────────────────
$conf = @{
    ECO_ATIVO          = '1'
    ECO_PICOS_UTC      = '01:00-04:00 06:00-10:00'   # ORDEM CRONOLÓGICA (UTC)
    ECO_DESCONTO_LABEL = 'economia = metade do preço de pico (50% off, todos os modelos)'
    ECO_PRECO_FLASH_ECONOMIA = '$0.007 / $0.22 / $0.66'
    ECO_PRECO_PRO_ECONOMIA   = '$0.022 / $0.66 / $1.98'
    ECO_PRECO_FLASH_PICO     = '$0.014 / $0.44 / $1.32'
    ECO_PRECO_PRO_PICO       = '$0.044 / $1.32 / $3.96'
    ECO_FONTE          = 'https://api-docs.deepseek.com/quick_start/pricing/'
}
$confPath = if ($env:DEEPECO_CONF) { $env:DEEPECO_CONF } else { Join-Path $HOME '.config/aula-dev/deepeco.conf' }
if (Test-Path $confPath) {
    foreach ($line in Get-Content $confPath -Encoding utf8) {
        # Aceita CHAVE="v", CHAVE='v' e CHAVE=v (com comentário após o valor),
        # e tolera \r de arquivos com CRLF — espelha o que o `source` do bash lê.
        if ($line -match '^\s*([A-Z_]+)=(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim() -replace "`r", ''
            if ($v -match '^"([^"]*)"')      { $v = $Matches[1] }
            elseif ($v -match "^'([^']*)'")  { $v = $Matches[1] }
            else                             { $v = ($v -split '\s+#')[0].Trim() }
            $conf[$k] = $v
        }
    }
}

function ToMin([string]$hhmm) { $p = $hhmm.Split(':'); [int]$p[0] * 60 + [int]$p[1] }
# [int] antes do formato: [math]::Floor devolve Double, e '{0:d2}' sobre Double
# lança FormatException — o cast pós-Floor é exato para os valores daqui.
function ToHHMM([int]$min)    { '{0:d2}:{1:d2}' -f [int][math]::Floor($min / 60), ($min % 60) }
function Dur([int]$m) { if ($m -ge 60) { '{0}h{1:d2}' -f [int][math]::Floor($m/60), ($m%60) } else { "$m min" } }

$nowUtcDt = [DateTime]::UtcNow
$now      = $nowUtcDt.Hour * 60 + $nowUtcDt.Minute
$offMin   = [int][TimeZoneInfo]::Local.GetUtcOffset($nowUtcDt).TotalMinutes
$tzLabel  = 'UTC{0}{1}' -f ($(if ($offMin -ge 0) { '+' } else { '' })), [int][math]::Truncate($offMin / 60)
if ($offMin % 60 -ne 0) { $tzLabel += ':{0:d2}' -f [int][math]::Abs($offMin % 60) }
function ToLocal([int]$minUtc) { ToHHMM ((($minUtc + $offMin) % 1440 + 1440) % 1440) }

# ── picos (e os segmentos de economia entre eles) ────────────────────────────
$emPico = $false; $fimPico = 0
$proxPicoDelta = 99999; $proxPicoIni = 0
$pIni = @(); $pFim = @(); $picosLoc = @()
foreach ($jan in $conf.ECO_PICOS_UTC -split '\s+') {
    if (-not $jan) { continue }
    $i = ToMin ($jan -split '-')[0]; $f = ToMin ($jan -split '-')[1]
    $pIni += $i; $pFim += $f
    $picosLoc += "$(ToLocal $i)-$(ToLocal $f)"
    if ($i -le $f) { if ($now -ge $i -and $now -lt $f) { $emPico = $true; $fimPico = $f } }
    else           { if ($now -ge $i -or  $now -lt $f) { $emPico = $true; $fimPico = $f } }
    $d = ((($i - $now) % 1440) + 1440) % 1440
    if ($d -lt $proxPicoDelta) { $proxPicoDelta = $d; $proxPicoIni = $i }
}
$ateEconomia = ((($fimPico - $now) % 1440) + 1440) % 1440
# economia = fim de um pico → início do próximo, ciclicamente
$ecoLoc = @()
for ($k = 0; $k -lt $pIni.Count; $k++) {
    $nx = ($k + 1) % $pIni.Count
    $ecoLoc += "$(ToLocal $pFim[$k])-$(ToLocal $pIni[$nx])"
}
$picosLocStr = $picosLoc -join ' e '
$ecoLocStr   = $ecoLoc   -join ' e '

# ── tabela de horários e valores (células ASCII: PadRight alinha por char) ──
function Show-Tabela {
    $mEco = '  '; $mPico = '  '
    if ($emPico) { $mPico = '> ' } else { $mEco = '> ' }
    $c1 = @('faixa', "${mEco}economia", "${mPico}pico (2x)")
    $c2 = @("horario ($tzLabel)", $ecoLocStr, $picosLocStr)
    $c3 = @('v4-flash (hit/miss/out)', $conf.ECO_PRECO_FLASH_ECONOMIA, $conf.ECO_PRECO_FLASH_PICO)
    $c4 = @('v4-pro (hit/miss/out)',   $conf.ECO_PRECO_PRO_ECONOMIA,   $conf.ECO_PRECO_PRO_PICO)
    $w1 = [int]($c1 | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $w2 = [int]($c2 | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $w3 = [int]($c3 | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $w4 = [int]($c4 | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    Write-Host ('┌─' + '─'*$w1 + '─┬─' + '─'*$w2 + '─┬─' + '─'*$w3 + '─┬─' + '─'*$w4 + '─┐')
    Write-Host ('│ ' + $c1[0].PadRight($w1) + ' │ ' + $c2[0].PadRight($w2) + ' │ ' + $c3[0].PadRight($w3) + ' │ ' + $c4[0].PadRight($w4) + ' │')
    Write-Host ('├─' + '─'*$w1 + '─┼─' + '─'*$w2 + '─┼─' + '─'*$w3 + '─┼─' + '─'*$w4 + '─┤')
    Write-Host ('│ ' + $c1[1].PadRight($w1) + ' │ ' + $c2[1].PadRight($w2) + ' │ ' + $c3[1].PadRight($w3) + ' │ ' + $c4[1].PadRight($w4) + ' │')
    Write-Host ('│ ' + $c1[2].PadRight($w1) + ' │ ' + $c2[2].PadRight($w2) + ' │ ' + $c3[2].PadRight($w3) + ' │ ' + $c4[2].PadRight($w4) + ' │')
    Write-Host ('└─' + '─'*$w1 + '─┴─' + '─'*$w2 + '─┴─' + '─'*$w3 + '─┴─' + '─'*$w4 + '─┘')
}

function Show-StatusCurto {
    if ($emPico) {
        Write-Host "[pico] deepeco: HORÁRIO DE PICO (preço 2x) — a economia volta às $(ToLocal $fimPico) $tzLabel (daqui a $(Dur $ateEconomia))"
    } else {
        Write-Host "[eco] deepeco: ECONOMIA ATIVA (metade do preço de pico) — próximo pico às $(ToLocal $proxPicoIni) $tzLabel (daqui a $(Dur $proxPicoDelta))"
    }
}

# ── saída ────────────────────────────────────────────────────────────────────
if ($args.Count -gt 0 -and $args[0] -eq '--short') {
    if ($conf.ECO_ATIVO -ne '1') {
        Write-Host '[eco] deepeco: sem variação de preço por horário no momento (preço fixo).'
        exit 0
    }
    Show-StatusCurto
    Show-Tabela
    exit 0
}

Show-MundoDevBanner
Write-Host ("Agora:   {0} {1}  ·  {2} UTC" -f (ToLocal $now), $tzLabel, (ToHHMM $now))
if ($conf.ECO_ATIVO -ne '1') {
    Write-Host 'Status:  (i) a DeepSeek NÃO varia preço por horário no momento — preço fixo 24h.'
    Write-Host "         (Se isso mudar, atualize $confPath)"
} else {
    Write-Host ("Regime:  peak/off-peak — {0}" -f $conf.ECO_DESCONTO_LABEL)
    Show-StatusCurto
    Write-Host ''
    Show-Tabela
    Write-Host ''
    Write-Host 'Atenção: a doc oficial não define se vale o horário de INÍCIO ou de'
    Write-Host '   CONCLUSÃO da requisição (na política de 2025 valia a conclusão) —'
    Write-Host '   perto da fronteira do pico, dê margem nas tarefas longas.'
}
Write-Host "Fonte: $($conf.ECO_FONTE)"
