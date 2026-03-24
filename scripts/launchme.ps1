# =============================================================================
# My Brain Is Full - Crew :: Installer (PowerShell)
# =============================================================================
# Run this from inside the cloned repo, which should be inside your vault:
#
#   cd C:\path\to\your-vault\My-Brain-Is-Full-Crew
#   .\scripts\launchme.ps1
#
# It copies agents and references into your vault's .claude\ directory.
# =============================================================================

$ErrorActionPreference = 'Stop'

# ── Helpers ─────────────────────────────────────────────────────────────────
function info    { param([string]$msg) Write-Host "   > $msg" -ForegroundColor Cyan }
function success { param([string]$msg) Write-Host "   v $msg" -ForegroundColor Green }
function warn    { param([string]$msg) Write-Host "   ! $msg" -ForegroundColor Yellow }
function die     { param([string]$msg) Write-Host "`n   Error: $msg`n" -ForegroundColor Red; exit 1 }

# ── Find paths ──────────────────────────────────────────────────────────────
$ScriptDir = $PSScriptRoot
$RepoDir   = Split-Path $ScriptDir -Parent
$VaultDir  = Split-Path $RepoDir -Parent

# Sanity checks
if (-not (Test-Path "$RepoDir\agents")) { die "Can't find agents\ in $RepoDir — are you running this from the repo?" }
if (-not (Test-Path "$RepoDir\references")) { die "Can't find references\ in $RepoDir" }

# ── Banner ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║  My Brain Is Full - Crew :: Setup        ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""
Write-Host "   Repo:   " -NoNewline; Write-Host $RepoDir -ForegroundColor White
Write-Host "   Vault:  " -NoNewline; Write-Host $VaultDir -ForegroundColor White
Write-Host ""

# ── Confirm vault location ──────────────────────────────────────────────────
Write-Host "Is this your Obsidian vault folder?" -ForegroundColor White
Write-Host "   $VaultDir" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   y) Yes, install here"
Write-Host "   n) No, let me type the correct path"
$confirm = Read-Host "   > "

if ($confirm -match '^[Nn]$') {
    Write-Host ""
    Write-Host "Enter the full path to your Obsidian vault:" -ForegroundColor White
    $VaultDir = Read-Host "   > "
    $VaultDir = $VaultDir.TrimEnd('\')
    if (-not (Test-Path $VaultDir)) { die "Directory not found: $VaultDir" }
}

# ── Copy agents ──────────────────────────────────────────────────────────────
Write-Host ""
info "Creating .claude\agents\ in vault..."
New-Item -ItemType Directory -Force "$VaultDir\.claude\agents" | Out-Null

$agentCount = 0
Get-ChildItem "$RepoDir\agents\*.md" | ForEach-Object {
    Copy-Item $_.FullName "$VaultDir\.claude\agents\"
    $agentCount++
}
success "Copied $agentCount agents"

# ── Copy references ──────────────────────────────────────────────────────────
info "Creating .claude\references\ in vault..."
New-Item -ItemType Directory -Force "$VaultDir\.claude\references" | Out-Null
Copy-Item "$RepoDir\references\*.md" "$VaultDir\.claude\references\"
success "Copied references"

# ── Generate and copy skills (for Cowork/Desktop) ───────────────────────────
$skillCount = 0
$python = Get-Command python -ErrorAction SilentlyContinue
$generateScript = "$RepoDir\scripts\generate-skills.py"

if ($python -and (Test-Path $generateScript)) {
    info "Generating skills from agents..."
    $skillsTmp = Join-Path $env:TEMP ("mbif-skills-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force $skillsTmp | Out-Null

    $env:SKILLS_DIR = $skillsTmp
    & python $generateScript 2>$null | Out-Null
    Remove-Item Env:\SKILLS_DIR -ErrorAction SilentlyContinue

    $skillFiles = Get-ChildItem "$skillsTmp\*\SKILL.md" -ErrorAction SilentlyContinue
    if ($skillFiles) {
        info "Creating .claude\skills\ in vault..."
        Get-ChildItem $skillsTmp -Directory | ForEach-Object {
            $skillName = $_.Name
            $destDir = "$VaultDir\.claude\skills\$skillName"
            New-Item -ItemType Directory -Force $destDir | Out-Null
            Get-ChildItem $_.FullName | Copy-Item -Destination $destDir
            $skillCount++
        }
        success "Copied $skillCount skills"
    }

    Remove-Item $skillsTmp -Recurse -Force -ErrorAction SilentlyContinue
} else {
    warn "python not found — skipped skills generation (Cowork/Desktop won't have skills)"
    warn "Install Python 3 and re-run this script to enable Cowork/Desktop support"
}

# ── Copy CLAUDE.md ────────────────────────────────────────────────────────────
if (Test-Path "$RepoDir\CLAUDE.md") {
    Copy-Item "$RepoDir\CLAUDE.md" "$VaultDir\CLAUDE.md"
    success "Copied CLAUDE.md"
}

# ── MCP servers (Gmail + Calendar) ──────────────────────────────────────────
Write-Host ""
Write-Host "Do you use Gmail or Google Calendar?" -ForegroundColor White
Write-Host "   The Postman agent can read your inbox and calendar." -ForegroundColor DarkGray
Write-Host "   You can always add this later." -ForegroundColor DarkGray
Write-Host ""
Write-Host "   y) Yes, set up Gmail + Calendar"
Write-Host "   n) No, skip for now"
$mcpAnswer = Read-Host "   > "

if ($mcpAnswer -match '^[Yy]$') {
    if (Test-Path "$VaultDir\.mcp.json") {
        warn ".mcp.json already exists — skipping (won't overwrite)"
    } else {
        Copy-Item "$RepoDir\.mcp.json" "$VaultDir\.mcp.json"
        success "Created .mcp.json (Gmail + Google Calendar)"
    }
} else {
    info "Skipped MCP setup"
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "   Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "   Your vault is ready. Here's what was installed:"
Write-Host ""
Write-Host "   $VaultDir\"
Write-Host "   ├── .claude\"
Write-Host "   │   ├── agents\          " -NoNewline; Write-Host "<-- $agentCount crew agents (CLI)" -ForegroundColor DarkGray
Write-Host "   │   ├── skills\          " -NoNewline; Write-Host "<-- $skillCount crew skills (Cowork/Desktop)" -ForegroundColor DarkGray
Write-Host "   │   └── references\      " -NoNewline; Write-Host "<-- shared docs" -ForegroundColor DarkGray
Write-Host "   ├── CLAUDE.md            " -NoNewline; Write-Host "<-- project instructions" -ForegroundColor DarkGray
if ($mcpAnswer -match '^[Yy]$') {
    Write-Host "   └── .mcp.json            " -NoNewline; Write-Host "<-- Gmail + Calendar" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "   Next steps:" -ForegroundColor White
Write-Host "   1. Open Claude Code in your vault folder"
Write-Host '   2. Say: "Initialize my vault"'
Write-Host "   3. The Architect will guide you through setup"
Write-Host ""
Write-Host "   To update after a git pull: .\scripts\updateme.ps1" -ForegroundColor DarkGray
Write-Host ""
