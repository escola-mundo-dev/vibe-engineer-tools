# deepeco.ps1 — estamos na janela de economia da API DeepSeek agora?
# Versão Windows/PowerShell do `deepeco` da aula (PS 5.1 e 7).
#
#   deepeco            banner MUNDO DEV + status + tabela de horários/valores
#   deepeco --short    status + tabela, sem o banner (uso do deepclaude)
#
# Regime (vigente desde 16/08/2026): horários de PICO custam 2x e todo o
# resto do dia (17h) é economia (metade do pico). Picos definidos em UTC
# (relógio do SERVIDOR); conversão para o fuso local é automática.
# Regra nova de fim de semana (desde 2026-08-23 00:00 Pequim = 2026-08-22
# 16:00 UTC): no sábado e no domingo do fuso de PEQUIM (UTC+8) o dia inteiro
# é economia — picos NÃO valem. Dias úteis (seg a sex, Pequim) seguem o
# regime acima. Default: ON (1) — um conf antigo sem as chaves ECO_FDS_*
# aplica a regra nova; desligue com ECO_FDS_ECO_DIA_INTEIRO="0".
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
    ECO_FDS_ECO_DIA_INTEIRO = '1'          # default ON: 1 = fim de semana é economia o dia todo (0 desliga)
    ECO_FDS_VIGENCIA  = '2026-08-23'       # data de PEQUIM (AAAA-MM-DD) em que vale (default, se conf não trouxer)
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

# dias desde a época (1970-01-01) a partir de data civil — algoritmo de
# Howard Hinnant (date_algorithms.html), espelho do deepeco.sh. Usa
# [long] (evita overflow do Int32) e floor com números positivos-ok aqui.
# days_from_civil(2026,8,23) = 20688.
function DaysFromCivil([int]$y, [int]$m, [int]$d) {
    $yr = $y
    if ($m -le 2) { $yr = $y - 1 }
    $era = [math]::Floor($yr / 400.0)
    $yoe = $yr - $era * 400                          # [0, 399]
    $mm  = if ($m -gt 2) { $m - 3 } else { $m + 9 }
    $doy = [int][math]::Floor((153 * $mm + 2) / 5) + $d - 1   # [0, 365]
    $doe = $yoe * 365 + [int][math]::Floor($yoe / 4) - [int][math]::Floor($yoe / 100) + $doy
    return [long]($era * 146097 + $doe - 719468)
}

# Relógio (uma leitura só): DEEPECO_NOW="YYYY-MM-DD HH:MM" (UTC) substitui o
# relógio — hook de teste e preview (ver `deepeco --help`).
$nowAbs = 0L
if ($env:DEEPECO_NOW) {
    $parts = $env:DEEPECO_NOW.Trim() -split '\s+'
    $dparts = $parts[0].Split('-'); $hparts = $parts[1].Split(':')
    $ny = [int]$dparts[0]; $nm = [int]$dparts[1]; $nd = [int]$dparts[2]
    $nh = [int]$hparts[0]; $nmi = [int]$hparts[1]
    $nowAbs = (DaysFromCivil $ny $nm $nd) * 1440 + ($nh * 60 + $nmi)
    $now = $nh * 60 + $nmi
    $nowDayAbs = [long](DaysFromCivil $ny $nm $nd)
} else {
    $nowUtcDt = [DateTime]::UtcNow
    $now      = $nowUtcDt.Hour * 60 + $nowUtcDt.Minute
    $nowDayAbs = [long](DaysFromCivil $nowUtcDt.Year $nowUtcDt.Month $nowUtcDt.Day)
    $nowAbs = $nowDayAbs * 1440 + $now
}
$offMin   = [int][TimeZoneInfo]::Local.GetUtcOffset([DateTime]::UtcNow).TotalMinutes
$tzLabel  = 'UTC{0}{1}' -f ($(if ($offMin -ge 0) { '+' } else { '' })), [int][math]::Truncate($offMin / 60)
if ($offMin % 60 -ne 0) { $tzLabel += ':{0:d2}' -f [int][math]::Abs($offMin % 60) }
function ToLocal([int]$minUtc) { ToHHMM ((($minUtc + $offMin) % 1440 + 1440) % 1440) }

# ── fuso de Pequim (UTC+8 fixo, sem DST) e dia da semana ────────────────────
# bjDow: 1=seg .. 7=dom. dowUtc (0=dom .. 6=sáb, escala Hinnant) vem do dia
# civil absoluto; bump soma o "dia seguinte de Pequim" quando UTC já passou
# de 16h (Pequim = UTC+8).
$utcHour = [int][math]::Floor($now / 60)
$bump = [math]::Floor(($utcHour + 8) / 24)                        # 0 antes das 16h UTC, 1 depois
$dowUtc = ( ($nowDayAbs % 7) + 4 ) % 7                            # 0=dom .. 6=sáb
$bjDow  = ( ( ( $dowUtc - 1 + $bump ) % 7 + 7 ) % 7 ) + 1         # 1=seg .. 7=dom
$bjDayAbs = $nowDayAbs + $bump                                    # dia de Pequim absoluto

