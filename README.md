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

The public bootstrap installs the latest signed GitHub release into a versioned directory under `~/.local/share/workon`; it does not execute an arbitrary plugin update from `main`. A local checkout remains a development installation and links its files directly, so this repository can be tested without replacing it with a release. Both modes ask Homebrew to install only missing packages, move replaced config into a timestamped backup, and restore the plugin commits recorded in `lazy-lock.json`. Preview a local installation first with `./install.sh --dry-run`.

Your existing Neovim/Kitty/tmux configuration is not changed merely by cloning this repository. It changes only when you run the installer.

## Daily workflow

Open a repository with:

```bash
workon ~/Documents/work/my-repo
```

The command creates or reuses one persistent workspace for that repository:

```text
┌─────────────────────────────────┬──────────────┐
│ Neovim                          │              │
├─────────────────────────────────┤ agent shell  │
│ terminal tab                    │              │
└─────────────────────────────────┴──────────────┘
```

Run `workon .` when your shell is already in the repository. Each Kitty/Workon window has its own local set of repositories and its own selected repository. Press `Ctrl-B N` to add a repo only to the current Workon window. Move among its repositories with `Ctrl-B n` / `Ctrl-B p` or the mouse.

To see a repository in a separate macOS window, run:

```bash
workon --new-window /path/to/repository
```

Opening the same repository in two Workon windows intentionally links both views to the same persistent editor, terminals, and agents. For genuinely independent changes, create a separate Git worktree and open that path instead; this prevents two agents from editing the same files. `Ctrl-B &` removes a repository only from the current Workon window and never destroys its shared workspace.

The bottom and right panes are fixed terminal decks. Click the green `[+]` at the far-left of the bottom status bar, or press `Ctrl-B c`, to create and reveal another bottom terminal without splitting the pane. The adjacent `[T 2/5]` indicator tracks the visible terminal and opens the terminal picker when clicked. `Ctrl-B t` opens the same picker, while `Ctrl-B T` creates a terminal with a memorable name. `Ctrl-B a` switches agent shells and `Ctrl-B A` creates a named agent shell. Each shell remains alive, with its own process and scrollback, while another is visible. The right pane is tool-neutral: start `codex`, `claude`, or another approved agent yourself. The descriptive alias `vim-workspace` is installed too.

When `workon` is invoked by an agent or macOS automation without an attached TTY, it opens the prepared workspace in a new Kitty window automatically. Closing Kitty does not terminate the underlying workspaces.

Pane sizes start as percentages, so they adapt to laptop and external-monitor dimensions. Drag borders with the mouse, or press `Ctrl-B` followed by repeated `H`, `J`, `K`, or `L`.

Kanagawa Dragon provides one muted, low-brightness palette across Kitty, tmux, Neovim, and Lazygit. In terminal output, hold `Cmd` and click a detected URL to open it. If a link is difficult to target, press `Cmd-Shift-U`; Kitty labels every visible URL so you can choose one from the keyboard.

