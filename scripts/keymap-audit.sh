#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# tmux's Unix socket path has a small platform limit, so keep this deliberately
# short even when macOS exposes a very long TMPDIR.
tmp_root="$(mktemp -d "/tmp/vsk.XXXXXX")"
server="keys"

cleanup() {
  TMUX_TMPDIR="$tmp_root" tmux -L "$server" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmp_root"
}
trap cleanup EXIT
readiness_backoff=(0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)

duplicates="$({
  awk '$1 == "map" { print "kitty " $2 }' "$repo_root/config/kitty/kitty.conf"
  awk '
    $1 == "bind" || $1 == "bind-key" {
      table = "prefix"
      key = ""
      for (i = 2; i <= NF; i++) {
        if ($i == "-T") { table = $(i + 1); i++; continue }
        if ($i == "-r" || $i == "-n") { if ($i == "-n") table = "root"; continue }
        key = $i
        break
      }
      if (key != "") print "tmux " table " " key
    }
  ' "$repo_root/config/tmux/tmux.conf"
} | sort | uniq -d)"

if [[ -n "$duplicates" ]]; then
  printf 'Duplicate configured shortcuts:\n%s\n' "$duplicates" >&2
  exit 1
fi

# tmux must never consume ordinary application keystrokes without its prefix.
# Mouse events are UI click targets; User0 is the private Kitty Cmd-K transport.
if awk '
  $1 == "bind" || $1 == "bind-key" {
    table = "prefix"
    key = ""
    for (i = 2; i <= NF; i++) {
      if ($i == "-T") { table = $(i + 1); i++; continue }
      if ($i == "-n") { table = "root"; continue }
      if ($i == "-r") continue
      key = $i
      break
    }
    if (table == "root" && key !~ /^Mouse/ && key != "User0") found = 1
  }
  END { exit !found }
' \
  "$repo_root/config/tmux/tmux.conf"; then
  printf 'tmux config contains a global unprefixed binding.\n' >&2
  exit 1
fi

grep -Fq 'range=user|newterm' "$repo_root/config/tmux/tmux.conf" || {
  printf 'Clickable terminal button is missing its tmux status range.\n' >&2
  exit 1
}
grep -Fq 'range=user|termpick' "$repo_root/config/tmux/tmux.conf" || {
  printf 'Clickable terminal picker is missing its tmux status range.\n' >&2
  exit 1
}
grep -Fq 'range=user|workonupdate' "$repo_root/config/tmux/tmux.conf" || {
  printf 'Clickable Workon update indicator is missing its tmux status range.\n' >&2
  exit 1
}
grep -Fq 'MouseDown1Status if-shell' "$repo_root/config/tmux/tmux.conf" || {
  printf 'Clickable terminal button has no mouse handler.\n' >&2
  exit 1
}

# Kitty owns macOS-only chords. Shift-Enter is the intentional terminal-chat
# translation; Ctrl keys stay available to tmux and Neovim.
invalid_kitty="$(awk '$1 == "map" && $2 !~ /^cmd\+/ && $2 != "shift+enter" { print $2 }' \
  "$repo_root/config/kitty/kitty.conf")"
if [[ -n "$invalid_kitty" ]]; then
  printf 'Kitty mapping crosses into tmux/Neovim keyspace: %s\n' "$invalid_kitty" >&2
  exit 1
fi

# Cmd-click must still reach Kitty when tmux or Neovim has grabbed the mouse.
# Keep a keyboard picker as a reliable fallback for awkward/long links.
grep -Fxq 'mouse_map cmd+left press grabbed discard_event' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Cmd-click does not discard the application-grabbed mouse press.\n' >&2
  exit 1
}
grep -Fxq 'mouse_map cmd+left release grabbed,ungrabbed mouse_handle_click link' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Cmd-click is not mapped to open detected links through grabbed mouse mode.\n' >&2
  exit 1
}
grep -Fxq 'map cmd+shift+u open_url_with_hints' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Kitty URL-hints fallback is missing.\n' >&2
  exit 1
}
grep -Fxq 'allow_hyperlinks yes' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Kitty is not configured to accept application-provided OSC 8 hyperlinks.\n' >&2
  exit 1
}
grep -Fxq 'map cmd+k send_text all \x1b[5;30012~' \
  "$repo_root/config/kitty/kitty.conf" || {
  printf 'Cmd-K does not forward the private pane-scoped tmux transport.\n' >&2
  exit 1
}
if grep -Eq '^map cmd\+k .*clear_terminal' "$repo_root/config/kitty/kitty.conf"; then
  printf 'Cmd-K clears the entire Kitty window instead of one tmux pane.\n' >&2
  exit 1
