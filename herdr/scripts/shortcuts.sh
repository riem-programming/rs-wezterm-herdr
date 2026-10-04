#!/usr/bin/env bash
# Shortcut cheat sheet popup for herdr: lists shortcuts.txt in fzf (type to filter, Esc closes).

DIR=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=lib.sh
source "$DIR/lib.sh"
FZF=$(resolve_fzf)

awk -F'\t' '{ printf "%-11s %-30s %s\n", $1, $2, $3 }' "$DIR/shortcuts.txt" |
  "$FZF" --layout=reverse --no-sort --no-multi --prompt 'shortcut> ' \
    --header 'Type to filter | Esc: close' --bind 'enter:ignore' >/dev/null
exit 0
