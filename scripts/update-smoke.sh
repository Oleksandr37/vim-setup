#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/workon-update.XXXXXX")"
release_repo="$test_root/releases"
test_home="$test_root/home"
api_file="$test_root/latest.json"
signing_key="$test_root/release-key"
signers="$test_root/allowed-signers"

cleanup() {
  [[ "$test_root" == "${TMPDIR:-/tmp}"/workon-update.* ]] && rm -rf "$test_root"
}
trap cleanup EXIT

fail() {
  printf 'update smoke: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$release_repo" "$test_home"
rsync -a --exclude .git "$repo_root/" "$release_repo/"
git -C "$release_repo" init -q
git -C "$release_repo" config user.name 'Workon release test'
git -C "$release_repo" config user.email 'release-test@example.invalid'
ssh-keygen -q -t ed25519 -N '' -f "$signing_key"
printf 'release-test@example.invalid %s\n' "$(<"$signing_key.pub")" > "$signers"
git -C "$release_repo" config gpg.format ssh
git -C "$release_repo" config user.signingkey "$signing_key"

publish_release() {
  local version="$1" signed="${2:-true}"
  printf '%s\n' "$version" > "$release_repo/VERSION"
  git -C "$release_repo" add .
  git -C "$release_repo" commit -qm "Release v$version"
  if $signed; then
    git -C "$release_repo" tag -s "v$version" -m "Workon v$version"
  else
    git -C "$release_repo" tag -a "v$version" -m "Unsigned Workon v$version"
  fi
  jq -n --arg tag "v$version" --arg body "Test release v$version" \
    '{tag_name: $tag, body: $body, html_url: ("https://example.invalid/releases/" + $tag)}' > "$api_file"
}

workon_env=(
  env
  HOME="$test_home"
  WORKON_HOME="$test_home/.local/share/workon"
  WORKON_STATE_HOME="$test_home/.local/state/workon"
  WORKON_REPO_URL="$release_repo"
  WORKON_RELEASES_API_URL="file://$api_file"
  WORKON_SIGNERS_FILE="$signers"
  WORKON_UPDATE_SKIP_RUNTIME=1
  WORKON_UPDATE_TESTING=1
  VIM_SETUP_TMUX_SOCKET="workon-update-test-$$"
)

publish_release 0.2.0
"${workon_env[@]}" "$repo_root/bin/workon-update" install --yes >/dev/null
current="$test_home/.local/share/workon/current"
[[ -L "$current" ]] || fail 'managed current link was not created'
[[ "$(<"$current/VERSION")" == 0.2.0 ]] || fail 'first release was not activated'
[[ "$(readlink "$test_home/.local/bin/workon")" == "$current/bin/vim-workspace" ]] || \
  fail 'workon command does not follow the managed current link'

publish_release 0.3.0
"${workon_env[@]}" "$test_home/.local/bin/workon" update --yes >/dev/null
[[ "$(<"$current/VERSION")" == 0.3.0 ]] || fail 'second release was not activated'
[[ "$(<"$test_home/.local/share/workon/previous/VERSION")" == 0.2.0 ]] || \
  fail 'previous release was not retained'

"${workon_env[@]}" "$test_home/.local/bin/workon" rollback --yes >/dev/null
[[ "$(<"$current/VERSION")" == 0.2.0 ]] || fail 'rollback did not restore the previous release'

publish_release 0.4.0 false
if "${workon_env[@]}" "$test_home/.local/bin/workon" update --yes >/dev/null 2>&1; then
  fail 'an unsigned release was accepted'
fi
[[ "$(<"$current/VERSION")" == 0.2.0 ]] || fail 'failed verification changed the active release'

source_home="$test_root/source-home"
mkdir -p "$source_home"
env HOME="$source_home" WORKON_INSTALL_TESTING=1 VIM_SETUP_TMUX_SOCKET="workon-install-test-$$" \
  "$repo_root/install.sh" --skip-packages --skip-plugins >/dev/null
plist="$source_home/Library/LaunchAgents/dev.workon.update-check.plist"
[[ -f "$plist" ]] || fail 'source install did not create the hourly launch agent'
plutil -lint "$plist" >/dev/null || fail 'hourly launch agent plist is invalid'
grep -q '<integer>3600</integer>' "$plist" || fail 'hourly launch interval is not 3600 seconds'
grep -q '<string>--background</string>' "$plist" || fail 'launch agent does not use the quiet checker'

printf 'Signed release update and rollback smoke tests passed.\n'