fi
grep -Fxq 'set -s user-keys[0] "\e[5;30012~"' "$repo_root/config/tmux/tmux.conf" || {
  printf 'tmux does not define the private Cmd-K transport sequence.\n' >&2
  exit 1
}
grep -Fq "bind -T root User0 clear-history -H" "$repo_root/config/tmux/tmux.conf" || {
  printf 'tmux does not consume the reserved Cmd-K transport.\n' >&2
  exit 1
}
grep -Fq "pane_current_command}}' 'send-keys -H" "$repo_root/config/tmux/tmux.conf" || {
  printf 'Cmd-K shell clear is not guarded by the focused pane command.\n' >&2
  exit 1
}
grep -Fq 'send-keys -H 1b 5b 35 3b 33 30 30 31 33 7e' "$repo_root/config/tmux/tmux.conf" || {
  printf 'tmux does not forward the private clear sequence to interactive shells.\n' >&2
  exit 1
}
grep -Fq "if-shell -F '#{==:#{@vim_setup_role},agent}' 'send-keys C-l'" "$repo_root/config/tmux/tmux.conf" || {
  printf 'Cmd-K does not invoke the standard clear action in agent panes.\n' >&2
  exit 1
}
if grep -F 'send-keys C-l' "$repo_root/config/tmux/tmux.conf" |
  grep -Fvq "if-shell -F '#{==:#{@vim_setup_role},agent}' 'send-keys C-l'"; then
  printf 'Cmd-K leaks Ctrl-L outside Workon agent panes.\n' >&2
  exit 1
fi
if rg -q 'User0|30012' "$repo_root/config/nvim"; then
  printf 'Neovim references the private Cmd-K terminal transport.\n' >&2
  exit 1
fi
grep -Fxq 'set -as terminal-features ",xterm-kitty:RGB:hyperlinks"' "$repo_root/config/tmux/tmux.conf" || {
  printf 'tmux does not advertise OSC 8 hyperlinks to Kitty clients.\n' >&2
  exit 1
}

# Cmd-. uses a function key only as a cross-application transport. Keep this
# exact so a future Kitty or tmux edit cannot silently break quick fixes.
grep -Fxq 'map cmd+. send_key f13' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Cmd-. is not translated to the Neovim code-action transport key.\n' >&2
  exit 1
}
grep -Fxq 'map cmd+i send_key ctrl+space' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Cmd-I is not translated to Neovim manual completion.\n' >&2
  exit 1
}
if grep -Eq '^map cmd\+i send_key (i|shift\+i)$' "$repo_root/config/kitty/kitty.conf"; then
  printf 'Cmd-I leaks plain i into Neovim instead of using the completion transport.\n' >&2
  exit 1
fi
if rg -q '(^|[[:space:]])F13([[:space:]]|$)' "$repo_root/config/tmux/tmux.conf"; then
  printf 'tmux consumes F13, which is reserved for the Cmd-. code-action transport.\n' >&2
  exit 1
fi

# The four visible layers should use one named palette instead of drifting into
# independently chosen colors over time.
grep -Fxq 'include kanagawa-dragon.conf' "$repo_root/config/kitty/kitty.conf" || {
  printf 'Kitty is not using the shared Kanagawa Dragon palette.\n' >&2
  exit 1
}
grep -Fq 'config/kitty/kanagawa-dragon.conf' "$repo_root/install.sh" || {
  printf "The installer does not link Kitty's included Kanagawa Dragon palette.\n" >&2
  exit 1
}
grep -Fq 'vim.cmd.colorscheme("kanagawa-dragon")' "$repo_root/config/nvim/lua/vim_setup/plugins/ui.lua" || {
  printf 'Neovim is not using Kanagawa Dragon.\n' >&2
  exit 1
}
grep -Fq '# Compact Kanagawa Dragon status line.' "$repo_root/config/tmux/tmux.conf" || {
  printf 'tmux is not marked as using the shared Kanagawa Dragon palette.\n' >&2
  exit 1
}

