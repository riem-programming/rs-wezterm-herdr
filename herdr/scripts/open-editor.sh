#!/usr/bin/env bash
# Jump to the "nvim" tab of the active herdr workspace, or create it
# (cwd = focused pane cwd) running Neovim.
# Usage: open-editor.sh [--dry-run]
set -u

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERDR=$(resolve_herdr)
JQ=$(resolve_jq)
NVIM=$(resolve_nvim)
LABEL="nvim"

ws="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
cwd="${HERDR_ACTIVE_PANE_CWD:-${PWD:-$HOME}}"

run() {
  if [ "$DRY" = 1 ]; then printf 'DRY: %s\n' "$*"; else "$@"; fi
}

if [ -z "$ws" ]; then
  echo "open-editor: no active workspace id" >&2
  exit 1
fi

tabs_json="$("$HERDR" tab list --workspace "$ws" 2>/dev/null | tr -d '\r')"
tab_id="$(printf '%s' "$tabs_json" | "$JQ" -r --arg ws "$ws" --arg l "$LABEL" \
  '[.result.tabs[] | select(.workspace_id == $ws and .label == $l)][0].tab_id // empty' | tr -d '\r')"

if [ -n "$tab_id" ]; then
  run "$HERDR" tab focus "$tab_id"
  exit 0
fi

created="$(run "$HERDR" tab create --workspace "$ws" --cwd "$cwd" --label "$LABEL" --focus | tr -d '\r')"
if [ "$DRY" = 1 ]; then
  echo "$created"
  echo "DRY: pane run <root pane of new tab> & \"$NVIM\" ."
  exit 0
fi

pane_id="$(printf '%s' "$created" | "$JQ" -r '.result.root_pane.pane_id // .result.pane.pane_id // empty' | tr -d '\r')"
if [ -z "$pane_id" ]; then
  echo "open-editor: could not determine new pane id: $created" >&2
  exit 1
fi
# Panes start in PowerShell, so the call operator is required for a quoted path.
"$HERDR" pane run "$pane_id" "& \"$NVIM\" ."
