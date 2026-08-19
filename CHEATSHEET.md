# Cheat sheet

Press `<Space> /` or `<Space> ?` in Neovim at any time for the live shortcut menu. Run `:Tutor` for the built-in interactive Vim lesson.

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
| `Cmd-.` | Quick fixes for the diagnostic at the cursor |
| `<Space> c a` | All code actions, including general refactors |
| `<Space> c d` | Full diagnostic message at the cursor |
| `<Space> x x` | All workspace diagnostics |

In the `Cmd-P` file picker, press `Enter` to reuse the current window or `Ctrl-T` to open the selected file in a new tab.

Put the cursor on flagged code and press `Cmd-.` from Normal or Insert mode; choose a fix with `Up` / `Down` and apply it with `Enter`. Nothing changes until you press `Enter`; `Esc` closes the list. Only fixes offered by the attached language server appear, so some diagnostics report `No code actions available`. Use `<Space> c a` when you deliberately want broader refactors too. Kitty translates `Cmd-P`, `Cmd-Shift-F`, and `Cmd-.` into terminal-safe keys. The leader alternatives work in every terminal.

## Complete code

| Shortcut | Action |
|---|---|
| `Up` / `Down` | Select the previous / next visible suggestion |
| `Enter` or `Tab` | Accept the selected suggestion |
| `Cmd-I` or `Ctrl-Space` | Open suggestions manually |
| `Ctrl-E` | Close suggestions |

When no suggestion is open, `Enter` inserts a newline and `Tab` retains its normal snippet/tab behavior. Suggestions never modify the buffer until accepted. If the popup closes while using the arrow keys, the arrows are safely ignored instead of moving the editing cursor to another code line.

Diagnostics and completions are separate LSP features. If `Cmd-.` reports no automatic fix for a wrong value, place the cursor where the value is being typed and press `Cmd-I`; type-aware completion may offer the valid replacement. `Ctrl-Space` remains available when the operating system does not reserve it for switching input languages.

## Review agent changes

| Shortcut | Action |
|---|---|
| `<Space> g g` | Review changed files with syntax-colored green/red diffs |
| `<Space> g f` | Open the same changed-files review |
| `<Space> g G` or `Ctrl-B g` | Open Lazygit for staging, commits, branches, and rebases |
| `]h` / `[h` | Next / previous changed hunk |
| `<Space> g p` | Preview changed hunk |
| `<Space> g s` | Stage hunk |
| `<Space> g r` | Reset hunk (asks before destructive cases) |
| `<Space> g b` | Blame current line |
| `<Space> g l` | Git log picker |

In Diff, scrolling or using `Up` / `Down` only moves the file-tree highlight. Click a file or press `Enter` to display its diff explicitly. Click the diff, then use `Ctrl-D` / `Ctrl-U` or the mouse wheel to read it. `[c` / `]c` moves between changed hunks, `t` toggles inline and side-by-side layouts, `o` opens the file for editing, `Tab` stages or unstages it, and `Esc` or `q` closes the review. The diff keeps source-language syntax colors while applying clear line- and character-level green/red backgrounds.

Inside Lazygit, `Tab` / `Shift-Tab` move among panels, `Space` stages the selected file or hunk, and `Enter` inspects. In the Files panel, select an actual file (not its parent folder) and press `e` to return to that file in Neovim with LSP support. `?` shows Lazygit's shortcuts, and `q` closes Lazygit (`Esc` only cancels an open dialog).

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
| `<Space> r v` | Choose/start a project service terminal |
| `<Space> r a` | Create a named agent shell |

## Windows, tmux, and scrolling

- `workon version` shows the active release; `workon update --check` checks manually and `workon update` installs it.
- Click `[↑ vX.Y.Z]` when it appears in the bottom bar to review and install an available signed release. `workon rollback` returns to the previous release.
- `workon .` opens the repository in the current Workon window, or reuses an unattached one.
- `workon --new-window .` opens another macOS Workon window. The same repo shares its persistent workspace; use a Git worktree for independent edits.
- `Ctrl-B n` / `Ctrl-B p` switches repositories local to this Workon window; `Ctrl-B N` adds one and `Ctrl-B &` removes one from this window.
- `Ctrl-B c` creates a bottom terminal tab; `Ctrl-B t` switches terminals; `Ctrl-B T` creates a named terminal.
- Click the green `[+]` at the far-left of the bottom status bar to create a terminal. Click `[T 2/5]` beside it to choose among terminals.
- `Ctrl-B a` switches right-side agent shells; `Ctrl-B A` creates a named agent shell.
- `Ctrl-B v` chooses a service from the project's `.vim-setup.json`.
- `Ctrl-H/J/K/L` crosses both Neovim splits and tmux panes.
- `<Space> w H/J/K/L` resizes a Neovim split.
- `Ctrl-B H/J/K/L` resizes a tmux pane; dragging a border works too.
- Mouse-wheel scroll enters tmux history. Keyboard alternative: `Ctrl-B [` then `Ctrl-U` / `Ctrl-D`; press `q` to leave.
- `Cmd-click` opens a visible URL, including inside tmux/Neovim. `Cmd-Shift-U` opens a keyboard URL picker.
- `Ctrl-B g` opens Lazygit directly from tmux.
- `Ctrl-B d` detaches without stopping anything; `workon .` returns to an unattached matching window.
- Shift-Enter sends the terminal newline key used by agent chat composers through the shared Kitty mapping.
