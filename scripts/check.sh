#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/install.sh" "$repo_root/bin/vim-workspace" "$repo_root/bin/workon-update" "$repo_root/bin/vim-setup-run" "$repo_root/bin/vim-setup-doctor" \
  "$repo_root/bin/workon-shell" \
  "$repo_root/scripts/e2e.sh" "$repo_root/scripts/keymap-audit.sh" "$repo_root/scripts/lsp-completion-matrix.sh" \
  "$repo_root/scripts/release.sh" "$repo_root/scripts/release-smoke.sh" "$repo_root/scripts/smoke.sh" \
  "$repo_root/scripts/update-smoke.sh" "$repo_root/scripts/workspace-smoke.sh" "$repo_root/scripts/zsh-smoke.sh"
zsh -n "$repo_root/config/zsh/.zshenv" "$repo_root/config/zsh/.zshrc" "$repo_root/config/zsh/workon.zsh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$repo_root/install.sh" "$repo_root/bin/vim-workspace" "$repo_root/bin/workon-update" "$repo_root/bin/vim-setup-run" "$repo_root/bin/vim-setup-doctor" \
    "$repo_root/bin/workon-shell" \
    "$repo_root/scripts/e2e.sh" "$repo_root/scripts/keymap-audit.sh" "$repo_root/scripts/lsp-completion-matrix.sh" \
    "$repo_root/scripts/release.sh" "$repo_root/scripts/release-smoke.sh" "$repo_root/scripts/smoke.sh" \
    "$repo_root/scripts/update-smoke.sh" "$repo_root/scripts/workspace-smoke.sh" "$repo_root/scripts/zsh-smoke.sh"
fi
if command -v jq >/dev/null 2>&1; then
  jq empty "$repo_root/.vim-setup.json" "$repo_root/examples/.vim-setup.json"
fi
git -C "$repo_root" diff --check
grep -Fq -- '--repo "$GITHUB_REPOSITORY"' "$repo_root/.github/workflows/release.yml" || {
  printf 'The checkout-free release job does not pass an explicit repository to gh.\n' >&2
  exit 1
}
"$repo_root/scripts/keymap-audit.sh"
printf 'Static checks passed.\n'
