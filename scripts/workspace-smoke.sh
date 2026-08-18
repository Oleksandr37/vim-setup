#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
socket_root="$(mktemp -d "${TMPDIR:-/tmp}/vim-setup-tmux.XXXXXX")"
server="vim-setup-check"

cleanup() {
  TMUX_TMPDIR="$socket_root" tmux -L "$server" kill-server >/dev/null 2>&1 || true
  rm -rf "$socket_root"
}
trap cleanup EXIT

TMUX_TMPDIR="$socket_root" tmux -L "$server" -f "$repo_root/config/tmux/tmux.conf" new-session -d -s harness
TMUX_TMPDIR="$socket_root" tmux -L "$server" run-shell -t harness:1 \
  "VIM_SETUP_NO_ATTACH=1 VIM_SETUP_EDITOR_COMMAND=: '$repo_root/bin/vim-workspace' '$repo_root'"

roles="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" list-panes -t work: -F '#{@vim_setup_role}' | sort)"
expected=$'agent\neditor\nrunner'
if [[ "$roles" != "$expected" ]]; then
  printf 'Unexpected workspace roles:\n%s\n' "$roles" >&2
  exit 1
fi

pane_count="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" list-panes -t work: -F '#{pane_id}' | wc -l | tr -d ' ')"
[[ "$pane_count" == "3" ]] || { printf 'Expected 3 panes, found %s\n' "$pane_count" >&2; exit 1; }

layout="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" list-panes -t work: -F '#{@vim_setup_role}|#{pane_left}|#{pane_top}')"
agent_left="$(printf '%s\n' "$layout" | awk -F'|' '$1 == "agent" { print $2 }')"
editor_left="$(printf '%s\n' "$layout" | awk -F'|' '$1 == "editor" { print $2 }')"
editor_top="$(printf '%s\n' "$layout" | awk -F'|' '$1 == "editor" { print $3 }')"
runner_top="$(printf '%s\n' "$layout" | awk -F'|' '$1 == "runner" { print $3 }')"
(( agent_left > editor_left )) || { printf 'Agent pane is not on the right.\n' >&2; exit 1; }
(( runner_top > editor_top )) || { printf 'Runner pane is not below the editor.\n' >&2; exit 1; }

printf 'Workspace layout smoke test passed.\n'
