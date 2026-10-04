#Requires -Version 7.0
<#
.SYNOPSIS
  Installs the WezTerm + herdr + LazyVim terminal environment (user scope, no admin).

.DESCRIPTION
  1. Installs tools with winget (skipped with -SkipTools; already-installed tools are skipped).
  2. Installs herdr with its official installer, only if it is not present.
  3. Copies the configs. Targets that differ from the repo are first backed up to
     <name>.bak-<timestamp>; targets that are already identical are left alone.
     NOTE: this replaces your PowerShell 7 profile (the old one is backed up).
  4. Reloads the herdr config if the herdr server is running.

  Safe to re-run. With -DryRun nothing is installed, copied or changed.

.PARAMETER SkipTools
  Do not install any tools (winget packages or herdr); only copy configuration.

.PARAMETER DryRun
  Print what would happen without writing anything.

.PARAMETER Yes
  Do not ask for confirmation before running the official herdr installer.

.EXAMPLE
  pwsh ./install.ps1 -DryRun -SkipTools
#>
[CmdletBinding()]
param(
    [switch]$SkipTools,
    [switch]$DryRun,
    [switch]$Yes
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
        $null
    )
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) { $candidates[2] = Join-Path $pf86 'Git\bin\bash.exe' }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    # Custom install location: registry written by the Git for Windows installer.
    foreach ($hive in 'HKLM:', 'HKCU:') {
        $key = Get-ItemProperty -Path "$hive\SOFTWARE\GitForWindows" -ErrorAction SilentlyContinue
        $prop = if ($key) { $key.PSObject.Properties['InstallPath'] } else { $null }
        if ($prop -and $prop.Value) {
            $bash = Join-Path $prop.Value 'bin\bash.exe'
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

function Get-PathHash([string]$Path) {
    # File: SHA256 of its bytes. Directory: SHA256 over every file's relative path and hash.
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $root = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\')
        $lines = Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
            $rel = $_.FullName.Substring($root.Length)
            "$rel|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
        }
        $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
        return [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes)).Replace('-', '')
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Install-File([string]$Source, [string]$Target) {
    if ((Test-Path -LiteralPath $Target -PathType Leaf) -and ((Get-PathHash $Source) -eq (Get-PathHash $Target))) {
        Write-Note "unchanged, skipped: $Target"
        return
    }
    if ($DryRun) {
        Backup-Existing $Target
        Write-Plan "copy $Source -> $Target"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Backup-Existing $Target
    Copy-Item -LiteralPath $Source -Destination $Target
    Write-Note "installed $Target"
}

function Install-Text([string]$Content, [string]$Target, [string]$Label) {
    # Writes generated text (UTF-8, no BOM) unless the target already has identical bytes.
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
    $newHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes)).Replace('-', '')
    if ((Test-Path -LiteralPath $Target -PathType Leaf) -and ((Get-PathHash $Target) -eq $newHash)) {
        Write-Note "unchanged, skipped: $Target"
        return
    }
    if ($DryRun) {
        Backup-Existing $Target
        Write-Plan "write $Label -> $Target"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Backup-Existing $Target
    [IO.File]::WriteAllBytes($Target, $bytes)
    Write-Note "installed $Target"
}

function Install-Directory([string]$Source, [string]$Target) {
    if ((Test-Path -LiteralPath $Target -PathType Container) -and ((Get-PathHash $Source) -eq (Get-PathHash $Target))) {
        Write-Note "unchanged, skipped: $Target"
        return
    }
    if ($DryRun) {
        Backup-Existing $Target
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
    if (-not $Yes) {
        $answer = Read-Host 'Install herdr with the official installer? [y/N]'
        if ($answer -notmatch '^(y|yes)$') {
            Write-Warning 'Skipped the herdr install. Install it later from https://herdr.dev or re-run with -Yes.'
            return
        }
    }
    try {
        Invoke-RestMethod $url | Invoke-Expression
    } catch {
        Write-Warning "herdr installation failed: $($_.Exception.Message). Continuing with the rest; install herdr manually from https://herdr.dev."
    }
}

function Install-Configs {
    Write-Step 'Installing configuration files'

    # WezTerm
    Install-File (Join-Path $RepoRoot 'wezterm\wezterm.lua') (Join-Path $HOME '.config\wezterm\wezterm.lua')

    # herdr: the config is copied as-is. The launcher run.cmd holds the Git Bash path
    # (see the quoting notes in herdr\config.toml.tmpl).
    $herdrDir = Join-Path $env:APPDATA 'herdr'
    Install-File (Join-Path $RepoRoot 'herdr\config.toml.tmpl') (Join-Path $herdrDir 'config.toml')

    $gitBash = Find-GitBash
    if (-not $gitBash) {
        Write-Warning 'Git Bash not found. herdr popups (finder, editor, cheat sheet) will not work until you install Git and re-run.'
        $gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    } else {
        Write-Note "Git Bash: $gitBash"
    }
    if ($gitBash.Contains('"') -or $gitBash.Contains('%')) {
        throw "The Git Bash path contains a double quote or percent sign and cannot be used safely in a cmd launcher: $gitBash"
    }
    $launcher = "@`"$gitBash`" --noprofile --norc `"%~dp0scripts\%~1`"`r`n"
    Install-Text $launcher (Join-Path $herdrDir 'run.cmd') 'herdr launcher run.cmd'

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
Write-Note "Replaced files were saved as <name>.bak-$Stamp (identical files are skipped)."
