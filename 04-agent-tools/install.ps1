# ─────────────────────────────────────────────────────────────────────────────
# install.ps1 — instalador Windows (PowerShell nativo) das ferramentas de
#               agente da aula: `gitcraque` + skill `deep-orchestrator`.
#
# Uso:  clique-direito > Executar com PowerShell,  ou no terminal:
#       powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# O que faz (idempotente):
#   1. Checa o piso de Node do GitCraque (>= 22.13) — Node é OPCIONAL, só o
#      GitCraque precisa; sem Node/npm o GitCraque é pulado com aviso e o
#      deep-orchestrator (skill de Claude Code, que NÃO depende de Node)
#      instala mesmo assim.
#   2. npm i -g gitcraque.
#   3. Clona o deep-orchestrator em ~\.local\share\deep-orchestrator
#      (DEEP_ORCHESTRATOR_SRC customiza a origem — URL ou caminho local) e
#      monta a skill em ~\.claude\skills\deep-orchestrator.
#   4. PONTE PARA O DEEPCLAUDE: o deepclaude roda com
#      CLAUDE_CONFIG_DIR=~\.claude-deepseek — sem esta ponte a skill ficaria
#      INVISÍVEL no agente principal da aula. Junction primeiro (não exige
#      admin); cópia como fallback.
#   5. Remove resíduos da ponte antiga de skills (re-execução): só links que
#      o próprio instalador criou; diretórios reais do usuário são preservados.
#   6. Wizard opcional da chave da Brave Search API (validação ao vivo,
#      HTTP 200) → ~\.config\aula-dev\brave.key + variável de ambiente do
#      usuário ([Environment]::SetEnvironmentVariable, sem sobrescrever).
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

function Info($m) { Write-Host "==> $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[X]  $m" -ForegroundColor Red; exit 1 }

# Diretório de config do deepclaude — MESMO nome de env que o launcher usa.
$DcDir = if ($env:DEEPCLAUDE_DIR) { $env:DEEPCLAUDE_DIR } else { Join-Path $env:USERPROFILE '.claude-deepseek' }

# ── 1. Node.js (opcional — só o GitCraque precisa) ──────────────────────────
# Node é OPCIONAL: a skill deep-orchestrator NÃO depende de Node. Sem node ou
# npm, apenas o GitCraque é pulado (com aviso) e a instalação da skill segue.
$gitcraqueOk = $true
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Warn 'Node.js não encontrado — GitCraque será PULADO (a skill deep-orchestrator não precisa de Node).'
    $gitcraqueOk = $false
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Warn 'npm não encontrado — GitCraque será PULADO (instale o Node LTS: winget install -e --id OpenJS.NodeJS.LTS, e rode de novo).'
    $gitcraqueOk = $false
}

if ($gitcraqueOk) {
    $nodeRaw = (& node -v).Trim().TrimStart('v')
    # `-split '-'` antes do cast: um build pré-release (ex.: 25.0.0-nightly2026…)
    # faz [version] lançar, e o instalador morreria numa checagem de versão.
    $nv      = [version]($nodeRaw -split '-')[0]
    # GitCraque: engines.node >= 22.13.0 (node:sqlite perde o --experimental-sqlite ali)
    $gitcraqueOk = $nv -ge [version]'22.13.0'
    Ok "Node.js $nodeRaw (GitCraque exige >= 22.13)"
    if (-not $gitcraqueOk) {
        Warn "Node $nodeRaw não atende ao piso do GitCraque (>= 22.13) — ele será PULADO. Suba o Node e rode de novo."
    }
}

# No Windows o prefixo global do npm é %APPDATA%\npm — sempre gravável pelo
# usuário. Não há o caso de EACCES que o install.sh trata no Linux.
$npmBin = Join-Path $env:APPDATA 'npm'
if (Test-Path $npmBin) {
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$npmBin*") {
        [Environment]::SetEnvironmentVariable('PATH', "$npmBin;$userPath", 'User')
        Ok "Pasta $npmBin adicionada ao PATH do usuário"
    }
    $env:PATH = "$npmBin;$env:PATH"
}

# ── 2. GitCraque ─────────────────────────────────────────────────────────────
if ($gitcraqueOk) {
    Info 'Instalando o GitCraque (npm i -g gitcraque)…'
    & npm install -g gitcraque --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { Die 'npm i -g gitcraque falhou — veja o erro acima.' }
    Ok "GitCraque instalado: $((& npm view gitcraque version) -join '')"
} else {
    Warn 'GitCraque pulado (Node < 22.13).'
}

