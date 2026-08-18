# Cheat sheet

Press `<Space> ?` in Neovim at any time for the live shortcut menu. Run `:Tutor` for the built-in interactive Vim lesson.

## The four ideas to learn first

- `i` enters Insert mode; `Esc` returns to Normal mode.
- `v` selects text; `y` copies, `d` deletes, and `p` pastes.
- `:` opens a command; `:q` quits and `:w` saves.
- `<Space>` is the leader key for setup-specific actions.

## Find and inspect

| Shortcut | Action |
|---|---|
| `Cmd-P` or `<Space> f f` | Find file |
| `Cmd-Shift-F` or `<Space> f g` | Search text in the project |
| `<Space> e` | Toggle project explorer |
| `<Space> f b` | Find open buffer |
| `<Space> f s` | Symbols in current file |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Documentation for symbol |
| `[d` / `]d` | Previous / next diagnostic |
| `<Space> x x` | All workspace diagnostics |

Kitty translates `Cmd-P` and `Cmd-Shift-F` into terminal-safe keys. The leader alternatives work in every terminal.

## Review agent changes

| Shortcut | Action |
|---|---|
| `<Space> g d` | Full repository diff with file tree |
| `<Space> g c` | Close diff view |
| `<Space> g g` | Lazygit popup |
| `<Space> g f` | List changed files |
| `]h` / `[h` | Next / previous changed hunk |
| `<Space> g p` | Preview changed hunk |
| `<Space> g s` | Stage hunk |
| `<Space> g r` | Reset hunk (asks before destructive cases) |
| `<Space> g b` | Blame current line |
| `<Space> g h` | Current file history |

Inside Diffview, `Tab` / `Shift-Tab` move through changed files, `]c` / `[c` move through differences, and `q` closes ordinary auxiliary windows.

## Read and write Markdown

| Shortcut | Action |
|---|---|
| `<Space> m t` | Toggle rendered/source Markdown |
| `<Space> m e` | Enable rendering |
| `<Space> m d` | Show raw source |
| `<Space> i p` | Preview image referenced under cursor |

Opening a PNG or SVG file displays the asset directly in Kitty. Image links in Markdown can render inline.

## Run projects

| Shortcut | Action |
|---|---|
| `F5` or `<Space> r r` | Run the default project task |
| `<Space> r t` | Choose a task |
| `<Space> r l` | Repeat last task |
| `<Space> r s` | Stop the runner |

## Windows, tmux, and scrolling

- `workon .` starts or returns to the full workspace for the current repository.
- `Ctrl-H/J/K/L` crosses both Neovim splits and tmux panes.
- `<Space> w H/J/K/L` resizes a Neovim split.
- `Ctrl-B H/J/K/L` resizes a tmux pane; dragging a border works too.
- Mouse-wheel scroll enters tmux history. Keyboard alternative: `Ctrl-B [` then `Ctrl-U` / `Ctrl-D`; press `q` to leave.
- `Ctrl-B g` opens Lazygit directly from tmux.
- `Ctrl-B d` detaches without stopping anything; `tmux attach -t work` returns.
- Shift-Enter sends the terminal newline key used by agent chat composers through the shared Kitty mapping.
