# rs-wezterm-herdr

A portable terminal environment for Windows 11: **WezTerm** (terminal) + **herdr** (workspace, tab and pane manager) + **LazyVim** (Neovim). One script installs the tools and drops the configs in place.

Screenshots: coming soon.

## Requirements

- Windows 11 with `winget` (App Installer)
- PowerShell 7 (`pwsh`) to run the installer. If you only have Windows PowerShell: `winget install Microsoft.PowerShell`
- No admin rights needed (user scope)

## Quick install

```powershell
git clone https://github.com/riem-programming/rs-wezterm-herdr rs-wezterm-herdr
cd rs-wezterm-herdr
pwsh ./install.ps1            # tools + configs (asks before installing herdr)
pwsh ./install.ps1 -DryRun    # preview only, writes nothing
pwsh ./install.ps1 -SkipTools # configs only
pwsh ./install.ps1 -Yes       # do not ask before running the herdr installer
```

Then fully restart WezTerm. The first `nvim` launch installs plugins, parsers and LSPs.

> **Warning: your PowerShell profile is replaced.** `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` is overwritten with the one from this repo. The previous one is kept as `Microsoft.PowerShell_profile.ps1.bak-<timestamp>`. The same applies to the WezTerm config, the herdr config and scripts, and the whole `nvim` folder. Run with `-DryRun` first to see exactly what will happen.

The installer is idempotent: installed tools are skipped, and every existing target that differs from the repo is backed up (`<name>.bak-<timestamp>`) before being replaced. Targets that are already byte-identical (compared by SHA256, directories by a hash of all their files) are skipped, so re-running does not create new backups.

### herdr installer

herdr is installed with its official script (`irm https://herdr.dev/install.ps1 | iex`) only when it is not already present. The installer asks `Install herdr with the official installer? [y/N]` first; pass `-Yes` to skip the question. If the herdr install fails, a warning is printed and the rest of the setup continues. To review the script before running it:

```powershell
irm https://herdr.dev/install.ps1 | more
```

### Tools installed (winget)

WezTerm, Git, fzf, jq, Neovim, Zig, fd, lazygit, tree-sitter CLI, Node.js LTS, PowerShell 7, JetBrainsMono Nerd Font (`DEVCOM.JetBrainsMonoNerdFont`).

## What gets installed

| Repo path | Target |
| --- | --- |
| `wezterm/wezterm.lua` | `~\.config\wezterm\wezterm.lua` |
| `herdr/config.toml.tmpl` | `%APPDATA%\herdr\config.toml` |
| (generated) | `%APPDATA%\herdr\run.cmd` (launcher holding the Git Bash path) |
| `herdr/scripts/` | `%APPDATA%\herdr\scripts\` |
| `powershell/Microsoft.PowerShell_profile.ps1` | `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| `nvim/` | `%LOCALAPPDATA%\nvim\` |

herdr runs custom commands through `cmd.exe /d /c`, whose quote handling breaks on a quoted Git Bash path plus a quoted script path when either contains spaces. So each herdr command is just `"%APPDATA%\herdr\run.cmd" <script>.sh`, and the installer generates `run.cmd` with the detected Git Bash path (Program Files, `%LOCALAPPDATA%\Programs\Git`, the Git for Windows registry key, or `git.exe` on PATH).

## Keyboard shortcuts

Press `Ctrl+Shift+H` at any time to open this list in a filterable popup. The source of truth is `herdr/scripts/shortcuts.txt`; update it whenever you change a binding.

#### Help

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+H` | Show this shortcut list |

#### Terminal

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+C` | Copy selection |
| `Ctrl+Shift+V` | Paste |
| `Right click` | Paste |
| `Ctrl+C` | Copy if text is selected, otherwise interrupt |
| `Alt+V` | Paste image in Claude Code |

#### Workspaces

| Keys | Action |
| --- | --- |
| `Ctrl+T / Ctrl+Shift+F` | Workspace finder (type to filter, Esc closes) |
| `Finder: Enter` | Open the selected workspace |
| `Finder: + New workspace` | Ask for a name and create a workspace |
| `Finder: unknown name + Enter` | Create a workspace with that name |
| `Ctrl+Alt+N` | New workspace (asks for a name) |
| `Ctrl+Shift+Tab` | Next workspace |
| `Ctrl+B Shift+W` | Rename workspace |
| `Ctrl+B Shift+D` | Close workspace |

#### Tabs

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+D` | New tab in the current folder |
| `Ctrl+Shift+W` | Close tab |
| `Ctrl+Tab` | Next tab |
| `Ctrl+B P` | Previous tab |
| `Ctrl+B Shift+T` | Rename tab |

#### Panes

| Keys | Action |
| --- | --- |
| `Ctrl+B V` | Split right |
| `Ctrl+B -` | Split down |
| `Ctrl+B H/J/K/L` | Move between panes |
| `Ctrl+B Z` | Zoom pane |
| `Ctrl+B X` | Close pane |

