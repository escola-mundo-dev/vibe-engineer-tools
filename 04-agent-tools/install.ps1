# ─────────────────────────────────────────────────────────────────────────────
# install.ps1 — instalador Windows (PowerShell nativo) das ferramentas de
#               agente da aula: `gitcraque` + `surf-skill`.
#
# Uso:  clique-direito > Executar com PowerShell,  ou no terminal:
#       powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# O que faz (idempotente):
#   1. Checa os DOIS pisos de Node: surf-skill >= 18 · GitCraque >= 22.13.
#   2. npm i -g gitcraque · npm i -g surf-skill.
#   3. ⚠️ PONTE DAS SKILLS: o postinstall do surf-skill só conhece
#      ~\.claude\skills, ~\.agents\skills, ~\.codex\skills e ~\.pi\agent\skills.
#      O `deepclaude` roda com CLAUDE_CONFIG_DIR=~\.claude-deepseek — sem esta
#      ponte as skills ficariam INVISÍVEIS no agente principal da aula.
#      Junction primeiro (não exige admin); cópia como fallback.
#   4. Oferece o wizard de chaves do surf (`surf`), com validação ao vivo.
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

# ── 1. Node.js: dois pisos de versão ────────────────────────────────────────
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Die 'Node.js não encontrado — instale o Node LTS (winget install -e --id OpenJS.NodeJS.LTS) e rode de novo.'
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Die 'npm não encontrado — reinstale o Node.js e rode de novo.'
}

$nodeRaw = (& node -v).Trim().TrimStart('v')
# `-split '-'` antes do cast: um build pré-release (ex.: 25.0.0-nightly2026…)
# faz [version] lançar, e o instalador morreria numa checagem de versão.
$nv      = [version]($nodeRaw -split '-')[0]
# surf-skill: engines.node >= 18
if ($nv.Major -lt 18) { Die "Node $nodeRaw é antigo demais (surf-skill exige >= 18)." }
# GitCraque: engines.node >= 22.13.0 (node:sqlite perde o --experimental-sqlite ali)
$gitcraqueOk = $nv -ge [version]'22.13.0'
Ok "Node.js $nodeRaw (surf-skill exige >= 18 · GitCraque exige >= 22.13)"
if (-not $gitcraqueOk) {
    Warn "Node $nodeRaw não atende ao piso do GitCraque (>= 22.13) — ele será PULADO. Suba o Node e rode de novo."
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

# ── 3. surf-skill ────────────────────────────────────────────────────────────
Info 'Instalando o surf-skill (npm i -g surf-skill)…'
# O postinstall do pacote cria os symlinks/junctions das 3 skills nas 4 pastas
# de harness conhecidas e o ~\.config\surf\keys.json.
& npm install -g surf-skill --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { Die 'npm i -g surf-skill falhou — veja o erro acima.' }
Ok "surf-skill instalado: $((& npm view surf-skill version) -join '')"

# ── 4. Ponte das skills para o deepclaude ───────────────────────────────────
Info "Ligando as skills do surf ao deepclaude ($DcDir\skills)…"
$npmRoot   = (& npm root -g).Trim()
$surfRoot  = Join-Path $npmRoot 'surf-skill'
if (-not (Test-Path $surfRoot)) {
    Warn "Não achei o pacote em $surfRoot — pulando a ponte de skills."
} else {
    $skillsDir = Join-Path $DcDir 'skills'
    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null

    function New-SkillLink([string]$Name, [string]$Target) {
        $link = Join-Path $skillsDir $Name
        if (-not (Test-Path $Target)) { Warn "skill '$Name' não encontrada em $Target — pulada"; return }
        if (Test-Path $link) {
            $item = Get-Item $link -Force
            # ReparsePoint = junction/symlink nosso → pode refazer. Pasta real
            # (cópia do usuário) fica intacta.
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item $link -Force -Recurse
            } else {
                Warn "$link já existe e não é junction — preservado (remova à mão se quiser a versão do npm)"
                return
            }
        }
        try {
            # Junction funciona para diretórios SEM privilégio de admin.
            New-Item -ItemType Junction -Path $link -Target $Target -ErrorAction Stop | Out-Null
            Ok "skill $Name -> $link"
        } catch {
            Copy-Item $Target $link -Recurse -Force
            Ok "skill $Name copiada para $link (sem junction neste sistema)"
        }
    }

    New-SkillLink 'surf-research-skill' $surfRoot
    New-SkillLink 'surf-plan-skill'     (Join-Path $surfRoot 'skills\surf-plan-skill')
    New-SkillLink 'surf-free-skill'     (Join-Path $surfRoot 'skills\surf-free-skill')
}

# ── 5. Chaves do surf (opcional, interativo) ────────────────────────────────
# `surf-free-skill` funciona SEM chave — pular aqui nunca deixa o aluno sem pesquisa.
Write-Host ''
Write-Host 'Configurar agora as chaves de pesquisa do surf? (Tavily / Parallel / Brave / OpenRouter)'
$resp = Read-Host 'Pular é seguro: o surf-free-skill pesquisa sem chave nenhuma. [s/N]'
if ($resp -match '^[sSyY]') {
    try { & surf } catch { Warn 'Wizard não concluiu — rode depois: surf' }
} else {
    Info 'Pulado. Quando quiser: `surf` (chaves de busca) e `surf-research-skill ai-setup` (chave OpenRouter do surf-ai).'
}

# ── 6. Smoke tests ───────────────────────────────────────────────────────────
Info 'Testando…'
if (Get-Command surf-search-normal -ErrorAction SilentlyContinue) { Ok 'surf-search-normal está no PATH' }
else { Warn 'surf-search-normal fora do PATH nesta sessão — abra um terminal novo' }
if ($gitcraqueOk) {
    if (Get-Command gitcraque -ErrorAction SilentlyContinue) { Ok 'gitcraque está no PATH' }
    else { Warn 'gitcraque fora do PATH nesta sessão — abra um terminal novo' }
}
foreach ($s in 'surf-research-skill', 'surf-plan-skill', 'surf-free-skill') {
    if (Test-Path (Join-Path $DcDir "skills\$s")) { Ok "deepclaude enxerga a skill $s" }
    else { Warn "skill $s não está em $DcDir\skills" }
}

Write-Host ''
Ok 'Instalação concluída.'
Write-Host @'

Como usar (2 min) — em um terminal NOVO (para o PATH valer):
  1. cd <um repo git> ; gitcraque
       · abre o navegador no grafo; trocar de worktree é process.chdir(),
         não `git checkout` — combina com as worktrees que o `qwe` cria
  2. surf-free-skill "sua pergunta"        → pesquisa sem chave nenhuma
  3. surf                                  → adiciona chaves (validadas ao vivo)
     surf-research-skill ai-setup          → chave OpenRouter que move o surf-ai
  4. Dentro de um projeto, uma vez por projeto:
       surf-research-skill project-config  → sobe o timeout do Bash do harness
  5. Dentro do deepclaude, peça: "pesquise na web sobre X" ou "faça um plano para Y"
'@