# ── vigência da regra de fim de semana (ECO_FDS_VIGENCIA "AAAA-MM-DD", Pequim) ─
# vigUtcMin = days_from_civil(y,m,d)*1440 − 480 (00:00 Pequim = 16:00 UTC do dia anterior).
# Âncora: ECO_FDS_VIGENCIA="2026-08-23" → vigUtcMin = 29790240.
$vigUtcMin = 0L
if ($conf.ECO_FDS_VIGENCIA) {
    $vp = ($conf.ECO_FDS_VIGENCIA.Trim() -split '-')
    $vigUtcMin = (DaysFromCivil [int]$vp[0] [int]$vp[1] [int]$vp[2]) * 1440 - 480
}

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

# ── fim de semana (regra nova): ECONOMIA o DIA TODO; picos não valem ────────
# Ativo = ECO_FDS_ECO_DIA_INTEIRO=1 E nowAbs >= vigUtcMin E bjDow ∈ {6,7}.
# "Próximo pico" nesse caso = o INÍCIO da PRIMEIRA janela de pico configurada
# ($pIni[0]) na próxima segunda de Pequim — derivado de ECO_PICOS_UTC, não
# hardcoded. Com as janelas padrão (01:00-04:00) $pIni[0]=60 → mesma saída.
# Âncoras: sáb 2026-08-29 07:00Z → 42h; dom 2026-08-30 07:00Z → 18h.
$fdsAtivo = $false
if ($conf.ECO_FDS_ECO_DIA_INTEIRO -eq '1' -and $nowAbs -ge $vigUtcMin -and ($bjDow -eq 6 -or $bjDow -eq 7)) {
    $fdsAtivo = $true
    $emPico = $false
    $diasAteSeg = (8 - $bjDow) % 7                       # sáb=2, dom=1
    $proxPicoIni = [int]$pIni[0]                         # início da 1ª janela de pico (UTC)
    $proxPicoDelta = [int](($bjDayAbs + $diasAteSeg) * 1440 + $proxPicoIni - $nowAbs)
}

# ── tabela de horários e valores (células ASCII: PadRight alinha por char) ──
function Show-Tabela {
    $mEco = '  '; $mPico = '  '
    if ($emPico) { $mPico = '> ' } else { $mEco = '> ' }
    $r2lbl = "${mPico}pico (2x)"
    $c1 = @('faixa', "${mEco}economia", $r2lbl)
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
    if ($fdsAtivo) {
        $picoBj = ($proxPicoIni + 480) % 1440            # horário de Pequim
        $picoLocal = ToLocal $proxPicoIni
        Write-Host "[eco] deepeco: ECONOMIA o DIA TODO (fim de semana — fuso de Pequim); primeiro pico da próxima semana (segunda de Pequim): $(ToHHMM $picoBj) Pequim (= $(ToHHMM $proxPicoIni) UTC = $picoLocal $tzLabel)"
    } elseif ($emPico) {
        Write-Host "[pico] deepeco: HORÁRIO DE PICO (preço 2x) — a economia volta às $(ToLocal $fimPico) $tzLabel (daqui a $(Dur $ateEconomia))"
    } else {
        Write-Host "[eco] deepeco: ECONOMIA ATIVA (metade do preço de pico) — próximo pico às $(ToLocal $proxPicoIni) $tzLabel (daqui a $(Dur $proxPicoDelta))"
    }
}

# ── saída ────────────────────────────────────────────────────────────────────
# Paridade com o deepeco.sh (e com `deepclaude --help`): --help responde, e
# flag desconhecida ERRA em vez de cair no caminho normal imprimindo a tabela.
if ($args.Count -gt 0 -and ($args[0] -eq '-h' -or $args[0] -eq '--help')) {
    Write-Host @"
deepeco — a API DeepSeek está em horário de economia ou de pico agora?

  deepeco            banner MUNDO DEV + status + tabela de horários e tarifas
  deepeco --short    só status + tabela (é o que o ``deepclaude`` imprime ao subir)
  deepeco --help     esta ajuda

Dentro de uma sessão do deepclaude: /eco

Regime (desde 16/08/2026 16:00 UTC): os picos custam 2x e todo o resto do dia
(17h) é economia — metade do preço de pico, para todos os modelos. As janelas
são definidas em UTC pelo relógio do SERVIDOR da API; este comando converte
para o SEU fuso automaticamente.

Regra de fim de semana (desde 2026-08-23 00:00 de Pequim = 2026-08-22 16:00
UTC): no sábado e no domingo do fuso de PEQUIM (UTC+8) o dia inteiro é
economia — os picos NÃO valem. Dias úteis (seg a sex, Pequim) seguem o regime
acima. Desligue com ECO_FDS_ECO_DIA_INTEIRO="0" no conf.

Janela, tarifas e vigência vivem em:
  $confPath
Quando a DeepSeek mudar a política, edite esse arquivo — não este script.

Ambiente:
  DEEPECO_CONF        caminho do conf (default: ~\.config\aula-dev\deepeco.conf)
  DEEPECO_NOW="YYYY-MM-DD HH:MM"  simula o relógio nesse instante (UTC) — teste
                          e preview (ex.: ver "como estará amanhã")
  MUNDO_DEV_BANNER=0  desliga o banner
"@
    exit 0
}
if ($args.Count -gt 0 -and $args[0] -ne '--short') {
    Write-Host "deepeco: flag desconhecida '$($args[0])' (veja: deepeco --help)" -ForegroundColor Red
    exit 2
}

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
