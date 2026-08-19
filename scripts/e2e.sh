#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/vim-setup-e2e.XXXXXX")"
fixture="$test_root/project"
lazygit_server="lazygit-e2e"
nvim_socket="$test_root/nvim.sock"

cleanup() {
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" kill-server >/dev/null 2>&1 || true
  for delay in 0.02 0.04 0.08 0.16 0.32 0.5 0.5 0.5; do
    if ! nvim --server "$nvim_socket" --remote-expr '1' >/dev/null 2>&1; then
      break
    fi
    sleep "$delay"
  done
  rm -rf "$test_root" 2>/dev/null || true
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
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export VIM_SETUP_TESTING=1
export VIM_SETUP_E2E_LSP="${VIM_SETUP_E2E_LSP:-0}"
export VIM_SETUP_E2E_ROOT="$fixture"
export VIM_SETUP_REPO_ROOT="$repo_root"

prepare_nvim() {
  local output status
  set +e
  output="$(nvim --headless "$@" +qa 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 ]] || grep -Eiq \
    'Error detected|E5113:|E492:|vim\.schedule callback|stack traceback|attempt to call method|Error executing' \
    <<<"$output"; then
    printf '%s\n' "$output" >&2
    printf 'Could not prepare the isolated Neovim E2E runtime.\n' >&2
    exit 1
  fi
}

prepare_nvim "+Lazy! restore"
prepare_nvim "+lua require('nvim-treesitter').install({ 'markdown', 'markdown_inline', 'typescript', 'yaml' }):wait(300000)"
prepare_nvim "+Lazy load mason-tool-installer.nvim" \
  "+lua local wanted; for _, tool in ipairs(require('vim_setup.mason_tools')) do if tool[1] == 'typescript-language-server' then wanted = tool end end; assert(wanted, 'missing pinned TypeScript server'); local installer = require('mason-tool-installer'); installer.setup({ ensure_installed = { wanted }, run_on_start = false }); installer.check_install(false, true)"

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

code_diff_file() {
  local field="$1"
  case "$field" in
    selected)
      nvim --server "$nvim_socket" --remote-expr \
        "luaeval('(function() local e=require(\"codediff.ui.lifecycle\").get_explorer(vim.api.nvim_get_current_tabpage()); return e and e.current_file_path or \"\" end)()')" \
        2>/dev/null || true
      ;;
    cursor)
      nvim --server "$nvim_socket" --remote-expr \
        "luaeval('(function() local e=require(\"codediff.ui.lifecycle\").get_explorer(vim.api.nvim_get_current_tabpage()); if not e then return \"\" end; return vim.api.nvim_win_call(e.split.winid, function() local n=e.tree:get_node(); local d=n and n.data or nil; return d and d.type ~= \"group\" and d.type ~= \"directory\" and d.path or \"\" end) end)()')" \
        2>/dev/null || true
      ;;
    *) printf 'Unknown CodeDiff file field: %s\n' "$field" >&2; return 2 ;;
  esac
}

wait_for_code_diff_file() {
  local field="$1"
  local expected="$2"
  local label="$3"
  local actual=""
  local attempts=0
  for delay in "${readiness_backoff[@]}"; do
    attempts=$((attempts + 1))
    actual="$(code_diff_file "$field")"
    if [[ "$actual" == "$expected" ]]; then
      return 0
    fi
    sleep "$delay"
  done
  printf 'Timed out waiting for %s after %d readiness checks; expected=%q actual=%q.\n' \
    "$label" "$attempts" "$expected" "$actual" >&2
  return 1
}

move_to_another_code_diff_file() {
  local previous="$1"
  local actual=""
  local attempts=0
  nvim --server "$nvim_socket" --remote-expr \
    "luaeval('(function() local e=require(\"codediff.ui.lifecycle\").get_explorer(vim.api.nvim_get_current_tabpage()); if e then vim.api.nvim_set_current_win(e.split.winid) end return true end)()')" \
    >/dev/null
  TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" g g
  for _ in {1..12}; do
    attempts=$((attempts + 1))
    TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Down
    actual="$(code_diff_file cursor)"
    if [[ -n "$actual" && "$actual" != "$previous" ]]; then
      ready_code_diff_file="$actual"
      return 0
    fi
  done
  printf 'CodeDiff cursor did not reach another file after %d moves; file=%q.\n' \
    "$attempts" "$actual" >&2
  return 1
}

