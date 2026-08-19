#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/vim-setup-e2e.XXXXXX")"
fixture="$test_root/project"
lazygit_server="lazygit-e2e"
nvim_socket="$test_root/nvim.sock"

cleanup() {
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

cp -R "$repo_root/tests/fixtures/sample-project" "$fixture"
git -C "$fixture" init -q
git -C "$fixture" config user.name "vim-setup test"
git -C "$fixture" config user.email "vim-setup@example.invalid"
git -C "$fixture" add .
git -C "$fixture" commit -qm "Initial fixture"
sed -i '' -e 's/console\.log/console.warn/' "$fixture/src/app.ts"
sed -i '' -e 's/: true/: false/' "$fixture/config.yaml"

grep -q '^  editPreset: nvim-remote$' "$repo_root/config/lazygit/config.yml" || {
  printf 'Lazygit is not configured to return files to the current Neovim instance.\n' >&2
  exit 1
}

image_output="$test_root/icon.png"
magick "$fixture/assets/icon.svg" "$image_output"
[[ -s "$image_output" ]] || { printf 'ImageMagick did not render the SVG fixture.\n' >&2; exit 1; }

export XDG_CONFIG_HOME="$repo_root/config"
export VIM_SETUP_TESTING=1
export VIM_SETUP_E2E_LSP="${VIM_SETUP_E2E_LSP:-0}"
export VIM_SETUP_E2E_ROOT="$fixture"
export VIM_SETUP_REPO_ROOT="$repo_root"

TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" new-session -d -x 180 -y 50 -c "$fixture" \
  "XDG_CONFIG_HOME='$repo_root/config' VIM_SETUP_TESTING=1 nvim --listen '$nvim_socket' README.md"
lazygit_pane="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" list-panes -F '#{pane_id}' | head -n 1)"
readiness_backoff=(0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5)

wait_for_pane() {
  local pattern="$1"
  local label="$2"
  local captured
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    captured="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane" 2>/dev/null || true)"
    if grep -Fq "$pattern" <<<"$captured"; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for %s after %d readiness checks.\n' "$label" "$attempts" >&2
  printf '%s\n' "$captured" >&2
  return 1
}

