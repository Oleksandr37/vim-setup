#!/usr/bin/env bash
set -euo pipefail

repo_url="https://github.com/Oleksandr37/vim-setup.git"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd -P || true)"

# When invoked through curl, use a disposable bootstrap checkout. The managed
# installer then obtains and verifies the latest signed GitHub release.
if [[ ! -f "$script_dir/Brewfile" ]]; then
  bootstrap_root="$(mktemp -d "${TMPDIR:-/tmp}/workon-bootstrap.XXXXXX")"
  trap 'rm -rf "$bootstrap_root"' EXIT
  git clone --depth 1 -q "$repo_url" "$bootstrap_root/source"
  "$bootstrap_root/source/install.sh" --managed "$@"
  exit
fi

dry_run=false
skip_packages=false
skip_plugins=false
managed=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run        Show changes without making them
  --skip-packages  Do not install Homebrew packages
  --skip-plugins   Do not download Neovim plugins and parsers
  --managed        Install the latest signed release (used by the bootstrap)
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --skip-packages) skip_packages=true ;;
    --skip-plugins) skip_plugins=true ;;
    --managed) managed=true ;;
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
    run brew bundle --no-upgrade --file="$script_dir/Brewfile"
  elif ! $dry_run; then
    printf 'Homebrew installation finished but brew is not on PATH. Reopen the shell and rerun this script.\n' >&2
    exit 1
  fi
fi

install_launch_agent() {
  local checker_root="$HOME/.local/share/workon/checker"
  local checker_bin="$checker_root/bin/workon-update"
  local launch_agents="$HOME/Library/LaunchAgents"
  local plist="$launch_agents/dev.workon.update-check.plist"
  local temporary="$plist.tmp.$$"
  local path_value="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  if $dry_run; then
    printf '+ install hourly Workon update checker at %s\n' "$plist"
    return
  fi
  mkdir -p "$checker_root/bin"
  cp "$script_dir/bin/workon-update" "$checker_bin"
  cp "$script_dir/VERSION" "$checker_root/VERSION"
  chmod 755 "$checker_bin"
  mkdir -p "$launch_agents"
  cat > "$temporary" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.workon.update-check</string>
  <key>ProgramArguments</key>
  <array>
    <string>$checker_bin</string>
    <string>check</string>
    <string>--background</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$path_value</string>
    <key>WORKON_BACKGROUND_CHECK</key><string>1</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>3600</integer>
  <key>StandardOutPath</key><string>/dev/null</string>
  <key>StandardErrorPath</key><string>/dev/null</string>
</dict>
</plist>
EOF
  plutil -lint "$temporary" >/dev/null
  mv -f "$temporary" "$plist"
  if [[ "${WORKON_INSTALL_TESTING:-0}" != 1 ]]; then
    launchctl bootout "gui/$UID" "$plist" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$UID" "$plist"
  fi
}

if $managed; then
  if $dry_run; then
    printf '+ install latest verified Workon release into %s\n' "${WORKON_HOME:-$HOME/.local/share/workon}"
  else
    "$script_dir/bin/workon-update" install --yes
  fi
  install_launch_agent
  printf '\nWorkon managed installation is ready.\n'
  exit
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
link_path "$script_dir/bin/workon-update" "$HOME/.local/bin/workon-update"
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
  nvim --headless "+Lazy! restore" +qa
  nvim --headless "+lua require('vim_setup.treesitter').install(300000)" +qa
  nvim --headless "+Lazy load mason-lspconfig.nvim" "+MasonToolsInstallSync" +qa
fi

tmux_socket="${VIM_SETUP_TMUX_SOCKET:-vim-work}"
if ! $dry_run && tmux -L "$tmux_socket" has-session 2>/dev/null; then
  tmux -L "$tmux_socket" source-file "$HOME/.config/tmux/tmux.conf"
fi

install_launch_agent

if $dry_run; then
  printf '\nDry run complete; no files or packages were changed.\n'
else
  printf '\nvim-setup is ready.\n'
  if $backed_up; then
    printf 'Previous configuration was moved to: %s\n' "$backup_root"
  fi
  printf 'Ensure ~/.local/bin is on PATH, restart Kitty, then run:\n  workon /path/to/repository\n'
fi
