#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
selected="${1:-all}"
cases=(typescript react python yaml compose terraform docker json html css lua)
matrix_root="$(mktemp -d "${TMPDIR:-/tmp}/vim-setup-lsp.XXXXXX")"
fixture="$matrix_root/project"

cleanup() {
  rm -rf "$matrix_root"
}
trap cleanup EXIT
mkdir -p "$matrix_root/state" "$matrix_root/cache"
cp -R "$repo_root/tests/fixtures/sample-project" "$fixture"
git -C "$fixture" init -q

is_known=false
if [[ "$selected" == "all" ]]; then
  is_known=true
else
  for case_name in "${cases[@]}"; do
    if [[ "$selected" == "$case_name" ]]; then
      is_known=true
      break
    fi
  done
fi

if [[ "$is_known" != true ]]; then
  printf 'Unknown completion case: %s\nAvailable cases: %s\n' "$selected" "${cases[*]}" >&2
  exit 2
fi

run_case() {
  local case_name="$1"
  local status

  printf '[RUN]  %s\n' "$case_name"
  set +e
  env \
    XDG_CONFIG_HOME="$repo_root/config" \
    XDG_STATE_HOME="$matrix_root/state" \
    XDG_CACHE_HOME="$matrix_root/cache" \
    VIM_SETUP_TESTING=1 \
    VIM_SETUP_E2E_LSP=1 \
    VIM_SETUP_E2E_SCOPE=lsp-completion \
    VIM_SETUP_E2E_LSP_CASE="$case_name" \
    VIM_SETUP_E2E_ROOT="$fixture" \
    VIM_SETUP_REPO_ROOT="$repo_root" \
    nvim --headless \
      --cmd "lua dofile(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/harness.lua').schedule(vim.env.VIM_SETUP_REPO_ROOT .. '/tests/e2e.lua')" \
    2>&1 &
  local nvim_pid=$!
  (
    sleep 30
    kill -TERM "$nvim_pid" >/dev/null 2>&1 || true
  ) &
  local watchdog_pid=$!
  wait "$nvim_pid"
  status=$?
  kill -TERM "$watchdog_pid" >/dev/null 2>&1 || true
  wait "$watchdog_pid" >/dev/null 2>&1 || true
  set -e

  if [[ $status -ne 0 ]]; then
    printf '[FAIL] %s\n' "$case_name" >&2
    return 1
  fi
  printf '[PASS] %s\n' "$case_name"
}

if [[ "$selected" == "all" ]]; then
  for case_name in "${cases[@]}"; do
    run_case "$case_name"
  done
else
  run_case "$selected"
fi

printf 'Language completion matrix passed.\n'
