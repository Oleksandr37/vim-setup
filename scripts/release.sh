#!/usr/bin/env bash
set -euo pipefail

repo_root="${WORKON_RELEASE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
signing_key="${WORKON_RELEASE_SIGNING_KEY:-$HOME/.ssh/workon_release_ed25519.pub}"
allowed_signers="$repo_root/security/release-signers"
assume_yes=false
release_key_loaded_by_script=false

unload_release_key() {
  if $release_key_loaded_by_script; then
    ssh-add -d "$public_key_file" >/dev/null 2>&1 || true
  fi
}

usage() {
  cat >&2 <<'EOF'
Usage: ./scripts/release.sh VERSION [--yes]

Creates, verifies, and pushes a signed Workon release tag. GitHub Actions tests
the tag and publishes the GitHub Release; this command does not publish assets.
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
version="$1"
shift
[[ "${1:-}" != --yes ]] || { assume_yes=true; shift; }
[[ $# -eq 0 ]] || usage
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'Version must have the stable semantic form X.Y.Z.\n' >&2
  exit 1
}
tag="v$version"

[[ -d "$repo_root/.git" ]] || { printf 'Not a Git checkout: %s\n' "$repo_root" >&2; exit 1; }
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] || {
  printf 'Releases must be created from main.\n' >&2
  exit 1
}
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] || {
  printf 'The worktree is not clean. Commit or remove every change before releasing.\n' >&2
  exit 1
}
[[ -f "$repo_root/VERSION" && "$(tr -d '[:space:]' < "$repo_root/VERSION")" == "$version" ]] || {
  printf 'VERSION does not match %s. Change it through a reviewed pull request first.\n' "$version" >&2
  exit 1
}
[[ -f "$signing_key" ]] || {
  printf 'Dedicated release signing key is missing: %s\n' "$signing_key" >&2
  printf 'Create and unlock it using the instructions in RELEASING.md.\n' >&2
  exit 1
}
[[ -f "$allowed_signers" ]] || { printf 'Trusted signer policy is missing.\n' >&2; exit 1; }

public_key_file="$signing_key"
if [[ "$public_key_file" != *.pub ]]; then public_key_file="$signing_key.pub"; fi
[[ -f "$public_key_file" ]] || { printf 'Signing public key is missing: %s\n' "$public_key_file" >&2; exit 1; }
public_key="$(awk 'NR == 1 { print $1 " " $2 }' "$public_key_file")"
grep -Fq " $public_key" "$allowed_signers" || {
  printf 'The selected key is not trusted by security/release-signers.\n' >&2
  exit 1
}

git -C "$repo_root" fetch --quiet origin main --tags
[[ "$(git -C "$repo_root" rev-parse HEAD)" == "$(git -C "$repo_root" rev-parse origin/main)" ]] || {
  printf 'Local main is not exactly origin/main. Pull with --ff-only before releasing.\n' >&2
  exit 1
}
if git -C "$repo_root" show-ref --verify --quiet "refs/tags/$tag"; then
  printf 'Tag %s already exists. Versions are immutable.\n' "$tag" >&2
  exit 1
fi

if ! $assume_yes; then
  [[ -t 0 && -t 1 ]] || { printf 'Run interactively or pass --yes.\n' >&2; exit 1; }
  printf 'Sign and push Workon %s from %s? [y/N] ' "$tag" "$(git -C "$repo_root" rev-parse --short HEAD)"
  read -r answer
  [[ "$answer" == y || "$answer" == Y ]] || { printf 'Release cancelled.\n'; exit 0; }
fi

# Keep the release identity out of the long-lived SSH agent during ordinary
# network connections. On macOS, unlock this exact dedicated key from Keychain
# only for signing and remove only this key again when the command exits.
if [[ "$signing_key" == "$HOME/.ssh/workon_release_ed25519.pub" ]] && \
    ! ssh-add -L 2>/dev/null | awk -v expected="$public_key" \
      '$1 " " $2 == expected { found=1 } END { exit !found }'; then
  ssh-add --apple-use-keychain "${signing_key%.pub}"
  release_key_loaded_by_script=true
  trap unload_release_key EXIT
fi

git -C "$repo_root" -c gpg.format=ssh -c user.signingkey="$signing_key" \
  tag -s "$tag" -m "Workon $tag"
if ! git -C "$repo_root" -c gpg.format=ssh \
    -c gpg.ssh.allowedSignersFile="$allowed_signers" verify-tag "$tag"; then
  printf 'Local signature verification failed; %s was not pushed.\n' "$tag" >&2
  exit 1
fi

git -C "$repo_root" push origin "refs/tags/$tag"
printf 'Pushed %s. GitHub Actions will test it and publish the release.\n' "$tag"
