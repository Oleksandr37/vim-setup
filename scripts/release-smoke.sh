#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/workon-release.XXXXXX")"
source_repo="$test_root/source"
remote_repo="$test_root/remote.git"
key="$test_root/release-key"

cleanup() {
  [[ "$test_root" == "${TMPDIR:-/tmp}"/workon-release.* ]] && rm -rf "$test_root"
}
trap cleanup EXIT

fail() {
  printf 'release smoke: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$source_repo/security"
git init --bare -q "$remote_repo"
git -C "$source_repo" init -q -b main
git -C "$source_repo" config user.name 'Workon release test'
git -C "$source_repo" config user.email 'release-test@example.invalid'
git -C "$source_repo" remote add origin "$remote_repo"
ssh-keygen -q -t ed25519 -N '' -f "$key"
printf 'release-test@example.invalid %s\n' "$(<"$key.pub")" > "$source_repo/security/release-signers"
printf '0.2.0\n' > "$source_repo/VERSION"
printf 'fixture\n' > "$source_repo/README.md"
git -C "$source_repo" add .
git -C "$source_repo" commit -qm 'Release fixture'
git -C "$source_repo" push -qu origin main

env WORKON_RELEASE_REPO_ROOT="$source_repo" WORKON_RELEASE_SIGNING_KEY="$key" \
  "$repo_root/scripts/release.sh" 0.2.0 --yes >/dev/null

object_type="$(git --git-dir="$remote_repo" cat-file -t refs/tags/v0.2.0)"
[[ "$object_type" == tag ]] || fail 'pushed release ref is not an annotated tag'
git --git-dir="$remote_repo" -c gpg.format=ssh \
  -c gpg.ssh.allowedSignersFile="$source_repo/security/release-signers" \
  verify-tag refs/tags/v0.2.0 >/dev/null || fail 'pushed tag signature is not trusted'

if env WORKON_RELEASE_REPO_ROOT="$source_repo" WORKON_RELEASE_SIGNING_KEY="$key" \
    "$repo_root/scripts/release.sh" 0.2.0 --yes >/dev/null 2>&1; then
  fail 'release command allowed an immutable version to be reused'
fi

printf 'Signed release publication smoke test passed.\n'
