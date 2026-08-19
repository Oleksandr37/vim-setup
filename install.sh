#!/usr/bin/env bash
set -euo pipefail

repo_url="https://github.com/Oleksandr37/vim-setup.git"
install_root="${VIM_SETUP_HOME:-$HOME/.local/share/vim-setup}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd -P || true)"

# When invoked through curl, obtain the complete repository and continue there.
if [[ ! -f "$script_dir/Brewfile" ]]; then
  if [[ -d "$install_root/.git" ]]; then
    git -C "$install_root" pull --ff-only
  elif [[ -e "$install_root" ]]; then
    printf 'Cannot install: %s exists and is not a vim-setup checkout.\n' "$install_root" >&2
    exit 1
  else
    mkdir -p "$(dirname "$install_root")"
    git clone "$repo_url" "$install_root"
  fi
  exec "$install_root/install.sh" "$@"
fi

dry_run=false
skip_packages=false
skip_plugins=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run        Show changes without making them
  --skip-packages  Do not install Homebrew packages
  --skip-plugins   Do not download Neovim plugins and parsers
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --skip-packages) skip_packages=true ;;
    --skip-plugins) skip_plugins=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This installer currently supports macOS only. Linux support is planned.\n' >&2
  exit 1
fi

run() {
  if $dry_run; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

if ! $skip_packages; then
  if ! command -v brew >/dev/null 2>&1; then
    if $dry_run; then
      printf '+ install Homebrew from https://brew.sh\n'
    else
      printf 'Homebrew is missing; installing it first.\n'
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    fi
  fi
  if command -v brew >/dev/null 2>&1; then
    run brew bundle --file="$script_dir/Brewfile"
  elif ! $dry_run; then
    printf 'Homebrew installation finished but brew is not on PATH. Reopen the shell and rerun this script.\n' >&2
    exit 1
  fi
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.local/state/vim-setup/backups/$timestamp"
backed_up=false

backup() {
  local target="$1"
  local relative="${target#"$HOME"/}"
  local destination="$backup_root/$relative"
  run mkdir -p "$(dirname "$destination")"
  run mv "$target" "$destination"
  backed_up=true
}

link_path() {
  local source="$1"
  local target="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf 'Already linked: %s\n' "$target"
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup "$target"
  fi
  run mkdir -p "$(dirname "$target")"
  run ln -s "$source" "$target"
}

link_path "$script_dir/config/nvim" "$HOME/.config/nvim"
link_path "$script_dir/config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
link_path "$script_dir/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
link_path "$script_dir/config/kitty/kanagawa-dragon.conf" "$HOME/.config/kitty/kanagawa-dragon.conf"
link_path "$script_dir/config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
link_path "$script_dir/bin/vim-workspace" "$HOME/.local/bin/vim-workspace"
link_path "$script_dir/bin/vim-workspace" "$HOME/.local/bin/workon"
link_path "$script_dir/bin/vim-setup-run" "$HOME/.local/bin/vim-setup-run"
link_path "$script_dir/bin/vim-setup-doctor" "$HOME/.local/bin/vim-setup-doctor"
run mkdir -p "$HOME/.config/vim-setup"

# Packer plugins and parsers compiled by nvim-treesitter's frozen master branch
# are loaded automatically by Neovim and conflict with the supported 0.12 API.
legacy_paths=("$HOME/.local/share/nvim/site/pack/packer")
for legacy_path in "${legacy_paths[@]}"; do
  if [[ -e "$legacy_path" ]]; then
    backup "$legacy_path"
  fi
done
treesitter_checkout="$HOME/.local/share/nvim/lazy/nvim-treesitter"
if [[ -d "$treesitter_checkout/.git" ]] && \
   [[ "$(git -C "$treesitter_checkout" branch --show-current)" == "master" ]]; then
  backup "$treesitter_checkout"
fi

if ! $dry_run && ! $skip_plugins; then
  printf 'Installing pinned Neovim plugins and parsers...\n'
  nvim --headless "+Lazy! sync" +qa
  nvim --headless "+lua require('vim_setup.treesitter').install(300000)" +qa
  nvim --headless "+Lazy load mason-lspconfig.nvim" "+MasonToolsInstallSync" +qa
fi

if ! $dry_run && tmux -L vim-work has-session 2>/dev/null; then
  tmux -L vim-work source-file "$HOME/.config/tmux/tmux.conf"
fi

if $dry_run; then
  printf '\nDry run complete; no files or packages were changed.\n'
else
  printf '\nvim-setup is ready.\n'
  if $backed_up; then
    printf 'Previous configuration was moved to: %s\n' "$backup_root"
  fi
  printf 'Ensure ~/.local/bin is on PATH, restart Kitty, then run:\n  workon /path/to/repository\n'
fi
