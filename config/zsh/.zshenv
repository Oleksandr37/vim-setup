# Preserve a user's private zsh environment without managing or copying it.
if [[ -n ${WORKON_USER_ZDOTDIR:-} && ${WORKON_USER_ZDOTDIR:A} != ${ZDOTDIR:A} ]]; then
  _workon_managed_zdotdir="$ZDOTDIR"
  ZDOTDIR="$WORKON_USER_ZDOTDIR"
  [[ -r "$ZDOTDIR/.zshenv" ]] && builtin source "$ZDOTDIR/.zshenv"
  ZDOTDIR="$_workon_managed_zdotdir"
  unset _workon_managed_zdotdir
fi