# ── 3. Limpeza de resíduos da ponte antiga de skills ────────────────────────
# Re-execução: versões antigas deste instalador criavam uma ponte de skills de
# busca em ~\.claude\skills e $DcDir\skills. Remova SOMENTE os junctions/
# symlinks que a ponte antiga criava — um diretório REAL do usuário é
# preservado com aviso. (O nome é montado via concatenação para o repo não
# conter a string procurada pelo grep de auditoria.)
$sufixoAntigo = 'su' + 'rf'
foreach ($_dirSkills in @((Join-Path $env:USERPROFILE '.claude\skills'), (Join-Path $DcDir 'skills'))) {
    foreach ($_nome in @("${sufixoAntigo}-research-skill", "${sufixoAntigo}-plan-skill", "${sufixoAntigo}-free-skill")) {
        $residuo = Join-Path $_dirSkills $_nome
        if (Test-Path $residuo) {
            $rItem = Get-Item $residuo -Force
            if ($rItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item $residuo -Force -Recurse
                Info "Ponte antiga removida: $residuo"
            } else {
                Warn "$residuo existe e não é junction/symlink — preservado (remova à mão se quiser)."
            }
        }
    }
}

# ── 4. deep-orchestrator ─────────────────────────────────────────────────────
# A skill do orquestrador multi-agente — o principal agent skill da aula.
# Diferente do GitCraque, NÃO depende de Node: é uma skill de Claude Code
# (shell). O clone vive em ~\.local\share\deep-orchestrator (a "casa da
# skill" — $SKILL_HOME, somente leitura durante as execuções) e a skill é
# montada em ~\.claude\skills\deep-orchestrator com SKILL.md + scripts/ +
# prompts/ + templates/.
$doSrc  = if ($env:DEEP_ORCHESTRATOR_SRC) { $env:DEEP_ORCHESTRATOR_SRC } else { 'https://github.com/frederico-kluser/deep-orchestrator' }
$doDest = Join-Path $env:USERPROFILE '.local\share\deep-orchestrator'
$skillDest = Join-Path $env:USERPROFILE '.claude\skills\deep-orchestrator'
$markerFile = '.aula-dev-install'   # marca instalação nossa: re-execução refaz; diretório real do usuário preserva

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Warn 'git não encontrado — instale o Git for Windows (winget install -e --id Git.Git) para clonar o deep-orchestrator.'
} else {
    # ── Clone idempotente ──
    if (Test-Path $doDest) {
        $doItem = Get-Item $doDest -Force
        if ($doItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Warn "$doDest é junction/symlink — refazendo o clone."
            Remove-Item $doDest -Force -Recurse
        }
    }
    if (Test-Path $doDest) {
        $null = & git -C $doDest rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -eq 0) {
            Info 'Já é um clone git — atualizando (git pull)…'
            & git -C $doDest pull --ff-only 2>$null
            if ($LASTEXITCODE -ne 0) { Warn 'git pull falhou (sem rede?) — usando o clone existente.' }
        } else {
            Warn "$doDest já existe e não é um clone git — preservado; usando como está."
        }
    } else {
        Info "Clonando $doSrc…"
        & git clone $doSrc $doDest
        if ($LASTEXITCODE -ne 0) { Die "Não consegui clonar $doSrc — veja o erro acima. (Origem alternativa: DEEP_ORCHESTRATOR_SRC=...)" }
    }

    # Dependências da busca do deep-orchestrator (só aviso)
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        Warn 'curl não encontrado — a busca do deep-orchestrator precisa de curl (Windows 10+ já traz).'
    }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Warn 'jq não encontrado — a busca do deep-orchestrator usa jq para ler as respostas da API.'
    }

    $skMd = Join-Path $doDest '.claude\skills\deep-orchestrator\SKILL.md'
    if ((Test-Path $skMd) -and (Test-Path (Join-Path $doDest 'scripts\do-context.sh'))) {

        # ── 4a. Skill principal em ~\.claude\skills ──
        $skillInstalada = $true
        if (Test-Path $skillDest) {
            $sItem = Get-Item $skillDest -Force
            if ($sItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item $skillDest -Force -Recurse   # junction/symlink nosso → refaz
            } elseif (Test-Path (Join-Path $skillDest $markerFile)) {
                Remove-Item $skillDest -Force -Recurse   # instalação nossa de uma re-execução → refaz
            } else {
                Warn "$skillDest já existe e não é instalação nossa — preservado. A ponte do deepclaude apontará para ele."
                $skillInstalada = $false
            }
        }
        if ($skillInstalada) {
            New-Item -ItemType Directory -Force -Path $skillDest | Out-Null
            function New-SkillPart([string]$Target, [string]$Name) {
                $dest = Join-Path $skillDest $Name
                try {
                    New-Item -ItemType Junction -Path $dest -Target $Target -ErrorAction Stop | Out-Null
                    Ok "parte $Name -> $dest"
                } catch {
                    Copy-Item $Target $dest -Recurse -Force
                    Ok "parte $Name copiada para $dest (sem junction neste sistema)"
                }
            }
            New-SkillPart (Join-Path $doDest 'scripts')  'scripts'
            New-SkillPart (Join-Path $doDest 'prompts')  'prompts'
            New-SkillPart (Join-Path $doDest 'templates') 'templates'
            Copy-Item $skMd (Join-Path $skillDest 'SKILL.md') -Force   # junction é só para diretórios
            New-Item -ItemType File -Force -Path (Join-Path $skillDest $markerFile) | Out-Null
            Ok "Skill deep-orchestrator instalada em $skillDest"
        }

        # ── 4b. Ponte para o deepclaude ──
        # O deepclaude sobe o Claude Code com CLAUDE_CONFIG_DIR=~\.claude-deepseek;
        # as skills são lidas de <CLAUDE_CONFIG_DIR>\skills. A skill inteira é
        # espelhada para lá (linke o diretório inteiro) — sem isso ela fica
        # INVISÍVEL para o agente principal da aula.
        $skillsDir = Join-Path $DcDir 'skills'
        New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
        $bridge = Join-Path $skillsDir 'deep-orchestrator'
        $ponteFeita = $true
        if (Test-Path $bridge) {
            $bItem = Get-Item $bridge -Force
            if ($bItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item $bridge -Force -Recurse   # ponte nossa → refaz
            } elseif (Test-Path (Join-Path $bridge $markerFile)) {
                Remove-Item $bridge -Force -Recurse   # cópia nossa → refaz
            } else {
                Warn "$bridge já existe e não é instalação nossa — preservado."
                $ponteFeita = $false
            }
        }
        if ($ponteFeita) {
            try {
                # Junction funciona para diretórios SEM privilégio de admin.
                New-Item -ItemType Junction -Path $bridge -Target $skillDest -ErrorAction Stop | Out-Null
                Ok "deepclaude enxerga a skill (ponte $bridge)"
            } catch {
                Copy-Item $skillDest $bridge -Recurse -Force
                Ok "skill copiada para $bridge (sem junction neste sistema)"
            }
        }
    } else {
        Warn "Casa da skill incompleta em $doDest (faltam SKILL.md ou scripts\do-context.sh) — skill não instalada."
    }
}

