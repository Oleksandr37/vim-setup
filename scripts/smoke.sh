#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/vim-setup-smoke.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export XDG_CONFIG_HOME="$repo_root/config"
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export VIM_SETUP_TESTING=1

run_nvim() {
  local output status
  set +e
  output="$(nvim --headless "$@" +qa 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 ]] || grep -Eiq \
    'Error detected|E5113:|E492:|vim\.schedule callback|stack traceback|attempt to call method|Error executing' \
    <<<"$output"; then
    printf '%s\n' "$output"
    printf 'Neovim smoke test failed.\n' >&2
    exit 1
  fi
}

run_nvim "+Lazy! restore"
run_nvim "+lua require('nvim-treesitter').install({ 'markdown', 'markdown_inline', 'typescript' }):wait(300000)"
run_nvim "+lua local plugins = vim.tbl_keys(require('lazy.core.config').plugins); require('lazy').load({ plugins = plugins })" "+lua print('vim-setup plugins loaded')"
run_nvim "+luafile $repo_root/tests/update.lua"
printf 'Neovim smoke test passed.\n'
