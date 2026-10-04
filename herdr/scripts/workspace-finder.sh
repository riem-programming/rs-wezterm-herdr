#!/usr/bin/env bash
# Workspace finder popup for herdr.
# Enter on an item focuses it; Enter on "+ New workspace" (default row) asks for a name;
# a query that matches nothing creates a workspace labeled with that query; Esc cancels.
# Usage: workspace-finder.sh [--dry-run]

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FZF=$(resolve_fzf)
JQ=$(resolve_jq)
HERDR=$(resolve_herdr)

# Target cwd as a Windows-style path.
if [[ -n $HERDR_ACTIVE_PANE_CWD && -d $HERDR_ACTIVE_PANE_CWD ]]; then
  CWD=$HERDR_ACTIVE_PANE_CWD
elif [[ -d $PWD ]]; then
  CWD=$(cygpath -w "$PWD")
else
  CWD=$(cygpath -w "$HOME")
fi

NEW_ROW='+ New workspace'
CR=$'\r'
TAB=$'\t'

# Rows: "N. label<TAB>id"; $() strips trailing newlines, CRs removed below.
list=$("$HERDR" workspace list | "$JQ" -r '.result.workspaces[] | "\(.number). \(.label)\t\(.workspace_id)"')
list=${list//$CR/}
rows="$NEW_ROW$TAB"
[[ -n $list ]] && rows+=$'\n'$list

if [[ $1 == --dry-run ]]; then
  printf '%s\ncwd: %s\n' "$rows" "$CWD"
  exit 0
fi

new_workspace() { "$HERDR" workspace create --label "$1" --cwd "$CWD" --focus >/dev/null; }

trim() { # $1=string; prints it without CRs and surrounding whitespace
  local s=${1//$CR/}
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

# Name prompt as an fzf input box. Returns 0 with NAME set when a non-empty name was entered;
# returns 1 on Esc or empty name (caller goes back to the list).
prompt_name() {
  local pout pcode
  pout=$("$FZF" --print-query --layout=reverse --prompt 'New workspace name> ' \
    --header 'Enter: create | Esc: back' < /dev/null)
  pcode=$?
  # Enter with no matches exits 1 (query on first line); 130 = Esc / Ctrl+C
  [[ $pcode -eq 0 || $pcode -eq 1 ]] || return 1
  NAME=$(trim "${pout%%$'\n'*}")
  [[ -n $NAME ]]
}

while true; do
  out=$(printf '%s\n' "$rows" | "$FZF" \
    --delimiter "$TAB" --with-nth 1 --tiebreak=index \
    --print-query --layout=reverse --prompt 'workspace> ' \
    --header 'Enter: open | empty Enter: new | Esc: cancel')
  code=$?
  out=${out//$CR/}

  # 130 = Esc / Ctrl+C, 2 = error
  [[ $code -eq 0 || $code -eq 1 ]] || exit 0

  query=$(trim "${out%%$'\n'*}")

  if [[ $code -eq 1 ]]; then
    # Non-empty query matching nothing: create directly with the query as label
    [[ -n $query ]] && new_workspace "$query"
    exit 0
  fi

  selected=
  [[ $out == *$'\n'* ]] && selected=${out#*$'\n'}
  id=
  [[ $selected == *"$TAB"* ]] && id=${selected#*"$TAB"}

  if [[ -n $id ]]; then
    "$HERDR" workspace focus "$id" >/dev/null
    exit 0
  fi

  # "+ New workspace" row: ask for a name; Esc or empty name returns to the list
  if prompt_name; then
    new_workspace "$NAME"
    exit 0
  fi
done
