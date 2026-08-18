# vim-setup

A fast, inspectable macOS development environment built from three focused tools:

- Kitty renders the terminal and translates familiar macOS shortcuts.
- tmux owns repositories, agent, editor, and runner panes.
- Neovim handles code intelligence, navigation, Git review, and documentation.

It is designed for TypeScript/React, Python, Docker, Terraform, JSON, YAML, and Markdown. PNG, SVG, and other common image assets render directly in Kitty through the local graphics protocol; ImageMagick performs local conversion. Nothing is uploaded for preview. The configuration is modular, uses a deliberately small plugin set, and pins plugin revisions in `lazy-lock.json`.

## Install

Once this repository is public, a new Mac can install it with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/Oleksandr37/vim-setup/main/install.sh | bash
```

For the current local checkout:

```bash
./install.sh
```

The installer is idempotent. It asks Homebrew to install only missing packages, moves existing config to `~/.local/state/vim-setup/backups/<timestamp>`, and links the repository config into place. Preview everything first with `./install.sh --dry-run`.

Your existing Neovim/Kitty/tmux configuration is not changed merely by cloning this repository. It changes only when you run the installer.

## Daily workflow

Open a repository with:

```bash
workon ~/Documents/work/my-repo
```

The command creates or reuses one tmux window for that repository:

```text
┌─────────────────────────────────┬──────────────┐
│ Neovim                          │              │
├─────────────────────────────────┤ agent shell  │
│ runner / shell                  │              │
└─────────────────────────────────┴──────────────┘
```

Run `workon .` when your shell is already in the repository. The right pane is a normal shell rooted in the repo: start `codex`, `claude`, or another approved agent yourself. Run `workon` for another repository and it creates or reuses that repo's window. Only active repositories occupy tmux windows; `Ctrl-B c` still creates an ordinary window. Move among windows with `Ctrl-B n` / `Ctrl-B p` or the mouse. The descriptive alias `vim-workspace` is installed too.

When `workon` is invoked by an agent or macOS automation without an attached TTY, it opens the prepared workspace in a new Kitty window automatically.

Pane sizes start as percentages, so they adapt to laptop and external-monitor dimensions. Drag borders with the mouse, or press `Ctrl-B` followed by repeated `H`, `J`, `K`, or `L`.

## Project tasks (the launch.json replacement)

Press `F5` or `<Space> r r`. For JavaScript projects, `dev`, `start`, and other package scripts are detected automatically. Make, Just, Docker Compose, and Terraform projects receive useful defaults too.

For explicit per-project behavior, commit a `.vim-setup.json` file:

```json
{
  "default": "dev",
  "tasks": {
    "dev": "npm run dev",
    "test": "npm test",
    "lint": "npm run lint"
  }
}
```

Tasks run in the tmux pane marked `runner`, keeping terminal processes outside Neovim. Use `<Space> r t` to choose, `<Space> r l` to rerun, and `<Space> r s` to stop.

## Language intelligence

Mason installs and Neovim enables language servers for:

- TypeScript, JavaScript, React, ESLint, HTML, and CSS
- Python with Pyright and Ruff
- Dockerfile and Docker Compose
- Terraform
- JSON and YAML with SchemaStore schemas
- Lua (for editing this setup)

Formatting runs on save through Ruff, Prettier/Prettierd, Stylua, Terraform fmt, or an attached LSP. Use `:FormatDisable` per session, `:FormatDisable!` per buffer, and `:FormatEnable` to restore it.

## Images and documentation

Opening PNG, SVG, JPEG, WebP, GIF, PDF, or macOS ICNS assets shows them in the terminal. Images referenced by Markdown, HTML, CSS, TSX, and JavaScript can render inline. Put the cursor on an image link and press `<Space> i p` for a floating preview. Kitty provides the graphics protocol, tmux passes it through, and ImageMagick converts non-PNG formats locally.

## Local/private overrides

Public config should not contain work paths, tokens, hostnames, or private certificates. Put device-specific settings in:

- `~/.config/kitty/local.conf`
- `~/.config/tmux/local.conf`
- `~/.config/vim-setup/local.lua`

These files are loaded last and remain outside the repository.

## Maintenance

- `vim-setup-doctor` checks external dependencies and config links.
- `:checkhealth` checks Neovim, LSP clients, parsers, and providers.
- `:Lazy` manages plugins; `:Mason` shows language tools.
- `./scripts/check.sh` runs repository checks.
- `./scripts/smoke.sh` installs into temporary XDG directories and verifies startup without touching your live config.
- `./scripts/workspace-smoke.sh` creates a disposable tmux server and verifies the three-pane workspace.

See [CHEATSHEET.md](CHEATSHEET.md) for the small set of shortcuts worth learning first.
For the trust model and plugin supply-chain notes, see [SECURITY.md](SECURITY.md).