wait_for_completion() {
  local visible
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    visible="$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval(\"require('blink.cmp').is_menu_visible()\")" 2>/dev/null || true)"
    if [[ "$visible" == "true" || "$visible" == "v:true" || "$visible" == "1" ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for the code-completion menu after %d readiness checks.\n' "$attempts" >&2
  printf 'mode=%s filetype=%s blink_active=%s blink_visible=%s\n' \
    "$(nvim --server "$nvim_socket" --remote-expr 'mode()' 2>/dev/null || true)" \
    "$(nvim --server "$nvim_socket" --remote-expr '&filetype' 2>/dev/null || true)" \
    "$(nvim --server "$nvim_socket" --remote-expr "luaeval(\"require('blink.cmp').is_active()\")" 2>/dev/null || true)" \
    "$visible" >&2
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane" >&2 || true
  return 1
}

wait_for_completion_hidden() {
  local visible
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    visible="$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval(\"require('blink.cmp').is_menu_visible()\")" 2>/dev/null || true)"
    if [[ "$visible" == "false" || "$visible" == "v:false" || "$visible" == "0" ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Completion menu did not close after %d readiness checks; visible=%q.\n' "$attempts" "$visible" >&2
  return 1
}

wait_for_completion_acceptance() {
  local key_name="$1"
  local current_line
  local visible
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    current_line="$(nvim --server "$nvim_socket" --remote-expr 'getline(".")' 2>/dev/null || true)"
    visible="$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval(\"require('blink.cmp').is_menu_visible()\")" 2>/dev/null || true)"
    if [[ ( "$visible" == "false" || "$visible" == "v:false" || "$visible" == "0" ) \
      && "$current_line" =~ ^greet(\(\))?$ ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf '%s did not accept completion after %d readiness checks; line=%q visible=%q.\n' \
    "$key_name" "$attempts" "$current_line" "$visible" >&2
  return 1
}

wait_for_typescript_diagnostic() {
  local count
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    count="$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval('#vim.diagnostic.get($code_action_buffer, { lnum = 1 })')" 2>/dev/null || true)"
    if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for the TypeScript code-action diagnostic after %d readiness checks; count=%q.\n' \
    "$attempts" "$count" >&2
  return 1
}

wait_for_insert_mode() {
  local mode
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    mode="$(nvim --server "$nvim_socket" --remote-expr 'mode()' 2>/dev/null || true)"
    if [[ "$mode" == i* ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Neovim did not enter Insert mode after %d readiness checks; mode=%q.\n' "$attempts" "$mode" >&2
  return 1
}

wait_for_code_action_picker() {
  local picker_count
  local item_count
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    picker_count="$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval('#Snacks.picker.get()')" 2>/dev/null || true)"
    if [[ "$picker_count" =~ ^[1-9][0-9]*$ ]]; then
      item_count="$(nvim --server "$nvim_socket" --remote-expr \
        "luaeval('#Snacks.picker.get()[1]:items()')" 2>/dev/null || true)"
      if [[ "$item_count" =~ ^[0-9]+$ ]] && (( item_count > 0 )); then
        return 0
      fi
    fi
    sleep "$delay"
  done
  printf 'Quick Fix did not leave a chooser open after %d readiness checks; pickers=%q items=%q.\n' \
    "$attempts" "$picker_count" "$item_count" >&2
  printf 'mode=%s mapping=%s source=%q\n' \
    "$(nvim --server "$nvim_socket" --remote-expr 'mode()' 2>/dev/null || true)" \
    "$(nvim --server "$nvim_socket" --remote-expr \
      "luaeval('(vim.fn.maparg(\"<F13>\", \"i\", false, true) or {}).desc')" 2>/dev/null || true)" \
    "$(nvim --server "$nvim_socket" --remote-expr \
      "join(getbufline($code_action_buffer, 1, '\$'), '\\n')" 2>/dev/null || true)" >&2
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane" >&2 || true
  return 1
}

wait_for_pane_change() {
  local previous="$1"
  local label="$2"
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    ready_capture="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane" 2>/dev/null || true)"
    if [[ "$ready_capture" != "$previous" ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for %s after %d readiness checks.\n' "$label" "$attempts" >&2
  return 1
}

wait_for_cursor() {
  local previous="${1:-}"
  local label="$2"
  local attempts=0
  local cursor_x
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    ready_cursor="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" display-message -p -t "$lazygit_pane" '#{cursor_x},#{cursor_y}')"
    cursor_x="${ready_cursor%,*}"
    if [[ "$cursor_x" -gt 60 && ( -z "$previous" || "$ready_cursor" != "$previous" ) ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for %s after %d readiness checks; cursor=%s.\n' \
    "$label" "$attempts" "$ready_cursor" >&2
  return 1
}

wait_for_pane "README.md" "Neovim startup"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Space g g
wait_for_pane "Diff" "the changed-files review"
wait_for_pane "enabled: false" "the first changed-file preview"
colored_review="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -e -t "$lazygit_pane")"
[[ "$colored_review" == *"48;2;23;61;36"* ]] || {
  printf 'The review preview did not render the configured green addition background.\n' >&2
  exit 1
}
[[ "$colored_review" == *"48;2;74;32;37"* ]] || {
  printf 'The review preview did not render the configured red deletion background.\n' >&2
  exit 1
}

# Ctrl-D is a normal Vim reading key. In Snacks' defaults it scrolls the file
# list, so this catches the regression where reading a diff selects another
# file and replaces the document under review.
review_before_scroll="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane")"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" C-d
wait_for_pane_change "$review_before_scroll" "Ctrl-D diff scrolling"
scrolled_review="$ready_capture"
[[ "$scrolled_review" == *"feature_"* && "$scrolled_review" == *": false"* ]] || {
  printf 'Ctrl-D changed the selected file instead of scrolling the diff.\n' >&2
  exit 1
}

# Reproduce the mouse path used during review: click the diff, then scroll it.
# One wheel tick should use Neovim's three-line mousescroll setting rather
# than Snacks' much larger half-page preview action, and focus must stay right.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -H -t "$lazygit_pane" \
  1b 5b 3c 30 3b 31 30 30 3b 32 35 4d 1b 5b 3c 30 3b 31 30 30 3b 32 35 6d
wait_for_cursor "" "Diff focus after click"
cursor_before="$ready_cursor"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -H -t "$lazygit_pane" \
  1b 5b 3c 36 35 3b 31 30 30 3b 32 35 4d
wait_for_cursor "$cursor_before" "smooth Diff wheel scrolling"
cursor_after="$ready_cursor"

before_x="${cursor_before%,*}"
before_y="${cursor_before#*,}"
after_x="${cursor_after%,*}"
after_y="${cursor_after#*,}"
# Scrolling may move the cursor to keep it inside the preview's viewport, so
# its exact column can change. Both coordinates must remain in the right-hand
# diff region; the file list occupies the left side of this fixed test layout.
[[ "$before_x" -gt 60 && "$after_x" -gt 60 ]] || {
  printf 'Mouse-wheel scrolling moved focus out of the diff (%s -> %s).\n' "$cursor_before" "$cursor_after" >&2
  exit 1
}
wheel_delta=$((before_y - after_y))
[[ "$wheel_delta" -ge 0 && "$wheel_delta" -le 3 ]] || {
  printf 'One mouse-wheel tick moved too aggressively (%s -> %s).\n' "$cursor_before" "$cursor_after" >&2
  exit 1
}

review_before_repeated_wheel="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane")"
for _ in {1..12}; do
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -H -t "$lazygit_pane" \
    1b 5b 3c 36 35 3b 31 30 30 3b 32 35 4d
done
wait_for_pane_change "$review_before_repeated_wheel" "repeated Diff wheel scrolling"
cursor_repeated="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" display-message -p -t "$lazygit_pane" '#{cursor_x},#{cursor_y}')"
[[ "${cursor_repeated%,*}" -gt 60 ]] || {
  printf 'Repeated mouse-wheel scrolling moved focus out of the diff (%s -> %s).\n' "$cursor_before" "$cursor_repeated" >&2
  exit 1
}

TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape Escape
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Space g G
wait_for_pane "Unstaged changes" "the Lazygit actions popup"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" 2 j e

returned_to_file=false
return_attempts=0
for delay in "${readiness_backoff[@]}"; do
  return_attempts=$((return_attempts + 1))
  captured="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -t "$lazygit_pane" 2>/dev/null || true)"
  if grep -Eq 'src/app\.ts|config\.yaml' <<<"$captured" && ! grep -Fq "Unstaged changes" <<<"$captured"; then
    returned_to_file=true
    break
  fi
  sleep "$delay"
done
[[ "$returned_to_file" == true ]] || {
  printf 'Lazygit e did not return to the selected file after %d readiness checks.\n' "$return_attempts" >&2
  printf '%s\n' "$captured" >&2
  exit 1
}

# Exercise completion through the actual terminal mappings. Configuration-only
# checks cannot catch mappings that were skipped or overwritten at runtime.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -l -t "$lazygit_pane" ':edit src/app.ts'
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Enter G o
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -l -t "$lazygit_pane" 'gre'
wait_for_completion
# Auto-trigger and manual trigger are separate critical paths. Close the menu,
# then exercise the Ctrl-Space destination used by Kitty's Cmd-I mapping.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" C-e
wait_for_completion_hidden
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" C-Space
wait_for_completion
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Enter
wait_for_completion_acceptance "Enter"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape
enter_completion="$(nvim --server "$nvim_socket" --remote-expr 'getline(".")')"
[[ "$enter_completion" =~ ^greet(\(\))?$ ]] || {
  printf 'Enter did not accept the selected completion; current line is %q.\n' "$enter_completion" >&2
  exit 1
}

TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" G o
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -l -t "$lazygit_pane" 'gre'
wait_for_completion
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Tab
wait_for_completion_acceptance "Tab"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape
tab_completion="$(nvim --server "$nvim_socket" --remote-expr 'getline(".")')"
[[ "$tab_completion" =~ ^greet(\(\))?$ ]] || {
  printf 'Tab did not accept the selected completion; current line is %q.\n' "$tab_completion" >&2
  exit 1
}

# VS Code's Quick Fix command is a chooser, not its separate Auto Fix command.
# Exercise the real terminal path from Insert mode and prove opening the picker
# cannot mutate the disposable source buffer before an explicit confirmation.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape
nvim --server "$nvim_socket" --remote-expr \
  "luaeval(\"vim.api.nvim_buf_set_lines(0, 0, -1, false, {'export function needsAsync() {', '  await Promise.resolve()', '}'}) or true\")" \
  >/dev/null
nvim --server "$nvim_socket" --remote-expr 'cursor(2, 3)' >/dev/null
code_action_buffer="$(nvim --server "$nvim_socket" --remote-expr 'bufnr("%")')"
wait_for_typescript_diagnostic
code_action_before="$(nvim --server "$nvim_socket" --remote-expr \
  "join(getbufline($code_action_buffer, 1, '\$'), '\\n')")"

TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" i
wait_for_insert_mode
nvim --server "$nvim_socket" --remote-expr 'cursor(2, 4)' >/dev/null
# Kitty's legacy-compatible F13 sequence is CSI 25 ~. tmux does not accept
# "F13" as a named send-keys argument and would type those literal characters.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -H -t "$lazygit_pane" 1b 5b 32 35 7e
wait_for_code_action_picker
code_action_after="$(nvim --server "$nvim_socket" --remote-expr \
  "join(getbufline($code_action_buffer, 1, '\$'), '\\n')")"
[[ "$code_action_after" == "$code_action_before" ]] || {
  printf 'Quick Fix changed the source buffer before an action was selected.\n' >&2
  exit 1
}
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Escape

set +e
output="$(nvim --headless \
  --cmd "lua dofile(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/harness.lua').schedule(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/e2e.lua')" \
  2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]] || grep -Eiq \
  'Error detected|E5108:|E5113:|E492:|vim\.schedule callback|stack traceback|attempt to call|Error executing' \
  <<<"$output"; then
  printf '%s\n' "$output"
  printf 'End-to-end test failed.\n' >&2
  exit 1
fi

printf '%s\n' "$output"
printf 'Full end-to-end test passed.\n'
