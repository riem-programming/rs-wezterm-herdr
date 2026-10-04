#Requires -Version 7.0
<#
.SYNOPSIS
  Installs the WezTerm + herdr + LazyVim terminal environment (user scope, no admin).

.DESCRIPTION
  1. Installs tools with winget (skipped with -SkipTools; already-installed tools are skipped).
  2. Installs herdr with its official installer, only if it is not present.
  3. Backs up every existing target to <name>.bak-<timestamp>, then copies the configs.
  4. Reloads the herdr config if the herdr server is running.

  Safe to re-run. With -DryRun nothing is installed, copied or changed.

.PARAMETER SkipTools
  Do not install any tools (winget packages or herdr); only copy configuration.

.PARAMETER DryRun
  Print what would happen without writing anything.

.EXAMPLE
  pwsh ./install.ps1 -DryRun -SkipTools
#>
[CmdletBinding()]
param(
    [switch]$SkipTools,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# winget id -> friendly name
$WingetPackages = [ordered]@{
    'wez.wezterm'                    = 'WezTerm'
    'Git.Git'                        = 'Git (provides Git Bash)'
    'junegunn.fzf'                   = 'fzf'
    'jqlang.jq'                      = 'jq'
    'Neovim.Neovim'                  = 'Neovim'
    'zig.zig'                        = 'Zig (C compiler for treesitter)'
    'sharkdp.fd'                     = 'fd'
    'JesseDuffield.lazygit'          = 'lazygit'
    'tree-sitter.tree-sitter-cli'    = 'tree-sitter CLI'
    'OpenJS.NodeJS.LTS'              = 'Node.js LTS'
    'Microsoft.PowerShell'           = 'PowerShell 7'
    'DEVCOM.JetBrainsMonoNerdFont'   = 'JetBrainsMono Nerd Font'
}

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Note([string]$Message) { Write-Host "    $Message" }
function Write-Plan([string]$Message) { Write-Host "    [dry-run] $Message" -ForegroundColor Yellow }

function Find-GitBash {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    # Custom install location: registry written by the Git for Windows installer.
    foreach ($hive in 'HKLM:', 'HKCU:') {
        $key = Get-ItemProperty -Path "$hive\SOFTWARE\GitForWindows" -ErrorAction SilentlyContinue
        if ($key -and $key.InstallPath) {
            $bash = Join-Path $key.InstallPath 'bin\bash.exe'
            if (Test-Path -LiteralPath $bash) { return $bash }
        }
    }
    # Last resort: walk up from git.exe on PATH until <root>\bin\bash.exe exists.
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) {
        $dir = Split-Path $git.Source
        while ($dir) {
            $bash = Join-Path $dir 'bin\bash.exe'
            if (Test-Path -LiteralPath $bash) { return $bash }
            $dir = Split-Path $dir
        }
    }
    return $null
}