TMUX_TMPDIR="$tmp_root" tmux -L "$server" -f "$repo_root/config/tmux/tmux.conf" new-session -d
prefix="$(TMUX_TMPDIR="$tmp_root" tmux -L "$server" show-options -gv prefix)"
[[ "$prefix" == "C-b" ]] || { printf 'Expected isolated tmux prefix C-b, found %s.\n' "$prefix" >&2; exit 1; }
clear_binding="$(TMUX_TMPDIR="$tmp_root" tmux -L "$server" list-keys -T root | awk '$4 == "User0"')"
[[ "$clear_binding" == *"clear-history -H"* && \
  "$clear_binding" == *"send-keys -H 1b 5b 35 3b 33 30 30 31 33 7e"* && \
  "$clear_binding" == *'#{==:#{@vim_setup_role},agent}'* && \
  "$clear_binding" == *"send-keys C-l"* ]] || {
  printf 'Isolated tmux did not load the complete User0 clear binding: %s\n' "$clear_binding" >&2
  exit 1
}

export XDG_CONFIG_HOME="$repo_root/config"
export VIM_SETUP_TESTING=1
export VIM_SETUP_REPO_ROOT="$repo_root"
set +e
output="$(nvim --headless \
  --cmd "lua dofile(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/harness.lua').schedule(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/keymaps.lua')" \
  2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]] || grep -Eiq \
  'Error detected|E5108:|E5113:|E492:|vim\.schedule callback|stack traceback|attempt to call|Error executing' \
  <<<"$output"; then
  printf '%s\n' "$output"
  printf 'Neovim shortcut audit failed.\n' >&2
  exit 1
fi
printf '%s\n' "$output"

tmux_test() {
  TMUX_TMPDIR="$tmp_root" tmux -L "$server" "$@"
}

link_target="https://example.com/workon/wrapped/hyperlink/abcdefghijklmnopqrstuvwxyz0123456789"
link_label="OPEN-LINK-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789"
tmux_test new-window -d -n hyperlink-test
tmux_test resize-window -t :hyperlink-test -x 34 -y 10
tmux_test send-keys -t :hyperlink-test -l "printf '\\033]8;;${link_target}\\033\\\\${link_label}\\033]8;;\\033\\\\\\n'"
tmux_test send-keys -t :hyperlink-test Enter

link_ready=false
link_attempts=0
for delay in "${readiness_backoff[@]}"; do
  link_attempts=$((link_attempts + 1))
  if tmux_test capture-pane -H -p -t :hyperlink-test -S - -E - | grep -Fxq "$link_target"; then
    link_ready=true
    break
  fi
  sleep "$delay"
done
if [[ "$link_ready" != true ]]; then
  printf 'Wrapped OSC 8 target was not preserved after %d readiness checks.\n' "$link_attempts" >&2
  tmux_test capture-pane -e -p -t :hyperlink-test -S - -E - >&2
  exit 1
fi
tmux_test kill-window -t :hyperlink-test

tmux_test resize-window -x 140 -y 45
tmux_test send-keys -t :1 -l "cd -- '$repo_root' && env XDG_CONFIG_HOME='$repo_root/config' VIM_SETUP_TESTING=1 nvim"
tmux_test send-keys -t :1 Enter

started=false
startup_attempts=0
for delay in "${readiness_backoff[@]}"; do
  startup_attempts=$((startup_attempts + 1))
  if [[ "$(tmux_test display-message -p -t :1 '#{pane_current_command}')" == "nvim" ]]; then
    started=true
    break
  fi
  sleep "$delay"
done
[[ "$started" == true ]] || {
  printf 'Neovim did not start after %d readiness checks.\n' "$startup_attempts" >&2
  exit 1
}

assert_which_key() {
  local final_key="$1"
  local screen=""
  local attempts=0
  tmux_test send-keys -t :1 Space "$final_key"
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    screen="$(tmux_test capture-pane -p -t :1)"
    if [[ "$screen" == *"Find files"* && "$screen" == *"Search project text"* && "$screen" == *"Run default project task"* ]]; then
      tmux_test send-keys -t :1 Escape
      return
    fi
    sleep "$delay"
  done
  printf 'Space %s did not render the shortcut guide after %d readiness checks. Terminal contents:\n%s\n' \
    "$final_key" "$attempts" "$screen" >&2
  exit 1
}

# Exercise the literal terminal keystrokes, including Shift-/ as '?'.
assert_which_key /
assert_which_key '?'

printf 'Cross-layer shortcut audit passed.\n'
