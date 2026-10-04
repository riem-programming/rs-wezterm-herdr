#!/usr/bin/env bash
# Shared helpers for the herdr scripts (Git Bash). Source it, do not execute it.
#
# The herdr server keeps the PATH it was started with, so freshly installed tools
# may be missing from it. Every resolver therefore tries, in order:
#   1. PATH
#   2. the winget Packages folder (portable/zip-style packages)
#   3. well-known install locations

# LOCALAPPDATA is a Windows path (backslashes); convert it so globbing works.
LOCAL_APPDATA_UNIX=$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")
WINGET_PKGS="$LOCAL_APPDATA_UNIX/Microsoft/WinGet/Packages"

# resolve_winget_tool <exe> <package-glob>  -> prints a path, or returns 1
resolve_winget_tool() {
  local exe=$1 glob=$2 p
  p=$(command -v "$exe" 2>/dev/null) && { printf '%s' "$p"; return 0; }
  # shellcheck disable=SC2086
  p=$(compgen -G "$WINGET_PKGS/$glob/$exe" | head -n1)
  [[ -n $p && -x $p ]] && { printf '%s' "$p"; return 0; }
  return 1
}

resolve_fzf() { resolve_winget_tool fzf.exe 'junegunn.fzf*' || printf '%s' fzf; }
resolve_jq() { resolve_winget_tool jq.exe 'jqlang.jq*' || printf '%s' jq; }

# resolve_herdr: HERDR_BIN_PATH, then PATH, then the default install location.
resolve_herdr() {
  local p
  if [[ -n ${HERDR_BIN_PATH:-} && -e $HERDR_BIN_PATH ]]; then
    printf '%s' "$HERDR_BIN_PATH"; return
  fi
  p=$(command -v herdr.exe 2>/dev/null) && { printf '%s' "$p"; return; }
  p="$LOCAL_APPDATA_UNIX/Programs/Herdr/bin/herdr.exe"
  if [[ -x $p ]]; then printf '%s' "$p"; return; fi
  printf '%s' herdr
}

# resolve_nvim: prints a Windows-style path (it is typed into a PowerShell pane),
# or plain "nvim" so PowerShell resolves it with its own PATH.
resolve_nvim() {
  local p
  p=$(command -v nvim.exe 2>/dev/null)
  if [[ -z $p ]]; then
    for p in "${ProgramFiles:-/c/Program Files}/Neovim/bin/nvim.exe" \
             "$LOCAL_APPDATA_UNIX/Programs/Neovim/bin/nvim.exe"; do
      [[ -x $p ]] && break
      p=
    done
  fi
  if [[ -n $p ]]; then cygpath -w "$p"; else printf '%s' nvim; fi
}