function Backup-Existing([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $backup = "$Path.bak-$Stamp"
    if ($DryRun) { Write-Plan "back up $Path -> $backup"; return }
    Move-Item -LiteralPath $Path -Destination $backup
    Write-Note "backed up $Path -> $backup"
}

function Install-File([string]$Source, [string]$Target) {
    if ($DryRun) {
        if (Test-Path -LiteralPath $Target) { Backup-Existing $Target }
        Write-Plan "copy $Source -> $Target"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Backup-Existing $Target
    Copy-Item -LiteralPath $Source -Destination $Target
    Write-Note "installed $Target"
}

function Install-Directory([string]$Source, [string]$Target) {
    if ($DryRun) {
        if (Test-Path -LiteralPath $Target) { Backup-Existing $Target }
        Write-Plan "copy directory $Source -> $Target"
        return
    }
    Backup-Existing $Target
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse
    Write-Note "installed $Target"
}

function Test-WingetInstalled([string]$Id) {
    winget list --id $Id --exact --accept-source-agreements 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-Tools {
    Write-Step 'Installing tools with winget'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget not found. Install "App Installer" from the Microsoft Store, or re-run with -SkipTools.'
        return
    }
    foreach ($id in $WingetPackages.Keys) {
        $name = $WingetPackages[$id]
        if (Test-WingetInstalled $id) { Write-Note "$name ($id): already installed"; continue }
        if ($DryRun) { Write-Plan "winget install --id $id --exact --scope user (fallback: default scope)"; continue }
        Write-Note "installing $name ($id)"
        winget install --id $id --exact --silent --scope user --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            # Some packages (e.g. machine-wide installers) do not support user scope.
            winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { Write-Warning "winget failed for $id (exit $LASTEXITCODE); continuing." }
        }
    }
}

function Get-HerdrExe {
    $default = Join-Path $env:LOCALAPPDATA 'Programs\Herdr\bin\herdr.exe'
    if (Test-Path -LiteralPath $default) { return $default }
    $cmd = Get-Command herdr -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-Herdr {
    Write-Step 'Installing herdr'
    if (Get-HerdrExe) { Write-Note 'herdr already installed; skipping.'; return }
    $url = 'https://herdr.dev/install.ps1'
    Write-Note "This will download and run the official herdr installer: $url"
    Write-Note 'It installs to %LOCALAPPDATA%\Programs\Herdr and updates your user PATH (no admin).'
    Write-Note "To review it first: irm $url | more"
    if ($DryRun) { Write-Plan "irm $url | iex"; return }
    Invoke-RestMethod $url | Invoke-Expression
}

function Install-Configs {
    Write-Step 'Installing configuration files'

    # WezTerm
    Install-File (Join-Path $RepoRoot 'wezterm\wezterm.lua') (Join-Path $HOME '.config\wezterm\wezterm.lua')

    # herdr: render the template with the detected Git Bash path
    $gitBash = Find-GitBash
    if (-not $gitBash) {
        Write-Warning 'Git Bash not found. herdr popups (finder, editor, cheat sheet) will not work until you install Git and re-run.'
        $gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    } else {
        Write-Note "Git Bash: $gitBash"
    }
    $herdrDir = Join-Path $env:APPDATA 'herdr'
    $template = Get-Content -LiteralPath (Join-Path $RepoRoot 'herdr\config.toml.tmpl') -Raw
    $rendered = $template.Replace('{{GIT_BASH}}', $gitBash)
    $configTarget = Join-Path $herdrDir 'config.toml'
    if ($DryRun) {
        if (Test-Path -LiteralPath $configTarget) { Backup-Existing $configTarget }
        Write-Plan "render herdr\config.toml.tmpl ({{GIT_BASH}} = $gitBash) -> $configTarget"
    } else {
        New-Item -ItemType Directory -Force -Path $herdrDir | Out-Null
        Backup-Existing $configTarget
        # No BOM: herdr parses the file as plain UTF-8 TOML.
        [IO.File]::WriteAllText($configTarget, $rendered, [Text.UTF8Encoding]::new($false))
        Write-Note "installed $configTarget"
    }

    # herdr scripts. Keep LF endings: bash chokes on CRLF.
    Install-Directory (Join-Path $RepoRoot 'herdr\scripts') (Join-Path $herdrDir 'scripts')

    # PowerShell 7 profile (replaces the existing one; the old one is backed up)
    $profileTarget = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
    Install-File (Join-Path $RepoRoot 'powershell\Microsoft.PowerShell_profile.ps1') $profileTarget

    # Neovim (LazyVim)
    Install-Directory (Join-Path $RepoRoot 'nvim') (Join-Path $env:LOCALAPPDATA 'nvim')
}

function Invoke-HerdrReload {
    Write-Step 'Reloading herdr config'
    $herdr = Get-HerdrExe
    if (-not $herdr) { Write-Note 'herdr not found; nothing to reload.'; return }
    if ($DryRun) { Write-Plan "$herdr server reload-config (if the server is running)"; return }
    & $herdr server reload-config *> $null
    if ($LASTEXITCODE -eq 0) { Write-Note 'reloaded.' }
    else { Write-Note 'server not running (or reload failed); the config applies on next start.' }
}

# --- main ---------------------------------------------------------------------
if ($DryRun) { Write-Host 'DRY RUN: nothing will be written.' -ForegroundColor Yellow }

if ($SkipTools) { Write-Step 'Skipping tool installation (-SkipTools)' }
else { Install-Tools; Install-Herdr }

Install-Configs
Invoke-HerdrReload

Write-Step 'Done'
Write-Note '1. Fully restart WezTerm so it picks up the new config.'
Write-Note '2. Launch nvim once: plugins, treesitter parsers and LSPs install on first run.'
Write-Note '3. Press Ctrl+Shift+H inside herdr for the shortcut cheat sheet.'
Write-Note "Previous files were saved as <name>.bak-$Stamp."