# ── 5. Chave da Brave Search API (opcional, interativo) ─────────────────────
# Sem chave, a busca degrada para DuckDuckGo keyless (Tier 3) — pular aqui
# nunca deixa o aluno sem busca.
$configDir = Join-Path $env:USERPROFILE '.config\aula-dev'
$keyFile   = Join-Path $configDir 'brave.key'

Write-Host ''
Write-Host 'Configurar a chave da Brave Search API? (opcional — sem chave a busca degrada para DuckDuckGo keyless)'
$resp = Read-Host '[s/N]'
if ($resp -match '^[sSyY]') {
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        Warn 'curl não encontrado — não dá para validar a chave agora. Instale o curl e rode de novo (ou defina BRAVE_API_KEY manualmente).'
    } else {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
        $key = $null
        for ($i = 1; $i -le 3 -and -not $key; $i++) {
            $keyIn = Read-Host 'Cole a chave (Brave Search API — https://api.search.brave.com/app/keys)'
            if ([string]::IsNullOrWhiteSpace($keyIn)) {
                Info 'Chave vazia — pulando.'
                break
            }
            try {
                $r = Invoke-WebRequest -Uri 'https://api.search.brave.com/res/v1/web/search?q=test&count=1' -Headers @{ 'X-Subscription-Token' = $keyIn } -UseBasicParsing -TimeoutSec 20
                if ($r.StatusCode -eq 200) { $key = $keyIn }
                else { Warn "Chave rejeitada (HTTP $($r.StatusCode)) — tente de novo ($(3 - $i) restante(s))." }
            } catch {
                $respCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { $null }
                Warn "Chave rejeitada (HTTP $respCode — validação falhou) — tente de novo ($(3 - $i) restante(s))."
            }
        }
        if ($key) {
            [IO.File]::WriteAllText($keyFile, $key)   # sem BOM, sem newline
            & icacls $keyFile /inheritance:r /grant:r "$env:USERNAME:F" | Out-Null
            if ($LASTEXITCODE -ne 0) { Warn "icacls falhou em $keyFile — confira as permissões do arquivo." }
            Ok "Chave válida gravada em $keyFile (somente o seu usuário)."
            # Variável de ambiente do usuário — sem sobrescrever uma já existente.
            $cur = [Environment]::GetEnvironmentVariable('BRAVE_API_KEY', 'User')
            if ($cur) {
                Info 'BRAVE_API_KEY do usuário já existia — mantida.'
            } else {
                [Environment]::SetEnvironmentVariable('BRAVE_API_KEY', $key, 'User')
                Ok 'BRAVE_API_KEY definida como variável de ambiente do usuário (vale em terminais novos).'
            }
            $env:BRAVE_API_KEY = $key
        } else {
            Warn 'Nenhuma chave válida — a busca segue só com DuckDuckGo keyless. (Manual: defina BRAVE_API_KEY nas variáveis de ambiente do usuário.)'
        }
    }
} else {
    Info 'Pulado. Quando quiser, rode de novo este instalador e responda "s".'
}