code_diff_cursor_position() {
  nvim --server "$nvim_socket" --remote-expr \
    "luaeval('(function() local e=require(\"codediff.ui.lifecycle\").get_explorer(vim.api.nvim_get_current_tabpage()); if not e then return \"\" end; vim.api.nvim_set_current_win(e.split.winid); return vim.fn.screencol() .. \",\" .. vim.fn.screenrow() end)()')" \
    2>/dev/null
}

code_diff_explorer_mapping() {
  local key="$1"
  nvim --server "$nvim_socket" --remote-expr \
    "luaeval('(function() local e=require(\"codediff.ui.lifecycle\").get_explorer(vim.api.nvim_get_current_tabpage()); if not e then return \"\" end; return vim.api.nvim_win_call(e.split.winid, function() return (vim.fn.maparg(\"$key\", \"n\", false, true) or {}).rhs or \"\" end) end)()')" \
    2>/dev/null || true
}

code_diff_filetype() {
  nvim --server "$nvim_socket" --remote-expr \
    "luaeval('(function() local _, b=require(\"codediff.ui.lifecycle\").get_buffers(vim.api.nvim_get_current_tabpage()); return b and vim.bo[b].filetype or \"\" end)()')" \
    2>/dev/null || true
}

code_diff_has_treesitter() {
  nvim --server "$nvim_socket" --remote-expr \
    "luaeval('(function() local _, b=require(\"codediff.ui.lifecycle\").get_buffers(vim.api.nvim_get_current_tabpage()); return b and vim.treesitter.highlighter.active[b] ~= nil or false end)()')" \
    2>/dev/null || true
}

wait_for_pane "README.md" "Neovim startup"
registered_socket=""
for delay in "${readiness_backoff[@]}"; do
  registered_socket="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" show-option -pqv \
    -t "$lazygit_pane" @workon_nvim_socket 2>/dev/null || true)"
  [[ "$registered_socket" == "$nvim_socket" ]] && break
  sleep "$delay"
done
[[ "$registered_socket" == "$nvim_socket" ]] || {
  printf 'Neovim did not register its RPC endpoint with the owning tmux pane.\n' >&2
  exit 1
}
[[ "$(nvim --server "$nvim_socket" --remote-expr "luaeval('vim.env.VSCODE_DIFF_NO_AUTO_INSTALL')")" == "1" ]] || {
  printf 'CodeDiff automatic release-binary downloads are not disabled.\n' >&2
  exit 1
}
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Space g g
wait_for_pane "Changes" "the CodeDiff changed-files review"

initial_selected_file=""
for delay in "${readiness_backoff[@]}"; do
  initial_selected_file="$(code_diff_file selected)"
  if [[ -n "$initial_selected_file" ]]; then
    break
  fi
  sleep "$delay"
done
[[ -n "$initial_selected_file" ]] || {
  printf 'CodeDiff did not select an initial changed file.\n' >&2
  exit 1
}

if [[ "$initial_selected_file" == "config.yaml" ]]; then
  wait_for_pane "enabled: false" "the first CodeDiff document"
else
  wait_for_pane "console.warn" "the first CodeDiff document"
fi
colored_review="$(TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" capture-pane -p -e -t "$lazygit_pane")"
[[ "$colored_review" == *" Diff "* && "$colored_review" != *"CodeDiff Explorer"* ]] || {
  printf 'The review surface leaked CodeDiff internal names instead of displaying Diff.\n' >&2
  exit 1
}
[[ "$colored_review" == *"48;2;23;61;36"* ]] || {
  printf 'CodeDiff did not render the configured green addition background.\n' >&2
  exit 1
}
[[ "$colored_review" == *"48;2;74;32;37"* ]] || {
  printf 'CodeDiff did not render the configured red deletion background.\n' >&2
  exit 1
}

# CodeDiff owns this interaction: passive movement in its tree must not replace
# the document. Enter and our configured single click are the explicit choices.
move_to_another_code_diff_file "$initial_selected_file"
enter_target="$ready_code_diff_file"
[[ "$(code_diff_file selected)" == "$initial_selected_file" ]] || {
  printf 'Moving through CodeDiff files replaced the document without selection.\n' >&2
  exit 1
}

TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" Enter
wait_for_code_diff_file selected "$enter_target" "Enter-selected CodeDiff document"

