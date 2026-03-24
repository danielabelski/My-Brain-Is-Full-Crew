# =============================================================================
# My Brain Is Full - Crew :: Updater (PowerShell)
# =============================================================================
# After pulling new changes from the repo, run this to update the agents
# in your vault:
#
#   cd C:\path\to\your-vault\My-Brain-Is-Full-Crew
#   git pull
#   .\scripts\updateme.ps1
#
# =============================================================================

$ErrorActionPreference = 'Stop'

# ── Helpers ─────────────────────────────────────────────────────────────────
function info    { param([string]$msg) Write-Host "   > $msg" -ForegroundColor Cyan }
function success { param([string]$msg) Write-Host "   v $msg" -ForegroundColor Green }
function warn    { param([string]$msg) Write-Host "   ! $msg" -ForegroundColor Yellow }
function die     { param([string]$msg) Write-Host "`n   Error: $msg`n" -ForegroundColor Red; exit 1 }

function FilesAreDifferent {
    param([string]$src, [string]$dst)
    if (-not (Test-Path $dst)) { return $true }
    $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
    return $srcHash -ne $dstHash
}

# ── Find paths ──────────────────────────────────────────────────────────────
$ScriptDir = $PSScriptRoot
$RepoDir   = Split-Path $ScriptDir -Parent
$VaultDir  = Split-Path $RepoDir -Parent

if (-not (Test-Path "$RepoDir\agents")) { die "Can't find agents\ — are you running this from the repo?" }

# ── Check vault has been set up ─────────────────────────────────────────────
if (-not (Test-Path "$VaultDir\.claude\agents")) {
    die "No .claude\agents\ found in $VaultDir — run launchme.ps1 first"
}

# ── Banner ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║  My Brain Is Full - Crew :: Update       ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

# ── Update agents ─────────────────────────────────────────────────────────
$agentCount = 0
Get-ChildItem "$RepoDir\agents\*.md" | ForEach-Object {
    $name = $_.Name
    $dst  = "$VaultDir\.claude\agents\$name"
    if (FilesAreDifferent $_.FullName $dst) {
        Copy-Item $_.FullName $dst
        if (Test-Path $dst) {
            info "Updated $name"
        } else {
            info "Added $name (new agent)"
        }
        $agentCount++
    }
}

# ── Update references ────────────────────────────────────────────────────
$refCount = 0
New-Item -ItemType Directory -Force "$VaultDir\.claude\references" | Out-Null
Get-ChildItem "$RepoDir\references\*.md" | ForEach-Object {
    $name = $_.Name
    $dst  = "$VaultDir\.claude\references\$name"
    if (FilesAreDifferent $_.FullName $dst) {
        Copy-Item $_.FullName $dst
        info "Updated reference: $name"
        $refCount++
    }
}

# ── Regenerate and update skills ─────────────────────────────────────────
$skillCount = 0
$python = Get-Command python -ErrorAction SilentlyContinue
$generateScript = "$RepoDir\scripts\generate-skills.py"

if ($python -and (Test-Path $generateScript)) {
    $skillsTmp = Join-Path $env:TEMP ("mbif-skills-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force $skillsTmp | Out-Null

    $env:SKILLS_DIR = $skillsTmp
    & python $generateScript 2>$null | Out-Null
    Remove-Item Env:\SKILLS_DIR -ErrorAction SilentlyContinue

    $skillFiles = Get-ChildItem "$skillsTmp\*\SKILL.md" -ErrorAction SilentlyContinue
    if ($skillFiles) {
        foreach ($skillFile in $skillFiles) {
            $skillName = Split-Path (Split-Path $skillFile.FullName -Parent) -Leaf
            $dst = "$VaultDir\.claude\skills\$skillName\SKILL.md"
            if (FilesAreDifferent $skillFile.FullName $dst) {
                New-Item -ItemType Directory -Force "$VaultDir\.claude\skills\$skillName" | Out-Null
                Copy-Item $skillFile.FullName $dst
                info "Updated skill: $skillName"
                $skillCount++
            }
        }
    }

    Remove-Item $skillsTmp -Recurse -Force -ErrorAction SilentlyContinue
} else {
    warn "python not found — skipped skills update"
}

# ── Update CLAUDE.md ────────────────────────────────────────────────────────
$claudeMdUpdated = $false
if (Test-Path "$RepoDir\CLAUDE.md") {
    if (FilesAreDifferent "$RepoDir\CLAUDE.md" "$VaultDir\CLAUDE.md") {
        Copy-Item "$RepoDir\CLAUDE.md" "$VaultDir\CLAUDE.md"
        info "Updated CLAUDE.md"
        $claudeMdUpdated = $true
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
if ($agentCount -eq 0 -and $refCount -eq 0 -and $skillCount -eq 0 -and -not $claudeMdUpdated) {
    success "Everything is already up to date!"
} else {
    success "Updated $agentCount agent(s), $skillCount skill(s), and $refCount reference(s)"
}
Write-Host ""
Write-Host "   Restart Claude Code to pick up the changes." -ForegroundColor DarkGray
Write-Host ""