Workon terminals use a compact `directory ❯` prompt: only the current directory's basename is shown, and the arrow turns green or red for success or failure. The installer also provides zsh completion, private persistent history-based command autosuggestions, and command syntax highlighting through Homebrew packages. This layer applies only to shells created inside Workon: your normal Kitty tabs and private `~/.zshrc` remain yours. Workon sources that private startup file at runtime so existing aliases, SDK paths, and functions still work, but it never copies it into this public repository.

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
  },
  "services": {
    "django": "python manage.py runserver",
    "celery": "celery -A app worker -l INFO",
    "stripe": "stripe listen --forward-to localhost:8000/webhooks/stripe"
  }
}
```

Tasks run in the dedicated bottom terminal named `runner`, keeping terminal processes outside Neovim. Starting a task brings that terminal forward but never interrupts another service terminal. Use `<Space> r t` to choose, `<Space> r l` to rerun, and `<Space> r s` to stop.

Long-running services use their own persistent terminal tabs. Press `<Space> r v` in Neovim or `Ctrl-B v` anywhere to choose a configured service. Starting an already-running service focuses it; use `workon service restart NAME` when you deliberately want to restart it, and `workon service stop NAME` to send Ctrl-C only to that service.

## Review agent changes

Press `<Space> g g` in Neovim for the Diff review surface: changed files on the left and one unified diff on the right. Added and removed lines have distinct green/red backgrounds, character-level changes, and source-language syntax highlighting. Scrolling or moving through the file tree only moves its highlight; the displayed diff changes only when you click a file or press `Enter`.

Click the diff before using `Ctrl-D` / `Ctrl-U` or the mouse wheel to read it. Use `[c` / `]c` for changed hunks, `t` to toggle inline and side-by-side layouts, `o` to open the file for editing, `Tab` to stage or unstage it, and `Esc` or `q` to close the review. The plugin is pinned in `lazy-lock.json` and its native diff library is compiled locally from that pinned source during installation rather than downloaded as an unverified release binary.

Press `<Space> g G` in Neovim or `Ctrl-B g` anywhere in tmux when you need Lazygit's staging, commit, branch, stash, or rebase operations. In Lazygit's Files panel, select an actual file rather than its parent directory and press `e` to open it in Neovim. Press `q` to leave Lazygit; `Esc` only cancels its current dialog.

## Language intelligence

Mason installs and Neovim enables language servers for:

- TypeScript, JavaScript, React, ESLint, HTML, and CSS
- Python with Pyright and Ruff
- Dockerfile and Docker Compose
- Terraform
- JSON and YAML with SchemaStore schemas
- Lua (for editing this setup)

Formatting runs on save through Ruff, Prettier/Prettierd, Stylua, Terraform fmt, or an attached LSP. Use `:FormatDisable` per session, `:FormatDisable!` per buffer, and `:FormatEnable` to restore it.

Code completion opens automatically while typing. `Up` / `Down` select without modifying the buffer, `Enter` or `Tab` accepts, `Cmd-I` opens completion manually on macOS, and `Ctrl-E` closes it. Kitty translates `Cmd-I` to Neovim's `Ctrl-Space`, leaving macOS free to use the physical `Ctrl-Space` chord for switching input languages. Without a visible suggestion, `Enter` and `Tab` retain their normal editing behavior. Arrow keys are consumed if the popup disappears between keystrokes, preventing accidental cursor movement and edits on another source line.

For a flagged error or warning, put the cursor on it and press `Cmd-.` to request only the language server's genuine quick fixes. The chooser never applies an action until you select it and press `Enter`; when the server reports a problem but supplies no fix, Neovim says that no code action is available. `<Space> c a` is the broader list of all code actions and refactors, while `<Space> c d` shows the complete diagnostic.

Diagnostics do not always include an automatic edit. For a type-invalid value, `Cmd-I` can still request context-aware completion at the cursor; for example, TypeScript can suggest a valid string-literal union member even when it publishes no Quick Fix for the diagnostic.

Neovim's recursive client-side LSP file watcher registration is explicitly disabled to avoid file-descriptor exhaustion in macOS and large repositories. Language servers use their native watcher fallback; diagnostics, completion, navigation, and formatting remain enabled.

## Images and documentation

Opening PNG, SVG, JPEG, WebP, GIF, PDF, or macOS ICNS assets shows them in the terminal. Images referenced by Markdown, HTML, CSS, TSX, and JavaScript can render inline. Put the cursor on an image link and press `<Space> i p` for a floating preview. Kitty provides the graphics protocol, tmux passes it through, and ImageMagick converts non-PNG formats locally.

## Local/private overrides

Public config should not contain work paths, tokens, hostnames, or private certificates. Put device-specific settings in:

- `~/.config/kitty/local.conf`
- `~/.config/tmux/local.conf`
- `~/.config/vim-setup/local.lua`

These files are loaded last and remain outside the repository.

## Maintenance

- `workon version` shows the active version and whether it is a development checkout.
- `workon update --check` checks the latest stable GitHub release without installing it.
- `workon update` verifies, stages, tests, and activates a signed release; `workon rollback` atomically returns to the previous one.
- A macOS LaunchAgent checks once per hour. It only reads public GitHub release metadata and never opens a work repository or installs anything. When an update exists, an `↑ vX.Y.Z` button appears in the tmux status line; click it to review and install.
- After activation, clean Workon Neovim instances use Neovim's native session-preserving restart automatically. An instance with unsaved changes waits and restarts as soon as its final modified buffer is saved; changes are never discarded.
- Editors that were already running before this update feature existed need one initial `:restart`; every Workon editor created afterward registers its own private RPC endpoint and updates automatically.
- `vim-setup-doctor` checks external dependencies and config links.
- `:checkhealth` checks Neovim, LSP clients, parsers, and providers.
- `:Lazy` manages plugins; `:Mason` shows language tools.
- `./scripts/check.sh` runs repository checks.
- `./scripts/keymap-audit.sh` rejects duplicate or cross-layer shortcut conflicts and exercises the live shortcut menu keys.
- `./scripts/smoke.sh` installs into temporary XDG directories and verifies startup without touching your live config.
- `./scripts/workspace-smoke.sh` creates a disposable tmux server and verifies local per-window repo lists, shared persistent workspaces, fixed-pane terminal/agent decks, services, and runner isolation.
- `./scripts/zsh-smoke.sh` uses an isolated home and PTY to verify the short prompt, preserved private startup behavior, completion, autosuggestions, and syntax highlighting.
- `./scripts/update-smoke.sh` creates disposable signed and unsigned release repositories and verifies upgrades, rejection, atomic rollback, managed links, and the hourly LaunchAgent.
- `./scripts/e2e.sh` opens a temporary project and exercises Markdown, Tree-sitter, shortcuts, search, CodeDiff rendering and explicit file selection, images, and real terminal-driven completion acceptance with both `Enter` and `Tab`.
- `./scripts/lsp-completion-matrix.sh all` runs isolated, language-specific LSP completion probes. Pass one case such as `python` or `terraform` for a targeted CI/debug run.

See [CHEATSHEET.md](CHEATSHEET.md) for the small set of shortcuts worth learning first.
For the trust model and plugin supply-chain notes, see [SECURITY.md](SECURITY.md).
For the one-command signed-tag workflow whose CI job publishes a GitHub Release, see [RELEASING.md](RELEASING.md).
