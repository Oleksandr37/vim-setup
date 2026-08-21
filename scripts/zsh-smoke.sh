#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "/tmp/workon-zsh.XXXXXX")"
test_home="$test_root/home"
prompt_dir="$test_root/a/deliberately/long/path/project"
socket_root="$(mktemp -d "/tmp/wz-tmux.XXXXXX")"
server="workon-zsh-$$"
pane=""

cleanup() {
  TMUX_TMPDIR="$socket_root" tmux -L "$server" kill-server >/dev/null 2>&1 || true
  [[ "$test_root" == /tmp/workon-zsh.* ]] && rm -rf "$test_root"
  [[ "$socket_root" == /tmp/wz-tmux.* ]] && rm -rf "$socket_root"
}
trap cleanup EXIT

fail() {
  printf 'zsh smoke: %s\n' "$1" >&2
  if [[ -n "$pane" ]]; then
    TMUX_TMPDIR="$socket_root" tmux -L "$server" capture-pane -e -p -t "$pane" >&2 || true
  fi
  exit 1
}

wait_for_pane() {
  local expected="$1" description="$2" output="" delay
  local attempts=0
  local readiness_backoff=(0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5 0.5 0.5 0.5 0.5)
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    output="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" capture-pane -e -p -t "$pane" 2>/dev/null || true)"
    [[ "$output" == *"$expected"* ]] && return 0
    sleep "$delay"
  done
  fail "$description was not ready after $attempts bounded attempts"
}

mkdir -p "$test_home" "$prompt_dir"
cat > "$test_home/.zshrc" <<'EOF'
typeset -g WORKON_TEST_USER_RC=loaded
autoload -Uz add-zsh-hook
_workon_test_long_prompt() {
  PROMPT='user /an/intentionally/very/long/path git:(long-branch) % '
  RPROMPT='git status'
}
add-zsh-hook precmd _workon_test_long_prompt
_omp_precmd() {
  PROMPT='oh-my-posh should not repaint this prompt % '
  RPROMPT='oh-my-posh git status'
}
_omp_preexec() { :; }
_omp_zle-line-init() { :; }
add-zsh-hook precmd _omp_precmd
add-zsh-hook preexec _omp_preexec
zle -N zle-line-init _omp_zle-line-init
HISTFILE="$WORKON_ZDOTDIR/.zsh_history"
HISTSIZE=100
SAVEHIST=100
EOF
mkdir -p "$test_home/.local/state/workon"
printf '%s\n' 'echo workon-autosuggest-ready' > "$test_home/.local/state/workon/zsh_history"
user_rc_digest="$(shasum -a 256 "$test_home/.zshrc")"

TMUX_TMPDIR="$socket_root" tmux -L "$server" new-session -d -x 100 -y 24 -c "$prompt_dir" -P -F '#{pane_id}' \
  "env HOME='$test_home' WORKON_USER_ZDOTDIR='$test_home' '$repo_root/bin/workon-shell'" >/dev/null
pane="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" list-panes -F '#{pane_id}' | head -n 1)"

wait_for_pane '❯' 'minimal prompt'
initial="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" capture-pane -e -p -t "$pane")"
initial_plain="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" capture-pane -p -t "$pane")"
[[ "$initial_plain" == *'project ❯'* ]] || fail 'prompt does not show the current directory basename'
[[ "$initial_plain" != *'/deliberately/long/path/project'* ]] || fail 'prompt includes the full current path'
[[ "$initial" != *'/an/intentionally/very/long/path'* ]] || fail 'user prompt framework overrode the Workon prompt'
[[ "$initial" != *'git status'* ]] || fail 'right-side Git status was not removed'

# Expanded by the isolated zsh in the pane, not by this Bash test harness.
# shellcheck disable=SC2016
probe='print -r -- "WORKON_ZSH_PROBE=${WORKON_TEST_USER_RC}:$+functions[compdef]:$+functions[_zsh_autosuggest_start]:$+functions[_zsh_highlight]:${precmd_functions[(Ie)_omp_precmd]}:${preexec_functions[(Ie)_omp_preexec]}"'
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" -l "$probe"
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" Enter
wait_for_pane 'WORKON_ZSH_PROBE=loaded:1:1:1:0:0' 'zsh feature probe'
[[ ! -e "$repo_root/config/zsh/.zsh_history" ]] || fail 'shell history leaked into the public config directory'
[[ -f "$test_home/.local/state/workon/zsh_history" ]] || fail 'private Workon history was not created'

TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" -l \
  'bindkey | command grep -F _workon_clear_terminal'
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" Enter
wait_for_pane '_workon_clear_terminal' 'private terminal-clear widget'

# Expanded by the isolated zsh in the pane, not by this Bash test harness.
# shellcheck disable=SC2016
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" -l \
  'for i in {1..80}; do print -r -- WORKON_CLEAR_MARKER_$i; done'
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" Enter
wait_for_pane 'WORKON_CLEAR_MARKER_80' 'terminal-clear fixture'
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" Escape
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" -l '[5;30013~'

cleared=false
clear_attempts=0
for delay in 0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5 0.5 0.5; do
  clear_attempts=$((clear_attempts + 1))
  cleared_capture="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" capture-pane -p -t "$pane" -S - -E -)"
  history_size="$(TMUX_TMPDIR="$socket_root" tmux -L "$server" display-message -p -t "$pane" '#{history_size}')"
  if [[ "$history_size" == 0 && "$cleared_capture" != *'WORKON_CLEAR_MARKER_'* && "$cleared_capture" == *'❯'* ]]; then
    cleared=true
    break
  fi
  sleep "$delay"
done
[[ "$cleared" == true ]] || fail "private terminal clear was not complete after $clear_attempts bounded attempts"

TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" -l 'echo workon-auto'
wait_for_pane 'suggest-ready' 'history autosuggestion'
TMUX_TMPDIR="$socket_root" tmux -L "$server" send-keys -t "$pane" C-c
[[ "$(shasum -a 256 "$test_home/.zshrc")" == "$user_rc_digest" ]] ||
  fail 'Workon modified the user zsh configuration'

printf 'Workon zsh prompt, completion, autosuggestion, and highlighting smoke tests passed.\n'