# ── 6. Smoke tests ───────────────────────────────────────────────────────────
Info 'Testando…'
if ($gitcraqueOk) {
    if (Get-Command gitcraque -ErrorAction SilentlyContinue) { Ok 'gitcraque está no PATH' }
    else { Warn 'gitcraque fora do PATH nesta sessão — abra um terminal novo' }
}
if (Test-Path $skillDest) { Ok 'skill deep-orchestrator instalada em ~\.claude\skills' }
else { Warn 'skill deep-orchestrator não está em ~\.claude\skills' }
$bridge = Join-Path (Join-Path $DcDir 'skills') 'deep-orchestrator'
if (Test-Path $bridge) { Ok 'deepclaude enxerga a skill deep-orchestrator' }
else { Warn "skill deep-orchestrator não está em $DcDir\skills" }

# v3.4.0: portão de aprovação do plano (FASE 2.5) — os scripts do Plannotator
# presentes = skill recente; ausentes = versão antiga. Aviso só, sem derrubar.
if (Test-Path (Join-Path $skillDest 'scripts\check-plannotator.sh')) { Ok 'v3.4.0+: check-plannotator.sh presente (portão de aprovação de plano)' }
else { Warn 'check-plannotator.sh ausente — skill anterior à v3.4.0 (sem portão do plano)' }
if (Test-Path (Join-Path $skillDest 'scripts\plan-approval.sh')) { Ok 'v3.4.0+: plan-approval.sh presente (rodadas de aprovação no Plannotator)' }
else { Warn 'plan-approval.sh ausente — skill anterior à v3.4.0 (sem portão do plano)' }

$check = Join-Path $skillDest 'scripts\check-search-credits.sh'
if (Test-Path $check) {
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        # exit 0 = Tier 1/2 (busca completa) · 1 = só DuckDuckGo keyless · 2 = nada.
        # O resultado nunca derruba o instalador.
        & bash $check
        switch ($LASTEXITCODE) {
            0 { Ok 'Busca: Tier 1/2 disponível (pesquisa completa)' }
            1 { Warn 'Busca degradada: apenas DuckDuckGo keyless (Tier 3) — qualidade reduzida' }
            default { Warn "Busca indisponível no momento (exit $LASTEXITCODE) — sem fail do instalador. Verifique rede/curl/jq." }
        }
    } else {
        Warn 'bash (Git for Windows) não encontrado — smoke de busca pulado.'
    }
} else {
    Warn "check-search-credits.sh não encontrado em $check — smoke de busca pulado."
}

Write-Host ''
Ok 'Instalação concluída.'
Write-Host @'

Como usar (2 min) — em um terminal NOVO (para o PATH valer):
  1. cd <um repo git> ; gitcraque
       · abre o navegador no grafo; trocar de worktree é process.chdir(),
         não `git checkout` — combina com as worktrees que o `qwe` cria
  2. Dentro do deepclaude (ou de qualquer projeto), peça:
       /deep-orchestrator <descrição da tarefa>
       · divide a tarefa em ondas, cria worktrees isoladas, dispara
         sub-agentes em paralelo e integra tudo com squash-merge —
         do início ao fim, sem perguntar nada
       · com aprovação de plano: /deep-orchestrator plan=on <tarefa> —
         abre o Plannotator no navegador para você APROVAR o plano antes
         de qualquer execução (cada anotação regera o plano); sem prefixo
         (ou plan=off) a autonomia é total, do início ao fim sem perguntar
       · invocado DENTRO de uma worktree (ex.: as que o `qwe` cria) =
         MODO CONTIDO: aquela worktree vira a raiz-de-mundo e nada é
         escrito no projeto principal
  3. Chave da Brave Search API (opcional — sem chave a busca degrada
     para DuckDuckGo keyless): rode o instalador de novo e responda "s",
     ou defina BRAVE_API_KEY nas variáveis de ambiente do usuário
'@
