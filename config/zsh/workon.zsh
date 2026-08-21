# Workon-only interactive shell behavior. This file is safe to source into an
# already-running Workon pane when applying an update without restarting it.
[[ -o interactive ]] || return 0

typeset -g WORKON_SHELL_ACTIVE=1

# A clean macOS account has no persistent zsh history by default. Preserve any
# user choice; otherwise create a private Workon history for useful suggestions
# across terminal tabs and restarts.
_workon_history_needs_private_path=false
if [[ -z ${HISTFILE:-} ]]; then
  _workon_history_needs_private_path=true
elif [[ -n ${WORKON_ZDOTDIR:-} && ${HISTFILE:A} == "${WORKON_ZDOTDIR:A}/"* ]]; then
  _workon_history_needs_private_path=true
fi
if $_workon_history_needs_private_path; then
  _workon_history_dir="${XDG_STATE_HOME:-$HOME/.local/state}/workon"
  mkdir -p "$_workon_history_dir"
  chmod 700 "$_workon_history_dir"
  HISTFILE="$_workon_history_dir/zsh_history"
  HISTSIZE=50000
  SAVEHIST=50000
  setopt append_history share_history hist_ignore_dups
  touch "$HISTFILE"
  chmod 600 "$HISTFILE"
  fc -R "$HISTFILE" 2>/dev/null || true
  unset _workon_history_dir
fi
unset _workon_history_needs_private_path

if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  _workon_comp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  mkdir -p "$_workon_comp_cache"
  compinit -d "$_workon_comp_cache/zcompdump"
  unset _workon_comp_cache
fi

typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
if (( ! $+functions[_zsh_autosuggest_start] )); then
  for _workon_brew_prefix in ${HOMEBREW_PREFIX:-} /opt/homebrew /usr/local; do
    _workon_plugin="$_workon_brew_prefix/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    if [[ -r "$_workon_plugin" ]]; then
      builtin source "$_workon_plugin"
      break
    fi
  done
fi

# Oh My Posh owns zle-line-init in addition to PROMPT, so a later precmd hook
# alone cannot prevent asynchronous full-prompt repaints. Restore only the
# widgets it decorated and remove only its hooks inside Workon; the user's
# global prompt configuration remains untouched in normal shells.
if (( $+functions[_omp_precmd] )); then
  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _omp_precmd 2>/dev/null || true
  add-zsh-hook -d preexec _omp_preexec 2>/dev/null || true
  for _workon_prompt_widget in self-insert zle-line-init; do
    if [[ -n ${widgets[._omp_original::$_workon_prompt_widget]:-} ]]; then
      zle -A "._omp_original::$_workon_prompt_widget" "$_workon_prompt_widget"
    elif [[ ${widgets[$_workon_prompt_widget]:-} == user:_omp_* ]]; then
      zle -D "$_workon_prompt_widget"
    fi
  done
  unset _workon_prompt_widget
fi

# Run after prompt frameworks loaded by the user's .zshrc. The pane border
# already shows the current path, so the prompt needs only success/failure and
# a compact input marker.
autoload -Uz add-zsh-hook
_workon_prompt_precmd() {
  PROMPT='%F{blue}%1~%f %(?.%F{green}.%F{red})❯%f '
  RPROMPT=''
}
add-zsh-hook -d precmd _workon_prompt_precmd 2>/dev/null || true
add-zsh-hook precmd _workon_prompt_precmd
_workon_prompt_precmd

# zsh-syntax-highlighting must be loaded after other widgets and shell setup.
if (( ! $+functions[_zsh_highlight] )); then
  for _workon_brew_prefix in ${HOMEBREW_PREFIX:-} /opt/homebrew /usr/local; do
    _workon_plugin="$_workon_brew_prefix/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    if [[ -r "$_workon_plugin" ]]; then
      builtin source "$_workon_plugin"
      break
    fi
  done
fi

unset _workon_brew_prefix _workon_plugin
