#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture_root="$(mktemp -d "/tmp/workon-e2e.XXXXXX")"
socket_root="$(mktemp -d "/tmp/workon-tmux.XXXXXX")"
server="workspace-$$"
pool="__workon_pool"
decks="__workon_decks"
export TMUX_TMPDIR="$socket_root"
export VIM_SETUP_TMUX_SOCKET="$server"
export VIM_SETUP_EDITOR_COMMAND=:
export VIM_SETUP_NO_ATTACH=1

cleanup() {
  tmux -L "$server" kill-server >/dev/null 2>&1 || true
  [[ -n "$fixture_root" && "$fixture_root" == /tmp/workon-e2e.* ]] && rm -rf "$fixture_root"
  [[ -n "$socket_root" && "$socket_root" == /tmp/workon-tmux.* ]] && rm -rf "$socket_root"
}
trap cleanup EXIT

fail() {
  printf 'workspace smoke: %s\n' "$1" >&2
  exit 1
}

wait_until() {
  local description="$1"; shift
  local attempts=0 delay
  local readiness_backoff=(0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5 0.5 0.5 0.5 0.5)
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    if "$@"; then return 0; fi
    sleep "$delay"
  done
  fail "$description was not ready after $attempts bounded attempts"
}

file_exists() {
  [[ -f "$1" ]]
}

file_changed_from() {
  [[ -f "$1" && "$(sed -n '1p' "$1")" != "$2" ]]
}

mkdir -p "$fixture_root/one/project" "$fixture_root/two/project"
repo_a="$(cd "$fixture_root/one/project" && pwd -P)"
repo_b="$(cd "$fixture_root/two/project" && pwd -P)"

printf '%s\n' '{' \
  '  "services": {' \
  '    "heartbeat": "while :; do date +%s%N > heartbeat; sleep 0.1; done"' \
  '  }' \
  '}' > "$repo_b/.vim-setup.json"

workon() {
  "$repo_root/bin/vim-workspace" "$@"
}

workon --view view-one "$repo_a" >/dev/null
workon --view view-one "$repo_b" >/dev/null
workon --view view-two "$repo_b" >/dev/null

pool_roots="$(tmux -L "$server" list-windows -t "$pool" -F '#{@vim_setup_path}' | sed '/^$/d' | sort)"
expected_roots="$(printf '%s\n%s\n' "$repo_a" "$repo_b" | sort)"
if [[ "$pool_roots" != "$expected_roots" ]]; then
  printf 'expected pool roots:\n%s\nactual pool roots:\n%s\n' "$expected_roots" "$pool_roots" >&2
  fail "pool did not create exactly one canonical window per repository"
fi

repo_b_window="$(tmux -L "$server" list-windows -t "$pool" -F '#{window_id}|#{@vim_setup_path}' | awk -F'|' -v root="$repo_b" '$2 == root {print $1}')"
for view in view-one view-two; do
  view_window="$(tmux -L "$server" list-windows -t "$view" -F '#{window_id}|#{@vim_setup_path}' | awk -F'|' -v root="$repo_b" '$2 == root {print $1}')"
  [[ "$view_window" == "$repo_b_window" ]] || fail "$view did not link the canonical repository workspace"
done

view_one_count="$(tmux -L "$server" list-windows -t view-one -F '#{window_id}' | wc -l | tr -d ' ')"
view_two_count="$(tmux -L "$server" list-windows -t view-two -F '#{window_id}' | wc -l | tr -d ' ')"
[[ "$view_one_count" == 2 && "$view_two_count" == 1 ]] || fail "repository membership leaked between Workon windows"

repo_a_window="$(tmux -L "$server" list-windows -t "$pool" -F '#{window_id}|#{@vim_setup_path}' | awk -F'|' -v root="$repo_a" '$2 == root {print $1}')"
tmux -L "$server" select-window -t "view-one:$repo_a_window"
tmux -L "$server" select-window -t "view-two:$repo_b_window"
[[ "$(tmux -L "$server" display-message -p -t view-one '#{@vim_setup_path}')" == "$repo_a" ]] || fail "view-one lost its independent current repository"
[[ "$(tmux -L "$server" display-message -p -t view-two '#{@vim_setup_path}')" == "$repo_b" ]] || fail "view-two lost its independent current repository"

roles="$(tmux -L "$server" list-panes -t "$repo_b_window" -F '#{@vim_setup_role}' | sort)"
[[ "$roles" == $'agent\neditor\nterminal' ]] || fail "workspace pane roles are not editor, agent, terminal"

for name in django celery ngrok stripe logs; do
  workon terminal new "$name" --root "$repo_b" >/dev/null