move_to_another_code_diff_file "$enter_target"
click_target="$ready_code_diff_file"
[[ "$(code_diff_file selected)" == "$enter_target" ]] || {
  printf 'Passive CodeDiff navigation changed the Enter-selected document.\n' >&2
  exit 1
}
IFS=, read -r list_mouse_x list_mouse_y <<<"$(code_diff_cursor_position)"

# Store a different row's screen coordinates, then move away from it. This
# catches a false-positive where a mouse mapping selects only the old cursor
# row instead of the row actually clicked.
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -t "$lazygit_pane" g g
[[ "$(code_diff_file cursor)" != "$click_target" ]] || {
  printf 'Could not move away from the CodeDiff mouse target before clicking it.\n' >&2
  exit 1
}
printf -v list_click_event '\033[<0;%d;%dM\033[<0;%d;%dm' \
  "$list_mouse_x" "$list_mouse_y" "$list_mouse_x" "$list_mouse_y"
TMUX_TMPDIR="$test_root" tmux -L "$lazygit_server" send-keys -l -t "$lazygit_pane" "$list_click_event"
wait_for_code_diff_file selected "$click_target" "mouse-selected CodeDiff document"

for horizontal_key in '<ScrollWheelLeft>' '<ScrollWheelRight>' '<S-ScrollWheelUp>' '<S-ScrollWheelDown>'; do
  [[ "$(code_diff_explorer_mapping "$horizontal_key")" == "<Nop>" ]] || {
    printf 'CodeDiff explorer does not suppress horizontal gesture %s.\n' "$horizontal_key" >&2
    exit 1
  }
done

expected_diff_filetype="yaml"
if [[ "$click_target" == *.ts ]]; then
  expected_diff_filetype="typescript"
fi
actual_diff_filetype=""
for delay in "${readiness_backoff[@]}"; do
  actual_diff_filetype="$(code_diff_filetype)"
  if [[ "$actual_diff_filetype" == "$expected_diff_filetype" && "$(code_diff_has_treesitter)" == "true" ]]; then
    break
  fi
  sleep "$delay"
done
[[ "$actual_diff_filetype" == "$expected_diff_filetype" && "$(code_diff_has_treesitter)" == "true" ]] || {
  printf 'CodeDiff did not preserve Tree-sitter syntax for %s; filetype=%q.\n' \
    "$click_target" "$actual_diff_filetype" >&2
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

# A Workon update must never discard a modified buffer. Neovim defers its
# native session-preserving restart until the last change is written, then the
# same terminal UI reconnects to a fresh process automatically.
nvim --server "$nvim_socket" --remote-expr "execute('edit! src/app.ts')" >/dev/null
nvim --server "$nvim_socket" --remote-expr \
  "luaeval(\"vim.api.nvim_buf_set_lines(0, -1, -1, false, {'// restart guard'}) or true\")" >/dev/null
restart_pid_before="$(nvim --server "$nvim_socket" --remote-expr 'getpid()')"
restart_result="$(nvim --server "$nvim_socket" --remote-expr \
  "luaeval(\"require('vim_setup.update').request_restart(_A)\", 'v9.9.9')")"
[[ "$restart_result" == waiting-for-save ]] || {
  printf 'Workon update did not defer restart for a modified buffer; result=%q.\n' "$restart_result" >&2
  exit 1
}
nvim --server "$nvim_socket" --remote-expr "execute('write!')" >/dev/null
restart_pid_after="$restart_pid_before"
restart_ready=false
restart_attempts=0
for delay in "${readiness_backoff[@]}"; do
  restart_attempts=$((restart_attempts + 1))
  restart_pid_after="$(nvim --server "$nvim_socket" --remote-expr 'getpid()' 2>/dev/null || true)"
  if [[ "$restart_pid_after" =~ ^[0-9]+$ && "$restart_pid_after" != "$restart_pid_before" ]] && \
      [[ "$(nvim --server "$nvim_socket" --remote-expr "exists(':WorkonRestart')" 2>/dev/null || true)" == 2 ]]; then
    restart_ready=true
    break
  fi
  sleep "$delay"
done
[[ "$restart_ready" == true ]] || {
  printf 'Neovim did not automatically restart and restore its RPC endpoint after %d checks; before=%q after=%q.\n' \
    "$restart_attempts" "$restart_pid_before" "$restart_pid_after" >&2
  exit 1
}

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
