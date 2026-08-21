# Make Homebrew's additional completion definitions available before a user's
# normal compinit call. Standard Apple Silicon and Intel prefixes require no
# subprocess on every shell startup.
typeset -ga _workon_brew_prefixes
_workon_brew_prefixes=(${HOMEBREW_PREFIX:-} /opt/homebrew /usr/local)
for _workon_brew_prefix in "${_workon_brew_prefixes[@]}"; do
  [[ -d "$_workon_brew_prefix/opt/zsh-completions/share/zsh-completions" ]] || continue
  # Use Homebrew's versioned opt link instead of its group-writable shared
  # directory so zsh's compaudit security check remains meaningful.
  fpath=("$_workon_brew_prefix/opt/zsh-completions/share/zsh-completions" $fpath)
done

# Keep aliases, functions, SDK initialization, and other private settings. The
# installer never edits, copies, or commits the user's startup file.
if [[ -n ${WORKON_USER_ZDOTDIR:-} && ${WORKON_USER_ZDOTDIR:A} != ${ZDOTDIR:A} ]]; then
  _workon_managed_zdotdir="$ZDOTDIR"
  ZDOTDIR="$WORKON_USER_ZDOTDIR"
  [[ -r "$ZDOTDIR/.zshrc" ]] && builtin source "$ZDOTDIR/.zshrc"
  ZDOTDIR="$_workon_managed_zdotdir"
  unset _workon_managed_zdotdir
fi

builtin source "${WORKON_ZDOTDIR:-${0:A:h}}/workon.zsh"

unset _workon_brew_prefix _workon_brew_prefixes