done
for name in codex claude; do
  workon agent new "$name" --root "$repo_b" >/dev/null
done

pane_count="$(tmux -L "$server" list-panes -t "$repo_b_window" -F '#{pane_id}' | wc -l | tr -d ' ')"
[[ "$pane_count" == 3 ]] || fail "logical terminal tabs changed the fixed three-pane layout"
terminal_names="$(workon terminal list --root "$repo_b")"
[[ "$(printf '%s\n' "$terminal_names" | wc -l | tr -d ' ')" == 6 ]] || fail "expected runner plus five terminal sessions"
agent_names="$(workon agent list --root "$repo_b")"
[[ "$(printf '%s\n' "$agent_names" | wc -l | tr -d ' ')" == 3 ]] || fail "expected main plus two agent sessions"

logs_pane="$(tmux -L "$server" list-panes -a -F '#{pane_id}|#{@vim_setup_path}|#{@vim_setup_name}' | awk -F'|' -v root="$repo_b" '$2 == root && $3 == "logs" {print $1; exit}')"
background_marker="$fixture_root/background-alive"
tmux -L "$server" send-keys -t "$logs_pane" -l "sleep 0.15; touch '$background_marker'; sleep 30"
tmux -L "$server" send-keys -t "$logs_pane" Enter
workon terminal switch runner --root "$repo_b" >/dev/null
wait_until "parked terminal process" file_exists "$background_marker"

workon service start heartbeat --root "$repo_b" >/dev/null
heartbeat="$repo_b/heartbeat"
wait_until "heartbeat service" file_exists "$heartbeat"
heartbeat_before="$(sed -n '1p' "$heartbeat")"

runner_marker="$fixture_root/runner-complete"
tmux -L "$server" run-shell -t "$repo_b_window" \
  "'$repo_root/bin/vim-setup-run' --root '$repo_b' -- \"touch '$runner_marker'\""
wait_until "project runner" file_exists "$runner_marker"
wait_until "service surviving runner activation" file_changed_from "$heartbeat" "$heartbeat_before"

active_terminal="$(tmux -L "$server" list-panes -t "$repo_b_window" -F '#{@vim_setup_deck}|#{@vim_setup_name}' | awk -F'|' '$1 == "terminal" {print $2}')"
[[ "$active_terminal" == runner ]] || fail "project task did not focus the dedicated runner terminal"
[[ "$(tmux -L "$server" show-option -wqv -t "$repo_b_window" @vim_setup_terminal_position)" == 5/7 ]] || fail "clickable terminal selector did not track the visible terminal position"

workon terminal close django --root "$repo_b" >/dev/null
[[ "$(tmux -L "$server" list-panes -t "$repo_b_window" -F '#{pane_id}' | wc -l | tr -d ' ')" == 3 ]] || fail "closing a terminal tab changed the workspace layout"

repo_a_editor="$(tmux -L "$server" list-panes -t "$repo_a_window" -F '#{pane_id}|#{@vim_setup_role}' | awk -F'|' '$2 == "editor" {print $1}')"
workon repo remove --view view-one --target "$repo_a_editor"
[[ "$(tmux -L "$server" list-windows -t view-one -F '#{@vim_setup_path}')" == "$repo_b" ]] || fail "repo removal affected the wrong local view"
tmux -L "$server" list-windows -t "$pool" -F '#{@vim_setup_path}' | grep -Fxq "$repo_a" || fail "local repo removal destroyed the persistent workspace"

tmux -L "$server" source-file "$repo_root/config/tmux/tmux.conf"
for key in c t T a A v N '&'; do
  tmux -L "$server" list-keys -T prefix "$key" >/dev/null 2>&1 || fail "missing tmux prefix binding: $key"
done
bindings="$(tmux -L "$server" list-keys -T prefix)"
for binding in \
  'workon terminal new --target' \
  "workon popup terminal --root '#{@vim_setup_path}'" \
  'workon agent new' \
  "workon popup agent --root '#{@vim_setup_path}'" \
  "workon popup service --root '#{@vim_setup_path}'" \
  "--client '#{client_name}'"; do
  [[ "$bindings" == *"$binding"* ]] || fail "tmux binding lost required client-aware command: $binding"
done
status_left="$(tmux -L "$server" show-option -gv status-left)"
[[ "$status_left" == *'range=user|newterm'* && "$status_left" == *'range=user|termpick'* ]] || fail "clickable terminal controls are missing from the status bar"

[[ -n "$(tmux -L "$server" list-windows -t "$decks" -F '#{window_id}' 2>/dev/null)" ]] || fail "persistent deck storage was not created"

printf 'Workon multi-window, terminal deck, agent deck, service, and runner smoke tests passed.\n'