#### herdr

| Keys | Action |
| --- | --- |
| `Ctrl+B ?` | Show every herdr binding |
| `Ctrl+B Q` | Detach (herdr keeps running) |

#### Editor

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+E` | Open Neovim (or jump to its tab) |

#### Neovim

| Keys | Action |
| --- | --- |
| `Space` | Menu with every Neovim shortcut |
| `Space F F` | Find files |
| `Space F R` | Recent files |
| `Space /` | Search text in the project |
| `Alt+P` | Toggle preview inside the finder |
| `Space E` | File tree |
| `Space G G` | lazygit |
| `gd` | Go to definition |
| `K` | Show docs for the symbol under the cursor |
| `Space C A` | Code actions |
| `Ctrl+U / Ctrl+D` | Half page up / down |
| `Ctrl+V` | Visual block selection |
| `u / Ctrl+R` | Undo / redo |
| `:w` | Save |
| `:e!` | Discard changes |
| `:qa` | Quit Neovim |

#### Oil

| Keys | Action |
| --- | --- |
| `-` | Go to the parent folder |
| `Enter` | Open folder or file |
| `g.` | Show or hide hidden files |
| `g?` | Oil help |
| `Edit name + :w` | Rename a file |
| `dd + :w` | Delete a file |
| `New line + :w` | Create a file (end with / for a folder) |

## Design notes

- **Ctrl+Shift remaps to Ctrl+Alt chords.** Terminals cannot distinguish `Ctrl+Shift+<letter>` from `Ctrl+<letter>`, so herdr could never see those keys. WezTerm intercepts the browser-style shortcut and sends a `Ctrl+Alt+<letter>` chord that herdr binds. Letters `h`, `i`, `j` and `m` are avoided because they collide with legacy control codes (Backspace, Tab, LF, Enter).
- **WezTerm owns no panes.** There are no split bindings in `wezterm.lua`; herdr manages workspaces, tabs and panes and survives closing the window.
- **Single-file Neovim mode.** Opening another file closes the previous buffer. If it has unsaved changes you get one Save / Discard / Cancel prompt. Swap files are disabled (closing a herdr tab kills Neovim and used to leave stale swap files); persistent undo covers recovery.
- **Markdown is render-only.** No linting, formatting or diagnostics for Markdown.
- **Scripts do not trust PATH.** The herdr server keeps the PATH it started with, so `herdr/scripts/lib.sh` resolves fzf, jq, herdr and Neovim from PATH first, then the winget Packages folder and well-known install locations.
- **Python Store alias caveat.** Windows ships zero-byte `python.exe` stubs in `WindowsApps` that shadow a real Python install. If Python tooling in Neovim misbehaves, disable the aliases in Settings > Apps > Advanced app settings > App execution aliases. The installer does not touch them.
- **Treesitter on Windows.** `nvim-treesitter` needs a C compiler. `nvim/scripts/zig-cc.cmd` wraps `zig cc` (stripping the MSVC target flag the `cc` crate passes) and `options.lua` points `CC` at it when `CC` is unset.

## Troubleshooting

- **A popup does nothing** (`Ctrl+T`, `Ctrl+Shift+E`, `Ctrl+Shift+H`): check the Git Bash path in `%APPDATA%\herdr\run.cmd`. If Git was installed after the repo, re-run `pwsh ./install.ps1 -SkipTools`.
- **Treesitter parser compile fails**: make sure `zig` and `tree-sitter` are on PATH (open a new terminal after installing). Delete stale locks in `%LOCALAPPDATA%\tree-sitter\lock` if a previous install was interrupted.
- **"Swap file already exists"**: swap files are disabled in this config; remove leftovers from `%LOCALAPPDATA%\nvim-data\swap`.
- **Icons look broken**: install JetBrainsMono Nerd Font manually from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) if the winget package is unavailable.
- **WezTerm shows no Git Bash menu entry**: it is only listed when Git Bash is found in a standard location.

## Uninstall / restore

Every file or folder the installer replaces (when it differs from the repo version) is first renamed to `<name>.bak-<timestamp>` next to the original. To restore, delete the installed target and rename the backup back, for example:

```powershell
Remove-Item $env:LOCALAPPDATA\nvim -Recurse -Force
Rename-Item $env:LOCALAPPDATA\nvim.bak-20260101-120000 nvim
```

Tools installed through winget can be removed with `winget uninstall <id>`. herdr has its own uninstall instructions on its website.

## License

`nvim/` is based on [LazyVim/starter](https://github.com/LazyVim/starter) (Apache-2.0, see [nvim/LICENSE-LazyVim-starter](nvim/LICENSE-LazyVim-starter)). Everything else is MIT, see [LICENSE](LICENSE).
