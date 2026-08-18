#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/install.sh" "$repo_root/bin/vim-workspace" "$repo_root/bin/vim-setup-run" "$repo_root/bin/vim-setup-doctor" "$repo_root/scripts/workspace-smoke.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$repo_root/install.sh" "$repo_root/bin/vim-workspace" "$repo_root/bin/vim-setup-run" "$repo_root/bin/vim-setup-doctor" "$repo_root/scripts/workspace-smoke.sh"
fi
if command -v jq >/dev/null 2>&1; then
  jq empty "$repo_root/examples/.vim-setup.json"
fi
git -C "$repo_root" diff --check
printf 'Static checks passed.\n'
